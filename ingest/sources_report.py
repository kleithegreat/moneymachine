"""C5.4: per coin of U, event counts in the search part of W and in the live window, coverage
intervals, and each source's classification (historically replayable / prospective / blocked)."""

import json
import sys

from ingest import events
from ingest.store import HOLDOUT_START, W_START


def report(data_root, version, live_dir, discourse_admitted):
    out = {}
    for source, admitted in (("discourse", discourse_admitted), ("snapshot", False)):
        spec = events.SOURCES[source]
        coin_of = {r[spec["key"]]: r["coin"] for r in json.loads(spec["map"].read_text())["rows"]}
        cover = events.coverage(data_root, version, live_dir, admitted and source == "discourse", source)
        items = events.items(data_root, version, live_dir, source)
        per = {}
        for (key, _), (created, _) in items.items():
            if key not in coin_of:
                continue
            c = per.setdefault(coin_of[key], {"search_part": 0, "live_window": 0})
            c["search_part"] += W_START <= created < HOLDOUT_START
            c["live_window"] += key in cover and created >= cover[key][0]
        for key, (first, start, end) in cover.items():
            if key in coin_of:
                per.setdefault(coin_of[key], {})["coverage_hours"] = [start, end]
        out[source] = {"classification": "historically replayable" if admitted and source == "discourse" else "prospective",
                       "per_coin": per}
    out["unlocks"] = {"classification": "blocked", "reason": "see Blockers"}
    return out


if __name__ == "__main__":
    data_root, version, live_dir, admitted = sys.argv[1:]
    print(json.dumps(report(data_root, int(version), live_dir, admitted == "admitted"), indent=1))
