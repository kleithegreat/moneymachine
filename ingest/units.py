"""Units and records shared across `ingest` and `gate`."""

from typing import TypedDict

type EpochMs = int


class Policy(TypedDict):
    """`policy.json`: the knownAt rule's delays and the window boundaries, all in epoch milliseconds."""

    delta_ms: EpochMs
    settlement_latency_ms: EpochMs
    w_start: EpochMs
    holdout_start: EpochMs
    w_end: EpochMs
