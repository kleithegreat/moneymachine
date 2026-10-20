"""C5.4: per coin of U, event counts in the search part of W and in the live window, coverage
intervals, recording gaps, and each source's classification (historically replayable / prospective / blocked)."""

import json
import sys

from ingest import events
from ingest.policy import HOLDOUT_START, W_START

GAP_MS = 600_000


def report(data_root, version, live_dir, discourse_admitted):
    from ingest.sources_backfill import START

    out = {}
    for source, spec in events.SOURCES.items():
        admitted = discourse_admitted and source == "discourse"
        coin_of = {r[spec["key"]]: r["coin"] for r in json.loads(spec["map"].read_text())["rows"]}
        obs, polled = events.records(data_root, live_dir, source, version)
        rows = events.counts(obs, polled, coin_of, admitted, START)
        per = {coin: {"search_part": 0, "live_window": 0} for coin in coin_of.values()}
        for (key, _), (created, _) in events.items(obs).items():
            if key in coin_of:
                per[coin_of[key]]["search_part"] += W_START <= created < HOLDOUT_START
                per[coin_of[key]]["live_window"] += key in polled and created >= min(polled[key])
        for key, coin in coin_of.items():
            hours = [h for c, h, _ in rows if c == coin]
            t = sorted(polled.get(key, []))
            per[coin] |= {"coverage_hours": [min(hours), max(hours)] if hours else None,
                          "recording_gaps": [[a, b] for a, b in zip(t, t[1:]) if b - a > GAP_MS]}
        out[source] = {"classification": "historically replayable" if admitted else "prospective", "per_coin": per}
    out["unlocks"] = {"classification": "blocked", "reason": "see Blockers"}
    return out


if __name__ == "__main__":
    data_root, version, live_dir, admitted = sys.argv[1:]
    print(json.dumps(report(data_root, int(version), live_dir, admitted == "admitted"), indent=1))
