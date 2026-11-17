# Argon on the architect's rounds 5 and 6 (D194 to D204)

Model Gemini 4 Argon in the Gemini web UI, given the self-contained bundle `argon-last-pass-r5r6.md` (618 KB, 14 files, built from `rearchitecture` `57ce8b9`), in two parts. Saved by the human as a PDF on 2026-11-17. Converted with pdftotext, with page furniture and stray characters removed. The text is otherwise verbatim.


     See attached instructions
     https://gemini.google.com/app/ba7744af4abaf0b8

     User prompt: See attached instructions

     Response: 1. Attack on D202 (Two Hosts per Attempt)
     Finding 1.1 — Comparing only forward-run rows leaves abort summaries, confirm/held,
     and CS2.3's vault-fill replay and matching exposed to single-host or unpinned-input faults

             What it breaks: D202 ("Every attempt runs on two hosts, and its rows are those both give,
             byte for byte", "What a single host's fault can do: nothing published") and A13's attempt
             identity.
             Concrete construction: Three gaps arise if two-host validation compares only mm2's
             forward-run report and trace rows on the market files hashed in A13:
                    1. Vacuous agreement on empty rows when two hosts abort differently: By C2 and
                       A19, a run that rejects or aborts writes no report and no trace (finish returns
                       {"error": code, "time": t, "detail": text}). Suppose on day 80 the true
                       record has a crossing ("outgrew"), but Host 1 has a transient fault on day 50 and
                       aborts, while Host 2 completes day 80. They disagree, so Host 3 runs; if Host 3
                       aborts at start (e.g., E_FPENV or a mount error), both Host 1 and Host 3 produce
                       empty report and trace files. Unless two-host agreement compares finish's
                       summary JSON (including error and abort time, rounded down to the last midnight)
                       alongside the rows, two aborting hosts agree on empty rows and trigger CS2.1's
                       truncated rerun, missing the crossing or ending the test early.
                    2. Single-host execution of confirm, held, or CS2.3's vault-fill replay and
                       bipartite matching: In Study 2, mm2 writes the forward run's report and trace,
                       after which confirm computes W, Wᵇ, B̄, and the CS2.1 verdict, held computes
                       CS2.2's 212-day variance ratio, and at the first replay completing day 61 the runner
                       replays the vault's fills and runs CS2.3's bipartite matcher (plus the optimistic
                       diagnostic run). If two-host comparison checks only mm2's forward-run rows and runs
                       confirm, held, or CS2.3's vault replay and matching once on the coordinator host, a
                       single-host fault during that post-processing step still fixes an irreversible false
                       "outgrew" or a wrong once-only CS2.2 or CS2.3 verdict.
                    3. Unpinned mmvault files across hosts during CS2.3's judging attempt: By A13, a
                       forward run's identity hashes "the market's every file to the length the run reads it to",
                       and D194 Rule 6 notes that the vault's fills (mmvault and the pre-2026-11-01 copy)
                       "are no input of the forward run". Because a forward replay takes hours while
                       mmvault pulls hourly, if the attempt identity at the start of the day-61 replay does not
                       also record the byte lengths and SHA-256 hashes of mmvault's files (and the old

11/17/26, 4:31 PM                                                See attached instructions

                      copy) for both hosts to read and verify, Host 1 and Host 2 can read different mmvault
                      snapshots or judge CS2.3 on a single host.
             Outcome it could change: Fixes an irreversible false CS2.1 "outgrew", a wrong once-only
             CS2.2 or CS2.3 verdict, or a false early end.
             Classification: Design/specification defect (specify that the attempt snapshot pins
             mmvault's file lengths and hashes as well, and that two-host byte-for-byte agreement
             covers finish's summary JSON, confirm's and held's outputs, and CS2.3's vault-fill
             replay and matching).

     Finding 1.2 — Ambiguity between a single-host crash/kill (D200) and a host disagreement
     (D202), and stalling on a two-host list

             What it breaks: D200 ("a killed attempt produced nothing, so the next attempt reads the
             files as they are when it starts") against D202 ("A host fault is a wrong computation of a
             reading the comparator made, so it gets no new reading... Where the two differ, the same
             identity runs on the next host of a fixed list, until two hosts agree") and the Round 6
             report's request for "at least two hosts".
             Concrete construction:
                    1. Single-host crash/kill vs. wrong output: Suppose at the 12:00 UTC firing, the pull
                       completes and the attempt starts on Host 1 and Host 2 with identity I12:00 . Host 1
                                                                                                     

                       finishes cleanly, but Host 2 is killed by OOM, loses power, aborts with E_FPENV, or
                       fails a file-hash check before writing its result row. If Host 2's non-completion causes
                       the attempt to be classified as a "killed attempt" under D200 rather than advancing
                       to Host 3 on the same identity I12:00 under D202, the runner discards I12:00 and
                                                                                                        

                       waits for the next hourly timer firing to pull and capture a new identity Ilater . A single
                                                                                                             

                       host crashing (or being killed) then moves the reading time, whereas D202 requires
                       resolving a single-host fault on the same identity I12:00 . An attempt is only "killed" in
                                                                                             

                       D200's sense if the attempt is aborted before its identity is committed or before any
                       host can read the pinned snapshot.
                    2. A fixed list of only two hosts cannot resolve a single-host fault without human
                       intervention: The Round 6 report asks the advisor for "a host list for step 7, at least
                       two hosts that can read the recorder's volume", and D202 states: "Where none agree,
                       nothing is published and the runs go to the architect". If the fixed list has only two
                       hosts and one host suffers a single bit-flip, no third host exists to break the tie; the
                       attempt halts for the architect, reintroducing manual timing discretion (or ending the
                       test if unresolved). Automatic resolution of a single faulty host requires at least three
                       hosts in the fixed list (or one retry on the same identity before escalating).
                    3. Truncated rerun after a two-host agreed abort: Under CS2.1, when a replay rejects
                       or aborts at time t, "the replay is run again to the last midnight at or before that time".

11/17/26, 4:31 PM                                         See attached instructions

                    To match D202 and D194's answer to GPT 1, when two hosts agree on an engine
                    rejection or abort at t, that truncated rerun to the last midnight ≤ t must run
                    immediately on the same captured file lengths and hashes on two hosts, publish
                    through that midnight, and mark the test ended there—not wait for the next hourly
                    timer firing to take a new pull and snapshot.
             Outcome it could change: Shifts the snapshot reading time upon a single-host crash,
             stalls a replay on a two-host list, or allows a later hourly firing to run past an abort that the
             committed replay met.
             Classification: Text/specification defect in Step 7 Wall 3 (treat any single-host crash, kill,
             or E_FPENV after the identity is recorded by running the next host on the same identity;
             require at least three hosts in the list or a bounded retry on the same identity; and run
             CS2.1's post-abort truncated replay immediately on the same pinned file lengths on two
             hosts).

     Common-Mode Faults Not Excluded by D202

     D202 explicitly states its trust boundary ("two hosts that err alike"). The remaining common-
     mode surfaces are:
             Single shared storage volume and snapshot coordinator: Both hosts read one recorder
             volume ("no second copy of the record"). Pre-hash disk corruption, a writer bug, or a fault
             on the host that records the attempt's lengths and hashes affects both hosts identically.
             Shared software stack: Both hosts execute the same Nix derivation (Lean/C code,
             OCaml readers, DuckDB 1.5.2, mmrec cat), so any deterministic bug in the unverified
             boundary errs identically on both hosts.

     2. Attack on X5 and D203 (nearestBits and Law X4)
     Verification of X5's Statement, Proof Outline, and Engine Binding

         1. X5's statement as a characterization of IEEE 754 roundTiesToEven over Q:
            Assuming Engine.Exact.decode is IEEE 754's binary64 decoder (returning some 0 on
            both +0 and -0, some w on every other finite bit pattern, and none when the biased
            exponent is 2047) and infBits = 0x7FF0000000000000, theorem X5 uniquely
            determines Engine.Exact.nearestBits q for every q : Rat and matches IEEE 754
            (§4.3.1):
                    Signed zero and underflow: At q = 0, nearestBits 0 = 0 (+0). For 0 < |q| <
                    2⁻¹⁰⁷⁵, the unique nearest decoded rational is v = 0 (and at the tie |q| = 2⁻¹⁰⁷⁵
                    between 0 and ±2⁻¹⁰⁷⁴, 0 has LSB 0 while ±2⁻¹⁰⁷⁴ has LSB 1). Because decode b
                    = some 0 holds only for b = 0 (+0) and b = 2^63 (-0), the sign clause 2^63 ≤
                    (nearestBits q).toNat ↔ q < 0 uniquely forces -0 (0x8000000000000000)

11/17/26, 4:31 PM                                        See attached instructions

                    for q ∈ [-2⁻¹⁰⁷⁵, 0) and +0 (0x0000000000000000) for q ∈ (0, 2⁻¹⁰⁷⁵].
                    Crucially, fixing D203's -0 defect makes the preimage of every b : UInt64 under
                    nearestBits a convex interval in Q (under the old +0 behavior, -2⁻¹⁰⁷⁶ and
                    +2⁻¹⁰⁷⁶ both mapped to +0 while straddling negative rationals that map to -0).

                    Subnormals, normal boundaries, and ties: For q ≠ 0 below the overflow threshold,
                    0 is itself representable, so no tie ever straddles 0. Every midpoint between adjacent
                    finite binary64 values—within subnormals, at the greatest-subnormal/least-normal
                    boundary (253 − 1)2−1075 , within a normal binade, or at a binade boundary (253 −
                    1)2e−52 —pairs one encoding with LSB 0 and one with LSB 1, so w ≠ v →
                    (nearestBits q).toNat % 2 = 0 uniquely selects the even neighbor.

                    Overflow: The midpoint between the greatest finite binary64 (2 − 2−52 )21023 and
                    the phantom even value 21024 is (2 − 2−53 )21023 . At or above this magnitude, the
                    second conjunct plus the sign conjunct uniquely forces +∞ (0x7FF0000000000000)
                    for q > 0 and -∞ (0xFFF0000000000000) for q < 0.
         2. Brief 3's proof outline (Step 5, Wall 11): The outline is mathematically sound, with two
            details the Lean proof must handle explicitly:
                    Strict inequality below 2e for the tie clause: For e = ilog2 ∣q∣ > −1022, the
                                                                                             

                    greatest finite binary64 below 2e is wmax = 2e − 2e−53 = 2e − 12 step. To establish
                                                                                                

                    X5's tie clause ((w - q)^2 = (v - q)^2 → w ≠ v → ...), the proof needs that
                    wmax is never a tie with v : when ∣q∣ = 2e , ∣v − q∣ = 0 < 12 step = ∣wmax − q∣, and
                                                                                                   

                    when ∣q∣ > 2e , ∣wmax − q∣ = (∣q∣ − 2e ) + 12 step > 12 step ≥ ∣v − q∣ (or note that
                                                                                   

                    for ∣q∣ ∈ [2e , 2e + 12 step], v = 2e already has even LSB 0).
                                                 

                    Carry at the top of a binade (m = 253 ): When ∣q∣ ∈ [2e+1 − 2e−53 , 2e+1 ),
                    roundHalfEven rounds m up to 253 (or 252 at the subnormal-to-normal boundary),
                    which increments the biased exponent and sets the 52-bit significand field to 0,
                    preserving m's even parity (0 % 2 = 0) and decoding to 2e+1 (or overflowing to
                    infBits when e = 1023).

                    Lean 4 syntax note for Laws.lean: Core Lean 4 Rat defines ^ for Nat exponents
                    (HPow Rat Nat Rat), so unless Engine.Exact defines an HPow Rat Int Rat
                    instance, write (2 - (2 : Rat) ^ (-53 : Int)) * (2 : Rat) ^ (1023 :
                    Int) in Laws.lean with Nat exponents as (2 - 1 / (2 : Rat) ^ 53) * (2 :
                    Rat) ^ 1023.

     Finding 2.1 — bitsOps.ofExact and bitsOps.toExact remain unbound in Laws.lean

             What it breaks: The completeness of the evaluator binding in Laws.lean (Step 5 Wall 4
             and Round 6 Section 4: "Only float(·) of an exact value under 2⁻¹⁰⁷⁵ in magnitude
             reaches it").

11/17/26, 4:31 PM                                      See attached instructions

             Concrete construction: D196 moved bitsOps.exp = Exact.exp ∧ bitsOps.log =
             Exact.log out of the interface comment into Law X4's statement, and D203 proves X5
             for Engine.Exact.nearestBits over Engine.Exact.decode. However, the evaluator's
             two crossings (float(e) via bitsOps.ofExact and exact(f) via bitsOps.toExact)
             are still bound only in Step 5 Wall 4's prose ("bitsOps takes Exact.decode and
             Exact.nearestBits"). Adding bitsOps.ofExact = Engine.Exact.nearestBits ∧
             bitsOps.toExact = Engine.Exact.decode to X4's binding clause (or X5) in
             Laws.lean ensures checks.engine-proofs verifies that float(·) and exact(·) in
             the running evaluator actually use nearestBits and decode.
             Outcome it could change: An unlinked bitsOps.ofExact or bitsOps.toExact could
             pass X4 and X5 while changing float(·) or exact(·) in triggers or order prices.
             Classification: Minor proof-contract note (add bitsOps.ofExact =
             Engine.Exact.nearestBits ∧ bitsOps.toExact = Engine.Exact.decode to
             Laws.lean).

     What I Accept in Part 1
             D202's core two-host validation architecture: Running every attempt on two hosts from
             one pinned identity before anything is published closes GPT 3 (single-host false final
             verdicts) at the design level, once the comparison scope and host-failure handling in
             Findings 1.1–1.2 are specified.
             D196, D203, and Law X5: Stating X4 via the least deciding count with bitsOps bound in
             the theorem, fixing nearestBits to return -0 on negative rationals that round to zero, and
             proving Law X5 over all q : Rat completely closes Argon 3.1, Argon 6.1, and GPT 4.
             Together with the paper remainder bounds (verified in Round 5 and tested against MPFR in
             Test 12), X4 and X5 guarantee that every non-NaN output of Exact.exp and Exact.log is
             IEEE 754's roundTiesToEven result.
     PART 1 END

     User prompt: continue

     Response: 3. Attack on D194 with D200 and D201 (The Record as It Is, the
     Timer, and the Pull)
     Verification of D194 + D200's Pathwise Inclusion Claim

     With D200's removal of inherited file lengths, the pathwise inclusion claim holds at the design
     level: on any sequence of attempt snapshots S(t1 ), … , S(tm ), either S(tk ) reproduces the
                                                                                 

     published prefix through Tk−1 (in which case D194 and the committed runner produce identical
                                            

11/17/26, 4:31 PM                                               See attached instructions

     rows through Tk ), or S(tk ) differs before Tk−1 (in which case D194 stops before Tk−1 and
                                                                                                   

     examines no new days). Thus, on identical attempt snapshots, D194 never names a crossing that
     the committed text does not.
     The remaining attack surface lies in the mechanical specification of the capture, the pull's range,
     and the reader's deduplication boundary:

     Finding 3.1 — Midnight boundary race between pull completion and file-length capture, 31-
     day month gaps in the collector's "daily range", and hung-attempt blocking

             What it breaks: D201's deduction ("If the pull completed on the UTC day it began, the
             firing starts an attempt at once. So the pull began after the last midnight the attempt can
             run to"), the settled-funding collector's coverage, and the hourly retry timer.
             Concrete construction:
                    1. Pull completion before midnight vs. quote timestamp at or after midnight:
                       Suppose an hourly firing starts at 23:00 UTC on day D. Its funding pull begins at
                       23:00 UTC (covering up to 23:00 UTC on day D, so it does not cover the 00:00 UTC
                       settlement at midnight TD+1 ). Suppose the pull runs slow and completes at
                                                     

                       23:59:59.950 UTC on day D—on the same UTC day it began. The firing "starts an
                       attempt at once", but enumerating and hashing the recorder's files finishes 100 ms
                       later at 00:00:00.050 UTC on day D + 1 (or at 23:59:59.980 UTC host time when
                       the venue's clock is 30 ms ahead of the host's clock), after mmrec has written a
                       quote with venue timestamp ≥ TD+1 . By D194 Rule 3, the attempt runs to "the last
                                                                

                       midnight at or before the last quote the recorder's files hold" (TD+1 ), running past
                                                                                               

                       what the 23:00 UTC pull covered and aborting with R_SETTLEMENT_MISSING.
                    2. Collector "daily range" after a 31-day month or multi-day outage: D201 states
                       that the firing "runs a pull of the settled-funding collector over its daily range". If the
                       collector's daily range is 24 hours (or even 30 days, like mmvault) and a daily pull
                       failed earlier in a 31-day month (or the replay runs on the 2nd after a day-1 outage), a
                       24-hour or 30-day pull does not reach back to the previous published replay's
                       midnight Tprev , leaving a gap that e691341's full-horizon fetch would have covered.
                                      

                    3. Hung pull or remote host blocking hourly retries: D201 specifies that "a firing
                       while one runs does nothing". Without a hard timeout on the collector pull and two-
                       host execution, a hung socket or stalled remote host blocks all subsequent hourly
                       firings until an operator manually kills it, reintroducing manual timing discretion over
                       when the next hourly firing runs.
             Outcome it could change: Triggers a false R_SETTLEMENT_MISSING abort at midnight
             TD+1 (ending CS2.1 early or leaving CS2.2/CS2.3 "not judged"), or lets manual intervention
                      

             after a hang set the retry hour.

11/17/26, 4:31 PM                                           See attached instructions

             Classification: Text/specification defect in Step 7 Wall 3 (cap the attempt's horizon at the
             last midnight at or before both the recorder's last quote and the pull's start time—or
             require the snapshot capture itself and the last quote's venue timestamp to precede the
             next midnight; ensure the pre-attempt funding pull covers from at least the last published
             midnight Tprev ; and enforce a bounded timeout on each pull and attempt).
                               

     Finding 3.2 — Pull-envelope metadata in "one event, one item", horizon filtering before
     feed, and trailing partial .zst frames

             What it breaks: D194 Rules 1–3 ("It reads only whole lines; a partial last line or frame is not
             read", "An item is the event a line holds, as the engine or the vault's replay reads it. Lines
             that hold the same event hold one item") and KERNEL.md A18.
             Concrete construction:
                    1. Pull receipt timestamps (known) on re-pulled funding rows: In KERNEL.md A18, a
                       funding record in a chunk carries both time and known, and feed rejects a second
                       funding event for the same (coin, hour) with R_MARKET. When the settled-
                       funding collector re-pulls an hour's settlement across multiple daily pulls and the
                       pre-attempt pull, each pull envelope has a different fetch timestamp. If the reader
                       sets known from the pull envelope's fetch timestamp rather than deterministically as
                       time + lag, identical settlements from two pulls become distinct engine events
                       and feed immediately rejects the second under A18. (The pilot hit this exact trap in
                       C0.3.)
                    2. Reader horizon filtering on active files: At 12:00 UTC on the first of the month, the
                       writers' files contain events from 00:00 UTC to 12:00 UTC (with time >= w_end).
                       Because KERNEL.md A18 specifies that feed rejects any event with time outside
                       [w_start, w_end) (R_MARKET), the OCaml reader must filter events to w_start
                       <= time < w_end before feeding chunks.

                    3. Truncated .zst frames at the pinned byte length: Recording an active .zst file's
                       byte length L cuts the file mid-frame; mmrec cat reading head -c L must emit all
                       complete lines within the first L bytes and exit cleanly without treating the trailing
                       incomplete frame as a corrupt stream.
             Outcome it could change: Falsely rejects every replay on re-pulled funding rows or post-
             midnight events (R_MARKET), or aborts on the active hour's .zst file.
             Classification: Text/implementation specification note for Step 6 and Step 7 readers
             (define funding's known = time + lag independent of pull metadata, filter reader
             events to [w_start, w_end), and ensure mmrec cat truncates trailing partial frames
             cleanly at byte length L).

     4. Attack on D204 (One Vault Fill Is One Item)

11/17/26, 4:31 PM                                              See attached instructions

     Verification of the (coin, tid, oid) Identity

     On Hyperliquid, a trade ID (tid) identifies a bilateral match between a maker order and a taker
     order, and an order ID (oid) uniquely identifies each side's order. Two distinct fills of the same
     account can share a tid only in a self-trade, where the account owns both the maker order and
     the taker order (oid_1 != oid_2). Conversely, if a single order (oid) fills against multiple
     counterparties, each match has a distinct tid. Therefore, two genuinely different fills cannot
     collide on (coin, tid, oid).

     Finding 4.1 — Deduplicating vault fills by raw JSON line rather than parsed read fields, and
     omitting coin from the uniqueness key

             What it breaks: D204 ("the reader merges lines that hold one fill alike; the replay of given
             fills rejects a fill whose trade and order ids an earlier fill holds, whatever else it holds").
             Concrete construction:
                    1. Raw JSON line vs. parsed read fields across pulls: The Round 6 report notes in
                       Section 5 that mmvault's pulls overlap for 30 days and also overlap the pre-2026-11-
                       01 historical file, stating: "If the venue now serves an old fill with a different read field,
                       the two copies conflict". However, if the OCaml reader merges lines by raw JSON
                       string equality rather than by the tuple of fields the replay actually reads—(coin,
                      time, tid, oid, side, dir, px, sz, startPosition, fee,
                      closedPnl, crossed)—then any benign formatting difference, key reordering, pull-
                      envelope metadata, or change to an unread API field between the pre-2026-11-01
                      copy and mmvault's pull (or across two mmvault pulls) will fail to merge, pass both
                      copies to Lean's replay, and trigger D204's duplicate (tid, oid) rejection.
                    2. Scoping (tid, oid) per coin: Step 6 Test 10 explicitly allows the same oid pair
                       on two different coins ("the same two oid on two coins are two prints"),
                       and C2 keys prints by (coin, time, id). Keying vault fills by (coin, tid, oid)
                       rather than bare (tid, oid) prevents a cross-coin collision if tid/oid numbering
                       is ever per-asset.
             Outcome it could change: Falsely rejects the vault's fill replay and forces CS2.3 to "not
             judged" on benign formatting or unread-field differences across pulls.
             Classification: Text/specification defect in Step 2 Test 5 and Step 7 Wall 3 (specify that
             the reader merges fills by equality of their parsed read fields, and key uniqueness by
             (coin, tid, oid)).

     5. Evaluation of the Recommended Dated Note to CS2.1
             Is it needed? Not for statistical validity—the committed words ("what a day's end showed
             stands in every later replay" and "A record that stops, or that the engine cannot run past
             some time, ends it at the last day run") already license stopping at the last midnight before

11/17/26, 4:31 PM                                        See attached instructions

             a changed published row. However, it is needed for transparent pre-registered disclosure:
             CS2.1's "Fails while the claim holds" enumerates every other honest way the test can fail to
             confirm (power wall, intraday crossings, wide bid spreads, noise prints on the bar, staleness
             gaps, full disk), and without this note, terminating a two-year forward study because the
             venue indexed an unheld coin's funding row 13 hours late is an undisclosed failure mode.
             Is it safe? Yes—with one scope refinement. Ending the test at the last midnight before a
             changed published row only removes future crossings and never adds a discovery,
             preserving Ville's 5% bound. However, the Round 6 wording ("An item about a published day
             that the venue served after the replay that published it ends the test at the last midnight
             before it, with every writer kept to its specification") describes only the venue-caused
             subcase. Combining the general operational rule with the honest-cost disclosure—"Where
             a replay's rows of a day already run differ from those published, the test ends at the last
             midnight before the first row that differs, as a record the engine cannot run past ends it; an
             item about a published day that the venue served after the replay that published it can end
             the test this way with every writer kept to its specification"—is completely safe and covers
             both the mechanism and the honest cost.

     What I Accept in Part 2
             D194 with D200 and D201 (the record as it is): Dropping D189's lag, cut, keys, and D194's
             inherited lengths eliminates GPT 1 (killed-attempt length inheritance) and all earlier cut/lag
             constructions at their cause.
             D204 (vault fill conflict detection): Rejecting a repeated (coin, tid, oid) with
             differing read fields in the replay of given fills closes GPT 5 (buy A → sell B → buy A'
             → sell B' passing chained) cleanly and conservatively.

             The dated note to CS2.1: Safe to commit before the freeze and improves disclosure of the
             honest early-termination cost.

     Ledger: Agreed, Disputed, and Build Impact Across Rounds 5 and 6

                                                                                            Would
                                                                                            change
       Item                    State             Summary
                                                                                            what is
                                                                                            built?

                                                 Closed at their cause: least-deciding-
       D195, D196,                               count X4, MPFR subnormalization, per-      No beyond
       D197, D198,             Agreed            argument diagnostics, MXCSR control-       the Round 5
       D199                                      bit mask (0xFFC0), and environ[0]          & 6 lists
                                                 == NULL re-exec guard.

11/17/26, 4:31 PM                                        See attached instructions

                                                                                            Would
                                                                                            change
       Item                    State             Summary
                                                                                            what is
                                                                                            built?

       D200 (killed
                                                                                            No beyond
       attempt                                   Closes GPT 1's pathwise
                               Agreed                                                       the Round 6
       produces                                  counterexample at the cause.
                                                                                            list
       nothing)
                                                 Core design is sound, but must: (1) cap
                                                 the attempt horizon at the last midnight
                                                 ≤ both the pull's start time and the
                                                 recorder's last quote (Finding 3.1); (2)
                                                 ensure the pre-attempt funding pull        Yes — Step
       D201 (hourly                              covers from Tprev and enforce attempt
                        Disputed (spec                                                      6/7 reader
       timer, pull, and
                                                                       

                        details)                 timeouts (Finding 3.1); (3) set funding    & runner
       attempt capture)
                                                 known = time + lag independent of          spec
                                                 pull metadata, filter reader events to
                                                 [w_start, w_end), and ignore
                                                 trailing partial .zst frames at byte cut
                                                 L (Finding 3.2).

                                                Core two-host validation is right, but
                                                must: (1) include mmvault file
                                                lengths/hashes in the snapshot and
                                                verify finish's summary JSON,
                                                confirm/held, and CS2.3's vault
       D202 (two                                replay/matching on both hosts (Finding Yes — Step
                               Disputed (scope
       hosts per                                1.1); (2) advance to the next host on the 7 runner &
                               & failure rules)
       attempt)                                 same identity if one host                 Test 10
                                                crashes/aborts, provide ≥ 3 hosts (or a
                                                same-identity retry), and run CS2.1's
                                                post-abort truncated rerun immediately
                                                on the same snapshot on two hosts
                                                (Finding 1.2).
       D203 & Law X5           Agreed (with 1    X5's statement and proof outline are       1 line in
       (nearestBits            minor clause)     sound and -0 is fixed; add                 Laws.lean
       universal law &                           bitsOps.ofExact =                          (Step 5)
       -0 fix)                                   Exact.nearestBits ∧
                                                 bitsOps.toExact = Exact.decode
                                                 to Laws.lean so the crossings are

11/17/26, 4:31 PM                                        See attached instructions

                                                                                             Would
                                                                                             change
       Item                    State             Summary
                                                                                             what is
                                                                                             built?
                                                 theorem-bound like exp/log (Finding
                                                 2.1).
                                                 (coin, tid, oid) prevents genuine
                                                 collisions and closes GPT 5; specify
                               Disputed
       D204 (one vault                           that the reader merges identical fills by   Step 2/7
                               (text/spec
       fill is one item)                         their parsed read fields (ignoring pull     reader spec
                               note)
                                                 metadata and unread JSON fields) and
                                                 includes coin in the key (Finding 4.1).
       CS2.1 dated                               Safe and recommended before the
       note (honest            Agreed            freeze; state both the changed-row          No (criteria
       late row early          (recommended)     stopping rule and its honest venue-         text only)
       end)                                      latency cause.


