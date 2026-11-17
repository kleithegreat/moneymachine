# Argon on the architect's rounds 3 and 4 (D180 to D193)

Model Gemini 4 Argon in the Gemini web UI, given the self-contained bundle `argon-last-pass-r3r4.md` (624 KB, 14 files, built from `rearchitecture` `3f911d1`), in three parts. Saved by the human as a PDF on 2026-11-17. Converted with pdftotext, with page furniture and stray characters removed. The text is otherwise verbatim.


     Audit and Vulnerability Analysis of D189 and
     D190
     https://gemini.google.com/app/fae67d08154773b5

     User prompt: See attached instructions?

     Response: 1. Attack on D189 (A Day Is Read Once: Cuts, Lag, Keys, and Order)
     Finding 1.1 — Underspecified attempt binding allows cross-replay, rejected, or aborted
     attempts to freeze empty or premature cuts

             What it breaks: D189 (ledger.md and the Round 4 report: "A day's record is its items
             within the cut of the first attempt whose horizon reached it, among the attempts of the
             study's one evaluation ledger. An attempt killed after its row binds too"), A13, and D190.
             Concrete construction: Three failure modes arise from binding a day's cut to "the first
             attempt whose horizon reached it, among the attempts of the study's one evaluation ledger":
                 1. Cross-replay file sets (market replay vs. vault-fill replay): By A13, an attempt's
                    identity hashes "the market's every file to the length the run reads it to", and the Layer
                    1 replay of given fills writes to the same SQLite evaluation ledger. A forward market
                    replay (mm2 on quotes, trades, funding, listings) reads no mmvault files; a vault-fill
                    replay (Layer 1 on userFillsByTime) reads no market files. If both share one
                    evaluation ledger without partitioning cuts by replay kind (or hashing both file trees in
                    every attempt), the first forward market attempt reaching day d commits an attempt
                    row with no mmvault files, leaving day d's vault-fill cut empty or undefined.

                 2. Premature or malformed attempts rejected at start: By A13, the attempt row is
                    committed to SQLite before the engine starts (start). If an operator accidentally
                    launches a run on day d + 1 whose header sets w_end past Td (violating the 31-day  

                    lag or meeting an unreleased protected window), the attempt row is committed
                    before start rejects it with R_PROTECTED or E_HEADER. Because "an attempt killed
                    after its row binds too", that rejected attempt permanently locks Cut(d) 30 days
                    early, before day d's 30-day collector window has run.

                 3. Mid-horizon aborts under CS2.1: In CS2.1 ("The days run"), when a replay with
                    horizon [T0 , T60 ) aborts on day 20 (e.g., R_SETTLEMENT_MISSING), "the replay is run
                                       

                    again to the last midnight at or before that time" (T19 ), so only days 1..19 are days run
                                                                                    

                    completed by the engine. However, Attempt 1's horizon reached days 20..60, binding
                    their cuts even though the engine never reached them.
             Outcome it could change: Freezes an empty or incomplete cut for judged days, causing
             CS2.1 to miss crossings or abort, or CS2.3 to fail chained ("not judged").

11/17/26, 10:56 AM                                   Audit and Vulnerability Analysis of D189 and D190

             Classification: Design/text defect (a day's cut for a given replay stream must be bound
             only by the first attempt of that replay stream whose horizon satisfies Td + 31 days ≤ s    

             and passes header/window validation).

     Finding 1.2 — Deleting D180's 30-day write-timestamp filter restores an operator timing
     lever after d + 31 days and can break chained across day cuts

             What it breaks: D189's claim that "when an attempt starts changes nothing", CS2.3's
             chained check (M4), and the Round 4 report's mmvault catch-up rule.

             Concrete construction:
                 1. Operator timing lever after d + 31 days: Round 3 (D180) excluded items written
                    more than 30 days after day d and used the 31st day as a delivery buffer. Round 4
                    (D189) deletes the 30-day write-time filter: every item inside Cut(d) is read
                    regardless of when it was written ("Where a writer misbehaved, the day is what its cut
                    holds"). Suppose a suspended recorder flushes its buffer, a remote file syncs to the
                    replay host, or an unpatched mmvault catch-up writes a day-d item at Td +                

                    31 days + 2 hours. An operator who runs Replay 1 at Td + 31 days + 1 hour 

                    excludes that item from Cut(d) forever; an operator who runs Replay 1 at Td +                    

                    32 days includes it forever.

                 2. Cross-cut chain break in CS2.3: Suppose a vault position opens on day d1 = 10                

                    and closes on day d2 = 45. Due to a collector outage or sync delay, the day-10
                                                 

                    opening fill is written on day 42—after Replay 1 on day 41 sealed Cut(10) without it,
                    but before Replay 2 on day 92 seals Cut(45) with the day-45 closing fill. In Replay 2
                    (which judges CS2.3), day 10 is read within Cut(10) (omitting the open) while day 45
                    is read within Cut(45) (retaining the close with startPosition > 0). Even though
                    the complete chain is on disk when CS2.3 is judged, combining Cut(10) and
                    Cut(45) breaks chained (M4) at day 45. Likewise, if the advisor applies the Round
                    4 report's change so mmvault catch-ups "not reach back more than 30 days before
                    the last midnight", any outage lasting past day d + 30 forbids mmvault from ever
                    fetching the missing day-d fill, permanently breaking chained.

             Outcome it could change: Moves a CS2.1/CS2.2/CS2.3 verdict via replay start time, or
             forces CS2.3 to "not judged" on a complete chain.
             Classification: Design defect in D189 (dropping the 30-day write-timestamp filter on
             collectors and applying per-day cuts to chained when a round trip spans two cuts).

     Finding 1.3 — Unaligned byte-length cuts on active files, same-millisecond vault fill
     ordering across pulls, and duplicate print IDs

11/17/26, 10:56 AM                                Audit and Vulnerability Analysis of D189 and D190

             What it breaks: D189's cut reader, Step 1's M1 chain ordering, and C2's repeated-trade-ID
             check.
             Concrete construction:
                 1. Mid-frame/mid-line byte cuts: Recording the byte length L of every file while the
                    live recorder's .zst file (or an arriving sync) is open can record an L that ends mid-
                    zstd-frame or mid-JSON-line. Unless the cut is defined as the complete frames/lines
                    within the first L bytes (with mmrec cat reading head -c L without aborting on a
                    trailing partial frame), two replays or mmrec cat can fail on the cut file.
                 2. Same-millisecond vault fills split across pulls: D189 orders items by (writer,
                    file path, place in file). Suppose two vault fills on one coin in millisecond t
                    have distinct keys (coin, tid_1, oid_1) (buying 5 from startPosition = 0)
                    and (coin, tid_2, oid_2) (buying 5 from startPosition = 5). If the second
                    fill was captured in hourly pull path_A and the first fill was recovered later in daily
                    re-read path_B (path_A < path_B), ordering same-millisecond fills by file path
                    feeds startPosition = 5 before startPosition = 0, breaking chained unless
                    M1's chain sort orders same-millisecond fills after key deduplication.
                 3. Print key (coin, time, id) vs. C2: Websocket reconnect snapshots re-send
                    recent trades with the same (coin, time, tid), so deduplicating by (coin,
                    time, id) rightly drops reconnect duplicates. However, if two distinct partial fills in
                    one millisecond ever shared a tid, reader deduplication silently drops the second
                    volume instead of triggering C2's repeated-ID rejection.
             Outcome it could change: Aborts a replay on a trailing partial frame, breaks CS2.3's
             chained on same-millisecond fills across pulls, or silently drops same-millisecond trade
             volume.
             Classification: Text/specification defect (specify frame/line truncation within L, M1
             ordering after key deduplication for same-millisecond vault fills, and how first-of-key
             interacts with corrupt rows).

     2. Attack on D190 (The Dated Revision's Text)
     Finding 2.1 — The drafted revision cites briefs/4-study-2.md without updating the
     frozen e691341 commit pointer, conflicts with the abort fallback in "The days run", and
     makes the February 2027 replay empty after a Jan 31 freeze

             What it breaks: The drafted revision text in the Round 4 report
             (data/builder/architect-last-pass-r4-report.md) against
             audit/criteria.md.

             Concrete construction:

11/17/26, 10:56 AM                                Audit and Vulnerability Analysis of D189 and D190

                 1. Dangling commit reference: The header of Study 2 in audit/criteria.md pins all
                    cited files to rearchitecture e691341 ("Verbatim from
                    audit/program/criteria-notes.md at rearchitecture e691341, whose files
                    the definitions cite: ... audit/program/briefs/4-study-2.md"). The drafted
                    revision delegates the keys and record order to (briefs/4-study-2.md, step 7,
                    wall 3). At e691341, step 7 wall 3 does not contain D189's keys or record order;
                    those exist only at the Round 4 commit (3f911d1).
                 2. Conflict with the abort fallback in "The days run": Placed directly beneath "The
                    days run", the revision says "the first attempt of a replay whose horizon reaches a day"
                    locks that day's cut, whereas the parent bullet says that if the engine rejects or
                    aborts at t, "the replay is run again to the last midnight at or before that time", and
                    only completed days are "days run" (see Finding 1.1).
                 3. February 2027 monthly replay vs. 31-day lag: CS2.1 states: "It is replayed once a
                    month from February 2027, and each time the end of every day run so far is examined."
                    Because the pre-registration holdout window runs to 2027-01-31 (briefs/3-
                    kernel-v2.md), a freeze on or after 2027-01-31 has its first judged day end at
                    2027-02-01 00:00 UTC. Thirty-one days after 2027-02-01 is 2027-03-04—so in
                    February 2027 (a 28-day month), zero judged days are ≥ 31 days old, and a replay in
                    February 2027 has no eligible midnight (wend ≤ wstart ).
                                                                                      

             Outcome it could change: Leaves keys and order unpinned at e691341, binds cuts on
             aborted days, and causes the February 2027 replay to fail start unless a 0-day horizon is
             defined as a no-op.
             Classification: Text defect in the drafted revision (state the keys and record order inline or
             cite the Round 4 commit hash for briefs/4-study-2.md, bind cuts only for completed
             days or valid horizons per stream, and note that a monthly replay before 31 judged days
             have elapsed runs 0 days).

     What I Accept in Part 1
             D189's core reader-side cut principle: Recording each file's byte length and
             cryptographic hash before execution and reading only within that cut eliminates writer-
             side availability assumptions across replays once attempt binding and the 30-day write
             filter are tightened.
             D189's key definitions and historical chain scope: Using (coin, hour) for funding,
             (coin, time, id) for prints, and (coin, tid, oid) for vault fills (preserving self-
             trade halves), and reading the pre-2026-11-01 vault copy whole before mmvault pulls.
             D190's statistical validity: Because the revision is fixed before any judged day is run and
             reads no outcome, it cannot add a false discovery or alter any threshold.
     PART 1 END

11/17/26, 10:56 AM                               Audit and Vulnerability Analysis of D189 and D190

     User prompt: continue

     Response: 3. Attack on D192 (exp and log, Law X4)
     Finding 3.1 — X4 leaves bitsOps binding in a comment and relies on Exact.decode and
     Exact.nearestBits, which have no theorem in Laws.lean outside normal decimals

             What it breaks: X4 in kernel2/lean/Engine/Laws.lean
             (data/builder/architect-last-pass-r4-report.md and
             audit/program/kernel-v2.md B3) and the claim that "a wrong engine fails X4 at the
             first argument where it differs".
             Concrete construction:
                 1. bitsOps wiring is in the interface comment, not the theorem: In the Round 4
                    report's specification of Laws.lean, with bitsOps.exp := Exact.exp and
                    bitsOps.log := Exact.log is placed under "In the interface comment", while
                    the theorem clauses (exp), (log), (width), and (nesting) state properties of
                    Exact.exp and Exact.log alone. If bitsOps.exp or bitsOps.log in the
                    evaluator is not definitionally or propositionally required by X4 to equal Exact.exp
                    and Exact.log (compare X3, which explicitly states @Exact.readBits =
                    @Exact.readBitsFast in the theorem), an engine whose Exact.exp satisfies X4
                    while bitsOps.exp calls another function still passes checks.engine-proofs.
                 2. Exact.nearestBits and Exact.decode are unverified outside X2's decimal
                    range: X4 specifies Exact.exp bits and Exact.log bits in terms of lo :=
                    nearestBits (expLoAt x (expTerms x)) and hi := nearestBits
                    (expHiAt x (expTerms x)) for decode bits = some x. However, per D169
                    (ledger.md), "The crossings are definitions (Exact.decode, Exact.nearestBits),
                    held by test 1 and no clause of L2", and X2 only constrains readBits on decimals n ⋅
                    10−d with ∣n∣ < 1015 and 0 ≤ d ≤ 12 (magnitudes in [10−12 , 1015 ) ⊂ [2−40 , 250 )).
                    No theorem in Laws.lean proves that Exact.nearestBits implements IEEE 754
                    round-to-nearest-even on subnormals (2−1074 ≤ ∣q∣ < 2−1022 ), near the overflow
                    boundary (2 − 2−53 )21023 , or at dyadic midpoints. Suppose Exact.nearestBits
                    has a defect in its subnormal shift (e.g., flushing ∣q∣ < 2−1022 to 0 or off-by-one
                    exponent on subnormals) or uses (2 − 2−52 )21023 as its overflow cutoff. Then lo :=
                    nearestBits (expLoAt ...) and hi := nearestBits (expHiAt ...) still
                    agree (lo = hi), so Exact.exp returns the wrong UInt64, passes the normal
                    witnesses exp(1.0) and log(2.0), and X4 is proved in Lean.
                 3. Sign-reversal of nearestBits on negative log intervals: For 0 < y < 1,
                    log y < 0. In IEEE 754 sign-magnitude encoding (UInt64), nearestBits is order-

11/17/26, 10:56 AM                                                            Audit and Vulnerability Analysis of D189 and D190

                     reversing on negative rationals (p ≤ q < 0 ⟹ nearestBits(p) ≥
                     nearestBits(q) as UInt64). Early stopping at the first N where nearestBits
                     (logLoAt y N) = nearestBits (logHiAt y N) only guarantees equality with
                     logTerms = 90 if nearestBits is proved monotone on each sign in Lean (so that
                     Exact.log with early stopping can be proved equal to X4's formula at logTerms).

             Outcome it could change: A bug in nearestBits (on subnormals, ties, or overflow) or an
             unlinked bitsOps changes exp/log bits in triggers or exact(·) crossings and moves a
             judged CS2.1–CS2.3 outcome while passing X4.
             Classification: Proof-contract / text defect in X4 (include bitsOps.exp = Exact.exp
             ∧ bitsOps.log = Exact.log as a conjunct of X4, and ensure Exact.log/Exact.exp
             in Lean are proved to satisfy (exp) and (log) directly rather than only testing early-stopping
             equivalence).

     Finding 3.2 — Verification of X4's mathematical formulas, NaN reachability, and Lefèvre–
     Muller worst-case coverage

             What it breaks: Nothing in X4's mathematical series or remainder bounds; one
             certification gap remains on exp's subnormal output range (acknowledged as uncertified in
             D192), while the overflow and underflow edges are fully closed by Test 12.
             Concrete verification of the formulas and bounds:
                 1. exp series, remainder, width, and nesting: For a = ∣x∣ < 746 and N ≥ ⌈2a⌉,
                                                                              k+1
                     each term past N satisfies a a/(k+1)!
                                                   k /k!   = k+1
                                                              a
                                                                 < 12 , so the omitted Taylor tail is
                                                                                                                                     

                                                                                    N +1
                                                     2a
                     strictly in [0, TN ] with TN = (N
                                                    

                                                       +1)!
                                                            . Because N2a+2 < 1 for all N ≥ ⌈2a⌉, loN +1 −
                                                                                                                                                                                               

                                        N +1                                                                                                               N +1
                     loN = (Na +1)! (3 − N2a+2 ) ≥ 0 and hiN − hiN +1 = (Na +1)! (1 − N2a+2 ) ≥ 0, so
                                                                                                                                                                                

                     intervals nest from N = ⌈2a⌉ upward. Note that in Brief 3 Step 5 Wall 11, "add terms
                     from a few until both ends round alike" must start at N ≥ ⌈2∣x∣⌉, never below ⌈2∣x∣⌉
                     where TN is not a valid remainder bound. At N = ⌈2a⌉ + 260, comparing TN
                                                                                                                                                                                             

                                                                           M
                     against the M = ⌈2a⌉ term gives TN < 2 ⋅ 2−261 aM ! < 2−260 SN , so the relative                                                                           

                     width for both x ≥ 0 and x < 0 is SN2T−TN
                                                               N
                                                                 < 2−258 < 2−256 (and near a = 746 is
                                                                                                   
                                                                                                                   

                                                                                                                       
                                                                                                                           

                     ≈ 2−707 ).

                 2. log series, remainder, width, and nesting: For y = 2e ⋅ m with 3/4 ≤ m < 3/2,
                    z = m−1
                         m+1
                             ∈ [−1/7, 1/5). The artanh remainder satisfies ∣RN (w)∣ ≤ BN (w), and
                                                                                                                                                                                        

                                                          2N +3
                                                   2∣w∣
                     ∣ΔAN (w)∣ = 2N +3 = (1 − w2 )BN (w) ≤ BN (w) − BN +1 (w), so intervals
                                                                                                                                                                      

                                                                                      1 −182
                     nest for all N ≥ 0. At N = 90 (2N + 3 = 183), B90 (1/3) = 244      3     ≈ 2−296.39                                                                     

                     and B90 (1/5) ≈ 2−432.69 , so the relative width is at most ≈ 2−294.8 < 2−256 for
                                

                     every y > 0 (and 0 ≤ 0 at y = 1).

11/17/26, 10:56 AM                                       Audit and Vulnerability Analysis of D189 and D190

                 3. Reachability of nanBits and worst-case coverage:
                          Overflow and underflow edges are closed: The overflow threshold is Xovf =          

                          log((2 − 2−53 )21023 ) ≈ 709.782712893384 < 710, and the subnormal-to-
                          zero threshold is Xudf = −1075 log 2 ≈ −745.133219101941 > −746.
                                                 

                          Each threshold is a single real point bracketed by two adjacent binary64 floats
                          spaced by 2−43 ; the nearest binary64 arguments lie ≈ 2−46 away from Xovf              

                          and Xudf , giving relative distances > 2−47 ≫ 2−256 from the rounding
                                       

                          thresholds. Because Test 12 explicitly tests the binary64s on either side of
                          log((2 − 2−53 )21023 ), −1022 log 2, and −1075 log 2 (plus 710 and −746),
                          the overflow, normal-to-subnormal, and underflow edges are completely
                          certified by direct execution.
                          exp's subnormal interior (−1075 log 2, −1022 log 2): Lefèvre and Muller's
                          2001 exhaustive search for exp covered normal outputs (ex ≥ 2−1022 , worst-
                          case midpoint distance ≈ 2−113 ) and did not table the 53 subnormal output
                          binades x ∈ (−745.1332, −708.3964), where subnormal spacing is fixed at
                          2−1074 (midpoints (2k + 1)2−1075 ). However, at ∣x∣ ∈ (708, 746), X4's relative
                          width is < 2−680 , so its absolute interval width is < 2−680 ⋅ 2−1022 =
                          2−1702 = 2−627 ulpsub . No reachable NaN exists on any known binary64 input,
                                                     

                          and as D192 states, any hypothetical undecided subnormal would surface
                          visibly as undefined (nanBits), never as a wrong number.
             Outcome it could change: None on any known binary64 input; an undecided subnormal
             would evaluate to undefined rather than mis-rounding.
             Classification: No design defect in X4's mathematical formulas; only the proof-contract
             items in Finding 3.1 and Step 5 Wall 11's wording that early stopping for exp starts at N ≥
             ⌈2∣x∣⌉.

     4. Attack on D193 (B4's New Reference)
     Finding 4.1 — The shared MPFR C stub in Tests 12 and 13 must explicitly enforce
     mpfr_subnormalize to avoid double rounding on subnormals, and Test 13's diagnostic
     argument diff must account for state divergence

             What it breaks: Test 12 and Test 13's specification in data/builder/architect-last-
             pass-r4-report.md and audit/program/briefs/3-kernel-v2.md (Step 5 Tests 12
             and 13).
             Concrete construction:
                 1. Double rounding in MPFR without mpfr_subnormalize: Test 12 and Test 13
                    specify "MPFR at 53 bits, with binary64's exponent range and subnormals, through the

11/17/26, 10:56 AM                                Audit and Vulnerability Analysis of D189 and D190

                     test's own stub". In MPFR, an mpfr_t of precision 53 always keeps a full 53-bit
                     significand even at exponents below −1022. If the C stub sets emin = -1073 and
                     calls mpfr_exp(y, x, MPFR_RNDN); mpfr_get_d(y, MPFR_RNDN); without
                     calling mpfr_subnormalize(y, t, MPFR_RNDN) on the ternary status t, MPFR
                     rounds first to 53 bits and mpfr_get_d rounds a second time to the subnormal's
                     1..52 bits (double rounding). Because Test 12 and B4's new reference in Test 13 share
                     the same C stub, a missing mpfr_subnormalize call would make Test 12 fail on
                     subnormals or, if mirrored, hide a subnormal rounding discrepancy in B4.
                 2. Diagnostic argument list in Test 13 after a 1-ULP divergence: Test 13 prints "the
                    count of items differing from stage 6's stored streams, and every argument at which
                    glibc's result was not MPFR's". Once an early tick's exp(x) differs by 1 ULP between
                    MPFR and glibc, a downstream ema or sum feeding a later exp node gives the MPFR
                    reference run a slightly different input argument xmpfr = xglibc than stage 6's stored
                                                                                                     

                    run had. To list the arguments where glibc was not nearest, the diagnostic must
                    compare glibc(x) against mpfr(x) on the same argument x, not compare exp
                    outputs across two runs whose arguments x have already diverged.

             Outcome it could change: Causes false failures on subnormal exp in Test 12, or conflates
             downstream input drift with glibc mis-roundings in Test 13's diagnostic printout.
             Classification: Text/test specification note (specify mpfr_set_emin(-1073),
             mpfr_set_emax(1024), and mpfr_subnormalize in the stub, and test glibc(x) !=
             mpfr(x) per argument in Test 13).

     What I Accept in Part 2
             D192's core re-derivation of X4: Writing the concrete rational Taylor/artanh series and
             remainder bounds directly into Laws.lean with nanBits when lo != hi completely
             closes GPT 3.1 (arbitrary engine bounds) and GPT 3.2 (unproven lower-bound fallback).
             Because the true value lies inside [lo, hi] by elementary calculus and nearestBits is
             monotone on each sign, no branch can ever return an incorrectly rounded number.
             D193's core re-derivation of B4: Rebuilding B4's reference from stage 6's frozen source
             with MPFR's correctly rounded exp and log and comparing every stream item with zero
             exceptions completely closes GPT 4.1 (running-sum state residue) and GPT 4.2
             (permanent EMA blind spots) at their cause.
     PART 2 END

     User prompt: continue

11/17/26, 10:56 AM                               Audit and Vulnerability Analysis of D189 and D190

     Response: 5. Attack on D191 (The Trusted Launch and Per-Call Floating-Point
     Checks)
     Finding 5.1 — Checking MXCSR "after every call" aborts on normal IEEE 754 sticky
     exception flags (PE, UE, OE) unless status bits 0..5 are masked out, and self-reexecution
     requires a non-looping guard when launched with an already-empty environment

             What it breaks: D183 and D191 (audit/program/kernel-v2.md A13: "The C stub that
             calls the engine reads it before and after every call and aborts the run (E_FPENV) unless its
             control bits are the default: round to nearest, no flush to zero, no denormals as zero, every
             exception masked"; "Each executable, at its start and before it reads anything, executes
             itself again with an empty environment, and gives every program it calls an empty one"), and
             Brief 3 Step 9 Test 8.
             Concrete construction:
                 1. MXCSR sticky exception status bits (0..5) vs. control bits (6..15): On x86-64,
                    the 16-bit MXCSR register has default value 0x1F80, where bits 7..12 are the
                    exception masks (0x1F80), bit 6 is DAZ (0), bits 13..14 are RC (0), bit 15 is FTZ (0),
                    and bits 0..5 (0x003F) are the sticky exception flags (IE, DE, ZE, OE, UE, PE). Any
                    ordinary non-exact floating-point operation inside the Lean evaluator (1.0 / 3.0,
                    sqrt(2.0)), inside DuckDB when reading doubles, or inside OCaml sets the Inexact
                    flag (PE, bit 5 = 0x0020), changing MXCSR from 0x1F80 to 0x1FA0 (and valid
                    subnormal/overflow/NaN operations set UE, OE, ZE, or IE). If the C stub checks
                    _mm_getcsr() != 0x1F80 instead of masking out the sticky status bits
                    ((_mm_getcsr() & 0xFFC0) != 0x1F80, and similarly checking x87 FPU control
                    word rounding/precision bits if any C/OCaml code uses x87), the post-call check
                    immediately aborts every real run with E_FPENV.
                 2. Infinite execve loop when spawned with envp = {}: By D183, study2 re-
                    executes itself with an empty environment (envp = {NULL}) and passes an empty
                    environment (envp = {NULL}) to every child program it spawns (mm2, mmrec cat).
                    When mm2 starts, how does it know whether it is in its first image or its re-executed
                    image? If mm2 unconditionally calls execve("/proc/self/exe", argv,
                    empty_env), it loops forever. If mm2 skips execve whenever environ[0] == NULL,
                    then a process launched directly with envp = {NULL} skips the self-reexecution
                    step—which is still safe for MXCSR on Linux only because the kernel's execve into
                    mm2 already resets the FPU/SSE control registers (fpu_SysV) and ld-linux already
                    saw envp = {NULL}, provided mm2 resolves /proc/self/exe (never a relative
                    argv[0] when PATH is empty) whenever environ[0] != NULL.

             Outcome it could change: Aborts every run containing an inexact float with E_FPENV, or
             infinite-loops / fails execve when study2 invokes mm2 with an empty environment.

11/17/26, 10:56 AM                                 Audit and Vulnerability Analysis of D189 and D190

             Classification: Text/implementation specification note for Step 9 Test 8 (specify
             (_mm_getcsr() & 0xFFC0) == 0x1F80 so sticky flags 0..5 are ignored, and re-
             execute via /proc/self/exe iff environ[0] != NULL).

     6. Attack on the Rest of D180 to D193 and Cause-Level Closure Audit
     Finding 6.1 — O26 and X4 in Step 5: Running Test 12's 2 × 106 evaluations on Rat without
     either an early-stopping proof in Lean or an @[csimp] integer twin will stall checks.mm2-
     tests at Step 5

             What it breaks: Brief 3 Step 5 Test 12, Step 5 Wall 11, and O26
             (data/builder/architect-last-pass-r4-report.md: "Python takes 26 ms an exp
             (mostly at |x| near 700) and 10 ms a log. Lean's GMP is faster, and an integer twin proved
             equal is the fallback").
             Concrete construction:
                     In Laws.lean, X4's (exp) and (log) clauses define Exact.exp bits and
                     Exact.log bits by the intervals at expTerms x = ⌈2|x|⌉ + 260 (up to 1, 752
                     rational factorial terms with Nat.gcd normalization at every step) and logTerms =
                     90.

                     Meanwhile, Test 12 (kernel2/ocaml/test/) runs at Step 5 on 106 arguments of
                     exp and 106 arguments of log through the engine (bitsOps).

                     The architect faces a fork at Step 5 that cannot be deferred to Step 6's B5
                     benchmark:
                        1. If Exact.exp and Exact.log in Lean evaluate the fixed cap (expTerms x,
                           logTerms) directly without early stopping so that X4's (exp) and (log) hold by
                           rfl, then 106 calls of exp and 106 calls of log on reduced Rat sums—even if
                           Lean's GMP is 5× faster than Python's 26 ms / 10 ms—take ∼ (5 ms +
                           2 ms) × 106 = 7, 000 s (≈ 2 hours) in checks.mm2-tests.
                        2. Conversely, if Exact.exp and Exact.log implement early stopping in Lean
                           (briefs/3-kernel-v2.md Step 5 Wall 11) or use an integer twin via
                           @[csimp], then checks.engine-proofs at Step 5 cannot prove X4's (exp)
                           and (log) by rfl: the builder must either prove nearestBits monotonicity +
                           (nesting) in Lean to equate the early-stopping loop with expTerms x, or prove
                           the @[csimp] integer twin equal in Step 5.
             Outcome it could change: Causes Step 5's build/test cycle (checks.mm2-tests or
             checks.engine-proofs) to hit a wall unless the proof strategy for early stopping (or the
             @[csimp] twin) is budgeted at Step 5 rather than deferred to O26.

11/17/26, 10:56 AM                                 Audit and Vulnerability Analysis of D189 and D190

             Classification: Build-plan / proof-cost note on D192 and O26.

     Audit of GPT's Nine Round 3 Points and Argon's Thirteen Round 1–2 Points

             Closed at the cause (no remaining dispute):
                     Argon 1.4 & 5.2 (D181): L1 and D176's midnight slice explicitly name report rows
                     before T , coin (at = day) and account rows at T , and trace rows before T .

                     Argon 2.1 (D182): Stand-in vs. real .drv byte identity after substituting
                     windows_text and build_hash, plus two-host sandboxed builds, directly test
                     D177's two premises.
                     Argon 3.1 (D184): Engine-owned exp and log eliminate host libm path probing and
                     E_HOST.

                     Argon 4.1 & 4.2 (D174, D188): False grid/divisibility claims in Step 10 Tests 3 and 14
                     are deleted, Test 13 uses the 5/4 lattice, and LCM/telescoping bounds are derived
                     and measured.
                     Argon 5.1 (D186): A6's minimum-notional exemption matches the certified venue
                     rule, and offer is a no-op at remainder zero (provided signed a.order in R1's
                     minimum is the signed remainder, matching Test 7).

                     Argon 5.3 (D187): Millisecond staleness and open are pinned to the end of each
                     millisecond, and guard's trading across holes is disclosed.
             Re-derived at the cause, with boundary defects to close from Parts 1–3:
                     Argon 1.1–1.3 & GPT 1.1–1.3 (D180 → D189): Moving to a reader-side byte/hash cut
                     removes writer-side completeness and delivery assumptions, subject to Findings 1.1–
                     1.3.
                     GPT criteria reconciliation (D190): The dated revision is statistically valid and adds
                     no false discovery, subject to Finding 2.1.
                     Argon 2.2, 3.2 & GPT 2 (D183, D191): The trusted-launch boundary and per-call
                     MXCSR checks close environment/FPU contamination, subject to Finding 5.1.
                     GPT 3.1, 3.2 (D192): X4's explicit series and nanBits cap close arbitrary bounds and
                     unproven fallbacks, subject to Findings 3.1 and 6.1.
                     GPT 4.1, 4.2 (D185 → D193): Rebuilding B4's reference with MPFR's exp and log
                     and comparing every item removes all reach exemptions, subject to Finding 4.1.

     What I Accept in Part 3

11/17/26, 10:56 AM                                        Audit and Vulnerability Analysis of D189 and D190

             D191's trusted-launch boundary: Stating in A13 and D1 that the launch is trusted (just as
             the build and recordings are) while scrubbing the inherited environment to remove honest
             shell leftovers closes GPT 2 and Argon 2.2.
             D181, D182, D186, D187, and D188: All five are closed at their cause.

     Ledger: Agreed and Disputed Across D180 to D193

      Item                State                  Summary

      D181, D182,
      D186, D187,         Agreed                 Closed at their cause; no remaining design or text defects.
      D188
                                                 Core reader-cut principle is right, but: (1) cuts must bind per
      D189                                       replay stream only on valid attempts that pass start and
      (replaces           Disputed               complete the day (Finding 1.1); (2) dropping D180's 30-day
      D180: a day         (design &              write-timestamp filter restores an operator timing lever after
      is read             text)                  day 31 and can break chained across cuts (Finding 1.2); (3)
      once)                                      byte cuts must specify complete frames/lines and M1 chain
                                                 sorting after key deduplication (Finding 1.3).
                                                 Cannot add a false discovery, but must update the e691341
      D190 (dated
                          Disputed               commit pointer for briefs/4-study-2.md (or inline the
      criteria
                          (text)                 keys/order), align with the abort fallback in "The days run", and
      revision)
                                                 allow a 0-day horizon in Feb 2027 (Finding 2.1).
      D191 (with
                                                 Trusted-launch boundary is accepted; specify
      D183:
                          Disputed               (_mm_getcsr() & 0xFFC0) == 0x1F80 so sticky exception
      trusted
                          (text/spec)            flags (0..5) do not trigger E_FPENV, and re-exec via
      launch &
                                                 /proc/self/exe iff environ[0] != NULL (Finding 5.1).
      MXCSR)
                                                 Series, remainders, nanBits cap, and overflow/underflow
      D192                                       edges are mathematically sound, but: (1) bitsOps.exp =
      (replaces           Disputed               Exact.exp ∧ bitsOps.log = Exact.log must be in X4's
      D184: Law           (proof                 theorem, not just a comment, and nearestBits must be
      X4 exp and          contract)              verified on subnormals/overflow/monotonicity (Finding 3.1); (2)
      log)                                       Test 12's 2 × 106 calls require the early-stopping proof or
                                                 @[csimp] twin at Step 5 (Finding 6.1).

11/17/26, 10:56 AM                                       Audit and Vulnerability Analysis of D189 and D190

      Item                State                  Summary

      D193
                                                 Full-stream comparison against the MPFR-backed reference
      (replaces
                          Disputed               closes GPT 4.1–4.2 at the cause; specify mpfr_subnormalize
      D185: B4's
                          (test spec)            in the shared C stub and per-argument glibc(x) !=
      MPFR
                                                 mpfr(x) comparison in Test 13's diagnostic report (Finding 4.1).
      reference)


