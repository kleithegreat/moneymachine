"""The cost cells of coins without a calibrated book (C0.7: a delisted coin of U)."""

from typing import Any

Cells = dict[str, dict[str, dict[Any, float]]]


def fill_missing(model: Cells, coins: list[str]) -> tuple[Cells, list[str]]:
    """Coins without a live book get the cell-wise maximum over the calibrated coins."""
    flagged = [c for c in coins if c not in model]
    worst = {
        side: {size: max(model[c][side][size] for c in model) for size in model[next(iter(model))][side]}
        for side in ("buy", "sell")
    }
    return {c: model.get(c, worst) for c in coins}, flagged
