# Pre-registered criteria (audit record)

Every stage's exit criteria as frozen, with every dated revision and labeled amendment beneath the criterion it
changes. Append-only, never pruned or edited (CLAUDE.md). Moved verbatim from PROGRESS.md on 2026-10-23; before
that, git history of PROGRESS.md holds them.

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
  - *Amendment 2026-10-22, after a dry C1.4 run failed on the second fetch (human decision; a labeled amendment, not a pass of the original).*
    - **What failed.** `mm` resolved each key to its latest revision fetched by the version, then delivered it at that revision's knownAt. `as_of` filtered knownAt ≤ t first, then took the latest. The second fetch had written 24 funding revisions identical in content to the first fetch's, differing only in a knownAt that C0.3's revised rule moved later. So `as_of` still showed the first fetch's revision, under the superseded rule's knownAt, and the witness traded on it.
    - **The amendment.**
      - A revision stores only what was observed: the values, the venue's reported time, fetchedAt, source, and a content hash over them. It never stores knownAt.
      - knownAt is computed from those fields by the rule that the store's bound `policy.json` pins: funding at max(hour + δ, reportedTime + `settlement_latency_ms`), a bar at eventTime + δ, a derived event count at eventTime, and a raw source revision at fetchedAt. The rule is `ingest.store.known_at` in Python and `known` in `market.rs` (they are in two languages, so the rule is written once in each). `reference/tests/test_resolution.py` checks that the two resolve a store alike, knownAt included. A stored knownAt column from earlier files is never read.
      - `as_of(t, version)` is, per key, the latest revision fetched at or before the cutoff, unless a tombstone, provided its knownAt ≤ t. This is exactly what `mm` delivers. A raw source's content live at t (C5.2) is `as_of(t, t)`.
      - A write appends a row only if its observed content differs from the key's latest live revision.
      - The boundary tests and the 1,000-time property test are kept, restated under this definition.
    - **Why it cannot increase false discoveries.** An earlier revision is never shown while a later one exists at the version. The rule's knownAt is never earlier than the first fetch's: max(hour + δ, reportedTime + 60 s) ≥ hour + δ. So data only becomes available later.
    - **Re-run under it.** C0.5's `as_of` view is recomputed (`audit/stage0/replay-as-of-amended-1792613363942.json`). It has 23 failures in 36,925 pairs (99.94%): the 12 from before, plus 11 coins at the 2025-07-27 12:00 UTC settlement, which was stamped late. The dry C1.4 on the second fetch now passes.
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
  - *Revision 2026-10-21, after the C0.3 and C0.7 results on the window [2026-10-20 07:39:41, 2026-10-21 07:39:41) UTC were read (applies to both). GPT reviewed the draft, and this is its one revision. It is a post-result amendment: the original results stay recorded, and a pass under it is a pass of the amended criteria, not of the originals.*
    - **What was judged.** C0.3 found no late value: 0 failures, and every listed coin had 24 funding events and 6 bar closes. But its clock check read 14.4 s. C0.7 met coverage in all 44 cells (lowest 0.907). Seven cells exceeded the 3 bps median excess: TIA $10k buy 3.45 and sell 3.79, WIF $10k buy 3.15, and all four POPCAT cells (4.76, 4.95, 5.25 and 5.93).
    - **C0.3: the clock precondition was not established.** The check took the L2 response's `time` field minus the midpoint of the request's send and receive times. That field timestamps the book snapshot, possibly before the request, so it mixes snapshot age, clock offset and network timing.
      - If it had been stamped during each request with a constant offset, the intervals [time − received, time − sent] over the window's 31,406 polls would intersect. They do not: the largest lower end is −430 ms and the smallest upper end is −8,508 ms.
      - The window therefore did not demonstrate the clock precondition. Like the earlier windows whose polling preconditions failed, it does not qualify. This reading was made after the result was seen.
      - *Revised instrument:* the host's systemd-timesyncd NTP record, which the stage 5 recorder logs every 5 minutes on the same host.
      - *The requirement:* every logged |offset| in the window is under 1 s; readings bracket both ends of the window, with no two consecutive readings more than 10 minutes apart; and the logged values change at least every 40 minutes, so each reflects an NTP exchange no older than the daemon's longest poll interval (34 min 8 s).
      - The smallest margin between a value's first observation and its knownAt is reported beside the offsets.
      - On the spent window the largest |offset| was 53 ms over 288 readings (43 distinct exchanges), and the smallest margin was 108 s.
    - **C0.7: the 3 bps median-excess limit is replaced, which changes what is measured.**
      - History has no books, and a 24 h window holds about 6 bars per coin, too few to fit a model conditioned on bar features. So the model is a constant per (coin, side, size).
      - Treating the spent window as development data: within that model class, for POPCAT even the constant at the test period's own 90th percentile overstates the test median by 3.85 to 4.74 bps. So no constant met both original limits. The original limit bounded absolute median accuracy, and that bound is given up.
      - *Revised limit:* in each cell, the model cost is at most 3 bps above q90_test. q90_test is the ⌈0.9 n⌉-th smallest test-period cost, with unfillable snapshots counted as infinite. It is the least constant that would have covered 90% of the test snapshots. The limit bounds the model's conservatism beyond what 90% coverage needs, and it is used for scoring only, never to refit.
      - Unchanged: the model (95th percentile of the first 70% of the cell's snapshots in time order, as the order statistic numpy's `method="higher"` gives), coverage (≥ 90%), sizes, sides, fee exclusion on both sides, unfillable snapshots as coverage misses, and the FTM rule.
      - Each cell's original median excess is reported beside the revised statistic.
      - Overstated costs lower net PnL along a fixed execution path. Because sizing depends on equity, this is not claimed as a bound on a full replay.
    - **Standing rule (human decision 2026-10-22, CLAUDE.md §3).** After a criterion fails, it may be amended only if the change cannot increase false discoveries, and the amendment is labeled as one. Both changes qualify.
      - The C0.3 change replaces an instrument that measured the wrong quantity. The clock requirement itself is unchanged.
      - The C0.7 change relaxes the median-excess limit, which only bounds how far the model overstates costs. Coverage (the model is at least the observed cost in ≥ 90% of snapshots) is unchanged. An overstated cost lowers every strategy's net return, so it can only make strategies harder to pass, never easier.
    - **Evidence.** Both criteria are judged on new evidence only: the first window, under the unchanged committed window rule, that counts from the recorder's restart after the second backfill. That restart comes after this commit. The backfill sets the timing only, because it needs the rate budget alone. The restart time is recorded in `ingest.availability.RECORDING_FROM`. The first completed qualifying window is the judged window, whatever its result. The spent window's data are not used for judgment.
  - *Amendment 2026-10-23 (human decision), before any result of the window it governs was read (applies to both C0.3 and C0.7; a labeled amendment):* a gap of more than 10 minutes in the NTP clock log restarts the window, like an L2 gap. The current window started at 2026-10-22 19:37:32.79 UTC, when the HL recorder returned from an outage. The clock log's readings around it are 18:57:53 and 19:37:39.59, so they did not bracket that start within 10 minutes. The window now starts at 19:37:39.59 and ends 2026-10-23 19:37:39.59 UTC (`ingest.availability.window`, with `test_a_clock_log_gap_restarts_the_window`). It only demands more evidence, so it cannot increase false discoveries.
  - *Amendment 2026-10-23 (human decision), before any merged window starts (applies to C0.3 and C0.7 and to any later window judged on recorded L2 snapshots; a labeled amendment). The current window, ending 2026-10-24 06:09:58 UTC, is judged on the local recorder alone, as frozen.* From the first window that starts after the second (cloud) HL recorder has run with its clock logged for 24 h, the window's L2 series per coin is merged from both hosts:
    - **Tagging.** Every snapshot carries its host: `local` (this PC) or `oci` (the cloud VM). It also keeps that host's own send and receive times; times are never shifted between hosts.
    - **Clocks.** Each host's NTP record meets C0.3's clock requirement over the window: every |offset| under 1 s, readings bracketing both ends with no two more than 10 minutes apart, and values changing at least every 40 minutes. A host failing it contributes nothing to that window, which is then judged on the other host alone.
    - **Deduplication (pre-registered).** Per coin, snapshots are grouped by 30-second poll slot, floor(send time / 30 s). In each slot the `local` snapshot is kept if there is one, else the `oci` one. Within one host, the earliest send time is kept, ties broken by file order.
    - **Gaps.** A gap is counted only where the merged, deduplicated series has no snapshot within the limit (60 s), so a gap restarts the window only if neither host covered it. A clock-log gap restarts the window for that host's contribution.
    - **What changes.** Only which snapshots are judged. Thresholds, the cost model's construction, coverage and every other C0.3/C0.7 rule are unchanged, and each judged result reports how many snapshots came from each host.
    - **Why it is not judged on the current window.** Bridging one host's outages lets more windows qualify. The human approved that, with the conditions above, for windows that start after this amendment.
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
  - **Amendment (2026-10-23, human decision; labeled as an amendment, not a pass of the original).** The market is a martingale: log returns are Gaussian with σ = 2% and mean −σ²/2, so a bar's expected price change is zero. The threshold stays at 4. Seed 12549401516693113639 joins the fixed seeds (6 fixed, 5 drawn). Why: Gaussian log returns with zero mean give each bar an arithmetic mean of exp(σ²/2) − 1, an edge any long-biased program harvests (a constant long averaged Sharpe 1.47, sd 0.77, over 300 seeds), and on that seed every constant-weight case reached 4.258 without reading any data. On the martingale market the same program averages −0.15, sd 0.77. C1.7 is judged only on runs after this amendment: `audit/stage1/c17-amended.txt`.
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
  - *Revision 2026-10-20, after the locked run v1 failed and before any C2.4 run (calibration v2). GPT reviewed the draft, and this is its one revision.*
    - **What failed.** Locked v1 (`audit/stage2/holdout-size-locked.json`) passed 52 of its 54 judged pairs. sparse/540 and sparse/546 failed at u = 0.05: rates 0.0595 and 0.0602, with upper bounds 0.0648 and 0.0656 against 0.0625. That is a failure to certify the registered bound, not proof that the true rate exceeds it. The run stays recorded as a failure.
    - **What development showed afterwards (post-v1, reported only).** Three sparse generators were added at the three lengths (`audit/stage2/holdout-size-development-v2.json`):
      - sparse10: P(flat → active) = 1/36, P(active → flat) = 1/4, i.i.d. t₅;
      - sparse5: 1/76 and 1/4, over the GARCH-t₅ latent;
      - sparse5_long: 1/228 and 1/12, over the GARCH-t₅ latent.

      Under the v1 calibration, sparse10/540 rejects 0.060 at 0.05 and sparse5/540 rejects 0.065, so the oversizing is real and reproducible. The long-episode cell rejects 0.045, so short active bursts are the hard direction. The explanation (few active episodes) is a hypothesis these runs support, not a proof.
    - **The v2 test.** The raw p-value is unchanged.
      - **The calibration table.** It is now the 18 v1 development cells, byte for byte with the same seeds, plus the 9 development-v2 cells: 27 cells of 4,000 series, in `gate/holdout_calibration.json` with its new sha256 in the Log.
      - **The calibrated p.** It is the maximum, over the 27 cells, of (1 + #{p_raw ≤ observed}) / 4,001.
      - **The cost.** In development, a Gaussian series rejects about 0.023 at 0.05.
      - **The minimum attainable calibrated p.** It is 0.0015, so Holm can reject only in a campaign with at most 33 finalists. Every campaign reports its finalist count against that limit.
    - **The activity floor (a scope rule, not a coverage claim).** A finalist's holdout series is untested, and gets p = 1, when it has fewer than ⌈0.05 n⌉ steps whose stored net return is not exactly 0.0 (27, 28 and 54 at n = 540, 546 and 1,080).
      - A floored finalist stays in its campaign's frozen Holm family with p = 1. Raising a p-value can never add a rejection.
      - Every finalist's nonzero-step count is reported.
      - The floor does not make sparser or otherwise uncovered series valid. It only marks where the calibration's evidence stops.
      - A non-finite return in the series is an implementation failure, not a result.
    - **What a pass means.** The calibrated p is a Monte Carlo p-value against each development generator. Its guarantee averages over the calibration draws and is not conditional on the committed table. A locked pass supports only the measured rejection bounds for the locked generators, at the judged levels. It does not show superuniformity at every Holm level, or validity for return laws outside these families or conditional on search. Paper §8's sentence on asymptotic validity is narrowed to match.
    - **Locked suite v2.** Its id is `holdout-calibration-locked-v2`. It uses the same three lengths, 20,000 series per cell, levels, limits and confidence (K = 54, 1 − 0.05/54). Its generators were chosen after seeing v1's failure and the development-v2 results, but before any v2 locked draw, and none is a development generator:
      - long-episode sparse: P(active → flat) = 1/12, P(flat → active) = 1/160 (about 7% active, mean episode 12), active returns from a GARCH(1,1) with α = 0.08, β = 0.9 and t₄ innovations;
      - very sparse: P(active → flat) = 1/4, P(flat → active) = 1/129 (about 3% active), active returns i.i.d. t₄, so most series fall under the floor;
      - rare loss: i.i.d. 0.1 + N(0, 1), minus 20 with probability 0.005 (mean 0, negatively skewed);
      - noisy sparse: N(0, 0.05²) at every step plus sparse10-style t₅ bursts (1/36, 1/4), so the floor never applies;
      - endogenous exposure: the GARCH-t₅ latent of the development generators, active exactly when its conditional variance exceeds 1.5;
      - persistent: Gaussian AR(1) with φ = 0.8.

      Every chain starts from its stationary distribution, and every GARCH has initial variance 1 and 500 burn-in steps. A series under the floor counts as a non-rejection, as in the gate. The per-cell floor rate, the rejection rate among eligible series (a diagnostic only), and the realized activity are reported beside the judged unconditional bounds.
    - **Failure handling.** A crash, a missing series or an incomplete cell invalidates the run, which is then rerun under a new id and logged; series are never dropped. A failed v2 run stays recorded as a failure, and any v3 needs a new locked suite. The 95% confidence holds for this v2 suite alone, not jointly across redesign attempts.
  - *Revision 2026-10-21, after the locked run v2.1 failed and before any C2.4 run (calibration v3, human decision of 2026-10-21).*
    - **Why v2 cannot be repaired.** The v2.1 failure is inherent, not a calibration defect. By Bahadur and Savage (1956), no test of a mean is both valid over every finite-mean distribution and powerful: small gains with a rare large loss look like a real edge whenever the loss is absent from the sample. Lengthening the holdout only moves that boundary, and it is not available for stage 3, whose holdout is fixed by the model's cutoff. No check aimed at that shape is added, since that would tune v3 to the suite that judged v2.1.
    - **The scope assumption.** Per-step net returns are bounded below by −B. The kernel lets equity go negative (a liquidation fills at the bar's adverse extreme, which can lie past the bankruptcy price), so the kernel adopts the venue's rule that losses are capped at account equity: when a step ends with equity ≤ 0, any position still held is liquidated, the venue absorbs the shortfall, pending orders are cancelled, and equity is 0 from then on. So B = 1. This is a kernel change. It lands before C1.4 or any judged run records the kernel hash, is stated as a Lean law and proved in the reference model, and `mm` aborts on any step return below −B.
    - **The test: testing by betting** (Waudby-Smith and Ramdas, 2024), for H0: E[r_t | past] ≤ 0 at every step. The tested series r_1..r_n is unchanged: the finalist's per-4h-step net return from the kernel over the holdout report window, every step included.
      - The bet: λ_1 = 0, and for t ≥ 2, λ_t = min(1/(2B), max(0, S_{t−1}/Q_{t−1})), where S_{t−1} = Σ_{s<t} r_s and Q_{t−1} = Σ_{s<t} r_s². Then λ_t = 0 when Q_{t−1} = 0. This is the aGRAPA plug-in (the Kelly bet μ/E[r²] estimated from the past), truncated at c/B with c = 1/2.
      - The wealth: K_0 = 1 and K_t = K_{t−1} (1 + λ_t r_t).
      - The p-value: p = min(1, 1 / max_{0≤t≤n} K_t).
      - Any r_t < −B, or any non-finite r_t, is an implementation failure, not a result.
    - **Why it is valid.** λ_t depends on the past only and lies in [0, 1/(2B)], and r_t ≥ −B, so 1 + λ_t r_t ≥ 1/2. Under H0, E[K_t | past] ≤ K_{t−1}, so K is a nonnegative supermartingale from 1. By Ville's inequality, P(max_t K_t ≥ 1/u) ≤ u, so P(p ≤ u) ≤ u at every level u. This holds for every distribution in H0, with any dependence, heteroskedasticity or sparsity, with no simulation and no table. It does not cover returns with a positive conditional mean at some steps. Those are predictable, so a strategy could exploit them, and they are not the gate's no-edge null. The gate's no-edge null makes every strategy's conditional expected net PnL ≤ 0 given F_open, and so satisfies H0.
    - **What changes.** The studentized bootstrap, its lag window, the calibration table (`gate/holdout_calibration.json`) and the activity floor are retired. Holm across the frozen finalists, α = 0.05, the net-return > 0 condition and the per-campaign error claims are unchanged. The smallest attainable p is 1/max K, so there is no fixed floor on p, and campaigns are no longer limited to 33 finalists.
    - **Power.** It is very low on any holdout of a few months, under this test or any valid one. When λ is capped, log K_n ≈ n (μ/2 − E[r²]/8). A finalist reaching p ≤ 0.05 needs a per-step mean of roughly 1% at n = 546, and even an untruncated Kelly bet would need an annualized Sharpe ratio of about 5. Zero promotions remains the expected outcome. Paper §8 is updated to match.
    - **Locked suite v3.** v2.1's suite has been seen, so v3 is judged on a fresh locked suite, `holdout-calibration-locked-v3`. Its spec is written independently of the test's code and implemented by GPT, given the spec alone. The spec requires null series with E[r_t | past] = 0 and r_t ≥ −1, at the lengths 540, 546 and 1,080, including bounded-below heavy-tailed series and rare-loss series at the stage 3 holdout length. GPT may add two adversarial generators of its own within that class. The levels u, the limits (Clopper–Pearson upper bound at confidence 1 − 0.05/K ≤ 0.0625, 0.015, 0.01), the 20,000 series per cell, the seeding from SHA-256 of the suite id and the cell, and the failure handling are as in v2. The suite and its generators are committed before the run. A failed v3 run stays recorded as a failure.

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
- *Revision 2026-10-23, before any stage 3 campaign run or inspection of holdout results (human direction of the same day: weigh a later start against extending forward, and choose per the paper; revised once after GPT's review).* The window above starts the month after the model's knowledge cutoff, a margin of zero. Paper §12 asks for a generous margin, because cutoffs are imprecise and later fine-tuning can leak later information.
  - **Window.** The stage 3 holdout is [2026-11-01T00:00:00Z, 2027-01-31T00:00:00Z), for both arms: 91 days, 546 scheduled 4h decision intervals, the horizon used in length calibration v3.
    - It leaves four months between the end of the model's stated June 2026 knowledge cutoff and the holdout start. That buffer reduces possible overlap with training, but does not prove all training or later fine-tuning predates the holdout.
    - The exact served model version, and any known later training exposure, are recorded before the campaign.
  - **Why this window.**
    - It starts strictly after the last order book used to fit or validate C0.7's execution table (the stage 0 window ending 2026-10-24 06:09:58 UTC) and after that table's freeze. Searches use that table, so a holdout overlapping its data would let holdout-period information reach selection.
    - Rejected: [2026-08-01, 2026-09-30) keeps a one-month margin but shortens the horizon to 60 days, which is uncalibrated, with lower power.
    - Rejected: [2026-09-01, 2026-12-01) overlaps the execution table's data, and no table fitted before September can exist, since order books were first recorded in October.
    - Preserving the horizon does not by itself establish validity for a different placement.
  - **Search and embargo.** The search period [2024-09-30, 2026-04-03), its dataset version and U are unchanged. Neither arm receives observations, results or derived information from [2026-04-03, 2026-11-01), and none from the holdout before both arms' finalists are frozen. The reserved `data/holdout/` [2026-04-03, 2026-09-30) is not used by stage 3 and stays unspent.
  - **Holdout construction.** The holdout is fetched by the stage 0 backfill no earlier than 2027-01-31T00:00:00Z + δ.
    - Before the fetch, δ, timestamp conventions, source precedence, revision handling, retry rules and completeness criteria are fixed in a hashed ingestion specification. The rules for listed intervals and delistings are fixed for U.
    - The holdout has its own immutable manifest and content hashes. It is written only to a holdout store, never to the search store or any default dataset resolver.
  - **Integrity and failures.** The holdout is checked with C0.2's coverage and integrity rules.
    - Detailed checks and ingestion logs stay unavailable to either arm, and to anyone able to change their selections, until both finalist sets are frozen.
    - A failed check never authorizes a changed universe, a shifted or shortened window, a replacement source or another campaign. Completion attempts are allowed only under the frozen ingestion specification; otherwise the campaign is blocked and the failure reported.
  - **Live recordings.** Live polls covering the embargo or the holdout, and every summary or derivative of them, are excluded from stage 3 research and selection.
    - The agent never sees them. Whoever can change the brief, strategies, universe, execution assumptions or finalists inspects them for integrity only (status, sizes, hashes, gaps), never prices or returns, and records any other access.
    - Stage 0's availability and execution judgments, which use the window ending 2026-10-24, are the only result-bearing use. They precede the holdout and are disclosed here.
  - **Null calibration.** C3.2 uses exact half-open decision-index intervals reproducing the real geometry: search [0, 3300), embargo [3300, 4572) and holdout [4572, 5118), in 4h steps on an 853-day market. This replaces "day 640 of 730", and the execution-model treatment is the real campaign's. C3.2 remains a 20-campaign smoke test, not a general error-control guarantee.
  - **Release.** The real campaign starts only after C3.1, C3.2 and the procedure freezes. Both arms and both finalist freezes precede one primary holdout evaluation and release. Primary promotion decisions are committed before the twice-cost and coverage diagnostics are released or used, and the diagnostic methods are fixed before the holdout is accessed.
  - **Error claims.** This revision is made without any holdout feedback and authorizes no further campaign or holdout opportunity. Holm claims remain per arm, so across both arms the union bound is twice the per-arm level. Moving the holdout later reduces possible overlap with training; on its own it does not prove an unchanged false-discovery probability, which still rests on the validity of the whole registered holdout procedure.
  - **Timing.** The real run waits for the fetch after 2027-01-31 (early February 2027).
- *Revision of that revision, 2026-10-23 (human decision, before any stage 3 run: optimize for fast iteration where rigor permits); it replaces it.*
  - **Holdout.** The stage 3 holdout is [2026-08-01T00:00:00Z, 2026-09-30T00:00:00Z), for both arms: 60 days, 360 decision steps, taken from the reserved `data/holdout/`, which no search has touched.
    - It leaves a one-month margin after the model's stated June 2026 knowledge cutoff.
    - It ends before the October data the C0.7 execution table is fitted on, so no data the searches use falls in or after the holdout's own period.
    - The embargo is [2026-04-03, 2026-08-01): neither arm sees results from it. The search period, its dataset version and U are unchanged.
  - **Validity at this length.** The betting test is anytime-valid, so its level holds at 360 steps. The v3 locked suite judged other lengths; this one is not separately calibrated.
  - **Expected power, stated.** It is close to zero.
    - For one finalist (no Holm), per-step net returns simulated as normal with the gate's own `holdout_pvalues`, 4,000 series per cell: the rejection rate at p ≤ 0.05 is 0 at 360 steps for an annualized Sharpe ratio up to 20 at a per-step volatility up to 2%. It is 0.006 at a mean of 1.07% per 4h step (volatility 5%), and 0.94 at 2.14%.
    - At 546 steps the same means give 0.33 and 1.0.
    - At the bet cap, reaching p ≤ 0.05 needs a mean net return of about 1.66% per 4h step at 360 steps, against 1.1% at 546.
    - Zero promotions is therefore the expected outcome.
  - **What the campaign is.** The real campaign is a pipeline validation run, not a test for edge. It checks that the agent harness, the ledger, the gate, the mechanism check and the holdout release work end to end on real data, under the error control they claim. This label appears in these criteria and in every stage 3 report and result file, and no result is described as evidence of edge or its absence.
  - **Null calibration.** C3.2 mirrors these lengths on its 730-day null markets: search [0, 3300), embargo [3300, 4020) and holdout [4020, 4380), in 4h decision steps. Its holdout is reported from day 670, replacing "day 640 of 730".
  - **Later confirmation.** The forward window [2026-11-01, 2027-01-31), after the execution table's data, is kept as a later, separate confirmation for anything this campaign promotes, under the ingestion, access and release rules of the replaced revision. It does not block stage 3.
  - **Kept from the replaced revision.** The live-recordings exclusion, the release order, and per-arm Holm claims (union bound twice the per-arm level) all still apply.

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

- *Amendment 2026-10-22, after C5.3 failed as written for Discourse (human decision; a labeled amendment, not a pass of the original).*
  - **What failed** (`audit/stage5/sources-availability-full-recording.json`). The knownAt rule held for every observed item (36) and edit (12). But one NTP reading was −4.9 s, and realized poll gaps reached 200 min. A strict reading of "polls every 5 minutes" also fails on jitter alone: the median gap is 300.03 s.
  - **The amendment.** Discourse is classified *prospective only*. Its claimed times are never admitted, and an item is known 60 s after its earliest observation (fetchedAt + 60 s). Snapshot is unaffected: prospective, known at its earliest observation.
    - For prospective sources, C5.3's polling, clock and reconciliation figures are reported, not judged.
    - C5.6 is vacuous for both sources: their counts lie in the forward holdout, so the search part has none to replay.
    - The derivation keeps only the prospective rule (`venue/sources/derived.md`).
  - **Why it cannot increase false discoveries.** No historical replay is admitted. A later knownAt, and items known only from our own observation, can only remove information a strategy could use.
- *Clarification of that amendment, 2026-10-22, after GPT's pre-exit review found its justification incomplete (it adds requirements and relaxes none).*
  - **The system-level argument.** Every derived event row lies after the holdout boundary, so the search store carries no event dataset. Any search program naming `forum_posts` or `gov_proposals` is refused with R_INPUT_UNAVAILABLE before it runs (L5, `kernel/mm/tests/events.rs`). So the inputs cannot enter any search, selection or N, and the holdout step evaluates only finalists from search. They cannot contribute to any discovery until a search store binds them.
  - **C5.6 is deferred, not passed.** It must be met before any search store carries an event dataset. `criteria/test_stages3to5.py` fails if one does without C5.6's evidence.
  - **Causal coverage.** The derivation's coverage depends only on polls up to each hour (C5.5 fix, `derived.md`), so missingness carries no later information.
  - **What C5.3 keeps for prospective sources, judged:** a recorder running from its first start until stage 5 exits, for at least 72 h, with an uptime and gap log; clock offsets logged; and a reconciliation report.
  - **What it reports without judging:** the polling cadence, the 1 s clock threshold, the claimed-time rule's 100% and its fresh-segment clause. Those last two govern admitting claimed times, and none is admitted.
  - **Terms.** A source binds only under the terms rule (Log, 2026-10-22), and data from forums whose terms do not permit our use is deleted.

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
- *Revision 2026-10-20, while proving L3 and before any L3 proof:* L3_rewrite is false over an arbitrary lawful `NumOps`.
  - **Why.** R v1's obligations hold on finite operands. The model, like `mm`, stores every node value through `finite` except `hours_since` and `xs_rank`. Take a lawful structure whose `ofInt` is non-finite, and x = hours_since(…). Then `neg(neg x)` is Undef while x is defined, and `negNeg` changes the weight downstream of it.
  - **The fix.** The model filters those two outputs too. In binary64 they are always finite, so the filter is the identity on every value `mm` produces, and no binary64 behavior changes. The differential test now runs an `hours_since` program bit for bit. SEMANTICS.md §1 and §4 say so. L2_units' proof is updated, and no law statement changes.
- *Revision 2026-10-20, while proving L3 and before any L3 proof:* L3_rewrite's `p'.WF` is false for a WF program with a unit of other than six exponents.
  - **Why.** The model's `Dim` is a list, and `Dim.zip` truncated to the shorter one. So with a seven-exponent u, `mul(x, 1)` had a six-exponent type, and redirecting its users to x broke their typing. L3 assumes only `p.WF`, which never fixes a unit's length.
  - **The fix.** `zip` is now undefined for units of unequal length, as for the engine's fixed `[i8; 6]`. Every unit the checker produces has six exponents, so no verdict or run changes, and the differential tests agree.
- *Chronology note, 2026-10-23 (GPT's review read "before any Lean or Bend code existed" against `bend.md`'s local dates):* in UTC, the stage 6 criteria were committed at 2026-10-20 01:43 (`1ebc588`), the first Bend file at 03:00 (`761e2e5`), and Lean's laws were frozen at 03:13 (`cb095f7`), before the first proof at 03:24 (`7180965`). `bend.md` now gives UTC times.
- *Amendment 2026-10-23, after C6.1 and C6.5 were found unmet as written for Bend's statements and for effort (a labeled amendment, not a pass of the originals):*
  - **C6.1 for Bend.** Bend's formal statements were never frozen with GPT's review. Over an abstract number structure the laws cannot be stated in a form `--verdict` accepts (`761e2e5`). The concrete-type L5 statement of 2026-10-22 was written with its proof and never reviewed. So C6.1 is judged for Lean, whose statements were reviewed and frozen before any proof. Bend's L5 is reported as a successful verdict run (`bend-l5-verdict.txt`, `bend-l5-translated.md`), not as an accepted law.
  - **C6.5's effort element.** Per-milestone active agent time and retries were not instrumented while the work ran. They are reported as a proxy recovered afterwards (`audit/stage6/effort.py`): session activity over commit intervals, with commit and revision counts from git, and the limits stated. The element is unmet as written and is amended to that proxy.
  - **Why neither can increase false discoveries.** Bend is not adopted, so its statements govern no evaluation. Effort, by C6.5's own rule, changes neither the ranking nor any decision.
- *Revision 2026-10-23, recording a change of 2026-10-21 that took no dated revision at the time (found by GPT's stage 6 review):* conversion nodes are interned by (factor bits, target unit, argument). Before commit `5f2b538` (2026-10-21, the checker hole fixed in `mm` and the Lean model together, authorized as a kernel change), they were interned by (factor bits, argument). `SEMANTICS.md` §5 now says so. No proof depended on the old interning, and every C6.4 run is on the fixed behavior.
- *Revision 2026-10-21, with the I10 kernel change (stage 2 calibration v3, human decision of 2026-10-21):* the engine and the model now cap losses at equity. A step whose equity after margin and delisting is not positive liquidates what is still held at the adverse extreme, and the venue absorbs the negative balance. An order due at such a step is unfilled. The return is e1/previous − 1 while both are positive, −1 at the bankruptcy, and 0 after it, and a return below −1 aborts with R_BOUND. Accounting now fails on a non-finite difference.
  - **L4_orders.** As frozen, an order whose bar traded is filled. That is now false at a bankrupt step. The iff now also requires that the run's equity at the order's due step is positive. The rest of the law is unchanged, and an Unfilled record still resolves every due order exactly once.
  - **L6_bounded (new).** For every `NumOps` satisfying `NumOps.Bounded` (four facts that hold in binary64), no run aborts with R_BOUND. So every recorded return is ≥ −1.
  - Every other law's statement is unchanged; the proofs were updated for the new step. Runs are unchanged bit for bit on every program whose equity stays positive, which is all of the differential corpus.

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
- *Revision 2026-10-23 (human decision; before the freeze, any session or any registered thesis): builder-deployed (HIP-3) markets are marked at the venue's mark price.* Their trade candles have hours without trades, and on those hours "missing bars never cause an earlier price to be used" left theses unresolved.
  - **Request types.** The exchange adapter also permits `metaAndAssetCtxs`, a public, read-only request that returns each market's mark price. All other "Exchange reads" terms are unchanged.
  - **Recording.** From the freeze on, the track records every builder dex's `metaAndAssetCtxs` once an hour, sent at H + 5 s, with send and receive times, as an append-only archive. mark_m(H) is market m's `markPx` from the earliest sample sent in [H, H + 5 min) and received by the time it is used. If there is no such sample, mark_m(H) is missing.
  - **Hourly bars of a builder market.** The 1h bar opening at H is (open, close) = (mark_m(H), mark_m(H + 1 h)). It exists only when both marks exist and H + 1 h has passed. Every rule above that uses 1h opens or closes (entry, invalidation, exits, the funding mark, `markets`) therefore uses marks for these markets. A missing mark gives a missing bar, which never causes an earlier price to be used.
  - **Unchanged.** Core markets keep their 1h trade candles. Daily bars, eligibility (90 completed daily bars), base rates and the `prices` command keep daily candles for every market. SCORING.md's input is still hourly bars, so C10.3's fixtures and C10.4's independent scorer apply as judged. New fixtures cover the mark-bar construction: the sampling window, a missing mark, a sample received late, and a bar whose closing mark is missing.
  - **No backfill.** The venue's API keeps no history of marks, so a builder market has hourly bars only from the start of recording; no earlier mark is reconstructed.
- *Revision of that revision, 2026-10-23, after GPT's review and before the freeze; it replaces it.* Builder-deployed (HIP-3) markets use sampled venue mark prices as hourly reference prices. Core markets keep 1h trade candles. Daily candles remain the input to eligibility, `prices`, base rates and the benchmark's direction.
  - **Request types.** The exchange adapter also permits the public, read-only `metaAndAssetCtxs`; every other "Exchange reads" term is unchanged.
  - **Sampling.** For every builder dex and hour boundary H, a request is sent at H + 5 s. Every attempt is archived append-only with its dex, send time, complete-receipt time and the response.
  - **Sealing.** The reference for H is sealed at H + 5 min.
    - **Candidates:** samples sent in [H, H + 5 min) and completely received by H + 5 min.
    - **Selection:** the earliest send time, ties broken by archive order. M_m(H) is market m's finite, positive `markPx` in that sample. If there is no candidate, or the selected sample lacks a valid mark for m, M_m(H) is missing; no other sample substitutes for one market.
    - **Finality:** a sealed reference, present or missing, never changes, and late responses are kept but never used.
    - **Meaning:** M_m(H) is a post-boundary sample assigned to H for paper accounting, not the venue's mark at exactly H and not an executable price. It is available at H + 5 min.
  - **Opening references and bars.**
    - M_m(H), once sealed and present, is the opening reference for H on its own. The bar opening at H has open M_m(H), and close M_m(H + 1 h) once that is sealed and present; until then its close is null.
    - A missing later mark never erases, moves or invalidates an earlier opening reference or fill.
    - Entries, horizon exits and discretionary exits use opening references exactly as they use 1h opens. Each is committed before its boundary H, so its fill uses no later information.
  - **Decision inputs.** A price informs a decision only once it is available.
    - **Sizing:** E_r uses, for each builder leg, references available by t_r (an opening reference from H + 5 min, a close from H + 1 h + 5 min).
    - **Invalidation:** for a bar ending at B, the check runs once every leg's closing reference is available, and the actionability time is the later of B + δ and that availability. With a 5-minute seal this still selects the next opening boundary, and the open simultaneous with the invalidating close is never used.
  - **Funding.** Funding at hour h is valued at M_m(h). If M_m(h) is missing, the latest earlier reference is used, the same convention core markets have, and it is stated as such. Funding is a paper accounting entry, never a decision input.
  - **Prolonged gaps.** If no opening reference exists between entry and the horizon (e ≥ x), the thesis is unresolved. This holds for every market, and SCORING.md states it.
  - **Snapshots.** Every market and price snapshot includes only references available at its cutoff. The full no-reading agent receives the main session's identical snapshot, and the conditional ablation's cutoff is t_r.
  - **Daily-history exception.** Eligibility does not imply any hourly mark history before recording began. A builder market's base rate is a daily-candle historical comparator for a mark-referenced live outcome, not a historical reconstruction of it, and reports say so.
  - **No backfill.** No reference is reconstructed before recording began.
  - **Scoring.** SCORING.md's hourly rows may carry a null close. Its mark rule skips null closes, and e ≥ x leaves a thesis unresolved. GPT implements the revised SCORING.md afresh, and C10.4 is judged again on its 1,000 sets, with the generator covering null closes and builder markets. New C10.3 fixtures cover:
    - sealing: out-of-order receipt, receipt after the seal, ties;
    - an opening reference whose next mark is missing;
    - a valid reference after a missing one;
    - invalidation awaiting its closing reference;
    - sizing at a t_r inside a seal window;
    - funding with a missing reference;
    - a mixed core and builder spread;
    - e ≥ x.
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
  - *Revision 2026-10-23 (human decision; before the freeze, any session or any registered thesis): a descriptive outcome-market baseline.* Polymarket's public market prices and resolutions are recorded every 3 h from 2026-10-23 (`venue/sources/polymarket.md`). A thesis may name one Polymarket market at registration as its outcome market. The report then shows that market's latest recorded price at or before t_r, and its resolution, beside p. The comparison is descriptive only: a Polymarket question rarely states the thesis's exact outcome, so no Brier or skill score uses it, and theses without a named market are unaffected.

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

### Stage 7: sources as a language feature

Frozen 2026-10-23, before any stage 7 code. GPT reviewed the draft, and this is the one revision.

**Scope.** Paper §5 and roadmap item 7. A data source is a typed declaration; a feed binds to it only through a certificate issued by the certification verifier and recorded in the ledger. Every existing feed moves onto declarations, and the per-feed code paths they replace are deleted.
- **Ordering.** Implementation begins only after stage 5 exits (done 2026-10-23) and the pilot's judged runs that record a kernel hash are complete: C1.4, the stage 2 sweeps, stage 3's campaigns and stage 4's swarm smoke. The baseline commit, build hashes and baseline outputs (C7.4) are recorded before implementation.
- **Supported subset.** Fields are numeric with a unit in the frozen DSL unit grammar. The entity domain is the run's coins, reached through a certified entity mapping. Enum fields, non-coin entity types and many-to-many relationships are out of scope for stage 7, recorded as a gap from the paper. A declaration using them is rejected explicitly.
- **Evidence rule.** Before the first judged run of any criterion, its baseline identities, fixture inventory, generation procedure, seeds, mandatory coverage classes, expected outcomes and comparison procedure are committed. Every selected case counts. A missing case, skipped test, crash, timeout or malformed output fails the criterion. A failed judged run stays recorded, and a rerun gets a new identity. Development runs are iterative and never judged.
- **Migrated feeds.** Their certificates keep the thresholds, applicability decisions, dated amendments and limitations frozen by stages 0 and 5. Stage 7 claims no new pre-registration for them, and a feed binds only for the scope its passing evidence supports. For a new feed, the declaration, feed specification, thresholds and applicability decisions are committed before any return-conditioned evaluation or selection involving it (choosing a mapping, keyword set, lag or coverage window by its correlation with returns counts as return-conditioned).

- **C7.1 Declarations.**
  - A declaration is a versioned, schema-validated file under `sources/`. It defines:
    - the entity-key domain;
    - each field's name, numeric type and unit;
    - missing-value semantics, where missing is never zero;
    - the cadence: a held grid with its period, or event aggregates fresh only at their tick;
    - the availability rule, in the C7.6 language;
    - the revision semantics.
  - Binding validates the feed against the schema and its certified mapping, and never coerces entities or units.
  - DSL input names are declared field names, unique across declarations.
  - No production code (ingestion, kernel, reference kernel, or generated code) selects typing, delivery, availability, revision or binding behavior by a concrete source, dataset or field identifier. Two checks show this:
    - a frozen registry, with every declared name and its programs renamed consistently, gives identical semantic outputs;
    - a scan finds no declared name as a literal in production code (supporting evidence).
  - A declaration is a contract, not evidence: a field's point-in-time validity comes only from certification (C7.3).
- **C7.2 Checking, binding and preflight.**
  - `mm check` types a program from the declarations alone, reading no feed, binding, certificate or store.
  - Every source a program names is in its required set: in the weight, in any let (used or not), in any branch, and in the prediction condition.
  - The market data the simulator itself uses (bars for fills and marks, funding for settlement) is also required to be certified.
  - Before any delivery or evaluation, preflight checks every required binding and certificate. A declared but unbound source gives `R_INPUT_UNAVAILABLE`; a binding without a valid, matching, in-scope certificate gives `R_UNCERTIFIED`.
  - A refusal emits no result-bearing output and is recorded through the ledger.
  - A bound feed with no observation for an entity and tick follows the declaration's missing and coverage semantics. It is never filled with zero, and an event value is never held past its tick.
  - Positive controls: the same programs, fully bound and certified, evaluate.
- **C7.3 Certificates.**
  - **Issuance.** Only the certification verifier issues a certificate, from an evidence bundle. The feed builder may submit evidence but cannot issue or assert a pass.
    - The verifier takes the required tests from a frozen applicability policy covering paper §5's six categories: terms, availability, revisions, entity mapping, coverage and extractor validation.
    - It recomputes every machine-checkable result and checks the integrity of external evidence: terms quotes per `ingest/terms.py`, blind labels with their labeler's independence recorded.
    - It rejects a missing, failed, unverifiable or empty-sample test. An inapplicability decision needs a justification of a frozen kind, which the verifier checks.
    - Each test has a frozen metric, predicate or threshold, sample procedure, minimum sample and evidence window.
  - **Identity.** A certificate pins:
    - the declaration and rule-language versions;
    - the feed specification and data-manifest hashes, and the dataset cutoff;
    - producer and transformation versions;
    - mapping and coverage artifacts;
    - the revision policy and upstream certificates;
    - extractor model and prompt hashes, where they apply;
    - evidence hashes and the verifier's version;
    - the certified entity, field and time scope.
  - **Availability.** Feed-supplied timestamps are not authoritative. The effective rule is the paper's: the later of the claimed-time rule, used only where the claimed time is protocol-enforced or server-set and a live test passed, and any independent witness. Rows without qualifying evidence are prospective-only. No rule backdates a later-observed revision.
  - **Lifecycle.** A change to any pinned artifact, or use beyond the certified scope, needs a new certificate. Supersession records are append-only. Earlier experiments stay reproducible, and new evaluations cannot use a superseded certificate.
  - Each run's identity records its certificate ids.
- **C7.4 Existing feeds migrated, behavior preserved.**
  - **Feeds.** Hyperliquid funding and premium, the 4h bars, `events_forum` and `events_governance` move onto declarations and certificates, bound for the scope their stage 0 and stage 5 evidence supports. Insufficient evidence is a blocker, not a pass.
  - **Derived feeds.** The event counts are versioned transformations with declared upstream dependencies (raw observations and polls). A derived value is available no earlier than its latest required input plus its processing delay. The per-feed code paths are deleted: `EVENT_INPUTS`, the per-input enum variants, and the per-dataset branches in `market.rs` and `ingest/store.py`.
  - **Derived fixtures.** A frozen fixture set from `derived.md` passes. It covers:
    - pre-first-poll items excluded;
    - earliest-observation and claim tie-breaks;
    - both margins;
    - records after the cutoff excluded;
    - the window ending at the tick;
    - polls exactly 10 minutes apart and gaps;
    - no coverage inferred from a later poll;
    - zero only for covered mapped hours;
    - undefined elsewhere;
    - lineage hashes.
  - **Baseline.** Captured before implementation on the stage 0 dataset version (1792613363942) and C6.4's frozen markets: W0, every stage 2 probe, and the first 200 programs of the frozen C6.4 corpus.
    - After migration, these are byte-identical: deliveries with their knownAt, definedness, node streams, decisions, fills, accounting traces and returns.
    - The comparison uses a frozen projection that removes only enumerated identity fields: kernel, declaration, binding and certificate ids.
    - The suite must deliver every migrated field, both event feeds, covered zero counts, uncovered hours, revisions, tombstones and availability boundaries, or it fails.
    - No spent holdout is used.
- **C7.5 New feeds without code changes.**
  - After the generic implementation is frozen, a synthetic source is added through declarations, data and certification evidence only, with no change to any production, ingestion, reference-kernel or generated code. It has:
    - a previously unused field name;
    - a previously unused unit combination;
    - a distinct cadence;
    - its own availability rule.
  - It produces nonempty deliveries, and a strategy on it changes output exactly at hand-specified ticks.
  - **Substitutability:** one checked strategy evaluates against two certified feeds of one declaration without changing its source references.
  - Incompatible schemas, units and entity mappings are rejected.
  - *Amendment 2026-10-23 (human decision, before any stage 7 code or result; a labeled amendment that adds requirements and relaxes none).* Extensibility is the stage's goal, so C7.5 also requires the operator's whole path, end to end:
    - **Path.** The declaration is committed. The certificate is issued by the certification verifier from an evidence bundle and recorded in the ledger. The binding is recorded. A checked strategy then evaluates on the feed. Each step goes through the CLI, with no edit to any file outside `sources/`, the evidence bundle and the data.
    - **Identity.** The `mm` binary's sha256 and the git trees of `kernel/`, `ingest/`, `reference/` and any generated code are recorded before and after, and are identical.
    - **Real feed.** This is done for the synthetic source, and again for one real feed from the keyless data layer that fits stage 7's supported subset (for example a daily series held on a grid and mapped to every coin by a certified mapping). If no real feed fits the subset, that part is recorded as blocked, never passed.
  - *Revision of that amendment, 2026-10-23, after GPT's review and before any stage 7 code or result; it replaces the amendment above and still only adds requirements.* C7.5 also requires the operator's whole path, end to end:
    - **Path.** After the generic implementation is frozen, the operator:
      1. registers and commits the declaration;
      2. submits an evidence bundle to the certification verifier, and obtains a verifier-issued certificate recorded in the ledger;
      3. records a binding;
      4. checks a strategy and evaluates it.

      Every operation uses the documented CLI. The operator supplies or edits only files under `sources/`, the evidence bundle and the data. CLI-produced ledger records, content-addressed artifacts and run outputs are permitted, and they are enumerated in the frozen demonstration procedure. No production code, executable plug-in, generated implementation, build configuration or certification policy is added or changed, including through files placed in those permitted locations.
    - **Identity.** The `mm` binary's sha256 and the git trees of `kernel/`, `ingest/`, `reference/` and all generated code are recorded before and after each demonstration, and they must be identical. The demonstration records the identities of the declaration, data, evidence, certificate, binding and run, with the CLI invocation sequence and its expected outcomes.
    - **Real feed.** The whole path is demonstrated for the synthetic source, and independently for one real feed from the keyless data layer. The synthetic source satisfies all the novelty requirements above. The real feed must independently show the path, nonempty certified deliveries and a hand-specified strategy outcome. It need not introduce a second unused unit combination or cadence.
    - **Supported subset.** Both demonstrations use numeric fields with units in the frozen unit grammar and an entity domain of the run's coins only. A real scalar series may be supplied as a contextual field for several coins only through an explicit, certified assignment to those coin keys. The assignment asserts that the feature applies, not that its subject is a coin. It performs no implicit entity or unit conversion, introduces no other entity domain or many-to-many relationship, and has its scope and availability certified under C7.3. If the frozen mapping contract cannot represent that assignment, the example is blocked, and the contract is not silently broadened.
    - **Blocker.** If no real feed meets these requirements, the real-feed requirement stays blocked, and C7.5 is not reported as passed.
- **C7.6 The rule language.**
  - A versioned, deterministic AST language, frozen before its implementations. It is total or explicitly rejecting:
    - typed timestamps and durations in integer ms since the Unix epoch;
    - floors on the hour grid with a fixed origin, and an exact boundary convention;
    - no implicit conversions;
    - overflow, absent fields and invalid values rejected;
    - no host code, I/O, clock or randomness;
    - cross-source references only through declared derived dependencies.
  - GPT implements it from the spec alone. A frozen suite then has to match exactly across Python, Rust and that independent implementation:
    - at least 1,000 distinct valid (rule, row) pairs, at least 100 of them exercising each of floors, maxima, offsets and composition;
    - hand-computed cases at exact boundaries and ±1 ms, missing fields, invalid types, overflow and negative timestamps;
    - a malformed-rule suite whose rules must all be rejected.
  - The full resolver is tested the same way. `store.as_of` and `mm`'s loader agree on at least 1,000 frozen queries over multi-revision fixtures, covering:
    - the latest revision chosen before the availability filter, with no fallback to an older revision;
    - tombstones and cutoffs;
    - corrected rules.
- **C7.7 Reference kernel, laws and attacks.**
  - The Lean semantics are parameterized by validated declarations and bindings. The binding law states that evaluation is undefined whenever a required source lacks a valid, matching, in-scope certificate.
  - Every stage 6 law keeps its guarantee for every admitted declaration, held and event cadences included. Each law whose referenced definitions change is reviewed, revised if needed, independently reviewed and frozen before its proof. A proof of an older or weaker statement does not count.
  - A fresh C6.4 corpus, frozen before its run and including novel declarations, valid and invalid bindings, revisions and coverage boundaries, agrees exactly.
  - All I1–I10 and C5 mutants are still caught.
  - Named tests, each with a positive control and an expected code or exact outcome, reached at the check they target, catch:
    1. forged ledger passes;
    2. missing tests, or an unjustified inapplicability;
    3. changed thresholds or policy;
    4. a certificate replayed against another manifest, mapping, extractor or rule;
    5. use outside the certified scope;
    6. data changed after validation;
    7. a failed issuance or ledger commit before output;
    8. a missing source hidden in an unused let or an inactive branch;
    9. uncertified execution data;
    10. a feed timestamp posing as trusted availability;
    11. backdated revisions, superseded-rule outputs and old-revision fallback;
    12. future-dependent coverage or mapping;
    13. a derived feed available before an upstream input;
    14. timestamp overflow or a malformed rule exposing data early;
    15. holdout data reached through a declaration, binding, dataset alias or derived dependency;
    16. zero-filling, holding an event value past its tick, or a held value expiring wrongly.
  - GPT red-teams declarations from the paper and the CLI usage alone. Every attack it finds becomes a permanent test.

Exit when C7.1 to C7.7 hold.

### Stage 8: multi-asset research

Frozen 2026-10-23, before any stage 8 code or data. GPT reviewed the draft, and this is the one revision.

**Scope.** Roadmap item 8 and paper §9. Research moves to underlying assets with long histories (equities, indices,
commodities, macro and rates), with the kernel generalized to their instruments. Results on underlyings are
signal studies. A projection onto a venue market is labeled model-dependent until that market's own forward
record confirms it. Trading is stage 11, the human's decision.
- **Ordering.** Implementation begins only after stage 7 exits and the pilot's judged runs (C7's ordering clause)
  are complete.
- **Scope manifest.** Committed before any new market observation is inspected. For each of the four classes it
  names:
  - its proposed sources;
  - its instruments, or its role as a feature;
  - its universe rule;
  - the jurisdictions and venues considered;
  - the source-selection procedure.

  Selection may use documentation, terms, schemas and catalog metadata, never returns, signals or calibration
  results. The manifest marks each class admitted, blocked or unattempted. A blocked class records the sources
  tried and the requirement unmet (data access needing keys or paid vendors is under Blockers). An empty admitted
  scope is not a pass, and a partial one is reported as "stage 8 completed for [scope]; the rest blocked".
- **Class annexes.** Each admitted class has an annex, reviewed by GPT and committed before its market
  observations are fetched. It fixes:
  - the research window and minimum history (years or eligible observations, chosen from the intended study);
  - the search and holdout boundaries;
  - the witness family and strategy, and the decision cadence;
  - the required fields, and the expected-observation denominator (scheduled closures and absent releases are
    not missing);
  - the maximum gap in eligible observations;
  - the recording procedure and its duration and event minima;
  - the execution and accounting assumptions.

  An unfinished annex is a blocked prerequisite, not leave to choose thresholds after seeing results.
  - *Revision 2026-10-23 (human decision of the same day: certify and ingest the keyless sources now as background data-layer work, before any annex).* Recording may start before a class annex, because a source without recoverable past versions is point in time only from our own recording. Until the class annex is frozen, nothing derived from those recordings is inspected beyond integrity: HTTP status, sizes, hashes, poll times and parse success. In particular no value, return, coverage-by-value, signal or calibration statistic is computed or looked at. Annex thresholds and windows therefore still precede every inspection of the observations they judge. The scope manifest was committed before any of this ingestion (`audit/stage8/scope-manifest.md`).
- **Evidence rule (as C7's).** Before each judged run, its specification, artifact identities, fixture inventory,
  sampling procedure, seeds, minimum samples, thresholds and expected outcomes are committed. Every selected case
  counts. A missing case, skipped mandatory category, crash, timeout or malformed result fails the criterion. A
  failed run stays recorded, and a rerun gets a new identity.

- **C8.1 Point-in-time universes.**
  - Each universe's rule is frozen before its data is inspected: eligibility, ranking window, rebalance
    schedule, information cutoff, tie-breaks, stable identifiers, entry and exit policies.
  - The candidate population is a certified historical listing or contract registry, not the assets that
    happen to have price files. Membership and ranking inputs are resolved as known at the decision time, with
    publication, effective and observation times kept distinct.
  - **Audit:** at least 100 preselected dates across the window (every date if fewer), plus every
    membership-change boundary in a frozen event sample. At each, the whole expected set is compared with
    independent historical membership or listing evidence. Zero unexplained omissions, additions, identifier
    collisions or interval errors are allowed. The audit must include assets absent today and identifier or
    lifecycle changes; a mandatory category with no instance blocks that claim. The result supports sampled
    completeness only, and is reported as such.
  - **Fixtures** for delisting, merger, expiry, suspension and missing terminal prices. A position never
    vanishes, never gets an unsupported recovery value, and is never closed at a last price known to be the last.
  - **Prefix invariance:** adding records available after t changes no universe or decision through t, on a
    frozen suite, with zero differences.
- **C8.2 Certified sources and transformations.** Every feed is declared and certified under C7.3, with the
  terms rule. Every transformation is a declared, certified derived source with its information use and
  availability.
  - **Equities and indices:**
    - raw prices are the execution basis;
    - corporate actions carry announcement, ex or effective, payment and observation times;
    - decision inputs use point-in-time adjustments, or a frozen argument and test shows the computation is
      invariant to later adjustments (a vendor's currently adjusted history alone is not enough);
    - hand-computed fixtures (splits, cash dividends, merger and spin-off consideration, delisting proceeds)
      reconcile shares, cash, receivables and marks, with no omitted or doubled distribution;
    - each index series states price, gross or net total return, currency and tax basis, and an index level is
      never an executable instrument.
  - **Commodities:**
    - individual contracts are certified with their multipliers, ticks, currencies, last-trade dates and
      delivery constraints;
    - the roll decision uses only information available at it;
    - a continuous series is a feature only, while PnL uses the held contracts with explicit closing and opening
      trades and their costs, so a splice is never a trade or a cash flow;
    - fixtures cover rolls, expiry, missing observations, and zero or negative prices where admitted.
  - **Macro and rates:**
    - each observation separates its reference period, its vintage, its actual publication time and later
      corrections;
    - the release calendar is its own certified source with revision history, and actual releases are never
      backdated to scheduled times;
    - fixtures cover first releases, revisions, benchmark revisions, postponed releases, date-only timestamps,
      timezone changes and simultaneous releases;
    - at every tested decision the value returned is exactly the latest vintage then available;
    - observation, vintage and correction keys are frozen before resolution is implemented, and tested against an
      independently built publication history, with no future-vintage substitution and no revival of a
      superseded record.
- **C8.3 Feasibility per class.** Stage 0's protections hold under each annex:
  - at most 1% missing per required entity and field over eligible observations;
  - no gap beyond the annex maximum;
  - zero unexplained duplicate keys, unit errors or integrity violations;
  - the store's boundaries checked on at least 1,000 frozen queries;
  - every decision input within its certified availability rule;
  - replay completeness of at least 99% of eligible decision-entity pairs;
  - an independent witness that reconciles to relative 1e-9 (with a frozen absolute tolerance near zero) and
    exercises nonzero positions, fills and every applicable accounting mechanism (synthetic fixtures for
    mechanisms absent from history).
  - Cost models fitted to quotes pre-register their cells, minimum observations, chronological split and
    acceptance statistics, or inherit C0.7 as amended, named exactly. An unsupported cost, borrow or fill is a
    limitation or a blocker, never "conservative" without a derivation and a defined domain.
- **C8.4 The kernel generalized.**
  - **Entity domains.** The new entity domains and relationships (securities, contracts, series, memberships)
    are enumerated. The affected stage 7 contracts are revised, reviewed and frozen before implementation, and
    identifiers are never coerced into coins.
  - **Instrument kinds.** Each kind freezes its timezone and calendar versions, sessions and auctions, decision
    and execution times, settlement and cash flows, currency conversion, units and position lifecycle.
  - **Fixtures**, nonempty or with a verified inapplicability, cover holidays, daylight-saving shifts, early
    closes, overnight sessions, unscheduled closures, halts, stale marks, asynchronous closes, corporate actions,
    rolls and settlement.
  - **Timing.** No fill occurs in a closed or halted session or before its decision. No signal on a close fills
    in that close's auction unless its timing rules allow it. Cross-sectional decisions use each market's actual
    availability time.
  - **The holdout test's assumption.** Before a configuration reaches the gate, it is proved that its returns
    satisfy the holdout test's lower bound (−1, I10) under its modeled contractual mechanics, with no invented
    debt cancellation. Configurations without it are blocked from that procedure.
  - **Invariants.** I1–I10 are restated per kind where they assume a perpetual, with dated revisions, and each
    has a mutant caught by a named test.
  - **Reference kernel.** The Lean model follows, and C7.7's rule applies: changed definitions are reviewed and
    frozen before proof. A freshly frozen multi-asset C6.4 corpus agrees exactly, with its size, mandatory cases
    and projection frozen first.
  - **The pilot reproduces.** Its results reproduce bit for bit on the generalized kernel, on C6.4's frozen
    markets and the stage 0 dataset version, with no spent holdout reopened.
- **C8.5 Calibration repeated.**
  - **No-edge condition.** Per instrument kind it is derived from the generalized kernel's self-financing
    accounting and filtration, including dividends, funding, financing, borrow, FX, multipliers, rolls and
    settlement. It implies nonpositive conditional expected net PnL for every admitted predictable DSL strategy.
    Observables, membership, coverage and calendars reveal no future innovation.
  - **Generators.** Fitted only to certified search data. The dependence statistics are frozen before the fit is
    judged, with their estimators, minimum samples and tolerances: within and between sectors, between classes,
    volatility persistence, tails and regimes where modeled, and asynchronous sessions. Unsupported dimensions
    are reported.
  - **Independent implementation.** GPT implements the generators from the spec, and they agree within frozen
    tolerances on every judged statistic.
  - **Whole-procedure simulation.** It uses the admitted dynamic universes, calendars, cadences, costs,
    missingness and selection rules. Planted signals cover the claimed scope, cross-asset signals included where
    claimed. C2's frozen complete-null, mixed false-discovery and power targets hold, and changing any is a
    labeled, reviewed revision before its evidence.
  - **The holdout test.** C8 inherits C2's v3 betting test and its assumptions. A locked suite, specified apart
    from the design generators and implemented by GPT from the spec, judges it once before any real multi-asset
    campaign. Its lengths match the actual windows, and its cells, seeds, series counts, levels and simultaneous
    confidence are committed first.
- **C8.6 Holdouts and information boundaries.**
  - **Boundaries.** Holdout boundaries and each campaign's complete information boundary (target returns,
    auxiliary sources, universe inputs, transformations, labels, overlapping intervals) are committed before any
    reserved observation is inspected.
  - **Joint reservation.** Jointly researched classes share a calendar-time reservation, or an isolation scheme is
    shown to keep every reserved observation from any selection decision of its campaign. Embargoes cover
    forward-looking labels and overlapping holds.
  - **No access paths.** Frozen tests attempt access through another class, an alias, a derived source, a
    corporate-action table or a vintage, and require zero unauthorized deliveries. Hashing and ingestion checks
    disclose no holdout-derived diagnostic to the research process.
  - **Use.** The finalist family and the multiplicity rule are frozen before holdout access, and a spent holdout is
    never reused. Every campaign's counts, failures, promotions and class choices are reported beside its
    per-campaign claims.
- **C8.7 Execution mappings.** For each venue-market projection claimed:
  - operator eligibility is established from the venue's documented terms within the hard limits;
  - the mapping (units, currency, contract terms, corporate-action treatment) is certified;
  - before the judged recording window, its duration, minimum samples, tracking-error metrics and thresholds are
    frozen, along with closed-hours and reopening-gap tests, funding and cost assumptions, and handling of halts,
    oracles, parameter changes and delistings;
  - no category passes on an empty sample;
  - a closed-hours strategy cannot be validated from underlying prices that do not exist in those hours.

  If no eligible mapping can be certified, signal-study completion is reported separately and this requirement
  stays blocked.

Exit when C8.1 to C8.7 hold for every admitted class and claimed projection, and every blocked or unattempted
class is recorded under Blockers with what was tried.

- *Amendment 2026-10-23 (human decision, before any stage 8 code or result; a labeled amendment): the signal-study tier.* It adds a weaker, separately labeled claim class. Every executable-backtest claim keeps C8.2 as its bar, and the gate and its calibration are unchanged.
  - **The claim.** A strategy's signal predicts a named benchmark series, for example a reference fixing, a policy rate or a monthly commodity benchmark. There is no execution, cost, capacity or venue claim. Every report labels it "signal study: predicts <series>; no execution claim", and it is never relabeled as a backtest.
  - **Inputs.** Each decision input is certified under C7.3 with its point-in-time availability. A source with recoverable past versions is used at the vintage then available. A source without them is usable only from its certified recording start, never historically.
  - **Target.** The benchmark as published, taken at the value available under its availability rule at the horizon's end. The target series, horizon and value rule are fixed in the class annex.
  - **Score.** The returns of a zero-cost paper position in the benchmark, computed by the kernel's accounting with I10's loss cap, so C2 v3's lower bound (−1) holds.
  - **What applies.** C8.1, C8.3 (without the cost model and fills), C8.5 calibrated for the tier's configuration, and C8.6 apply in full. C8.2's execution requirements (raw executable prices, contracts, rolls, held-contract PnL) and C8.7 do not.
  - **Moving up a tier.** A class or source moves to the backtest tier only when data meeting C8.2 arrives, and it is judged there on fresh evidence. A signal-study result never counts toward a backtest claim.
  - **Reporting.** The exit names its tier: "stage 8 completed for [scope] as signal studies" or "as backtests".
  - **Why it cannot increase false discoveries.** It adds only a weaker claim, labeled apart. No backtest claim loses a requirement, and the statistical gate, its calibration and the holdout rules are unchanged.
- *Revision of that amendment, 2026-10-23, after GPT's review and before any stage 8 code or result; it replaces the amendment above.*
  - **Status and exit.** It adds a separately labeled signal-study completion tier, and changes the stage's exit requirements only for that tier. It discharges and weakens no executable-backtest or venue-projection requirement.
    - Before observations are inspected, each admitted scope's annex fixes its tier, benchmark, decision cadence, horizon, target-resolution rule, score and applicable requirements.
    - Reporting a weaker tier after seeing results does not create a fresh campaign, and does not reset its selection history, multiplicity accounting or holdout.
  - **The claim.** A strategy's signal predicted a named benchmark series under a predeclared target-resolution and scoring rule. There is no execution, cost, capacity or venue claim. Every report labels it "signal study: predicts <series>; no execution claim", and it is never relabeled as a backtest.
  - **Applicable requirements.** Signal studies satisfy C8.1, C8.3, C8.4, C8.5 and C8.6, together with C8.2's certification, transformation, benchmark-identification and point-in-time requirements.
    - Inapplicable to a signal-study claim: only the requirements specifically about actual execution, fills, transaction costs, borrow, executable contract histories, contract rolls and venue projections. Each inapplicability is identified and justified in the annex before observations are inspected.
    - Still required: paper-position accounting, loss bounds, timing, reference agreement and the applicable invariants. C8.7 is required only for a claimed venue projection.
    - Mandatory universe-audit categories that do not exist for a fixed benchmark need a frozen, verified applicability decision; an empty sample is never a pass.
  - **Inputs.** Every decision input, including universe inputs, mappings, calendars and derived sources, is declared and certified under C7.3.
    - Each delivered version is supported by qualifying availability evidence, and is available no earlier than that evidence permits.
    - A recoverable historical version is usable only with evidence of its content and its availability at the decision time; possessing a historical version is not enough. Where versions or their availability cannot be established, values are usable only prospectively, from their individually certified observation times.
    - A source's recording start does not backdate rows first observed later. Corrections and transformations keep their certified availability and lineage.
  - **Target.** Before observations are inspected, the annex fixes:
    - the benchmark's stable identity, units and currency, and its return or distribution convention where it applies;
    - the decision times and the horizon-end rule;
    - the exact endpoint resolver: observation and vintage keys, the ordering of publications and corrections, tie-breaks, freshness limits and missing-value outcomes.

    At each endpoint the resolver uses only records certified as available by then, and applies the frozen supersession rule with no fallback to a superseded record. A value published later never replaces an unavailable endpoint value, and later revisions never rewrite a resolved target or score. Every selected decision is kept. Missing or stale endpoints follow the precommitted scoring and coverage procedure, which is included in calibration and holdout evaluation, and they are never dropped or set to zero. Level-ratio returns are allowed only where the denominator's admissible domain is established (policy rates and some benchmarks can be zero or negative).
  - **Score.** The annex defines the scored process mathematically before observations are inspected: the benchmark-to-payoff transformation, position rule, normalization, initial equity, exposure limits, accounting of overlapping positions, valuation times, and the treatment of missing values and zero equity. "Zero transaction cost" means only that costs are omitted from this expressly non-executable score; it does not confer limited liability or cancel debt.
    - **Lower bound.** Before the configuration reaches the gate, a reviewed derivation establishes that every scored period return is at least −1 on every admitted benchmark path under the scoring mechanics, including jumps, zero or negative values where admitted, overlapping positions and every permitted exposure. It may not rely on an assumed intervening liquidation price, retrospective clipping or unsupported debt cancellation. Any bounded payoff or limited-liability mechanism is defined explicitly as part of the artificial scoring contract.
    - **Conditional null.** Separately, C8.5 establishes the conditional no-edge property C2 v3 requires for this exact score, filtration and strategy class; bounds alone do not establish it. Any transformation, cap or normalization is included in both the derivation and the tier's calibration. A configuration lacking either derivation is blocked from the gate.
    - **Fixtures.** Boundary fixtures and reference-kernel comparisons exercise the score's admitted extremes: discontinuous moves, denominator boundaries, overlapping exposures, total loss and later decisions. The implementation must match the specified mechanics exactly.
  - **Completion.** Signal-study completion requires every requirement applicable to the admitted scope and tier to pass. Outstanding backtest or projection requirements stay recorded as blocked or unattempted, and are never described as satisfied.
  - **Moving up a tier.** Moving to the backtest tier needs newly preregistered evidence and fresh adjudication. An earlier signal-study result never satisfies the stronger claim.

### Stage 9: cross-domain exploration

Scope: roadmap item 9 and paper §8 (exploration across domains). Agents explore cross-source relationships
freely on a search period; at most k finalists, fixed in advance, are confirmed once on an untouched period after
an embargo, with Holm across k. Zero confirmed hypotheses is an acceptable outcome. Implementation begins after
stage 8 exits, since the design needs long multi-asset histories and certified sources. GPT reviewed the draft
(2026-10-23); this version adopts its points.

- **C9.1 Campaign manifest.** Before the first campaign-specific search observation or evaluation is disclosed,
  an immutable manifest and its hash are committed to the ledger. It fixes: the admitted domains and sources; the
  search, embargo, optional intermediate and final confirmation periods; k (1 ≤ k ≤ 5); the search budget and
  stopping rule; what the searcher is shown; the finalist-selection rule and tie-breaks; the mechanism rubric
  (C9.3); the confirmation rule (C9.4); and failure handling. Nothing in it changes after search begins; a
  changed design is a new campaign and cannot reuse a period the old one disclosed. "Free exploration" removes
  the DSR, SPA and ranking screens, not the budget, the information boundary or the ledger, and stage 2's
  searchers keep their frozen budgets. Every period comes from data certified under stages 7 and 8.
- **C9.2 Information boundary.** Before any reserved observation is inspected, the campaign's boundary is
  committed under C8.6: target returns, auxiliary data, universe and source-selection inputs, labels, release
  calendars, vintages, caches, external retrievals and earlier campaigns' disclosures. The embargo is derived
  from the longest end-to-end dependency the admitted programs allow (composed lags and windows, forward labels,
  overlapping positions, the instruments' calendars and publication times), and a frozen suite of its
  maximum-length and asynchronous-boundary cases finds zero forbidden overlaps. Certification of reserved data
  happens behind the boundary: no value, diagnostic, fitted parameter or error derived from it reaches anything
  making campaign decisions, and a period already disclosed to that process is ineligible. Access tests follow
  C8.6's evidence rule (inventory, fixtures, expected deliveries and denials frozen first; every path including
  aliases, derived sources, other domains, vintages, metadata and error channels, caches; zero unauthorized
  deliveries; a missing case, crash or timeout fails). Every search evaluation is ledgered with what the agent
  saw, and no search-period statistic is reported as evidence. The eligible searchers and retrieval channels are
  named in the manifest, since these tests cannot show a period was unknown to an unrestricted model.
- **C9.3 Finalists and mechanisms.** At most k finalists, chosen by the committed rule. Before any confirmation
  disclosure each is frozen: canonical program and build, parameters, sources and certificate versions, universe
  and asset selection, cadence, execution and cost configuration, and its mechanism record. Any later change
  disqualifies it. The record names the distinct domains, the transmission channel, the predicted direction and
  timing, and when it should hold; the domain classification and acceptance rubric are frozen before search, and
  renaming, aliasing or transforming a source does not create a domain. Any empirical mechanism check runs on
  search data before freezing. The record is never reinterpreted after confirmation, and a confirmation supports
  a mechanism-backed predictive hypothesis, not a causal claim. Each finalist passes the source, type and
  return-bound checks first; a frozen checker suite (cross-domain level pairings, aliases and transforms that
  evade the differencing rule of paper §4, well-typed controls) matches every expected rejection and acceptance.
- **C9.4 Confirmation.** All finalists are tested together, once per confirmation stage. A finalist passes a
  stage only if its net return over the whole committed window is positive and its C2 v3 betting p-value passes
  Holm at α = 0.05; every emitted step counts, and each stage starts from wealth one. At the first stage Holm runs
  across the k committed slots, unused slots at p = 1. With an intermediate period, the passing finalists advance
  automatically and unchanged, and Holm at the final stage runs across all that advanced; one that becomes
  untestable stays in the family at p = 1. No reranking, replacement, window extension or choice among passers.
  Only a final pass is a confirmation. The claim rests on v3's conditional null (nonpositive expected net return
  given everything revealed so far, including search and intermediate results) with returns bounded below at −1
  under C8.4; the embargo prevents overlap and is not claimed to make periods independent. Any decision taken
  after confirmation access outside this rule fails the campaign.
- **C9.5 Calibrated in simulation first.** Before the judged simulation, a reviewed annex fixes every generator,
  fitting procedure and dependence tolerance (search data only, inheriting C8.5's), campaign lengths and
  embargo, searcher and disclosure interface, finalist and mechanism rule, planted signals and their analytic
  truth, seeds, cell list and sample sizes. Development and judged runs use separate seeds. Each judged campaign
  runs the full procedure (search by the agent harness or stage 2 searchers under the same mechanism and finalist
  rules, embargo, every confirmation stage, Holm), for every configuration claimed for real use.
  - Complete null: each generator is shown analytically to give every admitted predictable strategy nonpositive
    conditional expected net PnL, and includes persistent volatility, cross-domain dependence, asynchronous
    observations and dependence across both embargo boundaries. Per cell, at least 300 campaigns, fixed in
    advance; the exact one-sided 95% (Clopper-Pearson) upper bound on P(at least one confirmation) is ≤ 0.05.
  - Mixed: planted cross-domain signals at two or more strengths. The judged quantity is the campaign FDR
    E[V/max(R,1)], not a pooled fraction. Per cell, n ≥ 400 campaigns fixed in advance, and
    mean FDP + sqrt(log(M/0.05)/(2n)) ≤ 0.10 in every one of the M mixed cells.
  - Power: the rate of campaigns with at least one true confirmation is reported with CIs at every strength;
    at the strongest, its point estimate is ≥ 0.30 (as C2.6).
  - Every started campaign counts; a crash, timeout or malformed output counts as a false confirmation in the
    error rates and as no success in power.
- **C9.6 Reporting.** A campaign is registered before its first search disclosure and reported however it ends,
  including campaigns with no finalists and abandoned ones: manifest and artifact hashes, budget and evaluations
  used, finalist and mechanism decisions, every confirmation disclosure, family sizes, p-values and Holm
  decisions, failures, and every period consumed. A reserved period is spent once anything derived from it,
  partial or diagnostic, reaches a decision-maker; stopping, crashing or renaming does not restore it. Claims are
  per campaign and confirmation family, shown beside the number of campaigns attempted; a project-wide claim
  needs the gate's separate precommitted budget.

Exit when C9.1 to C9.6 hold and at least one registered real campaign has run final confirmation on at least one
frozen cross-domain finalist, exercising the declared source, mechanism, type, boundary and confirmation paths.
Zero confirmed hypotheses is an acceptable outcome; zero finalists tested is not an exit.
