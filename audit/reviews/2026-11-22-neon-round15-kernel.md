# Neon on round 15's kernel half

Model Gemini 4 Neon through the Gemini web UI (the human pasted `neon-r15-kernel-bundle.md`, 397 KB, and its prompt; reply saved as `r15-kernel.pdf`, 2026-11-22 21:06 UTC (16:06 EST)). Neon did not author round 15. Extracted by `pdftotext -layout`:

```text
11/22/26, 4:02 PM                                                 See attached instructions



    See attached instructions
    https://gemini.google.com/app/fca5f84335fc034a

    User prompt: See attached instructions

    Response: Finding 1. Observation (L1c): L1c enforces only a lower bound on view freshness,
    allowing zero-delay / early delivery of own-state arrival effects (EarlyViewApply) (design
    defect)
          What it breaks: B3 L1c's claim that "the view's account is the world's δ earlier", A1 ("It holds an event from the
          event's known time, and an effect from the effect's time plus δ"), and A5 ("Own-state inputs are computed from the
          effects the view holds, so they lag the world by δ").
          Construction: Round 15's L1c asserts at every tick r ∈ run.ticks:
          r.world = r.queue.foldl (apply) r.account ∧ ∀l ∈ r.queue, r.time < l.known ∧ l.known = l.time + δ

          This enforces a lower bound on how up-to-date r.account is (no effect with l.time + δ ≤ r.time may remain in
          r.queue), but no upper bound: r.queue = [] with r.account = r.world trivially satisfies both conjuncts even
          when effects with l.time + δ > r.time have already been applied to r.account.

          Take tick = 1000, decide_every = 1, δ = 1000, λ = 500 (or δ = 1500, λ = 0), with two slots: entry (slot 0,
          active at τ = 0) and follow (slot 1, when := resting(0) > 0). In a buggy (subject) arriveWish, whenever λ >
          0 (leaving L1c's λ = 0 witness untouched) and st.queue = [], arriveWish applies the arrival's placed (or
          cancelled) effect directly to both st.acct (world) and st.viewAcct (view), pushing nothing onto st.queue. No
          shadow field is added (frozen.txt is unchanged).
                At τ = 0, entry sends wish w0 (sent = 0, arrives = 500).
                At t = 500, w0 arrives and places entry. Its effect should become known at 500 + 1000 = 1500, so at τ =
                1000 resting(0) must still be 0. Instead, EarlyViewApply mutates both st.acct and st.viewAcct at t
                = 500, leaving st.queue = [].

                Check every Round 15 law at τ = 1000:
                      L1c: r.world = r.account and r.queue = [], so both the foldl equality and the universal
                      quantifier over r.queue hold trivially. L1c's witness has λ = 0 and passes.
                      L1a: At τ = 1000, τ − δ = 0. Wish w0 was sent at τ = 0, determined solely by events with known ≤
                      0 and time ≤ −1000 — both subsets of L1a's two premises (known ≤ 1000 and time ≤ 0). Any es₁,
                      es₂ satisfying L1a's premises at τ = 1000 therefore emit the identical w0 at τ = 0, arrive it at t = 500,
                      and both deliver placed early into r.account at τ = 1000, yielding identical TickRecord.seen.
                      R1: a.after = worldBook st_after = (arrive a.before w0).1 holds; at τ = 1000, follow's
                      wish matches wishAt initial r 0 1 because r.account and r.exacts already see resting(0)
                      > 0.

                      L0, S1, X1, C1, C2, and frozen.txt: all pass.

          Outcome: Own-state inputs (resting(slot), resting_price(slot)) observe placements and cancellations up
          to δ early, causing dependent slots to fire early and changing fills and CS2.1–CS2.3 verdicts.
          Defect type & fix: Design defect in L1c. Record the world's emitted effects (run.effects or per-tick emitted
          effects) in the single observation and prove in L1c that at every tick r: (i) r.account is initial.acct folded over
          all effects emitted before tick r with l.time + δ ≤ r.time, (ii) r.queue is the exact list of effects emitted before
          tick r with r.time < l.time + δ (each having l.known = l.time + δ), and (iii) r.world is r.queue folded
          onto r.account. Add EarlyViewApply to checks.engine-proofs-fixtures.


https://gemini.google.com/app/fca5f84335fc034a                                                                                    1/7
11/22/26, 4:02 PM                                                 See attached instructions


    Finding 2. Observation (R1 & S1): Deleting run.admissions.Pairwise and
    run.placed.Pairwise does not follow from run.arrivals's chain — because run.admissions
    and run.placed are untied to run.arrivals, leaving S1's placement cooldown and X1's
    placement check vacuous (design defect)
         What it breaks: Round 15's claim that run.admissions.Pairwise and run.placed.Pairwise are "the chain's
         consequences", Round 15's fourth rule ("One observation, read as one run"), S1's cycle-restart causality bound
         (s.time + δ + λ ≤ p.order.placed), and X1's placement rounding clause on run.placed.
         Construction: In b94e128's Laws.lean together with Round 15's R1 diff, Run stores arrivals : List Arrival,
         admissions : List Admission, and placed : List Placement as three separate lists. Across R1, X1, S1, L0,
         L1a, and L1c, the only equation connecting run.admissions or run.placed to any other field is R1's
         run.admissions.filterMap (fun a => (admit a).toOption) = run.placed.map (·.order). No
         clause in any law ties run.admissions or run.placed to run.arrivals.
               First, run.admissions.Pairwise and run.placed.Pairwise are mathematically not consequences of
               run.arrivals.Pairwise and the arrival chain: run.admissions and run.placed can be arbitrarily
               permuted or emptied without contradicting run.arrivals.
               Second, a subject machine that executes arriveWish honestly on st.acct (so R1's arrival chain and L1c
               hold) while recording admissions := [] and placed := [] on every run other than the fixed step5Moves
               witness passes R1 ([] = []), passes X1 (∀ p ∈ [], ... vacuously), passes S1 (both p.order.cycle ≠
               s.before.cycle coin and s.time + δ + λ ≤ p.order.placed hold vacuously), and passes L0, L1a,
               L1c, and frozen.txt.

               In particular, a machine that drops a premature post-cycle-end placement from run.placed (while still
               placing it in st.acct and run.arrivals) violates A6's δ + λ cycle-restart bound while passing S1 and every
               other law.
         Outcome: Unchecked or premature placements after a cycle end (or out-of-order / dropped admission logs) evade
         S1 and X1, altering orders, fills, and CS2.1–CS2.3 verdicts.

         Defect type & fix: Design defect in R1. Tie run.admissions directly to run.arrivals inside R1 via the frozen
         specification functions (cancelSlot, prepare, admission): assert that run.admissions equals
         run.arrivals.filterMap of the admission records generated by every arrival that is not ended, is in the current
         cycle, is not same, and produces prepare cancelled a.wish = some o, keeping
         run.admissions.filterMap (fun a => (admit a).toOption) = run.placed.map (·.order). Once
         run.admissions is derived in order from run.arrivals, both deleted Pairwise clauses genuinely follow as
         corollaries, and run.placed cannot omit any order installed by run.arrivals. (While editing R1, also remove the
         unnecessary w.cycle ≤ b.cycle w.coin premise on arrive's characterization so arrive is specified for all
         (b, w) unconditionally.)

    Finding 3. Build boundary (environment walk): The 1-hop walk misses transitive trigger exposure
    through already-refused constants and unvalidated closed autoParam tactic names (design
    defect)
         What it breaks: B2's claim that check-source.lean's environment walk automatically proves the completeness
         of the name rule on every build (including future toolchain bumps) so no allowed identifier can reach autoParam,
         Lean.reduceBool, or Lean.reduceNat.

         Construction: Step 5x sub-step 1 specifies that check-source.lean walks every constant's type, every
         definition's value, and every alias in Init, failing unless "each constant that holds autoParam (its tactic argument),
         Lean.reduceBool or Lean.reduceNat (its argument) with that argument missing or holding a loose bound
         variable, and each alias to one, is a name the rule refuses."
             1. 2-hop transitive bypass (TransitiveTrigger): The walk checks only direct syntactic occurrences of the
                three root trigger constants (autoParam, Lean.reduceBool, Lean.reduceNat), not transitive references to


https://gemini.google.com/app/fca5f84335fc034a                                                                                    2/7
11/22/26, 4:02 PM                                                   See attached instructions


               already-refused constants that expose an open trigger. Lean 4.34.0 already contains two such refused
               constants (Lean.ofReduceBool and Lean.ofReduceNat). If Init (in a future toolchain or an extended
               environment) contains a refused helper def Lean.wrap (b : Bool) : Bool := Lean.reduceBool b —
               or directly wraps Lean.ofReduceBool — and a non-refused constant def Expose.wrap (b : Bool) :
               Bool := Lean.wrap b (or a mutually recursive pair where only one twin carries a Lean component):

                    The 1-hop walk checks Lean.wrap (or Lean.ofReduceBool), sees a direct open trigger, confirms the
                    name rule refuses it, and passes.
                    The 1-hop walk checks Expose.wrap, finds no direct occurrence of autoParam, Lean.reduceBool, or
                    Lean.reduceNat in its type or body, and passes.

                    A library module then invokes Expose.wrap myBadBool using only allowed identifiers and b94e128
                    syntax forms, and WHNF/kernel reduction unfolds Expose.wrap → Lean.wrap → Lean.reduceBool
                    myBadBool, executing compiled library code during lake build.

             2. Unchecked closed autoParam tactic names: The walk ignores autoParam α c whenever c is a closed
                Lean.Name literal (no loose bound variable). If any Init constant ever carries a closed autoParam whose
                tactic name c is not already declared in Init (and contains neither Lean nor autoParam), a library module
                could declare _root_.<c> and have the elaborator evaluate it via evalConstCheck.
         Outcome: A future toolchain bump introducing a 2-hop non-Lean wrapper over Lean.ofReduceBool,
         Lean.ofReduceNat, autoParam, or a Lean.* helper silently passes the build-time completeness audit, reopening
         arbitrary build-time execution (divergent compiled engine verdicts on CS2.1–CS2.3 or @[init] leakage of protected
         data).
         Defect type & fix: Design defect in check-source.lean's environment walk. Replace the 1-hop scan with a
         transitive fixed-point walk: seed exposed := {autoParam, Lean.reduceBool, Lean.reduceNat}and iterate
         to fixpoint, adding any constant whose type or definition value mentions anyd ∈
         exposed(conservatively anywhere, or wheneverdis under-applied or has a loose bound
         variable in an argument) and any alias targeting anexposedconstant; fail unless every
         constant and alias inexposedis refused by the name rule. Separately check that every
         closedNameliteral passed asautoParam's second argument in Initresolves to an existing
         constant inInit. Add a TransitiveTrigger fixture (Lean.wrap+Expose.wrap) to checks.engine-proofs-
         fixtures`.
    CONTINUE



    User prompt: continue

    Response: Finding 4. Observation (R1): a.before is untied across timestamps, letting
    arriveWish silently cancel a resting order before recording a.before (UnnecessaryReplace)
    (design defect)
         What it breaks: A6 ("if it equals the slot's live order in price and target, nothing changes"), A7 (resting orders fill on
         prints without re-arriving at the next quote), and Round 15's fourth rule ("One observation, read as one run").
         Construction: Round 15's restated R1 checks a.after = (arrive a.before a.wish).1 (with a.after =
         worldBook st_after) and chains consecutive arrivals only within the same millisecond (a.time = b.time →
         b.before = a.after). Nothing ties the first (or sole) arrival's a.before at a new timestamp t to worldBook of
         the state entering t (nor to prior CycleSteps or TickRecord.world).
         Take a coin with a live resting alo (or gtc) buy o_old at p = 100, target = 1, placed = 0, arrived at quote t =
         1 (bid = 99, ask = 101). At t = 1000, the deciding tick sends an identical wish w (price = 100, target =
         1, arrives = 1000), which is the first or only arrival at t = 1000. Suppose a buggy (subject) arriveWish —
         firing on tif = "alo" or w.slot > 0 or w.coin > 0, leaving step5Program's r1_witness untouched —


https://gemini.google.com/app/fca5f84335fc034a                                                                                        3/7
11/22/26, 4:02 PM                                                 See attached instructions


         cancels (w.coin, w.slot) on st first (emitting cancelled to both world and view queue), records a.before
         := worldBook st_cancelled, and then runs arrive on st_cancelled (placing o_new with placed = 1000
         and emitting placed to both world and queue) and records a.after := worldBook st_after.
               R1: In a.before, slot (w.coin, w.slot) is absent, so same is false, cancelSlot a.before c s =
               a.before, prepare a.before w = some o_new, admit succeeds, and (arrive a.before w).1 =
               install a.before o_new = worldBook st_after = a.after. Because w is the first arrival at t =
               1000, a.time = b.time → b.before = a.after never constrains a.before. Even with Finding 2 fixed,
               run.admissions and run.placed faithfully record o_new.

               L1c: Both cancelled and placed were applied to world and pushed onto queue with known = 1000 + δ,
               so r.world = r.queue.foldl apply r.account holds at every tick.
               S1, X1, L0, L1a, C1, C2, and frozen.txt: All pass (cancelled/placed are .other steps; o_new is properly
               rounded; behavior is causal and deterministic).
               The same unbound a.before also lets arriveWish drop an arbitrary resting order on another slot before
               taking a.before at a new timestamp (so long as it logs the cancel to world and queue).
         Outcome: o_new has placed = 1000 instead of 0, so under A7 it is no longer resting until the first quote with
         time > 1000: any sell-aggressor print at x < 100 in [1000, next_quote) misses the order under
         pessimistic, and if the next quote has ask ≤ 100, an alo order is refused (losing the fill) while a gtc order
         converts from a maker fill (0.015% fee) to a taker fill (0.045% fee). Directly changes fills and CS2.1–CS2.3 verdicts.
         Defect type & fix: Design defect in R1 (and the unified observation). Tie each arrival's a.before (and each
         CycleStep's s.before) to the world book produced by all transitions strictly preceding it — either by folding all
         world transitions (arrival, fill, liquidation, listing, ending, funding) into one sequential book chain
         starting from worldBook initial where every step's before equals the previous step's after, or by tying
         a.before to initial.acct folded over run.effects prior to a (building on Finding 1's effect log). Add
         UnnecessaryReplace to checks.engine-proofs-fixtures.

    Finding 5. Observation (C2): Leaving stop codes (R_OFF_RULES vs hard faults) out of C2 allows
    verdict-changing hold/halt mislabels (design defect)
         What it breaks: Directly answers Ledger Check 6 ("Whether R_OFF_RULES and admission's order can change a
         verdict, and so belong in C2") and A18's guarantee that study2 holds the month on R_OFF_RULES and ends the test
         on every other admission fault.
         Construction: Round 15's restated C2 asserts only (finishExported after.1).ok = false, leaving the
         Fault constructor unconstrained and test-only. Because study2's runner branches its study-level decision on the
         fault code (R_SETTLEMENT_MISSING and R_OFF_RULES hold the month; every other fault permanently ends the
         test), two opposite mislabels pass C2 and frozen.txt:
             1. Genuine rule change mislabeled as a hard fault: Hyperliquid expands a coin's szDecimals or price grid
                inside an hour before the hourly meta copy updates, producing a valid print/quote off the stale rules. A
                subject admission function returning E_DECIMAL / E_GRID instead of R_OFF_RULES causes study2 to
                permanently terminate the test instead of holding the month for the updated meta copy, forfeiting CS2.1–
                CS2.3 confirmation.
             2. Hard fault mislabeled as R_OFF_RULES: An event is both off the current grid and out of order, crossed, a
                duplicate trade ID, or inside an unreleased protected window. A subject admission function that checks
                onGridAt before rule-free checks (violating A18's check order) emits R_OFF_RULES, causing study2 to hold
                the month instead of ending the test on a corrupted or protected record.
         Outcome: Directly flips whether Study 2 terminates without confirming CS2.1–CS2.3 or continues past a
         corrupted/protected-window event.
         Defect type & fix: Design defect (small, since C2 is already restated on typed finish in Step 5x sub-step 2). Add a
         stop-code clause to C2 characterizing .error .offRules: whenever any rule-free fault holds (out-of-order, ended

https://gemini.google.com/app/fca5f84335fc034a                                                                                    4/7
11/22/26, 4:02 PM                                                 See attached instructions


         coin, unreleased protected window, crossed/one-sided quote, non-positive price/size, repeated trade ID, invalid
         listing rules, or a decimal outside |n| < 10¹⁵ / scale > 12), (finish after.1).2 ≠ .error .offRules; and
         whenever no rule-free fault holds while the event fails only the current rules (grid or szDecimals), (finish
         after.1).2 = .error .offRules.

    Finding 6. Build boundary (environment walk): Generalized field notation (x.f) bypasses Lean-
    prefix refusal in the walk's completeness check (design defect)
         What it breaks: B2's claim that check-source.lean's environment walk automatically guarantees no allowed
         identifier can invoke an exposed trigger across future toolchain bumps (Ledger Check 1).
         Construction: Round 15's walk checks that every Init constant exposing an open trigger has a name refused by
         the name rule (containing component Lean or autoParam). Under Lean 4's generalized field notation, however, if
         an expression x has type Lean.T ... (for any declared type constant Lean.T in Init, such as Lean.Name or
         Lean.Syntax — both constructible without writing Lean via dot-constructors as in N1.lean), writing x.helper
         resolves to Lean.T.helper while the source file contains only the identifier helper (neither Lean nor autoParam).
         If a future toolchain bump introduces any constant under a Lean.<Type> namespace exposing a trigger (e.g. def
         Lean.Name.mkAuto (n : Lean.Name) (α : Type) : Type := autoParam α n, or a transitive wrapper
         under Lean.Name / Lean.Syntax), Round 15's walk sees the component "Lean" in Lean.Name.mkAuto,
         concludes the name rule refuses it, and passes — while a library module reaches it via (.str .anonymous
         "smuggled").mkAuto Nat. (Note: On pinned Lean 4.34.0 today, the audit's five trigger-exposing constants —
         autoParam, Lean.reduceBool, Lean.reduceNat, Lean.ofReduceBool, Lean.ofReduceNat — live under
         _root_ or the non-type namespace Lean, so this does not fire on 4.34.0; it is a latent hole in the walk's completeness
         theorem for toolchain updates.)
         Outcome: On a toolchain bump adding a trigger-exposing method under a Lean.<Type> namespace, the
         automated completeness audit falsely passes, reopening build-time execution (divergent verdicts on CS2.1–CS2.3 or
         @[init] protected-data leakage).

         Defect type & fix: Design defect in check-source.lean's walk. Inside Finding 3's transitive fixpoint walk, for
         every c ∈ exposed of the form .str p s, if p is itself a declared constant or alias in Init (so generalized field
         notation x.s could resolve to c), fail unless the unqualified component s alone is also refused by the name rule. Add
         a DotMethodTrigger fixture (Lean.Name.badReduce in a scratch Init extension) to checks.engine-proofs-
         fixtures.

    What I accept (and Round 14 closure check)
         Round 14 Finding 2 (L0 / L1a on snapshots and Step 7 abort) — closed at its cause: Deleting snapshots and
         fireNoRec, recording TickRecord directly inside tickBody on orderRun, tying finishExported.ok = true
         ↔ ∃ run, orderRun = some run, and moving L0's clock coverage and L1a onto orderRun (with C1's wire
         round-trip premise on both R1 and L1a) eliminates the second fold and cleanly excludes R_SETTLEMENT_MISSING
         aborts.
         Round 14 Finding 4 (K1 flip-to-short sale and reserve invariant) — closed at its cause: Setting m = h whenever
         −u ≥ q (eliminating negative holdings on a flip-to-short sale), counting the ending row first (consistent with
         architecture 6.1 and V16), freezing state after end, and qualifying the reserve invariant to positive buys (n > 0, with n
         = 0 when 24C < ΣB) make K1 exact and provable.

         Round 14 Finding 5 (finish type vs C1/C2/L1a and frozen.txt diff gate) — closed at its cause (subject to
         Finding 5): Restating C1, C2, and L1a on typed finish / FinishResult.ok inside sub-step 2's explicit
         frozen.txt diff and enumerating every Lean and OCaml caller/test to migrate closes the build wall and binds C2 to
         OCaml's publication flag.
         Round 14 Finding 6 (packages.mm2 skipping post-build clauses) — closed at its cause: Moving all four clauses
         of check-proofs.sh into mm2For's single shared engine build derivation (run in a clean environment excluding
         LEAN_CC and LEAN_AR) prevents packages.mm2 or checks.mm2-tests from linking an unchecked engine,
         provided study2 also links that same shared build derivation.

https://gemini.google.com/app/fca5f84335fc034a                                                                                       5/7
11/22/26, 4:02 PM                                                See attached instructions


         Round 14 Finding 1 (autoParam.eq_def) — closed on 4.34.0, walk gaps in Findings 3 and 6: Refusing Lean and
         autoParam in any identifier component closes autoParam.eq_def/autoParam.eq_1 and reserved-name families
         derived from them; wishAt in R1 and B2's corrected assurance-limits list close the wish-payload half of Round 14
         Finding 3.
         Study 2's delisted-coin end rule (Check 7) — accepted: Setting ending.time to the hour settlements stop
         (closing the position at class 1 before class 2 funding, so that hour is not due for R_SETTLEMENT_MISSING), settling
         at the coin's own price with no price in Payload.ending, cutting later events, and dating ending.known =
         max(ending.time + listings.lag, flagging_copy_time) is causal (known ≥ time + lag and known ≥
         flagging_copy_time), consistent with slotKeysAt and L1a (settlement fill/cancel effects enter the view at
         ending.time + δ just as real exchange fills do, covered by L1a's time ≤ τ − δ premise), and cleanly removes
         unreachable zero-settlement clauses. (Minor note: confirm with Study 2's half that a coin delisted before its first
         quote in the horizon has no span return / K2 holding term, matching A12's "no return before its first quote".)

    Summary ledger

     Point                                            State          Would a dispute change what is built or run?

                                                                     Yes: record emitted effects in orderRun, strengthen
     1. L1c enforces only a lower bound on view
                                                      Disputed       L1c to an exact time + δ ≤ r.time / r.time <
     freshness (EarlyViewApply)
                                                                     time + δ split, add EarlyViewApply fixture

                                                                     Yes: bind run.admissions directly to
     2. Deleting admissions.Pairwise and
                                                                     run.arrivals.filterMap via frozen
     placed.Pairwise leaves                           Disputed
                                                                     cancelSlot/prepare/admission in R1 (and drop
     admissions/placed untied to arrivals
                                                                     w.cycle ≤ b.cycle premise on arrive)

     3. Environment walk is 1-hop and ignores                        Yes: replace 1-hop scan in check-source.lean with
     closed autoParam tactic names                    Disputed       transitive fixpoint walk + check closed autoParam
     (TransitiveTrigger)                                             names exist in Init, add TransitiveTrigger fixture
                                                                     Yes: tie a.before (and CycleStep.before) into a
     4. R1's a.before is untied across timestamps                    sequential world-book chain from worldBook
                                                      Disputed
     (UnnecessaryReplace)                                            initial (or prior effects), add UnnecessaryReplace
                                                                     fixture
     5. C2 leaves stop codes (R_OFF_RULES vs                         Yes: add .error .offRules characterization clause
                                                      Disputed
     hard faults) unbound                                            to C2 in sub-step 2's restatement
                                                                     Yes: require unqualified last component refusal
     6. Environment walk ignores generalized field                   whenever an exposed constant's prefix is a declared
                                                      Disputed
     notation (x.f on Lean.<Type>)                                   constant/alias in Init, add DotMethodTrigger
                                                                     fixture
     R14 closures (L0/L1a on orderRun, K1 fold &
                                                      Agreed
     reserve, typed finish & C1/C2/L1a migration,
                                                      (subject to
     shared build with all 4 clauses, wishAt,                        —
                                                      Findings 1–
     Lean/autoParam any-component ban on
                                                      6)
     4.34.0)
     Study 2 delisted-coin end rule (time, known,
     settlement at coin's price, hour not due, jsont, Agreed         —
     B2 headline)

    Does any dispute change what is built or run? Yes — all six disputed findings change Step 5x's guard (check-
    source.lean, checks.engine-proofs-fixtures) or Step 5x sub-step 2's laws (L1c, R1, C2, and orderRun's
    world/effect chain) before building.

https://gemini.google.com/app/fca5f84335fc034a                                                                                  6/7
11/22/26, 4:02 PM                                See attached instructions




https://gemini.google.com/app/fca5f84335fc034a                               7/7
```
