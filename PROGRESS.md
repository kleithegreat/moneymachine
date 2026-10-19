# PROGRESS

## Now

Stage 0 (feasibility), waiting on time. The live recorder runs detached (`pgrep -f ingest.record`, started 2026-10-19 04:57 UTC; stop it after ≥ 24 h), and the first backfill is running (its version goes in `data/reports/`). After the backfill: the C0.2/C0.5 report. After 24 h: `python -m ingest.availability data/live` (C0.3), `python -m ingest.execution data/live venue/hyperliquid/execution.json` (C0.7), a second backfill (C0.4), the witness `python -m ingest.witness data <version> <out>` (C0.8), and `python -m ingest.holdout data audit/holdout.json` (C0.9).

Stage 1 (kernel MVP) is running in parallel. Its criteria are frozen; the only stage 0 output it waits on is the data for C1.4/C1.8. Done so far: DSL type checker plus 35 adversarial cases, interpreter, simulator, ledger, CLI, 8 hand fixtures (C1.3), the leak canary (C1.7), and CLI ledger tests (C1.6). Next: mutants (C1.1), GPT red team (C1.2), GPT independent timing checker (C1.5), then C1.4/C1.8 on real data.

GPT: `opencode run -m openai/gpt-6.1-sol --variant high --dir <fresh tmp dir> "<prompt>" -f <file>` (message before `-f`, which takes an array). Run it in the background.

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
  - *Revision 2026-10-19, before any data was fetched:* the open of the bar starting at B is a trade from about B, which comes before t_d = B + δ. That breaks the paper's t_decision ≤ t_fill. The fill reference is now the open of the first bar starting after t_d (the bar at B + 4h), and fill time is B + 4h. Decisions therefore execute one bar late. With 4h bars as the finest history, this is the earliest price provably after t_d.
- **C0.9 Holdout.** The last 180 days of W, [2026-04-03, 2026-09-30), live only under `data/holdout/`, and their content hash is recorded when written. A test shows that the search store cannot return any row with eventTime in the holdout. Agent-side isolation is a deployment criterion for stage 3.

Exit when C0.1 to C0.9 all hold. If C0.2, C0.3, or C0.5 fails for this family, stop and pre-register a different family.

### Stage 1: kernel MVP

Frozen 2026-10-19, before any kernel code was written.

**Scope.** `kernel/` is a Rust workspace with a CLI, `mm`. Strategies are JSON ASTs, and the kernel type-checks and interprets them for the stage 0 family: hourly funding and premium, 4h bars, U, decisions at B + δ, taker fills, and costs and rules from `venue/hyperliquid/`. `kernel/INVARIANTS.md` states the invariants and a threat-model matrix (attack mechanism → invariant → expected rejection code). `kernel/DSL.md` and `mm --help` are all that an agent, or the GPT red team, gets besides the paper.

Invariants:
- **I1 causality:** every value a decision reads has knownAt ≤ t_decision under the dataset version.
- **I2 timing:** every fill satisfies max knownAt of the decision's inputs ≤ t_decision ≤ t_submission ≤ t_fill.
- **I3 fill:** each fill names its source bar (coin, openTime). That bar is the first bar with openTime ≥ t_submission, its openTime is ≤ t_fill, and it recorded at least one trade, otherwise the order is unfilled. The fill price is the bar's open moved adversely by the cost model for the order's side and size. The fill records the side and the versions of the cost model and the rules.
- **I4 units:** a program type-checks only if every operation is dimensionally consistent. Rates of different time bases never combine without an explicit conversion. The output is a dimensionless target weight.
- **I5 accounting:** equity = cash + Σ position · mark, where mark is the last closed bar's close. At every 4h step, equity equals initial + realized + unrealized − fees + funding as computed by an independent average-entry ledger, within an absolute $1e-5.
- **I6 ledger:** every result-bearing output (stdout, stderr, files, errors that carry statistics) passes through one disclosure path. That path commits the experiment row and the disclosure row in one transaction before anything is emitted. If the commit fails, nothing result-bearing is emitted. The ledger rejects UPDATE and DELETE. Type-check rejections are logged without touching data.
- **I7 determinism:** the same experiment identity gives a byte-identical result across fresh processes. The identity pins the content hashes of the dataset files at or before the version, rules.json, execution.json, and the kernel build.
- **I8 holdout:** search mode rejects any row with eventTime ≥ the holdout start, whatever path it came from. That covers decision inputs, fills, funding, and valuation.
- **I9 portfolio:** order notional ≤ $10k, gross leverage ≤ 2× equity, sizes truncated to szDecimals, minimum notional enforced (except for exact closes), and maintenance margin checked at each bar's adverse extreme with liquidation. A non-finite weight means hold, and it is recorded rather than crashing.

Criteria:
- **C1.1 Mutants.** For each of I1–I9, at least one patch in `kernel/mutants/` admits a specific prohibited behavior. For each patch, a named test that detects that behavior fails, while the unpatched suite passes. A runner script shows all mutants caught, and the result is recorded in the log.
- **C1.2 Adversarial suite.** `kernel/tests/adversarial/` holds at least 30 programs covering at least 15 distinct mechanisms from the threat matrix. Each attack sits inside an otherwise valid program and declares its expected rejection code. At least 10 programs come from a GPT red team given only the paper, `DSL.md`, and `mm --help`. Every program is rejected with exactly its expected code. A parse error counts only where the mechanism is syntactic. Any evasion is a kernel bug, fixed per §1, after which the program stays in the suite.
- **C1.3 Hand fixtures.** At least 8 hand-computed scenarios match exactly, each with its expected cash, positions, fees, funding, and equity worked out in the test: funding settlement, position reversal, fees, delayed fill, zero-trade (unfilled) bar, liquidation, delisting closeout, and min-notional/rounding.
- **C1.4 Differential replay.** `mm` replays W0 on the stage 0 dataset version, and its trace (decisions, fills, funding, equity) matches the stage 0 Python witness to $1e-6 at every step. Every disagreement found along the way is resolved with its root cause recorded.
- **C1.5 Independent timing checker.** GPT implements an I2/I3 trace checker from the paper and INVARIANTS.md alone. A generator produces at least 1,000 traces with source bars, at least half with labeled planted violations, including wrong-bar, early-bar, zero-trade-bar, and time-order violations. Both checkers match the labels on all of them.
- **C1.6 Ledger and identity.** Tests show: triggers reject UPDATE and DELETE; the experiment row holds every identity field in paper §5 plus the I7 hashes; a read-only or failing ledger makes `mm eval` emit no statistics and exit nonzero; and two fresh processes produce byte-identical results.
- **C1.7 Leak canary (supporting).** The synthetic market is 12 coins over 550 days with i.i.d. Gaussian 4h log returns, σ = 2%, zero funding, and production costs. Seeds are 5 fixed and 5 drawn at test time and logged. Every adversarial program that is admitted, plus 20 random valid programs, has annualized net Sharpe ≤ 4 on every seed (Sharpe is 0 for no trades or zero variance). A deliberately leaking evaluator, compiled only into this test, exceeds 20.
- **C1.8 Speed (supporting).** On this machine in a release build: data load is excluded; interpretation and all runtime checks are included; the ledger commit is excluded; no caching; W0 over the search part of W; median of 20 runs in one process ≤ 100 ms.

Exit when C1.1 to C1.8 all hold.

## Blockers

## Log

- 2026-10-19: The C1.7 canary exposed an I9 flaw. The $10k order cap was checked at the fill price, but an order is sized at the decision price. It is now checked at the decision price (recorded on every fill). The first leak program (0.08 per coin) reached Sharpe 19.6 < 20 because compounding made the cap bind. Sized at 0.005, the leak reaches about 200 and honest runs about −5.
- 2026-10-19: Commit 855260e (`criteria: stage 1`) also carries an unrelated 3-line witness.py fix (the zero-trade fill bar), swept in by `commit -a`. The criteria text in it is unaffected. Criteria commits now stage PROGRESS.md only.
- 2026-10-19: U = BTC ETH SOL SUI kPEPE TIA WIF AAVE FTM(delisted) WLD POPCAT BNB (`data/universe.json`). Survivorship: 10 delisted eligible perps lack full daily bars in the ranking window (MATIC 10/30, about $51M extrapolated vs. the #12 cutoff of $213M; RNDR had been renamed RENDER; the other 8 are micro-caps with 0 bars). None plausibly ranks top 12.
- 2026-10-19: The holdout rule (nothing reads `data/holdout/`) means C0.2/C0.5 for the holdout part of W run on the fetched frames at ingestion, before the split-write, and report counts only. The search part is also checked through the real `as_of`.
- 2026-10-19: `nix develop` verified (cargo 1.95, rustc 1.95, python 3.13, arch 8.0.0, sqlite 3.51); flake.lock committed; GPT 6.1 Sol reachable.
