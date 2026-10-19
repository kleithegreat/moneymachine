# PROGRESS

## Now

Stage 0 (feasibility). Next: pre-register stage 0 criteria, GPT review, commit.

GPT: `opencode run -m openai/gpt-6.1-sol --variant high --dir <fresh tmp dir> -f <file> "<prompt>"`.

## Criteria

### Stage 0: feasibility (family: Hyperliquid perp funding dislocations)

Frozen 2026-10-19, before any market data was fetched. Thresholds come from research needs, not from what the data held.

**Family.** Strategies decide at t_d = B + δ for each 4h bar boundary B (UTC 00/04/08/12/16/20). They read only the settled hourly funding rate and premium (Hyperliquid `fundingHistory`) and closed OHLCV bars, never predicted funding. They trade with taker orders of at most $10k notional, keep gross leverage at or below 2× account equity, and pay or receive hourly funding. The witness strategy W0 is fixed now: at each t_d, for each listed coin in U, the target position is −sign(f) · 0.1 · equity / (|U| · p) if |f| > 1e-4, and 0 otherwise. Here f is the funding rate settled at B and p is the close of the bar ending at B.

**Window and universe.** W = [2024-09-30, 2026-09-30) UTC, 730 days. U is the 12 perps with the highest USD volume (Σ close·volume of daily bars) over [2024-08-31, 2024-09-30) among perps whose first funding settlement precedes 2024-08-31. Delisted perps are included. A coin's listed interval runs from its first to its last funding settlement. A coin leaves U at delisting, and W0 is closed out at its last bar.

- **C0.1 Sources.** A manifest names every endpoint used, with its pagination, retention limit, and rate limit as documented and as observed. An acquisition script reproduces the dataset from scratch, stays under half of each documented rate limit, and uses public read-only endpoints only.
- **C0.2 Coverage and integrity.** Over W, for every coin in U within its listed interval: at most 1% of expected funding hours and at most 1% of expected 4h bars are missing, no single contiguous gap exceeds 24 h, and every gap is listed. There are no duplicate keys, bars align to their interval grid, low ≤ min(open, close) and max(open, close) ≤ high, volume ≥ 0, and |funding| ≤ the venue's hourly cap. Units and the sign convention (positive means longs pay) are verified against the venue's docs.
- **C0.3 Availability.** The assumed rule is knownAt = eventTime + δ with δ = 120 s, where eventTime is the funding settlement time or the bar close. For backfilled history this is an assumed convention; it is checked only live. A live recorder polls every coin in U at most every 30 s for at least 24 h, with the host clock offset under 1 s, verified and logged. For every coin and field (funding: at least 24 events per coin; bars: at least 6 closes per coin), 100% of new values are first observed at or before the rule's knownAt. Unclosed bars are never stored.
- **C0.4 Point-in-time store.** Rows are immutable revisions carrying source, fetchedAt, and a content hash. A dataset version pins a fetchedAt cutoff. `as_of(t, version)` returns, per key, the latest revision fetched at or before the cutoff with knownAt ≤ t. Tests cover the exact boundaries (knownAt = t, knownAt = t + 1 ms, the instant a bar closes, a revision fetched after the cutoff) and at least 1,000 random times, and never return a row with knownAt > t. A full refetch of W at least 24 h after the first fetch is stored as a second version, and the count of differing rows is reported.
- **C0.5 Replay completeness.** For at least 99% of (t_d, coin) pairs in W while listed, `as_of(t_d)` returns the funding settled at B and the bar ending at B. Every failure is listed. On a failure, the replay holds its position and does not trade.
- **C0.6 Venue rules.** A versioned rules file covers, for the base fee tier and for U: taker fee, funding interval, payment convention, and cap; size decimals and minimum order notional; maintenance margin; and the liquidation trigger. Each rule carries a source URL and an effective-from date. Where a rule's history before its documented date is unknown, a stated conservative bound applies (highest fee, highest maintenance margin) and is flagged.
- **C0.7 Execution model.** A per-coin taker cost model (bps from mid = half-spread + depth impact, plus fee) is calibrated from the chronologically first 70% of at least 24 h of forward-recorded L2 snapshots (at least 1 per coin per minute). On the last 30%, for each coin in U, each side, and each of $1k and $10k: the model cost is at or above the observed walk-the-book cost from mid in at least 90% of snapshots, and the median excess is at most 3 bps. If the recorded depth cannot fill an order, that snapshot counts as a miss. Applying the model to earlier history is a stated limitation.
- **C0.8 End-to-end witness.** W0 replays over the search part of W from $10k. The fill reference is the open of the bar starting at B, adjusted by the C0.7 model and C0.6 rules. Liquidation is checked at each bar's adverse extreme. The replay emits a decision → order → fill → position → funding/fee → equity trace in which equity equals initial + Σ trade PnL − Σ fees + Σ funding, to 1e-9 relative, at every step. Every input a decision used has knownAt ≤ t_d.
- **C0.9 Holdout.** The last 180 days of W, [2026-04-03, 2026-09-30), live only under `data/holdout/`, and their content hash is recorded when written. A test shows that the search store cannot return any row with eventTime in the holdout. Agent-side isolation is a deployment criterion for stage 3.

Exit when C0.1 to C0.9 all hold. If C0.2, C0.3, or C0.5 fails for this family, stop and pre-register a different family.

## Blockers

## Log

- 2026-10-19: `nix develop` verified (cargo 1.95, rustc 1.95, python 3.13, arch 8.0.0, sqlite 3.51); flake.lock committed; GPT 6.1 Sol reachable.
