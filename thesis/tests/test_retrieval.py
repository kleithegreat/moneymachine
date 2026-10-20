"""C10.2: the retrieval proxy refuses credentials, other schemes and ports, and non-global destinations
(directly, after a redirect, and on a mixed resolution); honors robots.txt, failing closed; spaces
requests per host; and connects only to the address it validated."""

import socket

import pytest

from thesis import retrieval

PUBLIC = {"example.org": ["93.184.215.14"], "docs.example.org": ["93.184.215.15"], "inner.example.org": ["10.1.2.3"],
          "meta.example.org": ["169.254.169.254"], "loop.example.org": ["127.0.0.1"], "six.example.org": ["::1"],
          "ula.example.org": ["fd00::1"], "mapped.example.org": ["::ffff:127.0.0.1"], "mixed.example.org": ["93.184.215.16", "192.168.0.1"]}


def resolve(host, *_, **__):
    if host not in PUBLIC:
        raise socket.gaierror("unknown")
    return [(socket.AF_INET6 if ":" in a else socket.AF_INET, socket.SOCK_STREAM, 6, "", (a, 443)) for a in PUBLIC[host]]


class Web:
    """A fake network: {(host, path): (status, location, body)}; records every connection."""

    def __init__(self, pages):
        self.pages, self.calls = pages, []

    def __call__(self, host, address, tls, path):
        self.calls.append((host, address, path))
        status, location, body = self.pages.get((host, path), (404, None, b""))
        return status, location, "text/html", body


def fetcher(pages, clock=None):
    t = [0.0]
    sleeps = []
    f = retrieval.Fetcher(resolve=resolve, connect=Web(pages), clock=clock or (lambda: t[0]),
                          sleep=lambda s: (sleeps.append(s), t.__setitem__(0, t[0] + s)))
    return f, sleeps


@pytest.mark.parametrize("url", ["ftp://example.org/x", "https://user:pw@example.org/x", "https://user@example.org/",
                                 "https://example.org:8443/x", "file:///etc/passwd", "https:///nohost"])
def test_refuses_userinfo_schemes_and_ports(url):
    f, _ = fetcher({})
    assert "refused" in f.fetch(url) and f.connect.calls == []


@pytest.mark.parametrize("host", ["inner", "meta", "loop", "six", "ula", "mapped", "mixed"])
def test_refuses_non_global_destinations(host):
    f, _ = fetcher({})
    out = f.fetch(f"https://{host}.example.org/x")
    assert "non-global" in out["refused"] and f.connect.calls == []


def test_refuses_literal_private_addresses():
    f, _ = fetcher({})
    assert "refused" in f.fetch("http://169.254.169.254/latest/meta-data") and f.connect.calls == []


def test_a_redirect_into_a_private_host_is_refused_at_the_next_hop():
    pages = {("example.org", "/robots.txt"): (404, None, b""), ("example.org", "/a"): (302, "https://inner.example.org/x", b"")}
    f, _ = fetcher(pages)
    out = f.fetch("https://example.org/a")
    assert out["redirects"] == ["https://example.org/a"] and "non-global" in out["refused"]
    assert all(c[0] == "example.org" for c in f.connect.calls)


def test_connects_to_the_validated_address_and_follows_up_to_five_redirects():
    pages = {("example.org", "/robots.txt"): (404, None, b"")}
    pages.update({("example.org", f"/{i}"): (301, f"/{i + 1}", b"") for i in range(5)})
    pages[("example.org", "/5")] = (200, None, b"done")
    f, _ = fetcher(pages)
    out = f.fetch("https://example.org/0")
    assert out["status"] == 200 and out["body"] == b"done" and len(out["redirects"]) == 5
    assert {c[1] for c in f.connect.calls} == {"93.184.215.14"}
    pages[("example.org", "/5")] = (301, "/6", b"")
    pages[("example.org", "/6")] = (200, None, b"")
    f, _ = fetcher(pages)
    assert "redirects" in f.fetch("https://example.org/0")["refused"]


def test_robots_disallow_and_failures_are_honored():
    disallow = {("example.org", "/robots.txt"): (200, None, b"User-agent: *\nDisallow: /private\n"),
                ("example.org", "/private/x"): (200, None, b"secret"), ("example.org", "/public"): (200, None, b"ok")}
    f, _ = fetcher(disallow)
    assert "robots" in f.fetch("https://example.org/private/x")["refused"]
    assert f.fetch("https://example.org/public")["status"] == 200
    for robots in [(500, None, b""), (403, None, b"")]:
        f, _ = fetcher({("example.org", "/robots.txt"): robots, ("example.org", "/public"): (200, None, b"ok")})
        assert "robots" in f.fetch("https://example.org/public")["refused"]
    f, _ = fetcher({("docs.example.org", "/public"): (200, None, b"ok")})
    assert f.fetch("https://docs.example.org/public")["status"] == 200


def test_requests_to_one_host_are_spaced():
    pages = {("example.org", "/robots.txt"): (404, None, b""), ("example.org", "/a"): (200, None, b"a")}
    f, sleeps = fetcher(pages)
    f.fetch("https://example.org/a")
    f.fetch("https://example.org/a")
    assert len(f.connect.calls) == 3 and sum(sleeps) >= 2 * retrieval.SPACING - 1e-9


def test_a_connection_whose_peer_differs_is_refused(monkeypatch):
    class Sock:
        def getpeername(self):
            return ("10.0.0.9", 443)

        def close(self):
            pass

    monkeypatch.setattr(socket, "create_connection", lambda *a, **k: Sock())
    with pytest.raises(retrieval.Refused):
        retrieval.pinned_socket("93.184.215.14", 443)
