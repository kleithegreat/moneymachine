# PROGRESS

## Now

Scope: stages 0 to 10 (paper revision 5); stage 11 is a human decision. Stages run in parallel wherever work does not depend on a wait. Every command is `nix develop -c python -m cli <command>` (`-h` lists them). Criterion checks are tests in `criteria/` over the evidence committed under `audit/`; they skip until the evidence exists. Detached processes (kill by PID only): `pgrep -af "ingest.record"` (HL live recorder), `pgrep -af sources_record` (stage 5 recorder).

Order while waiting on recording windows (human, 2026-10-20): (a) behavior-preserving cleanup, finished before the first judged run that records a kernel or harness hash (C1.4, stage 2 sweeps, the harness freeze); otherwise it waits until stage 5 exits; (b) stage 10, the thesis track; (c) stage 6, the reference kernels. Stages 7 to 9 start after stage 5 exits.

- **Cleanup (a):** done. Every step was byte-identical on a fingerprint of seeds, genomes, null markets, written stores, kernel, holdout and mechanism results, traces and check codes, and all 14 mutants are caught.
- **Stage 0, from 2026-10-21 00:20 UTC** (the judged 24 h window after the 00:19:10 restart, unless a gap restarts it; `python -c "from ingest.availability import window; print(window('data/live'))"` shows it):
  - `availability data/live audit/stage0/availability.json` (C0.3);
  - `execution data/live venue/hyperliquid/execution.json audit/stage0/execution.json` (C0.7);
  - stop the HL recorder (by PID) so the second backfill has the rate budget alone, then `backfill data 200` (C0.4; its report in `audit/stage0/` is the judged C0.2/C0.5 evidence), then restart the recorder as a regime diagnostic and report the frozen cost model's coverage on each later recorded day;
  - `witness data <version> data/witness.jsonl > audit/stage0/witness.json` (C0.8);
  - `holdout-hashes data audit/holdout.json` (C0.9);
  - `pytest criteria/test_stage0.py`.

  Failing stage 0 is an acceptable outcome. The criteria are judged as written, never reread to pass, and a failure of C0.2, C0.3 or C0.5 means the exit rule: stop and pre-register a different family.
- **Stage 1:** done except C1.4 and C1.8, which follow C0.7 (both already pass a dry run on provisional costs).
- **Stage 2:** nulls frozen; C2.2 and C2.3 met; C2.1's fixed probes pass (v3). The locked holdout calibration v1 failed (sparse cells at 0.05, see the Log). Redesign v2 (sparser development cells, an activity floor, locked suite v2) is drafted and under GPT review; after its one revision it is committed as a stage 2 revision, then the v2 development cells, then the v2 locked run, all before any sweep. After C0.7 and a passing locked run: record the searcher hash, then `sweep null`, `betas`, `sweep mixed`, `truth`, `probes-top5 audit/stage2/c21-top5.json`, `sweep-summary audit/stage2/sweeps.json`.
- **Stage 3:** built. After C0.7: `freeze-harness` (commit `audit/stage3/harness.json`), `agent-null agent 20` (paced one campaign per 5 h, resumable), `agent-summary agent audit/stage3/null-summary.json`. Once stage 2 exits: `agent-real data <version>` (C3.3, C3.4, to `audit/stage3/real.json`), then the reviewer.
- **Stage 4:** C4.1 and C4.2 done; C4.3's isolation and injection tests pass (the per-campaign parts are judged on C4.5's runs). After the harness freeze, and after the stage 3 null series so the two never share a subscription window: `agent-null swarm 10`, `agent-summary swarm audit/stage4/null-summary.json`.
- **Stage 5:** C5.1, C5.2's store and recompute tests, and C5.5's independent derivation and mutants are done. C5.6's code is ready. At ≥ 72 h of recording (2026-10-22 10:26 UTC):
  - `sources-availability data/sources_live > audit/stage5/sources-availability.json` (C5.3);
  - `sources-backfill data`, then `sources-reconcile data data/sources_live <backfill version>`;
  - `events data <version> data/sources_live admitted|prospective` (Discourse), and `… prospective snapshot`;
  - `sources-coverage data <version> data/sources_live admitted|prospective` (C5.4).
  - After stage 2 exits, if Discourse is admitted: `probes audit/stage5/c56-probes.json data <version>` and `sweep events data <version>` (C5.6). If it is prospective only, its counts all lie in the forward holdout, so the search part has none to replay and C5.6 is vacuous for it.

  Snapshot is prospective only (client-claimed time). Unlocks: blocked (see Blockers).
- **Stage 10 (b):** criteria frozen. Built and tested: positions (C10.3 fixtures), registration and ledger (C10.1), retrieval proxy, daemon and client (C10.2), scoring (C10.4 met: GPT's independent scorer agrees on 1,000 sets), harness, runner, report. Next, after the stage 0 window (the venue is the recorder's until 2026-10-21 00:30 UTC) and C0.7's `execution.json`:
  - one dry main session under a scratch data root to check the harness end to end (not counted), and `harness.audit` checked against a real transcript;
  - then `thesis-freeze` (commit `audit/stage10/manifest.json`; C10.5's 28 days start), and `thesis-run` detached;
  - `thesis-report audit/stage10/report.json` at exit, plus the GPT reviewer.

  The thesis adapter takes 120/min. When the HL recorder restarts as a regime diagnostic, give it at most 480/min so the total stays at half the documented limit.
- **Stage 6 (c):** criteria frozen, with the C6.4 per-kernel revision. Lean v4.34.0 and Bend 2.0.37 are pinned. `reference/SEMANTICS.md` is drafted against mm's source, with measured details: min/max ties return the first argument, and sums are left folds from −0.0.
  - **The Lean model** (`reference/lean`) has a strict JSON front end and checker, the machine and the simulator over an abstract number structure, and a binary64 executable `refmm`.
    - Its verdicts agree with `mm check` on all 372 checked programs.
    - Its runs agree bit for bit with `mm` on 31 programs over 120 days. `reference/mmdump` links mm as a library to export the resolved market and the trace.
  - **Laws** (`Ref/Laws.lean`, frozen, with two dated revisions: L4's liquidation reference and L1_simulator's step range). Proved, with `#print axioms` ⊆ {propext, Classical.choice, Quot.sound}: L5_binding, L2_checker, L1_simulator, L1_values. The frozen definitions live in `Ref/Spec.lean` (moved verbatim from `Laws.lean`, which now holds only the statements and proofs). Proof libraries live in `Ref/Proof/` (`Except`: Avoids/Holds logic; `Sim`: grafting, tick loops, steps; `Prefix`: delivery as a cursor walk over knownAt-sorted rows; `Checker`: a Hoare logic for the checker). Next: L2_units (tick-level erasure), L3, L4_fills and L4_orders (`Market.index` lookups, order bookkeeping), L1_decisions.
  - **Bend:** C6.3 counts 0 by construction (Log, Bend finding); no Bend model is built.

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
  - *Revision 2026-10-19 18:50 UTC, before any C0.3 or C0.7 judgment (applies to both):* neither recorded window met its polling precondition. A host network outage (DNS failure) stopped all polling from 13:07 to 16:19 UTC. Also, at every 4h boundary the funding and bar polls (24 × weight 20) exhausted the shared rate budget and delayed every coin's L2 poll by up to 148 s. The recorder now polls L2 on its own thread with its own budget (120 of the 400 per minute) and was restarted at 1792435373620 (18:42:53 UTC). Both criteria are judged on the first 24 h after that restart in which no coin's L2 poll gap exceeds 60 s (`ingest.availability.window`): C0.7 on the L2 snapshots inside it, and C0.3 on the boundaries whose first and verify polls fall inside it. A gap restarts the window after it. Polls from before the restart are not judged.
  - *Revision 2026-10-19 20:20 UTC, before any C0.3 or C0.7 judgment (applies to both):* the window above is invalid too.
    - At the 20:00 4h boundary, the funding and bar polls plus retries exceeded the 280/min boundary budget. kPEPE's funding retry waited in the rate limiter and was first observed at +120.9 s, though the venue stamped the row at +21 ms. That violates C0.3's precondition (each coin polled at least every 30 s), so the lateness is the recorder's.
    - In 14 recorded funding boundaries, no row was missing from a poll sent later than +1.7 s.
    - The recorder now starts each boundary's polls at +5 s, spends the full half-limit budget (600/min: 120 L2, 480 boundaries; nothing else queries the venue while it runs), and skips delisted coins (FTM is outside its listed interval for C0.3 and has no live book for C0.7). It restarted at 1792440985867 (20:16:25 UTC).
    - Both criteria are judged on the first 24 h after that restart in which no coin's L2 gap exceeds 60 s and no boundary poll comes more than 35 s (30 s plus loop latency) after the boundary or the previous poll of the same row. Such a gap restarts the window after it.
  - *Revision 2026-10-20 00:25 UTC, before any C0.3 or C0.7 judgment (applies to both):* the window above restarted at the 00:00 4h boundary, and the cause was a second definition of a closed bar.
    - The recorder and the C0.3 analysis counted a bar as closed only once the next bar existed. The store counts it closed when openTime + 4 h ≤ fetchedAt. TIA and POPCAT had not traded by +9 s, so their bars were retried. Each miss cost two requests, the first round used the whole 480/min, and the retries waited 56 s in the rate limiter.
    - Under the store's rule, the closed bar's value equalled the verified final value in all 943 first polls over 59 recorded coin-boundaries, the earliest sent at +55 ms.
    - The recorder and the C0.3 analysis now use the store's rule: a bar's observed value is the row opening at H − 4 h in a poll sent after H, fetched with one request. A routine 4h boundary costs 440 of the 480/min. If three or more coins' funding is late at a 4h boundary, the retries still exceed the budget, and the unchanged window rule restarts the window.
    - The window rule is unchanged and counts from the next recorder restart (`ingest.availability.RECORDING_FROM`).
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
  - *Revision 2026-10-20 (wording only):* paper revision 5 renumbered its sections. Paper §5 (experiment identity) is now §7, and §6 (the gate) is now §8.
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
  - *Revision 2026-10-20 (paper revision 5), before any C2.4 to C2.6 run.* This changes the holdout test's algorithm and adds a direct-calibration exit requirement. It does not change any frozen significance level, search budget, selection cutoff, or C2.4 to C2.6 target. Every started campaign still counts, and a crash or timeout still counts as a promotion.
    - **Selection versus inference.** SPA, StepM, the DSR screen and the mechanism check are selection rules only. They decide which candidates reach the holdout, and C2.4 to C2.6 measure how the whole procedure behaves, but their p-values and scores support no inferential claim after adaptive search. The holdout batch, with Holm across the frozen finalists, is the only inference. Holm bounds family-wise error only if the finalists' holdout p-values are valid given everything used to select them. The earlier mechanism-check revision's "Holm stays valid" carries that condition.
    - **Error claims are per campaign.** A campaign's false-promotion rate is claimed only for its own finalist family on its own holdout. In stage 2 that family is the campaign's frozen finalists. Stage 3 keeps its frozen design: one joint holdout batch with Holm within each arm, so its claims are per arm, not a 5% family-wise bound across both arms. No project-wide claim is made, and every promotion is reported beside the number of campaigns run.
    - **The tested series.** The tested series is the finalist's per-4h-step net return from the kernel (`results.returns`) over the holdout report window. Every step is included, flat steps and no-trade steps too; the steps are the ones the kernel emits.
    - **The test.** It is a one-sided, studentized stationary block bootstrap of that series' mean, using `arch.bootstrap.StationaryBootstrap` (version pinned by `flake.lock`). The mean block is 6, there are 10,000 resamples, and the integer seed is the first 4 bytes, little-endian, of SHA-256(campaign id + finalist strategy hash), as in the committed `gate.promote`.
      - Let x_t = r_t − r̄. For 0 ≤ k < n, γ̂(k) = n⁻¹ Σ_{t>k} x_t x_{t−k}, with no wrap-around. Then σ̂² = γ̂(0) + 2 Σ_{k=1}^{min(36, n−1)} (1 − k/37)(5/6)^k γ̂(k).
      - The weights, extended by zero beyond lag 36, are a product of a Bartlett and an AR(1) sequence. Both are positive definite, so σ̂² ≥ 0 in exact arithmetic.
      - The statistic is T = r̄/σ̂. Each resample gives T* = (r̄* − r̄)/σ̂*, with σ̂* computed the same way. The p-value is p = (1 + #{T* ≥ T}) / 10,001.
      - A series with σ̂ = 0 gets p = 1. A resample with σ̂* = 0 gets T* = +∞ if r̄* ≥ r̄, and −∞ otherwise.
      - A negative or non-finite computed variance is an implementation failure, not a result.
      - The block length and the lag window are fixed, so no general finite-sample or asymptotic validity is claimed. Calibration measures the test's rejection rates under the generators below, and passing supports only those stated bounds.
    - **Development calibration (reported only).** Lengths are 540 (C3.2's and C4.5's [640, 730)-day windows), 546 (stage 3's real [2026-07-01, 2026-09-30)) and 1,080 (stage 2's 180 days). There are 4,000 series per generator and length. Student-t innovations are standardized to variance 1. The generators are:
      - i.i.d. N(0, 1);
      - i.i.d. t₃;
      - GARCH(1,1), with ω = 1 − α − β, α = 0.1, β = 0.85, t₅ innovations, initial variance 1, and 500 burn-in steps;
      - N(0, 1) with the standard deviation tripled from step ⌊n/2⌋;
      - AR(1) with φ = 0.2, N(0, 1) innovations, starting at 0 with 500 burn-in steps;
      - zero-inflated: a stationary two-state chain with P(flat → active) = 1/12 and P(active → flat) = 1/4, over a latent GARCH-t₅ process that evolves at every step, with return 0 while flat.

      Development results may inform a redesign, which takes a new dated revision before the locked run.
    - **Locked calibration (judged; added to stage 2's exit).** It runs once, before any C2.4 run, on the frozen test. It uses the same three lengths and 20,000 series per cell. Its generators were not used to design the test:
      - Gaussian AR(1) with φ = 0.3 and 500 burn-in steps;
      - i.i.d. t₄;
      - GARCH(1,1) with α = 0.05, β = 0.93 and t₄ innovations, as above;
      - N(0, 1) with the standard deviation doubled from step ⌈2n/3⌉;
      - sparse: a stationary chain with P(flat → active) = 1/36 and P(active → flat) = 1/4, active returns i.i.d. t₅, and 0 while flat;
      - jumps: N(0, 1) plus, with probability 0.01 per step, an independent jump of ±10 with equal probability.

      Seeds come from SHA-256 of `holdout-calibration-locked-v1` and the cell name. For each of the K = 54 cells (generator × length × level u ∈ {0.05, 0.01, 0.005}), the one-sided Clopper–Pearson upper bound on P(p ≤ u), at confidence 1 − 0.05/54, must not exceed 0.0625, 0.015 or 0.01 respectively. Rejection counts at 0.001 and 0.0005 are reported. Holm levels below 0.005, reachable when a campaign has more than 10 finalists, are checked only through C2.4 to C2.6's whole-procedure runs. A failed locked run stays recorded as a failure; any redesign gets a new dated version and a new locked suite before it is judged.
    - These series tests supplement C2.4 to C2.6, which judge the whole procedure, and do not replace them.
  - *Revision 2026-10-20, after the development calibration and before the locked run:* the development suite (`audit/stage2/holdout-size-development.json`) found the studentized test oversized at the levels Holm uses.
    - **What it found.** Rejection rates reached 0.065 at 0.05, 0.016 at 0.01 and 0.0103 at 0.005, worst for the zero-inflated, volatility-break and heavy-tailed series. Even some Gaussian cells were high (0.0155 at 0.01). The locked limits would likely fail.
    - **The fix: direct calibration.** Let p_raw be the studentized bootstrap p-value specified above. The holdout p-value is now p = max over the 18 development cells c of (1 + #{development p_raw in c ≤ p_raw}) / 4,001. The development p_raw values are committed as `gate/holdout_calibration.json`, with its sha256 in the Log.
    - **Why it is valid.** For each generator this is the Monte Carlo p-value of p_raw against that generator's null distribution, which is valid when the null is that generator. The maximum is valid and conservative across the family.
    - **What stays.** Block 6, 10,000 resamples, the seed, Holm, α = 0.05, the net-return condition, and the locked suite's generators, sizes, levels and limits are unchanged. The locked suite now judges p.

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
  - *Revision 2026-10-20 (paper revision 5; reported, never judged):* two diagnostics per finalist are added. They are recorded only after the promotion decisions are committed. They never change promotion, finalist selection or the judged report, and any later operational use is recorded separately.
    - **Holdout return at twice the cost table.** It comes from the same holdout batch, as a full evaluator rerun with every C0.7 cost-table entry doubled, so costs also affect later equity and orders. Fees and funding are unchanged.
    - **Relative-range coverage.** For each coin, take the closed interval from the minimum to the maximum (high − low)/open over that coin's 4h bars inside the C0.7 calibration span. Report the fraction of its holdout bars that fall inside that interval, with numerator, denominator and missing-bar count. This measures relative-range coverage only, not every market condition that drives execution costs.

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

### Stage 6: verified reference kernels

Frozen 2026-10-20, before any Lean or Bend code existed. GPT reviewed the draft, and this is the one revision.

**Scope.** Paper §6: two reference kernels, one in Lean 4 and one in Bend 2, each define a formal and executable model of the pilot's strategy language and simulator, and prove the same five laws. The Rust engine `mm` is not modified in this stage (a human instruction).
- **Toolchains.** Pinned in `flake.nix` by content hash:
  - Lean v4.34.0 (Lake 5.0.0), the version Bend's `--verdict` requires;
  - Bend 2.0.37 with its bundled `bendtt.lean` checker.

  The mm build compared against is recorded. A toolchain change needs a dated revision before further judged work.
- **Outcome.** The comparison's winner becomes the reference kernel in `reference/`, differential-tested against `mm` permanently. The loser leaves the active tree, while its specifications, proof evidence and comparison report are kept. The engine is not replaced.

**Semantic contract.** Before any proof, `reference/SEMANTICS.md` is written and frozen. It is reviewed by GPT and committed with each kernel's formal statements of the laws, as `criteria: stage 6 laws`.
- **What it fixes.** It resolves DSL.md and INVARIANTS.md against the immutable engine, and fixes:
  - **The program:** the full DSL v1 syntax, the type-checking judgment with a complete signature table, and the initial state.
  - **The clock:** the delivery order of observations, ticks τ = H + 120 s, and every node evaluated once per tick, including nodes in unselected `if` branches.
  - **Operators:** each operator's transition equation, with initial state, output, state update, unit, and behavior on undefined and non-finite inputs. That includes the windows' exact numerical algorithms as `mm` computes them (running sums with periodic exact recompute), EMA seeding, cross-sectional membership, order and rank ties, and `hours_since` state.
  - **Decisions:** the decision and hold rules, including the freshness rule. A held older input never satisfies the requirement for funding and a bar at the current boundary.
  - **The portfolio:** scaling, the order cap, truncation, minimum notional and exact closes, funding settlement order, marks, margin, liquidation, delisting, fees, costs and accounting.
  - **Binding preflight.**
- **Conformance and non-vacuity.** Every well-typed program within the published resource limits is supported. Undefined values and runtime rejections occur only under enumerated conditions, and evaluation over a finite tick sequence terminates. Concrete conformance examples are included: defined values, a nonzero decision with its ordinary fill, and an available-source run that passes preflight. No kernel may replace these definitions with relations constrained only by the laws.
- **Changes.** A later change to any referenced definition takes a dated revision, as a changed law does.

**The laws.** Each kernel states them formally, matched one to one with this prose.
- **L1 Non-interference.**
  - **Setup.** Fix a well-typed program, its parameters, the runtime configuration, the start, the initial state and the universe schedule.
  - **Prefixes.** P_t(h) is the ordered delivery prefix of the observation records eligible by tick t. Each record carries its source, input, coin, observation identity, revision identity, eventTime, knownAt, tie-break sequence and value. Prefix equality keeps multiplicity and order. A revision is delivered when it becomes available and does not overwrite earlier delivered history, and warm-up uses nothing outside the prefix.
  - **Values.** For all admissible histories h₁ and h₂ and every tick t: if P_t(h₁) = P_t(h₂), then every node's value and the machine state agree at every tick through t. In particular, the raw target weights agree at every decision tick through t.
  - **Decisions.** If the initial portfolio and the execution, rule and universe prefixes through t also agree, then every decision record through t agrees: holds with their reasons, scaled targets and submitted quantities. This does not claim equal fills after t.
- **L2 Unit soundness.** For every program the frozen checker accepts, every schema-conforming history and every tick:
  - the unit-instrumented evaluation never fails with a unit or type mismatch;
  - every defined numeric value carries its static unit, and every defined boolean is a boolean.

  The instrumented evaluator performs the specified operand checks and unit transformations; it does not assign the expected unit by construction. Erasing its units gives the same values, transitions and non-unit errors as the executable evaluator. Domain errors and undefined values occur exactly where the operator semantics specify.
- **L3 Rewrite soundness.** For every rule schema of R version 1 (all twelve rows of CANONICAL.md), every well-typed substitution satisfying its side conditions, and every well-typed containing DAG context: the rewritten program is well-typed and has the same externally observable trading behavior.
  - **Equivalence.** From corresponding initial states, for every admissible history, universe schedule, parameter assignment and execution configuration, the two programs give identical weight streams, decision and hold records, orders, fills, fees, settlements and equity traces. Retained nodes have identical value streams under an explicit node correspondence. Stateful descendants receive the same tick inputs even in unselected branches.
  - **Obligations.** Each rule has its own listed semantic obligation: typing side conditions, definedness, and the numeric or boolean identity it needs. The numeric identities are neg(neg x) = x, abs(abs x) = abs x, abs(neg x) = abs x, x · 1 = x, x / 1 = x, x − (+0) = x, and commutativity of add and mul. The boolean obligations cover strict `and`/`or`, `not` involution, `if`/`not` duality and the comparison dualities, under the frozen undefined semantics.
  - **Abstract version.** The law is proved over every numeric structure satisfying the obligations.
  - **Binary64 version.** A binary64 claim is counted only once the rounding mode, signed zeros, non-finite intermediates and NaN handling are specified, and the obligations are established for reachable values under them.
- **L4 Fill ordering.**
  - **Cause.** Every fill has a nonzero quantity and a cause: an ordinary order, a liquidation or a delisting.
  - **Ordinary fills.** For an ordinary order, submittedAt = decidedAt. The selected bar is the first bar of its coin with openTime ≥ submittedAt, not filtered by trade count. If there is none, or it has trades < 1, the order is unfilled and does not roll.
  - **Fill terms.** Otherwise filledAt = the selected bar's openTime, and every observation in the decision's transitive input lineage has knownAt ≤ decidedAt. The reference is the bar's open. The bucket is "1000" when |qty| · reference ≤ 1000, else "10000". The price is reference · (1 + side · bps/10⁴), and the fee is |qty| · price · taker fee.
  - **Both directions.** Every ordinary fill follows this rule, and every valid submitted order whose selected bar has a trade produces exactly this fill.
  - **Closeouts.** Liquidation and delisting fills satisfy their own I3 source-bar and reference rules and I2's closeout times.
- **L5 Binding.**
  - **Sources.** Sources(s) follows the frozen dependency rule, covering every input occurrence, including unused lets and the prediction.
  - **Preflight.** After checking and before any tick, preflight checks every source. If any is unbound, or lacks an accepted certificate under the stage's certificate interface, the result is `R_INPUT_UNAVAILABLE` with no trace or partial result; the rejection may still be ledgered.
  - **Converse.** If every source passes, evaluation proceeds, and missing observations follow the operator semantics. The stage 6 certificate interface is a trusted flag from the pilot's store adapter, so the claim is conditional on that adapter. Certificate authenticity and validity are not claimed (stage 7).

**Proof acceptance.**
- **Lean.**
  - A clean `lake build` passes on the pinned toolchain. Each scored theorem has the exact frozen statement.
  - Its transitive dependencies contain no `sorryAx`, new axiom or unapproved trusted principle. The recorded `#print axioms` of each scored theorem is a subset of {propext, Quot.sound, Classical.choice}.
  - Numeric operations and their laws are explicit quantified hypotheses in the reviewed statements.
  - Abstract and binary64-instance theorems are reported separately. The executable used in C6.4 is the same definitions, and any extraction, foreign numeric code or adapter is named as part of the implementation boundary.
- **Bend.**
  - Each scored law corresponds explicitly to the frozen statement and semantics.
  - Its exact proof artifact completes `bend --verdict` on the pinned toolchain, with no fuel exhaustion, skipped obligations or unapproved assumptions. The invocation, exit status, full output, dependency hashes and translated theorem are archived, and the translated statement is audited against the law.
  - Everyday-checker success, or verdict success for another declaration, does not count.
  - Trust in the translation, the statement correspondence and the Lean-based checker is reported separately.

**Criteria.**
- **C6.1 Contract and laws frozen.** SEMANTICS.md and each kernel's formal statements are GPT-reviewed and committed alone, as `criteria: stage 6 laws`, before any proof. Changes take dated revisions, and proofs of old statements do not count.
- **C6.2 Lean.** L1 to L5 are proved under the Lean acceptance rule. L3 counts only with every R v1 rule.
- **C6.3 Bend.** L1 to L5 are proved under the Bend acceptance rule, with the same L3 rule.
- **C6.4 Differential agreement.**
  - **Corpus.** Generator revisions, seeds, program and market manifests, initial states and warm-up are frozen before the judged run. The corpus is:
    - at least 1,000 programs from the frozen stage 4 generator;
    - deterministic operator and boundary cases;
    - W0 and stage 2's probes;
    - all of this on N1, N2 and N3 markets of 550 days, long enough for the 4,380 h windows and nested lags to become defined.

    The deterministic cases cover:
    - every operator, both `if` branches, and stateful nodes in unselected branches;
    - undefined and resumed inputs, EMA seeding, rank ties and listing changes;
    - conversions, signed zeros and non-finite intermediates;
    - revision and timestamp ties;
    - empty first eligible bars, caps, truncation and zero-target closes;
    - settlements, liquidations, delistings and binding failures.
  - **Exact comparisons.** These are compared exactly in every case: type-checker verdicts and codes (including every `kernel/tests/adversarial` case), definedness, value category, booleans, units, holds and trades, traded coins, order quantities, fill source bars and times, closeout events, and signed zeros where the semantics distinguish them. Non-finite values are compared under the frozen policy.
  - **Numeric comparisons.** Finite numbers, money and equity are equal bit for bit. The one exception is outputs depending on `log`, `exp` or `sqrt` where a kernel's math library is shown to differ from mm's: those use |x − y| ≤ max(1e-12, 1e-9 · max(|x|, |y|)), and the differing library is named before the judged run.
  - **Pass.** No waiver: every case must agree. Each failure reports its first numeric and first discrete divergence. Coverage is reported: defined outputs, decisions, orders, fills and exercised rejection paths.
- **C6.5 Comparison and adoption.**
  - **Report.** The report gives, per kernel:
    - every law's result, including partial progress;
    - trust notes;
    - the replay benchmark: W0 on the 550-day N2 market, median of 5, on frozen hardware, threads, flags and inputs, with end-to-end and evaluator-only times separately;
    - null-simulation throughput, counting completed program-market-years only;
    - effort per milestone: elapsed time, active agent time, sessions and retries, failures included;
    - the differential results.
  - **Ranking.** Only kernels passing C6.4 are eligible. Rank eligible kernels by accepted-law count; on a tie, Lean wins. Performance and effort do not change the ranking.
  - **Exit.** Successful exit requires the winner to have all five laws accepted. Otherwise there is no adoption, and the blocker is recorded. The winner and its differential harness move to `reference/`.

Exit when C6.1 to C6.5 hold.
- *Revision 2026-10-20, during C6.1's review and before any proof:* GPT's review of the formal statements found three places where the frozen stage 6 text contradicts the immutable engine, which this stage may not change. The laws are restated to match the engine.
  - **History.** `mm` resolves revisions in the store before a run: per (dataset, coin, eventTime) it takes the revision with the largest fetchedAt ≤ the version, carrying that revision's knownAt. A run receives one record per key, and earlier revisions are never delivered. L1's records are these resolved rows (dataset, coin, eventTime, knownAt, value, plus each event's slot and index), and its prefix is their ordered delivery prefix. Non-interference across revisions is the store's property, tested by C0.4 and C5.2, not stage 6's.
  - **L4's selected bar.** As INVARIANTS.md's I3 states ("its openTime is ≤ t_fill"), an ordinary order decided at B + δ has the scheduled fill time B + BAR, and its selected bar is the coin's bar opening at B + BAR. If that bar is missing or has no trade, the order is unfilled and never rolls to a later bar. Orders due after the run's last step are not resolved within the run, since its horizon ends first. L4's converse covers the orders whose due step runs.
  - **L5's certificate interface.** It is the adapter's binding flag for each event source. The core funding and bar datasets are always present, because the loader fails otherwise; this is an adapter invariant.
- *Revision 2026-10-20, after the C6.1 freeze and before any proof:* the frozen Lean model computes its delivery orders and per-coin bar times with `Array.qsort`, for which Lean core has no correctness lemmas. They are now computed with `Array.mergeSort`, whose sortedness and permutation lemmas core provides. On an admissible market every sort key is unique: resolved rows have unique (coin, eventTime), event rows carry their array index, and bar times per coin are unique. Both sorts therefore yield the same order, and no law, statement or behavior changes. The smoke differential test checks that.
- *Revision 2026-10-20, before any stage 6 code or result:* C6.4 is judged per kernel, as the eligibility test C6.5 already uses it as. The stage exits when:
  - C6.1 holds;
  - C6.2 and C6.3 are reported for both kernels;
  - the adopted kernel passes C6.4 and has all five laws accepted;
  - C6.5's report and adoption are done.

  Reason: the pinned Bend 2.0.37 has no binary64 type, only `Nat`, `U32` and `F32` over bit-list words. Its executable model therefore cannot meet C6.4's exact comparisons with `mm`'s f64 arithmetic, and software binary64 over bit lists is far too slow for C6.4's corpus. Read literally, "exit when C6.1 to C6.5 hold" would make the stage unexitable because of a missing number type, not because of any law or the engine. Bend's numeric gap is reported as a comparison finding.
- *Revision 2026-10-20, while proving L4 and before any L4 proof:* L4_fills' closeout clause is false over an arbitrary `NumOps`, and so cannot be proved as frozen.
  - **What the statement says.** It phrases a liquidation's reference by the fill's own sign: `if 0 < f.qty then high else low`.
  - **What the model does.** Following `mm`, it takes the adverse extreme of the held position q, which the fill closes with qty = −q: `if 0 < q then low else high`.
  - **Why they differ.** Equating the two needs `lt 0 (neg q) = ¬ lt 0 q`, a numeric law L4 does not assume. The engine's check only compares the reference with `N.eq`, not equality. A structure where `lt` is always false and `eq` always true passes the run and breaks the clause.
  - **The fix.** The clause now states the construction: f.qty = −q for some q, and f.reference is the bar's close for a delisting, otherwise `if 0 < q then low else high`. That is I3's "adverse extreme of the position". No model definition and no other law changes, and on binary64 the two readings agree for every nonzero non-NaN q.
- *Revision 2026-10-20, while proving L1 and before any L1 proof:* L1_simulator is false for j beyond the run. `steps j` runs `bounds.take j`, so it stops after the run's last step, while `machineAfter (4j)` keeps delivering and ticking. The statement now assumes j ≤ bounds.length, the steps a run actually takes. Nothing else changes: L4 uses it only at decisions the run made, and L1_decisions does not use it.

### Stage 10: thesis track

Frozen 2026-10-20, before any stage 10 code existed and before any thesis was registered. GPT reviewed the draft, and this is the one revision.

**Scope.** This stage implements paper §12's forward-only, event-driven theses on Hyperliquid perpetuals, both core and builder-deployed (HIP-3: equities, indices, commodities, FX).
- **Data.** Prices come from the public, read-only info API.
- **Positions.** Paper positions only: no keys, no wallets, no orders, live or testnet.
- **What the stage does.** It registers, sizes, marks, resolves and scores theses, and it logs every disclosure to an agent.
- **Exit claim.** Stage exit is an operational claim only.
- **Skill claim.** None is made before 200 resolved main-agent clusters within one frozen track version. That is a minimum evidence floor, not proof of independence, power or skill; the paper's sample of about 194 is illustrative. Reports stay descriptive unless a separate inferential protocol is frozen before its outcomes accrue. That protocol would fix the primary comparator, hypothesis, weighting, dependence assumptions, multiplicity and stopping rule.

**Agents and harness.**
- **The main agent.** It runs `claude-opus-5-5` (knowledge cutoff June 2026) in stage 3's arm A sandbox: bubblewrap, the workspace only, Read and Write there, Bash only for `./thesis-agent`, and no web tools.
- **The daemon.** The client talks to a daemon outside the sandbox, which offers:
  - `markets`: eligible markets, each with its last completed 1h close and its time;
  - `prices MARKET`: completed daily bars before now;
  - `fetch URL`;
  - `register FILE`;
  - `positions`;
  - `exit ID REASON`.
- **Sessions.** A session starts daily at 00:10 UTC, at most one per UTC date. It is gated by a tiny model call, as in stage 3. Turn limit 100, wall limit 1 h, at most 2 accepted registrations. A crash, timeout or early stop consumes that date. Missed sessions are reported.
- **The full no-reading agent.** After each main session, a separate sandboxed session with the same brief and limits but without `fetch` registers its own theses, at most 2. It sees the same market and price snapshot, and is scored separately.
- **The conditional ablation.** For each accepted main thesis, a fresh no-fetch instance states its probability for the identical outcome. It sees only:
  - the exposure, its direction and the entry convention;
  - the horizon and the outcome definition;
  - price data available at t_r.

  It never sees the main agent's probability, catalyst, sources, rationale or transcript. A failed ablation is a reported missing pair; it never removes the main thesis from scoring.
- **The freeze.** A manifest is hashed and frozen before the first session. It covers:
  - prompts and workspace inputs;
  - the model id and the returned model metadata;
  - flags, permissions and limits;
  - the client and daemon code;
  - the ablation and benchmark definitions;
  - the cost rules and the scoring code.

  A behavior-affecting change starts a new track version. Versions are never pooled.

**Disclosure log.** Every daemon call, including rejected and failed ones, gets an append-only record before any response bytes are released: session id, request id, daemon UTC time, the canonical request, status, and the sha256 of the exact response bytes. Those bytes are retained.
- **Fetches** also record the URL, redirect chain, final URL, start and end times, HTTP status and raw-body sha256.
- **Sources.** Each source a thesis cites must be a retrieval already disclosed to that session.

**The retrieval proxy.**
- **What it serves.** Public, unauthenticated document reads only. It has no keys, cookies, authorization headers or credentials, and refuses URLs containing userinfo. It is GET only, with no caller-supplied headers or body.
- **Destinations.** Every initial and redirected destination is resolved and validated. Only globally routable addresses are used, and the connected peer must be a validated address. Private, loopback, link-local, reserved and metadata addresses are refused, for IPv4 and IPv6. At most 5 redirects are followed, each revalidated.
- **Politeness.** robots.txt is honored, failing closed. There is at most 1 request per 5 s per host, daemon-wide.
- **Exchange reads.** These go only through a separate fixed-host adapter permitting only the frozen `/info` request types (`meta`, `perpDexs`, `candleSnapshot`, `fundingHistory`). It has no signing, account or order operation.

**Registration.** A thesis gives:
- **Exposure.** One eligible market with sign w ∈ {−1, +1}, or a spread of two distinct eligible markets with weights +1 and −1.
- **Resolution time T.** A UTC midnight with 72 h ≤ T − t_r ≤ 1,440 h.
- **Claim.** p ∈ [0.01, 0.99].
- **Catalyst.** Catalyst text and a catalyst id.
- **Invalidation loss.** L ∈ [0.01, 0.50].
- **Sources.** Retrieval ids.

Values that are not finite, or fall outside these bounds, are refused. An eligible market is listed and not delisted at t_r, with at least 90 completed daily bars before t_r.

The daemon assigns the thesis id and t_r from its own clock at the atomic commit. Eligibility, baseline inputs and sizing are evaluated as of t_r, and the risk reservation is made in the same serialized transaction. The request can supply no time.

The thesis is written with `mm disclose --kind thesis` to the thesis ledger, whose triggers reject UPDATE and DELETE. Its content is canonical JSON (sorted keys, no whitespace), and its sha256 is logged. A retry with the same request id returns the original registration; changed content under that id is refused. Accepted theses cannot be cancelled or removed from scoring.

**Positions and outcome.**
- **Entry and fixed quantities.** Each leg j enters at the open of the first 1h bar with openTime ≥ t_r + δ, where δ = 120 s, at price P_j,e. Its quantity is fixed at q_j = w_j N / P_j,e, with no rebalancing. The gross return is R_gross(u) = Σ_j w_j (P_j(u)/P_j,e − 1), per N; a spread's gross notional is 2N.
- **Sizing.** E_r is the latest reconciled paper equity at t_r (initial $10,000). The risk budget is b = 0.01 E_r and N = b / L. The probability p is not a sizing input.
- **Admission cap.** Each funded thesis reserves b from registration until its position is fully closed, including the pending-entry period. A thesis is admitted only if the existing reservations plus b are at most 0.05 E_r. Otherwise its size is zero permanently, and admission follows commit order. This caps nominal budgets at admission. It does not bound realized losses, and no position is resized when equity falls. If E_r ≤ 0, every new thesis has size zero.
- **Invalidation.** It triggers when the close of a 1h bar ending at B gives R_gross ≤ −L. It becomes actionable at B + δ, and the position exits at the first 1h open at or after B + δ; the open simultaneous with the invalidating close is never used.
- **Discretionary exits.** An `exit` committed at t_x is an append-only decision that never amends the thesis. It exits at the first 1h open at or after t_x + δ.
- **Horizon exit.** This is scheduled at registration, at the first 1h open at or after T.
- **Missing bars.** These never cause an earlier price to be used.
- **Costs and funding.**
  - Fees and execution costs are charged on each leg's traded notional at entry and exit. That is the taker fee plus the coin's C0.7 cost cell. A coin without one uses the maximum cell over U, an explicitly unvalidated fallback, flagged in every result that depends on it.
  - Funding applies hourly from fundingHistory: it is paid on q_j at the 1h open of the settled hour, with longs paying positive rates. At an identical timestamp the order is: funding, then exits, then entries.
  - Data a result needs that is missing leaves it unresolved, never assumed zero.
- **Outcome.** The probability predicts the as-registered net return R_net: the hypothetical fixed-quantity position from the scheduled entry to the horizon exit, including price PnL, funding, fees and execution costs, per N. Invalidation and discretionary exits are ignored, and the same computation is done for size-zero theses. o = 1 if R_net > 0; exactly 0 gives o = 0.
- **Score views.** One Brier score per probability, against o. Position performance is reported two ways:
  - **as registered:** held to the horizon;
  - **as managed:** with invalidation and discretionary exits.

  No Brier score is computed for the managed view.
- **Accounting.** Paper equity reconciles hourly within 1e-9 dollars: initial cash plus realized and unrealized PnL plus funding, less fees and costs.

**Baselines.**
- **Base rate.** It uses at most 3 years of daily bars available before t_r, with the same exposure, signs, spread construction and net-outcome definition.
  - **Windows.** Non-overlapping windows of the holding duration, rounded to whole days, with entry and exit at daily opens, anchored backward from the last completed daily open. Funding is summed over each window, and costs are charged as above. An incomplete window is omitted without moving the others.
  - **Estimate.** With m ≥ 10 complete windows, of which x are positive, p_ref = (x + 1)/(m + 2). Otherwise the base rate is unavailable: that thesis is excluded from base-rate skill, and the exclusions are counted. m, the history span and the omitted windows are recorded.
  - **Interpretation.** The base rate is a frozen historical comparator, not a calibrated probability. No interval treats windows as independent.
- **Conditional ablation and full no-reading agent.** As above. The conditional comparison measures probability assessment given the main agent's chosen task, not the value of reading for choosing exposures and horizons; the full no-reading agent addresses that.
- **Frozen benchmark.**
  - Every Monday at 00:00 UTC, BTC, ETH, xyz:XYZ100, xyz:GOLD and flx:OIL are processed in that order. Each is long if its last completed daily close is above the close 20 UTC days earlier, otherwise short. The horizon is the Monday 21 days later, L = 0.10, and p is its base rate.
  - A market with a missing close, or without a base rate, is skipped and logged. Missed runs are logged, never backdated.
  - It uses its own $10,000 paper account with the same sizing and cap.
  - Its Brier score is descriptive, not a head-to-head forecast comparison. Its paper return is compared over the same calendar interval.
- **Market-implied probabilities.** Not used, since there is no free source for these exposures. The report says so.

**Scoring.**
- **Point scores.** Brier scores are thesis-weighted means. Each paired comparison uses the identical resolved theses with both forecasts, and reports its coverage. Skill is 1 − B/B_ref; if B_ref = 0, skill is undefined and B, B_ref and B − B_ref are reported.
- **Clusters.** Over all accepted main theses registered by the report's cutoff, including unresolved and size-zero ones, two theses are linked if they:
  - came from the same session;
  - share a catalyst id; or
  - share a market leg with intersecting closed intervals [t_r, T].

  The clusters are the connected components. A cluster counts as resolved only when every thesis in it is resolved. Each report records its graph, the cluster sizes and the largest cluster's share. The cluster count is a sample-size proxy, not proof of independence.
- **Intervals.** Resample the resolved clusters with replacement (the original count), keeping each sampled cluster's theses with their multiplicity. Recompute the thesis-weighted scores, the paired loss difference and skill, 10,000 times, with a frozen NumPy PCG64 seed of 10. Report percentile 95% intervals. Replicates where the ratio is undefined are counted. With fewer than 2 resolved clusters, no interval is given. The intervals are descriptive.
- **Portfolio returns.** Reported without intervals.

**Criteria.**
- **C10.1 Registration.** Tests show that:
  - every bound refuses an invalid thesis, including an ineligible market, a non-finite value and a supplied time;
  - a registered thesis is a ledger row whose canonical content matches its logged sha256;
  - UPDATE and DELETE fail;
  - retries return the original thesis and never change t_r, and changed content under a request id is refused;
  - concurrent registrations get a deterministic commit order, and reservations at the cap are exact;
  - delayed processing never backdates a thesis.
- **C10.2 Disclosure log, proxy and sandbox.**
  - The sandbox passes C3.1's OS-level tests, adapted to the thesis workspace.
  - Tests show:
    - a disclosure record is committed before its bytes are released;
    - credentials are refused, and so are private, loopback, link-local, reserved and metadata destinations, both directly and after a redirect or a rebinding resolution;
    - robots.txt disallows and failures are honored, and the per-host spacing holds;
    - the exchange adapter rejects any request type outside its list and any other host.
  - Per session, every transcript client call maps to exactly one daemon call record. The transcript has no tool call outside Read, Write and `./thesis-agent`.
- **C10.3 Positions.** Fixtures with hand-derived results are committed before the position code. They cover:
  - the entry bar;
  - sizing;
  - the cap with simultaneous registrations, and a pending-entry reservation;
  - falling equity;
  - invalidation, including the rejected open simultaneous with the invalidating close, and a gap through L;
  - a discretionary exit;
  - funding coincident with an entry and an exit;
  - a short and a spread;
  - a horizon on a missing bar;
  - a size-zero hypothetical outcome.

  Identifiers, times and outcomes match exactly, money within 1e-9 dollars, and the equity reconciles hourly.
- **C10.4 Independent scoring.** GPT receives this specification and the input schema alone. It implements the outcome, base rate, Brier and skill, clustering and the cluster bootstrap's point statistics. On 1,000 test sets from a frozen generator and seed, the two implementations agree:
  - exactly on outcomes, exclusions, missing statuses and cluster membership;
  - within 1e-12 on finite scores;
  - on which scores are undefined.

  The boundary cases are: R_net exactly 0, a horizon on a missing bar, chaining clusters, touching intervals, fewer than 10 base-rate windows, a size-zero thesis and B_ref = 0. Any ambiguity found is resolved, and this section is revised by dated revision before live registration.
  - *Revision 2026-10-20, during C10.4's first differential run:* "within 1e-12" did not say absolute or relative. Skill is a ratio and grows large when B_ref is small. The first run's only disagreement, after a generator fix (its daily bars were not on midnight, as SCORING.md requires), was a skill of −9751.869120430718 against −9751.86912043072, one unit in the last place. No summation order can meet an absolute 1e-12 at that magnitude. Finite scores now agree when |a − b| ≤ 1e-12 · max(1, |a|, |b|). C10.4 is judged on a run after this revision.
- **C10.5 Live operation.** The observation window is the first 28 consecutive UTC days after the harness freeze. It needs:
  - at least 20 accepted main theses, each with a completed conditional ablation or a reported failure;
  - every full no-reading session that was due, run or reported missed;
  - 4 executed benchmark batches, each listing every market as registered or skipped with its reason;
  - every horizon in the window with a score or an explicit missing-data status within 2 h of T, and scored within 2 h of the data becoming available;
  - at least 10 resolved main theses at exit, reached by continuing the frozen track;
  - links throughout: every accepted registration to exactly one ledger row; every disclosure to its response bytes; every resolution and management decision to its thesis;
  - static checks and runtime network tests showing that every reachable exchange operation is an approved public read, and that order, signing, authenticated, redirect-bypass and other-host requests are refused.
- **C10.6 Honest report.** The report enumerates:
  - sessions, registrations, rejected attempts and size-zero theses;
  - failed or missing ablations and unresolved outcomes;
  - skips and fallbacks;
  - thesis and cluster counts and paired coverage;
  - track versions.

  It separates forecast scoring from position performance, and stage completion from skill evidence, and it states the no-claim floor. A reviewer (GPT), given these criteria and the report, finds no claim beyond the evidence. The review supplements the mechanical checks; it does not replace them.

Exit when C10.1 to C10.6 hold. The track keeps running after exit.

## Blockers

- **Stage 5 unlock source (2026-10-19).** DefiLlama's emission endpoints return 402 (paid only), and its emissions-adapters repo is gone (404, absent from the org's public repos), so the pre-registered candidate fails C5.1. The fallback, vesting state read through public RPCs, was weighed and not built. Per coin (SUI, TIA, WLD) it needs its own source docs, enumeration of the vesting accounts or contracts, and a schedule-revision store. On top of that come a new kernel input kind (values from the schedule revision known at τ) and its mutants, all for at most 3 of U's 12 coins. Unlocks are therefore recorded as a blocked category at stage 5 exit, which the exit rule allows. Human decision (2026-10-20): unlocks stay blocked, and the RPC fallback is not built.
- **Checker: overflowed conversions share a node (2026-10-20, found proving L2).**
  - **What happens.** mm interns a `convert` node by its operator and factor bits, not by its target unit.
  - **Where it breaks.** DSL.md promises "the exact factor", but powi overflows for large time exponents. For example, the factor from `1` to `y^100/h^100` and the factor to `y^101/h^101` both come out as 0.
  - **The result.** The second convert reuses the first one's node and type, so `add` of the two passes the unit check. `mm check` and refmm both accept `{"op":"add","args":[convert(1,"y^100/h^100"), convert(1,"y^101/h^101")]}`.
  - **Impact.** Only degenerate values (0, ∞, NaN), and no timing leak. L2 still holds, because it is stated over the stored types.
  - **Proposed fix.** Key interning on the node's full identity, including the target. Reject a conversion whose factor is not finite and nonzero (E_UNIT). Both are kernel changes, so they wait: stage 6 does not modify the engine. They also change the kernel hash, so they belong before the first judged run that records it.

## Log

- 2026-10-20: The locked holdout calibration v1 failed (`audit/stage2/holdout-size-locked.json`, 360,000 series). 52 of 54 judged pairs pass; sparse/540 and sparse/546 at u = 0.05 do not (rates 0.0595 and 0.0602, upper bounds 0.0648 and 0.0656 against 0.0625). Every other cell's rate at 0.05 is at most 0.0514, at 0.01 at most 0.0117, at 0.005 at most 0.0043. The development family's sparsest generator was 25% active, the locked one 10%: the max-over-cells calibration did not cover sparser activity. Stays recorded as a failure; redesign v2 follows as a dated revision.
- 2026-10-20: Stage 6 proving found two frozen statements false as written, and both now have dated revisions: L4_fills' liquidation reference needs a numeric law it does not assume, and L1_simulator fails past the run's last step. A checker hole also surfaced: conversions whose factor overflows intern to one node (Blockers).

- 2026-10-20: Stage 6 Bend finding (`reference/bend/FINDINGS.md`, with reproductions). The pinned Bend 2.0.37 cannot state the frozen laws' quantification over every number structure in a form `--verdict` accepts:
  - functions are affine and never `Data`, so an abstract operation cannot be reused;
  - erased parameters cannot run;
  - `--verdict` refuses a law over a template-bound operation, as an implementation/kernel mismatch.

  Bend laws could cover only its own `F32` instance, which is weaker than the frozen statements, so C6.3 counts 0 by construction. Together with the missing binary64 (C6.4), this is recorded for C6.5, and no Bend model is built.
- 2026-10-20: The holdout test's development calibration finished (72,000 series, about 1 h), and the test was oversized (see the stage 2 revision). The calibration table `gate/holdout_calibration.json` (sha256 e2d6ebb83feb86c7b1f535ecbf7ec87c7d56b09aef1aedfa867feba23017a6d3) holds its 18 cells' bootstrap p-values, as integers over 10,001. The locked run judges the calibrated p-value.
- 2026-10-20: C10.4 met. GPT, given `thesis/SCORING.md` and the stage 10 criteria alone, wrote `thesis/tests/gpt_scoring.py`. On the run after the C10.4 tolerance revision, it agrees with `thesis/scoring.py` on all 1,000 generated sets: exactly on outcomes, exclusions, counts and clusters; within 1e-12 · max(1, |a|, |b|) on scores; and on which scores are undefined. Every listed boundary case occurs. The first run's mass disagreement on base-rate window counts was a generator bug: its daily bars were not on midnight, which SCORING.md requires.
- 2026-10-20: C10.3's fixtures were committed (30214dc) before `thesis/positions.py`. Running them found two errors in the hand derivations, not the code. The costs case bucketed the exit by N, though the cell follows each fill's traded notional (as in the kernel's I3 and the criteria), so a $1,100 exit uses the 20 bps cell. The funding case's 10 · 2e-4 · 100 was written as 0.02; its rate is now 2e-5, matching the stated derivation. Both corrections are in the same commit as the code.
- 2026-10-20: Paper revision 5. The roadmap now runs through stage 10 (6 reference kernels, 7 sources as a language feature, 8 multi-asset, 9 cross-domain exploration, 10 thesis track); stage 11, paper or live trading, is a human decision. Its `.tex` was swept into commit a624a69 by a `git add -A`; `docs/whitepaper.pdf` is built by `nix build .#whitepaper`.
- 2026-10-20: Human decisions on the blockers. Both C0.7 proposals are approved: the HL recorder restarts after the second backfill and keeps recording as a regime diagnostic, and holdout returns at 2× costs are reported after the promotion decision only. Unlocks stay blocked.
- 2026-10-19: Changes from an outside review.
  - Discourse forums map to a coin only at C5.1 precision ≥ 0.8, fixed before any return on the new inputs. That unmaps ethresear.ch (0.66) and forum.bnbchain.org (0.58) (mapping version 2). Both are still recorded and backfilled for C5.3.
  - The recorders' and analyses' shared helpers (clock, ISO time, JSONL reader) are unified in `ingest/live.py`. The paired modules otherwise stay, because the HL venue and the forum/Snapshot sources differ in API, records and availability rules.
  - pyflakes found that `reconcile`'s local dict shadowed the store's `live()`, which would have crashed the C5.3 reconciliation. It is fixed and now tested.
- 2026-10-19, before any C2.4 run: stage 2's judgement is wired (`gate.sweep truth`, `report`, `c21top`, tested on the criteria's own numbers). Campaign results now keep the in-sample top 5 programs, which C2.1 probes, because a campaign's ledger is deleted after it runs. C2.1's "first 20 C2.4 campaigns" is read literally as the first 20 ids in the committed `c24_specs()` order (c24-N1-G100-0 to -19), fixed here before any result exists. C2.5's "point estimate ≤ 0.078" is the rounded form of its binding Hoeffding bound ≤ 0.20 (exact limit 0.0776).
- 2026-10-19: C5.5's independent implementation is met for the derived counts. GPT (tools denied) wrote `ingest/tests/derived/independent.py` from `venue/sources/*.md` and DSL.md alone. It agrees exactly with `ingest/events.py` on 2,000 generated cases dense in boundary cases. As a power check, each of five one-token variations of the rule (≥ vs >, the coverage start, the tie rule, the window ends, the coverage end) changes 199 to 1,762 of the cases. GPT flagged that `snapshot.md` stated knownAt = max(created + 600 s, witness), which contradicts the stage 5 admissibility revision (an unadmitted claim never moves knownAt). The doc now states the witness rule. No strategy has used the input.
- 2026-10-19: C5.2 store work. A complete fetch now tombstones the keys it no longer lists, and a later listing restores them. `as_of` hides tombstoned keys. Tests cover edits, tombstones and restorations at exact fetch boundaries, plus a byte-identical recompute of the stored derived input. Also found and fixed: raw Discourse revisions had carried knownAt = created, so `as_of(t)` would have shown edited content before the edit. A raw row without knownAt is now known when fetched, and the server's claims stay value columns for the derivation to judge. The one existing raw version (1792408757368) was migrated in place: same rows and fetchedAt. Mutants for as_of returning the latest content and for dropped tombstones are caught. The derivation rule now lives in `venue/sources/derived.md`, and `ingest/events.py` implements it as a pure function for C5.5's differential test.
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
  - DefiLlama emissions (the unlock candidate): both endpoints return 402, paid only, so it fails C5.1 (see Blockers).
  - Rules fixed in `venue/sources/`. The live recorder `ingest/sources_record.py` runs detached from 10:26 UTC (`data/sources_live`).
- 2026-10-19: GPT is available again (10:11 UTC). Its stage 4 review exposed an N-undercount. Strategy identity hashes params by name, not value, and the gate deduplicated candidates by strategy hash, so parameter variants collapsed into one trial. The gate now keys trials by (strategy, params), and the exact submitted program lives on each experiment row instead of on strategies. No campaign had run yet.
- 2026-10-19: Stage 3 harness isolation probe (`data/stage3/isolation-s70v`). Reads outside the workspace, `ls /`, chained commands and WebFetch were denied or absent. The daemon log matched its 2 calls. Deviation: Claude Code allows read-only shell commands on workspace files (`cat brief.md`) as equivalent to the permitted Read, so in practice Bash is not limited to `./mm-agent`. The bwrap filesystem (`gate/tests/test_sandbox.py`) is the real boundary. Found and fixed: the agent CLI had inherited the operator's stdin, which leaked harness text into its prompt; stdin is now /dev/null.
- 2026-10-19: Null parameters frozen in `gate/nulls.json` (sha256 ebc7928421f5daab9447eac7149529996b06b915c4f80ed36cb03c8d1df6dddb), fit to search-part version 1792385868856. Spec changes made before freezing, after the first fit: GARCH ω by variance targeting (the raw fit overstated volatility 2×); funding and premium by joint block bootstrap of real data (an AR(1)-t fit was degenerate: about half of real hours sit exactly at the 1.25e-5 floor); the planted signal centered on that floor.
- 2026-10-19: The mutants now live in `kernel/mutants/mutants.py` as exact-match edits applied to a fresh copy of the working tree. Hand-kept patches went stale with every kernel change. All 9 are still caught.
- 2026-10-19: C1.1 met. `kernel/mutants/run.sh` catches all 9 mutants (I1–I9), each by its named test, with the clean tree passing every one. The first runs falsely reported 3 misses: `rsync -a` kept old mtimes, so the shared cargo target reused the previous mutant's build.
- 2026-10-19: The C1.7 canary exposed an I9 flaw. The $10k order cap was checked at the fill price, but an order is sized at the decision price. It is now checked at the decision price (recorded on every fill). The first leak program (0.08 per coin) reached Sharpe 19.6 < 20 because compounding made the cap bind. Sized at 0.005, the leak reaches about 200 and honest runs about −5.
- 2026-10-19: Commit 855260e (`criteria: stage 1`) also carries an unrelated 3-line witness.py fix (the zero-trade fill bar), swept in by `commit -a`. The criteria text in it is unaffected. Criteria commits now stage PROGRESS.md only.
- 2026-10-19: U = BTC ETH SOL SUI kPEPE TIA WIF AAVE FTM(delisted) WLD POPCAT BNB (`data/universe.json`). Survivorship: 10 delisted eligible perps lack full daily bars in the ranking window (MATIC 10/30, about $51M extrapolated vs. the #12 cutoff of $213M; RNDR had been renamed RENDER; the other 8 are micro-caps with 0 bars). None plausibly ranks top 12.
- 2026-10-19: The holdout rule (nothing reads `data/holdout/`) means C0.2/C0.5 for the holdout part of W run on the fetched frames at ingestion, before the split-write, and report counts only. The search part is also checked through the real `as_of`.
- 2026-10-19: `nix develop` verified (cargo 1.95, rustc 1.95, python 3.13, arch 8.0.0, sqlite 3.51); flake.lock committed; GPT 6.1 Sol reachable.
