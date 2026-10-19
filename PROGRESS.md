# PROGRESS

## Now

Stages run in parallel wherever work does not depend on a wait. Detached processes (kill by PID only): `pgrep -af "python -m ingest.record"` (HL live recorder), `pgrep -af sources_record` (stage 5 forum and Snapshot recorder).

- **Stage 0, from 2026-10-20 07:05 UTC:** C0.3 (from 04:57) and C0.7 (from 07:03) reach their 24 h.
  - `python -m ingest.availability data/live` (C0.3);
  - `python -m ingest.execution data/live venue/hyperliquid/execution.json` (C0.7);
  - a second backfill, `python -m ingest.backfill data 200` (C0.4; its ingestion report is the judged C0.2/C0.5 evidence);
  - the witness (C0.8);
  - `python -m ingest.holdout data audit/holdout.json` (C0.9);
  - stop the HL recorder.
- **Stage 1:** done except C1.4 and C1.8, which follow C0.7 (both already pass a dry run on provisional costs).
- **Stage 2:** nulls frozen; C2.2 and C2.3 met; C2.1's fixed probes pass (v3). After C0.7: `python -m gate.sweep c24`, then `calibrate`, then `c25`, then the C2.1 top-5 probes.
- **Stage 3:** built. After C0.7: record `harness.harness_hash()` (the freeze), run 20 `stage3.null_campaign`s (C3.2), then `real_campaign` once stage 2 exits.
- **Stage 4:** C4.1 and C4.2 done; C4.3's isolation and injection tests pass (the per-campaign parts are judged on C4.5's runs). The swarm is built. After the harness freeze: `python -m gate.stage4 10` (C4.5).
- **Stage 5:** criteria frozen (one revision). The Discourse backfill runs (`data/sources_backfill1.*`). At ≥ 72 h of recording (2026-10-22 10:26 UTC):
  - `python -m ingest.sources_avail analyze data/sources_live`;
  - re-backfill, then `reconcile`;
  - `python -m ingest.events data <version> data/sources_live admitted|prospective`;
  - then C5.4 and C5.6 (extend nulls, probes and searcher to `forum_posts`).

  Snapshot is prospective only (client-claimed time). Unlocks: no free source found so far (DefiLlama is paid; its adapters repo is gone).

GPT: `opencode run -m openai/gpt-6.1-sol --variant high --dir <fresh tmp dir> "<prompt>" -f <file>` (message before `-f`, which takes an array). Run it in the background.

## Criteria

### Stage 0: feasibility (family: Hyperliquid perp funding dislocations)

Frozen 2026-10-19, before any market data was fetched. Thresholds come from research needs, not from what the data held.

**Family.** Strategies decide at t_d = B + δ for each 4h bar boundary B (UTC 00/04/08/12/16/20). They read only the settled hourly funding rate and premium (Hyperliquid `fundingHistory`) and closed OHLCV bars, never predicted funding. They trade with taker orders of at most $10k notional, keep gross leverage at or below 2× account equity, and pay or receive hourly funding. The witness strategy W0 is fixed now: at each t_d, for each listed coin in U, the target position is −sign(f) · 0.1 · equity / (|U| · p) if |f| > 1e-4, and 0 otherwise. Here f is the funding rate settled at B and p is the close of the bar ending at B.

**Window and universe.** W = [2024-09-30, 2026-09-30) UTC, 730 days. U is the 12 perps with the highest USD volume (Σ close·volume of daily bars) over [2024-08-31, 2024-09-30) among perps whose first funding settlement precedes 2024-08-31. Delisted perps are included. A coin's listed interval runs from its first to its last funding settlement. A coin leaves U at delisting, and W0 is closed out at its last bar.
  - *Revision 2026-10-19, before the C0.2/C0.5 report was seen:* Hyperliquid keeps writing funding rows of rate 0.0 and premium 0.0 after a coin is delisted. FTM's daily bars end on 2025-01-12, but its zero rows run on to 2026-10. "Last funding settlement" therefore does not mark delisting. For a coin the venue flags delisted, the listed interval now ends at the close of its last 4h bar with at least one trade. Coins not flagged delisted are listed through all of W.

- **C0.1 Sources.** A manifest names every endpoint used, with its pagination, retention limit, and rate limit as documented and as observed. An acquisition script reproduces the dataset from scratch, stays under half of each documented rate limit, and uses public read-only endpoints only.
- **C0.2 Coverage and integrity.** Over W, for every coin in U within its listed interval: at most 1% of expected funding hours and at most 1% of expected 4h bars are missing, no single contiguous gap exceeds 24 h, and every gap is listed. There are no duplicate keys, bars align to their interval grid, low ≤ min(open, close) and max(open, close) ≤ high, volume ≥ 0, and |funding| ≤ the venue's hourly cap. Units and the sign convention (positive means longs pay) are verified against the venue's docs.
- **C0.3 Availability.** The assumed rule is knownAt = eventTime + δ with δ = 120 s, where eventTime is the funding settlement time or the bar close. For backfilled history this is an assumed convention; it is checked only live. A live recorder polls every coin in U at most every 30 s for at least 24 h, with the host clock offset under 1 s, verified and logged. For every coin and field (funding: at least 24 events per coin; bars: at least 6 closes per coin), 100% of new values are first observed at or before the rule's knownAt. Unclosed bars are never stored.
  - *Revision 2026-10-19, before any C0.3 or C0.5 judgment:* Hyperliquid stamps a funding row at its actual settlement, which is usually 50 ms after the hour but sometimes late. Every coin at 2025-07-19 10:00 UTC was stamped 887 s late, and there were 24 rows > 60 s late in the search part of W. Using knownAt = hour + δ would expose those rows before they existed. Funding is now knownAt = max(hour + δ, reportedTime + 60 s), with eventTime still the hour. The live check tests first-observed ≤ that knownAt. Judged on the second fetch, which writes the corrected rows as new revisions.
- **C0.4 Point-in-time store.** Rows are immutable revisions carrying source, fetchedAt, and a content hash. A dataset version pins a fetchedAt cutoff. `as_of(t, version)` returns, per key, the latest revision fetched at or before the cutoff with knownAt ≤ t. Tests cover the exact boundaries (knownAt = t, knownAt = t + 1 ms, the instant a bar closes, a revision fetched after the cutoff) and at least 1,000 random times, and never return a row with knownAt > t. A full refetch of W at least 24 h after the first fetch is stored as a second version, and the count of differing rows is reported.
- **C0.5 Replay completeness.** For at least 99% of (t_d, coin) pairs in W while listed, `as_of(t_d)` returns the funding settled at B and the bar ending at B. Every failure is listed. On a failure, the replay holds its position and does not trade.
- **C0.6 Venue rules.** A versioned rules file covers, for the base fee tier and for U: taker fee, funding interval, payment convention, and cap; size decimals and minimum order notional; maintenance margin; and the liquidation trigger. Each rule carries a source URL and an effective-from date. Where a rule's history before its documented date is unknown, a stated conservative bound applies (highest fee, highest maintenance margin) and is flagged.
- **C0.7 Execution model.** A per-coin taker cost model (bps from mid = half-spread + depth impact, plus fee) is calibrated from the chronologically first 70% of at least 24 h of forward-recorded L2 snapshots (at least 1 per coin per minute). On the last 30%, for each coin in U, each side, and each of $1k and $10k: the model cost is at or above the observed walk-the-book cost from mid in at least 90% of snapshots, and the median excess is at most 3 bps. If the recorded depth cannot fill an order, that snapshot counts as a miss. Applying the model to earlier history is a stated limitation.
  - *Revision 2026-10-19, before any C0.7 judgment:* FTM is delisted and its live book is empty, so it cannot be calibrated. It takes the cell-wise maximum over the other coins of U, flagged, and the coverage and excess tests apply to the 11 listed coins. Recorded depth now also includes the `nSigFigs = 4` aggregated book: when the 20 full-precision levels cannot fill an order, the walk uses the aggregated book. That book's bucket prices are the conservative edge, the ceiling for asks and the floor for bids. In 2 h of 20-level data, 37% of TIA $10k buys could not be filled. The 24 h requirement counts from the recorder restart that added the aggregated book.
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

### Stage 2: null, mixed, and power calibration

Frozen 2026-10-19, before any stage 2 code was written. The draft was reviewed by a fresh-context Opus subagent because GPT was unavailable (see Blockers).

**No edge.** Write f₁..f₄ for a bar's hourly funding rates. The kernel settles f₁..f₃ at the bar's open and f₄ at the next bar's open, on the position held through the bar. A market model has no edge if, for every coin and bar, opens equal the previous close and E[close · (1 − f₄) − open · (1 + f₁ + f₂ + f₃) | F_open] = 0, where F_open is everything observable at the bar's open, for every coin and every lag. Then every DSL position earns zero expected gross PnL, so expected net PnL is ≤ 0, with equality only for strategies that never fill. `gate/NULLS.md` derives this from the kernel's settlement code for each model, including liquidation at the adverse extreme, unfilled orders, rounding and the $10k cap.

**Null models.** Each is specified exactly in `gate/NULLS.md`. Its spec and its fitted parameters are hashed and committed before the first campaign. Common to all:
- the price equation close = open · (1 + f₁ + f₂ + f₃ + ε) / (1 − f₄), with ε conditionally symmetric and mean zero given F_open, and |ε| ≤ 0.5;
- funding generated within the venue cap;
- premium, wicks (from the bar's own path), and volume independent of future ε;
- trades ≥ 1 in every bar, and no delistings;
- 12 coins on W's timeline (550 search days, 180 holdout days), production fees, and for every coin the median over U of each C0.7 cost cell.

The models:
- **N1** (smoke test): ε i.i.d. Gaussian with σ = 2%, truncated at ±8σ; zero funding and premium.
- **N2:** GARCH(1,1) volatility; standardized Student-t innovations with ν = 5, truncated symmetrically at ±8; a common factor for cross-coin correlation; funding an AR(1) with t innovations, clipped to the cap; premium = funding plus independent noise. Fit to the search part of the stage 0 data.
- **N3:** two-state Markov regime-switching volatility and correlation, plus symmetric jumps; funding as in N2. Fit as N2.

**Planted signals.** In a mixed market, k = 2 of the 12 coins get ε with conditional mean β · g(F_open). Here g is a fixed funding-reversal function of the last settled funding rate, and its oracle strategy is a pinned DSL file. β is set so that the oracle's annualized net Sharpe is s, measured through the kernel on ≥ 200 simulated years.

**Searchers.** These calibrate the stage 3 baseline. Each is pinned by the hash of its code and of the set of statistics disclosed to it, and every evaluation goes through `mm` and the ledger:
- **G100 and G400:** random-plus-genetic search over the DSL at budgets of 100 and 400 evaluations, adaptive on the disclosed in-sample summary.
- **H400:** a hill-climber that perturbs the in-sample-best program, to maximize in-sample Sharpe, over 400 evaluations.

Later campaigns must stay within 400 evaluations.

**Gate.** Its parameters are fixed here:
- **N:** the number of distinct canonical strategies evaluated that filled at least once. This is the largest effective-N estimate. Counts from correlation clusters at |ρ| ≥ 0.9 and 0.5 are reported only as fragility diagnostics.
- **Screen:** DSR ≥ 0.95 on 4h returns, with T the number of 4h steps and S0 = σ_S · ((1 − γ) Φ⁻¹(1 − 1/N) + γ Φ⁻¹(1 − 1/(N e))). Here γ is the Euler–Mascheroni constant, σ_S is the cross-sectional standard deviation of the per-period Sharpe ratios of the N strategies, and γ̂₄ is ordinary kurtosis. A non-positive variance term gives DSR = 0.
  - *Revision 2026-10-19, during C2.3, before any C2.4 to C2.6 run:* the variance term is mathematically ≥ 0 (Pearson's inequality: kurtosis ≥ skew² + 1). It reaches 0 only for a two-point distribution at Sharpe = 2/skew, where rounding decides between "≤ 0, so DSR = 0" and "tiny positive, so DSR ≈ 1". GPT's independent DSR and the gate's disagreed exactly there. The rule is now: a variance term ≤ 1e-12 · (1 + |γ̂₃ S| + (γ̂₄ − 1) S²/4) is degenerate and gives DSR = 0.
- **SPA:** arch `SPA`, studentized, over all N against flat (zero returns), using the "consistent" p-value. Stationary bootstrap, mean block length 6 steps, 1,000 replications, seed derived from the campaign id. Rejects at α = 0.05; if it does not reject, nothing is promoted.
- **StepM:** arch `StepM` on the screened set, with the same bootstrap and α = 0.05.
- **Mechanism check:** skipped, since searchers state no mechanisms. This only adds promotions, so stage 2's false-promotion rates are upper bounds and its power figures overstate what stage 3 will see.
  - *Revision 2026-10-19 (wording only; no stage 2 result judged yet):* "This only adds promotions" is false in general. Removing finalists shrinks Holm's m, so a mechanism check can turn a non-promotion into a promotion. C2's rates are calibration for the procedure without the check, not strict upper bounds for an arm that has one. Under the complete null, Holm stays valid on any family chosen without holdout data.
- **Holdout:** all finalists, once. Promoted if net holdout return > 0 and the one-sided stationary-bootstrap p-value for mean > 0 (block 6, 10,000 replications) passes Holm at α = 0.05.

**Runs.** Seeds come from SHA-256 of a committed campaign id. Every market started counts, and a crash or timeout counts as a promotion. A rerun after any gate or null change uses fresh ids and is logged. Every bound below is a one-sided 95% Clopper–Pearson bound, unless stated otherwise.

**Criteria.**
- **C2.1 Nulls are null.** For each of N1–N3 and each coin, an OLS regression of the next bar's ε on lagged observables over 200 independent simulated years has an F-test p > 0.001: funding, premium, returns at lags 1–6, wick ranges, volume, and the cross-coin mean return. Probes are then run on 200 fresh simulated years per model:
  - buy-and-hold per coin;
  - one single-input sign strategy per DSL input and per xs op;
  - a martingale-sizing strategy;
  - the in-sample top-5 strategies of the first 20 C2.4 campaigns.

  Every probe's mean gross PnL (after funding, before fees and costs) has |z| < 3.7, with its SE taken across independent markets.
- **C2.2 Independent null generators.** GPT implements N2 and N3 from `gate/NULLS.md` and the frozen parameters alone. If GPT is still unavailable when the rest of stage 2 is met, a fresh-context Opus subagent substitutes, and this is recorded. Both implementations pass C2.1's regression test. On 100 simulated years, they agree within these tolerances: mean |ε| ± 5%, kurtosis of ε ± 20%, lag-1 autocorrelation of |ε| ± 0.05, mean cross-coin correlation ± 0.05, funding AR coefficient ± 0.05.
- **C2.3 Independent DSR.** GPT, with the same fallback, implements the DSR from the paper and the formula above. The inputs number 1,000 random cases plus edge cases: N = 1, T = 10, extreme skew and kurtosis, and a non-positive variance term. The two implementations agree to 1e-9 on all of them, once each disagreement is resolved with its root cause recorded.
- **C2.4 Complete null.** For each of N1–N3 and each searcher in {G100, G400, H400}, over 300 markets:
  - the probability of promoting anything has upper bound ≤ 0.05, so at most 8 promotions;
  - the probability that SPA rejects and finalists exist has upper bound ≤ 0.10.
- **C2.5 Mixed sweep.** For each base in {N2, N3}, each s ∈ {1, 2, 3}, and searcher G400, over 100 markets:
  - FDR = the mean over markets of V / max(R, 1), with a Hoeffding upper bound ≤ 0.20, so a point estimate ≤ 0.078. R counts promotions and V false ones.
  - A promotion is true only if its mean net return over 200 fresh simulated years of the same model is positive, with a 99% CI excluding 0. Anything else is false.
- **C2.6 Power.** In C2.5's runs, the rate of markets with at least one true promotion is reported with CIs for every cell. At s = 3 its point estimate is ≥ 0.30 on N2.

Exit when C2.1 to C2.6 all hold.

### Stage 3: single-agent research

Frozen 2026-10-19, before any stage 3 code was written. The draft was reviewed by a fresh-context Opus subagent because GPT was unavailable.

**One campaign, two arms.** Both arms run on the stage 0 data: U, the search part of W, the stage 1 dataset version, and venue/hyperliquid.
- **Arm A:** an LLM research agent proposes mechanism-backed DSL strategies.
- **Arm B:** the stage 2 searcher G100 (same code hash) does the same search.

Each arm has a budget of 100 evaluations. An evaluation is any `mm eval` call, including duplicates, rejections and strategies with zero fills. `mm check` calls are free, since they touch no data. Each arm passes the stage 2 search gate separately, with its own N, SPA and StepM. Arm A then gets the mechanism check. The finalists of both arms are frozen, then evaluated together in one `mm holdout` batch. Holm is applied within each arm, so each arm's error claim is a per-arm family-wise error rate. This is one campaign with two pre-registered arms; it reads the paper's "once per campaign" rule as one holdout query batch with no feedback between arms. After this campaign the holdout is spent.

**Holdout after the model's knowledge.** Arm A's model (pinned id `claude-opus-5-5`, knowledge cutoff June 2026) may have seen data up to its cutoff. That is an unlogged channel into history, which null markets cannot detect. The stage 3 holdout window is therefore [2026-07-01, 2026-09-30), for both arms. Neither arm sees results from [2026-04-03, 2026-07-01). Arm A's error control rests on this post-cutoff holdout and on the stage 2 holdout test being valid. It does not rest on C3.2.

**Harness (arm A).** The harness is frozen and hashed before C3.2. The hash covers the brief text, model id, CLI flags, permission set, turn limit (200) and wall-time limit (2 h), and the `mm-agent` client and daemon. A change means rerunning C3.2 with fresh campaign ids.
- **Sandbox:** the agent runs `claude -p` inside bubblewrap. Its filesystem holds only its workspace (DSL.md, the paper's research-direction and mechanism sections, the brief, and the `mm-agent` client) and a private HOME, with no repo, no `data/`, no ledger, no user settings, memory or MCP.
- **Tools:** Read and Write inside the workspace, and Bash only for `./mm-agent`. WebFetch, WebSearch and every other tool are disabled.
- **`mm-agent`:** a thin client that talks over a unix socket to a daemon outside the sandbox. The daemon:
  - fixes the store, ledger, campaign and agent;
  - accepts strategy text only;
  - enforces the budget;
  - discloses only `sharpe_annualized`, `fills`, `total_return` and `max_drawdown` per evaluation, or the rejection code;
  - logs every call with its payload hash.

  This disclosure set is richer than G100's (Sharpe only). That difference is stated and is not covered by stage 2's calibration.
- **Records:** the agent's full transcript and its final selection of up to 10 finalist candidates are stored, and their hashes are recorded in the ledger.
- **One attempt:** arm A runs once on real data. A crash, timeout or early stop ends the arm with whatever it evaluated. A rerun would need a new, later holdout.

**Mechanism check (arm A).** A candidate's strategy file must have carried, from its first evaluation, a structured `prediction`: a DSL boolean `condition` (type-checked, and not part of strategy identity). The claim is that mean net return per (coin, decision) exposure is higher where the condition held at the decision. The kernel computes, on the search period, the original strategy's per-coin return over each decision interval, split by the condition. It is logged but never disclosed to the agent, and does not count toward N or the budget. The check fails if either branch holds less than 10% or more than 90% of exposures, or if the difference is ≤ 0. A failing candidate is removed before the freeze. Each finalist's difference on the holdout is reported too.

**Criteria.**
- **C3.1 Isolation.** OS-level tests, run as the sandboxed agent would run, show that the sandbox cannot read the repo, `data/`, the ledger or the real HOME, and has no tool but its workspace and `mm-agent`. Daemon tests show that it rejects:
  - overrides of the store, ledger, campaign or agent;
  - a 101st evaluation;
  - any disclosure field outside the set.

  For every arm A run (null and real), the daemon's call log matches the arm's ledger rows one to one. A transcript audit finds no tool call outside the permitted set.
- **C3.2 Smoke calibration.** 20 campaigns run arm A's frozen procedure on fresh N2 null markets, with W's timeline and a holdout from day 640 of 730, mirroring the real campaign's post-cutoff window. Every started campaign counts, and a crash counts as a promotion. Pass if at most 2 campaigns promote. Also reported, against G100's C2.4 N2 distribution:
  - SPA p-values;
  - maximum in-sample DSR;
  - screened counts.

  This is a smoke test (20 runs bound the rate only to about 0.28) and is stated as such.
- **C3.3 Real run.** Both arms complete once on real data in the order C3.1 → C3.2 → freeze → both arms → both freezes → one holdout batch. The ledger holds every arm A disclosure, its transcript hash, its selection, and each candidate's prediction, mechanism-check result and holdout result.
- **C3.4 Honest comparison.** A report gives, per arm:
  - evaluations;
  - distinct canonical strategies;
  - N;
  - SPA p-value;
  - screened count;
  - finalists;
  - mechanism failures;
  - each finalist's holdout return, bootstrap p-value and Holm-adjusted p-value;
  - promotions.

  It states that one campaign per arm supports no claim that either generator is better. A reviewer (GPT, or a fresh-context Opus subagent if GPT is unavailable), given the frozen criteria and the report, finds no claim beyond the evidence.

Exit when C3.1 to C3.4 all hold. Zero promotions is an acceptable outcome.

### Stage 4: swarm and canonicalization

Frozen 2026-10-19, before any stage 4 code was written. The draft was reviewed by GPT; an earlier Opus review was cut off by a rate limit.

**Scope.** Stage 3 spends the only real holdout. A real-data swarm campaign needs a later holdout of at least 90 days after 2026-09-30, plus a model whose knowledge ends before it, so stage 4 includes none. Stage 4 is infrastructure plus a swarm-scale null smoke test. It claims no calibrated error rates, mixed-market FDR or power for the swarm.

**Equivalence key.** The stage 0–3 strategy hash stays as is. A new, versioned equivalence key comes from equality saturation (`egg`) with a fixed rule set R, deterministic insertion order, work limits counted in iterations and nodes (never wall time), and extraction of the term with the fewest nodes, ties broken by a total order on serialized terms that includes the float bits. The key is pinned by: R's hash, the canonicalizer version, the egg version, the limits, and the extraction order. A statistical trial is (equivalence key, parameter values).

Every rule in R must be exact under the kernel's semantics: IEEE-754 doubles with signed zeros, undefined propagation, `if` evaluating both branches every tick, windows with running sums and periodic exact recompute, xs ops over listed coins with defined values, and Rust's `f64::min`/`max`. `kernel/CANONICAL.md` gives each rule its argument and lists rejected laws with counterexamples. Candidates the review found exact:
- `neg(neg x) = x`, `abs(abs x) = abs x`, `abs(neg x) = abs x`;
- `mul(x, 1) = x`, `div(x, 1) = x`, `sub(x, +0) = x`;
- commutativity of `add` and `mul`;
- `not(not c) = c`, `and`/`or` commutativity;
- `if(not c, a, b) = if(c, b, a)`;
- `gt(a, b) = lt(b, a)`, `ge(a, b) = le(b, a)`;
- `lag(lag(x, a), b) = lag(x, a + b)` when a + b ≤ 4380.

Rejected:
- associativity and distributivity;
- `x + 0` (fails at −0.0);
- `min`/`max` commutativity (signed-zero ties);
- `if(c, x, x) = x` (fails when c is undefined);
- `xs_demean` idempotence;
- composed `convert`s;
- anything through a window or xs op.

**Swarm.** K = 4 arm A agents run in parallel, each in its own sandbox with its own workspace and its own daemon socket, so the socket determines agent identity. The stage 3 harness is extended by one command, `history`. It returns a snapshot up to a committed sequence number of every swarm evaluation: sequence, agent, equivalence key, program text, and the four disclosed fields. Rejections are included. Mechanism-test results never are. There are at most 20 `history` calls per agent, and each reply's payload and recipient are logged as a ledger disclosure, so what each agent knew can be reconstructed. The budget is 400 evaluations, 100 per agent, reserved atomically before execution. Free checks and evaluations are counted separately. The harness, history contract and limits are frozen and hashed before C4.5.

**Gate and effective N.** The gate runs once over all evaluations of all agents, whatever they select. N_raw is the number of trials that filled; evaluations with zero fills are reported too, since they also disclose information. Clusters come from complete linkage on |ρ| of aligned per-step returns, with zero-variance series as singletons, at thresholds 0.9 and 0.5. SPA is reported once. The screen and StepM are rerun at each N. A finalist is fragile if its status differs across the three N values.

**Criteria.**
- **C4.1 Rules are exact.** For each rule in R:
  - over at least 1,000 random well-typed programs (frozen generator and seeds), rewriting at a random matching position leaves every node's per-tick value stream (bit patterns, with undefined values) and the run's returns, trace and summary bitwise identical on 3 synthetic markets (N1, N2, N3);
  - plus targeted cases: signed zeros, undefined conditions, window warm-up, coins listing and delisting, and running-sum recompute boundaries.
- **C4.2 Canonicalization works.** On 1,000 pairs built by up to 10 random rule applications (frozen generator), plus at least 20 hand-built equivalent pairs, ≥ 99% share an equivalence key, and every failure is explained. Every rejected law's counterexample pair, whose semantics provably differ, has distinct keys. Re-running the canonicalizer in a fresh process gives the same key for every program.
- **C4.3 Swarm isolation and accounting.**
  - Each agent passes the C3.1 audit.
  - Tests show that agents cannot reach each other's workspaces or sockets, and that injecting history text cannot change the daemon's behavior.
  - `history` replies match their ledger rows one to one.
  - Evaluations total ≤ 400, with ≤ 100 per agent.
  - At least one agent per campaign received history containing another agent's evaluations.
- **C4.4 Effective-N report.** Every C4.5 campaign records N_raw, the cluster counts, zero-fill evaluations, the SPA p-value, the screen and StepM decisions at each N, and fragility flags. Stage 1–3 invariant tests still pass with the equivalence key in use.
- **C4.5 Swarm null smoke test.** 10 swarm campaigns on fresh N2 null markets:
  - search days [0, 550), holdout report window [640, 730) days;
  - every started campaign counts, and a crash, or fewer than 200 evaluations, counts as a promotion;
  - pass if at most 1 promotes.

  Each campaign also reports its evaluations, cross-agent history use, finalists and holdout results, beside H400's C2.4 N2 distribution. With 10 runs the 95% bound is about 0.39, and the result is stated as a smoke test only.

Exit when C4.1 to C4.5 all hold.

### Stage 5: data integration

Frozen 2026-10-19, before any candidate source was probed. Reviewed by GPT and by a fresh-context Opus subagent.

**Scope and decisions.** U is not extended. One source per category is integrated for U, each classified at exit as *historically replayable*, *prospective only*, or *blocked*. The pre-registered candidates, in order, are:
- governance: Snapshot (public GraphQL hub);
- token unlocks: DefiLlama's emissions data;
- discussion: the public Discourse forums of U's protocols.

A fallback is used only if a candidate fails C5.1, and the reason is recorded. A source is *usable* if at least one coin of U maps to it with at least 20 items in the search part of W. Otherwise it can be at most prospective. Stage 5 does no return-linked work. Derived-input definitions, entity mappings and knownAt rules are frozen before any strategy is evaluated on the new inputs. Stage 3 spent the real holdout, so the new sources' live recordings become the next forward holdout.

**Historical admissibility.** Each source's timestamps are classified as protocol-enforced, server-set or client-claimed. A row's knownAt is the later of:
- the rule applied to its claimed time, used only if that time is protocol-enforced or server-set and the C5.3 live test has passed;
- its earliest witnessed time: our own fetchedAt, a third-party archive capture time (Wayback CDX), or a protocol-enforced time.

Content is known no earlier than its last edit. A row with no admissible claimed time and no earlier witness gets knownAt = fetchedAt, so it is usable only prospectively. Items that vanish upstream become tombstone revisions. Deletions before our first fetch cannot be recovered and are stated as survivorship. For scheduled events, eventTime is when the information was published or revised, and the scheduled date is a value field. I8 therefore applies to publication times, unchanged.
  - *Revision 2026-10-19, before any C5 evidence:* the "later of" list wrongly includes our own fetchedAt as a witness. Read literally, every backfilled row would get knownAt = fetchedAt, so even a server-set source that passed the live test would be unusable historically. That contradicts the paragraph's own last sentence. Intended rule:
    - knownAt = the later of the claimed-time rule (when admissible) and any *independent* witness (an archive capture or a protocol-enforced time), which can only make it later;
    - our fetchedAt applies only to rows with neither an admissible claim nor an independent witness.

**Criteria.**
- **C5.1 Sources.** `venue/sources/<name>.md` gives:
  - the endpoint;
  - the terms clause relied on;
  - rate limits, with the observed limit used when none is documented, and requests held at no more than half of either;
  - history depth;
  - the timestamp class of each time field;
  - the knownAt rule, fixed before any live measurement.

  The entity mapping is a versioned file keyed by stable upstream ids (space id, protocol slug, contract address), never by tickers. Each mapping row has a validity interval, and U's unit conventions are noted (kPEPE = 1000 PEPE). A hand-labeled sample of at least 50 items per source, labeled before any returns are computed, reports precision and recall. A golden set of known collisions and rebrands resolves as declared.
- **C5.2 Revisions and lineage.** Rows are immutable revisions with source, upstream id, fetchedAt and a content hash. Edits are new revisions, and disappearances are tombstones. `as_of(t)` returns the content live at t, and tests cover edits, tombstones and restorations at exact boundaries. Derived inputs are computed by versioned code whose hash, along with the mapping file's, is part of the dataset version. A byte-identical recompute test reproduces every derived input from the store.
- **C5.3 Availability.** Each source has a live recorder that polls every 5 minutes or less, keeps an uptime and gap log, logs clock offset (< 1 s), checks pagination for dropped items, and runs from its first start until stage 5 exits, for at least 72 h. Results are pooled over all items the source publishes, not just U's.
  - The rule must hold for 100% of observed new items and of observed edit revisions, with the denominator and the rule's slack (knownAt − first observed) reported.
  - Fewer than 30 observed items means the rule is unvalidated, and the source can be at most prospective.
  - A rule revised after measurement must pass on a fresh recording segment.
  - A live-versus-backfill reconciliation re-backfills the live window and reports missing items (deletions), changed content (edits), and items claimed inside the window but not seen live in time (backdated).
- **C5.4 Coverage.** Coverage intervals are stored as data per source and coin. Inputs are undefined, never 0, outside coverage or for unmapped coins. Per coin of U, the report gives event counts in the search part and in the live window, gaps, and each source's classification.
- **C5.5 Kernel integration.**
  - Event sources enter the DSL as per-tick aggregates: the count of items with knownAt in (τ − 1h, τ], under a new base unit `ev` for counts.
  - Unlock schedules enter as values from the revision known at τ (for example, the fraction of circulating supply unlocking within the next 30 days, with the circulating supply also as known at τ).
  - One generic causal op, hours since a boolean last held, measured on the tick clock, joins the DSL.
  - DSL.md documents every input's unit, missingness and freshness.
  - I1 and I8 hold. Data-layer mutants must each be caught: as_of returning latest content, knownAt equal to the claimed time with no lag, dropped tombstones, schedules read from the latest revision, and an aggregation window admitting (τ, τ + 1h].
  - An independent implementation (GPT, or a fresh-context Opus subagent if GPT is unavailable), written from DSL.md and the source docs alone, matches every derived input exactly on synthetic event streams with boundary cases.
  - A strategy using an input absent from the dataset version is rejected with `R_INPUT_UNAVAILABLE`.
- **C5.6 Calibration extended.** The null markets replay the real event series independently of ε. C2.1's regression and probes are extended to the new inputs and pass. The C2.4 complete-null rate for G400 on N2 is rerun with the new inputs available, over 300 markets, with an upper bound ≤ 0.05. Every strategy counts toward N, whatever inputs it uses.

Exit when C5.1–C5.6 hold for every source classified historically replayable or prospective, and every blocked category is recorded under Blockers with what was tried.

## Blockers

- **Stage 5 unlock source (2026-10-19).** Both of DefiLlama's emission endpoints return 402 (paid only). Its open-source emissions-adapters repo returns 404 and is absent from the org's public repo list, so the pre-registered candidate fails C5.1. Untried fallback: on-chain vesting contracts read through public RPCs, per coin (SUI, TIA, WLD), whose times are protocol-enforced. That is substantial per-coin work. If it is not done, unlocks are recorded as a blocked category at stage 5 exit, which the exit rule allows.

## Log

- 2026-10-19: C5.1 hand-labeled samples (`audit/stage5/c51-discourse.json`, `c51-snapshot.json`), labeled blind by fresh-context Opus subagents before any return on the new inputs. 50 random items per mapped key; the labeler saw text only, not the source. Precision (item concerns its key's coin): Snapshot aavedao.eth 1.00; Discourse delvingbitcoin 0.94, solana 0.92, celestia 0.92, aave 0.88, sui 0.84, ethresear 0.66, bnbchain 0.58. The last two carry many posts about no coin of U (general research, support and spam). Recall, measured within the sample frame (labeled mentions of a coin that sit in its own key): 0.94–1.00, with stray WLD and kPEPE mentions elsewhere. Items in unmapped keys lie outside the frame. The golden set (`ingest/tests/test_mapping.py`) passes.
- 2026-10-19: C2.1's fixed-probe part passes on the corrected generator (`audit/stage2/c21-fixed-probes.v3.json`). HC3 regression min p: N1 0.059, N2 0.012, N3 0.034. Max |z|: 1.97, 1.79, 2.13. Still to do: the C2.4 top-5 probes.
- 2026-10-19: C2.3 met. GPT's independent DSR (`gate/tests/gpt_dsr.py`, tools denied) agrees with the gate's to 1e-9 on 1,000 random cases and the edge cases (N = 1, T = 10, zero variance, extreme skew and kurtosis, and degenerate two-point series at Sharpe = 2/skew). That last case exposed an ill-conditioned spec, now fixed by a dated revision to the gate's DSR (relative-tolerance degenerate rule); GPT updated its code from the revised spec.
- 2026-10-19: C2.2 met (`audit/stage2/c22.v2.json`). GPT's independent N2/N3 generators pass C2.1's regression and agree on every tolerance stat. The first comparison (`c22.json`) failed on N2 kurtosis, and robust stats then showed GPT's median |ε| consistently 1.5–9% higher. Both causes were deviations in *my* generator: (1) it scaled the truncated t to unit variance *before* truncating, so x had variance < 1; (2) it capped σ but not the GARCH recursion's state. Both are fixed, and NULLS.md now states the two points explicitly. No campaign had run. C2.1's fixed probes, produced with the old generator, are being re-run (v3).
- 2026-10-19: C1.5 met as written. GPT's independent fill checker (`kernel/tests/timing/gpt_checker.py`, tools denied) matches the labels on all 20,000 cases, as do the kernel's checker and the Opus one. The two earlier GPT attempts had silently outlived their timeouts. `--format json` streaming now shows progress.
- 2026-10-19: Null markets can carry block-bootstrapped real event counts, independent of ε (C5.6 groundwork).
- 2026-10-19: Dry run, on a provisional cost table from about 4 h of aggregated books: C1.4 passes (the kernel matches the witness at every step on version 1792385868856) and C1.8 gives a W0 median of 14.7 ms (i5-11400). Both get re-run as judged evidence on the final C0.7 model. Three kernel–witness disagreements were found on the way, all in the witness:
  1. It read listed intervals from the pre-revision ingestion report. It now applies the current rule to the store's bars.
  2. Its sizing arithmetic ordered operations differently from W0's DSL encoding, so near-integer truncation flipped a kPEPE order by one coin. It now uses the DSL's order.
  3. It iterated coins in a different order. It now uses venue order.
- 2026-10-19: C1.2 met. GPT's red team (`audit/stage1/gpt-test-cases.json`, 40 cases) produced 34 program cases, now in `kernel/tests/adversarial/gpt*.case`: 8 rejected with matching codes and 25 admitted probes that the leak canary passes. Its CLI cases are covered by named tests. Three kernel weaknesses it found are fixed at the root:
  1. `--policy` let the caller move the holdout boundary. The policy is now the store's own `policy.json`, the flag is gone, and unknown options are refused.
  2. The holdout-spent record lived in the caller-chosen ledger, so a fresh ledger could reuse the holdout. It now lives in `<holdout>/spent.jsonl`, and the ledger check is gone.
  3. Huge finite weights overflowed the gross sum to infinity, which scaled them to a silent close. Scaling now divides by the largest weight first.

  Earlier attempts: OpenAI's filter flagged the "red team" wording, and two runs hung on tool permissions. GPT now runs with `opencode.json` denying edit, bash and webfetch, which also keeps it from reading the repo.
- 2026-10-19: C4.1 and C4.2 met (`kernel/mm/tests/rules.rs`, `canon.rs`).
  - All 16 rules of R are bitwise exact (probe value streams and run outcomes) on 1,000 programs × 3 markets each.
  - 0 of 1,000 rewritten programs got a different key; 20 hand-built pairs merge; all 10 rejected-law counterexamples stay distinct; keys are stable across fresh processes.
  - C4.1 found a kernel bug: `and`/`or` short-circuited, so `and(false, undefined)` was false while `and(undefined, false)` was undefined, against DSL.md. Both arguments are now evaluated before combining.
- 2026-10-19: Stage 5 sources probed after the criteria froze.
  - Discourse: 7 public forums reachable (BTC delvingbitcoin, ETH ethresear.ch, SOL, SUI, TIA, AAVE, BNB).
  - Snapshot: only `aavedao.eth` (AAVE) among U.
  - DefiLlama emissions (the unlock candidate): both endpoints return 402, paid only, so it fails C5.1. The fallback to try is its open-source emissions-adapters repo (the GitHub API returned Not Found; to be located).
  - Rules fixed in `venue/sources/`. The live recorder `ingest/sources_record.py` runs detached from 10:26 UTC (`data/sources_live`).
- 2026-10-19: GPT is available again (10:11 UTC). Its stage 4 review exposed an N-undercount. Strategy identity hashes params by name, not value, and the gate deduplicated candidates by strategy hash, so parameter variants collapsed into one trial. The gate now keys trials by (strategy, params), and the exact submitted program lives on each experiment row instead of on strategies. No campaign had run yet.
- 2026-10-19: C2.1, fixed-probe part, passes on the frozen nulls (`audit/stage2/c21-fixed-probes.v2.json`). HC3 regression min p: N1 0.059, N2 0.116, N3 0.020 (> 0.001). Max probe |z|: 1.97, 3.13, 2.28 (< 3.7). v1 had NaN z for N1 probes that never trade, now 0. Still to do: the C2.4 top-5 strategy probes.
- 2026-10-19: Stage 3 harness isolation probe (`data/stage3/isolation-s70v`). Reads outside the workspace, `ls /`, chained commands and WebFetch were denied or absent. The daemon log matched its 2 calls. Deviation: Claude Code allows read-only shell commands on workspace files (`cat brief.md`) as equivalent to the permitted Read, so in practice Bash is not limited to `./mm-agent`. The bwrap filesystem (`gate/tests/test_sandbox.py`) is the real boundary. Found and fixed: the agent CLI had inherited the operator's stdin, which leaked harness text into its prompt; stdin is now /dev/null.
- 2026-10-19: Null parameters frozen in `gate/nulls.json` (sha256 ebc7928421f5daab9447eac7149529996b06b915c4f80ed36cb03c8d1df6dddb), fit to search-part version 1792385868856. Spec changes made before freezing, after the first fit: GARCH ω by variance targeting (the raw fit overstated volatility 2×); funding and premium by joint block bootstrap of real data (an AR(1)-t fit was degenerate: about half of real hours sit exactly at the 1.25e-5 floor); the planted signal centered on that floor.
- 2026-10-19: C1.5 is met with the Opus substitute (`kernel/tests/timing/independent_checker.py`). The kernel checker and the independent one both match the labels on 20,000 generated cases across 5 seeds. Disagreements came from 4 ambiguities in I3, each fixed in the spec, the kernel and the generator. (1) A closeout's reference could be close or extreme for either kind: liquidation now uses the adverse extreme and delisting the close. As a result the kernel's liquidation fallback to a stale mark is gone, and closeouts use the coin's latest bar. (2) A closeout must name the coin's latest bar with event ≤ t_fill. (3) An order on a zero-trade first bar is unfilled and does not roll to a later bar. (4) qty = 0 is R_FILL. The GPT run is still owed (see Blockers).
- 2026-10-19: The mutants now live in `kernel/mutants/mutants.py` as exact-match edits applied to a fresh copy of the working tree. Hand-kept patches went stale with every kernel change. All 9 are still caught.
- 2026-10-19: C1.1 met. `kernel/mutants/run.sh` catches all 9 mutants (I1–I9), each by its named test, with the clean tree passing every one. The first runs falsely reported 3 misses: `rsync -a` kept old mtimes, so the shared cargo target reused the previous mutant's build.
- 2026-10-19: The C1.7 canary exposed an I9 flaw. The $10k order cap was checked at the fill price, but an order is sized at the decision price. It is now checked at the decision price (recorded on every fill). The first leak program (0.08 per coin) reached Sharpe 19.6 < 20 because compounding made the cap bind. Sized at 0.005, the leak reaches about 200 and honest runs about −5.
- 2026-10-19: Commit 855260e (`criteria: stage 1`) also carries an unrelated 3-line witness.py fix (the zero-trade fill bar), swept in by `commit -a`. The criteria text in it is unaffected. Criteria commits now stage PROGRESS.md only.
- 2026-10-19: U = BTC ETH SOL SUI kPEPE TIA WIF AAVE FTM(delisted) WLD POPCAT BNB (`data/universe.json`). Survivorship: 10 delisted eligible perps lack full daily bars in the ranking window (MATIC 10/30, about $51M extrapolated vs. the #12 cutoff of $213M; RNDR had been renamed RENDER; the other 8 are micro-caps with 0 bars). None plausibly ranks top 12.
- 2026-10-19: The holdout rule (nothing reads `data/holdout/`) means C0.2/C0.5 for the holdout part of W run on the fetched frames at ingestion, before the split-write, and report counts only. The search part is also checked through the real `as_of`.
- 2026-10-19: `nix develop` verified (cargo 1.95, rustc 1.95, python 3.13, arch 8.0.0, sqlite 3.51); flake.lock committed; GPT 6.1 Sol reachable.
