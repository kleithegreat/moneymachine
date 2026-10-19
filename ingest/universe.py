"""Stage 0 universe rule: top 12 perps by USD volume over the 30 days before W."""

import json
import sys
from pathlib import Path

from ingest.hl import DAY, Info
from ingest.store import W_START

RANK_START = W_START - 30 * DAY
SIZE = 12


def rank(info):
    rows = []
    for asset in info.meta()["universe"]:
        coin = asset["name"]
        first = info.post({"type": "fundingHistory", "coin": coin, "startTime": 0}, per_items=20)
        if not first or first[0]["time"] >= RANK_START:
            continue
        bars = info.candles(coin, "1d", RANK_START, W_START)
        rows.append({
            "coin": coin,
            "delisted": bool(asset.get("isDelisted")),
            "first_funding": first[0]["time"],
            "daily_bars": len(bars),
            "usd_volume": sum(float(b["c"]) * float(b["v"]) for b in bars),
        })
        print(coin, rows[-1]["daily_bars"], round(rows[-1]["usd_volume"]), file=sys.stderr)
    return sorted(rows, key=lambda r: -r["usd_volume"])


if __name__ == "__main__":
    ranked = rank(Info())
    out = {"rule": "top 12 by sum(close*volume) of 1d bars in [RANK_START, W_START), first funding < RANK_START",
           "universe": [r["coin"] for r in ranked[:SIZE]], "ranked": ranked}
    Path(sys.argv[1]).write_text(json.dumps(out, indent=1))
