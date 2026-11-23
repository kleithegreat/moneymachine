# Neon (Gemini 4 Neon, web UI) on round 16's study 2 half

Reviewer: Gemini 4 Neon through the web UI, which did not author round 16 (a fresh Opus did). Bundle `neon-r16-study2-bundle.md` (`rearchitecture-s2` `7982cbe`, 407 KB; the two builder test lists omitted); the reviewer reports the architect's report truncated inside the CS2.1 draft, so the criteria drafts' tail was not reviewed. Reply saved by the human as a PDF, extracted with `pdftotext`, received 2026-11-22. Verbatim below.

11/22/26, 8:08 PM See the attached instructions

 See the attached instructions

 User prompt: See the attached instructions
 Response: Round 16 has not converged. Several Round 15 defects are genuinely closed at their
 cause—D324's e >= w_start bound (with its valid deduction that an unsettled B(e) >=
 w_start implies R <= B(e)), D326's move of print-book pairing to the socket-ordered router,
 D328's deletion of halt_fee_witness, D329's deletion of halt_substitution, and D330's
 remote capture registry all remove structural faults cleanly. However, three design defects in
 D325, D323/VAULT.md, and D330/Step 1 remain (Findings 1–3 below), alongside two smaller
 defects in D327 and D331/D326 in the next part.

 Finding 1 · D325: Dropping off-rule events breaks Ville's 5% optional-
 sampling argument at midnight and violates D326 by keeping books fresh
 while dropping prints during szDecimals changes
 What it breaks. audit/program/briefs/4-study-2.md step 7 wall 2 and wall 3 ("What
 stops a run"), architect-r16-s2-report.md D325 ("Validity" and "Not taken"), KERNEL.md
 A3/C2 (routed), and CS2.1's 5% validity argument.
 D325 drops and counts any quote or print that fails on its own content under the rules in force (a
 crossed or one-sided quote, a price off its coin's grid or not above zero, a size finer than its lots,
 or a number out of range). It claims two things: (a) for rung 1, "a dropped event merges two
 returns into one at the next fed event, a stopping time, so the composite return keeps the null's
 sign (optional sampling)"; and (b) refusing fresh Opus F2's rule that a dropped print
 unpairs/stalls the coin is harmless because during a lot-size change "the coin's books are
 mostly dropped too and it is stale anyway". Both claims are false.
 Constructions.
 Optional sampling fails at fixed midnight evaluation (breaks CS2.1's 5% bound):
 At 00:01 on Day 1, coin X trades at P0 = 100 (bid 99.95, ask 100.05), and the
 ​

 ledger holds 1/100 unit (W = 1, W b = 0.9995).

 At 23:59 (the final event before midnight T = 24 : 00), X 's true price moves under
 an exact Rung-1 martingale: with probability 1/2, P1 = 200 (quote 199.9/200.1,
 ​

 valid and fed); with probability 1/2, P1 = 0 (dropped as "not above zero")—or
 identically, a crash wipes out all bids into a one-sided book (dropped), or a downward
 move lands off-grid (dropped).
 Because CS2.1 evaluates W and W b at the fixed midnight T and there is no "next fed
 event" before T , the down-branch stays marked at P0 = 100 and its pre-crash bid
 ​

11/22/26, 8:08 PM See the attached instructions

 99.95. The last fed event before T is not a stopping time.

 At midnight T , E[WT ] = 0.5(2) + 0.5(1) = 1.5 > 1 and E[WTb ] = 0.5(1.999) +
 ​

 0.5(0.9995) = 1.49925 > 1. Repeating this censoring across days drives W b past
 20 with probability far above 5%, violating Ville's bound. Yet D333/D335's 5%
 argument concedes only late writing and delisting lookahead—not price-independent
 single-event drops.
 Fresh books with silently dropped prints during a szDecimals change (violates
 D326):
 On Hyperliquid perps, lot size is 10−szDecimals and max price decimals is 6 −
 szDecimals. Suppose at 10:05 the venue changes X 's szDecimals from 1 to 2
 (finer lots: 0.01 instead of 0.1), while the next hourly listings copy is dated 11:00.

 Because mmrec checks only syntactic A18 print grammar and does not know time-
 varying szDecimals, mmrec keeps X paired and writes all of X 's books to l2Book-
 fast.

 Under the old rules (szDecimals = 1), max price decimals was 5, so 100% of new
 4-decimal prices fit the old grid. Market makers routinely quote round sizes (multiples
 of 0.1, 1, or 10), so every l2Book-fast snapshot whose quoted sizes are multiples
 of 0.1 passes D325 admission. One such quote every 60 seconds (G = 60,000 ms)
 keeps X continuously fresh for the entire 55 minutes.

 Meanwhile, every print with a 2-decimal size (0.15, 1.23, 0.05) fails the old lot size
 and is silently dropped by D325.
 Symmetrically, when szDecimals decreases (2 → 1), 100% of new sizes fit the old
 0.01 lot size; any book sitting on 4-decimal prices keeps X fresh while every print at
 a 5-decimal price is silently dropped.
 For up to an hour per change, pessimistic allows taker fills on fresh books while
 silently suppressing maker fills (entries, levels, take-profits) and leaving W b valued at
 bids that dropped prints already traded through.
 Outcome changed. Overstates CS2.1's 5% false-confirmation guarantee (missing a third validity
 assumption); silently breaks D326's book-print pairing invariant during lot-size changes,
 distorting pessimistic fills, W , W b , CS2.2 variance, and CS2.3 entries.

 Defect of. Design (D325 rejecting Opus F2's rule that a dropped print must also stall/invalidate
 freshness for that coin until its next admitted print or the next rules copy) and Criteria text
 (CS2.1's 5% paragraph must state explicitly that single-event drops—crossed/one-sided books,
 zero/out-of-range prices, and off-grid/off-lot events—do not depend on price moves).

11/22/26, 8:08 PM See the attached instructions

 Finding 2 · D323 & VAULT.md: A transient forward host-clock jump
 permanently deadlocks mmvault, losing hourly fees, orders, fills, and CS2.3
 coverage
 What it breaks. recorder/VAULT.md ("One run" items 1–2, state.json, and "Limits") and
 D323's objective of eliminating host-clock failure modes (specifically Opus F5's 40-day-ahead
 boot on prodesk7).
 D323 removed host-clock trust from the reader by timing pulls with the venue's HTTP Date.
 However, mmvault itself still uses the host wall clock (now) both as endTime on hourly fills pulls
 and to advance monotonic cursors in state.json, and aborts its entire hourly run if Step 1 fails.
 Construction.
 On real Day 50, prodesk7 boots with its RTC 40 days ahead (now = Day 90, or year
 2030) for 15 minutes before NTP corrects it, and the hourly CronJob vault fires at minute
 7.
 Step 1 (hourly fills) requests userFillsByTime for [Day 50 - 1 h, Day 90].
 Hyperliquid accepts a future endTime and returns all fills through real Day 50 (< 2,000
 items, every fill's time inside [startTime, Day 90]). Every page check passes.
 VAULT.md updates state.json's watermark to max(watermark, Day 90) = Day 90
 ("it never moves back"). Step 2 sees a new UTC day and advances last_daily_reread
 and last_funding_end to Day 90.
 Fifteen minutes later, NTP steps prodesk7 back to real Day 50.
 For the next 40 days (or until 2030 on a year-2030 RTC jump), every single hourly
 mmvault run hits Step 1, finds now (Day 50) <= watermark - 1 h (Day 90 - 1
 h), logs error ("a clock stepped back is an error, and the watermark stays"), and stops
 the entire run immediately ("A run stops at its first failed pull and sends no request after
 it").
 Even if Step 1 did not abort the run, last_daily_reread = Day 90 blocks Step 2's daily
 fills re-read and daily userFunding pull for the entire 40 days (or years).
 Outcome changed. Total loss of hourly fees schedule copies (irrecoverable because userFees
 serves only current state, assumption V4) and orders (2,000-item retention cap) for 40 days or
 the remainder of Study 2; daily fills re-reads stall, delaying CS2.3 or permanently forfeiting
 CS2.3 coverage if 10,000 fills accrue during the stall (forcing CS2.3 to "not judged").
 Defect of. Design (VAULT.md). mmvault should never persist an unwitnessed host clock into
 monotonic state.json cursors: advance watermark and last_funding_end using the
 venue's HTTP Date on the completed reply (or omit endTime on hourly fills and advance
 watermark to Date), and trigger daily re-reads on UTC day changes of the venue's Date (or

11/22/26, 8:08 PM See the attached instructions

 compute whether today's re-read is due from stored files' Date headers, never from a host-
 clock timestamp in state.json).

 Finding 3 · D330 & Step 1 Capture: Re-hashing closed files in Step 1 bakes
 silent bit-rot into immutable captures.tsv, destroying recoverable
 halt_storage_corrupt and Opus N4.2 re-pack recovery

 What it breaks. audit/program/briefs/4-study-2.md step 7 wall 3 ("The capture" item 2,
 "Closed-hour per-coin seekable packs" / Opus N4.2, and "A halt ends the study at its last
 accepted report") and D330 (audit/study2/captures.tsv).
 In Round 16, D330 makes the first Capture_k pushed to audit/study2/captures.tsv the
 month's sole immutable capture. Meanwhile, Step 1 checks previously pinned closed files only
 against their pinned length (stat(f).size != L_prev), and then "hashes the pinned bytes"
 into Capture_k (only the registration file is explicitly pinned "of that hash").
 Construction.
 Month 1 pins a closed pack F (20270201/00.run.packed.zst on the pack volume, with
 its intact raw file still on ws) at length L_1 and hash H_1.
 Between Month 4 and Month 5, silent bit-rot on the pack volume flips 1 bit inside F, leaving
 stat(F).size == L_1 unchanged.

 Month 5's Step 1 checks stat(F).size == L_1 (passes!), freshly hashes F to
 H_corrupt != H_1, writes H_corrupt into Capture_5, and pushes Capture_5's SHA-
 256 to audit/study2/captures.tsv.
 Step 2 runs Capture_5 on two replay hosts. Both hosts verify sha256(F) ==
 H_corrupt (so E_HASH never fires!) and then fail zstd xxHash32 checksum verification
 when reading F—either crashing in an infinite transient retry loop or settling an
 unrecoverable deterministic refusal instead of halt_storage_corrupt.
 Even after the operator invokes Opus N4.2's two-host re-pack from the intact raw file on
 ws to restore F's exact original bytes (H_1), those restored bytes fail E_HASH against the
 immutable Capture_5 (H_corrupt) permanently.
 Symmetrically, equal-length corruption in an uncompressed closed file that still parses
 cleanly passes E_HASH on both hosts, diverges on Month 1, and permanently terminates
 the study as end_study (changed) at T* = w_start instead of triggering recoverable
 halt_storage_corrupt.

 Outcome changed. Converts a recoverable storage corruption (halt_storage_corrupt,
 recoverable via mirror or Opus N4.2 two-host re-pack) into an irrecoverable permanent study
 halt, deadlock, or premature end_study (changed), withholding all unjudged CS2.1–CS2.3
 verdicts.

11/22/26, 8:08 PM See the attached instructions

 Defect of. Design (Step 1 capture specification in brief 4 step 7 wall 3). For every file already
 pinned as closed in Capture_{k-1} (including closed packs and their frame/raw pins), Step 1
 must either verify sha256(f) == H_prev and halt immediately as halt_storage_corrupt
 before committing/pushing Capture_k, or carry forward (L_prev, H_prev) verbatim without
 re-hashing so Step 2 catches silent bit-rot via E_HASH -> recoverable halt_storage_corrupt
 against the true hash H_prev.
 CONTINUE

 User prompt: continue

 Response: Finding 4 · D327: Unreadable fills bypass CS2.3's < 10,000
 retention guard and page-cap check, and finality query rechecks omit row
 ordering, query boundaries, and unreadable-row handling
 What it breaks. audit/program/briefs/4-study-2.md step 7 wall 3 ("What the reader
 rechecks": Vault fills, Coverage, and An end's finality; "The vault's fills"), recorder/VAULT.md
 ("What a capture reads as coverage" and "What the reader trusts of a pull"), and D327.
 D327 correctly switches vault pages to fill-by-fill decoding so an unreadable fill dated outside
 [w_start, w_start + 61 d) neither discards 1,999 sibling fills nor forces CS2.3 to "not
 judged". However, it leaves the interaction between unreadable elements and the
 coverage/finality rechecks unspecified—creating concrete bypasses in both.
 Constructions.
 Unreadable fill defeats CS2.3's < 10,000 retention guard:
 Between Day 1 and Day 100, the vault executes 10,500 fills, so Hyperliquid's 10,000-
 fill retention window truncates the oldest 500 fills (say 50 complete round trips
 inside Days 1–10, breaking no chain).
 The Day 100 re-read (startTime = Day 1, no endTime) returns 10,000 raw fill
 elements across 5+ pages, all at or after Day 11. Suppose just one fill on Day 80
 (outside CS2.3's 61-day span) fails fill decoding (px: "1e-5", or an unreadable oid).
 Under D327, that Day 80 element is skipped without withholding CS2.3, leaving only
 9,999 distinct decoded fills with time >= Day 1.
 Because 9,999 < 10,000, the retention-truncated pull falsely satisfies coverage
 over [Day 1, Day 61] and judges CS2.3 ("Met" or "Not shown") on a record
 missing 500 early fills.
 Page-cap check ambiguity on a crashed pull:

11/22/26, 8:08 PM See the attached instructions

 If the rule "every page but the last holds 2,000 fills and the last fewer" counts
 decoded fills rather than raw JSON array elements, a 1-page pull aborted after Page 1
 (2,000 raw elements, 1 unreadable on Day 80) has 1,999 < 2,000 decoded fills and
 falsely passes as a completed single-page pull.
 Unreadable settlement row in [R, B(e)] falsely finalizes a delisting:
 Suppose coin X actually settles hour R with a row A18 cannot place (e.g., 13 decimal
 places or "1e-4"), stored by an older or faulty writer (the exact threat model of
 "What the reader rechecks"), while a temporary flag e exists.

 Because brief 4 defines "a row the reader would not read ... is no settlement", the
 finality query parses zero readable settlements in [R, B(e)] and declares the
 delisting final at R even though the venue returned a settlement row for hour R.

 Missing row-ordering and query-boundary checks in finality queries:
 Unlike the fills recheck (which requires every fill's time >= startTime and non-
 decreasing), the finality recheck never requires a page's rows to have strictly
 increasing time within [startTime, endTime], nor does it define how multiple
 queries for the same coin inside one multi-coin settled/funding file are delimited.
 A faulty writer storing a 500-row Page 1 (startTime <= R) whose last row is out-
 of-order at B(e) + 1 h advances Page 2's startTime to B(e) + 2 h, skipping
 [R, B(e)] entirely while passing every stated recheck and returning zero
 settlements in [R, B(e)].
 Outcome changed. CS2.3 certified "Met" or "Not shown" on a retention-truncated or incomplete
 vault record; or a live/relisted coin falsely finalized as delisted, advancing T past a live hole and
 later killing the study at T*.
 Defect of. Design (VAULT.md and brief 4 step 7 wall 3). Fix:
 1. Apply the 2,000-fill and 500-row page-cap checks strictly to raw JSON array element
 counts, not decoded-item counts.
 2. In fills coverage, count every unreadable element whose time >= t (or whose time is
 unreadable) toward the 10,000 retention ceiling—or simply disqualify any pull containing
 an unreadable element from certifying coverage.
 3. In finality queries, delimit each query cleanly (contiguous pages of one coin ending at the
 first page of < 500 raw elements), require every element of every page to be a valid
 readable settlement of that coin in strictly increasing time within [startTime,
 endTime], and treat any unreadable element as disqualifying the query from certifying
 finality.

11/22/26, 8:08 PM See the attached instructions

 Finding 5 · D323: HTTP Date from nginx/CloudFront is an unwitnessed proxy
 clock with zero cross-check, re-introducing backward-clock T* mutation
 and forward-clock coverage/finality forgery
 What it breaks. recorder/RECORDER.md ("The venue's time"), recorder/VAULT.md ("What a
 capture reads as coverage"), audit/program/briefs/4-study-2.md step 7 wall 3 ("One
 event, one item", "The horizon", and "The vault's fills"), and D323.
 For l2Book-fast, the design enforces a two-clock witness (|recv - time| <= 1 h), so
 neither a bad host clock alone nor a rogue venue timestamp alone can forge a horizon. By
 contrast, D323 replaces the unwitnessed host clock on REST replies with a second
 unwitnessed clock—the HTTP Date header emitted by nginx behind CloudFront (a web-
 proxy/CDN clock, not Hyperliquid's L1 consensus clock)—and applies zero cross-check against
 recv, Capture_k's firing date, or the L1 timestamps (time) in the capture.

 Constructions.
 Skewed or stale proxy Date mutates published history (T*):
 After a szDecimals or margin-tier change on Day 120, one hourly meta reply on Day
 180 is served by an origin or proxy node whose wall clock is unsynced (or that emits a
 stale Date reading Day 10, or between the last pre-w_start copy and w_start).
 Because D323 sorts all listings copies globally by HTTP Date with no lower bound
 against prior acquired copies or recv, Day 180's rules sort into Day 10 (or Day 1
 initialization) in Month 6—retroactively mutating already-published rules and
 terminating Study 2 at T* = Day 9 (or T* = w_start). This is Neon R15 Finding 1.3
 moved from recv to HTTP Date.
 Forward-skewed proxy Date forges CS2.3 coverage and delisting finality:
 On Day 62 (one day after CS2.3's 61-day window), a misconfigured origin/CDN node
 returns Page 1 of mmvault's daily fills re-read (or mmvault funding's open tail) with
 Date 40 days ahead (or year 2030).

 Because Date is never checked against Capture_k's firing date, recv, or the L1
 time of the fills/settlements, that single reply immediately certifies Days 1–61 as 30
 days old (judging CS2.3 on fills exposed for 1 day, violating V18) and finalizes a
 delisting flagged yesterday (publishing past an unfinalized end, risking T* when late
 settlements arrive).
 Silent persistent proxy skew:
 Unlike l2Book-fast (where the monthly report counts every line with |recv -
 time| > 1 h), nothing checks or reports |recv - Date| on listings, fills, or

11/22/26, 8:08 PM See the attached instructions

 settled/funding replies, leaving a persistent nginx/CloudFront clock offset
 invisible.
 Outcome changed. Premature end_study (changed) at T*, premature CS2.3 judging
 violating V18's 30-day indexing wait, or premature delisting finality.
 Defect of. Design (D323). Apply the same two-clock discipline used for l2Book-fast:
 1. Reject/ignore any REST Date that lies in the future relative to Capture_k's firing date (or
 require Date <= firing_midnight + 24 h, and for listings, ignore any copy whose
 Date steps backward behind an earlier-acquired copy's Date by more than the 1-hour
 premise so a single stale proxy header cannot retroactively rewrite published days).
 2. Report |recv - Date| > 1 h counts per channel in each monthly report so proxy or
 host clock drift is audited rather than assumed.

 Finding 6 · D331 (small): Lock-vs-wait ordering for ingest/hl.py and in-
 flight SIGKILL budget arithmetic; plus three text/corner points
 What it breaks. architect-r16-s2-report.md D331 (CLUSTER.md section 2,
 ingest/hl.py), recorder/RECORDER.md (Routing), and brief 4 step 7 wall 3 (D324).

 Constructions.
 D331 — Sleep before lock defeats the 60 s guard on ingest/hl.py:
 D331 states "A process that sends nothing in its first 60 s therefore never shares a
 venue minute with its predecessor's holds" and keeps ingest/hl.py under
 data/.hl-rest.lock.

 If a queued second ingest/hl.py invocation measures "its first 60 s" from process
 start while blocking on data/.hl-rest.lock for 59 s as Process 1 runs and sends
 300 weight at t = 59 s, Process 2 acquires the lock at t = 60 s and immediately
 sends 300 weight—placing 600 weight from ingest/hl.py alone into 2 seconds.
 Additionally, if Process 1 is SIGKILLed / OOMKilled while a 300-weight request is in
 flight on Hyperliquid's server (taking e.g. 5 s to complete server-side), Process 2
 starting 1 s later and waiting 60 s sends at t = 61 s—only 56 s after the server
 counted Process 1's request (805 total across processes, or 1,010 if all four
 processes were killed in-flight simultaneously). That remains safely under 1,200, so
 the operational safety holds, but the worst minute is 505 only under clean exits, not
 kills.
 Text point 1 — D326 vacuous quantifier on single-coin trades frames:
 RECORDER.md Routing states a coin is paired "after each trades frame in which
 every print of the coin is one the forward reader reads". Literally, a trades frame

11/22/26, 8:08 PM See the attached instructions

 containing only BTC prints contains zero ETH prints, so "every print of ETH" in it is
 vacuously readable and would re-pair an unpaired ETH! Change to "holding at least
 one print of the coin, every one of which the forward reader reads" (matching the
 next sentence's "its own next trades frame").
 Text point 2 — D324 rapid < 2 h delist-and-relist corner case & Month-1 February
 delay:
 If a coin is delisted at 04:00, flagged at 04:40 (B(e) = 06:00), and relisted before
 06:00 so hour 06:00 settles under a second unflagged entry, the 04:40 flag does
 not qualify (hour B(e) settled), no later copy flags the coin, and the missing 04:00–
 05:00 hours become a permanent hole holding T until the last firing. Rare in practice,
 but worth noting as an uncatchable delisting-relisting boundary.
 Note also that deleting Day 1's omission (D334) while requiring e >= w_start
 (D324) means a coin delisted months before w_start only reaches finality 30 days
 after w_start—so if w_start is 2027-02-01, Month 1 (2027-03-01, 28 days) holds
 T_1 = w_start and publishes zero days until Month 2. Benign, but worth
 documenting so operators do not mistake Month 1's T_1 = w_start for a bug.
 Bundle truncation note on D335:
 architect-r16-s2-report.md in the provided bundle truncates mid-sentence
 inside the CS2.1 draft (...the record its capture held; the report...),
 cutting off the remainder of CS2.1's draft (including the "Why the 5% holds"
 paragraph) and the full CS2.3 draft. The full drafted criteria texts cannot be signed off
 until their unclipped text is reviewed—and per Finding 1, the "Why the 5% holds"
 paragraph will need the third assumption for single-event drops anyway.
 Outcome changed. For D331, avoidable HTTP 429s under queued ingest/hl.py scripts; for
 D326, a literal builder implementation re-pairing unpaired coins on other coins' trades; for D335,
 unreviewed criteria tail.
 Defect of. Design (D331: specify that the 60 s wait runs after acquiring the exclusive lock, and
 note the in-flight kill margin); Text (D326 quantifier; D324 notes; unclipped D335 criteria drafts).

 Round 15 Closure Check & What I Accept
 D324 (Delisting flag bound & multi-entry relisting): Accepted. Requiring e >=
 w_start closes Neon R15 Finding 1.1 at its cause, and the architect's correction that R <=
 B(e) follows from e >= w_start (since every hour in [w_start, R) is settled) is
 mathematically valid. Reading a coin by all entries of its name (listed by exactly one
 unflagged entry; flagged when all are flagged) cleanly handles Hyperliquid's append-only
 universe on relistings. Carrying max(R, t_F) + lag for ending known is sound.

11/22/26, 8:08 PM See the attached instructions

 D326 (Router-driven print-book pairing, deleting reader withholding): Accepted in
 structure (modulo Finding 1's rule-dropped prints during szDecimals changes and the
 vacuous-quantifier wording fix). Routing every frame by channel and unpairing a fast
 connection on unplaceable/events frames closes Opus F1 and Neon R15 Finding 2 at
 their cause, and removes the last qualification on D309.
 D328 (Deleting halt_fee_witness & earliest-end precedence): Accepted. Deleting
 halt_fee_witness as a measurement with no criterion behind it closes Neon R15
 Finding 4 at its cause, and scoping all verdict naming strictly through the run's earliest end
 before checking complete closes Opus's two-ends defect.
 D329 (Deleting halt_substitution & rerunning refused reports): Accepted. Closes
 Opus F3 cleanly without weakening detection.
 D330 (Pushing Capture_k to audit/study2/captures.tsv before Step 2 runs):
 Accepted in mechanism (closes Opus F4), conditional on fixing Step 1's closed-file re-
 hashing bug in Finding 3.
 D332 (Whole replies & curl 8.22.0 lib/http.c): Accepted. Deleting the false framing
 sentence and verifying CURLOPT_MAXFILESIZE_LARGE against curl 8.22.0's source
 closes Opus's framing point and Neon R15 Finding 6.2.
 D333 (Conceding delisting lookahead in CS2.1's 5% argument): Accepted for
 delistings (closes Neon R15 Finding 5 for delistings; per Finding 1, the same concession is
 now needed for D325's single-event drops).
 D334 & D336 (Texts & human decisions of 2026-11-22): Accepted. Holes bounded by
 end, Day 1 omission deleted, distinct fills and retention-by-time stated, Phase 2 / Oracle
 VM / second copy removed cleanly.
 D325 (Dropping single-event faults): Direction accepted for survival (Opus F2),
 disputed on validity & print-book pairing (Finding 1).
 D323 (HTTP Date), D327 (Rechecks), D331 (60 s wait): Partially accepted; disputed on
 Findings 2, 4, 5, and 6.

 Ledger

 Changes what is built or
 Status Point
 run?

 Agreed D324 (flag bound e >= w_start, multi-entry As proposed
 relisting, ending known), D328
 (halt_fee_witness deleted, earliest-end
 precedence), D329 (halt_substitution deleted,
 rerun from accepted state), D332 (whole-reply

11/22/26, 8:08 PM See the attached instructions

 Changes what is built or
 Status Point
 run?
 argument & curl 8.22.0 overflow), D333 (delisting
 lookahead assumption & count), D334 (text fixes),
 D336 (human 2026-11-22 decisions)
 Finding 1 · D325: optional-sampling argument fails
 at fixed midnight evaluation (missing 3rd
 Yes (KERNEL.md A3/C2,
 assumption in CS2.1's 5% proof); rejecting Opus
 Disputed brief 4 wall 2/3, CS2.1 5%
 F2's stall-on-dropped-print keeps books fresh
 draft)
 while silently dropping prints during szDecimals
 changes
 Finding 2 · D323 & VAULT.md: mmvault still
 persists unwitnessed host now into monotonic
 Yes (recorder/VAULT.md
 state.json cursors (watermark,
 Disputed state cursors & Step 1–2
 last_daily_reread, last_funding_end), so a
 scheduling)
 transient forward RTC jump permanently deadlocks
 mmvault and loses fees/orders/coverage

 Finding 3 · D330 & Step 1: Step 1 checks closed
 files only by length and re-hashes them into
 immutable captures.tsv, baking equal-length Yes (brief 4 step 7 wall 3,
 Disputed
 bit-rot into Capture_k and destroying recoverable Step 1 capture logic)
 halt_storage_corrupt / Opus N4.2 re-pack
 recovery
 Finding 4 · D327: unreadable Day 80 fill bypasses
 < 10,000 retention guard (and 2,000-fill page Yes (recorder/VAULT.md,
 check if decoded-counted); finality query rechecks brief 4 step 7 wall 3,
 Disputed
 omit raw-element counts, row ordering/range KERNEL.md A18 forward
 checks, query delimitation, and unreadable-row reader)
 disqualification
 Finding 5 · D323: HTTP Date from
 nginx/CloudFront is an unwitnessed proxy clock Yes (brief 4 step 7 wall 3,
 Disputed with zero cross-check, letting one skewed reply KERNEL.md A18 reader date
 mutate published rules (T*) or forge 30-day bounds & reporting)
 coverage/finality
 Disputed Finding 6 · D331 (small) & Text: ingest/hl.py Yes (ingest/hl.py
 must wait 60 s after acquiring data/.hl- lock/wait order;
 rest.lock (plus note in-flight SIGKILL margin); RECORDER.md Routing
 D326 vacuous quantifier on single-coin trades

11/22/26, 8:08 PM See the attached instructions

 Changes what is built or
 Status Point
 run?
 frames; unclipped D335 criteria drafts needed for wording; full D335 draft
 full sign-off review)

 Does any dispute change what is built or run? Yes: Findings 1 through 6 each change what is
 built or run (KERNEL.md A3/C2/A18, brief 4 Step 1 and Step 7 wall 3, VAULT.md,
 RECORDER.md, and ingest/hl.py), and Finding 1 changes the CS2.1 criteria draft (whose tail
 was also truncated in the bundle).


