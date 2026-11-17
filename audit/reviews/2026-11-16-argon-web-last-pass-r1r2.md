# Argon on the architect's rounds 1 and 2 (D161 to D179)

Model Gemini 4 Argon in the Gemini web UI, given the self-contained bundle `argon-last-pass-r1r2.md` (574 KB, 16 files, built from `rearchitecture` `d7a9ba2`), in three parts. Saved by the human as a PDF on 2026-11-16 at 18:43 EST (23:43 UTC). Converted with pdftotext, with page furniture, blank runs and stray characters removed. The text is otherwise verbatim.


    Security Findings on System Rules and
    Builds
    https://gemini.google.com/app/3552ea2f43128298

    User prompt: See attached instructions.
    Response: 1. Attack on D175 and D176 (Replay Closure, Earliest-Pull Funding, and Byte-for-
    Byte Prefix Check)
    Finding 1.1 — Delisted or halted universe coins wedge D175's funding-closure rule forever,
    or let a later pull mutate a closed day and trigger D176's permanent stop
            What it breaks: D175's funding-closure rule ("settled funding [has closed a midnight] once
            every universe coin then listed has every hour before it, held or not"), Brief 3's recorders
            table ("runs no day in which a universe coin then listed lacks an hour"), and D176's early-
            termination rule.
            Concrete construction: Consider two readings of "every universe coin then listed has
            every hour before it" for a midnight T1 ending day d:

                    1. Reading A ("then listed" evaluated at each hour H < T1 ): Coin X is delisted by the

                       venue at 10:45 UTC on day d, so the venue never emits a fundingHistory
                       settlement for 11:00 UTC. Because meta is copied hourly (lag = 3,600,000 ms, V3),
                       the copy recording the delisting is taken at 11:15 UTC, so in the market's listing events
                       Coin X remains listed at 11:00 UTC. Similarly, if the venue halts for an hour or omits
                       one coin's fundingHistory row while the replica is flat (pos = 0), the engine's
                       R_SETTLEMENT_MISSING check would not abort (A9 only requires due hours for held
                       coins), yet D175 demands a fundingHistory row for every listed coin whether held
                       or not. Because no pull ever contains (Coin X, 11:00), midnight T1 and every           

                       subsequent midnight in the 730-day test never close.
                    2. Reading B ("then listed" evaluated at midnight T1 ): Coin X is delisted at 12:00 UTC

                       on day d (listing, the end at 12:00). Pull 1 (taken after T1 ) holds all 24 hours for

                       the 16 coins still listed at T1 , but is missing Coin X's 11:00 row (when Coin X was still

                       listed, and flat in the replica). Under Reading B, T1 closes because Coin X is not listed

                       at T1 , and Replay 1 completes day d without (Coin X, 11:00). Pull 2 later fetches

                       (Coin X, 11:00). Because Pull 2 is the earliest pull that holds a row for (Coin X,
                       11:00), Replay 2 reads it. That row changes Coin X's coin report row (events,
                       funding, sum1..3) and adds a funding trace row before T1 . D176's byte-for-byte

                       check then fails on Replay 2, and because recorded files are never rewritten, the
                       cause cannot be undone and the forward test terminates at day d − 1 for nothing.

11/16/26, 6:43 PM                                                Security Findings on System Rules and Builds

            Outcome it could change: Terminates the forward test early (preventing CS2.1 from
            reaching 730 days and leaving CS2.2 or CS2.3 "not judged") on an honest record where the
            replica wasn't even holding the coin.
            Classification: Design defect in D175's unconditional "held or not" funding-closure
            requirement and its interaction with hourly meta copies.
    Finding 1.2 — Websocket recorder file rotation by receipt time versus engine ordering by
    venue time causes cross-midnight spillover that breaks D176
            What it breaks: D175 ("The recorder has closed [a midnight] once it has opened a later
            hour") and D176's byte-for-byte prefix check across replays.
            Concrete construction: A trade or quote occurs on the venue at T1 − 5 ms                             

            (23:59:59.995 UTC) and arrives over the websocket 20 ms later at T1 + 15 ms                              

            (00:00:00.015 UTC), after the recorder has rotated and opened the 00:00 hour file at
            T1 + 1 ms. The event is written into the 00:00 file (hour ≥ T1 ) with venue timestamp
                                                                                                        

            time = T1 − 5 ms < T1 .
                                            

                    If Replay 1 for horizon [wstart , T1 ) selects recorder files by hour name < T1 (up to the
                                                                                                                           

                    23:00 file), or runs right after the 00:00 file opens before the zstd block containing
                    the T1 + 15 ms message is flushed, Replay 1 omits the event at T1 − 5 ms.
                                                                                                                        

                    Replay 2 for horizon [wstart , T2 ) (T2 > T1 ) reads the closed 00:00 file, and mm2's
                                                                              

                    merge feeds the event at T1 − 5 ms before T1 .
                                                                                       

                    Replay 2's report (events, price, sum1..3 in day T1 's coin row) and trace (an extra

                    print row at T1 − 5 ms) differ from Replay 1's before T1 's day rows, firing D176 on
                                                                                                            

                    an honest record and ending the study early.
            Outcome it could change: Permanent early termination of CS2.1–CS2.3 on an honest
            recording.
            Classification: Design defect in D175 (closing midnight T1 when the 00:00 file is merely

            opened, without waiting for network-skew spillover into the 00:00 file to flush and
            requiring the reader for horizon T1 to read that spillover window).

    Finding 1.3 — D175's copy-closure rule and CS2.3's once-only judging ignore the 30-day
    rolling re-read of userFillsByTime
            What it breaks: D175 ("a copy [has closed a midnight] once it holds a later copy"), CS2.3
            ("Judged once, at the first replay after the 61st judged day is run"), and Brief 3's 30-day
            late-fill recovery.

11/16/26, 6:43 PM                                            Security Findings on System Rules and Builds

            Concrete construction: Suppose the 61st judged midnight T61 falls at the end of a month  

            (e.g., March 31, if the freeze is January 29, or whenever a monthly replay runs within 30
            days after T61 ). One hour after T61 , the hourly userFillsByTime collector writes a copy
                                                    

            stamped > T61 , so D175 declares T61 closed. However, Hyperliquid's API indexes a partial
                                                              

            exit fill on day 60 (or an entry fill on day 60) 48 hours late—inside the 30-day daily re-read
            window specifically built for V18.
                    If Replay k runs on day 62 (after T61 is closed by D175, but before day 63's 30-day

                    re-read fetches the late fill), chained (M4) sees a gap in startPosition on day 60
                    and marks CS2.3 "not judged" forever (or, if a whole round trip was indexed 48 hours
                    late, entries omits it and changes the CS2.3 match verdict), without triggering D176
                    because userFillsByTime is not in the replica's report or trace.
                    When day 63's re-read appends the late fill, a later replay sees a different
                    userFillsByTime record for days 1..61 than the one judged.

            Outcome it could change: Flips CS2.3 between "met", "not shown", and "not judged", or
            changes day 1..61's vault entries between replays while passing D175 and D176.
            Classification: Design defect in D175 (closing userFillsByTime for CS2.3 after one
            hourly copy rather than after its 30-day re-read window, and excluding the vault fills'
            replay rows from D176).
    Finding 1.4 — D176's slice boundary ("up to the last day rows") is undefined on the trace
    and omits the last day's account row
            What it breaks: D176's prefix check specification in ledger.md and the Round 2 report.
            Concrete construction: In KERNEL.md A19, at midnight T1 , the report writes day T1 's                          

            coin rows (at = day), then day T1 's account row, and in Replay 1 (w_end = T1 ) finish
                                                                                                                   

            then appends the closing span rows (at = span) at T1 . Stopping the comparison "up to

            the last day rows" omits day T1 's account row (equity, absorbed, funding, stale,

            open). Furthermore, the trace has no day rows at all (its row kinds are print, funding,
            end, tick, and effects; and since [wstart , T1 ) is half-open, Replay 1 has no tick at T1
                                                                                                                              

            whereas Replay 2 does).
            Outcome it could change: Either false-positive D176 failures at T1 on the trace                 

            (comparing Replay 1's EOF against Replay 2's rows at T1 ) or leaving day T1 's account row
                                                                                                               

            unchecked.
            Classification: Text defect (the slice boundary must be: in the report, through the
            account row of Replay 1's last midnight T1 ; in the trace, all rows with time < T1 ).
                                                                                                                       

    2. Attack on D177 (Nix Derivation Hash as the Build Identity)

11/16/26, 6:43 PM                                 Security Findings on System Rules and Builds

    Finding 2.1 — Hashing the stand-in derivation does not commit to how the flake function
    builds the real derivation
            What it breaks: A13 and Step 9 Wall 5 ("The build's hash is the store path's hash of that
            same derivation given a fixed stand-in for the windows (the empty list) and no hash, which
            Nix computes without building it").
            Concrete construction: Let the flake's package builder be mkExec { windows_text,
            build_hash }. By Step 9 Wall 5, the build hash H is the store-path hash of
            drv_standin = mkExec { windows_text = "[]", build_hash = "" }, while the
            actual executable is compiled by a second evaluation drv_real = mkExec {
            windows_text = W, build_hash = H }.

                    Because flake.nix is the evaluator that produces the derivation attribute set and is
                    not hashed inside drv_standin except via the attributes drv_standin receives,
                    any expression in flake.nix that branches on build_hash != "" or
                    windows_text != "[]" (e.g., moreLeancArgs = if build_hash == "" then
                    [] else ["-ffast-math"]) produces the exact same drv_standin and
                    therefore the exact same build hash H , while compiling drv_real with different
                    flags or sources.
                    Even without an intentional branch, H is an input-addressed .drv hash computed
                    without building drv_standin, and nix eval produces the exact same H whether
                    drv_real is built with sandbox = true, sandbox = false, or different
                    NIX_BUILD_CORES (which Nix passes into the sandbox without changing .drv).

            Outcome it could change: Two executables with identical build hash H can compute
            different float values, wishes, and CS2.1–CS2.3 verdicts.
            Classification: Design/text defect (Step 9 Test 10 must verify that drv_real's serialized
            .drv ATerm is byte-identical to drv_standin's .drv ATerm after substituting the literal
            strings windows_text and build_hash in place of "[]" and "").
    Finding 2.2 — The runtime environment (envp) outside PATH is neither cleared nor hashed,
    allowing one executable to compute differently across runs
            What it breaks: D177's guarantee that one build hash determines what a run executes, and
            Step 9 Test 10 (which tests only an empty PATH).
            Concrete construction: Take a single compiled study2 / mm2 binary (identical derivation
            hash H , passing E_HOST at start). Run it twice on the same host with different
            environment variables:
                    Run 1 has a clean environment.
                    Run 2 sets LD_PRELOAD (or LD_AUDIT, which the Nix store's dynamic linker ld-
                    linux-x86-64.so.2 honors for any non-setuid binary), or sets GLIBC_TUNABLES

11/16/26, 6:43 PM                                Security Findings on System Rules and Builds

                    affecting a non-probed math/allocator path after startup, or sets TMPDIR /
                    OCAMLRUNPARAM affecting DuckDB's on-disk spill/merge or OCaml's runtime. Neither
                    study2 nor mm2 scrubs envp via clearenv() / execve(..., empty_env) at
                    startup.
            Outcome it could change: Different wishes, fills, or aborts from the exact same
            executable binary and registered build hash.
            Classification: Design defect (study2 and mm2 should scrub their environment at startup
            and pass an empty environment when spawning child processes).
    What I accept in Part 1:
            D175's core principle: Append-only pull files and reading the earliest pull's row for each
            (coin, hour) to prevent upstream funding revisions from rewriting past days.

            D176's fail-closed prefix invariant: Checking byte-for-byte prefix identity before
            publishing any replay.
            D177's replacement of gen.ml with Nix's derivation: Using the Nix derivation rather than
            a hand-maintained file/directory list, once drv_real vs. drv_standin equivalence and
            runtime envp scrubbing are enforced.
    PART 1 END

    User prompt: continue
    Response: 3. Attack on D178 (Startup Host Probe E_HOST)
    Finding 3.1 — Single-argument exp and log probes only provide 1 bit of discrimination per
    function and cannot separate more than two IFUNC/libm paths
            What it breaks: D178, A13 ("every run computes the stage 6 reference's exp and log, and
            D1 is of the hosts that pass"), and Brief 3 Step 9 Test 8.
            Concrete construction: The architect measured exp and log on a single host under two
            settings—default (FMA enabled) and GLIBC_TUNABLES=glibc.cpu.hwcaps=-FMA—over
            4 million arguments, finding 2,446 arguments where exp differs by 1 ULP and 1 argument
            where log differs by 1 ULP.
                    In glibc's x86-64 multiarch libm (sysdeps/x86_64/fpu/multiarch/e_exp.c and
                    e_log.c), IFUNC dispatch selects among more than two code paths:
                    __ieee754_exp_fma (FMA3), __ieee754_exp_fma4 (AMD FMA4),
                    __ieee754_exp_avx (AVX without FMA, which is what hwcaps=-FMA selects on an
                    AVX host), and __ieee754_exp_sse2 (baseline SSE2 when AVX is also absent or
                    masked), in addition to non-x86 architectures or patched glibc builds.
11/16/26, 6:43 PM                                        Security Findings on System Rules and Builds

                    Every faithful table-driven exp or log implementation has error < 0.55 ulp.
                    Consequently, at any probe input x0 where __exp_fma(x_0) !=

                    __exp_avx(x_0), the true value exp(x0 ) lies in the narrow table-maker's dilemma

                    band around a midpoint (m + 1/2) ulp, and every faithful implementation outputs
                    one of only two bit patterns: blow or bhigh .
                                                                      

                    By the pigeonhole principle, testing one fixed input x0 for exp and one fixed input z0
                                                                                                            

                    for log provides only 1 bit of discrimination per function. A third host path—such as
                    pure SSE2 (glibc.cpu.hwcaps=-FMA,-AVX or a VM exposing baseline x86-64
                    without AVX) or FMA4—that rounds to the same side of the midpoint as _fma at
                    (x0 , z0 ) passes the E_HOST check at start and then computes a 1-ULP different
                           

                    exp(x_1) or log(z_1) at other midpoint-adjacent arguments during the run.

            Outcome it could change: A trigger or slot reading when: gt(exp(x_1), threshold)
            or price: exact(exp(x_1)) evaluates differently on two hosts that both pass E_HOST,
            changing wishes, fills, and judged CS2.1–CS2.3 outcomes.
            Classification: Design defect in D178 (probing one input per function distinguishes two
            paths, not the full multiarch selector or CPU feature set).
    Finding 3.2 — A host with MXCSR Denormals-Are-Zero (DAZ = 1, FTZ = 0) or directed
    rounding passes the startup probe and computes different floats during the run
            What it breaks: D178's startup check ("compute exp, log and a subnormal product at
            arguments where the paths differ... A host that gives other bits than the path B4 passed on
            is refused (E_HOST)").
            Concrete construction: On x86-64, the MXCSR control register has separate control bits
            for subnormal outputs (FTZ, bit 15), subnormal inputs (DAZ, bit 6), and rounding mode (RC,
            bits 13–14):
                    Case A (DAZ = 1, FTZ = 0): Suppose the startup probe checks "a product that is
                    subnormal" by multiplying two normal floats, such as DBL_MIN * 0.5 (2−1022 ×
                    0.5 = 2−1023 ), and checks exp(x_0) and log(z_0) at normal arguments. Because
                    the inputs are normal and FTZ = 0, the CPU produces the exact non-zero subnormal
                    output 2−1023 (0x0008000000000000) and identical exp/log bits, so the executable
                    passes E_HOST. During the run, whenever that subnormal result s = 2−1023 is fed as
                    an input into another float operator (mul(s, 2.0), add(s, 0.0), or gt(s, 0.0)),
                    DAZ = 1 flushes the input s to +0.0, turning gt(s, 0.0) from true to false.

                    Case B (Rounding mode RC != 00): If the probe's subnormal product is an exact
                    power of two (DBL_MIN * 0.5), it is invariant to rounding mode; and if the chosen
                    probe arguments (x0 , z0 ) happen to be ones where _fma in FE_TONEAREST rounds
                                                    

                    down (toward zero), a process started with fesetround(FE_TOWARDZERO) or

11/16/26, 6:43 PM                                   Security Findings on System Rules and Builds

                    FE_DOWNWARD returns the exact same bits on all three startup probes while changing
                    div (1.0 / 3.0), sqrt, add, and mul across the evaluator.

            Outcome it could change: Changes float evaluation, when conditions, exact(·)
            crossings, and CS2.1–CS2.3 verdicts on a host that passes E_HOST.
            Classification: Design defect in D178 (the probe must either read/enforce MXCSR directly
            via C stub or test a subnormal input such as (DBL_MIN * 0.5) * 2.0 == DBL_MIN and
            non-exact rounding cases 1.0 + 2^-53 and -1.0 - 2^-53).
    4. Attack on D174 (Deleting the Cash Grid; Unbounded Exact Denominators)
    Finding 4.1 — Step 10 Test 14 still hardcodes the deleted 1/2 * 10⁻⁵⁰ cash grid, and Test
    3's replacement denominator invariant is false on general confirm inputs and across
    listing changes
            What it breaks: Brief 3 Step 10 Tests 3 and 14, and D174's claim that all grid dependencies
            were removed.
            Concrete construction: Two places in Brief 3 Step 10 still rely on broken denominator
            assumptions:
                    Test 14 still requires the deleted grid: Step 10 Test 14 states: "A rule trades at
                    prices alone, so its cash is a whole multiple of half of 10⁻⁵⁰ and its units whole test
                    lots after every trade". If guard is run on off-grid price reports (such as Test 13's
                    simulated null paths where prices are 100 * (5/4)^k), or if a listing settles at a
                    non-decimal rational in a fixture, Test 14's 1/2 * 10⁻⁵⁰ assertion fails.
                    Test 3's new denominator rule is false as stated: Step 10 Test 3 states: "on random
                    runs its cash's denominator divides twice 10⁵⁰ times the units in lots of each fill of
                    several prices it copied (kernel A12)". First, in Step 10 Test 1, random runs of confirm
                    test "fee rates over the whole of 0 to 1"; any rational fee rate whose denominator does
                    not divide 1012 violates Test 3 even when every fill is at a single price. Second, if a
                    listing event changes sz_decimals during a run (Step 5 Test 9), "the units in lots of
                    each fill" depends on the sz_decimals in force at that fill, which is not in the flow
                    rows passed to confirm.
            Outcome it could change: Causes Step 10's property tests (Tests 3 and 14) to fail during
            the build.
            Classification: Text defect in Brief 3 Step 10 Tests 3 and 14.
    Finding 4.2 — D174's 381-bit measurement understates denominator growth on the
    replica's gtc ladder, in held (CS2.2), in the Step 5 bootstrap, and in Step 10 Test 13's
    20,000 off-grid null paths

11/16/26, 6:43 PM                                                                           Security Findings on System Rules and Builds

            What it breaks: D174's resource bound ("takes the denominator from 168 bits to 381"),
            held (CS2.2), Step 5's bootstrap, and Step 10 Test 13.

            Concrete construction: The architect measured 381 bits on the vault's 46 multi-price
            taker fills out of 748 takes over 7 months, where level and exit orders were almost always
            makers (1.8% and 1.0% takers). That understates denominator growth in four places:
                    1. The replica's gtc ladder and ioc/gtc entries: In Brief 4 Step 2 Wall 3, all 5 levels
                       (up to 1, 468 USD) and the exit (2, 779 USD) are gtc with a 1-second delay (λ =
                       1, 000 ms). Whenever a level, exit, or entry arrives at a book that moved across its
                       limit, it sweeps multiple levels as a taker. On a coin with sz_decimals = 5 at price
                       $1, one sweep of 100–2, 779 USD is Lk ∼ 107 –2.7 × 108 lots (∼ 24–28 bits).                     

                       Because confirm rounds trade sizes down to whole test lots (10−30 ), the prime
                       factors of Lk do not cancel and remain in cashtest 's denominator across cycles for
                                                                                                                                      

                       the entire 212-day or 730-day run. Over hundreds of multi-level sweeps, the cash
                       denominator grows to thousands of bits.
                    2. held (CS2.2) exact variance blowup: On day t, let Wt = At /Bt . The daily return                                                      

                       rt = Wt /Wt−1 − 1 = (At Bt−1 − Bt At−1 )/(Bt At−1 ) puts the previous day's
                                                                                                                                           

                       numerator At−1 into the denominator of rt . Because At−1 is a changing ≥ 381-bit
                                                                                                                                                     

                       (or multi-thousand-bit) integer coprime across days, the exact rational mean rˉ =
                         1    212                   1     212
                        212 ∑t=1 rt and variance 212 ∑t=1 (rt − r
                                          
                                                                    ˉ)2 in held have denominators equal to
                                                                                                             

                       the LCM of {(Bt At−1 )2 }212
                                                  t=1 , which is ≥ 2 × 212 × 381 ≈ 160, 000 bits even at
                                                                                  

                       381 bits/day (and millions of bits on the replica), all of which must be reduced via gcd
                       and printed in the report.
                    3. Step 5's 730-day block bootstrap: Multiplying block wealth factors
                       Wend(m) /Wstart(m) across K blocks of a 730-day bootstrap path multiplies the
                                                               

                       running denominator by Astart(m) Bend(m) at every block boundary without                           

                       cancellation across 30 (φ, d) pairs × thousands of paths.

                    4. Step 10 Test 13's 20,000 off-grid null paths: As noted in Step 10's wall, a simulated
                                                    k
                       null path's prices Pk = P0 ∏i=1 (1 + ri ) leave every decimal grid after a few events.
                                                                                                                

                       Over 730 days of price and funding events per path, exact rational prices accumulate
                       Θ(k)-bit denominators, and folding confirm's exact cash across 20,000 paths of
                       730 days triggers quadratic/cubic Rat.add gcd reductions at every trade and
                       funding row.
            Outcome it could change: Can stall or OOM Step 10 Test 13, Step 5's bootstrap, or held,
            and bloats the report's exact rational variance strings to hundreds of kilobytes.
            Classification: Design/performance defect in held, the bootstrap, and Step 10 Test 13
            when combined with unrounded rationals.

11/16/26, 6:43 PM                                    Security Findings on System Rules and Builds

    What I accept in Part 2:
            D178's motivation: Detecting host libm/FPU mismatches at startup via E_HOST rather
            than assuming a Nix derivation controls the host CPU.
            D174's core decision: Deleting the false 1/2 * 10⁻⁵⁰ cash grid from A12 and K1 rather
            than rounding the test ledger's cash or splitting one fill row into multiple rows.
    PART 2 END

    User prompt: continue
    Response: 5. Attack on Round 1 (D161–D163, D167, and D172 with D179)
    Finding 5.1 — D162's reduce_only remainder cap makes every reduce_only order with
    target − filled ≥ pos satisfy "opens nothing and closes the position exactly",
    contradicting A6's dust-minimum rule; and the Laws.lean spec of offer omits the
    remainder = 0 no-op guard

            What it breaks: A6's minimum-notional condition ("its remainder's notional is at least the
            venue's minimum, 10 USD, unless it opens nothing and closes the position exactly... The
            minimum is the venue's, and a remainder under it is refused there too; a program closes
            dust with close"), R1, and the Round 1 report's Laws.lean specification of Move.offer.
            Concrete construction:
                    1. Dust minimum bypass vs. close: Suppose Coin A has a dust long position pos =
                       0.05 coins at price 100 (notional $5 USD < 10 USD minimum). A reduce_only sell
                       slot with an explicit target size = 10 coins (not "close") and filled = 0 arrives
                       at A6. Under D162, prepare sets the order's remainder to min(10 − 0, 0.05) =
                       0.05 = pos. Because its remainder equals pos, filling its remainder opens nothing
                       and closes the position to zero! If A6's admission exception ("unless it opens nothing
                       and closes the position exactly") tests whether filling the remainder brings pos to
                       zero (remainder == reducible), then every reduce_only order with target -
                       filled >= reducible is exempt from the 10 USD minimum—contradicting A6's
                       statement that a remainder under 10 USD is refused and a program must close dust
                       with close. Conversely, if admission only exempts size = "close", then a
                       reduce_only order with target = 0.05 (which also opens nothing and closes the
                       position) is refused, making A6's stated condition inaccurate.
                    2. Live reduce_only order with remainder = 0 at offer: When a non-
                       reduce_only order flips a long position +3 to short -2 without hitting 0, a resting
                       reduce_only sell stays live with dynamic remainder = 0
                       (step5_11_reduce_only_in_remainder). In the Round 1 report's Laws.lean
                       specification, Machine.offer says: "With no live order, or with the coin stale at the

11/16/26, 6:43 PM                                  Security Findings on System Rules and Builds

                    last fed event (before its first quote included), the move does nothing", omitting the
                    guard that offer also does nothing when the live order's dynamic remainder is 0
                    (without which offer would pass 0 units to Ledger.step, failing E_FILL, or treat
                    the order's remainder reaching zero as finishing the order and removing it from the
                    book).
            Outcome it could change: Admits or refuses dust reduce_only orders contrary to
            A6/R1, or cancels a resting reduce_only order while the position is temporarily flipped.
            Classification: Design/text defect in A6's minimum condition (which should state unless
            its target is close, or else intentionally exempt capped reduce_only remainders)
            and text omission in the Round 1 report's Laws.lean comment for offer.
    Finding 5.2 — L1's "a day's end's rows at t" (D167) must explicitly include the account row
    at t, and finish at horizon.end = T vs. events at T requires filtering by row kind, not
    timestamp
            What it breaks: L1's statement in kernel-v2.md B3 and Brief 3 Step 7 Wall 3 / Step 9
            Test 10.
            Concrete construction: Let Run 1 have horizon.end = T (a UTC midnight) and Run 2
            have horizon.end = T_2 > T, agreeing on all events with time < T, while Run 2 also
            has a funding event or quote at time = T. At timestamp T, Run 1 writes coin rows (at =
            day), the account row, and coin rows (at = span), whereas Run 2 writes coin rows (at
            = day), the account row, and then flow or coin (at = span) rows from events at T.
            Because KERNEL.md A19 only tags coin rows with at = day (the account row has kind
            account and no at field), formalizing "a day's end's rows at t" in Laws.lean as rows with
            at = day omits the account row at T (which holds equity, absorbed, funding, stale,
            and open), whereas formalizing it by timestamp time ≤ T is falsified by Run 2's flow
            rows at time = T and Run 1's span rows at time = T.
            Outcome it could change: Leaves the daily account row unprotected by L1 or makes L1
            unprovable when events occur on the midnight boundary T.
            Classification: Text defect (L1 and D176 should specify: all report rows with time < t,
            plus at midnight t the coin rows with at = day and the account row).
    Finding 5.3 — KERNEL.md A19's per-millisecond stale and open fields (D172) are
    ambiguous at the millisecond a quote ends a stale gap, and guard rebalances on stale
    coins throughout holes while the replica is frozen
            What it breaks: KERNEL.md A19's definition of stale and open in the account row, and
            D172/D179's interpretation of holes in the replay.
            Concrete construction:

11/16/26, 6:43 PM                                      Security Findings on System Rules and Builds

                    1. Sub-millisecond staleness transition: By A3 and Brief 3 Step 3 Test 4, when a
                       quote at millisecond t ends a stale gap, a print at millisecond t (ordered before the
                       quote) sees the world as stale, whereas the quote itself and any wish arriving at
                       millisecond t (ordered after the quote by A18) see the world as not stale. If an
                       arriving wish at millisecond t places an order, or if the quote at t fills an arriving ioc
                       closing a position, the world is stale during the first part of millisecond t and fresh
                       during the second part. KERNEL.md A19 defines stale as "the share of the day's
                       milliseconds... in which the world held the coin stale" and open as 1 when "the coin
                       had a position or a live order in one of the milliseconds in which the world held it stale",
                       without specifying whether a millisecond's staleness and open state are evaluated
                       after all events of that millisecond or across sub-millisecond steps.
                    2. Asymmetry between the replica and guard during holes: During the July week-
                       long hole and TON's 138-day book outage (2026-06-16 to 2026-10-31), TON still
                       has fundingHistory events (and potentially prints), which are price events. While
                       A3 forbids the replica from filling any order on a stale coin (freezing any open TON
                       position for 138 days with Wᵇ anchored to June 15's bid, or blocking entries if flat),
                       guard (B1) has no staleness check and rebalances its constant mixes across all 17
                       coins at every clock tick on print and funding prices throughout the holes.
            Outcome it could change: Off-by-one millisecond discrepancies in stale and false
            positives in open on the millisecond a gap ends; and guard refusing Rung 2 on the replay
            due to trading during holes where the replica is barred from trading.
            Classification: Text defect for A19's millisecond boundary (pinning stale and open in
            millisecond t to the state at the end of millisecond t, i.e. whether no quote existed in (t −
            G, t]), and a disclosed model property for guard.

    What I accept in Round 1 (D161–D173) and Round 2 (D179):
            D161 & D163: Making an order's fill at an event one atomic move (offer taking List (Nat
            × Rat)), with one fee, one fill/flow row at notional over units, and one cycle-end check
            at the end of the order's walk, while keeping cycle-end cancellation across distinct orders
            at the same event (accepting GPT's qualification of my Part 1 Finding 1.1), and folding "no
            quote yet" into the stale guard.
            D162: Moving the reduce_only bound into prepare's remainder so zero-unit cuts and
            reduce_only cancellations disappear, once Finding 5.1 is addressed.

            D164, D165, D166, D168, D169, D170, D171 (scope), D173: Refusing marketable alo before
            walking the book and crediting resting orders on optimistic quotes (D164); testing slot
            order in Step 6 and deleting R1's false idempotence (D165); stating X1 over exactValues
            (D166); renaming observations via Config.rename at parseHeader, adding wishes to
            N1/L3, and accepting GPT's qualification that Program.redirect need not rewrite slot
            roots (D168); separating L2's exact typing from bitsOps crossings and defining

11/16/26, 6:43 PM                                  Security Findings on System Rules and Builds

            bitsOps.finite on integer bits (D169); withdrawing the cross-tier conservatism claim
            for adverse marks under V6 (D170); placing study2 and the readers inside the build while
            keeping collectors outside (D171); and reporting Layer 2's stale-span fill counts by role and
            cadence period (D173).
            D172 & D179: Reading the replay as recorded (holes included), defining open as overlap
            with staleness, and reporting each period's stale share beside CS2.2's variance ratio.
    Ledger: Agreed and Disputed

      Item                       State             Summary

      D161, D163–D166,
                                                   Closed at the cause; GPT's two qualifications of Argon
      D168–D171
                                 Agreed            Part 1 (1.1 across orders, 2.2 on Program.redirect)
      (scope), D173,
                                                   are accepted.
      D179
                                                   Remainder cap is right, but A6's minimum-notional
      D162                       Disputed          exception must state whether it exempts only size =
      (reduce_only in            (minor            "close" or any reduce_only order with remainder
      remainder)                 design/text)      = reducible, and Laws.lean's offer spec must
                                                   state the remainder = 0 no-op guard (Finding 5.1).

      D167 & D176 (L1                              The prefix slice at midnight T must explicitly include
      and replay slice           Disputed (text)   day T 's account row in the report and be defined as
      boundary)                                    time < T on the trace (Findings 1.4, 5.2).

      D172 (stale and                              Pin whether millisecond t's staleness and open
      open millisecond           Disputed (text)   overlap in A19 are evaluated after millisecond t's
      boundary)                                    events or across sub-millisecond steps (Finding 5.3).
                                                   Step 10 Test 14 still asserts the deleted 1/2 * 10⁻⁵⁰
                                                   grid; Test 3's denominator rule fails on arbitrary fee
                                 Disputed (text
      D174 (unbounded                              rates or listing changes (Finding 4.1); and exact
                                 &
      denominators)                                rational variance in held, Step 5's bootstrap, and Step
                                 performance)
                                                   10 Test 13's 20,000 off-grid null paths face severe
                                                   denominator blowup (Finding 4.2).

11/16/26, 6:43 PM                                Security Findings on System Rules and Builds

      Item                       State           Summary

                                                 Unconditional "held or not" funding closure wedges
                                                 forever if a coin is delisted mid-hour or misses an
                                                 unheld funding row (Finding 1.1); recorder hour-
      D175 (replay               Disputed
                                                 opening misses network-skew spillover across
      closure rules)             (design)
                                                 midnight (Finding 1.2); and closing userFillsByTime
                                                 after one hourly copy ignores the 30-day late-fill re-
                                                 read for CS2.3 (Finding 1.3).
                                                 Step 9 Test 10 must verify that the real .drv equals
      D177 (Nix                  Disputed        the stand-in .drv up to substituting windows_text
      derivation hash)           (design/test)   and build_hash (Finding 2.1), and executables must
                                                 scrub envp at startup (Finding 2.2).
                                                 Single-argument probes only give 1 bit of
                                                 discrimination and cannot separate all multiarch libm
      D178 (startup host         Disputed
                                                 paths (e.g., SSE2 vs. AVX vs. FMA) (Finding 3.1), nor do
      check E_HOST)              (design)
                                                 they catch DAZ = 1, FTZ = 0 or directed rounding
                                                 modes in MXCSR (Finding 3.2).


