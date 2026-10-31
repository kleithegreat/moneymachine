"""Stage 5 live recorder: polls Discourse forums and Snapshot every 4 minutes, appending raw replies,
and logs the kernel's own bound on its clock error (adjtimex) each cycle as source "clock".

Each line: {"source", "key", "sent", "recv", "data"}. Analysis is offline (C5.3).
"""

import ctypes
import hashlib
import struct
import time
from pathlib import Path

import httpx

from ingest.live import append, now_ms, recording

FORUMS = ["delvingbitcoin.org"]
SPACES = ["aavedao.eth"]
HUB = "https://hub.snapshot.org/graphql"
POLL = 240
QUERY = ('{ proposals(first: 20, where: {space: "%s"}, orderBy: "created", orderDirection: desc) '
         '{ id created updated start end state author ipfs } }')


def kernel_clock():
    buf = ctypes.create_string_buffer(256)
    if ctypes.CDLL(None).adjtimex(buf) < 0:
        raise OSError("adjtimex")
    maxerror, esterror, status = struct.unpack_from("qqi", buf, 24)
    return {"maxerror_ms": maxerror / 1000, "esterror_ms": esterror / 1000, "unsynced": bool(status & 0x40)}


def reply(r):
    return r.json() if r.status_code == 200 else {"status": r.status_code}


def main(out_dir):
    out = Path(out_dir)
    stop = recording(out, "sources-record", out_dir=out_dir)
    http = httpx.Client(timeout=30, headers={"User-Agent": "moneymachine-research-recorder (read-only)"})
    while not stop.is_set():
        started = time.time()
        jobs = [("discourse", f, lambda f=f: reply(http.get(f"https://{f}/posts.json"))) for f in FORUMS]
        jobs += [("snapshot", s, lambda s=s: reply(http.post(HUB, json={"query": QUERY % s})))
                 for s in SPACES]
        jobs += [("clock", "kernel", kernel_clock)]
        for source, key, request in jobs:
            if stop.is_set():
                break
            sent = now_ms()
            try:
                data = request()
                if source == "discourse" and "latest_posts" in data:
                    keep = ("id", "topic_id", "post_number", "created_at", "updated_at", "version", "deleted_at", "hidden")
                    data = [{k: p.get(k) for k in keep} | {"cooked_sha256": hashlib.sha256(p.get("cooked", "").encode()).hexdigest()}
                            for p in data["latest_posts"]]
            except Exception as e:
                data = {"error": repr(e)}
            append(out, "sources", sent, {"source": source, "key": key, "sent": sent, "recv": now_ms(), "data": data})
        stop.wait(max(0, POLL - (time.time() - started)))

