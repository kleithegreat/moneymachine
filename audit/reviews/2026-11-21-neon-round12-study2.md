# Neon on round 12's study 2 half (D250 to D261)

Model Gemini 4 Neon, through the Gemini web UI (the human pasted the bundle neon-r12-study2-bundle.md (rearchitecture-s2 f67812b) and its prompt from `~/Downloads`, and saved the reply as a PDF, 2026-11-21 23:21 to 23:25 UTC (18:21 to 18:25 EST)). Neon did not author round 12. The 381 KB bundle arrived whole. The reply, as extracted from the PDF by `pdftotext -layout` (page headers and footers kept):

```text
11/21/26, 6:25 PM                                          See attached instructions.



    See attached instructions.
    https://gemini.google.com/app/68dcd38cd20d616c

    User prompt: See attached instructions.
    Response: Round 12 (study 2 half) is not converged. The core move—reading coverage
    directly from pinned bytes rather than host-clock or clean-stream proxies—is the right direction,
    and several items are ready to accept (detailed with the full ledger in Part 2). However, three of
    the round's load-bearing mechanisms (D258's stake filter, D255's quote-gating rule, and D250's
    horizon) break under concrete constructions that change CS2.1–CS2.3 verdicts, and three
    further defects remain in the drafted criteria revisions, the recorder specs/build plan, and
    State_0 reporting.

    1. D258's stake-eligibility formula is algebraically wrong for the stake rule
    and still lets routine funding end the ledger
            What it breaks: D258's claim that φ ∈ {1/16, 1/8} selects "those whose stake no
            settlement can end" (leaving cash for a 4% capped hour with all 17 coins at depth via (1 −
            φ)^17 ≥ 1/26) and keeps the ledger alive through CS2.2's 212 days.

            Derivation and construction: The factor (1 − φ)^17 holds only if each of the 17 cycles
            spends its entire depth d sequentially before the next cycle opens (or if d = 100, where
            the first buy is the entire depth). Under architecture.md 6.1 ("Nothing is set aside"), each
            cycle fixes its scale at its first buy ($100) from the cash then available, spending only
            fraction r = 100/d of its committed depth (3.62% at d = 2,763, 50.5% at d = 198).
            When m coins enter during a correlated dip before descending their ladders (zero fees;
            positive fees reduce cash further), coin i observes cash (1 − φr)i−1 and commits notional
            φ(1 − φr)i−1 , for a total committed spend of:
                                                 m
                                                                            1 − (1 − φr)m
                                   S(m, φ, r) = ∑ φ(1 − φr)
                                                       ​
                                                                    i−1
                                                                          =               .
                                                                                          ​




                                                 i=1
                                                                                   r

            Evaluating the 12 "eligible" pairs (φ ∈ {1/16, 1/8}, d ∈ {100, 198, 384, 745,
            1439, 2763}):

                    At φ = 1/8, every depth d > 100 (5 of 6 depths) over-commits cash: at d =
                    2,763, S(17) = 2.05—and even m = 9 coins give S(9) = 1.105 > 1; at d = 198
                    (just one ladder level deep), S(17) = 1.327 > 1 (and m = 11 gives 1.014 > 1).

                    At φ = 1/16, d = 2,763 gives S(17) = 1.044 > 1 and d = 1,439 gives S(17) =
                    1.026 > 1; d = 745 gives S(17) = 0.994, leaving only 0.59% of starting cash
                    (nearly 7× less than one 4% capped hour's 3.98%).


https://gemini.google.com/app/68dcd38cd20d616c                                                             1/11
11/21/26, 6:25 PM                                         See attached instructions.


                    Only 4 of the 12 pairs (d = 100 at φ = 1/8; d ≤ 384 at φ = 1/16) even survive one
                    capped hour at entry prices under simultaneous entries. In 7 of the 12 eligible pairs,
                    a correlated dip drives cash to literally zero on buys alone ("every buy is cut to the
                    cash there is"), after which any routine positive funding rate (e.g., 0.0001%, not a
                    4% cap) immediately terminates the ledger.
                    Moreover, even for the 4 surviving pairs, funding is charged at current prices (not
                    entry prices) across every hour a cycle stays open (up to 254 hours in the vault's
                    history, or during a stale gap when take-profits cannot fill), so "no settlement can end"
                    fails there too.
            Outcome changed: Step 5's survival-conditioned bootstrap still cannot generate a cash-
            exhaustion path if the replay lacked a correlated deep dip, so Step 5 can select an eligible-
            but-fragile pair (e.g., φ = 1/8, d = 1,439 or φ = 1/16, d = 2,763). When that ledger
            ends on a forward correlated dip + routine positive funding before Day 212, CS2.2 flips to
            "not judged" and later CS2.1 crossings are lost.

            Defect type: Design defect—and a patch rather than a fix at the cause. Filtering φ with a
            sequential-cycle formula leaves the underlying cause untouched: buys are allowed to
            spend the ledger down to zero cash. Under law K1 ("every scale that is not negative and is
            fixed before the buy it scales is valid"), capping each buy's spend to preserve a cash buffer
            (analogous to the guard's 1/25 reserve) attacks the cause directly without eliminating deep
            ladders.

    2. D255 reconstructs cross-file trades liveness from a non-monotonic wall
    clock (recv) that RECORDER.md explicitly allows to step backwards
            What it breaks: D255's forward reader rule gating a coin's quotes on trades subscription
            liveness by comparing recv timestamps across separate files (events, trades, l2Book-
            fast) of one run. RECORDER.md explicitly recognizes that the host wall clock (recv) can
            step backwards mid-run (Storage: "a clock stepping back never reopens a closed file";
            Compression: monotonic flush timer; Test 4: "with the wall clock stepped back an hour
            between two flushes").
            Constructions (all using RECORDER.md Test 4's backward clock step):
                    False live (restores GPT-6.2 Finding 7): On connection k, BTC trades is
                    subscribed at recv = 10:00:01 and close/error occurs at 10:10:00. At
                    10:10:05, NTP steps the wall clock back 1 hour to 09:10:05. Connection k reopens
                    at 09:10:10; BTC l2Book-fast is acknowledged, while BTC trades is never
                    acknowledged (dead). During true 11:00:01–11:10:00, quotes arrive with recv
                    ∈ [10:00:01, 10:10:00]—falling inside the earlier live interval [10:00:01,
                    10:10:00]. D255 feeds 10 minutes of BTC quotes while its trades channel is dead.




https://gemini.google.com/app/68dcd38cd20d616c                                                                  2/11
11/21/26, 6:25 PM                                             See attached instructions.


                    False dead (suppresses valid trading): On connection k, BTC trades is
                    subscribed at recv = 10:00:01. At 10:05:00, the wall clock steps back 1 hour
                    to 09:05:00. For the next 55 minutes (recv ∈ [09:05:00, 10:00:00]), both
                    channels are healthy and streaming, yet recv < 10:00:01 causes D255 to drop 55
                    minutes of valid BTC quotes, forcing BTC stale and blocking fills and exits. (Likewise,
                    a small backward step right after a reconnect places the prior close after the new
                    subscribed in recv order, killing the new healthy stretch.)

                    Retroactive prefix divergence: If a backward wall-clock step exceeding the
                    capture margin (e.g., >12 h) occurs after Capture_1, followed by a close/error,
                    that event carries recv < T_1. On Capture_2, the new close retroactively
                    terminates the live stretch before T_1, dropping quotes that Capture_1 fed and
                    terminating the study at T ∗ < T1 .   ​




                    Two accompanying spec defects in D255: (a) brief 4 Step 7's file-skip rule skips
                    recorder stream channels before w_start − 24 h and explicitly exempts only
                    listings, settled/funding, and mmvault—omitting events (where a long-lived
                    run like the live recorder started 2026-11-14 recorded its subscribed events) and
                    skipping pre-w_start − 24 h trades files that could otherwise serve as print-
                    openers; (b) "from the first line ... to the first of ..." literally defines a single interval per
                    (run, conn, coin) rather than one per reconnect session.

            Outcome changed: Feeds quotes under a dead trades stream (missed resting fills/exits)
            or drops quotes under a healthy stream (false staleness), altering positions, W, Wᵇ, and entry
            counts—changing CS2.1, CS2.2, and CS2.3 verdicts—or ending the study early via
            retroactive prefix divergence.
            Defect type: Design defect. D255 re-introduced a host wall clock into causal ordering
            across independently written files. Fixing it at the cause requires mmrec to stamp a
            monotonic per-run sequence number (or a per-connection monotonically incremented
            session id on every open, written into every events, trades, and l2Book-fast line), so
            cross-file liveness never reads wall-clock recv.

    3. D250's single-line recorder witness allows one wild l2Book-fast
    timestamp to leap the horizon arbitrarily far past a stopped recorder
            What it breaks: D250's Clause 2 (Capture_k holds a single l2Book-fast line of one
            universe coin—"of any book, one-sided or empty"—with time ∈ [T + 1 h, T + 25 h)).
            Specifically, it refutes brief 4 Step 7's claims that a wild quote moves T by no day while
            funding does not, poisons no later capture (Test 10), and carries T "at most a day past the
            stop" (Wall 3).
            Construction A (single wild timestamp overshooting a stopped recorder):
                    mmrec records cleanly through Day 150, then stops permanently (hardware failure or
                    stopped process), while REST mmvault funding continues running normally.
https://gemini.google.com/app/68dcd38cd20d616c                                                                           3/11
11/21/26, 6:25 PM                                         See attached instructions.


                    On Day 150, before stopping, a single corrupted l2Book-fast frame on one universe
                    coin (even an empty or crossed book) arrives with time = Day 215 02:00:00
                    UTC (65 days ahead, inside the two-year window).

                    At Capture_6 (Day 180) and Capture_7 (Day 210), funding has not reached Day 215,
                    so T holds at Day 150.
                    At Capture_8 (Day 240), real funding has passed Day 215. Now for T = Day 215
                    00:00 UTC: Clause 1 holds (every listed coin has real settled funding in [Day 215
                    01:00, Day 216 01:00)), and Clause 2 holds (the single Day-150 wild line lies in
                    [Day 215 01:00, Day 216 01:00)).

                    T_8 leaps 65 days past the recorder's stop to Day 215. Worse, because Day 215
                    02:00 ≥ T_8, that wild line lies outside [w_start, T_8) and is never fed to or
                    validated by engine admission in Capture_8 or any subsequent capture.
            Construction B (let-go rule still admits premature advancement on a single short
            pull):
                    D250 defends the let-go rule by noting "a capture interval holds about thirty such
                    asks". That premise fails in two permitted regimes:
                       1. Delayed capture: If Capture_k is delayed (e.g., by the release wait or a capture
                          write retry) until the last day of a month (say Feb 28 23:00 UTC),
                          Capture_{k+1} fires on Mar 1 12:00 UTC—only 13 hours later, with one daily
                          funding pull between them. If a newly delisted coin receives a short/empty
                          page on that pull and the monthly pull fails or times out (permitted by D251),
                          Capture_{k+1} lets it go after a single ask.

                       2. Capture_1 against State_0: State_0 starts with count = 0, pulls = 0.
                          If w_start falls shortly before the first monthly firing (e.g., Jan 30 → Feb 1), a
                          coin delisted on Day 1 whose single pull returns [] has count = 0 ==
                          State_0.count and pulls = 1 > 0, letting it go on Capture_1 with zero
                          funding rows—aborting any run holding it on Day 1 and ending the study at
                          w_start.

            Outcome changed:
                    Construction A flips CS2.2 from "not judged" (a 150-day record) to a judged
                    verdict ("did not hold" or "held") computed across 62 phantom stale days of a
                    dead recorder; identically, a Day-40 stop with a single wild line stamped Day 65
                    02:00 flips CS2.3 from "not judged" to "not shown" (25 dead days of zero
                    replica entries against an active vault).
                    Construction B restores GPT's round 9 Dispute 1 (aborting on a held delisted coin's
                    missing funding hours and losing all subsequent CS2.1–CS2.3 evidence).


https://gemini.google.com/app/68dcd38cd20d616c                                                                 4/11
11/21/26, 6:25 PM                                       See attached instructions.


            Defect type: Design defect. Removing D221's multi-coin quorum and valid-book check
            without replacing them with any cross-coin or per-day continuity check re-opened single-
            line horizon poisoning on a stopped recorder; and counting "≥ 1 completed pull
            since Capture_{k-1}" does not enforce the ~30-pull wait the derivation assumes.

    CONTINUE



    User prompt: continue

    Response: 4. D254's vault-fill coverage union is defeated by a collector
    clock just > 1 hour ahead, well inside its stated 1-day margin
            What it breaks: D254's claim that taking the union of completed pull files' [startTime,
            endTime] ranges over [w_start, w_start + 62 d] certifies vault-fill coverage for
            CS2.3 while absorbing a collector clock up to one day ahead.
            Construction:
                    mmvault's host clock runs 12 hours ahead of true UTC (host_now = true_utc +
                    12 h)—half of the 1-day margin brief 4 Step 7 and CS2.3's drafted revision claim
                    to tolerate.
                    Under VAULT.md One run, step 1, each hourly pull requests [watermark − 1 h,
                    host_now] and updates watermark := host_now. Once running hourly, every pull
                    requests [host_now − 2 h, host_now], which in venue time is [true_now +
                    10 h, true_now + 12 h]—strictly in the future. Hyperliquid returns [] (under
                    the 2,000 cap, vacuously passing the page check), so mmvault atomically commits
                    the file to fills/ and advances watermark.
                    At host Day 61 00:07 (true Day 60 12:07), step 2's 30-day daily re-read
                    succeeds and commits [Day 31 00:07, Day 61 00:07], fetching fills only
                    through true Day 60 12:07.
                    Over the next 24 hours (true Day 60 12:07 to true Day 61 12:07), all 24 hourly
                    pulls ask 10–12 hours into the future, receive [], and commit cleanly.
                    At host Day 62 00:07 (true Day 61 12:07), step 1's hourly pull [Day 61 22:07,
                    Day 62 00:07] commits first; then step 2's daily re-read fails (HTTP 500, timeout,
                    or kill) or has not yet finished when Capture_k runs.
                    In Capture_k, the union of [startTime, endTime] across completed files in
                    fills/ covers [w_start, w_start + 62 d] completely. Yet zero fills from
                    true [Day 60 12:07, Day 61 00:00) (nearly 12 hours of Day 61) were ever
                    fetched by any pull executed after they occurred. (Any skew > 2 h produces the

https://gemini.google.com/app/68dcd38cd20d616c                                                           5/11
11/21/26, 6:25 PM                                         See attached instructions.


                    same blind spot for the full skew duration, and if daily re-reads fail repeatedly while
                    tiny empty hourly pulls keep succeeding, the union can certify days or weeks of zero
                    fetched fills.)
                    If the vault opened and closed round trips during those 12 hours (flat before and
                    after), every stored fill chains cleanly, Capture_k passes D254's coverage check,
                    and CS2.3 locks in its permanent verdict on a truncated vault record.
            Outcome changed: CS2.3 flips between "met" and "not shown" depending on
            whether the missing suffix held matched or unmatched round trips—restoring GPT-6.2
            Finding 6 inside the spec's own clock-skew envelope.
            Defect type: Design defect. Adding 1 day to the right endpoint of the union (w_start +
            62 d) only protects a single pull covering the full span; it does not protect a union of short
            hourly pulls whose own endTime is read from a skewed host clock. Each individual
            completed pull file [startTime, endTime] can only certify [startTime, endTime −
            M] under a maximum clock-ahead bound M (1 day), so hourly pulls certify nothing and only
            pulls wider than M (such as the 30-day daily re-read) contribute coverage to the union.

    5. D253 and D260's drafted criteria revisions turn the human's stop into an
    outcome-censoring lever and break cross-condition consistency on prefix
    divergence
            What it breaks: The drafted revisions to CS2.1, CS2.2, and CS2.3 (architect-r12-s2-
            report.md Item 3), specifically CS2.1's claim that "each end above can only withdraw a
            non-final 'Earned' or leave a condition not judged" and CS2.3's handling of prefix
            divergence.
            Constructions:
                    Discretionary stop censors failing controls and shields "Earned": Every monthly
                    replay publishes W, its running volatility, Layer 2 vault fills, and whether CS2.1 has
                    crossed 20. Suppose CS2.1 reaches non-final "Earned" on Day 90 (rung 2
                    registered, not yet reached), and by Day 150 W's realized variance is already 5× the
                    replay's—heading for CS2.2 "the volatility did not hold" at Day 212. Under
                    the drafted CS2.1 and CS2.2 revisions, "the human may stop the test by a dated
                    decision, which ends it at the last published day with the same effect." Stopping at
                    Day 150: (1) turns an observed imminent CS2.2 failure into "not judged" (and
                    likewise for CS2.3 before Day 61/coverage), and (2) locks in the Day-90 "Earned" as
                    final, shielding it from withdrawal by any later prefix divergence (a late funding row or
                    quote arriving behind Day 90 in a later month). This is an unblinded optional-stopping
                    lever, not a conservative rule.
                    Prefix divergence breaks CS2.3 in both directions:



https://gemini.google.com/app/68dcd38cd20d616c                                                                  6/11
11/21/26, 6:25 PM                                         See attached instructions.


                       1. False standing verdict: Capture_3 (Day 90) has full vault coverage and judges
                          CS2.3 = "met". Capture_4 (Day 120) hits a prefix divergence on Day 10 (T ∗ =
                          9). Under CS2.1's drafted revision, the study ends at T ∗ = 9 (with Days 10–61—
                          the very replica entries CS2.3 matched—invalidated), yet CS2.3's "met" stands
                          alongside a 9-day study, contradicting CS2.3's unamended "Not judged when
                          fewer than 61 judged days were run."
                       2. Unnecessary loss of a valid judgment: Capture_3 (Day 90) defers CS2.3
                          because vault pulls stopped at Day 55. Capture_4 (Day 120) restores complete
                          vault coverage over [w_start, w_start + 62 d], and receives a late
                          market row on Day 80 (T ∗ = 79 ≥ 61). Because Capture_4 hits
                          terminal_action = end_study ("publishes nothing"), CS2.3 is forced
                          to "not judged" even though Days 1–61 reproduced byte-for-byte and vault
                          coverage is complete.
            Outcome changed: CS2.1, CS2.2, and CS2.3 verdicts—either shielding "Earned" while
            censoring CS2.2/CS2.3 failures via an unblinded administrative stop, or losing/preserving
            CS2.3 inconsistently around T ∗ .

            Defect type: Design defect in the criteria revisions (D253/D260). A discretionary stop
            made after inspecting intermediate forward reports cannot be treated as equivalent to a
            mechanical last firing; if permitted for budget reasons, it must be tagged as an unblinded
            administrative abort (or forfeit non-final "Earned"). For CS2.3, judging on Capture_k
            when T ∗ ≥ 61 and vault coverage holds closes the Day-80 loss, while CS2.3's drafted
            revision must explicitly state how it interacts with a later T ∗ < 61.

    6. D261 (RECORDER.md, VAULT.md, and the 9-step build plan) and D256 leave
    concrete data-loss, crash, and authentication gaps
            What it breaks: D261's claim that all ten findings of GPT-6.2's recorder audit are closed by
            the revised specs and build plan, and D256's report-level authentication of State_0.
            Constructions:
                    Storing failed-read and partial meta responses into listings/ (D261 + Kernel
                    Change #2): RECORDER.md What it records, item 1 specifies that on a failed listings
                    read, "Responses that are whole are stored as received either way", and validates
                    meta only as a non-empty universe of objects with string name (neither checking
                    szDecimals/marginTables nor rejecting a truncated universe, and accepting
                    perpDexs = [null], which delists every HIP-3 perp). Kernel Change #2 then
                    instructs the forward reader to treat any stored meta line matching that weak shape
                    check as a valid main-dex copy and delist any absent coin. Thus a single partial
                    main-dex meta (e.g., {"universe": [{"name": "BTC"}]}) received during an
                    otherwise failed listings read is still written to listings/, ignored by live mmrec, and
                    then delists the other 16 universe coins inside the forward replay (ending the

https://gemini.google.com/app/68dcd38cd20d616c                                                                 7/11
11/21/26, 6:25 PM                                          See attached instructions.


                    study on their next event via A3), or rejects the record if
                    szDecimals/marginTables are absent.

                    Build Plan Step 3 introduces a live crash bug in route.ml: RECORDER.md
                    Implementation correctly permits catching both Yojson.Json_error and
                    Yojson.Safe.Util.Type_error, yet Build Plan Step 3 restricts route.ml to
                    catching Yojson.Json_error alone and requires a test that any other exception
                    propagates. Any valid non-object JSON server frame ([], null, "ok", 123) causes
                    Yojson.Safe.Util.member to raise Yojson.Safe.Util.Type_error,
                    propagating uncaught out of route.ml and killing the connection or process.
                    Build Plan ordering deploys four restarts before fixing the SIGTERM shutdown
                    bug: Steps 1–4 are deployed to the live ws StatefulSet before Step 5 fixes SIGTERM
                    shutdown (which currently drops the frame reader without joining and writes stop
                    before closing channel files, audit Finding 9). Every deployment restart across Steps
                    1–4 therefore exercises the exact live-data-loss bug Step 5 exists to eliminate.
                    Two boundary edge cases in VAULT.md (D252/D261): (1) On a backward host-
                    clock step exceeding the 1-hour overlap, startTime = watermark − 1 h >
                    endTime = now; VAULT.md does not guard startTime <= endTime, so []
                    completes the pull and moves watermark backwards. (2) Under D252's exclusive
                    mmvault funding pagination (start = last_time + 1), if a gap span [H_a,
                    H_b] has an exact multiple of 500 rows and the 500th row is stamped at H_b +
                    3,599,999 == endTime, the next request sends startTime > endTime—which
                    stalls gap backfill permanently if the API returns HTTP 400 (fix: also stop gap
                    pagination when last_time == endTime).
                    State_0 report omission (D256): brief 4 Step 6 specifies that every report prints
                    commit_id and w_start, omitting registration_sha256. A deployment that
                    substitutes State_0 on disk—keeping the real commit_id and w_start while
                    swapping registration_sha256 to a forged registration file (same build and
                    program hashes, altered φ or replay_variance)—passes both hosts and prints the
                    exact expected commit_id and w_start in every report, hiding the substitution
                    from anyone auditing reports against the remote.
            Outcome changed: Lost live recordings (SIGTERM drops during Steps 1–4 deploys,
            route.ml crash on non-object JSON, perpDexs = [null] unsubscribing all HIP-3
            markets), spurious study termination (failed-read meta written to listings/ delisting
            universe coins in replay; 500-hour funding gap stalling on startTime > endTime), and
            undetected registration substitution changing CS2.1/CS2.2.
            Defect type: Design/spec defects in RECORDER.md, Kernel Change #2, VAULT.md, and
            the build plan; text/reporting defect in D256 (add registration_sha256 to every
            report alongside commit_id and w_start).



https://gemini.google.com/app/68dcd38cd20d616c                                                              8/11
11/21/26, 6:25 PM                                      See attached instructions.


    What I accept
            D251 (nothing before a capture refuses): Falling back to raw pins on packer
            failure/disagreement and capturing after a failed monthly funding pull closes GPT's round
            9 Dispute 5 cleanly without adding an outcome lever (corrupt raw files still settle
            deterministically post-capture).
            D252 (exclusive mmvault funding pages): Moving from inclusive to last_time + 1
            closes GPT's round 9 Dispute 4 within a pull (modulo the last_time == endTime stop
            guard noted in Finding 6).
            D257 (months held back as a development set) and D259 (narrowed study claim):
            Both are honest concessions matching what the architecture actually establishes; no
            design break remains in either.
            D258's Brownian reference power arithmetic: The reproduced figures (0.2754/0.7831
            continuous and 0.2676/0.7763 daily at σ = 1 over 730 days; 0.0003/0.0037 over 187
            days) and the retraction of the generic Kelly headline are sound; only the stake-eligibility
            formula is broken (Finding 1).
            D250's deletion of R_HORIZON_REGRESSION and host-clock listing times: Removing
            host-clock listing timestamps from T and taking max(T_prev, T_raw) eliminates GPT's
            round 9 Dispute 2 cleanly, even though Clause 2 and the let-go rule still break (Finding 3).
            D261's core fixes in RECORDER.md and VAULT.md: Atomic per-pull staging in mmvault,
            page range/order checks, (coin, tid, oid) alarms, funding resume from last pull,
            unacked deadline semantics, active subscription retries, mmrec check whole-gap and
            subgap reporting, HTTP Content-Length/chunked-trailer checks, and the monotonic
            flush clock all address their audit findings at the cause (modulo Finding 4 and Finding 6's
            specific gaps).

    Ledger
                                                                                    Changes what is built or
      Status          Point
                                                                                    run?

                      D251 pre-capture fallback (raw pin on packer
      Agreed                                                                        No
                      failure, capture after failed monthly pull)
                      D252 exclusive funding pagination (with
      Agreed                                                                        Minor guard in VAULT.md
                      last_time == endTime stop guard)

                      D257 held-back months as development set; D259
      Agreed                                                                        No
                      narrowed positive-control claim

https://gemini.google.com/app/68dcd38cd20d616c                                                                 9/11
11/21/26, 6:25 PM                                       See attached instructions.



                                                                                     Changes what is built or
      Status          Point
                                                                                     run?

                      D258 Brownian reference power calculation and
      Agreed                                                                         No
                      retraction of generic Kelly headline
                      D250 removal of R_HORIZON_REGRESSION and
      Agreed                                                                         No
                      listing host-clock timestamps from horizon
                      D261 core recorder fixes (atomic staging, HTTP
      Agreed          completeness, unacked/retry, check gaps,                       No (except items below)
                      monotonic flush)
               Finding 1 (D258): (1 − φ)^17 ≥ 1/26 fails for
                                                                                     Yes (stake/cash-buffer
      Disputed simultaneous entries; 7 of 12 eligible pairs hit zero
                                                                                     rule in Step 5 / ledger)
               cash on buys alone
               Finding 2 (D255): Cross-file trades liveness uses
                                                                                     Yes (monotonic
               non-monotonic wall-clock recv (plus events
      Disputed                                                                       sequence/session id in
               skipped before w_start − 24 h and single-
                                                                                     mmrec and frozen reader)
               interval wording)
               Finding 3 (D250): Single unvalidated l2Book-
                                                                                     Yes (Clause 2 witness &
               fast line lets one wild timestamp leap T arbitrarily
      Disputed                                                                       let-go threshold in study2
               far past a stopped recorder; let-go rule fires on a
                                                                                     forward)
               single short pull
               Finding 4 (D254): Union of hourly [startTime,                         Yes (per-pull endTime −
      Disputed endTime] ranges certifies coverage under a clock >                    M coverage rule in study2
               1 h ahead while fetching zero fills                                   forward / VAULT.md)

               Finding 5 (D253/D260): Human's discretionary                          Yes (criteria revisions &
               stop censors CS2.2/CS2.3 failures and shields non-                    study2 forward
      Disputed final "Earned"; CS2.3 prefix-divergence handling
                                                                                     CS2.3/end_study
               contradicts T ∗ in both directions                                    handling)

               Finding 6 (D261/D256): Failed-read/partial meta
               written to listings/ delists universe coins in                        Yes (RECORDER.md, Kernel
               replay; Step 3 route.ml handler crashes on non-                       Change #2, Build Plan
      Disputed
               object JSON; Build Plan deploys Steps 1–4 before                      order/Step 3, VAULT.md
               Step 5 SIGTERM fix; State_0's                                         bounds, study2 report)
               registration_sha256 omitted from reports


    Convergence: Not converged. All six disputed items directly change what is built, deployed, or
    judged under CS2.1–CS2.3.

https://gemini.google.com/app/68dcd38cd20d616c                                                                    10/11
11/21/26, 6:25 PM                                See attached instructions.




https://gemini.google.com/app/68dcd38cd20d616c                                11/11
```
