# Neon (Gemini 4 Neon, web UI) on round 20's study 2 half

Reviewer: Gemini 4 Neon through the web UI, which reviewed study 2's rounds 17 and 18 and did not author round 20 (a fresh Opus did). Bundle `neon-r20-study2-bundle.md` (`rearchitecture-s2` `86aa583`, with KERNEL.md A18 and A19 from `rearchitecture` `fccd965`; 285 KB). Three replies, ending with its ledger; saved by the human as a PDF, extracted with `pdftotext` (page headers kept, repeated spaces collapsed), received 2026-11-25 01:09 UTC (20:09 EST). Verbatim below.

11/24/26, 8:08 PM See attached instructions

 See attached instructions

 User prompt: See attached instructions
 Response: Round 20's two core moves—bounding REST replies by both clocks (max(date + 1
 s, recv) and min(date, recv) − 30 s) and grounding silence in the venue's own funding
 replies—attack GPT's round 19 findings at the right level, but the design has not converged
 and the criteria commit must still be held. Three show-stopping design defects break prefix
 invariance across monthly replays, abort the engine on the first delisting of any held coin
 (including Brief 4's own Test 12), and leave GPT's pre-start delisting case broken at w_start.

 Finding 1. Month-end listing ends break prefix invariance and trigger a fatal
 build fault on an honest record
 What it breaks: Prefix invariance across monthly replays (law L1 / the shared criteria
 revision's "every later replay reads the same record of every day it runs") and End (5) ("a
 fault of the build"). KERNEL.md A18 ("A listing's end"), Brief 4 (step 7, wall 3), and the round
 20 report (routed item 4) all keep the gate: "The runner gives the reader the last month
 whose record is whole (its capture's month less three), and the reader uses an end only
 where the copy's day and the next lie within it." Round 20's new unsettled-hour rule makes
 that gate fatal.
 Construction: Take any universe coin X delisted on the last day of any month M—say
 2027-03-31—with its last settlement at 03:00, its last book at 03:40, and its first
 flagging copy in force at e = 2027-03-31 05:10:00.000. (The construction works for
 any e ∈ [2027-03-31 00:00:00.000, 2027-03-31 22:59:59.998], i.e., 23 hours
 minus 1 ms of the last day of every month.)
 1. The silence window [e − 1 h, e + 1 h] = [04:10, 06:10] and the listing's
 end τ = e + 1 h + 1 ms = 2027-03-31 06:10:00.001 both lie entirely on
 2027-03-31, strictly before the day-end midnight 2027-04-01 00:00:00.000.

 2. On 2027-04-01 00:17 UTC, mmvault funding queries X from 04:00 of March 31
 and stores [], covering [2027-03-31 04:00, 2027-04-01 00:16:30]. That file
 is first listed by the 2027-05-01 capture (since = 2027-05) and hashed by the
 2027-06-01 capture. Since 2027-05 ≤ 2027-03 + 2, it is in the record of every
 hour of March 31.
 3. In the June replay (k = 2027-06): last_whole_month = k − 3 = 2027-03.
 The copy's day is 2027-03-31 (in 2027-03), but the next day is 2027-04-01 (not in
 2027-03), so A18 suppresses the listing end. Unlike round 19 (where missing funding
 at 04:00 would have held the horizon before March 31 ended), round 20's unsettled-
 hour rule marks 04:00 .. 23:00 of March 31 as shown unsettled using April 1's []

11/24/26, 8:08 PM See attached instructions

 reply. The June replay therefore runs all of March 31 through 2027-04-01
 00:00:00.000 without ending X, settles, and is accepted.

 4. In the July replay (k = 2027-07): last_whole_month = 2027-04. Now both
 2027-03-31 and 2027-04-01 lie within ≤ 2027-04, so A18 activates the end at
 2027-03-31 06:10:00.001.

 5. Contradiction: On 2027-03-31, the July replay writes a span end at
 06:10:00.001 and advances the span index and coin membership in 2027-04-01
 00:00:00's coin rows (even if X was completely flat!)—and if X was held, July also
 writes a settlement flow row at 06:10:00.001, releases cash, and changes
 subsequent trades, W, and Wᵇ on March 31. June's accepted report and July's settled
 report disagree on March 31's engine rows.
 Outcome changed: Triggers End (5) ("a fault of the build") on a completely honest record
 with a bug-free binary, permanently halting the two-year forward study. Any CS2.1 crossing
 on March 31 ("earned" or "outgrew") is overturned to "not judged", and if March 31
 precedes day 212, CS2.2 is forced to "not judged" (and CS2.3 too if before its
 judgment).
 Defect of the design (changes KERNEL.md A18 and Brief 4 step 7 wall 3). Because τ = e
 + 1 h + 1 ms already lies strictly after [e − 1 h, e + 1 h], requiring τ <
 T_cutoff (the first UTC midnight after last_whole_month) guarantees that every
 millisecond of [e − 1 h, e + 1 h] lies inside ≤ last_whole_month, while any e with
 τ ≥ T_cutoff cannot affect any day before T_cutoff anyway.

 Finding 2. Every delisting of a held coin aborts the engine with
 R_SETTLEMENT_MISSING or violates post-end event discard

 What it breaks: The listing-end and funding-lateness contract in KERNEL.md A18, and
 Brief 4's own Test 12. Three rules in A18 directly collide:
 1. Funding's lateness: an hour H is due when w_start ≤ H, H + late < w_end, and
 "the coin's listing has not ended by H". A coin is held into H when its listing has not
 ended by H and its position is nonzero after every event with time < H. If no funding
 record names H, "the run aborts with R_SETTLEMENT_MISSING, at the end of the
 millisecond H + late."
 2. An hour the venue did not settle: for each whole hour H "before its listing's end"
 with no settlement and whole replies covering [H, H + late], the reader feeds an
 unsettled hour (a = 2), "timed H + late".
 3. A listing's end: the reader feeds the end at τ = e + 1 h + 1 ms, "and every event
 of the coin stamped at or after τ, a relisting's included, is counted and not fed."

11/24/26, 8:08 PM See attached instructions

 Construction: Take Brief 4 step 7 Test 12 verbatim. Coin X is held from day 44, its last
 settlement is 03:00 of day 45, its last book is 03:40, its first flagging copy is in force at e
 = 05:10:00.000, every reply from 04:00 holds no rows, and late = 3,599,999 ms.

 1. The listing ends at τ = 06:10:00.001.
 2. Consider whole hour H = 06:00:00.000. Because 06:00:00.000 <
 06:10:00.001, the listing has not ended by H = 06:00, and X is held through
 06:00 (until 06:10:00.001). Therefore, hour 06:00 is due, and X is held into 06:00.

 3. The unsettled-hour record (a = 2) for H = 06:00 is timed at H + late =
 06:59:59.999, which is 49 minutes and 59.998 seconds after τ. (More generally,
 for every e in an hour except the single millisecond XX:59:59.999—3,599,999 out
 of 3,600,000 ms—H = floor(τ) satisfies H < τ ≤ H + late.)
 4. Collision: If the reader obeys Rule 3 ("every event of the coin stamped at or after τ is
 counted and not fed"), the unsettled-hour record at 06:59:59.999 is dropped, and
 at 06:59:59.999 the engine aborts with R_SETTLEMENT_MISSING. If instead the
 reader feeds a = 2 at 06:59:59.999, it violates Rule 3 and feeds a funding record
 for a coin whose listing and span already ended at 06:10:00.001—and it also
 requires funding-reply coverage through 06:59:59.999 (50 minutes past the end
 window [04:10, 06:10]). Worse, if a genuine late settlement for 06:00 was
 stamped at 06:15:00.000 (valid under late = 3,599,999 ms, outside [04:10,
 06:10]), Rule 3 discards it at 06:15:00.000 while its presence in the record
 suppresses the unsettled-hour record, guaranteeing R_SETTLEMENT_MISSING either
 way.
 Outcome changed: Permanently aborts the forward test (End (1), engine stop) on the first
 delisting of any held coin, leaving CS2.1 without later days and forcing CS2.2 (and CS2.3 if
 before day 61) to "not judged".
 Defect of the design (changes KERNEL.md A18). In Funding's lateness, an hour H should
 be due only if the coin's listing has not ended by H + late (equivalently, a listing's end at
 τ discharges any open funding obligation for H = floor(τ) when τ ≤ H + late, and
 no unsettled-hour record is generated for H when H + late ≥ τ).

 Finding 3. Pre-start delistings still fail with E_HEADER at w_start, and
 mmvault funding leaves permanent coverage gaps on 500-row pages

 What it breaks: GPT section 3's pre-start delisting fix (Brief 4 step 6 wall 2 and step 7
 tests 11–12 vs. KERNEL.md A18's Listings initialization and calendar cutoff), plus the
 contract between mmvault funding (VAULT.md) and A18's funding-reply coverage rule.
 Constructions:

11/24/26, 8:08 PM See attached instructions

 1. E_HEADER on Day 0 for a pre-start delisted coin: Brief 4 requires a universe coin
 delisted before w_start—including one whose flag the venue later dropped—to
 trade nothing and hold nothing (step 6 wall 2; step 7 tests 11–12). Yet KERNEL.md A18
 specifies:
 a copy gives a coin rules only when it has "exactly one entry not flagged
 isDelisted" (a flagged copy only flags it, and a dropped coin gives it nothing);

 a copy with date: null (every copy recorded before round 20's Date-header
 build is deployed) is "no copy";
 "A forward market initializes each universe coin's header rules from the last copy
 in force at or before w_start that gives the coin rules (refusing with E_HEADER
 if none exists)."
 Now trace a freeze on 2027-02-05 (w_start = 2027-02-06): Brief 4 step 7 starts
 study2 capture "on the first of each month from the first after the start" (2027-03-
 01), so every pre-freeze listings file receives since = 2027-03. By A18's
 calendar cutoff (since ≤ M + 2), every listings copy from November or December
 2026 is excluded (2027-03 > 2026-12 + 2). Therefore, any of the 17 universe
 coins delisted in November–December 2026—or before the round-20 date
 build was deployed—has zero eligible unflagged copies at or before w_start,
 causing study2 forward to refuse the entire market with E_HEADER on Day 0.
 2. Permanent uncovered interval at every 500-row fundingHistory page
 boundary: KERNEL.md A18 states that a 500-row fundingHistory reply covers
 only [startTime, last_row.time]. VAULT.md ("Settled funding") advances the
 next page to the whole hour after last_row.time's hour (H + 3_600_000 ms),
 records H in S_c^disk, and never queries H again. On a normal Hyperliquid row
 stamped H + 50 ms, the 59 minutes and 59.95 seconds (H + 50 ms, H + 1 h)
 is permanently uncovered by any reply. If a coin is delisted after a 500-row cold-
 start or backfill page ending at H (common on cold start from 2026-11-01 across
 >21 days, or after a >21-day collector outage), any flagging copy e ∈ (H + 1 h +
 50 ms, H + 2 h) has [e − 1 h, e + 1 h] overlap (H + 50 ms, H + 1 h)
 and cannot end the listing on time (delaying the end by an hour, or blocking it
 indefinitely if the flag is later dropped).
 3. Unstated HTTP-200-[] assumption for dropped coin names: Brief 4 test 11
 assumes fundingHistory answers [] for a coin whose flag the venue dropped.
 Under VAULT.md, if the venue answers an unrecognized coin name with an HTTP
 400/500 or non-array error instead of [], mmvault funding logs an error and
 stores no reply for that coin on every run, so none of its hours is ever shown unsettled
 and the horizon stays at w_start forever.
 Outcome changed: Construction 1 (and Construction 3 if the venue rejects dropped
 names) aborts or stalls the forward study at Day 0, leaving CS2.1, CS2.2, and CS2.3 all

11/24/26, 8:08 PM See attached instructions

 "not judged". Construction 2 delays or prevents a listing end, altering held positions,
 cash release, and W/Wᵇ for CS2.1 and CS2.2.
 Defect of the design (changes KERNEL.md A18, Brief 4, and VAULT.md). A coin delisted
 before w_start with no unflagged copy in the forward record either needs its initial rules
 carried from the registration's last pre-freeze rules (or a flagged entry's own fields, which
 Hyperliquid's meta still carries while the entry remains in universe, or a pre-ended state
 at w_start when absent); and a 500-row fundingHistory page whose 500th row
 settles H should either cover through H + 3_599_999 ms (assuming at most one
 settlement per hour, since a second in H would already be a conflict) or start the next page
 at last_row.time + 1 ms.
 CONTINUE

 User prompt: continue

 Response: Finding 4. The two-clock rule ignores a third clock (the matching
 engine's time), rebuilding the 8.52% false-pass construction even when both
 Date and recv are exact

 What it breaks: CS2.1's 5% supermartingale guarantee on a fair market with a complete
 record, and CS2.1's drafted claim that "a listings copy is read only from the later of its two
 clocks, so no rule is read before the venue could have written it unless both clocks run
 behind", plus the soundness of reach = min(date, recv) − 30 s for
 fundingHistory.

 Construction (8.52% false pass with exact Date, exact recv, and a complete record):
 1. There are three independent clocks in the replay, not two: (i) our host's recv, (ii) the
 HTTP edge's Date (which RECORDER.md notes is "nginx behind CloudFront, not the
 venue's ledger"), and (iii) the venue matching engine's time that stamps l2Book,
 trades, and fundingHistory rows. Both eff = max(date + 1 s, recv) and
 reach = min(date, recv) − 30 s are computed in clock domain (i)/(ii) and then
 directly compared against timestamps in clock domain (iii).
 2. Assume both recv and Date are 100% synchronized to atomic UTC, and the record
 is 100% complete (zero dropped lines, zero missing files). Suppose the matching
 engine's consensus clock runs Δ = +10 s ahead of UTC (any Δ ∈ (2 s, 3,600 s)
 passes every check in the entire specification, including Brief 4 wall 3's 1-hour
 witness tolerance |stamp − recv| ≤ 1 h, and validator block-timestamp skew of
 several seconds against wall-clock UTC is routine in practice).
 3. At true UTC 10:00:00.000, the replica's $100 buy wish arrives against a fair book
 just above $100, stamped by the matching engine as t_buy = 10:00:10.000.

11/24/26, 8:08 PM See attached instructions

 4. At true UTC 10:00:01.000, the fair price jumps (stamped 10:00:11.000): using
 the same two nonpositive-mean gambles from GPT's section 2 (up marks 2,180 with
 probability 1/22 and 2,350 with probability 1/24, down marks 0.91, φ = 1, d =
 100, with the 1/24 reserve).

 5. At true UTC 10:00:02.000 (one full second after the jump), the hourly meta poll
 completes, reporting fine lots on the up branch and whole lots on the down branch,
 with exact Date: 10:00:02 GMT and exact recv = 10:00:02.100.
 6. Round 20's rule assigns eff = max(date + 1 s, recv) = 10:00:03.000.
 Because 10:00:03.000 < 10:00:10.000 = t_buy, the post-jump copy takes
 effect 7 seconds before the pre-jump buy in replay order—filling the $100 buy on
 the up branch and rounding it to zero on the down branch, reproducing the 8.52%
 false-pass rate (1/22 + (21/22)(1/24) ≈ 8.52% > 5%) on a fair venue with a
 complete record and zero clock faults on Date or recv.
 7. Symmetric failure on reach: If the matching engine's clock instead lags UTC by
 Δ = −20 min (again passing the 1-hour witness check) while both Date and recv
 are exact UTC, a fundingHistory poll at true UTC 00:17:00 (reach = 00:16:30)
 returns [] while the matching engine is only at 23:57:00—before H + late =
 23:59:59.999—prematurely marking hour 23:00 "shown unsettled" before the
 matching engine even finished the hour's lateness window.
 8. Secondary derivation flaw (header vs. body time): Even if the matching engine
 and Date shared one clock, HTTP Date timestamps header generation, not body
 completion, and min(date, recv) − 30 s bounds when the HTTP request began,
 not the freshness of an indexed/cached read-replica backing POST /info.
 Outcome changed: Breaks CS2.1's 5% Type I error bound (false "earned" / "outgrew"
 at 8.52% on a fair market with a complete record), and can prematurely mark an unsettled
 hour on reach, affecting CS2.1 and CS2.2.
 Defect of the design and the text (changes KERNEL.md A18, Brief 4 wall 4, and CS2.1's
 draft). Either the reader must bound a REST reply's effective time below by the latest
 matching-engine time already received before it (or only apply a copy after max(date +
 1 s, recv) plus an explicit clock-skew margin), or—at minimum—CS2.1's draft must
 replace its false "unless both clocks run behind" proof with an explicit unverified
 assumption that the matching engine's clock does not lead max(date + 1 s, recv)
 (for listings) or lag min(date, recv) − 30 s (for funding reach).

 Finding 5. Deleting the one-hour check without monotonicity lets a single
 forward-skewed clock resurrect stale rules months later and block
 legitimate listing ends

11/24/26, 8:08 PM See attached instructions

 What it breaks: Round 20's claim (report section 2; ledger D361) that "a clock that is off
 only delays a copy, so the hour check between them is deleted: it protected nothing the later
 clock does not", plus A18's listings-rule and listing-end semantics.
 Construction: Because A18 applies listings copies sorted by eff = max(date + 1 s,
 recv) rather than enforcing monotonicity with acquisition order, and because A18's
 calendar cutoff (since ≤ month(eff) + 2) has no lower bound on since, any single
 reply whose Date or recv jumps forward by hours, weeks, or months becomes a delayed
 time bomb:
 1. On 2027-02-10, coin X is live (unflagged) with szDecimals = 0. One hourly meta
 reply on 2027-02-10 has a transient forward clock fault (either a misconfigured
 edge server Date or a host clock jump on recv) of 2027-04-10 00:00:00. Its file
 receives since = 2027-03, which passes 2027-03 ≤ 2027-04 + 2 = 2027-06.
 2. On 2027-03-01, Hyperliquid legitimately changes X to szDecimals = 2. Every
 hourly meta reply throughout March and early April records szDecimals = 2.
 3. Rule rollback: At 2027-04-10 00:00:00 (between two legitimate April hourly
 copies), the two-month-old February 10 copy activates, rolling X's rules back from
 szDecimals = 2 to szDecimals = 0 for up to an hour—corrupting order lot-
 rounding and fills even though 1,400 newer copies superseded it.
 4. Blocked delisting: Worse, suppose Hyperliquid legitimately delisted X on 2027-04-
 09 23:30 (isDelisted: true, silence on [22:30, 00:30]). At 2027-04-10
 00:00:00—inside (e, e + 1 h]—the resurrected February 10 unflagged copy
 gives X rules and blocks the listing end (delaying cash release and span closure by
 an hour, or blocking the end permanently if the venue later drops the flag).
 Outcome changed: Corrupts lot-rounding, order fills, and listing-end timing on a live or
 delisted coin, altering W, Wᵇ, and CS2.1/CS2.2 verdicts.
 Defect of the design (changes KERNEL.md A18 and Brief 4 wall 4). An earlier copy in
 acquisition order can never supersede a later copy's rules: any copy whose eff exceeds
 the eff of a later copy in acquisition order (or whose eff is later than the file's capture
 month) was displaced forward by an off clock and must be discarded rather than sorted
 into the future.

 Finding 6. Kept-line vs. raw-file divergence on recorder witnesses, and build-
 fault acceptance (End (5)) both misses non-engine contradictions and
 certifies verdicts from a proven-faulty build
 What it breaks: Byte-for-byte host agreement between raw files and kept forms (Brief 4
 step 7 test 13; KERNEL.md A18), End (5) ("a fault of the build"), and the "every later
 accepted report gives the same verdict" invariant for CS2.1–CS2.3.

11/24/26, 8:08 PM See attached instructions

 Constructions:
 1. Raw files vs. kept forms disagree on the recorder witness at T_730 and on
 invalid books:
 Brief 4 wall 3 requires, for "every midnight T′ from w_start to T", an l2Book-
 fast witness line of a universe coin "stamped at or after T′ + 1 h and
 received within an hour of its stamp".
 For T = T_730 (the 730th judged day's end), the witness must be stamped at
 or after T_730 + 1 h (day 731, strictly after w_end = T_730). Yet KERNEL.md
 A18 specifies that a host's kept form keeps only "the lines holding an item some
 run reads (a universe coin's, stamped at or after w_start and in the record of its
 time)" and counts/drops the rest. Because no run ever feeds a line stamped at ≥
 T_730 (nor a crossed/one-sided l2Book-fast line), a host reading kept lines
 drops the T_730 witness (and any crossed/one-sided book witness) while a
 host reading raw files sees it—producing different horizons and breaking byte-
 for-byte agreement on day 730 (or any day witnessed only by a one-sided
 book).
 Separately, including T′ = w_start in "from w_start to T" applies "the
 second month after that of the day before T′" to w_start − 1 day. When
 w_start is the 1st of a month (e.g. 2027-02-01), the day before w_start is in
 2027-01, restricting w_start's witness to since ≤ 2027-03 even though
 day 1 (2027-02-01) allows since ≤ 2027-04.
 2. End (5)'s engine-row-only comparison misses non-engine build faults:
 Brief 4 wall 6 restricts acceptance's cross-month comparison to "the engine's
 rows". It never compares CS2.3's verdict (which depends on vault-pull selection,
 retention counting, chained, given-fill replay, and matched—none of which are
 forward-market engine rows), nor confirm's W/Wᵇ/bar outputs, nor held's
 CS2.2 verdict. If a bug in study2 forward, confirm, held, or vault-pull
 handling causes Month 6 and Month 7 to agree on all engine rows of days 1..90
 while disagreeing on CS2.3's, CS2.2's, or CS2.1's verdict, acceptance fails to
 detect a build fault, violating "every later one gives the same verdict".
 3. End (5) certifies verdicts from a proven-broken build or voting pipeline:
 Suppose Month 6 (days 1..90) and Month 7 (days 1..120) disagree on day 40's
 engine rows, proving either a bug in the frozen binary (violating L1) or two hosts
 erring identically. End (5) and Brief 4 test 13 still certify an "earned" crossing
 on day 35 as a standing study verdict because "the reports [are] alike through
 it".
 Agreement between two runs of a proven-faulty binary on days 1..35 does not
 establish correctness on days 1..35: a bug (e.g., wrong fill/reserve calculation, or

11/24/26, 8:08 PM See attached instructions

 a shared reader defect) can easily produce the same wrong output on days 1..35
 in both months while only diverging at day 40 when a new file enters. Similarly,
 Wall 6 states "CS2.2 and CS2.3 where both agree on their days", which would
 retain Month 6's CS2.3 verdict if engine rows agreed on days 1..61 and diverged
 on day 70—even if the two reports gave opposite CS2.3 verdicts!
 4. Mutable guard disclaimer on "outgrew":
 If "outgrew" is reached on day 90 (Month 6), the test is final but not complete
 until CS2.2 is judged at day 212 (Brief 4 test 6). Because the guard's bar-own-
 mix is recomputed at each replay's last day's end, Month 6's accepted report
 (horizon day 90) can publish "outgrew" with guard < 20, while Month 10's
 accepted report (horizon day 212) can show guard ≥ 20, adding the mandatory
 disclaimer "that the record rejected the null without the rule" (Brief 4 test 7).
 Neither the shared revision nor Brief 4 states which horizon defines "the judged
 record" for that sentence.
 Outcome changed: Construction 1 fails monthly settlement on day 730 (forcing the last
 firing to fall back to Month k − 1, potentially leaving CS2.1 without day 730). Construction
 2 lets contradictory CS2.3/CS2.2/CS2.1 verdicts pass unchecked. Construction 3 publishes
 a false CS2.1 "earned" or CS2.3 "met" verdict from a proven-broken binary. Construction
 4 leaves the published claim wording of "outgrew" inconsistent across accepted reports.
 Defect of the design (changes KERNEL.md A18, Brief 4 step 7 walls 3 and 6, test 13, and
 the shared criteria revision). Fix kept-line retention to explicitly define admissible witness
 items (including time ≥ T_730 + 1 h up to the capture cutoff, and w_start < T′ ≤
 T); compare all published verdicts and confirm/held/CS2.3 outputs alongside engine
 rows in acceptance; withhold all verdicts on a proven build fault rather than salvaging
 earlier ones from a known-faulty build; and pin "outgrew"'s guard horizon to either the
 crossing day or the final judged day.
 CONTINUE

 User prompt: continue

 Response: Finding 7. mmvault funding's daily schedule leaves a permanent
 25–43 minute uncovered hole after 00:17 UTC every day, and A18 leaves
 reach undefined when date is null

 What it breaks: The venue-coverage premise of listing ends (KERNEL.md A18; Brief 4 step
 7 wall 4) and the interaction between VAULT.md's fetch-once schedule and A18's coverage
 interval.
 Constructions:

11/24/26, 8:08 PM See attached instructions

 1. Daily uncovered hole on every coin's 00:00 hour: Under VAULT.md ("Settled
 funding"), the settled CronJob runs daily at 00:17 UTC, waits 60 s before its first
 request, and processes the 17 universe coins at 45 weight / 60 s—one coin per
 minute (00:18 to 00:34 UTC). For coin i, the open-tail reply on Day D arrives around
 00:18 + (i − 1) min, returning Day D's 00:00 settlement (stamped
 ~00:00:00.050) with reach = min(date, recv) − 30 s ≈ 00:17:30 + (i
 − 1) min.

 Because 00:00 is now in S_c^disk, H_max(c) advances to Day D 00:00.
 On Day D + 1, mmvault funding starts its open tail at H_max(c) + 1 h =
 Day D 01:00:00.000 and never queries hour 00:00 again.

 Consequently, every single day on every single coin, the 25–43 minute
 interval (reach, Day D 00:59:59.999] is never covered by any
 fundingHistory reply.

 If coin X makes its last settlement at 00:00:00.050, stops trading at 00:10,
 and is flagged at any e ∈ (reach + 1 h, 02:00:00.000), its silence
 window [e − 1 h, e + 1 h] overlaps (reach, 00:59:59.999]. The
 listing end fails at e and is delayed by an hour (or blocked permanently if the
 venue later drops the flag). The same hole occurs after any out-of-schedule
 manual or backfill run that lands mid-hour.
 Root cause: A18 requires reply coverage over [e − 1 h, e + 1 h] even for
 sub-intervals of an hour H that already has a valid settlement stamped before e
 − 1 h (the exact same root cause behind Finding 3's 500-row page gap).
 Because a coin can have at most one valid settlement per hour (a second is an
 engine stop), an hour already settled at t < e − 1 h needs no further silence
 proof over (t, H + late].
 2. Undefined reach on date: null: A18 explicitly states that a listings copy with
 date: null or an unreadable date is no copy, and Brief 4 test 5 explicitly states
 that a vault pull whose first line has date: null is not late. Yet A18 never states
 what a fundingHistory reply's reach is when date is null or unreadable (while
 RECORDER.md and VAULT.md both store whole replies with "date": null). An
 implementer who falls back to recv − 30 s breaks the two-clock invariant for
 funding coverage; one who gives it no reach must have that specified in A18.
 Outcome changed: Delays or prevents listing ends near UTC midnight (changing held
 cash release, span boundaries, W, and Wᵇ for CS2.1 and CS2.2), and risks divergent reader
 implementations on date: null funding replies.
 Defect of the design (changes KERNEL.md A18 and VAULT.md). Treat any hour H with a
 valid settlement already in its record as covered through H + late for listing-end window
 checks (fixing both this hole and Finding 3's 500-row boundary gap without breaking

11/24/26, 8:08 PM See attached instructions

 fetch-once), and explicitly specify in A18 that a fundingHistory reply with date: null
 or an unreadable date covers nothing.

 Finding 8. CS2.3 conflicting-fill contradiction, retention-count loophole,
 chained worst-case blowup, criteria-draft gaps, and cross-file
 disagreements
 What it breaks: CS2.3's verdict contract (KERNEL.md A18, Brief 4 step 1 wall 1 & step 7
 wall 5/test 5, CS2.3 draft), liveness of chained, and text/spec consistency across the
 bundle.
 Constructions:
 1. Conflicting versions of one fill cannot be handled as specified: A18 ("The vault's
 fills") defines a fill as "one item by its coin, tid and oid" without defining what
 happens when two elements share (coin, tid, oid) with differing fields. Brief 4
 step 1 wall 1 says study2 forward gives chained "the fills of one pull timed in the
 61 judged days" and feeds the given-fill replay the order chained returns,
 withholding CS2.3 "where the replay rejects a fill (two versions of one fill)"; test 5
 tests "two versions of one fill, alike but for their prices".
 If study2 forward deduplicates by (coin, tid, oid) before calling
 chained, the conflicting second version is silently dropped and test 5 fails
 (passing a corrupted pull as "met").
 If study2 forward passes both versions into chained, chained sees two
 nonzero-size fills with the same startPosition and fails the position chain
 before the given-fill replay is ever called (producing the wrong withholding
 reason), and if the two conflicting versions lie on day 62 (outside the 61 days),
 neither chained nor the given-fill replay checks them at all.
 2. Brief 4 test 5 opens a retention-count loophole: Suppose venue retention drops a
 day-10 round trip, leaving 10,000 newer fills in [day 10, day 91]: 9,999 readable
 fills plus 1 fill on day 70 whose time is readable (day 70, outside the 61 days) and
 whose px is "1e-5" (unreadable). The "may lie in the 61 days" check passes because
 time = day 70 is outside the 61 days. Brief 4 test 5 says "10,000 distinct fills at or
 after w_start, an element with no readable time counting as one", which omits an
 unreadable element that does have a readable time ≥ w_start—yielding count
 9,999 < 10,000 and passing CS2.3 on a retention-truncated pull. Conversely, wall
 5 and CS2.3's draft say "each element the reader cannot read counting as one", which
 over-counts unreadable elements with readable time < w_start (from Nov 2026–
 Jan 2027). The exact rule is: count every unreadable element except those with a
 readable time < w_start.

11/24/26, 8:08 PM See attached instructions

 3. chained backtracking is O(k!): Brief 4 step 1 wall 4 implements chained by
 backtracking over permutations of a millisecond's fills. A coin's fills in one millisecond
 are directed edges startPosition → startPosition + sz in a multigraph;
 checking whether a valid chain exists and constructing one is an Eulerian path
 problem solvable in linear time O(k) (degree balance + weak connectivity +
 Hierholzer's algorithm). Naive backtracking explodes as O((k/2)!2 ) on repeated
 same-millisecond round trips or multi-loop bursts (e.g., 16 fills oscillating between
 two levels), risking a timeout that prevents monthly settlement.
 4. Criteria-draft defects and unstated assumptions:
 Shared revision vs. CS2.3 calendar cutoff: The shared revision states
 unqualifiedly that "An item is read for its time only where that month is at most
 the second after the time's own UTC month". CS2.3's late vault pull is asked ≥ 30
 days after day 61 (month M + 3) and first listed in month M + 4 (since ≥ M
 + 4 > M + 2), so the shared revision literally excludes the fills CS2.3 needs
 unless vault pulls are explicitly exempted.
 Shared revision "What it adds" is incomplete: It omits that excluding late-
 arriving items (after M + 2)—such as a late funding debit or conflicting
 settlement—and settling a delisted coin at its last price (releasing cash to trade
 other coins) can both add passing paths against the committed reading.
 CS2.2 "ends before then" ambiguity: CS2.2's draft says "A test that ends
 before then ... leaves the condition 'not judged'". Because End (1) makes the test
 "final" at "outgrew" (which can happen on day 90 while replays continue to
 day 212 per Brief 4 test 6), CS2.2 should say "A test whose replays end before
 the 212th judged day".
 Unstated assumptions: (i) matching-engine clock skew against Date/recv
 (Finding 4); (ii) HTTP Date / read-replica freshness against body content
 (Finding 4); (iii) Hyperliquid answering fundingHistory with HTTP 200 []
 rather than an error for a dropped coin name (Finding 3); (iv) the vault not
 producing 2,000+ fills in one millisecond (VAULT.md's paging premise, absent
 from CS2.3's draft).
 5. Other KERNEL.md A18/A19 vs. Brief 4 / RECORDER.md / VAULT.md
 disagreements: Beyond Findings 1, 2, 3, 6, 7, and 8.1–8.2 above, A18 caps coin names
 at 32 printable ASCII characters with no space while RECORDER.md caps
 stored perp names at 64 bytes.
 Outcome changed: Item 1 can pass a corrupted pull as CS2.3 "met" or misdiagnose
 conflicts; Item 2 can pass a retention-truncated pull as CS2.3 "met" or falsely withhold
 CS2.3; Item 3 risks settlement timeouts; Item 4 leaves criteria text contradicting the
 implementation and omitting load-bearing assumptions.

11/24/26, 8:08 PM See attached instructions

 Defect of the design (Items 1–3 change KERNEL.md A18 and Brief 4 steps 1 & 7) and of
 the text (Items 4–5 change the criteria drafts, A18, and RECORDER.md). Resolve conflicting
 (coin, tid, oid) fills explicitly in A18's pull reader (exact-equality deduplication across
 page overlaps, explicit conflict rejection anywhere in the pull before chained).

 What is larger than its cause and could be deleted
 A18's separate copy's day and the next lie within last_whole_month gate
 (and the plumbing that passes last_whole_month separately from the replay's horizon
 cutoff): it is strictly larger than its cause and is the exact source of Finding 1. Replace it
 with τ < T_cutoff, which automatically keeps [e − 1 h, e + 1 h] inside ≤
 last_whole_month and guarantees every replay reaching T_cutoff agrees on every
 listing end before it.
 Permutation backtracking in chained (Brief 4 step 1, wall 4): replace with the linear-
 time Eulerian-path check and construction, which is simpler to prove for M4 and
 eliminates O(k!) blowup.

 Checking the recorder witness at T′ = w_start (Brief 4 step 7, wall 3): "from
 w_start to T" includes w_start itself, which drags w_start − 1 day's UTC month
 into the cutoff for no reason; judging days run over (w_start, T], so witnessing every
 judged day-end midnight w_start < T′ ≤ T is both cleaner and sufficient.

 What I accept plainly
 From GPT's round 19 review and round 20's answers:
 The calendar cutoff (since ≤ M + 2, running ≤ k − 3), monthly reporting on one
 fixed path, and the operator budget stop on an adapted path.
 Grounding silence (both unsettled hours and listing ends) in stored venue
 fundingHistory replies rather than our own record's absence, deleting round 19's
 Payload.fundingEnd (E), and treating RECORDER.md's unsubscribe as never being
 reader evidence.
 Placing a REST reply between min(date, recv) − 30 s and max(date + 1 s,
 recv) as a bound on the HTTP exchange (once supplemented for matching-engine
 clock skew and acquisition-order monotonicity).
 Closing the listing-end window at both ends [e − 1 h, e + 1 h] and placing the
 end at τ = e + 1 h + 1 ms (once Findings 1, 2, 3, and 7 are fixed).
 Dating CS2.3's pull by its own first reply's clocks, deleting the other-file since proxy,
 stating the retention bound conditional on V18, counting distinct fills, and scoping
 mmvault request failures to their own pull while keeping a 6th consecutive 429 fatal.

11/24/26, 8:08 PM See attached instructions

 Populating kept lines on all voting hosts, bounding retries of no-output runs at the
 next firing, separating the guard's mutable figures from prefix-invariant checks, and
 splitting the four stream states (complete, cut, malformed, corrupt) with zero
 lines read from corrupt streams.
 Consolidating the shared reading/lifecycle/ends text beneath the definitions and
 stating "outgrew"'s conservatism in CS2.1.

 Ledger

 Would change
 Agreed Disputed what is built or
 run?

 Finding 1: Month-end listing-end
 Calendar cutoff (since ≤ M +
 gate (copy's day and the next) Yes (KERNEL.md
 2, ≤ k − 3), monthly reports on
 breaks prefix invariance and triggers A18, Brief 4 wall 3)
 one path, operator budget stop
 a fatal build fault on an honest record
 Venue replies as sole evidence
 of silence; deleting Finding 2: H = floor(τ) is due and
 Payload.fundingEnd; closing held into while a = 2 at H + late ≥ Yes (KERNEL.md
 end window at e + 1 h and τ is discarded, aborting on every A18)
 ending at τ = e + 1 h + 1 held-coin delisting (including Test 12)
 ms

 Findings 3 & 7: Pre-start delistings
 still fail E_HEADER at w_start; 500-
 Fetch-once + gap backfill in row pages and daily 00:17 UTC pulls Yes (KERNEL.md
 mmvault funding; V23 leave permanent uncovered funding A18, Brief 4,
 assumption in principle intervals; fundingHistory HTTP VAULT.md)
 error on dropped names; undefined
 reach when date is null

 Findings 4 & 5: Matching-engine
 third clock rebuilds the 8.52% false-
 Two-clock bounding of HTTP pass rate with exact Date/recv and
 Yes (KERNEL.md
 exchange (min(date, recv) breaks reach; deleting the hour
 A18, Brief 4 wall 4,
 − 30 s, max(date + 1 s, check without acquisition-order
 CS2.1 draft)
 recv)) monotonicity lets forward-skewed
 clocks resurrect stale rules and block
 listing ends
 Populating all voting hosts, Finding 6: Kept lines drop T_730 + Yes (KERNEL.md
 bounding retries, four stream 1 h and invalid-book witnesses seen A18, Brief 4 walls

11/24/26, 8:08 PM See attached instructions

 Would change
 Agreed Disputed what is built or
 run?
 states (corrupt reads nothing), on raw files; End (5) misses non- 3 & 6 / test 13,
 excluding mutable guard figures engine verdict contradictions and shared criteria
 from prefix checks certifies verdicts from a proven- draft)
 broken build; mutable "outgrew"
 guard disclaimer
 Finding 8: Conflicting (coin, tid,
 oid) fill deduplication contradicts
 One late vault pull dated by its chained/replay; Test 5 drops
 readable-time unreadable fills from Yes (KERNEL.md
 first reply; per-pull failure
 the 10,000 count; chained A18, Brief 4 steps
 isolation; V18 conditional
 1 & 7,
 retention; consolidated shared backtracking is O(k!); shared cutoff
 RECORDER.md,
 criteria revision and "outgrew" contradicts CS2.3; incomplete "What criteria drafts)
 conservatism it adds", CS2.2 "ends" ambiguity,
 unstated assumptions, 32- vs. 64-
 byte coin-name cap


