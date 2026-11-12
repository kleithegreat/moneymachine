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


def write_pair(root: Path, market_id: str, strength: float) -> tuple[Path, Path]:
    """The market at `strength` and its twin at strength 0, in two directories of `root`."""
    stem = hashlib.sha256(market_id.encode()).hexdigest()[:16]
    cost_cells = series()["cost_cells"]
    paths = []
    for name, beta in ((f"{stem}-{strength!r}", strength), (f"{stem}-twin", 0.0)):
        paths.append(markets.write(root / name, arrays(market_id, beta), HOLDOUT_DAYS, cost_cells))
    return paths[0], paths[1]
