"""The time grid and the dataset policy. The one place Python reads policy.json."""

import json
from pathlib import Path
from typing import TypeAlias, TypedDict

EpochMs: TypeAlias = int


class Policy(TypedDict):
    delta_ms: EpochMs
    settlement_latency_ms: EpochMs
    w_start: EpochMs
    holdout_start: EpochMs
    w_end: EpochMs


POLICY: Policy = json.loads((Path(__file__).resolve().parents[1] / "policy.json").read_text())
HOUR: EpochMs = 3_600_000
DAY: EpochMs = 24 * HOUR
BAR: EpochMs = 4 * HOUR
DELTA: EpochMs = POLICY["delta_ms"]
SETTLEMENT_LATENCY: EpochMs = POLICY["settlement_latency_ms"]
W_START: EpochMs = POLICY["w_start"]
HOLDOUT_START: EpochMs = POLICY["holdout_start"]
W_END: EpochMs = POLICY["w_end"]
