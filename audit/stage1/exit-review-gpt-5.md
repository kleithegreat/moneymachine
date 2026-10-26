# Fifth Stage 1 exit review — C1.4

**C1.4: met.** The revised comparison closes the fourth review’s sole remaining objection: within-instant coin order is now checked, not collapsed into a set.

This judgment uses the supplied source and recorded clean-commit run at `dbe192b`; I did not independently rerun it.

## Criterion

> “`mm` replays W0 on the stage 0 dataset version, and its trace (decisions, fills, funding, equity) matches the stage 0 Python witness to $1e-6 at every step. Every disagreement found along the way is resolved with its root cause recorded.” — `criteria-stage1.md:23`

The trace is an **“ordered list”** (`INVARIANTS.md:4–5`).

## Evidence

**Ordered agreement is now enforced.** `steps` returns a list, preserving sequence and multiplicity:

> `return [(e["t"], e["type"], e.get("coin", "")) for e in by_type(events, KINDS)]` — `test_differential.py:39`

The test requires:

> `assert steps(kernel) == steps(py)` — `test_differential.py:53`

`KINDS` includes equity, decision, hold, fill, liquidation, delisting, unfilled and funding (`test_differential.py:31`). Thus neither phase boundaries nor within-phase coin ordering can be hidden by grouping or sorting.

**The witness uses venue order for held-coin events:**

> `held_coins = lambda: sorted(book.pos, key=list(rules["coins"]).index)` — `witness.py:93`

Funding, liquidation and delisting use that traversal (`witness.py:105–110,117–122`).

**Stepwise numerical checks remain intact.** With `TOL = 1e-6` (`test_differential.py:16`), the test compares equity and reconciliation (`:56–59`), fill quantities, prices and fees (`:61–65`), decision quantities and weights (`:67–69`), and funding rates, prices and payments (`:71–74`). Sorting the funding values does not weaken the separate ordered-event assertion.

**The judged replay passed.** `c14.txt:1–5` records the clean commit, dataset version `1792613363942`, **1 passed**, and **exit 0**. Coverage includes 3,299 equity marks, 1,033 decisions, 1,033 fills, 4,139 funding events and one delisting (`c14.txt:2`).

**Disagreement resolutions are recorded.** `c14-disagreements.md:8–12` identifies the ordering, fill-timing, listed-interval/arithmetic/venue-order and availability-revision causes and their resolving commits. The prior review documents the specific insertion-order versus venue-order discrepancy; the revised witness and passing ordered comparison close it.

## Remaining issues and outcome relevance

**No remaining C1.4 issue identified.** There is no unresolved discrepancy here that could change a false-discovery or leakage outcome. This is acceptance of the specified W0 replay, not a claim that differential testing alone proves the absence of all kernel bugs.


