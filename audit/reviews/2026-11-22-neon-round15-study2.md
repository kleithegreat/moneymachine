# Neon on round 15's study 2 half (D306 to D322)

Model Gemini 4 Neon through the Gemini web UI (the human pasted `neon-r15-study2-bundle.md`, 383 KB, and its prompt; reply saved as `r15-study2.pdf`, 2026-11-22 21:06 UTC (16:06 EST)). Extracted by `pdftotext -layout`:

```text
11/22/26, 4:05 PM                                     See attached instructions




    See attached instructions
    https://gemini.google.com/app/25a16b91c2a7ba54

    User prompt: See attached instructions
    Response: Round 15 has not converged. The three deletions are genuine simplifications at the
    cause—D309 (ending at every stop) and D314 (whole replies by JSON decode) close their
    round-14 flaws cleanly, and D311 (the accepted state chain) and D315 (three-step jsont with
    byte-sliced integers) close the authentication and numeric-truncation defects. Three design
    defects remain in D306/D307/D310, D317's unreadable-print withholding, and D317's page/fill
    rechecks (Findings 1–3 below), plus two smaller conflicts in halt_fee_witness and the criteria
    drafts (Part 2).

    Finding 1 · D306, D307, D310: Unbounded e breaks delisting finality with zero
    clock fault (and backward clocks under D310 mutate published history)
    What it breaks. brief 4 step 7 wall 3 ("A coin's listing ends at its reach", "An end is final thirty
    days after its flag", and "One event, one item" copy timing) and KERNEL.md A18 (routed items 1–
    3).
    D306 qualifies a flagging copy received at e whenever B(e) (the first whole hour after e + 1
    h) and "every hour from R to it" hold no settlement; D307 declares that end final when a
    completed funding query from a pull begun at least 30 days after e asked "every hour from R to
    B(e)" and returned none. Neither rule requires e >= w_start or R <= B(e). Because
    listings files are explicitly exempt from the w_start - 24 h skip, and D310 removed all
    lower bounds on recv, any flagging copy with B(e) < w_start <= R makes the hour range
    [R, B(e)] vacuously empty.

    Constructions.
        1. Zero clock skew (honest venue, honest recorder): mmrec records listings from
           2026-11-14 onward; w_start = 2027-02-01. Suppose a universe coin X is delisted on
           2026-12-01 (flagged at e = 2026-12-01 04:40, B(e) = 06:00 holding no
           settlement) and relisted on 2027-01-15. At w_start, the last copy <= w_start shows X
           live, so X enters the forward header. During Month 1 (Capture_1, 2027-03-01 12:00
           UTC), suppose X has a temporary funding outage starting 2027-02-20 04:00 (R =
           2027-02-20 04:00). Because e is pinned in Capture_1, B(e) = 2026-12-01 06:00
           holds no settlement, [R, B(e)] is empty (R > B(e)), and any completed funding pull of
           X in 2027-02 began > 30 days after e and vacuously asked [R, B(e)]. D306/D307
           immediately declare X ended and final at 2027-02-20 04:00: T_1 advances to 2027-
           03-01, X is falsely liquidated on Day 19, and when Month 2 backfills Feb 20–28, R
           advances, mutating published Day 19 and killing the study at T* = Day 19. Even without
           a mid-month outage, if the 2027-03-01 00:17 pull fails so R = 2027-03-01 00:00,
           the pre-w_start flag certifies X final at midnight immediately.


https://gemini.google.com/app/25a16b91c2a7ba54                                                             1/10
11/22/26, 4:05 PM                                      See attached instructions



        2. Power-cut RTC reset (the exact prodesk7 failure cited in D310): Coin X is delisted on
           Day 45 04:05 while a short funding page leaves R = Day 44 04:00. After a power loss
           on Day 45, one listings poll before NTP sync stamps e = 1970-01-01 (or 2026-01-
           01 < floor_ms). Again B(e) < floor_ms < w_start <= R, so B(e) holds no
           settlement, [R, B(e)] is empty, and every 2027 pull is > 30 days after e. The short-page
           reach Day 44 04:00 is declared immediately final with zero 30-day grace and zero
           empty query, advancing T past Day 44; the next pull backfills Day 44 and terminates the
           study at T* = Day 43.
        3. D310 backward clock into published history: Deleting the clamp fixes forward jumps
           (2030), but leaves backward jumps unguarded. After a szDecimals or margin-tier change
           on Day 120, a post-reboot copy on Day 180 stamped with a stale clock Day 10 05:00 (or
           (C_0, w_start]) sorts into Day 10 (or Day 1 initialization) in Month 6, retroactively
           altering already-published rules and terminating the study at T* = Day 9 (or w_start).
    Outcome changed. False liquidation of a live coin (moving CS2.1 Wᵇ, CS2.2 variance, and CS2.3
    entries), bypassing the 30-day delisting grace on an incomplete funding pull, or premature
    end_study at T* withholding all three verdicts.

    Defect of. Design. D306/D307 must require R <= B(e) (so [R, B(e)] is non-empty and
    B(e) >= w_start) and restrict qualifying flags to copies strictly after the last copy <=
    w_start that initialized the coin as live (in acquisition order). For D310, a copy's effective time
    should not sort before an earlier-acquired copy that already governed a published day (or before
    w_start once acquired after w_start—e.g. ignoring copies whose recv steps behind the prior
    copy's recv by more than the 1-hour premise, rather than clamping all future copies to a
    forward outlier).

    Finding 2 · D317: Unreadable-print book withholding is unimplementable on
    non-JSON lines, breaks on clock step-backs, and stalls quiet coins across
    reconnects
    What it breaks. brief 4 step 7 wall 3 ("What the reader rechecks — Prints"), step 7 Test 10 ("an
    unreadable print"), and KERNEL.md A18 (routed item 6).
    brief 4 specifies that an unreadable trades line withholds the coin's l2Book-fast lines "on
    that line's run and connection, from its recv to the recv of the next trades line of the coin there
    that holds an item", and that "a trades line that is not JSON or not of the channel's shape, so
    that its coin cannot be read, is such a gap for every universe coin on its connection".
    Constructions.
        1. Non-JSON line has no conn or recv: Under D315, Step 2 (Jsont.ignore) runs over the
           entire JSONL line before Step 3 extracts any field. When a line in a trades file is literally
           not JSON (the exact fixture required by Test 10: "a trades line that is not JSON withholds
           the books of every universe coin on its connection until each one's next readable print"), Step


https://gemini.google.com/app/25a16b91c2a7ba54                                                               2/10
11/22/26, 4:05 PM                                        See attached instructions



           2 fails on the whole line and yields neither conn nor recv. The reader cannot know which
           connection's coins to withhold or what recv starts the gap.
        2. Clock step-back in recv space (mutates published days or drops withholding):
           Suppose Month 1 publishes T_1 = Day 30 00:00. At Day 30 00:30 (on the same run
           and connection), the recorder's host clock steps back 2 hours to Day 29 22:30.
                    Retroactive prefix mutation: A single unreadable trades line occurs at recv = Day
                    29 22:35 (actually Day 30 00:35), followed in acquisition order by a readable print
                    at recv = Day 29 22:36. Comparing l2Book-fast lines against recv ∈
                    [22:35, 22:36) in Month 2 retroactively withholds Day 29's already-published
                    books from 22:35 to 22:36, causing prefix divergence and ending the study at T* =
                    Day 28!

                    Withholding defeated: Conversely, if the venue starts emitting "1e-5" prints right
                    after the 2-hour step-back (22:35 .. 00:30), an implementation that finds the
                    next readable print by recv order matches the pre-step readable print at Day 29
                    22:36 (recorded 2 hours earlier), ending withholding after 1 second and feeding 2
                    hours of fresh books while every print is unreadable.
        3. Quiet coin across reconnects, and multi-print frame ambiguity: Because conn is a slot
           index (0..7) reused across reconnects within one <run>, a single unreadable trades
           frame on conn = 2 at 10:00:00 right before a clean reconnect and trades re-
           acknowledgement at 10:00:01 withholds books on (run, conn = 2) until the coin's
           next readable print. A quiet universe coin that sees zero trades for 6 hours (or until
           delisting) is forced stale for the entire 6 hours despite a healthy, acknowledged trades
           stream. Separately, a trades frame holds an array msg.data = [p_1, p_2, ...]: if
           p_1 is readable and p_2 has px: "1e-5", "holds no item" is ambiguous—per-element
           decoding yields 1 item and fails to withhold books despite dropping p_2, whereas whole-
           line rejection drops valid p_1 too.
    Outcome changed. Test 10 cannot be satisfied as written; retroactive withholding terminates
    the study at T*; silent withholding failure feeds fresh books with unread prints (false
    CS2.1/CS2.3); prolonged staleness on quiet coins suppresses entries/exits and freezes bids in Wᵇ
    (moving CS2.1, CS2.2, CS2.3).
    Defect of. Design. Define the unreadable-print rule strictly on the three distinguishable cases:
    (a) a line that fails whole-line JSON syntax has no conn/recv, so it must either withhold all
    universe coins across that hour file from the preceding valid line's acquisition position, or be
    handled by envelope-free file-level staleness; (b) a valid-JSON trades line with any unreadable
    print element must trigger withholding (no mixed-element escape); and (c) withholding must
    operate in acquisition/stream order rather than raw recv intervals that can reach back behind
    T_prev, and should clear on a new trades acknowledgement (or be driven by mmrec routing
    once mmrec also checks A18's print shape, which shares the exact one-socket order already
    used for l2Book-fast-unpaired).


https://gemini.google.com/app/25a16b91c2a7ba54                                                            3/10
11/22/26, 4:05 PM                                          See attached instructions



    Finding 3 · D317: Page rechecks still pass truncated/wrong pulls, and "fill
    line" conflates a 2,000-fill page with a single fill
    What it breaks. brief 4 step 7 wall 3 ("What the reader rechecks": Vault fills, Coverage, and An
    end's finality), VAULT.md ("What the reader trusts of a pull"), and the CS2.3 criteria draft.
    Constructions.
        1. Truncated or wrong-request fills pull passes the coverage recheck: Both brief 4
           and VAULT.md check only: clean zstd stream end, "its first page's request has no
           endTime", each later page's startTime equals the previous page's last fill's time, every
           page but the last has 2,000 fills and the last fewer, and non-decreasing fill times >=
           startTime.

                    A faulty writer whose Page 1 has no endTime (2,000 fills ending at t_1) and whose
                    Page 2 includes "endTime": t_1 + 1000 (returning 10 fills < 2,000) passes
                    every single check while omitting the entire range after t_1 + 1000—falsely
                    certifying coverage over [t_0, now - 31 d] with fewer than 10,000 fills!
                    The recheck also omits verifying "type": "userFillsByTime", "user":
                    <vault>, "aggregateByTime": false, and >= 1 page: an
                    "aggregateByTime": true pull merges same-millisecond fills (lowering counts
                    and hiding fills), a wrong-user pull returning [] certifies full coverage on zero fills,
                    and a 0-line clean zstd stream satisfies the universal quantifiers vacuously.
        2. Finality query recheck omits stream end, endTime consistency, and the + 3_599_999
           hour-end bound: brief 4's finality recheck requires only that pages chain at the whole
           hour after the prior row's hour, with 500 rows per non-final page and fewer on the last. It
           does not require a clean zstd stream end on the settled/funding file (unlike Coverage),
           nor that every page of one query shares the same coin and endTime (absent or identical),
           nor that a bounded gap query's endTime is at least B(e) + 3_599_999 (rather than B(e)
           exact). On a coin delisted at 04:05 (R = 05:00, B(e) = 06:00) and relisted at 07:00, a
           gap query with endTime = 06:00:00.000 misses a settlement of hour 06:00 stamped
           at 06:00:00.050, returning [] and wrongly finalizing an end when hour B(e) actually
           settled.
        3. 2,000-fill page line vs single fill (unreadable fills): fills/*.jsonl.zst stores one
           2,000-fill page per line, not one fill per line. Suppose a Day 95 daily re-read covering
           Days 1..95 puts 1,500 fills from Days 1..61 and 500 fills from Days 62..95 onto one page line,
           and fill #1,800 (Day 80, outside CS2.3's 61-day span) has px: "1e-5". Under D315's
           whole-line typed decode (brief 4 "One decoder" + "Vault fills"), the entire 2,000-fill line
           fails Step 3, losing its 1,500 Days 1..61 fills from that file and leaving the failed line with no
           readable time—which triggers "where its time ... cannot be read, CS2.3 is 'not judged'"
           purely because of an irrelevant Day 80 fill.



https://gemini.google.com/app/25a16b91c2a7ba54                                                                  4/10
11/22/26, 4:05 PM                                    See attached instructions



    Outcome changed. CS2.3 certified "Met" or "Not shown" on a truncated or aggregated vault
    pull; CS2.3 falsely forced to "Not judged" by an out-of-span fill on a shared page; or a
    delisting falsely finalized despite a late-stamped settlement in hour B(e).
    Defect of. Design.
           Require every page of a covering fills pull (>= 1 page) to have "type":
           "userFillsByTime", "user": <vault>, "aggregateByTime": false, and no
           endTime.

           Require a finality query to live in a cleanly stream-ended file, have >= 1 page, match
           "type": "fundingHistory" and "coin": c on every page, keep the same endTime
           across all pages of the query, and have either no endTime or endTime >= B(e) +
           3_599_999.

           Separate page-envelope decoding (recv, request, msg as a JSON array) from per-
           element fill decoding so an unreadable fill element on Day 80 is judged by its own time
           without discarding the other 1,999 fills on its page.
    CONTINUE



    User prompt: continue

    Response: Finding 4 · D312: halt_fee_witness contradicts State_k verdict
    naming and is silently overridden by end_study (complete)
    What it breaks. brief 4 step 7 wall 3 ("Every settled run judges what its capture can", "A halt
    ends the study at its last accepted report", and "Two hosts... next settled state State_k").
    D312 states that all five halts—explicitly including halt_fee_witness—end the study at the
    last accepted report, with "what accepted reports named stands, each as its capture's, nothing is
    named after, a condition not judged is 'not judged'". Yet two other clauses in the same section
    specify that every settled run computes State_k by "naming what its capture newly allows"
    alongside terminal_action ∈ {continue, end_study, halt_fee_witness}, and that
    "A run whose State_k is complete settles end_study (complete), whatever else it might also
    name".
    Constructions.
        1. Verdict named on falsified fees: Months 1–4 are accepted (State_4, Day 120, no
           crossing). On Day 135, the venue increases fees (or mmvault fees misses a tier change),
           so the engine simulates Days 135–150 with stale lower fees; the vault's forward fills
           expose the mismatch, triggering halt_fee_witness in Month 5. Under the artificially low
           fees, Wᵇ crosses 20 × B̄ on Day 148. The State_k specification instructs Month 5 to emit

https://gemini.google.com/app/25a16b91c2a7ba54                                                          5/10
11/22/26, 4:05 PM                                    See attached instructions



           "Outgrew" on Day 148 in State_5 alongside terminal_action =
           halt_fee_witness—contradicting D312's rule that nothing is named after State_4.
           Once Month 5's report is logged, "the last accepted report" is also ambiguous between
           State_4 and State_5.

        2. complete overrides halt_fee_witness: Suppose State_7 (Day 210) already carries
           "Outgrew" (Day 90) and CS2.3 "Met". On Day 211, the fee witness fails
           (halt_fee_witness), while Month 8 reaches Day 212 and evaluates CS2.2 ("Held")
           using the mis-modeled Day 211–212 fees. Because State_8 now has CS2.1 final and both
           CS2.2 and CS2.3 judged, the rule "A run whose State_k is complete settles end_study
           (complete), whatever else it might also name" silently promotes the fee-witness halt into
           a clean end_study (complete), suppressing the halt and publishing a CS2.2 verdict
           computed under falsified fees. (Similarly, if a run reaches complete in the same capture
           that diverges at T* >= Day 61, complete masks the changed cause unless both are
           recorded.)
    Outcome changed. False "Outgrew", "Earned", or CS2.2 "Held" / "Did not hold"
    published on mis-modeled fees, and silent suppression of halt_fee_witness.
    Defect of. Design. Give halt_fee_witness strict precedence over verdict naming and over
    end_study (complete): when the forward fee witness fails, State_k must carry forward
    State_{k-1} unchanged (naming zero new verdicts and publishing zero new days) with
    terminal_action = halt_fee_witness, and D312 must state explicitly that the study ends
    at State_{k-1} (the last accepted report prior to the halt).

    Finding 5 · D321: CS2.1's drafted "Why the 5% holds" makes a false
    adaptedness claim for D306's backdated delisting
    What it breaks. The CS2.1 criteria draft (architect-r15-s2-report.md, "Why the 5% holds")
    and GPT-6.2's round 14 finding on CS2.1's common-process argument.
    The draft asserts that the record's reading—explicitly naming "where a listing ends, when a
    copy's rules take force, which books a coin's unreadable prints withhold"—"depends on each line's
    own content and on what was recorded before it, never on later prices", so W is a nonnegative
    supermartingale under Ville's bound provided late writing does not depend on prices.
    Construction. Under D306, a coin X that settles hour 03:00 normally (price 100), has no
    settlement for hour 04:00 (R = 04:00), and continues trading on live books and prints from
    04:00 to 04:30 has its 04:00..04:30 history determined by events after 04:00:

           If X crashes from 100 to 20 at 04:15 and that crash triggers an emergency venue delisting
           at 04:30 (flagged at e = 04:40, with no settlements through B(e) = 06:00), D306
           retroactively backdates the listing end to R = 04:00, deletes the 04:00..04:30 crash,
           and settles the long-only ledger at 03:59's pre-crash price of 100.



https://gemini.google.com/app/25a16b91c2a7ba54                                                          6/10
11/22/26, 4:05 PM                                      See attached instructions



           If instead X rallies from 100 to 180 at 04:15, the venue does not delist it and settles hour
           04:00; the ledger keeps the rally to 180.

    Even with zero clock skew and zero late writing, whether a listing ends at R depends on a flag at
    e > R and the absence of settlements through B(e) > e + 1 h—information strictly in the
    future of R that, in real venues, is directly correlated with price crashes in [R, e] (emergency
    delistings). Backdating liquidation to R therefore asymmetrically censors adverse moves and can
    break the supermartingale property of W even when raw prices satisfy the null. (Separately, as
    shown in Findings 1 and 2, backward-clock copies under D310 and recv-interval print
    withholding under D317 can also read future lines into earlier times.)
    Outcome changed. The 5% false-confirmation guarantee of CS2.1 ("Earned" and "Outgrew") is
    overstated relative to the actual proof.
    Defect of. Text (and stated assumption). Remove the false claim that "where a listing ends ...
    depends on ... what was recorded before it, never on later prices", and add the required condition
    explicitly beside the late-writing proviso: the 5% bound holds provided neither late writing nor a
    coin's delisting (and non-settlement of hour R) depends on price moves after R.

    Finding 6 · D318 & D314: Sequential one-off scripts still bypass the 1,200/min
    cap, and Test 21 contradicts D314's deletion of header checks
    What it breaks. CLUSTER.md / D318 (one-off script allocation) and RECORDER.md Test 21 /
    VAULT.md Test 7 (overflowing Content-Length).

    Constructions.
        1. Sequential one-off invocations (ingest/hl.py): D318 guards ingest/hl.py with
           data/.hl-rest.lock so only one script runs at a time, "with no limiter state carried
           across processes". A shell loop or operator running four short ingest/hl.py commands
           back-to-back within 20 seconds obeys the lock while starting each process with an empty
           300-weight (+100 post-reply item overshoot) window—sending up to 4 × 400 = 1,600
           weight in one minute on top of ws/vault/settled (and note also that a slow vault run
           finishing at XX:06:59 before the XX:07:00 CronJob adds +120 across the process
           boundary, though that alone stays under 1,200).
        2. Test 21 / VAULT.md Test 7 vs D314: D314 deletes all header/framing checks and relies on
           JSON decoding (plus CURLOPT_MAXFILESIZE_LARGE) to reject cut bodies. Yet
           RECORDER.md Test 21 and VAULT.md Test 7 state that every fixture's body is "otherwise a
           valid response of the venue's shape" and assert that "a Content-Length curl cannot read
           (18446744073709551616, 99999999999999999999), whatever follows it" fails with an
           error. If curl 8.22.0 ignores an overflowing Content-Length and falls back to close-
           delimited reading (the behavior GPT-6.2 cited in lib/http.c), a complete valid JSON
           body after 18446744073709551616 decodes cleanly and fails the test despite being
           harmless under D314's own completeness argument (only a cut body after an overflowing
           length is guaranteed to fail JSON decoding).

https://gemini.google.com/app/25a16b91c2a7ba54                                                            7/10
11/22/26, 4:05 PM                                       See attached instructions



    Outcome changed. HTTP 429s during live listings, vault, or settled-funding pulls (lost
    recordings or delayed coverage); a builder blocked on an unsatisfiable Test 21 / Test 7 fixture.
    Defect of. Design for D318 (persist the rolling 60-second request timestamps/weights inside
    the lockfile or an adjacent state file updated under data/.hl-rest.lock so back-to-back
    invocations share one 300/min budget); Text / Test spec for D314 (verify curl 8.22.0 with
    CURLOPT_MAXFILESIZE_LARGE set, and if curl falls back to close-delimited reading on
    overflow, scope the Test 21 / Test 7 fixture to a cut body under an overflowing Content-Length
    rather than "whatever follows it").

    What I accept
    The following Round 15 moves close their Round 14 findings at the cause and are accepted as
    specified:
           D308 (Clause 0 calendar bound): capping T at the midnight beginning the capture's
           firing day closes the post-delisting future-judging defect cleanly.
           D309 (Every stop ends the test): deleting the hold class closes Neon's Round 14 Finding
           4; the residual lot-size survival cost is honestly documented in wall 2 for the advisor to
           weigh, with no hidden hold state.
           D311 (Authenticated state chain): printing State_{k-1}, Capture_k, and State_k
           hashes inside the two-host ballot and checking State_{k-1} against
           audit/study2/accepted.tsv on a fresh remote clone closes both rollback and forged-
           state attacks (Neon Finding 5).
           D313 (Durable manifest & per-file capture wording): atomic fsync of the manifest and
           its ancestor directories, and stating explicitly that a capture is a per-file length cut rather
           than an instant.
           D314 (Core completeness rule): replacing bespoke HTTP framing checks with strict
           JSON array/object decoding, CURLOPT_MAXFILESIZE_LARGE = 16 MiB, and ignoring
           SIGPIPE is the right simplification at the cause (modulo the Test 21 wording in Finding 6).

           D315 (Three-step jsont): the depth-64 pre-pass, Jsont.ignore, byte-sliced integer
           decoding via locations, explicit duplicate-key semantics, and CR/LF-to-space
           normalization in mmvault close Neon Finding 7 and GPT-6.2's numeric-truncation defects
           cleanly.
           D316 (Exact retention coverage & re-read frontier): requiring fewer than 10,000 distinct
           fills at or after t and advancing the daily re-read past what retention has taken closes
           Neon Finding 2.1's livelock (and holds even when live fills occur during multi-page
           pagination), and the 2,000-fills-per-millisecond paging premise is cleanly stated.
           D318 (Recorder & collector weight enforcement): retiring hl, holding request weights
           until 60 s after request completion, retaining maximum weight on failures, and setting

https://gemini.google.com/app/25a16b91c2a7ba54                                                               8/10
11/22/26, 4:05 PM                                     See attached instructions



           backoffLimit: 0 on CronJobs close Neon Finding 8 for ws, vault, and settled
           (modulo sequential ingest/hl.py invocations in Finding 6).
           D319 & D320 & D322: the 64-byte per-name catalog bound, per-coin Day 1 initialization
           (handling {"universe": []}), and removing the hl comparison coupling are all clean.
           CS2.1 reserve draft & CS2.2 draft: both are sound once the horizon (Finding 1) and halt
           precedence (Finding 4) fixes are in place.

    Ledger

                                                                                  Changes what is
     Status         Point
                                                                                  built or run?

                    D308 (calendar bound), D309 (every stop ends the test),
                    D311 (authenticated state chain), D313 (durable manifest),
                    D315 (three-step jsont + byte-sliced integers), D316 (exact
     Agreed                                                                     As proposed
                    retention coverage & frontier), D319 (64-byte names), D320
                    (per-coin Day 1), D322 (hl decoupling), CS2.1 reserve &
                    CS2.2 drafts
              Finding 1 · D306, D307, D310: unbounded e allows B(e)               Yes (reader
              < w_start <= R (vacuously finalizing live coins or short            delisting/finality &
     Disputed
              pages on pre-w_start flags or post-reboot RTC resets);              listings timing;
              backward clocks under D310 mutate published history                 KERNEL.md A18)

              Finding 2 · D317 (unreadable prints): non-JSON lines
              have no conn/recv; recv-interval withholding mutates                Yes (forward reader
     Disputed published days or fails on clock step-backs; quiet coins            / mmrec routing;
              stall across reconnects; mixed valid/invalid multi-print            KERNEL.md A18)
              frames are ambiguous
              Finding 3 · D317 (page & fill rechecks): fills recheck
              checks no endTime only on page 1 and omits                          Yes (forward reader
              type/user/aggregateByTime/>= 1 page; finality                       & CS2.3 input
     Disputed
              recheck omits clean stream end, coin/endTime                        decoding; CS2.3
              consistency, and B(e) + 3_599_999; whole-line decode                draft)
              conflates 2,000-fill pages with single fills
              Finding 4 · D312 (halt_fee_witness precedence):                     Yes (study2
              State_k verdict naming contradicts "nothing named after             forward state
     Disputed
              last accepted report", and end_study (complete)                     transition &
              overrides halt_fee_witness                                          settlement)



https://gemini.google.com/app/25a16b91c2a7ba54                                                           9/10
11/22/26, 4:05 PM                                 See attached instructions




                                                                              Changes what is
     Status         Point
                                                                              built or run?

              Finding 5 · D321 (CS2.1 draft): "where a listing ends...
                                                                              No (criteria text
     Disputed never on later prices" is false under D306's backdated
                                                                              only)
              delisting; must state price-independent delisting proviso
              Finding 6 · D318 & D314: sequential locked                      Yes
              ingest/hl.py runs reset the 300/min window; Test 21 /           (ingest/hl.py
     Disputed VAULT.md Test 7 "whatever follows it" on overflowing            lockfile budget
              Content-Length may contradict D314's deletion of                state; Test 21 / Test
              header checks                                                   7 fixture)




https://gemini.google.com/app/25a16b91c2a7ba54                                                        10/10
```
