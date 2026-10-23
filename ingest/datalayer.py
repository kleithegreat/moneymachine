"""The keyless data layer's recorder (PROGRESS.md, Now): polls each feed of `venue/sources/datalayer.json` on its
cadence, read-only, and keeps every response body gzip-compressed under `<out_dir>/raw/<sha256 of the body>.gz` beside a
day-JSONL poll log {"feed", "url", "sent", "recv", "status", "sha256", "bytes"}. A body is known no earlier than
its poll's recv; parsing into point-in-time revisions is offline, per source. A feed whose file name changes per
release declares `discover`: an index URL, a pattern with one group, and a template the group fills; the index is
logged as `<feed>/index`. Every URL fetched, discovered ones included, needs certified terms for its host under the
feed's source in `venue/sources.toml`, so adding a feed is a JSON entry and a terms record, no code.
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


def body(out_dir, digest):
    """A recorded response body by its sha256."""
    return gzip.decompress((Path(out_dir) / "raw" / f"{digest}.gz").read_bytes())


def last_polls(out_dir):
    """Each feed's last poll time (an index fetch counts for its feed)."""
    return {p["feed"].removesuffix("/index"): p["sent"] for p in read(out_dir, "datalayer")}


def poll(http, feed, out_dir):
    """Fetch the feed once (its index first, if it declares one); returns the last record."""
    if "discover" not in feed:
        return get(http, feed["name"], feed["url"], feed.get("accept"), out_dir)
    d = feed["discover"]
    index = get(http, feed["name"] + "/index", d["url"], None, out_dir)
    m = re.search(d["pattern"], body(out_dir, index["sha256"]).decode(errors="replace"))
    if index["status"] != 200 or m is None:
        return index
    url = d["template"].format(m.group(1))
    certify(feed, url)
    return get(http, feed["name"], url, feed.get("accept"), out_dir)


def get(http, name, url, accept, out_dir):
    sent = now_ms()
    try:
        r = http.get(url, headers={"Accept": accept} if accept else {})
        body, status = r.content, r.status_code
    except httpx.HTTPError as e:
        body, status = repr(e).encode(), None
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
    spec = feeds()
    last = last_polls(out_dir)
    with httpx.Client(timeout=120, follow_redirects=False, headers={"User-Agent": spec["user_agent"]}) as http:
        while not stop.is_set():
            for f in spec["feeds"]:
                if stop.is_set():
                    break
                if now_ms() - last.get(f["name"], 0) >= f["every_h"] * 3_600_000:
                    last[f["name"]] = poll(http, f, out_dir)["sent"]
            stop.wait(TICK)
