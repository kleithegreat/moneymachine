"""The sequential sign test on discordant markets (step 6; audit/program/architecture.md 5.2)."""

import math

from gate.control.constants import ALPHA, BETA_ERROR, MAX_MARKETS, THETA1

WIN_STEP = math.log(THETA1 / 0.5)
LOSS_STEP = math.log((1 - THETA1) / 0.5)
UPPER = math.log((1 - BETA_ERROR) / ALPHA)
LOWER = -UPPER


def decide(wins: int, losses: int, markets: int) -> str:
    """`claim`, `futility`, `undecided` (at the last market) or `continue`, from the counts alone."""
    total = wins * WIN_STEP + losses * LOSS_STEP
    if total >= UPPER:
        return "claim"
    if total <= LOWER:
        return "futility"
    return "undecided" if markets >= MAX_MARKETS else "continue"


def outcome(agent_earns: bool, searcher_earns: bool) -> str:
    """A win only when the agent alone earns, a loss only when G100 alone does."""
    if agent_earns and not searcher_earns:
        return "win"
    if searcher_earns and not agent_earns:
        return "loss"
    return "concordant"
