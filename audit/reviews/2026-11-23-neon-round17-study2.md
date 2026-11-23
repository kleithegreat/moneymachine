# Neon (Gemini 4 Neon, web UI) on round 17's study 2 half

Reviewer: Gemini 4 Neon through the web UI, which did not author round 17 (a fresh Opus did). Bundle `neon-r17-study2-bundle.md` (`rearchitecture-s2` `1457cb3`, 405 KB, the architect's report and criteria drafts first; the builder test lists omitted; `RECORDER.md`'s tail and `CLUSTER.md` not read). Reply saved by the human as a PDF, extracted with `pdftotext`, received 2026-11-23. Verbatim below.


 See attached instructions/

 User prompt: See attached instructions/
 Response: Round 17 has not converged. Several Round 16 defects are closed cleanly at their
 cause: reading no market event against its coin's rules (D337) removes the off-rule content-drop
 bias and the book/print pairing break during szDecimals changes; the two-clock witness
 |recv - Date| <= 1 h on REST replies (D338) stops single-clock proxy skew from mutating
 published days or forging 30-day waits; deleting state.json closes the 40-day mmvault
 deadlock; counting raw returned elements closes the simple Day-80 unreadable-fill retention
 bypass (D340); and the re-pairing quantifier and ingest/hl.py removal (D342, D343) are
 clean.
 However, six defects remain across D339, D337/CS2.1, D338/VAULT.md, D340/CS2.3, and D341
 (Findings 1–6 below), and CLUSTER.md plus the tail of recorder/RECORDER.md were
 absent/truncated in the bundle.

 Finding 1 · D339 & Step 1 Capture: Permanently cut (killed-
 run) files and previously-open file prefixes are still re-
 hashed by Step 1, re-opening silent bit-rot capture
 poisoning
 What it breaks. audit/program/briefs/4-study-2.md step 7 wall 3 ("The capture" item 2
 and "Closed-hour per-coin seekable packs"), and D339.
 D339 directs Step 1 to carry forward pins verbatim only for files an earlier capture pinned as
 closed, while re-hashing every file "not pinned before, or pinned open". Meanwhile, Opus F4.1
 defines a l2Book-fast or trades hour file as provably closed if and only if its zstd stream
 ended cleanly with valid trailing xxHash32 and exact EOF ("never inferred from <run> ids;
 truncated/cut killed-run files are never packed and stay raw"). That creates two direct silent-
 corruption bypasses:
 Permanently cut (killed-run) files stay "open" forever.
 On Day 15, mmrec is SIGKILLed/OOMKilled, leaving a truncated l2Book-
 fast/20270215/14.<run>.jsonl.zst (F, length L1 , hash H1 ) with no clean zstd
 ​ ​

 EOF.
 Because F is never provably closed, Capture_1 through Capture_4 pin F as open
 at (L1 , H1 ).
 ​ ​

11/22/26, 9:55 PM See attached instructions/

 Between Month 4 and Month 5, silent bit-rot flips 1 bit inside F (length still L1 , hash
 ​

 now Hcorrupt =
  H1 ).
 ​ ​

 Month 5's Step 1 sees F was pinned open in Capture_4, reads length L1 , freshly​

 hashes F to Hcorrupt , writes Hcorrupt into immutable Capture_5, and pushes it to
 ​ ​

 audit/study2/captures.tsv.

 Both replay hosts verify sha256(F) == H_corrupt (so E_HASH never fires), hit the
 corrupted zstd block on Day 15, truncate Day 15's events differently from State_4,
 and permanently end Study 2 as end_study (changed) at T ∗ = Day 14 instead
 of settling halt_storage_corrupt.
 Already-pinned prefixes of live open files are never re-verified.
 At Capture_1, a genuinely open file F is pinned at (L1 , H1 ). After Capture_1,
 ​ ​

 mmrec appends bytes and closes F cleanly at L2 > L1 , and before Capture_2 bit-
 ​ ​

 rot flips 1 bit inside the already-pinned prefix [0, L_1).
 Month 2's Step 1 sees F was pinned open in Capture_1 and hashes [0, L_2) into
 H_2 without checking sha256(F[0..L_1)) == H_1, baking corruption of Month 1's
 published bytes into Capture_2 (and into a new two-host pack of F, if packed!).
 Outcome changed. Turns storage corruption (halt_storage_corrupt) in any killed-run
 stream/listings file or any previously-open file's prefix into an immutable poisoned capture and
 premature end_study (changed) at T ∗ .

 Defect of / Fix. Design (Step 1 in brief 4 step 7 wall 3). Because files are append-only, bytes [0,
 L_prev) of any previously pinned file may never change:

 1. If a file previously pinned as open has stat(f).size == L_prev and has not cleanly
 closed, carry (L_prev, H_prev) verbatim without re-hashing.
 2. If it grew to L_new > L_prev (or cleanly closed), verify sha256(f[0..L_prev)) ==
 H_prev before minting a new pin; if the prefix mismatches (or stat(f).size < L_prev),
 carry (L_prev, H_prev) verbatim so Step 2 settles halt_storage_corrupt against
 the original bytes.

 Finding 2 · D337 & CS2.1 Criteria Draft ("Why the 5% holds"):
 The "venue's own wealth" claim and crossing diagnostics
 are mathematically false, and the unreadable-event caveat
 misstates crash censoring as next-move predictability
 What it breaks. CS2.1 criteria draft ("Why the 5% holds"), audit/program/briefs/4-study-
 2.md step 7 test 7, and D337.

11/22/26, 9:55 PM See attached instructions/

 The redrafted CS2.1 claims:
 A day's end at which every coin held is valued at the venue's own last price before
 that midnight, after no listing end whose cut removed a quote or print the venue had
 made, is a day's end of the venue's own wealth, and a crossing there needs the
 assumption only for what no line of the record shows. So the report gives, beside
 each crossing, the coins held at its day's end that were stale there or whose last book
 or print before it the record holds and cannot read, and each listing's end before it at
 which the cut removed quotes or prints before the flag's bound. Where a book or
 print the model cannot read foretells the next move, as bids all pulled before a fall
 would, the null on these prices is false whatever the rule, and a pass need not mean
 the rule used anything.
 Three distinct defects break these statements:
 Path dependence of holdings and cash refutes "a day's end of the venue's own
 wealth."
 Suppose at 12:00 on Day 1, coin X trades at P0 = 100 and at 12:01 moves under an
 ​

 exact Rung-1 martingale to P1 = 200 (w.p. 1/2) or P1 = 0 (w.p. 1/2).
 ​ ​

 Suppose an unreadable print at 11:59 unpairs X's books on the down-branch only,
 making X stale at 12:00 so the replica's buy is refused on the down-branch (W = 1),
 while on the up-branch X is fresh, the buy fills, and W = 2. At 12:05 X recovers with
 valid prints and books.
 At midnight 24:00, on both branches, every held coin is fresh, valued at the venue's
 exact last price before midnight, with zero unreadable last lines and zero listing ends
 —yet W24:00 is not the venue's own wealth, and E[W24:00 ] = 0.5(2) + 0.5(1) =
 ​ ​

 1.5 > 1.
 Furthermore, for Rung 2, the bar B̄ is a function of every universe coin (held or not)
 across all Days 1 … D. An unrecorded/unpaired span or unreadable line on any non-
 held coin (or on any earlier day) alters B̄ at Day D's midnight while leaving the held-
 coin midnight count at zero.
 The < 60 s l2Book-fast-unpaired blind spot defeats the midnight valuation
 diagnostic itself.
 Capture_k excludes l2Book-fast-unpaired and events.

 Suppose at 23:59:20 on Day D, either X's trades subscription drops on a reconnect
 or a coinless/unparseable frame on X's socket (routed to events) unpairs every coin
 on that connection. Between 23:59:20 and 23:59:59, X crashes 50% across 70 valid
 books, all diverted to l2Book-fast-unpaired.

11/22/26, 9:55 PM See attached instructions/

 At midnight 24:00:00, X's last fed quote (23:59:19) is 41 seconds old (< G = 60 s),
 so X is not stale, and X's last line in Capture_k is readable (no unreadable print of X
 exists in trades).
 The report's crossing diagnostics print 0 stale held coins and 0 unreadable last
 lines, even though X is valued at a pre-crash price while the recorder itself recorded
 the crash in l2Book-fast-unpaired.
 Pushing unreadable events into the null misstates contemporaneous censoring as
 next-move predictability.
 Consider a one-step fair martingale (t = 0 → 1, no further moves): P0 = 100; at
 ​

 t = 1, w.p. 1/2 the book is 199.9/200.1 (P1 = 200), and w.p. 1/2 all bids vanish
 ​

 into a one-sided book (no bids, ask 0.01) or print at 0.
 Because the null defines unreadable books/prints to "move no price," the model's
 price process is P1 ∈ {200, 100} with E[P1 ] = 150 > 100—strictly positive drift
 ​ ​

 on the censored step itself, with no next move to foretell. Framing this as "Where a
 book or print the model cannot read foretells the next move" conflates
 contemporaneous censoring (which breaks Rung 1 on an i.i.d. martingale) with serial
 dependence (Rung 2's limit).
 Outcome changed. Overstates what zero midnight diagnostic counts certify about a crossing,
 and mischaracterizes when the restated Rung-1 null fails on a fair market.
 Defect of / Fix. Criteria text (CS2.1 draft) and reporting (brief 4 step 7 test 7). Withdraw the claim
 that an unflagged crossing is "a day's end of the venue's own wealth" needing the assumption
 only for unrecorded lines; state that the price-independence assumption applies over the entire
 path 1 … D for holdings, cash, and B̄; report cumulative stale/unreadable counts over Days
 1 … D (noting that l2Book-fast-unpaired diversions within G are unseen in Capture_k);
 and state plainly that defining unreadable events to move no price makes the null on model
 prices false whenever crashes manifest as one-sided/crossed books or zero prices, even
 without predicting a subsequent move.

 Finding 3 · D338 & VAULT.md: mmvault (userFunding)
 pagination contradicts itself and drops coins on boundary
 hours; hourly 30-day pulls cause a 24× storage/scan
 blowup risking CronJob starvation
 What it breaks. recorder/VAULT.md ("One run" items 1–2, "Identities", "Limits"),
 audit/program/briefs/4-study-2.md step 7, and D338.

 Concrete data-loss bug in mmvault (userFunding) pagination.

11/22/26, 9:55 PM See attached instructions/

 VAULT.md "One run" item 2 says mmvault's userFunding pull is "paged at its cap of
 500 and checked the same way" as item 1 (fills, which pages inclusively at
 last_time).

 Yet VAULT.md "Limits" (inside the mmvault section) specifies: "a funding page at the
 whole hour after its predecessor's last row"—copied from single-coin mmvault
 funding (fundingHistory).

 Unlike fundingHistory (1 row per coin-hour), userFunding returns funding rows
 for all coins the vault held, so up to 17 coins share the same hour/day timestamp.
 On any 500-row page (e.g., cold start or outage recovery) whose 500th row is the
 4th coin of hour/day H , starting Page 2 at H + 1 h permanently skips all
 remaining coins' userFunding rows for H , breaking layer 1's funding witness and
 V8's forward measurement.
 24× amplification and Year-2 CronJob starvation from deleting the daily cadence.
 Deleting the daily trigger causes mmvault to run a full ≥ 30-day fills pull and a full
 ≥ 30-day funding pull every hour (17,520 files over 730 days, storing every fill ~720
 times instead of ~30 times).
 Worse, VAULT.md ("Identities") rebuilds stored identities and coverage from all stored
 files on every hourly run, and study2 forward hashes and 3-pass jsont-decodes
 all stored mmvault files on every monthly replay.
 At the 2026 rate (~822 fills/30 d), Month 24 accumulates ~14.4 million JSON fill
 objects (~5.8 GB uncompressed JSON) re-scanned in 3 jsont passes every hour; at
 a 3–5× higher trading rate (~17–29 GB uncompressed JSON), each hourly startup
 scan can exceed 60 minutes, triggering concurrencyPolicy: Forbid and
 permanently losing irrecoverable hourly userFees (V4) and historicalOrders.
 Outcome changed. Lost userFunding rows on multi-coin 500-row boundaries; severe
 runtime/disk bloat in mmvault and study2 forward, risking starvation of hourly fees/orders
 captures.
 Defect of / Fix. Design (recorder/VAULT.md).
 1. Fix VAULT.md "Limits" so mmvault's multi-coin userFunding pages inclusively at
 last_time (stopping stuck if last_time == startTime on a 500-row page), keeping
 whole-hour advancement strictly for single-coin mmvault funding.
 2. Split mmvault into two stateless CronJobs (zero state.json, zero host-clock cursors):
 an hourly CronJob (fees, orders) and a daily CronJob (fills, funding), eliminating the
 24× amplification while keeping the exact same file-derived pull logic.

11/22/26, 9:55 PM See attached instructions/

 Finding 4 · D340 & CS2.3 / VAULT.md: Deduplication
 asymmetry on boundary-millisecond unreadable fills
 deadlocks CS2.3 coverage between mmvault and study2
 forward; plus finality open-tail range ambiguity
 What it breaks. recorder/VAULT.md ("Identities", "What a capture reads as coverage", "What
 the reader trusts of a pull"), audit/program/briefs/4-study-2.md step 7 wall 3 ("What the
 reader rechecks", "The horizon"), CS2.3 draft, and D340.
 Boundary-millisecond unreadable fill deadlocks mmvault vs. study2 forward.
 Fills pages overlap inclusively on the boundary millisecond last_fill.time.
 Suppose a completed pull returns 9,999 distinct fills across 5+ pages, and one fill on
 a page-boundary millisecond (say on Day 80, outside CS2.3's 61-day span) has valid
 (coin, tid, oid, time) but px: "1e-5" (unreadable as a full fill by study2
 forward).

 VAULT.md ("Identities") states mmvault reads only (coin, tid, oid, time)
 ("and nothing else of any item") and deduplicates by (coin, tid, oid). Thus
 mmvault counts 9,999 (< 10, 000), marks [Day 1, Day 61] covered, and
 advances all future pulls' startTime past Day 61.
 Meanwhile, study2 forward (CS2.3 draft / VAULT.md) counts "each distinct fill
 counted once and each element the reader cannot read as a fill at its time" without
 deduplicating unreadable elements. Because the Day-80 fill appears on both Page j
 and Page j + 1, study2 forward counts 9, 998 + 2 = 10, 000 (<  10, 000),
 declares [Day 1, Day 61] uncovered, and leaves CS2.3 waiting until the last
 firing ("not judged"), while mmvault never re-pulls Day 1–61 again.
 Open-tail range ambiguity in finality disqualification.
 Brief 4 requires that "no page of the coin in the capture whose range meets those
 hours holds an element the reader cannot read in them, or with no time it can read".
 An open-tail fundingHistory page has endTime = none (no explicit upper bound
 in its request). If a reader treats an open-tail page's range as [startTime, +∞),
 then a single element with unreadable time stored on Day 10 (whose page's Date
 was Day 10, 35 days before Day 45's delisting) permanently blocks Day 45's finality
 forever.
 Element ordering wording in VAULT.md.
 "What the reader trusts of a pull" states "every fill's time is at or after its page's
 startTime and none before the fill before it". Clarify that this check applies to every

11/22/26, 9:55 PM See attached instructions/

 element with a readable time (including elements unreadable on other fields), not
 only fully decoded fills.
 Outcome changed. mmvault permanently stops covering CS2.3 while study2 forward
 refuses to judge CS2.3; or an unrelated historical open-tail page permanently stalls T on a later
 delisting.
 Defect of / Fix. Design (VAULT.md and brief 4 step 7 wall 3). Make mmvault's coverage check
 strictly conservative relative to study2 forward (either count raw page elements or decode
 full fills identically to study2 forward when testing < 10,000). Define an open-tail page's
 upper range for finality disqualification explicitly (page.date + 1 h when date is witnessed;
 +∞ only when absent/unwitnessed).

 Finding 5 · D337 (Kernel F0 / A7) & D341 (Ending known
 arithmetic bug and funding.lag causality)
 What it breaks. architect-r17-s2-report.md (Kernel changes 1–2, D337, D341),
 audit/program/briefs/4-study-2.md step 7 test 10 (A delisting, held), and
 audit/program/architecture.md 6.4 (Layer 2 / Law F0).

 D337 falsifies Law F0 on sub-lot prints and leaves arriving taker sweeps of sub-lot
 book levels unspecified.
 During a szDecimals increase (e.g. 1 -> 2, copied lot 0.1, venue lot 0.01), a seller
 print of size 0.05 through a live eligible resting buy is admitted on a non-stale coin,
 yet D337 offers floor(0.05 / 0.1) * 0.1 = 0 lots—so optimistic fills 0. That
 breaks Law F0 as currently cited by Layer 2 (architecture.md 6.4: a real vault
 maker fill's print fills a live eligible order under optimistic). (T1 and Ville's 5% bound
 remain intact because zero-filling is adapted and fill prices still cannot beat the tape.)
 D337 also states "a resting order is offered a print's or a level's whole lots of the copied
 rules, rounded toward zero (A7)"—conflating resting orders (filled on prints) with
 arriving taker orders (filled on book levels)—and leaves unspecified whether an
 arriving taker order skips a best level whose size is < 1 copied lot (0 old lots) to walk
 to level 2 or stops at level 1.
 Operational dependency: recorder build step 1 (RECORDER.md router print rule)
 cannot be built until the kernel architect fixes sz's scale and range (currently "6
 proposed").
 D341 arithmetic error in test 10 and non-causal formula when funding.lag >
 listings.lag.

 For a flag at 04:40 (B(t_F) = 06:00), late = 3,599,999 ms (00:59:59.999),
 and listings.lag = 3,600,000 ms (01:00:00), the formula B(t_F) + late +

11/22/26, 9:55 PM See attached instructions/

 listings.lag evaluates to 07:59:59.999 (3 h 20 m after 04:40), not
 08:59:59.999 ("about two hours after the flag") as both architect-r17-s2-
 report.md and brief 4 step 7 test 10 assert. A builder implementing test 10 from
 the spec faces a directly contradictory test vector.
 For KERNEL.md A18 in general, the fact that hour B(t_F) held no settlement
 becomes known at B(t_F) + late + funding.lag, while the flag becomes
 known at t_F + listings.lag. Adding listings.lag to B(t_F) + late is
 dimensionally mixed and precedes B(t_F) + late + funding.lag on any
 header where funding.lag > listings.lag. The exact causal time is max(t_F
 + listings.lag, B(t_F) + late + funding.lag) (or B(t_F) + late +
 max(funding.lag, listings.lag)).

 Outcome changed. Broken F0 / ambiguous A7 taker-sweep semantics in kernel round 17;
 failing test 10 vector (08:59:59.999 vs 07:59:59.999) and lookahead in A18 when
 funding.lag > listings.lag.

 Defect of / Fix. Routed kernel spec (A7, F0, A18) and brief 4 step 7 test 10. Restate F0 for sub-
 lot prints (print.sz >= copied_lot), specify arriving taker behavior on sub-lot book levels,
 fix 08:59:59.999 → 07:59:59.999 (or use max(t_F + listings.lag, B(t_F) + late
 + funding.lag) = 06:59:59.999 + 1 s = 07:00:00.999 on Study 2's header, which is
 actually ~2 h 20 m after 04:40!), and fix sz scale before recorder step 1.

 Finding 6 · D338 (Pre-w_start pinned stream cost &
 fragility, intra-hour Date inversion) and minor criteria-text /
 bundle gaps
 What it breaks. audit/program/briefs/4-study-2.md step 7 wall 3 ("One event, one item",
 "The capture"), CS2.1 & CS2.3 drafts.
 Pinning and decoding all pre-w_start stream files (D338 + D339).
 Deleting the filename-based skip means every monthly replay reads all 79+ days of
 pre-w_start recordings (2026-11-14 to 2027-02-01, ~211M quotes across the 17
 coins; far more on any second registration). Running SHA-256 + zstd decompression
 + 3-pass jsont decoding over 2.6+ months of discarded lines takes tens of minutes
 to hours per replay—not "a few minutes"—and pinning pre-w_start permanently-cut
 raw files from the pre-fix November 2026 recorder means a single bit-flip in a dead
 2026 file (zero judged events) triggers unrecoverable halt_storage_corrupt.
 Fix (clock-free): Store two-host-verified max_venue_time in each closed pack's EOF
 seek table so study2 forward skips closed packs with max_venue_time <
 w_start in O(1) by content rather than filename.

 Intra-hour listings Date inversion within the 1-hour premise (Question 3).

11/22/26, 9:55 PM See attached instructions/

 Two origin/CDN replies with ±10 min skew (both passing |recv - Date| <= 1 h)
 across w_start or a rules change sort the newer copy before the older one,
 initializing w_start with post-w_start rules and reverting to pre-w_start rules
 minutes later, moving order rounding and fills without violating the 1-hour premise
 (does not break Ville's 5% bound, since order rounding is adapted).
 Small criteria-text omissions (unreviewed CS2.1 & CS2.3 drafts).
 CS2.1 end (6): States a changed-file halt resumes once pinned bytes are restored, but
 never states when an unrecoverable halt (e.g., a raw file on ws with no second copy)
 becomes final (brief 4 specifies the last firing's date).
 CS2.1 end (1): Lists engine stops as only contradictions, out-of-order events, or
 refused dates, omitting R_SETTLEMENT_MISSING when T_raw < T_prev (resolved
 under end (2) at T ∗ ) and reader/chunk faults (C2).

 CS2.3 draft: Omits aggregateByTime: false from the inline pull conditions
 (present only by cross-reference to recorder/VAULT.md).
 Bundle completeness note. CLUSTER.md was omitted from the bundle, and
 recorder/RECORDER.md truncates mid-paragraph inside "Why books are paired with
 prints here," so CLUSTER.md (D342) and RECORDER.md's tail were audited only via the
 architect's report and ledger.

 Round 16 Closure Check & What I Accept
 D337 (core mechanism — no rules check on market events): Accepted in structure.
 Deleting the off-rule drop outcome closes Neon R16 Finding 1's midnight censoring of off-
 rule moves and the szDecimals print/book desynchronization at their cause; disputed on
 Law F0 / A7 sub-lot taker sweep (Finding 5) and CS2.1's restated "Why the 5% holds"
 diagnostics and caveat (Finding 2).
 D338 (two-clock witness |recv - Date| <= 1 h & deleting state.json): Accepted
 in principle (closes Neon R16 Findings 2 and 5 at their cause, and cleanly protects cross-
 month boundaries given the 12-hour firing offset); disputed on userFunding pagination
 and the 24× hourly 30-day scan blowup (Finding 3) and pre-w_start stream
 pinning/decoding cost (Finding 6).
 D339 (carrying closed pins): Accepted in direction for cleanly closed files/packs;
 disputed for permanently-cut killed-run files and previously-open file prefixes (Finding 1).
 D340 (raw element counts & finality delimitation): Accepted in structure (closes Neon
 R16 Finding 4's Day-80 bypass, 2,000/500 page caps, and finality row-order skips);
 disputed on boundary-millisecond unreadable-fill deduplication mismatch between
 mmvault and study2 forward and open-tail finality range bounds (Finding 4).

11/22/26, 9:55 PM See attached instructions/

 D341 (ending known after B(t_F) + late): Accepted in direction (closes fresh Opus
 kernel F6); disputed on the 08:59:59.999 vs 07:59:59.999 arithmetic error and
 funding.lag vs listings.lag generality (Finding 5).

 D342 & D343 (ingest/hl.py removed, kill-doubled 410 budget, re-pairing quantifier,
 <2 h relisting note, Month-1 wait): Accepted (subject to auditing unclipped CLUSTER.md
 and RECORDER.md tail).

 Ledger
 Changes what is built or
 Status Point
 run?

 D337 core (no rules check on market events, drop
 Agreed recv - Date
 outcome deleted), D338 core (`
 Finding 1 · D339 & Step 1: Permanently-cut killed-
 run files stay "open" forever and previously-open Yes (brief 4 Step 1
 Disputed
 prefixes are not verified, re-opening silent bit-rot capture logic)
 capture poisoning
 Finding 2 · D337 & CS2.1 draft: "Venue's own
 wealth" crossing claim is refuted by path
 Yes (CS2.1 criteria draft,
 dependence, Rung 2's bar, and the < 60 s l2Book-
 Disputed brief 4 step 7 test 7
 fast-unpaired blind spot; unreadable-event
 report diagnostics)
 caveat misstates crash censoring as next-move
 predictability
 Finding 3 · D338 & VAULT.md: mmvault
 (userFunding) pagination contradicts itself and Yes
 Disputed skips coins on 500-row boundary hours; hourly 30- (recorder/VAULT.md,
 day pulls + full-history 3-pass jsont rebuild cause CronJob split)
 24× bloat risking CronJob starvation
 Finding 4 · D340 & CS2.3 / VAULT.md: Unreadable
 Yes
 boundary-ms fill deduplicated by mmvault but
 (recorder/VAULT.md,
 Disputed double-counted by study2 forward deadlocks
 brief 4 step 7 wall 3,
 CS2.3 coverage; open-tail finality range upper bound
 KERNEL.md A18)
 undefined
 Disputed Finding 5 · D337 (F0/A7) & D341 (known): Sub-lot Yes (KERNEL.md
 prints break Law F0; arriving taker sweep of sub-lot A7/F0/A18 routed, brief
 levels unspecified; D341 test 10 arithmetic is off by 1 4 step 7 test 10)
 hour (08:59:59.999 vs 07:59:59.999) and
 B(t_F) + late + listings.lag precedes

11/22/26, 9:55 PM See attached instructions/

 Changes what is built or
 Status Point
 run?
 B(t_F) + late + funding.lag when
 funding.lag > listings.lag

 Finding 6 · D338 & Criteria Texts:
 Pinning/decoding all pre-w_start stream files adds
 hours of dead work and unrecoverable
 Yes (pack seek-table
 halt_storage_corrupt exposure on 2026 raw
 Disputed max_venue_time,
 files; CS2.1 end (6) omits finalization date for
 CS2.1/CS2.3 drafts)
 unrecoverable halts; CS2.3 omits
 aggregateByTime: false inline; CLUSTER.md /
 RECORDER.md tail unbundled

 Does any dispute change what is built or run? Yes: Findings 1 through 6 each change what is
 built or run (Step 1 capture logic, recorder/VAULT.md and CronJob scheduling, KERNEL.md
 A7/F0/A18, brief 4 step 7 test 7 & test 10, and the CS2.1/CS2.3 criteria drafts).


