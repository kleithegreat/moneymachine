"""The retrieval proxy (PROGRESS.md, Stage 10): public, unauthenticated GET reads for the thesis agents.

Every hop's host is resolved and every address validated as globally routable; the connection is made
to a validated address itself (so a second resolution cannot redirect it), and the connected peer is
checked again. Only places with certified terms (SOURCES.md) are fetched, checked on every hop. URLs with
userinfo, other schemes or other ports are refused. No credential, cookie or caller header is ever sent.
robots.txt is honored and fails closed; requests are spaced at least
SPACING seconds per host across the whole daemon; at most MAX_REDIRECTS redirects are followed.
"""

import http.client
import ipaddress
import socket
import ssl
import threading
import time
import urllib.robotparser
from pathlib import Path
from urllib.parse import urljoin, urlsplit

from ingest import terms

SOURCES = Path(__file__).with_name("SOURCES.md")
USER_AGENT = "moneymachine-thesis-research (read-only)"
SPACING = 5.0
MAX_REDIRECTS = 5
MAX_BYTES = 2_000_000
TIMEOUT = 30
PORTS = {"http": 80, "https": 443}


class Refused(Exception):
    pass


def validated_addresses(host, resolve=socket.getaddrinfo):
    """Every address `host` resolves to, all globally routable, or Refused."""
    try:
        infos = resolve(host, None, proto=socket.IPPROTO_TCP)
    except socket.gaierror as e:
        raise Refused(f"cannot resolve {host}: {e}")
    addresses = sorted({info[4][0] for info in infos})
    for a in addresses:
        ip = ipaddress.ip_address(a.split("%")[0])
        if not ip.is_global or ip.is_multicast or (ip.version == 6 and ip.ipv4_mapped and not ip.ipv4_mapped.is_global):
            raise Refused(f"{host} resolves to a non-global address {a}")
    if not addresses:
        raise Refused(f"{host} resolves to nothing")
    return addresses


def check_url(url):
    parts = urlsplit(url)
    if parts.scheme not in PORTS:
        raise Refused(f"scheme {parts.scheme!r} is not http(s)")
    if parts.username is not None or parts.password is not None or "@" in parts.netloc:
        raise Refused("URLs with userinfo are refused")
    if not parts.hostname:
        raise Refused("no host")
    if (parts.port or PORTS[parts.scheme]) != PORTS[parts.scheme]:
        raise Refused("only the default port is allowed")
    try:
        ipaddress.ip_address(parts.hostname)
        literal = True
    except ValueError:
        literal = False
    return parts, literal


def pinned_socket(address, port):
    sock = socket.create_connection((address, port), TIMEOUT)
    if sock.getpeername()[0] != address:
        sock.close()
        raise Refused("connected peer differs from the validated address")
    return sock


class PinnedHTTP(http.client.HTTPConnection):
    """HTTP to a validated address, with the URL's host in the Host header."""

    def __init__(self, host, address):
        super().__init__(host, PORTS["http"], timeout=TIMEOUT)
        self.address = address

    def connect(self):
        self.sock = pinned_socket(self.address, self.port)


class PinnedHTTPS(http.client.HTTPSConnection):
    """HTTPS to a validated address, verifying the certificate for the URL's host."""

    def __init__(self, host, address):
        super().__init__(host, PORTS["https"], timeout=TIMEOUT, context=ssl.create_default_context())
        self.address = address

    def connect(self):
        self.sock = self._context.wrap_socket(pinned_socket(self.address, self.port), server_hostname=self.host)


class Fetcher:
    """The daemon-wide fetcher: spacing per host, robots cache, and the hop-by-hop validation."""

    def __init__(self, resolve=socket.getaddrinfo, connect=None, clock=time.monotonic, sleep=time.sleep, allowed=None):
        self.resolve, self.clock, self.sleep = resolve, clock, sleep
        self.allowed = terms.allowlist(SOURCES) if allowed is None else allowed
        self.connect = connect or self._connect
        self.lock = threading.Lock()
        self.last = {}
        self.robots = {}

    def _connect(self, host, address, tls, path):
        conn = (PinnedHTTPS if tls else PinnedHTTP)(host, address)
        try:
            conn.request("GET", path, headers={"User-Agent": USER_AGENT, "Accept": "*/*", "Connection": "close"})
            r = conn.getresponse()
            body = r.read(MAX_BYTES + 1)
            return r.status, r.getheader("Location"), r.getheader("Content-Type"), body
        finally:
            conn.close()

    def _space(self, host):
        with self.lock:
            wait = self.last.get(host, -1e18) + SPACING - self.clock()
            self.last[host] = self.clock() + max(wait, 0)
        if wait > 0:
            self.sleep(wait)

    def _get(self, url):
        """One validated GET of one URL (no redirects followed)."""
        parts, _ = check_url(url)
        host = parts.hostname
        address = validated_addresses(host, self.resolve)[0]
        self._space(host)
        path = (parts.path or "/") + (f"?{parts.query}" if parts.query else "")
        return self.connect(host, address, parts.scheme == "https", path)

    def _allowed(self, url):
        parts, _ = check_url(url)
        origin = f"{parts.scheme}://{parts.netloc}"
        if origin not in self.robots:
            try:
                status, _, _, body = self._get(origin + "/robots.txt")
            except (Refused, OSError, http.client.HTTPException):
                status, body = None, b""
            rp = urllib.robotparser.RobotFileParser()
            if status == 200:
                rp.parse(body[:MAX_BYTES].decode("utf-8", "replace").splitlines())
            elif status in (401, 403):
                rp.disallow_all = True
            elif status is not None and 400 <= status < 500:
                rp.allow_all = True
            else:
                rp.disallow_all = True
            self.robots[origin] = rp
        return self.robots[origin].can_fetch(USER_AGENT, url)

    def fetch(self, url):
        """{"status", "url", "final_url", "redirects", "content_type", "body", "truncated", "started", "ended"} or
        a refusal: {"refused": reason, ...}. Times are wall-clock ms."""
        started = int(time.time() * 1000)
        chain, current = [], url
        try:
            for _ in range(MAX_REDIRECTS + 1):
                parts, _ = check_url(current)
                if not terms.admits(self.allowed, parts.hostname, parts.path or "/"):
                    raise Refused(f"{parts.hostname}{parts.path} has no certified terms (SOURCES.md)")
                validated_addresses(parts.hostname, self.resolve)
                if not self._allowed(current):
                    raise Refused(f"robots.txt disallows {current}")
                status, location, ctype, body = self._get(current)
                if status in (301, 302, 303, 307, 308) and location:
                    chain.append(current)
                    current = urljoin(current, location)
                    continue
                return {"status": status, "url": url, "final_url": current, "redirects": chain, "content_type": ctype,
                        "body": body[:MAX_BYTES], "truncated": len(body) > MAX_BYTES,
                        "started": started, "ended": int(time.time() * 1000)}
            raise Refused(f"more than {MAX_REDIRECTS} redirects")
        except (Refused, OSError, http.client.HTTPException) as e:
            return {"refused": str(e) or type(e).__name__, "url": url, "final_url": current, "redirects": chain,
                    "started": started, "ended": int(time.time() * 1000)}
