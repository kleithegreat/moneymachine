"""The keyless data layer's recorder (paper §5, Acquisition): polls each feed of `venue/sources/datalayer.json` on its
cadence, read-only, and keeps every response body gzip-compressed under `<out_dir>/raw/<sha256 of the body>.gz` beside a
day-JSONL poll log {"feed", "url", "sent", "recv", "status", "sha256", "bytes"}. A stored body is checked before it is
reused: a damaged one is moved aside, never deleted, and rewritten, on a day-JSONL `repairs` log. A body is known no earlier than
its poll's recv; parsing into point-in-time revisions is offline, per source. A feed whose file name changes per
release declares `discover`: an index URL, a pattern with one group, and a template the group fills; the index is
logged as `<feed>/index`. A feed may declare `auth`, `{"param" | "header": NAME, "env": VAR}`: the value of VAR in
`.keys.env` (one `NAME=value` per line, gitignored) is sent as that query parameter or header, never logged, and
replaced by `<credential>` in the stored body before it is hashed (some APIs echo it). A host without a feed's key does not
poll that feed. Every
URL fetched, discovered ones included, needs certified terms for its host under the feed's source in
`venue/sources.toml`, so adding a feed is a JSON entry and a terms record, no code.
"""

import gzip
import hashlib
import json
import os
import re
import zlib
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import httpx

from ingest import terms
from ingest.live import append, now_ms, read, recording

REPO = Path(__file__).resolve().parents[1]
FEEDS = REPO / "venue/sources/datalayer.json"
KEYS = REPO / ".keys.env"
REDACTED = b"<credential>"
TICK = 60
SPACING = 1  # seconds after each poll, so a burst of due feeds never hammers one host


def certify(feed: dict[str, Any], url: str) -> None:
    u = urlsplit(url)
    if u.scheme != "https" or not terms.admits(terms.allowlist(feed["source"]), u.hostname, u.path):
        raise PermissionError(f"{feed['name']}: {u.hostname}{u.path} has no certified terms for source {feed['source']}")


def feeds(path: str | Path = FEEDS) -> dict[str, Any]:
    """The declared feeds, each checked against its doc's certified terms."""
    spec: dict[str, Any] = json.loads(Path(path).read_text())
    for f in spec["feeds"]:
        certify(f, f["discover"]["url"] if "discover" in f else f["url"])
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
    append(out_dir, "repairs", t, {"t": t, "feed": name, "url": url, "sha256": raw.name.removesuffix(".gz"), "kept": kept,
                                   "damaged_sha256": damaged, "bytes": len(bad)})
    os.replace(raw, raw.with_name(kept))


def last_polls(out_dir: str | Path) -> dict[str, int]:
    """Each feed's last poll time (an index fetch counts for its feed)."""
    return {p["feed"].removesuffix("/index"): p["sent"] for p in read(out_dir, "datalayer")}


def poll(http: httpx.Client, feed: dict[str, Any], out_dir: str | Path, keys: dict[str, str] | None = None) -> dict[str, Any]:
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
    certify(feed, url)
    return get(http, feed["name"], url, feed.get("accept"), out_dir, auth)


def get(http: httpx.Client, name: str, url: str, accept: str | None, out_dir: str | Path,
        auth: tuple[dict[str, str], dict[str, str]] = ({}, {})) -> dict[str, Any]:
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
    rec = {"feed": name, "url": url, "sent": sent, "recv": now_ms(), "status": status, "sha256": digest, "bytes": len(body)}
    append(out_dir, "datalayer", sent, rec)
    return rec


def main(out_dir: str | Path) -> None:
    stop = recording(out_dir)
    spec, keys = feeds(), secrets()
    held = [f for f in spec["feeds"] if f.get("auth", {}).get("env", "") in keys or "auth" not in f]
    print("not polled here, no key:", [f["name"] for f in spec["feeds"] if f not in held], flush=True)
    last = last_polls(out_dir)
    with httpx.Client(timeout=120, follow_redirects=False, headers={"User-Agent": spec["user_agent"]}) as http:
        while not stop.is_set():
            for f in held:
                if stop.is_set():
                    break
                if now_ms() - last.get(f["name"], 0) >= f["every_h"] * 3_600_000:
                    last[f["name"]] = poll(http, f, out_dir, keys)["sent"]
                    stop.wait(SPACING)
            stop.wait(TICK)
