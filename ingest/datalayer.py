"""The keyless data layer's recorder (paper §5, Acquisition): polls each feed of `venue/sources/datalayer.json` on its
cadence, read-only, and keeps every response body gzip-compressed under `<out_dir>/raw/<sha256 of the body>.gz` beside a
day-JSONL poll log {"feed", "url", "sent", "recv", "status", "sha256", "bytes"}. A body is known no earlier than
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
import re
from pathlib import Path
from urllib.parse import urlsplit

import httpx

from ingest import terms
from ingest.live import append, now_ms, read, recording

REPO = Path(__file__).resolve().parents[1]
FEEDS = REPO / "venue/sources/datalayer.json"
KEYS = REPO / ".keys.env"
REDACTED = b"<credential>"
TICK = 60


def certify(feed, url):
    u = urlsplit(url)
    if u.scheme != "https" or not terms.admits(terms.allowlist(feed["source"]), u.hostname, u.path):
        raise PermissionError(f"{feed['name']}: {u.hostname}{u.path} has no certified terms for source {feed['source']}")


def feeds(path=FEEDS):
    """The declared feeds, each checked against its doc's certified terms."""
    spec = json.loads(Path(path).read_text())
    for f in spec["feeds"]:
        certify(f, f["discover"]["url"] if "discover" in f else f["url"])
    return spec


def secrets(path=KEYS):
    """The `.keys.env` values, by name."""
    lines = Path(path).read_text().splitlines() if Path(path).exists() else []
    return dict(l.split("=", 1) for l in (l.strip() for l in lines) if l and not l.startswith("#"))


def credentials(feed, keys):
    """(query params, headers) carrying the feed's declared credential."""
    auth = feed.get("auth")
    if auth is None:
        return {}, {}
    value = keys[auth["env"]]
    return ({auth["param"]: value}, {}) if "param" in auth else ({}, {auth["header"]: value})


def body(out_dir, digest):
    """A recorded response body by its sha256."""
    return gzip.decompress((Path(out_dir) / "raw" / f"{digest}.gz").read_bytes())


def last_polls(out_dir):
    """Each feed's last poll time (an index fetch counts for its feed)."""
    return {p["feed"].removesuffix("/index"): p["sent"] for p in read(out_dir, "datalayer")}


def poll(http, feed, out_dir, keys=None):
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


def get(http, name, url, accept, out_dir, auth=({}, {})):
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
    if not raw.exists():
        raw.parent.mkdir(parents=True, exist_ok=True)
        raw.write_bytes(gzip.compress(body))
    rec = {"feed": name, "url": url, "sent": sent, "recv": now_ms(), "status": status, "sha256": digest, "bytes": len(body)}
    append(out_dir, "datalayer", sent, rec)
    return rec


def main(out_dir):
    stop = recording(out_dir, "datalayer-record", out_dir=out_dir)
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
            stop.wait(TICK)
