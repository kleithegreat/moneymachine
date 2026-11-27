"""The multi-source data layer recorder: polls each feed of `venue/sources/datalayer.json` on its
cadence and keeps every response body gzip-compressed under `<out_dir>/raw/<sha256 of the body>.gz`
beside a day-JSONL poll log `{"feed", "url", "sent", "recv", "status", "sha256", "bytes"}`. A stored
body is checked before it is reused: a damaged one is moved aside, never deleted, and rewritten, on
a day-JSONL `repairs` log. A body is known no earlier than its poll's recv; parsing into point-in-time
revisions is downstream, per source (see `fabric.adapters.datalayer_bridge`). A feed whose file name
changes per release declares `discover`: an index URL, a pattern with one group, and a template the
group fills; the index is logged as `<feed>/index`, and transient failures on the discovered URL are
retried on later ticks up to `MAX_DISCOVER_RETRIES` times, each attempt logged separately. A feed may
declare `auth`, `{"param" | "header": NAME, "env": VAR}`: the value of VAR in `.keys.env` (one
`NAME=value` per line, gitignored) is sent as that query parameter or header, never logged, and
replaced by `<credential>` in the stored body before it is hashed (some APIs echo it). A host without
a feed's key does not poll that feed. URLs are validated as HTTPS with an explicit host so adding a
feed is a JSON entry with no legal-certificate blocker.
"""

import gzip
import hashlib
import json
import os
import re
import threading
import zlib
from collections.abc import Collection
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import httpx

from ingest.live import append, now_ms, read, recording

REPO = Path(__file__).resolve().parents[1]
FEEDS = REPO / "venue/sources/datalayer.json"
KEYS = REPO / ".keys.env"
REDACTED = b"<credential>"
TICK = 60
SPACING = 1  # seconds after each poll, so a burst of due feeds never hammers one host
RETRY_STATUSES: frozenset[int | None] = frozenset({None, 404, 429, 500, 502, 503, 504})
MAX_DISCOVER_RETRIES = 10


def validate_url(feed: dict[str, Any], url: str) -> None:
    u = urlsplit(url)
    if u.scheme != "https" or not u.hostname:
        raise ValueError(f"{feed['name']}: invalid or non-HTTPS url {url!r}")


def feeds(path: str | Path = FEEDS) -> dict[str, Any]:
    """The declared feeds, each validated as a well-formed HTTPS endpoint."""
    spec: dict[str, Any] = json.loads(Path(path).read_text())
    for f in spec["feeds"]:
        validate_url(f, f["discover"]["url"] if "discover" in f else f["url"])
    return spec


def secrets(path: str | Path = KEYS) -> dict[str, str]:
    """The `.keys.env` values, by name."""
    lines = Path(path).read_text().splitlines() if Path(path).exists() else []
    return dict(l.split("=", 1) for l in (l.strip() for l in lines) if l and not l.startswith("#"))


def credentials(feed: dict[str, Any], keys: dict[str, str]) -> tuple[dict[str, str], dict[str, str]]:
    """(query params, headers) carrying the feed's declared credential."""
    auth = feed.get("auth")
    if auth is None:
        return {}, {}
    value = keys[auth["env"]]
    return ({auth["param"]: value}, {}) if "param" in auth else ({}, {auth["header"]: value})


def body(out_dir: str | Path, digest: str) -> bytes:
    """A recorded response body by its sha256."""
    return gzip.decompress((Path(out_dir) / "raw" / f"{digest}.gz").read_bytes())


def intact(raw: Path, content: bytes) -> bool:
    """Whether a stored body decompresses to `content`."""
    try:
        return gzip.decompress(raw.read_bytes()) == content
    except (EOFError, OSError, zlib.error):
        return False


def quarantine(raw: Path, out_dir: str | Path, name: str, url: str) -> None:
    """Move a damaged body aside, its bytes kept under their own hash, so its content can be written again. The repair is on
    the record before the move, so a kill between them leaves the body damaged in place and the next poll repairs it again."""
    t = now_ms()
    bad = raw.read_bytes()
    damaged = hashlib.sha256(bad).hexdigest()
    kept = f"{raw.name}.damaged-{damaged}"
    append(
        out_dir,
        "repairs",
        t,
        {
            "t": t,
            "feed": name,
            "url": url,
            "sha256": raw.name.removesuffix(".gz"),
            "kept": kept,
            "damaged_sha256": damaged,
            "bytes": len(bad),
        },
    )
    os.replace(raw, raw.with_name(kept))


def last_polls(out_dir: str | Path) -> dict[str, int]:
    """Each feed's last scheduled poll time, ignoring later retry attempts on indexed feeds."""
    last: dict[str, int] = {}
    indexed: set[str] = set()
    for p in read(out_dir, "datalayer"):
        feed_name: str = p["feed"]
        if feed_name.endswith("/index"):
            base = feed_name.removesuffix("/index")
            indexed.add(base)
            last[base] = p["sent"]
        elif feed_name not in indexed:
            last[feed_name] = p["sent"]
    return last


def poll(
    http: httpx.Client, feed: dict[str, Any], out_dir: str | Path, keys: dict[str, str] | None = None
) -> dict[str, Any]:
    """Fetch the feed once (its index first, if it declares one); returns the last record."""
    auth = credentials(feed, secrets() if keys is None else keys)
    if "discover" not in feed:
        return get(http, feed["name"], feed["url"], feed.get("accept"), out_dir, auth)
    d = feed["discover"]
    index = get(http, feed["name"] + "/index", d["url"], None, out_dir, auth)
    m = re.search(d["pattern"], body(out_dir, index["sha256"]).decode(errors="replace"))
    if index["status"] != 200 or m is None:
        return index
    url = d["template"].format(m.group(1))
    validate_url(feed, url)
    return get(http, feed["name"], url, feed.get("accept"), out_dir, auth)


def get(
    http: httpx.Client,
    name: str,
    url: str,
    accept: str | None,
    out_dir: str | Path,
    auth: tuple[dict[str, str], dict[str, str]] = ({}, {}),
) -> dict[str, Any]:
    """One GET of `url`, logged and stored without the credential `auth` adds."""
    params, headers = auth
    sent = now_ms()
    try:
        r = http.get(httpx.URL(url).copy_merge_params(params), headers=headers | ({"Accept": accept} if accept else {}))
        body, status = r.content, r.status_code
    except httpx.HTTPError as e:
        body, status = repr(e).encode(), None
    for secret in [*params.values(), *headers.values()]:
        body = body.replace(secret.encode(), REDACTED)
    digest = hashlib.sha256(body).hexdigest()
    raw = Path(out_dir) / "raw" / f"{digest}.gz"
    if raw.exists() and not intact(raw, body):
        quarantine(raw, out_dir, name, url)
    if not raw.exists():
        raw.parent.mkdir(parents=True, exist_ok=True)
        tmp = raw.with_suffix(".tmp")
        with open(tmp, "wb") as f:
            f.write(gzip.compress(body))
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, raw)
    rec = {
        "feed": name,
        "url": url,
        "sent": sent,
        "recv": now_ms(),
        "status": status,
        "sha256": digest,
        "bytes": len(body),
    }
    append(out_dir, "datalayer", sent, rec)
    return rec


def poll_with_retries(
    http: httpx.Client,
    feed: dict[str, Any],
    out_dir: str | Path,
    keys: dict[str, str] | None,
    pending: dict[str, tuple[str, int]],
) -> dict[str, Any]:
    """Poll `feed` once and track transient failures on discovered releases in `pending`."""
    rec = poll(http, feed, out_dir, keys)
    if "discover" in feed and rec["feed"] == feed["name"]:
        if rec["status"] in RETRY_STATUSES and MAX_DISCOVER_RETRIES > 0:
            pending[feed["name"]] = (rec["url"], MAX_DISCOVER_RETRIES)
        else:
            pending.pop(feed["name"], None)
    return rec


def retry_pending(
    http: httpx.Client,
    held: Collection[dict[str, Any]],
    out_dir: str | Path,
    keys: dict[str, str] | None,
    pending: dict[str, tuple[str, int]],
    polled: Collection[str] = (),
    stop: threading.Event | None = None,
) -> None:
    """Retry pending discovered URLs once for feeds not polled in the current tick."""
    if not pending:
        return
    resolved_keys = secrets() if keys is None else keys
    for f in held:
        if stop is not None and stop.is_set():
            break
        name = f["name"]
        if name in polled or name not in pending:
            continue
        url, left = pending[name]
        if left <= 0:
            pending.pop(name, None)
            continue
        validate_url(f, url)
        rec = get(http, name, url, f.get("accept"), out_dir, credentials(f, resolved_keys))
        if rec["status"] not in RETRY_STATUSES or left <= 1:
            pending.pop(name, None)
        else:
            pending[name] = (url, left - 1)
        if stop is not None:
            stop.wait(SPACING)


def main(out_dir: str | Path) -> None:
    stop = recording(out_dir)
    spec, keys = feeds(), secrets()
    held = [f for f in spec["feeds"] if f.get("auth", {}).get("env", "") in keys or "auth" not in f]
    print("not polled here, no key:", [f["name"] for f in spec["feeds"] if f not in held], flush=True)
    last = last_polls(out_dir)
    pending: dict[str, tuple[str, int]] = {}
    with httpx.Client(timeout=120, follow_redirects=False, headers={"User-Agent": spec["user_agent"]}) as http:
        while not stop.is_set():
            polled: set[str] = set()
            for f in held:
                if stop.is_set():
                    break
                if now_ms() - last.get(f["name"], 0) >= f["every_h"] * 3_600_000:
                    last[f["name"]] = poll_with_retries(http, f, out_dir, keys, pending)["sent"]
                    polled.add(f["name"])
                    stop.wait(SPACING)
            retry_pending(http, held, out_dir, keys, pending, polled, stop)
            stop.wait(TICK)
