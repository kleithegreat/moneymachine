"""Write venue/hyperliquid/rules.json: documented venue rules plus per-coin rules from `meta`."""

import json
import sys
import time
from pathlib import Path

from ingest.hl import Info

DOCS = "https://hyperliquid.gitbook.io/hyperliquid-docs"


def build(info, coins, today):
    meta = info.meta()
    tables = dict(meta["marginTables"])
    assets = {a["name"]: a for a in meta["universe"]}
    unknown_history = f"history before {today} unknown; current value applied to all of W"
    return {
        "venue": "hyperliquid",
        "fetched": today,
        "rules": {
            "taker_fee": {"value": 0.00045, "source": f"{DOCS}/trading/fees", "effective_from": today,
                          "flag": "base tier was 0.035% before an undated change; the higher 0.045% is applied to all of W"},
            "maker_fee": {"value": 0.00015, "source": f"{DOCS}/trading/fees", "effective_from": today,
                          "flag": unknown_history},
            "funding_interval_ms": {"value": 3_600_000, "source": f"{DOCS}/trading/funding", "effective_from": today,
                                    "flag": "fundingHistory is hourly from 2023-05; checked in data"},
            "funding_convention": {"value": "payment = size * oracle_price * rate; rate > 0 means longs pay shorts",
                                   "source": f"{DOCS}/trading/funding", "effective_from": today},
            "funding_cap_per_hour": {"value": 0.04, "source": f"{DOCS}/trading/funding", "effective_from": today,
                                     "flag": unknown_history},
            "min_order_notional_usd": {"value": 10.0, "source": f"{DOCS}/for-developers/api/error-responses",
                                       "effective_from": today, "flag": unknown_history,
                                       "note": "reduce-only orders that exactly close a position are exempt"},
            "size_rounding": {"value": "truncate toward zero to szDecimals",
                              "source": f"{DOCS}/for-developers/api/tick-and-lot-size", "effective_from": today},
            "maintenance_margin": {"value": "1 / (2 * maxLeverage of the margin tier containing the position notional)",
                                   "source": f"{DOCS}/trading/liquidations", "effective_from": today,
                                   "flag": unknown_history},
            "liquidation_trigger": {"value": "account equity at mark < total maintenance margin (cross)",
                                    "source": f"{DOCS}/trading/liquidations", "effective_from": today,
                                    "flag": "historical marks unavailable; evaluator uses each bar's adverse extreme"},
        },
        "coins": {
            c: {"szDecimals": assets[c]["szDecimals"], "maxLeverage": assets[c]["maxLeverage"],
                "marginTiers": tables[assets[c]["marginTableId"]]["marginTiers"]
                if assets[c].get("marginTableId") in tables else [{"lowerBound": "0.0", "maxLeverage": assets[c]["maxLeverage"]}],
                "delisted": bool(assets[c].get("isDelisted")),
                "flag": unknown_history}
            for c in coins
        },
    }


if __name__ == "__main__":
    data_root, out = sys.argv[1:]
    coins = json.loads((Path(data_root) / "universe.json").read_text())["universe"]
    rules = build(Info(), coins, time.strftime("%Y-%m-%d", time.gmtime()))
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    Path(out).write_text(json.dumps(rules, indent=1) + "\n")
