# Neon on round 14's study 2 half (D290 to D305)

Model Gemini 4 Neon through the Gemini web UI (the human pasted `neon-r14-study2-bundle.md`, 373 KB, whole, and its prompt; reply saved as a PDF, 2026-11-22 08:45 UTC (03:45 EST)). Extracted by `pdftotext -layout`:

```text
11/22/26, 3:45 AM                                      See attached instructions



    See attached instructions
    https://gemini.google.com/app/2ab09afe442eccab

    User prompt: See attached instructions

    Response: Status of my round 13 findings
    All three of my round 13 findings are closed at their specific causes, though two of the
    replacement mechanisms introduce new design defects below:
            Finding 1 (32-day re-read seam against 31-day coverage): closed by D296 (re-reading
            from the earliest uncovered instant with no endTime), which eliminates midnight-drift
            seams—but introduces a permanent livelock under the 10,000-fill retention cap (Finding 2
            below).
            Finding 2 (30 empty answers within 30 hourly retries): closed by D291 (requiring a pull
            begun 30 days after the flag) and D295 (deleting the capture's own pull and retries)—but
            D290/D291 introduce a cross-clock deadlock and inverted finality interval (Finding 1
            below).
            Finding 3 (VAULT.md funding test 1's last_time + 1): closed in 43116ed by paging at
            the whole hour after each page's last row.

    Finding 1 — D290/D291: Cross-clock delisting end causes a permanent
    horizon deadlock (reach > end) and an inverted finality range on ordinary
    delistings
            What it breaks: D290, D291, Brief 4 step 7 wall 3 ("The horizon"), and Kernel change #1.
            Constructions: D290 defines a flagged coin's listing end end_c as the whole hour after
            its last settlement stamped before e_c (the host-clocked recv of the first listings copy
            flagging isDelisted). Clause 1 defines reach(c) as the first whole hour at or after
            w_start with no settlement of c in Capture_k, and requires reach(c) > T or
            reach(c) == final_end(c). D291 makes end_c final only upon a completed empty
            funding query covering every hour from end_c to e_c from a pull begun at least 30 days
            after e_c. Mixing host-clocked e_c with venue-clocked settlement.time breaks in
            three concrete ways:
                1. Slow host clock well inside D292's ±1 h premise: Suppose mmrec's host clock is 10
                   minutes slow (6x smaller than the 1-hour receipt-clock bound D292 assumes). Coin c
                   settles hour 04:00 at venue time = 04:00:00.050, delists at true UTC 04:02:00,
                   and mmrec polls meta at true UTC 04:05:00, stamping e_c = 03:55:00. The last
                   settlement with time < e_c is 03:00:00.050, so end_c = 04:00:00. Meanwhile
                   mmvault funding fetches the real 04:00:00.050 settlement, so Capture_k
                   holds hour 04:00 and reach(c) = 05:00:00. Now reach(c) = 05:00 !=

https://gemini.google.com/app/2ab09afe442eccab                                                          1/14
11/22/26, 3:45 AM                                         See attached instructions


                    end_c = 04:00. Even if end_c were treated as final, Clause 1 (reach(c) > T or
                    reach(c) == final_end(c)) fails for every midnight after that day forever. In
                    addition, D290 drops the live 04:00 funding settlement and any 04:00–04:02
                    books/prints and settles a held position at 04:00's price instead of its true close.
                2. Zero clock skew boundary race: Hyperliquid's observed settlement stamps land up
                   to 139 ms after the hour. Suppose the venue flags isDelisted: true at
                   04:00:00.000 and stamps its final 04:00 settlement at 04:00:00.080, while an
                   accurately clocked mmrec poll completes at e_c = 04:00:00.020 (or the venue
                   pays one final settlement after setting isDelisted). Again end_c = 04:00:00
                   while reach(c) = 05:00:00 != end_c. Worse, hour 04:00 lies in [end_c,
                   e_c] and has a settlement (and fetch-once mmvault funding will never re-query
                   hour 04:00 because it is in S_c^disk), so end_c can never satisfy D291's empty-
                   query finality rule either.
                3. Ordinary zero-skew delisting produces an inverted finality range: Because
                   mmrec polls meta hourly, any coin that pays funding at 04:00:00.050, delists at
                   04:15:00, and is first flagged at e_c = 04:40:00 has its last settlement before
                   e_c at 04:00:00.050, giving end_c = 05:00:00 > e_c = 04:40:00. The
                   finality interval "every hour from its end to e_c" ([05:00, 04:40]) is inverted and
                   empty: a vacuous check never verifies that 05:00 remained empty 30 days later,
                   whereas a literal [start <= end_c, end >= e_c] check is ambiguous or rejects
                   valid pulls.
            Outcome it could change: In (1) and (2), T freezes permanently on the delisting day until
            the last firing, withholding all subsequent CS2.1 crossings, CS2.2 (if before day 212), and
            CS2.3 (if before day 61); in (1), it also corrupts the coin's final hour's fills, funding, and
            settlement price, moving W, Wᵇ, and B̄.
            Defect: Design. end_c should be defined against the contiguous funding stream itself
            (e.g., the first missing hour at or after e_c - tolerance, or the end of the contiguous run
            of settlements containing e_c - tolerance, with finality requiring an empty query over
            [end_c, max(end_c, e_c + tolerance)]—or reach(c) capped/checked against
            end_c consistently with >= rather than == only after ensuring no pre-relisting settlement
            was dropped).

    Finding 2 — D296: Hardcoding the daily re-read floor at 2026-11-01
    livelocks CS2.3 coverage under the 10,000-fill retention cap, and the
    forward reader omits pull-completeness rechecks
            What it breaks: D296, VAULT.md ("One run" item 2 and "What a capture reads as
            coverage"), and Brief 4 step 7 wall 3 ("The vault's fills" and "What the reader rechecks").
            Constructions:


https://gemini.google.com/app/2ab09afe442eccab                                                               2/14
11/22/26, 3:45 AM                                          See attached instructions


                1. Permanent livelock of the daily re-read (withholding CS2.3 on intact data):
                   VAULT.md requires every daily re-read to start "from the earliest instant not yet
                   covered, at or after 2026-11-01T00:00:00Z, with no endTime", and counts a pull
                   as covering only if it returned fewer than 10,000 distinct fills. Suppose any instant
                   t_0 >= 2026-11-01 remains uncovered once 10,000 subsequent fills accumulate.
                   This happens naturally in two realistic cases:
                          Pre-freeze pulls from 2026-11-01 onward written by the existing 851fc77
                          build carry endTime and therefore cover nothing; if the freeze (or a second
                          registration, explicitly defined by CS2.1) occurs after 10,000 fills since 2026-
                          11-01 (about 1 year at the vault's historical rate, or a few months during higher
                          volatility), t_0 = 2026-11-01 is permanently uncoverable.
                          Similarly, if an outage or volatility burst leaves any uncovered t_0 more than
                          10,000 fills behind venue now, every open-ended pull from t_0 hits the 10,000-
                          fill retention ceiling and covers nothing. Because the daily re-read always
                          restarts at the earliest uncovered instant >= 2026-11-01, it stays livelocked at
                          t_0 forever: every midnight it downloads 10,000 fills (5 pages, 600 weight, 5
                          minutes, raising alarm), covers zero instants, and never advances startTime
                          to w_start (or to the recoverable suffix)—even when [w_start, w_start +
                          62 d] holds only ~1,700 fills and is 100% intact inside the venue's 10,000-fill
                          window.
                2. Forward reader fails to recheck pull completeness for coverage: D304 rightly
                   states that "Nothing a line holds is trusted for having been written, since lines from
                   before a writer's fix were held to less and a writer can be wrong." Yet Brief 4 ("What
                   the reader rechecks" and "The vault's fills") grants coverage to any whole-decoded
                   fills file whose request has no endTime, startTime <= t, < 10,000 distinct fills,
                   and <pull> >= t + 31 d, without specifying that the frozen reader must verify
                   clean zstd EOF, exact inter-page chaining (page[0].startTime <= t, every page
                   k > 0 starting at last_time(page[k-1]) with |page[k-1]| == 2000, all pages
                   non-decreasing with time >= startTime and no endTime), and |last_page| <
                   2000. A single-page 2,000-fill file from an aborted or buggy writer (no endTime)
                   decodes whole, holds 2,000 < 10,000 fills, and would falsely certify coverage over
                   an incomplete range missing entire round trips.
            Outcome it could change: (1) Permanently withholds CS2.3 ("not judged" at the last firing)
            even when every judged fill is still served by the venue, while permanently burning 600
            REST weight every midnight and bloating disk; (2) allows a false "met" on CS2.3 if an
            incomplete fills file omits unmatched vault round trips without breaking the position chain.
            Defect: Design. The collector must advance past any t_0 whose open-ended pull hits
            10,000 fills (e.g., advancing its re-read floor to the earliest timestamp returned in that
            10,000-fill response, or parameterizing the coverage floor at w_start once registered
            rather than hardcoding 2026-11-01), and the frozen reader must recheck the full
            pagination/EOF invariants of every covering fills file.

https://gemini.google.com/app/2ab09afe442eccab                                                                3/14
11/22/26, 3:45 AM                                      See attached instructions


    Finding 3 — D294: Monotonic clamping max(recv, prev_time) on
    listings lets a single forward host-clock jump poison the entire 2-year
    study
            What it breaks: D294, Brief 4 step 6 and step 7 wall 3 ("One event, one item"), and Kernel
            change #2.
            Construction: listings files are exempt from the w_start - 24 h skip, so study2
            forward reads every listings file from 2026-11-14 onward in acquisition order (<run>,
            hour file, line) and assigns each copy time = max(recv, prev_time). Now suppose a
            single transient forward clock jump on the recorder host (e.g., a bad RTC on boot or NTP
            glitch stamping recv = 2030-01-01—an in-scope failure mode explicitly tested in Brief
            4 test 10 and VAULT.md funding test 3—before NTP steps the clock back minutes later)
            hits ONE listings line. Because time is monotonically latched to max(recv,
            prev_time), every subsequent listings copy for the remainder of the two-year study
            is stamped 2030-01-01:
                1. If the spike occurs before w_start (any time between 2026-11-14 and the
                   freeze): every subsequent copy, including the true w_start copy, receives effective
                   time 2030-01-01 > w_start. If no copy preceded the spike, study2 forward
                   permanently refuses with E_HEADER ("no copy timed at or before w_start"); if an
                   earlier copy existed (e.g., from November 2026), study2 forward initializes Day 1
                   from that stale copy, ignoring every szDecimals change and delisting between
                   November and w_start (immediately hitting R_OFF_RULES or admitting an already-
                   delisted coin).
                2. If the spike occurs after w_start: every subsequent copy has effective time 2030-
                   01-01 >= w_end. Because Brief 4 emits a rules change only at copies before
                   w_end, no subsequent szDecimals change is ever applied (causing
                   R_OFF_RULES to hold T permanently at the first rules change). Worse, for any coin
                   delisted after the spike, e_c = 2030-01-01: D291's 30-day finality check (<run>
                   >= e_c + 30 d) cannot be satisfied until 2030-01-31—after the 2029 last firing—
                   so T freezes permanently on the delisting day! Even a modest 3-day forward jump
                   before NTP corrects shifts any rules change in those 3 days past live trades that
                   obeyed the new grid, holding T via R_OFF_RULES.
            Outcome it could change: Permanent halt_refused(E_HEADER) at Month 1, stale Day-
            1 header rules, or permanent horizon freeze via R_OFF_RULES or unfinalizable e_c,
            withholding CS2.1, CS2.2, and CS2.3.
            Defect: Design. Clamping forward with max(recv, prev_time) trades a backward-step
            bug (restoring old rules) for an unrecoverable forward-spike latch. Because listings
            lines carry no venue timestamp, a copy's recv should be cross-checked against
            concurrent venue-clocked streams (or bounded/discarded when wild relative to adjacent
            copies and venue timestamps, rather than permanently latching prev_time forward).

https://gemini.google.com/app/2ab09afe442eccab                                                           4/14
11/22/26, 3:45 AM                                       See attached instructions


    CONTINUE



    User prompt: continue

    Response: Finding 4 — D293 vs D294 + append-only storage: R_OFF_RULES
    recovery is impossible once any post-trade listings copy is captured
            What it breaks: D293, D294, Brief 4 step 7 test 10 ("What stops a run") and wall 2–3, and
            Draft CS2.1 clause (1).
            Construction: D293 classifies R_OFF_RULES (a recorded trade off its coin's rules in force)
            as a recoverable hold rather than end_study, on the premise that a later capture could
            add a listings copy timed before the trade. Brief 4 test 10 explicitly tests this: "a run
            stopped by a recorded trade off the rules in force on day 80, the copy of the new rules
            received after it, settles continue at day 79's end... with that copy timed before the trade
            written into a later capture (a writer that held it), that capture's run passes day 80." Under
            D294 and append-only storage, this recovery path is mathematically impossible:
                1. Acquisition-order clamping defeats late-written copies: Suppose Capture_3
                   holds the Day 80 14:25 trade and the post-trade listings copy at 15:00 (which is
                   always the normal case: T_raw must be at least Day 81 00:00 for the run to reach
                   Day 80 14:25, ~10 hourly polls later). Because recordings are append-only
                   (RECORDER.md) and Capture_3 pins every closed earlier hour file by length
                   (halt_storage_corrupt if modified), any held copy timed 14:22 written into
                   Capture_4 must appear after the 15:00 copy in acquisition order (<run>, <HH>,
                   line)—whether appended to the same open file, a later hour file, or a higher <run>.
                   D294 then clamps its effective time to max(14:22, 15:00) = 15:00 > 14:25,
                   so it still takes effect after the trade and never resolves R_OFF_RULES. Conversely,
                   inserting it into an earlier hour file before 15:00 mutates a closed pinned file and
                   triggers halt_storage_corrupt.
                2. Cross-midnight recovery triggers T* anyway: Even if Capture_3 held no post-
                   trade listings copy at all, if the rules changed on Day 79 23:55 and the trade
                   occurred on Day 80 00:05, a Day 79 23:55 copy arriving in Capture_4 alters Day
                   79's trace/report rows before T_prev = Day 80 00:00, triggering prefix
                   divergence and ending the study at Day 79 (T*) rather than passing Day 80.
            Outcome it could change: Test 10 cannot pass as specified under D294. In production,
            holding on R_OFF_RULES instead of ending keeps the study stalled in zombie continue
            replays for up to 24 months until the last firing: any late row arriving behind Day 79 during
            those extra months triggers T* and can withdraw an earlier non-final "Earned" (CS2.1),
            and waiting keeps the study open to judge CS2.3 on a later capture where ending at
            Month 3 would have left CS2.3 "not judged".


https://gemini.google.com/app/2ab09afe442eccab                                                               5/14
11/22/26, 3:45 AM                                        See attached instructions


            Defect: Design (internal contradiction between D293 and D294). Either R_OFF_RULES is
            terminal (end_study, since an hourly REST poll cannot retroactively inject an earlier
            acquisition-order listings copy), or the test and hold rule must be restricted strictly to the
            degenerate case where zero listings copies exist after the trade's timestamp (and even
            then only within the same UTC day after T_prev).

    Finding 5 — D298: Checking only State_0's four identifiers does not detect
    state-chain rollback or intermediate State_{k-1} substitution
            What it breaks: D298 and Brief 4 step 6 ("A verdict is the study's only once its report's four
            are checked").
            Construction: D298 requires the advisor, from a fresh clone of the remote, to verify every
            settled report's four State_0 fields (reg_commit, reg_file_sha256, w_start, and
            State_0's SHA-256) before accepting its verdicts, "after a restart or a replaced state chain
            too." However, State_k carries forward Outgrew, CS2.2, CS2.3, and T_prev from
            State_{k-1} without chaining hashes back through prior accepted states, and the
            acceptance gate checks only State_0's four fields. Two substitutions pass completely
            undetected:
                1. State-chain rollback after a restart: Suppose Month 4 settles State_4 (T_prev =
                   Day 120, CS2.3 = "not shown" judged at Month 4). Before Month 5, a late print
                   arrives on Day 50 (which should diverge against State_4 and end the study at T* =
                   Day 49, withdrawing an "Earned" reached on Day 70), or new vault fills arrive that
                   would flip CS2.3 to "met". If a restart or operator replaces State_4 on disk with the
                   genuine State_0, both replay hosts run RunInput_5 = (Capture_5, State_0),
                   agree byte-for-byte, perform no prefix check (since T_prev = w_start), keep Day
                   70's "Earned", re-judge CS2.3 as "met", and emit Report 5 printing the exact four
                   authentic State_0 values. D298's gate checks those four values against GitHub
                   and accepts Report 5.
                2. Forged intermediate State_{k-1}: Replacing State_4 on disk with a crafted
                   State_4' that preserves State_0's four fields unchanged while inserting a
                   fabricated carried-forward Outgrew, CS2.2 = "held", or CS2.3 = "met" passes
                   both replay hosts (which carry forward State_{k-1}'s verdicts verbatim) and
                   passes D298's four-field remote check.
            Outcome it could change: Can forge, overwrite, or selectively re-judge CS2.1
            (Earned/Outgrew), CS2.2, and CS2.3, or suppress a mandatory T* termination after a
            restart.
            Defect: Design. Every State_k and settled report must include prev_state_sha256 and
            state_sha256 (inside the two-host compared output), and D298's external acceptance
            gate must verify both the four State_0 anchors and Report_k.prev_state_sha256



https://gemini.google.com/app/2ab09afe442eccab                                                               6/14
11/22/26, 3:45 AM                                          See attached instructions


            == last_accepted_Report.state_sha256 (starting from State_0's logged hash at k
            = 1, with each accepted state_sha256 committed to the remote).

    Finding 6 — D304: Silent drops on trades schema drift recreate absent-print
    corruption, dropped vault round trips can falsely pass CS2.3, and universe:
    [] breaks w_start initialization

            What it breaks: D304, Brief 4 step 6 ("The tests must show") and step 7 wall 3 ("What the
            reader rechecks"), and RECORDER.md ("What it records" item 1 and test 6).
            Constructions:
                1. Deleting R_MALFORMED_FRAME reintroduces silent print loss on trades: mmrec
                   stores websocket frames verbatim without validating px/sz decimal grammar or
                   trade-item schema (routing only by channel and coin). Under D304, any line whose
                   shape or number A18 cannot place is "counted, by channel and cause, and fed
                   nothing", and R_MALFORMED_FRAME is deleted. If Hyperliquid alters a trades field or
                   formats a low-priced coin's px/sz in scientific notation (e.g. "1e-5"), mmrec keeps
                   the trades subscription live and continues routing books to l2Book-fast, while
                   study2 forward silently drops the trades lines. Unlike a dead subscription (fixed
                   in round 13 via l2Book-fast-unpaired), the coin does not go stale and T keeps
                   advancing. Under pessimistic, resting entries (68.3% of the vault's first buys) and
                   take-profits silently stop filling, Wᵇ = min(bid, price) stops seeing prints below
                   the bid, and B̄ loses price events.
                2. Silent round-trip omission passes CS2.3 coverage and chained: D304 checks
                   coverage at the file level ("only from a fills file the reader decodes whole") while
                   dropping individual malformed fills ("a fill only with every field the replay of given fills
                   reads, of its type; a line without them is counted, and the chain then names the next
                   fill"). If both the opening buy and closing sell of a vault round trip fail A18's decimal
                   check (e.g. scientific-notation px or fee on a small coin), the fills file still decodes
                   whole as valid JSON (certifying coverage), both fills are silently dropped, and the
                   position stays 0 -> 0 so chained passes without error—silently omitting vault
                   entries.
                3. Shape-valid {"universe": []} stored before w_start breaks Day-1
                   initialization: RECORDER.md explicitly treats a main-dex meta returning
                   {"universe": []} (or omitting a coin) as a whole, shape-valid reply that changes
                   no subscriptions and is stored in listings/. Yet Brief 4 step 6 initializes Day 1 from
                   "the pinned listings copy in force at w_start" (singular). If a transient
                   {"universe": []} (or partial universe) is the last main-dex copy before
                   w_start, study2 forward either fails permanently with E_HEADER or silently omits
                   live universe coins from Day 1, contradicting RECORDER.md's rule that omission is
                   evidence of nothing.


https://gemini.google.com/app/2ab09afe442eccab                                                                    7/14
11/22/26, 3:45 AM                                        See attached instructions


            Outcome it could change: (1) Silently alters fills, W, Wᵇ, B̄, and entry counts across CS2.1,
            CS2.2, and CS2.3; (2) turns a true CS2.3 "not shown" into a false "met" (or vice versa)
            on incomplete fills; (3) causes permanent halt_refused(E_HEADER) or dropped
            universe coins at w_start.
            Defect: Design. (1) Unparseable/schema-invalid trades items inside a live trades stream
            should halt (R_MALFORMED_FRAME or per-coin staleness/hold) rather than silently running
            pessimistic printless; (2) any dropped fill element inside a fills file must disqualify that
            file from certifying CS2.3 coverage (and fail CS2.3 as "not judged" if inside the 61 days);
            (3) Day-1 header initialization at w_start must fold per-coin rules forward across all main-
            dex copies up to w_start (ignoring omission, honoring only explicit isDelisted),
            matching RECORDER.md.
    CONTINUE



    User prompt: continue

    Response: Finding 7 — D301: jsont decodes every JSON number through
    IEEE-754 float (breaking exact integer IDs past 253 − 1 and silently
    truncating floats), and catching Stack_overflow breaks cross-host and
    raw/packed determinism in mm2
            What it breaks: D301, RECORDER.md ("What it records" item 1 and "Implementation"),
            VAULT.md ("Limits"), and Kernel change #4.

            Constructions:
                1. IEEE-754 float-backed integers: In jsont, JSON numbers are decoded through
                   IEEE-754 float. Jsont.int64 accepts JSON numbers only inside [−253 +
                   1, 253 − 1], silently truncates fractional numbers (e.g., 1793491200000.9 decodes
                   as 1793491200000), and also accepts JSON strings in decimal/hex/octal/binary via
                   Int64.of_string_opt; Jsont.number decodes JSON null as Float.nan. Two
                   bugs follow:
                          architecture.md 6.4 notes Hyperliquid tid is already 50 bits—three bits shy
                          of 253 —and oid grows monotonically. If the venue ever emits a 54-bit numeric
                          tid or oid, Jsont.int64 rejects the valid JSON integer: mmvault fails every
                          fills pull permanently, and mm2 under D304 silently drops the print/fill.
                          Conversely, using Jsont.int64 directly without guarding against non-integer
                          floats and JSON strings violates VAULT.md's "integer time" check (accepting
                          1793491200000.9 or "0x1a1...").



https://gemini.google.com/app/2ab09afe442eccab                                                              8/14
11/22/26, 3:45 AM                                        See attached instructions


                2. Non-deterministic Stack_overflow inside the frozen forward reader:
                   RECORDER.md specifies "Nesting deeper than the decoder's stack fails the decode as
                   Stack_overflow, which the decode names", and Kernel change #4 routes the exact
                   same jsont decoder into mm2's readers and Coin_route.classify_line.
                   Because mmrec stores websocket frames verbatim, a deeply nested JSON line in
                   trades or l2Book-fast hits Stack_overflow at a depth that depends on stack-
                   frame layout, call-stack depth before invoking jsont (which differs between raw
                   study2 forward, mm2 pack, and mm2 unpack-verify), and runtime stack
                   configuration (OCAMLRUNPARAM=l=...). That can break raw ≡ packed equivalence
                   (R_PURITY) or cause differing ballots across replay hosts
                   (halt_non_deterministic).
            Outcome it could change: Permanent mmvault failure or silent print/fill drops on 54-bit
            IDs; raw/packed mismatch (R_PURITY) or unconditional halt_non_deterministic on
            deeply nested frames.
            Defect: Design. Specify an explicit syntactic nesting-depth cap (independent of call-stack
            size) instead of catching Stack_overflow, forbid null/string/fractional coercion on
            integer fields, and verify whether 64-bit integer IDs (tid, oid) need raw-token integer
            parsing rather than float-backed Jsont.int64.

    Finding 8 — D302: Process-local, send-time weight reservations can double
    the IP rate on slow replies, failed requests, and Kubernetes retries
            What it breaks: D302, RECORDER.md ("Limits it keeps"), VAULT.md ("Limits" and "Settled
            funding: Weight"), and CLUSTER.md section 2.
            Constructions:
                1. Send-time expiry doubles server-side weight on slow replies: Both
                   RECORDER.md and VAULT.md reserve weight "in a window of the 60 s before it" when
                   sending. Suppose mmvault sends a 120-weight fills page at t = 0.0 s, and the
                   server finishes processing and returning 2,000 fills at t = 25.0 s. If the reservation
                   expires 60 s after send (t = 60.0 s), mmvault sends the next 120-weight page at
                   t = 60.1 s, reaching the venue 35 s after the first—billing 240 weight (2× vault's
                   120 allocation) inside the venue's 60 s window. The same holds for settled (90 vs
                   45) and ws (80 vs 40).
                2. Unspecified settlement on failed/truncated/timed-out requests: The spec says
                   "once its reply is read the reservation is cut to the weight the venue counts", without
                   stating what happens on timeout (30 s), truncated body after 1,999 items, HTTP 500,
                   or 429. Dropping the reservation on error lets retries exceed the allocation; keeping
                   worst-case weight for 60 s from failure/completion must be stated explicitly.
                3. In-memory windows reset on Kubernetes Job/StatefulSet restarts: mmvault
                   run and mmvault funding are Kubernetes CronJobs that exit 1 on any failed pull,

https://gemini.google.com/app/2ab09afe442eccab                                                               9/14
11/22/26, 3:45 AM                                         See attached instructions


                    and mmrec exits non-zero on write failure. Under standard Job backoffLimit
                    (default 6) or StatefulSet crash restarts, a fresh process spawns seconds later with
                    an empty in-memory 60 s window and immediately re-spends its full allocation on
                    top of the dying process's requests (e.g., vault spends 120 weight on fills, fails fees,
                    exits 1, and restarts 10 s later to spend another 120 weight).
            Outcome it could change: Can exceed Hyperliquid's 1,200/min IP ceiling (with hl at 480
            and one-off scripts at 300), causing IP-wide 429 failures across mmrec, vault, and
            settled—losing live listings copies or delaying funding/vault pulls.

            Defect: Design. Anchor the 60 s window expiry to request completion/failure (keeping
            full worst-case weight on any timeout, truncation, or HTTP error), and set backoffLimit:
            0 on CronJobs (letting the next scheduled run retry) or persist reservation timestamps on
            disk across restarts.

    Finding 9 — D300: Libcurl specification leaves a Content-Length: 1 GiB
    test contradiction, close-delimited Transfer-Encoding bypasses, 1xx
    header bleed, and SIGPIPE exposure under CURLOPT_NOSIGNAL
            What it breaks: D300, RECORDER.md ("What it records" item 1 and test 21), and VAULT.md
            ("Limits" and test 7).
            Constructions:
                1. Spec vs Test 21 contradiction on Content-Length: 1 GiB: RECORDER.md item 1
                   enforces the 16 MiB cap only "counted by the write callback, which stops the transfer
                   at the first byte past it", while Test 21 requires "a Content-Length of 1 GiB, within 5
                   s". If the server sends Content-Length: 1073741824 and stalls or trickles bytes
                   slowly, a write-callback-only check waits 30 s (timeout) instead of failing within 5 s.
                2. Close-delimited bypasses and 1xx header bleed: RECORDER.md requires only that
                   "the final head announced a Content-Length or chunking." Under RFC 9112 §6.3, a
                   response with Transfer-Encoding: gzip or Transfer-Encoding: chunked,
                   identity (and no Content-Length) is close-delimited, yet libcurl returns
                   CURLE_OK on EOF; a naive header check for Transfer-Encoding or substring
                   chunked would accept a truncated body. Likewise, libcurl's HEADERFUNCTION fires
                   for 100/103 informational heads before the final 200: without explicitly resetting
                   framing flags on each HTTP/1.x status line, a header on a 1xx head bleeds into the
                   200 check.

                3. CURLOPT_NOSIGNAL = 1 disables libcurl's SIGPIPE suppression: Setting
                   NOSIGNAL = 1 stops libcurl from ignoring SIGPIPE on peer-closed sockets. While
                   Async ignores SIGPIPE globally in mmrec, any synchronous caller (mmvault or test
                   harness) that does not explicitly install Sys.Signal_ignore for SIGPIPE can be
                   killed abruptly on a remote reset during a TLS write without logging its error event.


https://gemini.google.com/app/2ab09afe442eccab                                                               10/14
11/22/26, 3:45 AM                                       See attached instructions


            Outcome it could change: Accepts truncated close-delimited replies into listings or
            vault (corrupting rules or advancing watermarks), fails Test 21, or kills mmvault mid-run
            without an error event.
            Defect: Design/spec gap in RECORDER.md item 1. Explicitly require: rejecting Content-
            Length > 16 MiB in the header callback (or CURLOPT_MAXFILESIZE_LARGE) in addition
            to the write callback; resetting framing state on every HTTP/1.x status line; verifying
            either a valid Content-Length or that chunked is the final transfer-coding token (with
            transfer decoding on and Accept-Encoding unset); and ignoring SIGPIPE at process
            startup in all callers.

    Finding 10 — D303: The four criteria drafts omit all five halt_* terminal
    states, and Draft CS2.1 understates what hold (1) adds
            What it breaks: D303 (all four criteria drafts in architect-r14-s2-report.md) vs Brief
            4 step 6 and step 7 wall 3.
            Constructions:
                1. Unaddressed halt_* states: Brief 4 defines five terminal halt states that
                   permanently stop the monthly timer: halt_fee_witness,
                   halt_storage_corrupt, halt_refused(code), halt_non_deterministic,
                   and halt_substitution. None of the four criteria drafts mention them. Suppose
                   Month 4 settles "Earned" (or "Outgrew", or CS2.2 "held"), and Month 5 hits
                   halt_non_deterministic (three distinct hosts produce three pairwise-distinct
                   ballots on identical RunInput_k, proving the frozen build itself is non-deterministic)
                   or halt_fee_witness (showing the forward fee schedule diverged from the vault's
                   Layer-1 fees) or halt_storage_corrupt. The drafted criteria leave unspecified
                   whether earlier verdicts stand, are withdrawn, or are voided—and Draft CS2.2/CS2.3
                   list only end_study causes when defining when unjudged conditions become "not
                   judged".

                2. Understatement in Draft CS2.1 ("What it adds"): Draft CS2.1 says hold (1) "runs on
                   and can name 'Earned' on a later day", omitting that hold (1) can equally run on to
                   name "Outgrew" (and reach Day 61/212 for CS2.3/CS2.2). Ville's 5% bound still
                   covers both rungs over the 730 days (B̄ >= 1), so this does not break size, but the
                   draft understates what the revision adds.
            Outcome it could change: Leaves a post-hoc discretion gap over whether prior CS2.1–
            CS2.3 verdicts stand if the study halts on halt_non_deterministic,
            halt_fee_witness, halt_storage_corrupt, or halt_refused.

            Defect: Design (fix verdict disposition for each halt_* state before the freeze—in
            particular, whether halt_non_deterministic voids prior verdicts of the same non-
            deterministic build) and text (include "Outgrew" and halt_* stops in Drafts CS2.1–
            CS2.3).

https://gemini.google.com/app/2ab09afe442eccab                                                              11/14
11/22/26, 3:45 AM                                        See attached instructions


    What I accept
            D292 (receipt-clock premise, witness reporting, and dropping the book witness once
            all coins have final ends): Accepted; closes GPT-6.2's day-212 and receipt-clock findings
            cleanly.
            D295 (durable capture paths fsynced up to the recording root; deleting the monthly
            capture pull and --from-ms): Accepted; resolves the power-cut path-durability race at
            its cause and removes an unnecessary pull/lock.
            D297 (separating capture admission from replay settlement; five end_study causes
            including complete): Accepted; closes the state machine's missing successful exit and
            missed-firing admission ambiguity.
            D299 (buy-time cost-basis cash reserve max(0, (24C - B)/25), post-rounding
            basis reduction, K1 invariant wording, and both-way power statement): Accepted.
            D300/D301 architectural pivot (replacing hand-rolled HTTP/JSON code with ocurl +
            jsont, rejecting cohttp-async and jsonm): Accepted in principle; Findings 7 and 9
            address the remaining integration edges.
            D305 (main-dex meta first, no : on main dex, duplicate dex check, 100,000 perp cap,
            buffer shrink, 16 MiB websocket cap): Accepted (modulo Day-1 universe: [] folding
            in Finding 6).
            Draft criteria structure (capture provenance, superseding the original "stands in
            every later replay" clause, observed-fills scope for CS2.3, reserve disclosure):
            Accepted (modulo Findings 2, 4, 6, and 10).

    Ledger

                                                                                     Changes what is
      Status          Point
                                                                                     built or run?

                                                                                     As proposed (subject
                      Round 13 findings 1–3 closed at their original causes
      Agreed                                                                         to new disputes
                      (43116ed, D291/D295, D296)
                                                                                     below)
                      D292 (receipt-clock premise & reporting; all-coins-ended
                      day-212 handling), D295 (durable capture paths, no
                      monthly pull), D297 (admission vs settlement, complete
      Agreed                                                                         As proposed
                      exit), D299 (cash reserve formula, K1 invariant, both-way
                      power), D305 (listings order, ownership, caps, buffer
                      shrink)


https://gemini.google.com/app/2ab09afe442eccab                                                              12/14
11/22/26, 3:45 AM                                       See attached instructions



                                                                                    Changes what is
      Status          Point
                                                                                    built or run?

                      Architectural pivot to ocurl + jsont (rejecting cohttp-       As proposed (with
      Agreed
                      async, jsonm, bespoke HTTP/JSON parsers)                      Findings 7 & 9 fixed)
               Finding 1 (D290/D291): Cross-clock end_c causes
                                                                                    Yes (horizon,
               permanent reach > end horizon deadlock (under 10-
      Disputed                                                                      delisting end, kernel
               min slow clock or 0-skew race) and inverted finality
                                                                                    A18)
               interval [end_c, e_c]
               Finding 2 (D296): Hardcoded 2026-11-01 re-read floor
                                                                                    Yes (mmvault, frozen
      Disputed livelocks CS2.3 under the 10,000-fill cap; frozen reader
                                                                                    reader, CS2.3)
               omits pull-completeness/EOF/pagination rechecks
               Finding 3 (D294): Monotonic max(recv, prev_time)
               on listings lets one forward clock spike poison Day-1                Yes (listings reader,
      Disputed
               init (E_HEADER), all future rules changes (R_OFF_RULES),             kernel A18)
               and e_c + 30 d finality
               Finding 4 (D293 vs D294): R_OFF_RULES recovery via
                                                                                    Yes (stop
               late listings copy is impossible once any post-trade copy
      Disputed                                                                      classification, Brief 4
               is captured under acquisition-order clamping and
                                                                                    test 10, Draft CS2.1)
               append-only storage
               Finding 5 (D298): External gate checks only State_0's                Yes (State_k hash
      Disputed four fields, missing state-chain rollback to State_0 and             chaining, report
               forged intermediate State_{k-1}                                      output, external gate)
               Finding 6 (D304): Silent drops on trades schema drift
                                                                                    Yes (frozen reader,
               run pessimistic printless; dropped malformed vault
      Disputed                                                                      CS2.3 coverage, Day-
               round trips pass CS2.3 coverage + chained; stored
                                                                                    1 header fold)
               universe: [] breaks w_start init

               Finding 7 (D301): jsont float-backed integers break
                                                                                    Yes (mmrec,
               exact IDs past 253 − 1 and truncate fractional
      Disputed                                                                      mmvault, mm2 JSON
               timestamps; catching Stack_overflow breaks
                                                                                    decoding)
               raw/packed and cross-host determinism in mm2
               Finding 8 (D302): Send-time windowing, unspecified                   Yes (mmrec,
               error settlement, and in-memory CronJob/StatefulSet                  mmvault, mmvault
      Disputed
               windows across restarts can double the allocated IP                  funding, K8s
               weight                                                               backoffLimit)




https://gemini.google.com/app/2ab09afe442eccab                                                                13/14
11/22/26, 3:45 AM                                  See attached instructions



                                                                               Changes what is
      Status          Point
                                                                               built or run?

               Finding 9 (D300): Content-Length: 1 GiB vs write-
               callback-only cap breaks Test 21; non-final Transfer-           Yes (RECORDER.md
      Disputed Encoding / 1xx header bleed bypass close-delimited              REST client spec &
               rejection; NOSIGNAL = 1 exposes synchronous callers to          tests, mmvault)
                      SIGPIPE

               Finding 10 (D303): Criteria drafts omit all five halt_*         Yes (verdict
               terminal states (notably halt_non_deterministic,                disposition on
      Disputed
               halt_fee_witness); Draft CS2.1 omits "Outgrew"                  halt_* and criteria
               under hold (1)                                                  drafts)




https://gemini.google.com/app/2ab09afe442eccab                                                       14/14
```
