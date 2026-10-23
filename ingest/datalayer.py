"""The keyless data layer's recorder (PROGRESS.md, Now): polls each feed of `venue/sources/datalayer.json` on its
cadence, read-only, and keeps every response body content-addressed under `<out_dir>/raw/<sha256>` beside a
day-JSONL poll log {"feed", "url", "sent", "recv", "status", "sha256", "bytes"}. A body is known no earlier than
its poll's recv; parsing into point-in-time revisions is offline, per source. A feed is fetched only if its doc
certifies terms for its host (`ingest/terms.py`); adding a feed is a JSON entry and a terms record, no code.
"""

import hashlib
import json
from pathlib import Path
from urllib.parse import urlsplit

import httpx

from ingest import terms
from ingest.live import append, now_ms, read, recording

REPO = Path(__file__).resolve().parents[1]
FEEDS = REPO / "venue/sources/datalayer.json"
TICK = 60


def feeds(path=FEEDS):
    """The declared feeds, each checked against its doc's certified terms."""
    spec = json.loads(Path(path).read_text())
    for f in spec["feeds"]:
        u = urlsplit(f["url"])
        if u.scheme != "https" or not terms.admits(terms.allowlist(REPO / f["doc"]), u.hostname, u.path):
            raise PermissionError(f"{f['name']}: {u.hostname}{u.path} has no certified terms in {f['doc']}")
    return spec


def last_polls(out_dir):
    return {p["feed"]: p["sent"] for p in read(out_dir, "datalayer")}


def poll(http, feed, out_dir):
    sent = now_ms()
    try:
        r = http.get(feed["url"], headers={"Accept": feed["accept"]} if "accept" in feed else {})
        body, status = r.content, r.status_code
    except httpx.HTTPError as e:
        body, status = repr(e).encode(), None
    digest = hashlib.sha256(body).hexdigest()
    raw = Path(out_dir) / "raw" / digest
    if not raw.exists():
        raw.parent.mkdir(parents=True, exist_ok=True)
        raw.write_bytes(body)
    rec = {"feed": feed["name"], "url": feed["url"], "sent": sent, "recv": now_ms(), "status": status,
           "sha256": digest, "bytes": len(body)}
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
