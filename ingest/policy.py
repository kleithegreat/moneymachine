"""The time grid and the dataset policy. The one place Python reads policy.json."""

import json
from pathlib import Path

POLICY = json.loads((Path(__file__).resolve().parents[1] / "policy.json").read_text())
HOUR = 3_600_000
DAY = 24 * HOUR
BAR = 4 * HOUR
DELTA = POLICY["delta_ms"]
SETTLEMENT_LATENCY = POLICY["settlement_latency_ms"]
W_START = POLICY["w_start"]
HOLDOUT_START = POLICY["holdout_start"]
W_END = POLICY["w_end"]
