"""C5.4: per coin of U and source, the mapped key, event counts, covered intervals, recording gaps, and each
source's classification (historically replayable / prospective / blocked).

`raw_items_created_in_search_part` counts the raw revisions whose claimed creation time lies in the search
part of W. Both sources are prospective, so no claimed time is admitted and none of them is an input:
`search_part_rows` is the derived rows there, always 0. `live_counted_items` is the sum of the derived
hourly counts, and `covered_intervals` the [first, last] covered hours of each run of consecutive ones.
Recorded keys that map to no coin of U are listed with their raw counts and gaps.
"""

import json
from pathlib import Path

from ingest import events
from ingest.policy import HOLDOUT_START, HOUR, W_START


def runs(hours):
    out = []
    for h in hours:
        if out and h == out[-1][1] + HOUR:
            out[-1][1] = h
        else:
            out.append([h, h])
    return out


def report(data_root, version, live_dir):
    coins = json.loads((Path(data_root) / "universe.json").read_text())["universe"]
    out = {}
    for source, spec in events.SOURCES.items():
        key_of = {r["coin"]: r[spec["key"]] for r in json.loads(spec["map"].read_text())["rows"]}
        coin_of = {k: c for c, k in key_of.items()}
        obs, polled = events.records(data_root, live_dir, source, version)
        rows = events.counts(obs, polled, coin_of, spec["margin"], version)
        raw = {}
        for (key, _), (created, _) in events.items(obs).items():
            raw[key] = raw.get(key, 0) + (W_START <= created < HOLDOUT_START)
        per = {}
        for coin in coins:
            key = key_of.get(coin)
            hours = sorted(h for c, h, _ in rows if c == coin)
            t = sorted(polled.get(key, []))
            per[coin] = {"mapped_key": key, "raw_items_created_in_search_part": raw.get(key, 0), "search_part_rows": 0,
                         "live_counted_items": sum(n for c, _, n in rows if c == coin), "covered_hours": len(hours),
                         "covered_intervals": runs(hours), "recording_gaps": [[a, b] for a, b in zip(t, t[1:]) if b - a > events.GAP]}
        unmapped = {k: {"raw_items_created_in_search_part": raw.get(k, 0),
                        "recording_gaps": [[a, b] for a, b in zip(sorted(t), sorted(t)[1:]) if b - a > events.GAP]}
                    for k, t in polled.items() if k not in coin_of}
        out[source] = {"classification": "prospective", "version": version, "per_coin": per, "recorded_unmapped_keys": unmapped}
    out["unlocks"] = {"classification": "blocked", "reason": "see Blockers"}
    return out
