"""Markets and twins (step 1): a study market at strength b and its twin at strength 0, from the frozen generator."""

import hashlib
from functools import cache
from pathlib import Path

from gate import markets
from gate.agent import campaigns
from gate.control.constants import PAIRS, PLANTED
from gate.sweep import DAYS, HOLDOUT_DAYS


@cache
def series() -> campaigns.SeriesInputs:
    return campaigns.series_inputs()


def fresh_ids(market_id: str) -> list[str]:
    return [f"{market_id}/fresh/{i}" for i in range(PAIRS)]


def arrays(market_id: str, strength: float) -> markets.Arrays:
    return markets.generate("N2", series()["params"], market_id, DAYS, PLANTED, strength)


def stem(market_id: str) -> str:
    return hashlib.sha256(market_id.encode()).hexdigest()[:16]


def write_market(root: Path, market_id: str, strength: float, label: str = "market") -> Path:
    """The market at `strength`, in the directory of `root` named by the id and `label`."""
    path = root / f"{stem(market_id)}-{label}"
    written: Path = markets.write(path, arrays(market_id, strength), HOLDOUT_DAYS, series()["cost_cells"])
    return written


def write_pair(root: Path, market_id: str, strength: float) -> tuple[Path, Path]:
    """The market at `strength` and its twin at strength 0, in two directories of `root`; at strength 0 the two
    are one market, written once."""
    planted = write_market(root, market_id, strength, "planted")
    if strength == 0.0:
        return planted, planted
    return planted, write_market(root, market_id, 0.0, "twin")
