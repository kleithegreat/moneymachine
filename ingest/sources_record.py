"""Stage 5 live recorder: polls Discourse forums and Snapshot every 5 minutes, appending raw replies,
and logs the host clock's NTP offset (systemd-timesyncd) each cycle as source "clock".

Each line: {"source", "key", "sent", "recv", "data"}. Analysis is offline (C5.3).
"""

import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

import httpx

FORUMS = ["delvingbitcoin.org", "ethresear.ch", "forum.solana.com", "forums.sui.io", "forum.celestia.org",
          "governance.aave.com", "forum.bnbchain.org"]
SPACES = ["aavedao.eth"]
POLL = 300
QUERY = ('{ proposals(first: 20, where: {space: "%s"}, orderBy: "created", orderDirection: desc) '
         '{ id created updated start end state author ipfs } }')


def now_ms():
    return int(time.time() * 1000)


def clock_offset_ms():
    out = subprocess.run(["timedatectl", "timesync-status"], capture_output=True, text=True).stdout
    m = re.search(r"Offset: ([+-]?[\d.]+)(us|ms|s)\b", out)
    return float(m.group(1)) * {"us": 1e-3, "ms": 1.0, "s": 1e3}[m.group(2)] if m else None


def reply(r):
    return r.json() if r.status_code == 200 else {"status": r.status_code}


def main(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    http = httpx.Client(timeout=30, headers={"User-Agent": "moneymachine-research-recorder (read-only)"})
    while True:
        started = time.time()
        jobs = [("discourse", f, lambda f=f: reply(http.get(f"https://{f}/posts.json"))) for f in FORUMS]
        jobs += [("snapshot", s, lambda s=s: reply(http.post("https://hub.snapshot.org/graphql", json={"query": QUERY % s})))
                 for s in SPACES]
        jobs += [("clock", "timesyncd", lambda: {"offset_ms": clock_offset_ms()})]
        for source, key, request in jobs:
            sent = now_ms()
            try:
                data = request()
                if source == "discourse" and "latest_posts" in data:
                    keep = ("id", "topic_id", "post_number", "created_at", "updated_at", "version", "deleted_at", "hidden")
                    data = [{k: p.get(k) for k in keep} | {"cooked_sha256": hashlib.sha256(p.get("cooked", "").encode()).hexdigest()}
                            for p in data["latest_posts"]]
            except Exception as e:
                data = {"error": repr(e)}
            day = time.strftime("%Y%m%d", time.gmtime(sent / 1000))
            with open(out / f"sources-{day}.jsonl", "a") as fh:
                fh.write(json.dumps({"source": source, "key": key, "sent": sent, "recv": now_ms(), "data": data}) + "\n")
        time.sleep(max(0, POLL - (time.time() - started)))


if __name__ == "__main__":
    main(sys.argv[1])
