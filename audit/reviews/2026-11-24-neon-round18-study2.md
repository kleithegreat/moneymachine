# Neon (Gemini 4 Neon, web UI) on round 18's study 2 half

Reviewer: Gemini 4 Neon through the web UI, which did not author round 18 (a fresh Opus did). Bundle `neon-r18-study2-bundle.md` (`rearchitecture-s2` `652900a`, 303 KB, every spec whole). Two parts; reply saved by the human as a PDF, extracted with `pdftotext`, received 2026-11-24. Verbatim below.


 See attached instructions

 User prompt: See attached instructions
 Response: Round 18 has not converged. Cutting brief 4 from 170 KB to 79 KB by re-deriving
 around a monthly rest-period capture and "a day is read once" is the right architectural direction,
 and it closes the root causes of several Round 17 defects. However, six defects remain—three of
 them structural breaks in the new core mechanisms (capture-table horizon reconstruction,
 retroactive listing-end lookahead breaking Ville's 5% bound, and delisted-coin funding skips
 breaking Wall 3)—which are presented in two parts (Findings 1–3 below; Findings 4–6, deletion
 trade-offs, and ledger next).

 Round 17 Closure Check (Findings 1–6)
 Finding 1 (D339 open/cut file re-hashing): Closed at its cause for bit-rot capture
 poisoning—hashing each file once after a month at rest eliminates open-file pins and re-
 hashing. However, resetting since when an open file closes after Capture s collides with
 Wall 2's literal "first listed by capture s" rule (Finding 1 below).
 Finding 2 (CS2.1 crossing diagnostics & crash censoring): Closed at its cause for the
 Round 17 defects (the "venue's own wealth" claim and crossing counts are gone, and the
 path-wide assumption and one-sided-book crash censoring are stated honestly). However,
 the same paragraph adds a new false claim ("No part of the record is chosen by what came
 after it") broken by Wall 4's retroactive settlement (Finding 2 below).
 Finding 3 (mmvault userFunding pagination & 24× hourly scan blowup): Closed
 cleanly at its cause by making mmvault daily, stateless, and inclusively paged on
 userFunding (CLUSTER.md still reflects the currently deployed hourly CronJob until
 deployment).
 Finding 4 (Boundary-ms unreadable fill deadlock & finality open-tail range): The three
 specific Round 17 sub-bugs are closed (collector counts nothing; finality deleted; ordering
 applies to all elements with readable time), but the replacements introduce two new
 defects: CS2.3's stateless judging cannot identify the first settled replay (Finding 4 in Part
 2), and deleting finality leaves Wall 3 unable to wait for delayed funding on delisted coins
 (Finding 3 below).
 Finding 5 (Law F0 sub-lot prints & D341 known arithmetic): Round 17's specific F0/test-
 10 defects are closed (recorded size offered as recorded; D341 formula deleted), but
 replaced by Wall 4's retroactive settlement lookahead (Finding 2 below).
 Finding 6 (Pre-w_start stream decoding cost, Date inversion, criteria text, bundle):
 Bundle completeness and the minor CS2.1/CS2.3 text omissions are closed; pre-w_start
 decoding cost is only partially closed (kept lines still retain and re-decode ~211M pre-

11/24/26, 12:53 AM See attached instructions

 w_start quotes of the 17 universe coins every month, Finding 6 in Part 2); and Date
 inversion is moved onto recv and worsened by deleting Date and |recv - Date| <=
 1 h (Finding 5 in Part 2).

 Finding 1 · D345 & D346 (Wall 2, Capture Table, CS2.1): "A
 line added behind is not read" breaks its own invariant
 across first listed vs. since, missing capture dates, and
 engine stops
 What it breaks. Round 18's central theorem ("every later replay reads the same events of every
 time an earlier one ran"), CS2.1 draft (What a replay reads), audit/program/briefs/4-study-
 2.md step 7 (Builds, walls 2–3, test 11), Kernel changes item 3a, D345, and D346.

 Three independent flaws prevent two replays from agreeing on what is dropped as "added
 behind":
 1. first listed vs. since mutates a published day on any file open across a capture.
 CS2.1, wall 2, D345, and Kernel item 3a all define the drop rule using the capture s
 that first listed the file: "a line of a file first listed by capture s, stamped before the
 horizon of the replay of capture s where that replay ran a day, is counted and not read."
 Yet Wall 2 defines the table's column as since: "the month of the first capture that
 listed it at that length" (resetting since whenever an open file grows or closes), and
 never records when a file was first listed.
 Construction (100% honest record, zero clock skew): On Feb 28 at 23:05 UTC,
 listings/20270228/23.<run>.jsonl.zst records a meta copy changing a
 coin's szDecimals. By RECORDER.md test 13 ("At the first frame of a new hour, the
 previous hour's file is closed and its stream ended"), that file remains open until the
 next hour's listings copy arrives. Suppose Hyperliquid's REST endpoint fails from
 Feb 28 23:10 to Mar 1 12:10 (13 hours) while websockets l2Book-fast and
 trades run normally.

 Capture 1 (Mar 1 12:00 UTC): lists listings/20270228/23 open at length L1
 (since = 2027-03, no hash). Replay 1 runs to H_1 = 2027-02-01 (w_start).
 Mar 1 12:10 UTC: REST recovers; the next copy arrives and closes
 listings/20270228/23 by writing its zstd end-of-stream block and
 xxHash32 checksum, growing its length to L2 > L1.
 Capture 2 (Apr 1 12:00 UTC): sees L2 != L1, resets since = 2027-04, and
 does not hash listings/20270228/23. Meanwhile l2Book-
 fast/20270301/01..10 and settled/funding through Feb 28 are
 unchanged and hashed.
11/24/26, 12:53 AM See attached instructions

 Replay 2 (Apr 1): reads only files hashed in Capture 2 (excluding
 listings/20270228/23), advances to H_2 = 2027-03-01 00:00 UTC, and
 publishes Feb 28 without the 23:05 szDecimals change.
 Capture 3 (May 1 12:00 UTC): hashes listings/20270228/23 (since =
 2027-04).

 Replay 3 (May 1): under the literal rule (s = Capture 1, the capture that first
 listed the file), Feb 28 23:05 is not before H_1 (Feb 1), so Replay 3 reads
 listings/20270228/23 on Feb 28, changing order rounding, fills, and W/Wᵇ
 on a day Replay 2 already published. (Only replacing "first listed by capture s"
 with "whose since is s" aligns the cutoff with H_2, the last replay that did not
 hash the file.)
 2. study2 forward cannot compute H_s (or even its own horizon cap) from its capture
 table alone.
 Brief 4 step 7 (Builds) specifies that study2 forward "reads the registration, the
 start, the capture's table and the files that table hashes, and nothing else: no earlier
 report, no state and no clock," and Kernel item 3a requires that "the runner computes
 those horizons from its capture's table."
 Wall 2's table stores only (path, length, since, sha256) with since as a
 month (YYYY-MM). It does not record the list of prior captures or their actual dates.
 Construction: By Test 11, "a capture made four days late moves the next replay's
 horizon by four days," and by Wall 2, "a month with none before the next month's firing
 has none, and 'the capture before' is the last one made." Suppose Capture 2 (2027-
 04.tsv) runs on 2027-04-05 (4 days late), so Replay 3's cap and horizon are H_3 =
 2027-04-05 00:00 UTC. A late file F (since = 2027-05, hashed in Capture 4)
 contains lines stamped 2027-04-03. When Replay 4 reads only 2027-06.tsv, it has
 no record that Capture 2 ran on 04-05 (or whether April had a capture at all).
 Assuming nominal 1st-of-month dates yields H_3 = 2027-04-01, so Replay 4
 feeds F's 2027-04-03 lines and disagrees with Replay 3. (Indeed, Replay 3 itself
 cannot determine its own 2027-04-05 cap from 2027-05.tsv alone.)
 3. Engine-stop horizon vs. Wall-3 horizon is ambiguous and breaks either statelessness
 or finality.
 Suppose Replay s has Wall-3 data horizon T_wall3(s) = Day 50, but hits an
 engine stop (R_SETTLEMENT_MISSING on a held delisted coin, or contradicting
 settlements) on Day 40 04:00 and re-runs to H_actual(s) = Day 40 00:00.
 If "the horizon of the replay of capture s" means H_actual(s), Replay k cannot
 compute H_actual(s) without executing the full engine for every prior capture
 1..k-1; worse, a late file (since = s) carrying a Day 40 02:00 quote/print is not

11/24/26, 12:53 AM See attached instructions

 before Day 40 00:00, so Replay s+1 reads it, can sell the held coin at 02:00, and
 runs past Replay s's final engine stop.
 If it means T_wall3(s) (computed purely from Wall 3 without running the engine),
 study2 forward still must compute T_wall3(1), T_wall3(2), ...,
 T_wall3(k-1) sequentially (because each T_wall3(s) depends on which
 witness/funding/flag lines of files with since < s survived earlier cutoffs)—an
 algorithm nowhere specified in Wall 2 or Wall 3.
 Outcome changed. Published days' rows and CS2.1/CS2.2 verdicts mutate between monthly
 replays, invalidating CS2.1's single-path supermartingale argument and triggering false "fault of
 the build or of two machines" rejections under wall 6.
 Defect of / Fix. Design (brief 4 step 7 walls 2–3, CS2.1 draft, Kernel item 3a).
 1. Define the cutoff strictly by since (the capture s immediately preceding the capture that
 hashed the file), not "first listed."
 2. Embed the ordered header table of all prior captures (capture_id,
 capture_date_utc) inside every <YYYY-MM>.tsv (carried forward verbatim like hashed
 rows, and verified against the remote), so each table is genuinely self-contained.
 3. Define H_s explicitly as the sequential data-availability horizon T_wall3(s) computed
 iteratively from s = 1 to k - 1 (never dependent on running the engine), and specify how
 H_s handles the initial w_start listings rules when earlier replays ran zero days.

 Finding 2 · D348 & CS2.1 ("Why the 5% holds"): Retroactive
 listing-end settlement at E < e + 1 h leaks future
 outcomes into the test ledger and bar, falsifying Ville's 5%
 bound on a gap-free fair martingale
 What it breaks. CS2.1 draft ("Why the 5% holds"—specifically "No part of the record is chosen by
 what came after it: a listing's end removes no event, ending a coin only where the record is silent
 around the flag"), Law K1, Law K3 (Ville's 5% bound), audit/program/briefs/4-study-2.md
 step 7 wall 4, Kernel changes item 2, and D348.
 The mechanism. Wall 4 and Kernel item 2 settle a delisted coin's holding at E (the first whole
 hour after its last event before e - 1 h) whenever a copy at e flags it and the record is silent
 over [e - 1 h, e + 1 h]. Although Kernel item 2 sets the replica view's known time to e +
 1 h + max(listings.lag, funding.lag, δ), the ending event itself is timed at E,
 which is at least ~2 hours (and arbitrarily longer if listings REST stalls or the host clock is ahead)
 before e + 1 h. The test ledger converts the ended coin into cash C (and reduces cost basis B)
 at E, and Rung 2 splits its span at E. Therefore, any buy of another coin between E and e + 1 h

11/24/26, 12:53 AM See attached instructions

 uses cash C and cost basis B that depend on whether the record is silent in [e - 1 h, e + 1
 h]—an event strictly in the future.

 Construction (zero gaps, zero unreadable lines, zero clock skew, exact Rung-1
 supermartingale on both venue and record).
 Take φ = 1, d = 100 (first buy = 100 USD), neglecting O(10⁻⁴) fees (exact with fees too).
 At Day 45 03:40, the replica holds coin X worth 0.90 of ledger wealth (B = 0.90,
 constant price 100, last settlement 03:00 at rate 0, last book 03:40) and cash C = 0.10
 (W = 1.00).
 At 04:05, the replica issues an identical 100 USD first buy of BTC (price 100, valid two-
 sided uncrossed book) on both branches.
 At 04:10, under an exact Rung-1 supermartingale (E[BTC_{04:10} | F_{04:10-}] =
 100), BTC jumps to 199 (w.p. 1/2) or drops to 1 (w.p. 1/2), with valid positive two-sided
 quotes.
 Between 04:10 and 06:10 (strictly after BTC's move at 04:10), market activity on X
 causally depends on BTC's move:
 On the BTC = 199 branch (prob 1/2): X stays quiet after 03:40, Hyperliquid delists
 X, and our hourly listings copy at e = 05:10 flags X with silence on [04:10,
 06:10]. Wall 4 inserts X's settlement retroactively at E = 04:00. At 04:05, the
 test ledger already has C = 1.00, B = 0, so under the 24/25 reserve (24C -
 B)/25 it buys 0.96 of BTC (keeping 0.04 cash). At 04:10, W = 0.04 + 0.96 ×
 1.99 = 1.9504.

 On the BTC = 1 branch (prob 1/2): X remains listed (prints at 05:50 at price 100,
 zero funding). X does not end at 04:00. At 04:05, the test ledger still holds X (C =
 0.10, B = 0.90), so the reserve (24 × 0.10 - 0.90)/25 caps its BTC buy at
 0.06 (keeping 0.04 cash and 0.90 in X). At 04:10, W = 0.04 + 0.90 + 0.06 ×
 0.01 = 0.9406.

 Result: Every single price event on both the venue's market and the complete, gap-free
 record satisfies Rung 1's null (E[r_X | F_{t-}] = 0, E[r_BTC | F_{t-}] = 0), yet:
 1 1
 E[W24:00 ] = (1.9504) + (0.9406) = 1.4455 > 1.0
 2 2
 ​ ​ ​

 Direct violation of the 5% crossing bound: Replace {199, 1} with a single-step
 supermartingale jumping 100 → 2180 w.p. 1/22 and 100 → 0.91 w.p. 21/22 (E =
 99.96 < 100). On the up-branch (1/22), W = 0.04 + 0.96 × 21.80 = 20.968 ≥
 20; on the down-branch (21/22), W = 0.94055 (losing only 6%). Repeating on a second
 coin/day (100 → 2350 w.p. 1/24, 100 → 0.91 w.p. 23/24) yields P(reach 20) = 1/22
 + (21/22)(1/24) = 8.52% > 5%—and repeating across days drives false confirmation
 probability toward 1.

11/24/26, 12:53 AM See attached instructions

 The exact same non-adaptedness affects Rung 2's bar B̄, which starts a new span at E =
 04:00 conditioned on [04:10, 06:10].

 Outcome changed. A run passes CS2.1 ("earned" and "outgrew") with Type I error arbitrarily
 above 5% while Rung 1's and Rung 2's nulls hold strictly on both the venue's market and the
 complete, uncorrupted record.
 Defect of / Fix. Design (brief 4 step 7 wall 4, Kernel item 2, CS2.1 draft). Separate due funding
 hours from the settlement timestamp: keep due funding hours as all hours < E (as now), but
 time the listing-end settlement event (and Rung 2's span boundary) at e + 1 h (or known = e
 + 1 h + max(lags)), strictly after the silence window [e - 1 h, e + 1 h] has closed.
 Because the coin has zero books, prints, or settlements in [E, e + 1 h], its settlement price
 at e + 1 h is identical to its price at E, while cash release and span splitting become strictly
 adapted to the past (under the clocks' premise).

 Finding 3 · D347 & D348 (Wall 3 & Wall 4): Wall 3's delisted-
 coin funding clause skips delayed settlements—
 permanently aborting Study 2 or corrupting Rung 2's bar on
 a 1-day mmvault funding failure—and Wall 3/Wall 4
 circularity can kill a live coin
 What it breaks. audit/program/briefs/4-study-2.md step 7 walls 3 and 4,
 recorder/VAULT.md (Settled funding: "a short page holds its horizon until a later run's open tail
 or gap backfill fetches the rest"), CS2.1 (fails while claim holds), D347, and D348.
 Wall 3 checks funding up to T via:
 "every coin of the forward header has a settlement for every hour from w_start to T,
 or, where its listing ended at or before T (wall 4), for every hour before its last
 settlement: a hole is never let go."
 Deleting Round 17's funding finality check leaves Wall 3 unable to tell "Hyperliquid never settled
 hour H" from "mmvault funding has not fetched hour H yet," creating two concrete failures:
 1. A 1-day mmvault funding outage on a delisting day permanently kills Study 2 (if
 held) or silently drops real funding from B̄ (if flat).
 Construction: On Feb 28 (the day before Capture 1 on Mar 1 12:00 UTC), coin X
 cleanly settles funding at 00:00, 01:00, 02:00, 03:00, and 04:00, has its last book
 at 04:30, and is flagged delisted by listings at e = 05:40 (silence on [04:40,
 06:40], so E = Feb 28 05:00). Suppose mmvault funding's single daily run on
 Mar 1 00:17 UTC fails for X (e.g., an HTTP 500 or a short < 500 page) and succeeds
 on Mar 2 00:17 UTC, backfilling Feb 28 00:00..04:00.

11/24/26, 12:53 AM See attached instructions

 In Capture 2 (Apr 1), listings and l2Book-fast through Mar 1 11:00 are hashed,
 while the Mar 2 settled/funding file is not yet hashed (since = Apr). Thus, in
 Capture 2's hashed files, X's last settlement is Feb 27 23:00.
 When Replay 2 tests T = Mar 1 00:00: Wall 4 sees e + 1 h = Feb 28 06:40
 < T and silence in [04:40, 06:40], so X ended at E = Feb 28 05:00 <= T. Wall
 3 then checks only whether X has settlements "for every hour before its last
 settlement" (Feb 27 23:00)—which is true!
 Wall 3 therefore does not wait for the Mar 2 funding file and sets T = Mar 1
 00:00.

 Outcome:
 If the replica held X at Feb 28 00:00: Hours 00:00..04:00 are < E and
 therefore due (Kernel item 2); the engine aborts with R_SETTLEMENT_MISSING
 at Feb 28 00:00 and permanently ends Study 2, even though Hyperliquid
 settled all five hours and mmvault funding fetched them the very next day.
 If the replica was flat in X on Feb 28: Replay 2 runs past Feb 28
 00:00..04:00 without X's five real funding settlements (and Capture 3 later
 discards the Mar 2 file's Feb 28 rows as "added behind"), silently corrupting
 Rung 2's bar B̄ and the guard's 8 rules.
 2. Wall 3 / Wall 4 circularity allows a 2-hour outage + single glitchy meta copy + 1-day
 funding failure to permanently end a live coin.
 Wall 3's horizon T depends on whether Wall 4 ended coin X, while Wall 4 ends X only
 when Wall 3's T > e + 1 h.
 Construction: Live coin X experiences a 2.5-hour ws outage (04:00–06:30), a single
 erroneous meta copy at e = 05:10 flags X (the 06:10 copy has X unflagged again,
 and valid books resume at 06:30), and mmvault funding fails on that day
 (backfilled the next day, not yet hashed in Capture 2).
 Testing candidate T = next midnight > 06:10: Capture 2 holds no book, print,
 or settlement of X in [04:10, 06:10] (books were down; funding not yet hashed).
 Wall 4 therefore concludes X ended at E = 04:00, which tells Wall 3 to stop waiting
 for X's funding after 03:00.
 Outcome: Replay 2 satisfies the Wall 3/Wall 4 fixed point, permanently ends live
 coin X at 04:00, and discards every quote, print, and settlement of X for the rest
 of the 2-year study—even though Capture 2 itself holds X's live books from 06:30
 onward and an unflagged meta copy at 06:10.
 Defect of / Fix. Design (brief 4 step 7 walls 3–4). For Case 1, Wall 3 cannot treat "last
 settlement currently on disk" as the coin's true final settlement without verifying that mmvault

11/24/26, 12:53 AM See attached instructions

 funding actually queried past E (e.g., requiring a hashed settled/funding open-tail response
 for X received after E—or requiring every hour < E to be settled, accepting that the rare case of
 a coin whose venue genuinely stopped settling before its last book holds the horizon unless a
 hashed post-E funding query shows [] for [last_settled + 1 h, E)). For Case 2, break
 the circularity by requiring no book, print, settlement, or unflagged meta copy of X after e -
 1 h (or at least across [e - 1 h, T] / requiring a post-e + 1 h funding query to confirm X
 really stopped settling) before ending X.
 CONTINUE

 User prompt: continue

 Response: Finding 4 · D349 & D350 (CS2.3, Wall 5,
 VAULT.md): Stateless study2 forward cannot implement
 CS2.3's "first settled replay" rule, Wall 5 contradicts CS2.3,
 and mmvault's stateless full-history fail-stop can brick
 collection for a year on one bad element
 What it breaks. CS2.3 draft (Judged once), audit/program/briefs/4-study-2.md step 7
 (Builds, wall 1, wall 5, test 5), recorder/VAULT.md (One run, Limits), D349, and D350.
 1. Stateless study2 forward cannot identify the "first settled replay," and Wall 5 lets
 later pulls overwrite CS2.3's verdict.
 CS2.3 requires that CS2.3 be "Judged once, by the first settled replay that runs the
 61 judged days and whose capture hashes a whole late pull of the vault's fills... Every
 later replay gives that verdict, computed on that capture's files."
 Yet brief 4 step 7 (Builds) requires study2 forward to read "the registration, the
 start, the capture's table and the files that table hashes, and nothing else: no earlier
 report, no state and no clock."
 Construction A (Unsettled month desynchronizes every later replay): Suppose
 Month 6 (Capture_6) runs 61 days and hashes whole late pull F1 (yielding "met" on
 Capture_6's files), but Month 6 fails to settle under wall 6 (three machines disagree
 or hosts cannot finish) and is passed over. Month 7 (Capture_7) hashes F2, which
 contains a late-arriving fill (or an unreadable element in [2026-11-01, Day 61])
 changing the verdict on Capture_7's files to "not shown" (or "not judged").
 Month 7 settles and is therefore the first settled replay. When Month 8 (Capture_8)
 runs, study2 forward has zero information in Capture_8's table about whether
 Month 6 settled—so if it infers the earliest qualifying capture from the table, it

11/24/26, 12:53 AM See attached instructions

 recomputes CS2.3 on Capture_6 and flips the published Month 7 verdict back to
 "met".

 Construction B (Wall 5 reads all fills files in Capture_k, mutating a settled
 verdict): Conversely, brief 4 wall 5 defines the input as "every fill of the capture's
 fills pulls and of the copy from before 2026-11-01," rather than restricting to the
 judging capture's files. Even if Month 6 did settle as "met", any unreadable element
 or conflicting restatement in Month 10's daily pull F5 (dated inside [2026-11-01,
 Day 61]) mutates Month 10's CS2.3 verdict to "not judged", violating "Judged
 once."
 Construction C (Pre-fix 851fc77 debris poisons chained): Because wall 5 unions
 all hashed files under vault/<user>/fills/ (not just whole pulls) and chained
 runs from pre-2026-11-01 through Day 61 (step 1 wall 1), any partial/corrupt file
 written by the pre-fix 851fc77 collector in November 2026—or a single unreadable
 fill during [2026-11-01, w_start), months before the study began—permanently
 forces CS2.3 to "not judged" even when a clean whole late pull covers every fill.
 2. mmvault's stateless 2026-11-01 pull + fail-stop lets a single bad element brick all
 vault collection for up to a year (or forever).
 VAULT.md (One run, Limits) runs fills from 2026-11-01 (no endTime), then
 funding from 2026-11-01 (no endTime), then fees and orders. Any single
 element failing strict integer time parsing or non-decreasing time fails the entire
 pull, stores nothing, and stops the run before later pulls ("A run stops at its first failed
 pull and sends no request after it").
 Construction: On Day 70 (past CS2.3's 61-day window), Hyperliquid serves one
 userFillsByTime element with a non-integer time (or two fills out of order, or a
 stuck millisecond). Every daily run from Day 70 onward queries from 2026-11-01,
 hits that exact same Day-70 element, fails fills, writes zero files, and never reaches
 funding, fees, or orders. At ~27 fills/day, that element stays inside Hyperliquid's
 10,000-fill retention window for ~370 days, preventing any whole late pull from ever
 being recorded (forcing CS2.3 to "not judged") and destroying a year of
 irrecoverable fees and orders snapshots. Worse, one out-of-order or malformed
 userFunding row in November 2026 has no 10,000-row rollover and permanently
 kills daily fees and orders for the rest of the 2-year study.
 Outcome changed. CS2.3 flips between monthly replays or is permanently forced to "not
 judged" despite a valid 61-day fill record; irrecoverable fees and orders recordings are lost.

 Defect of / Fix. Design (CS2.3 draft, brief 4 step 7 wall 5, VAULT.md).
 1. Judge CS2.3 on the single earliest hashed whole late pull (ordered deterministically by
 (since, path) in the capture table, independent of whether an intermediate month
 failed to settle), rather than unioning all historical fills files and depending on settlement

11/24/26, 12:53 AM See attached instructions

 state not present in the table; check chained over [w_start, Day 61] (initializing each
 coin from its first fill's startPosition at or after w_start, or from the single whole late
 pull alone), which eliminates both Capture_k drift and 851fc77 poisoning.
 2. In VAULT.md, do not let a fills or funding validation failure block fees and orders
 (only network/429/5xx transport failures should short-circuit the run, not payload-shape
 failures on an old page), and store fills pages whose elements fail time decoding as
 raw JSON when the page is valid JSON so the reader—not the collector—decides whether
 an element outside [w_start, Day 61] matters.

 Finding 5 · D351, Kernel item 1 & GPT's Round-4 Objections:
 Deleting Date and |recv - Date| <= 1 h on listings
 breaks acquisition-order vs. recv semantics and leaks
 post-w_start rules into w_start; GPT's Round-4 answers
 have two exposed edges
 What it breaks. KERNEL.md A18 (Kernel changes item 1), audit/program/briefs/4-study-
 2.md step 6 tests & step 7 wall 2, CS2.1 draft (What it adds), recorder/RECORDER.md, and
 D351.
 1. Deleting Date leaves listings copies with a direct contradiction between recv
 timestamps and acquisition order.
 Kernel item 1 deletes Date and |recv - Date| <= 1 h and defines: "each copy is
 timed by its line's recv and taken in acquisition order (run, hour file, line)... A copy
 stamped onto a time a replay already ran is a line added behind (item 3a), so a clock
 that steps back changes nothing published."
 Construction A (Intra-month clock step-back causes either a fatal engine stop
 or rule reversion): On Feb 28 12:00 UTC, Copy 1 arrives (recv = 12:00,
 szDecimals = 1). At 13:00 UTC, NTP steps prodesk7's clock back 2 hours to
 11:00 UTC, and Copy 2 arrives (recv = 11:00, szDecimals = 2, strictly later in
 acquisition order, in the same capture window so not "added behind").
 If A18 feeds copies in acquisition order, Copy 2's recv = 11:00 follows Copy
 1's recv = 12:00, triggering an out-of-order engine stop (CS2.1 end (1)) and
 permanently ending Study 2 on a routine NTP adjustment.
 If A18 sorts copies by recv (using acquisition order only for ties), Copy 2
 (11:00, szDecimals = 2) is applied before Copy 1 (12:00, szDecimals = 1),
 silently reverting szDecimals back to 1 until the next copy.
 Construction B (Month-1 clock step-back injects future post-w_start rules into
 w_start): Replay 1 (2027-03-01) runs zero days (H_1 = w_start = 2027-02-

11/24/26, 12:53 AM See attached instructions

 01). Suppose on Feb 15, prodesk7's clock resets to 2027-01-31 23:00 (<=
 w_start), and mmrec restarts (higher <run> ID) and writes a listings copy
 reflecting a Feb 10 szDecimals change (or delisting). Because Replay 1 ran zero
 days, Wall 2's drop rule ("where that replay ran a day") does not fire. This Feb 15 copy
 has recv <= w_start and is latest in acquisition order, silently overwriting
 w_start's initial rules with Feb 15's state (and if the coin delisted Feb 10, flagging it
 delisted at w_start).
 2. Audit of Round 18's answers to GPT's three Round-4 objections.
 Capture timing lever (GPT R4 #1): Partially closed, residual operator lever remains.
 Under Wall 2 and Test 11, delaying Capture k by four days moves Replay k+1's horizon
 by four days—and also shifts since for any late file written during those four days. If
 a file holding Feb 28 lines arrives on Mar 3, an on-time Mar 1 capture excludes those
 lines as "added behind" (under Finding 1's fix), while a capture delayed to Mar 4
 includes them. Because delayed captures are permitted and logged rather than
 refused, this relies on trusting the capture operator not to time delays against late
 files (the same trust model as D191's push timestamp, which should be stated
 explicitly as an assumption rather than claimed impossible).
 Wait that avoids a stop (GPT R4 #2): 5% Type I error holds; "adds no way to pass" is
 overstated. Holding the horizon at a missing settlement does keep all crossings inside
 Ville's single 5% bound over {1..730}. However, relative to the committed criteria
 (which ran to the hole and stopped the test), waiting for backfill does add passing
 sample paths (records that would have ended uncrossed at the hole can now wait
 and cross later). The report's "Whether 'adds no way to pass' still holds: yes against
 judging each day once at first publication" shifts the baseline instead of admitting
 plainly that waiting adds passing paths relative to the committed text while
 preserving the 5% error bound.
 First of a key (GPT R4 #3): Closed for published days (once Finding 1 is fixed), at the
 unstated cost that a conflicting second settlement or conflicting print arriving after
 its day was published is silently dropped as "added behind" rather than stopping the
 engine under End (1)—which CS2.1's End (1) should note explicitly.
 Outcome changed. A benign NTP step-back either aborts Study 2 as an out-of-order event or
 reverts/leaks coin rules across w_start; CS2.1's "What it adds" understates the change relative
 to the committed text.
 Defect of / Fix. Design (Kernel item 1, brief 4 step 7 wall 2) and text (CS2.1 What it adds & The
 ends). Either restore the lightweight |recv - Date| <= 1 h check on REST listings copies
 (which already closed single-clock skew cleanly in Round 17 without affecting websocket
 streams) or clamp each copy's effective timestamp monotonically in acquisition order (t_eff =
 max(recv, prev_t_eff)) AND explicitly forbid any file with since after w_start (or created
 after w_start) from supplying pre-w_start initial rules. State the capture-timing trust
 assumption and the post-publication contradiction drop plainly in CS2.1.

11/24/26, 12:53 AM See attached instructions

 Finding 6 · D346 & Wall 6 (Kept Lines, Pre-w_start Cost, and
 Deleting Halts): Kept lines still re-decode ~211M pre-
 w_start universe quotes every month, lose hash
 verification and 3-host resilience on single-copy bit-rot, and
 deleting halts lets a detected build/machine fault keep
 publishing
 What it breaks. audit/program/briefs/4-study-2.md step 7 (walls 1, 2, 6; test 9), Kernel
 changes item 3c, and D346.
 1. Kept lines do not close Round 17 Finding 6a's pre-w_start cost and break 2-of-3 tie-
 breaking on a dead 2026 file.
 Kernel item 3c defines kept lines as "its lines in order, less those
 Coin_route.classify_line skips unread (another coin's)." Because Coin_route
 filters only by coin (not by w_start), all ~211 million pre-w_start quotes of the 17
 universe coins (2026-11-14 to 2027-02-01) remain in every host's kept lines and
 are re-decompressed and 3-pass jsont-decoded on every monthly replay (four runs
 per month, 24+ months).
 Meanwhile, Test 9 specifies that if 1 bit flips in a hashed file on prodesk7, "a host that
 has not read it gives no output, and one that has gives the output it gave."
 Construction: Hosts A and B run Months 1–5 (caching kept lines for all pre-w_start
 2026 files); Host C has not yet been needed. In Month 6, 1 bit flips in a dead
 November 2026 l2Book-fast file (zero judged events). In Month 10, a transient fault
 causes Hosts A and B to disagree; Host C is invoked as tie-breaker, checks the 2026
 file's SHA-256, fails, and produces no output. A dead 2026 file permanently
 destroys 2-of-3 tie-breaking (and if Host A or B's local cache is ever rebuilt,
 permanently ends all future replays).
 Furthermore, Wall 2's claim that "every file its capture hashes [is] checked against its
 hash before a line of it is fed" is false on every replay after the first: a host trusts its
 local kept-lines cache by filename/hash key without any specified integrity check on
 the cached kept-lines file itself, and Kernel item 3b's failed-checksum count must
 also be explicitly serialized in that cache or kept lines diverge from raw reading.
 2. Deleting halts leaves Wall 6's detected prefix-mismatch fault running unstopped.
 Wall 6 adds an external check: "The advisor's acceptance (step 6) also compares a
 report's rows of the days the last accepted report ran with that report's: a difference is
 a fault of the build or of two machines, logged, and the earlier report's verdicts stand."

11/24/26, 12:53 AM See attached instructions

 Yet Wall 1 states "nothing halts" and the timer keeps running until complete, last
 firing, or operator stop.
 Construction: Suppose a deterministic bug in study2 forward (e.g., an
 uninitialized kept-lines cache interaction) causes two machines in Month 10 to agree
 on mutated rows for Month 9's days. Acceptance catches the mismatch and rejects
 Month 10—yet nothing stops Month 11 from running on the exact same broken build
 and publishing new verdicts for Month 11 once its prefix happens to match (or forcing
 manual ad-hoc intervention outside the criteria).
 Outcome changed. Hours of wasted CPU per replay on dead 2026 data; loss of 2-of-3
 redundancy on a single bit-flip in a 2026 file; undetected local cache corruption or continued
 publication after a proven build/2-machine fault.
 Defect of / Fix. Design (brief 4 step 7 walls 2 & 6, Kernel item 3c).
 1. Let study2 capture skip hashing l2Book-fast/, trades/, and settled/funding/
 files whose lines are provably < w_start (or store a verified empty marker /
 max_venue_time < w_start in kept lines after reading once, and exclude pre-w_start
 stream directories from the capture table once w_start is known—only listings/ and
 vault/fills/ are needed before w_start).

 2. Store an explicit SHA-256 (or checksum-failed status) for each kept-lines cache entry so
 cache corruption is caught before feeding lines.
 3. Make a verified prefix mismatch in Wall 6's acceptance check explicitly terminate further
 replays (recording it as a build/machine fault where the last accepted report stands), rather
 than letting a known-broken build keep running.

 What Is Still Larger Than Its Cause, and What Round 18's
 Deletions Lost
 Still larger than its cause (can be deleted or cut further):
 Unioning all historical fills pulls across months for CS2.3 (Wall 5). Once CS2.3
 already requires one whole late pull covering [w_start, pull_time] with < 10,000
 elements, unioning every daily fills pull ever written since November 2026 adds multi-
 pull version-conflict complexity, 851fc77 debris exposure, and cross-month verdict drift
 (Finding 4) for zero statistical gain. Judging CS2.3 from the single earliest qualifying whole
 late pull alone is strictly smaller and cleaner.
 Hashing and keeping pre-w_start l2Book-fast/ and trades/ files (Wall 2). Test 3
 proves pre-w_start market events change nothing, yet every host still hashes, caches,
 and re-decodes ~211M pre-w_start universe quotes every month (Finding 6). Only
 listings/ (and pre-2026-11-01 vault fills) are needed before w_start.

11/24/26, 12:53 AM See attached instructions

 Re-pulling mmvault fills from 2026-11-01 daily for two years after CS2.3 is judged
 (VAULT.md). Keeping mmvault stateless is a clear win, so keeping the 2026-11-01 floor
 is reasonable—only if a single bad historical element cannot block
 funding/fees/orders (Finding 4).

 What Round 18's deletions lost (trade-offs that must be either restored or explicitly
 accepted):
 Deleting funding finality (D348) lost the ability to distinguish "venue stopped
 settling a delisted coin" from "mmvault funding missed a day," creating Finding 3's
 false aborts and live-coin kills. A minimal post-E funding-query witness (much smaller
 than Round 17's 30-day finality machinery) is still needed.
 Deleting Date and |recv - Date| <= 1 h on REST listings (D351) lost single-clock
 skew protection on listings, reopening NTP step-back engine stops and Month-1
 w_start rule leakage (Finding 5).

 Deleting State_k / accepted.tsv lost the runner's knowledge of which capture was
 the "first settled replay" for CS2.3 (Finding 4) and lost the explicit prior-capture date
 history needed to compute H_s statelessly (Finding 1).
 Deleting halt_storage_corrupt and halt_non_deterministic lost a clean stop
 rule when Wall 6 detects a build/2-machine prefix divergence (Finding 6) and shifted
 de facto backup responsibility onto unverified host-local kept-lines caches.

 What I Accept
 Core architecture of Round 18 (D345–D346 direction): Replacing open-file pins, fsync
 capture chains, two-host seekable packs, T* truncation, withdrawals, and State_k carry-
 forward with a monthly rest-period capture (hash once after 1 month unchanged) and "a
 line added behind is not read" is a genuine simplification at the root cause—once Finding 1
 fixes since, embedded capture dates, and sequential T_wall3(s).
 Daily stateless mmvault with inclusive userFunding paging (D350 core): Cleanly
 closes Round 17 Finding 3's 24× scan blowup and multi-coin 500-row boundary skips
 (subject to Finding 4's payload-error isolation).
 Restated CS2.1 5% null and diagnostics (D351 core): Dropping the false "venue's own
 wealth" claim, reporting path-wide staleness/unreadable lines without overclaiming, and
 accurately stating one-sided-book/zero-print crash censoring cleanly closes Round 17
 Finding 2 (once Finding 2 fixes Wall 4's retroactive listing-end lookahead).
 CS2.2 draft & Law F0 fix (D352 core): CS2.2's operator-stop rule, offered recorded sizes
 without coin-rule lot rounding, CS2.3's inline aggregateByTime: false condition, and
 moving study2 measure outside the frozen build are all clean.

11/24/26, 12:53 AM See attached instructions

 CLUSTER.md & RECORDER.md tail: Audited unclipped; the 205 (410 kill-doubled) REST
 weight allocation, 60 s startup hold, mmrec routing/re-pairing quantifier, and mmrec cat
 chunk invariance are solid (noting CLUSTER.md's workload table will need updating from
 hourly to daily when the new mmvault and settled CronJobs deploy).

 Ledger
 Status Point Changes what is built or run?

 Round 18's rest-period hash-once capture
 direction (D346 core), daily stateless mmvault +
 inclusive userFunding paging (D350 core),
 restated CS2.1 5% null & crash-censoring
 Agreed wording (D351 core), CS2.2 operator-stop draft, No
 offered recorded sizes (F0), study2 measure
 outside frozen build, CLUSTER.md weight
 budget & RECORDER.md routing/chunk
 invariance
 Finding 1 · D345 & D346 (first listed vs.
 since, missing capture dates, engine-stop
 Yes (study2 capture table
 vs. Wall-3 H_s): Open files crossing a capture
 schema, study2 forward
 Disputed mutate published days; stateless study2
 Wall 2/3 logic, Kernel item 3a,
 forward cannot compute H_s or its own
 CS2.1 draft)
 horizon cap from <YYYY-MM>.tsv alone;
 engine-stop H_s is ambiguous
 Finding 2 · D348 & CS2.1 (Retroactive listing-
 end settlement at E < e + 1 h): Settling a
 delisted coin's cash/cost basis and splitting
 Yes (Kernel item 2, brief 4 step
 Disputed Rung 2's span at E conditioned on silence over
 7 wall 4, CS2.1 draft)
 [e - 1 h, e + 1 h] leaks future outcomes
 into buys between E and e + 1 h, breaking
 Ville's 5% bound on a gap-free fair martingale
 Finding 3 · D347 & D348 (Wall 3 delisted-coin
 funding skip & Wall 3/Wall 4 circularity): A 1-
 day mmvault funding outage on a delisting
 day skips T past unfetched settlements— Yes (brief 4 step 7 walls 3–4,
 Disputed
 permanently aborting Study 2 if held or CS2.1 draft)
 corrupting B̄ if flat; a 2.5 h ws outage + 1 glitchy
 meta copy + 1-day funding delay permanently
 ends a live coin

11/24/26, 12:53 AM See attached instructions

 Status Point Changes what is built or run?

 Finding 4 · D349 & D350 (CS2.3 stateless
 judging vs. "first settled replay", Wall 5
 multi-pull union, mmvault fail-stop bricking):
 Later replays cannot know if an earlier capture
 Yes (CS2.3 draft, brief 4 step 7
 Disputed settled; Wall 5 lets later pulls or 851fc77 files
 wall 5, recorder/VAULT.md)
 mutate/poison CS2.3; one bad element on Day
 70 bricks daily mmvault
 fills/funding/fees/orders for ~370 days (or
 permanently for userFunding)
 Finding 5 · D351 & Kernel item 1 (listings
 Date deletion & GPT R4 answers): Deleting
 Date makes an intra-month NTP step-back
 Yes (Kernel item 1,
 either halt Study 2 out-of-order or revert
 recorder/RECORDER.md,
 Disputed szDecimals, and lets a Month-1 step-back
 brief 4 step 7 wall 2, CS2.1
 overwrite w_start initial rules with future
 draft)
 rules; CS2.1 overstates "adds no way to pass"
 for funding waits and omits capture-delay trust
 and dropped post-publication contradictions
 Finding 6 · D346 & Wall 6 (Kept lines &
 deleted halts): Kept lines still retain and re-
 Yes (study2 capture,
 decode ~211M pre-w_start universe quotes
 study2 forward kept-lines
 Disputed every month, lack cache integrity checks, and
 cache, Kernel item 3c, brief 4
 lose 2-of-3 tie-breaking on a 2026 file bit-flip;
 step 7 walls 1, 2 & 6)
 deleting halts leaves a Wall-6-detected build/2-
 machine prefix divergence running unstopped

 Does any dispute change what is built or run? Yes—all six disputes change what is built or
 run (study2 capture table format, study2 forward horizon/kept-lines/CS2.3 logic,
 recorder/VAULT.md fail-stop behavior, KERNEL.md A18 items 1–3, and the CS2.1/CS2.3
 criteria drafts).


