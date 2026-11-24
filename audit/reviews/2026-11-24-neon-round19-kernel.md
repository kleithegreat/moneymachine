# Neon (Gemini 4 Neon, web UI) on round 19's kernel half

Reviewer: Gemini 4 Neon through the web UI, which did not author round 19 (a fresh Opus did) and had not seen rounds 17 to 19. Bundle `neon-r19-kernel-bundle.md` (`rearchitecture` `fccd965`, 177 KB; the build boundary out of scope, excerpts listed at its top). Two parts; saved by the human as a PDF, extracted with `pdftotext`, received 2026-11-24 17:34 UTC. Verbatim below.


 See attached instructions

 User prompt: See attached instructions
 Response: Round 19's architectural shift ("the machine is specification") is directionally
 right, and it closes GPT's points 3 and 4 cleanly, but the kernel half has not converged.
 Below are Findings 1 to 3 (all design defects in the newly folded KERNEL.md A18 reader rules);
 Findings 4 to 6 (A18 two-clock look-ahead, the U1 ★/L6 ★/P1 ★–K1 ★ gaps under "machine
 is specification", pre-first-quote settlements), the full evaluation of the specification shift and
 GPT's four points, and the ledger follow in Part 2.

 Finding 1 — Unsettled-hour / listing-end deadlock makes ~1/6 of delistings
 unrunnable (design defect)
 What it breaks: KERNEL.md A18 ("A listing's end", "An hour the venue did not settle", and
 "Funding's lateness"), kernel-v2.md A3, and C2 ★.
 Construction: Take the A18 header's late = 600,000 ms (10 minutes). Suppose
 universe coin X is held into hour H = 06:00:00.000 (e.g., bought at 03:30, last book at
 03:40, last settlement at 03:00), is flagged by a copy in force at e = 05:05:00.000 (or
 anywhere in [05:00:00.000, 05:09:59.999]), has no book, print, or settlement in
 [04:05:00.000, 06:05:00.000], has whole fundingHistory replies covering
 [04:05:00.000, 06:10:00.000], and has no unflagged copy in (05:05, 06:05].

 By A18 ("A listing's end"), X's listing ends at τ = e + 1 h + 1 ms =
 06:05:00.001.

 By A18 ("Funding's lateness"), hour H = 06:00:00.000 is due (w_start ≤ H, H +
 late < w_end, and X's listing has not ended by H, since 06:00:00.000 <
 06:05:00.001) and X is held into H (position nonzero after every event with time <
 06:00:00.000).

 By A18 ("An hour the venue did not settle"), H is before X's listing's end
 (06:00:00.000 < 06:05:00.001), no settlement names H, and whole replies cover
 [H, H + late], so the unsettled hour (a = 2) is timed H + late =
 06:10:00.000.

 Both reader behaviors fail:
 1. If the reader feeds the unsettled hour at 06:10:00.000, 06:10:00.000 > τ
 = 06:05:00.001 is an event of an ended coin, so A3 and C2 ★ reject the
 entire market. This still fails at the boundary e = 05:09:59.999, where τ =
 06:10:00.000 = H + late, because class 1 (listing) precedes class 2
 (funding) within the same millisecond in A3's order.

11/24/26, 12:33 PM See attached instructions

 2. If the reader omits the unsettled hour (following A18's rule that every event of
 the coin stamped at or after τ is counted and not fed), no funding record names
 H = 06:00:00.000, so at the end of millisecond 06:10:00.000 the engine
 aborts the run with R_SETTLEMENT_MISSING.
 (Why Test 15 missed it: Test 15 picked e = 05:10:00.000, putting τ =
 06:10:00.001 exactly 1 ms after H + late = 06:10:00.000.)

 Outcome it changes: Any valid forward run holding a coin delisted in the first late of an
 hour ([H − 1 h, H − 1 h + late)) either rejects under C2 or aborts with
 R_SETTLEMENT_MISSING, publishing no report or trace and blocking CS2.1–CS2.3.

 Fix: Require H + late < τ (strictly) for both a due hour in "Funding's lateness" and an
 unsettled hour in "An hour the venue did not settle". Because the listing's end at τ already
 requires whole fundingHistory replies with no settlement of X over [e − 1 h, e + 1
 h] = [τ − 2 h − 1 ms, τ − 1 ms], which covers [H, τ − 1 ms] whenever H < τ
 ≤ H + late, venue silence up to τ is already proved; waiving the due check when τ ≤ H
 + late also eliminates the ambiguity of "ended by H" at τ = H (e = H − 1 h − 1 ms).

 Finding 2 — "The copy's day and the next" in A18 breaks monthly replay
 prefix-consistency (design defect)
 What it breaks: KERNEL.md A18 ("A listing's end"), Brief 3 Step 6 Test 15, and the single-
 record-per-time premise that L1 ★ relies on for CS2.1's monthly replays (kernel-v2.md
 B3).
 Construction: Suppose a universe coin is flagged by a copy in force at e = 2026-04-30
 12:00:00.000, with no book, print, or settlement in [2026-04-30 11:00, 2026-04-30
 13:00], whole replies covering that span (all in files with since ≤ June), and no
 unflagged copy in (e, e + 1 h]. The listing end time is τ = 2026-04-30
 13:00:00.001, strictly inside April (< 2026-05-01 00:00:00.000).

 July replay (w_end = 2026-05-01 00:00:00.000; last whole month = July − 3
 = April): April's record (since ≤ April + 2 = June) is already complete in
 July's capture. Yet A18 states "the reader uses an end only where the copy's day and
 the next lie within it" (and Test 15 explicitly enforces "an end whose copy's next day
 lies after the last whole month the runner gives is not used"). Here the copy's day is
 April 30 and the next day is May 1, which lies after April. July's reader therefore does
 not emit the listing's end at 2026-04-30 13:00:00.001.
 August replay (w_end = 2026-06-01 00:00:00.000; last whole month = May):
 both April 30 and May 1 lie within May, so August's reader does emit the listing's
 end at 2026-04-30 13:00:00.001.
 Outcome it changes: Two monthly replays feed different event streams for April 30
 (before May 1). L1 ★ only compares runs fed the same events before t, so it does not

11/24/26, 12:33 PM See attached instructions

 catch this. August's replay retroactively inserts a settlement at 2026-04-30
 13:00:00.001, closing any position, cancelling orders, releasing cash for afternoon buys,
 and splitting the span on April 30 — changing April 30's day/account rows, K2's bar,
 guard's rebalance, and CS2.1–CS2.3 verdicts between the July and August replays.

 Fix: Gate the listing's end on e + 1 h (equivalently τ) lying inside the last whole month,
 not "the copy's day and the next". Whenever e + 1 h crosses midnight from the last day
 of month M into month M + 1 (e ≥ April 30 23:00), τ = e + 1 h + 1 ms is already
 in month M + 1 (≥ w_end of month M's replay) and would not be fed in month M's replay
 anyway.

 Finding 3 — The host's kept form drops pre-w_start books and prints that
 A18's listing-end window inspects (design defect)
 What it breaks: KERNEL.md A18 ("What a host keeps of a file" vs "A listing's end"), D1
 (determinism across hosts with and without cached kept forms), and Brief 3 Step 6 Test 13
 ("A host's kept form gives what its file gives").
 Construction: Universe coin X has a valid book or print stamped at w_start − 20 min
 (on its own line), followed by silence until w_start + 80 min, when X resumes with a
 valid book. A flagging copy is in force at e = w_start + 10 min (≥ w_start), whole
 fundingHistory replies cover [w_start − 50 min, w_start + 70 min] with no
 settlement of X, and no copy in (e, e + 1 h] gives X rules.
 Reading raw capture files: The book or print at w_start − 20 min is in the record
 and lies inside [e − 1 h, e + 1 h] = [w_start − 50 min, w_start + 70
 min], so the copy at e = w_start + 10 min does not end X's listing. X resumes
 at w_start + 80 min and remains listed for the rest of the run.
 Reading the host's kept form: By A18, of l2Book-fast and trades, the kept form
 retains only lines holding an item "stamped at or after w_start and in the record of
 its time". The book or print at w_start − 20 min is discarded from the kept form
 (unless it happened to share a trades line with a post-w_start print). Reading the
 kept form therefore sees no book or print in [e − 1 h, e + 1 h], emits X's
 listing end at τ = w_start + 70 min + 1 ms, splits the span, and discards X's
 resumed trading from w_start + 80 min onward.
 Outcome it changes: The cached run and the uncached raw-file run feed different event
 streams and produce different reports, traces, span splits, K2 bars, and trades on X,
 changing CS2.1–CS2.3 verdicts depending on whether a host uses its kept form.
 Fix: Have the kept form of l2Book-fast and trades retain universe-coin lines stamped
 at or after w_start − 1 h (matching the 1-hour lookback of [e − 1 h, e + 1 h] for e
 ≥ w_start), or restrict listing-end candidates to copies with e ≥ w_start + 1 h.

 CONTINUE

11/24/26, 12:33 PM See attached instructions

 User prompt: continue

 Response: Finding 4 — Deleting the Date/recv skew check lets stale meta
 copies overwrite newer rules (and veto valid delistings), while max(date,
 recv) drops + 1 s (design defect)

 What it breaks: KERNEL.md A18 ("A reply's two clocks", "Listings", "A listing's end"), Brief 3
 Step 6 Test 15, and the non-anticipation / rule-integrity premise for listing events.
 Construction A (stale-snapshot rollback): Round 19 deleted the hour check between
 Date and recv on the premise that "a clock that is off delays a copy and moves none
 earlier", and Test 15 explicitly treats a host clock 40 days ahead as harmlessly delaying
 copies. That premise holds for append-only events, not for state snapshots ordered by
 time-in-force. Suppose on April 1 a host clock glitch records recv = May 11 while date
 = April 1, fetching a meta copy showing coin X unflagged with maxLeverage = 20
 and szDecimals = 2. On April 2 NTP fixes the host clock. On April 10 the venue tightens
 X to maxLeverage = 5, szDecimals = 3; copies from April 10 through May 10 have
 date ≈ recv and correctly apply the new rules. Under A18, the April 1 copy has time-in-
 force max(April 1, May 11) = May 11, and its file's since = April ≤ May + 2 is
 inside the record of May 11. On May 11, A18 therefore applies the 40-day-old April 1 copy
 after May 10's copies:
 It rolls X back to maxLeverage = 20 and szDecimals = 2, cancels all live orders
 of X, runs X for up to an hour on wrong margin tiers (suppressing a real liquidation)
 and a wrong price grid/lot size, and cancels X's orders a second time when the next
 real hourly copy restores maxLeverage = 5.
 Worse, if X was legitimately flagged at e = May 11 04:00, the stale April 1 copy
 landing in force at May 11 04:30 ∈ (e, e + 1 h] gives X rules and vetoes X's
 listing end.
 Construction B (sub-second look-ahead): A18's own derivation states that a reply was
 made "before max(date + 1 s, recv), the Date's whole second included", yet the next
 bullet puts a copy in force at "the later of its reply's two clocks" (max(date, recv),
 confirmed by Test 15: "in force from its Date"). If recv runs behind date (e.g., a 1970 boot
 clock) and the server generated the reply at 12:00:00.900 with whole-second IMF-
 fixdate Date: 12:00:00, the copy enters force at 12:00:00.000 — 900 ms before the
 venue wrote it.
 Text gap on fundingHistory with date = null: A18 drops a listings copy whose
 date is null or unreadable, but never specifies reach for a fundingHistory reply
 whose date is null or unreadable (min(date, recv) is undefined).

11/24/26, 12:33 PM See attached instructions

 Outcome it changes: Spurious order cancellations, wrong price grids/lots, suppressed or
 spurious liquidations, vetoed listing ends, and up to 999 ms listing look-ahead — changing
 run records and CS2.1–CS2.3 verdicts.
 Fix: (1) Put a copy in force at max(date + 1 s, recv); (2) either restore a |date −
 recv| skew bound on meta copies or ignore any meta copy whose acquisition order /
 lower clock min(date, recv) is older than a copy already applied; (3) specify that a
 fundingHistory reply with date = null or unreadable has no reach (covers nothing,
 while its parsed settlement rows still enter the record).

 Finding 5 — Midnight-start funding settlements (and pre-first-quote listing
 ends) hit undefined price on Day 1 (design defect)
 What it breaks: kernel-v2.md A3, A9, A12, K2 ★, and KERNEL.md A19 (funding trace
 row, end trace row, coin report row).
 Construction: Every Study 2 forward run begins at a UTC midnight w_start (e.g., A18's
 own header example 1775174400000 = 2026-04-03 00:00:00.000 UTC).
 Hyperliquid's 00:00 fundingHistory settlement is stamped 00:00:00.000 (or shortly
 after, before a quiet coin's first L2 snapshot), carries no oracle price (a = 0), and has
 class 2 (funding), which precedes class 3 (quote) in A3's order even when a quote
 shares 00:00:00.000.
 At that event, every coin has had no quote yet, so by A3 and A19 its price is
 undefined (-).
 Yet A19 mandates a funding trace row (time, coin, hour, unit) for every
 settlement with unit = rate × coin's price (undefined), and A12/A19 update
 coin's events, funding, and return sums (−unit / price) over every price event
 while A12 simultaneously states "A coin has no return before its first quote".
 Similarly, if a universe coin listed at a span's start has no quote before a day's end or
 span's end (its own listing end or another coin's — e.g., Test 15's pre-w_start
 delisted coin or a coin silent at w_start), its first and price are undefined (-).
 That directly falsifies K2 ★'s statement ("the most that 1 put in one of the span's coins
 at its first price in the span became... that price is above zero (A3, A12)") and leaves
 A19's end trace row (time, coin, price) undefined.
 Outcome it changes: Crashes or undefined funding/coin/end rows on the very first
 millisecond of every midnight-start run, directly affecting guard (reads funding trace
 rows) and K2 ★ (reads coin rows' first, funding, and return sums), changing CS2.1 and
 CS2.2.
 Fix: Define pre-first-quote behavior explicitly in A3, A9, A12, A19, and K2 ★: before a coin's
 first quote in a span, a funding settlement cannot apply to a held position (the coin is
 stale), is not a price event of the span (writes unit = - in the trace, adds nothing to

11/24/26, 12:33 PM See attached instructions

 coin's events, funding, or return sums), and a listing's end writes price = - in the end
 trace row; K2 ★ takes the buy-and-hold max only over span coins with a defined first
 price (which is then > 0 by A3).

 Finding 6 — Deleting U1's machine half breaks the 5% null's proof chain; R1's
 record-order prose overclaims what remains proved (design defect + text
 defects)
 What it breaks: kernel-v2.md B3 (U1 ★, R1 ★, L6 ★), Brief 3 Step 7 (Laws ★), and
 the paper's claim that "every computational law a judged number depends on is a theorem
 about the functions that run" (B1).
 Construction A (omitted funding debit passes every remaining ★ law — answers
 Question 1 & 2): Suppose a restatement or bug in the machine's funding handler skips
 calling Ledger.step (or passes q = 0) on a held coin's settlement under a condition Step
 7's three synthetic days do not hit (e.g., on the second held coin of a same-millisecond
 funding batch, or when a = 0 with no oracle price), while still recording the coin's
 funding return in the coin report row. Every remaining ★ law holds:

 U1 ★ holds because Round 19 deleted U1's machine statement, leaving only Step 2's
 Ledger.step theorem (−0 · O · ρ = 0).

 A1 ★ and P1 ★ hold because cash equals starting cash plus emitted cash-flow
 rows, and no funding row was emitted for the skipped payment.
 K1 ★ holds because the test ledger folds the emitted cash-flow rows — so the
 copied strategy pays zero funding on its long position.
 K2 ★ holds and still deducts funding from the buy-and-hold / constant-mix bar.

 L0, L1–L1c, R1, S1, E1, L4, T1, L6, C1, C2, and X1–X6 all hold.

 Why this is different from deleting F0, M1, M2: A missed fill (F0), missed liquidation
 (M1), or missed listing settlement (M2) breaks strategy-reproduction fidelity, not the
 5% Ville false-positive bound (any non-anticipating strategy obeying T1 and exact
 accounting without free money still cannot beat K2's bar with probability > 5%).
 Omitting a funding debit on a held long hands the strategy free carry relative to
 the funding-paying benchmark, directly invalidating the 5% false-positive
 guarantee of CS2.1 and CS2.2.
 Construction B (R1 ★ record-order overclaim — answers Question 3): R1 ★ states
 that its kept order clauses ("steps in the order of their moves, each at its move's time, then
 its tick, then its arrivals") guarantee "no restatement can let a rule change's cancel follow its
 millisecond's arrival, a print's fill precede that cancel, or an arrival precede its tick." Once
 stepForm and ruleChanges are deleted, nothing links a step's effects to moves[idx].
 A restatement can tag the print's fill step with move index i (the listing change's index, at

11/24/26, 12:33 PM See attached instructions

 time t) and the rule-change cancel step with index i + 1 (the print's index, also at time t)
 — or place both effects in one step at index i with the fill before the cancel — satisfying
 idx₁ < idx₂ and moveTime moves idx = some t while letting the print's fill precede
 the rule-change cancel.
 Text defects in R1 ★ and L6 ★:
 R1 ★ says "the admitted orders of the arrivals are the orders placed" while admit
 checks A6's three conditions alone. Under GPT's Point 4a (minimum = 0, bankrupt
 account, buy rounded to price 0), admit returns true while arrive places nothing.
 Clarify that R1 equates run.admissions (the orders arrive submitted to admit
 and admitted) with run.placed, and remove the stale phrase "or offer" from R1 once
 Move.offer is deleted at Step 6.

 Step 7's Laws ★ lists L6 as a ★ theorem while the next sentence says "round 19
 deletes M1, M2 and the machine's statements of U1 and L6." Since L6 has no step-2
 ledger-only counterpart, clarify that L6 ★ (the state invariant: equity ≥ 0, absorbed
 rises only by shortfall at bankruptcy, returns 0 thereafter) is kept and only the round-
 18 stepForm clause was deleted.
 Outcome it changes: Construction A breaks CS2.1 and CS2.2 false-positive validity under
 a subtle funding bug; Construction B invalidates R1's stated guarantee against misordered
 same-millisecond effects.
 Fix: Keep a small witness-level machine clause in U1 ★ (no marketAt or second machine
 needed: at every admitted settlement of coin c, the machine passes c's current world
 position before that move to Ledger.step and emits its cash-flow row when nonzero, and
 makes no funding payment at any other move). Trim R1 ★'s prose to what the kept order
 law actually proves, disambiguate run.admissions vs admit, and fix Step 7's L6
 wording.

 Check of GPT's four points, "machine is specification", and what can be
 deleted
 GPT's four points:
 Point 1 (evaluator inputs unbound / first_price): Closed by making tick inputs frozen
 specification + fixture FirstPrice + Step 5 Test 2 + B4 rerun rule. One condition on B4:
 B4 only guards tick inputs if B4 exercises the tick-to-evaluator wiring (including
 first_price, filled, resting, age), not just standalone expression evaluation.

 Point 2 (millisecond-end marketAt; span & trace rows): Closed at its cause for
 marketAt (deleted) and GPT's two-quote liquidation (Step 7 Test 1). Trace completeness
 (funding, end) is now specification + review + Step 9 tests, which is consistent with the
 new boundary, except deleting U1's machine link leaves a gap in the 5% proof chain
 (Finding 6).

11/24/26, 12:33 PM See attached instructions

 Point 3a (F0 / Move.offer) & 3b (funding after same-ms liquidation): Closed cleanly.
 Deleting Move.offer at Step 6 is sound — every legal fill case in Step 5's tests/fixtures is
 reproducible with prints and quotes.
 Point 4a (bankrupt arrival) & 4b (moveTime): 4b is closed cleanly (none past the moves,
 proved). 4a is closed in A6 and Step 7 Test 2, pending the R1 ★ wording fix
 (run.admissions vs admit, Finding 6).
 The "machine is specification" choice, smaller alternatives, and what can be deleted:
 Accept the paradigm shift. Six rounds proved that constraining a mutable "subject"
 machine via partial content-binding laws (marketAt, stepForm, arrivalEffectsOf,
 ruleChanges, F0, M1, M2) converges either to recurring loopholes or to duplicating the
 engine inside the proof contract. Because the engine is already written as plain, total, pure
 Lean functions (with @[csimp] twins for speed), freezing the machine as its own
 specification is smaller and more honest than either per-move laws or a separate
 reference transition with a refinement proof. The exact bright line is: prove everything the
 5% Ville false-positive bound relies on (L0, L1–L1c, R1's schedule, S1, E1, L4, T1, A1,
 machine U1, L6, P1, C1, C2, K1, K2, X1–X6), and hold strategy/venue rule fidelity (F0, M1, M2,
 tick inputs, trace rows) by frozen specification, review, and part-A tests.
 Larger than its cause — candidate to delete: moveIdx and moveTime inside R1 ★'s
 record-order law. What L1c ★ actually needs from the single ordered record list is
 timestamp-and-phase ordering (steps < tick < arrivals within each millisecond,
 non-decreasing time). Once stepForm and ruleChanges are deleted, moveIdx and
 moveTime no longer bind a step's content to its move (Finding 6, Construction B); keeping
 only (time, phase) ordering is strictly smaller and makes no false promise.
 Other contested judgments — accepted:
 Not deriving run.placed/run.fills from records (agree: P1 ★ already ties
 orderRun's fills to the report's fill rows, and the machine is frozen specification).

 Keeping R1's schedule (slotKeysAt, λ delay, once and in order) as a ★ law (agree: it
 is the bridge from L1a/L1c to world orders).
 Unsettled hour without a funding trace row (agree for guard/confirm, neither of
 which needs it; the only trade-off is slightly reduced post-mortem readability of the
 trace, which is acceptable).
 B4 rerun on restatement of tick, view, or inputs (agree, provided B4 covers the tick-
 input table).
 Four stream states (complete, cut, malformed, corrupt), corrupt feeding nothing,
 and duplicate placement by first copy in the record of its time before horizon prefixes
 (all sound; no two reader-generated records collide on A3's 5-tuple once Finding 1 is
 fixed).

11/24/26, 12:33 PM See attached instructions

 Review ledger

 Would change what is
 Agreed Disputed
 built or run?

 Making the plain Lean machine
 its own frozen specification,
 Deleting U1's machine half
 deleting F0, M1, M2, marketAt,
 (Finding 6A: allows a silent
 stepForm, arrivalEffectsOf, Yes: Step 7 U1 ★ proof
 funding omission that breaks
 ruleChanges, arrive's 4- contract
 the 5% null under every
 clause characterization,
 remaining ★ law)
 Log.effects, and 10 redundant
 fixtures
 Keeping R1's schedule, L1c's
 prefix split, and (time, phase) R1 ★'s moveIdx/moveTime
 record ordering; deleting overclaim and admit vs Yes if
 Move.offer at Step 6; funding run.admissions wording; moveIdx/moveTime are
 on world position at the event Step 7's L6 self-contradiction removed from the
 (A9); moveTime returning none (Finding 6B/text); optional contract; text-only if only
 past the moves; B4 rerun rule; deletion of wording is fixed
 unsettled hour without a trace moveIdx/moveTime
 row
 Four stream states (corrupt
 feeding nothing); duplicate
 Unsettled-hour / listing-end
 placement in the record of its Yes: reader and engine
 deadlock for e ∈ [H − 1
 time before horizon prefixes; due-hour check (H +
 h, H − 1 h + late)
 fundingHistory 500-row late < τ)
 (Finding 1)
 covering rule (with date =
 null clarified)

 "Copy's day and the next"
 Calendar cutoff (since ≤ M + Yes: reader (e + 1 h in
 gate breaking monthly replay
 2) and single-record-per-time last whole month) and
 prefix-consistency on month-
 principle Step 6 Test 15
 end delistings (Finding 2)
 Kept form dropping
 [w_start − 1 h, Yes: reader kept-form
 Host kept-form caching with
 w_start) books/prints filter (w_start − 1 h)
 separate checksum
 inspected by [e − 1 h, e or listing-end floor
 + 1 h] (Finding 3)

11/24/26, 12:33 PM See attached instructions

 Would change what is
 Agreed Disputed
 built or run?

 Deleting the Date/recv
 skew check (stale meta copy
 Yes: reader (max(date
 overwrites newer rules /
 + 1 s, recv),
 Two-clock bound concept for vetoes delisting); max(date,
 skew/monotonicity
 REST replies recv) missing + 1 s; date
 guard, date = null
 = null unspecified on
 reach) and Step 6 Test 15
 fundingHistory reach
 (Finding 4)
 Pre-first-quote funding
 settlement (a = 0 at Yes: engine
 Midnight-aligned horizons and w_start) and pre-first-quote (funding/end/coin
 A3 event class ordering listing end hitting undefined rows before first quote)
 price in A19, A12, and K2 ★ and K2 ★ statement
 (Finding 5)

 Would any dispute change what is built or run? Yes: Findings 1 to 5 change the reader, the
 engine's due-hour and pre-first-quote handling, K2 ★, and Step 6 Test 15; Finding 6 restores U1
 ★'s machine funding invariant in Step 7.


