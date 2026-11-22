# Neon on round 14's kernel half (build boundary and observation)

Model Gemini 4 Neon through the Gemini web UI (the human pasted `neon-r14-kernel-bundle.md`, 372 KB, whole, and its prompt; reply saved as a PDF, 2026-11-22 08:18 UTC (03:18 EST)). Neon did not author round 14; it is the build boundary's only outside reviewer, GPT's filter refusing that subject. Extracted by `pdftotext -layout`:

```text
11/22/26, 3:18 AM                                                       See attached instructions


    See attached instructions
    https://gemini.google.com/app/a92af3a5bd54ee7a

    User prompt: See attached instructions

    Response: Finding 1. Build boundary: autoParam.eq_def / autoParam.eq_1 and dot-constructor
    notation bypass the name rule (design defect)
          What it breaks: B2's guarantee that rejecting identifiers whose first component (_root_ stripped) is Lean or whose last
          component is autoParam closes every trigger of evalConst so no compiled library code runs during lake build.
          Construction:
                The name rule in step 5x sub-step 1 rejects an identifier only when its first component (after _root_) is Lean or its last
                component is autoParam. Lean 4's reserved-name handler dynamically synthesizes equational lemmas
                (autoParam.eq_def and autoParam.eq_1) for def/abbrev declarations; neither name appears in Init's .lean
                source text (so grepping Init misses them), and both have first component autoParam (≠ Lean) and last component
                eq_def/eq_1 (≠ autoParam).

                autoParam.eq_def has type ∀ {u} (α : Sort u) (tacticName : Lean.Name), autoParam α tacticName
                = α. Because its second parameter already has expected type Lean.Name, dot-constructor syntax already in b94e128
                constructs a Lean.Name in constructor form with no identifier under Lean:
                def mkTrigger {T : Type} (_ : T = Nat) (y : Nat) (x : T) : Nat := x + y
                def trigger := mkTrigger (autoParam.eq_def Nat (.str (.str .anonymous "Engine") "smuggled"))

                Unifying ?T = Nat against autoParam Nat … = Nat assigns ?T := autoParam Nat … syntactically without
                unfolding autoParam, giving trigger the exact elaborated type Nat → autoParam Nat Engine.smuggled → Nat`.
                To give Engine.smuggled the literal type Lean.Syntax without writing Lean, define def ofDom {α β : Type} (_
                : α → β) (x : α) : α := x and apply it to any public non-Lean declaration in Init whose type exposes
                Lean.Syntax — in particular, the auxiliary Lean.Macro (= Lean.Syntax → Lean.MacroM Lean.Syntax) constants
                generated at root (or in non-Lean namespaces) by macro/macro_rules in Init/Notation.lean and
                Init/Tactics.lean. Its second argument then has expected type Lean.Syntax, so .node, .atom, .ident, .none,
                .str, and .anonymous construct the exact F3.lean syntax AST (exact (let rec @[implemented_by bad] h …;
                h 3) or @[init act]) using only b94e128's listed forms.

                Finally, def boom : Nat := trigger 0 invokes Elab/App.lean's autoParam handler (isAppOfArity
                ``autoParam 2), which calls evalConstCheck on Engine.smuggled and elaborates the smuggled syntax during
                lake build.

                (Verification note without a live 4.34.0 binary: check on the pinned 4.34.0 that autoParam.eq_def or autoParam.eq_1
                synthesizes for autoParam, and dump Init's compiled .olean environment to list every non-Lean constant whose type
                reaches Lean.Syntax or autoParam.)
          Outcome: Defeats the build boundary at its core: compiled engine code can silently depart from proved definitions (changing
          CS2.1–CS2.3 verdicts) or execute arbitrary IO via @[init] during the build (leaking protected data).
          Defect type & fix: Design defect. Reject any identifier in which any component is Lean or autoParam (not only first/last),
          reject compiler-internal prefixes (_aux_, _private_) and reserved-name suffixes on root symbols if needed, and audit Init's
          compiled .olean environment (not .lean source text) for every non-Lean constant whose type mentions autoParam,
          Lean.Syntax, Lean.reduceBool, or Lean.reduceNat.

    Finding 2. Observation: L0 clause 2 and L1a live on snapshots, which no law ties to production
    (feed/finish) or orderRun — and Step 7's R_SETTLEMENT_MISSING breaks L0 clause 2 (design defect)
          What it breaks: Round 14's claim that L0 guarantees every published run ticks on its clock and L1a guarantees production's
          views, evaluations, and wishes are causal; also compatibility with Step 7 (R_SETTLEMENT_MISSING).
          Construction:
                Production executes feedExported/finishExported. L0 clause 1 ties finishExported (runMoves initial
                moves).1 (ok = true) to orderRun bitsOps initial moves = some run, and X1 clause 3 ties orderRun's rows


https://gemini.google.com/app/a92af3a5bd54ee7a                                                                                               1/6
11/22/26, 3:18 AM                                                       See attached instructions

                to feed/finish's rows. Meanwhile, L0 clause 2 (clock coverage) and L1a (causality) quantify solely over snapshots
                initial events. No theorem in Laws.lean or Round 14 proves either (i) that finishExported.ok = true implies ∃
                records, snapshots initial events = some records, or (ii) that snapshots's tick records/rows/wishes agree
                with feed/finish's trace rows or orderRun's wishes.
                Step 5x sub-step 2 (SnapshotDrop) and B1 (fireNoRec) explicitly separate fireRec (called by snapshots) from
                fire/fireNoRec (called by production feed), and both are subjects (editable, unfrozen in frozen.txt). Thus two
                failures pass every law and frozen.txt:
                    1. Divergent production tick: fire/fireNoRec drops non-deciding ticks when decide_every > 1 (or reads
                       world/future prices instead of view prices), while fireRec ticks honestly on the clock. L0 clause 2 and L1a hold of
                       snapshots; R1 checks only deciding ticks (τ % (tick * decide_every) = 0); X1 equates orderRun only
                       with feed; frozen.txt is unchanged.
                    2. Step 7 abort contradiction: Laws.lean specifies snapshots as returning none only on admission rejection ("does
                       not ask finish's own verdict to be ok"). On a Step 7 run that aborts mid-horizon with R_SETTLEMENT_MISSING
                       (not an admission fault), snapshots either returns some truncated tick list — making L0 clause 2 false of a correct
                       Step 7 machine — or must be changed to return none on abort, in which case omitting finishExported.ok =
                       true → ∃ records, snapshots = some records lets snapshots return none on multi-event runs and
                       render L0 clause 2 and L1a vacuous.
          Outcome: Dropped non-deciding ticks corrupt every rolling window (sum, mean, std, ema, delay, ticks_since), and look-
          ahead in fire invalidates causal evaluation; either moves entries/exits and changes CS2.1–CS2.3 verdicts (and breaks Study
          2's causality claim).
          Defect type & fix: Design defect. Extend L0 (on events.map .event) so finishExported.ok = true implies ∃
          records, snapshots initial events = some records, and prove that snapshots's tick trace rows and wishes
          match feed/finish's trace and orderRun's run.wishes (i.e., promote the fireNoRec/fireRec simulation into a proved
          law rather than leaving it internal).

    Finding 3. Observation: R1 still leaves wish payloads and arrive's delayed view effects unbound, and
    B2's defense of wish values is false (design defect + text error)
          What it breaks: Round 14's claims that slotKeysAt closes GPT-6.2's ViewSkip at its cause, that a.after = worldBook
          st_after closes arrive's effects, and B2's assurance-limits statement that "B4 and the evaluator's being specification hold
          [the wishes' values]."
          Construction:
                (a) Unbound wish payloads (InactiveWish / ZeroCycleWish): With slotKeysAt derived from moves, R1 checks only
                that run.wishes contains one wish per (coin, slot) in slotKeysAt with w.arrives = w.sent + lambda. R1
                never ties w.value to Engine.Lang.slotEval, never ties w.cycle to the view's cycle at tick τ, and never ties
                w.side, w.reduceOnly, or w.tif to the program's slot definition. Because the machine's wish-emission transition is a
                subject (not frozen), a machine that skips slotEval on every run except the hardcoded step5Program witness and
                emits wishes with value := none (or cycle := 0, which arrive silently discards as a stale cycle since 0 < 1 =
                b.cycle) satisfies R1, S1, X1, L0, L1a, and frozen.txt. B2's justification that B4 and frozen slotEval close this is
                factually wrong: B4 executes Stage 6 float expressions as probes with zero slots, and freezing slotEval does not
                force a subject machine to call it or copy its outputs/slot attributes into Wish.
                (b) Unbound delayed view effects of arrive (ArriveViewDrop): Orders.Book (worldBook) projects only the world's
                orders, coins, cycle, position, filled, rules, and ended. It does not project the delayed effect queue that delivers
                placed, cancelled, and refused to the view δ later (A1, A5: resting(slot) and resting_price(slot)) or the
                trace's effect rows. If arriveWish updates the world's orders honestly (so a.after = worldBook st_after =
                (arrive a.before a.wish).1 holds and ArriveTags is defeated) while dropping or corrupting placed/cancelled
                in the view's delayed effect queue, R1, S1, X1, L0, and L1a all still hold while the strategy's own-state inputs
                resting(slot) and resting_price(slot) diverge from the world.

          Outcome: Suppressed or corrupted wishes, or stale resting/resting_price own-state inputs, alter order placements and
          fills, changing CS2.1–CS2.3 verdicts.
          Defect type & fix: Design defect (plus a factual text error in B2). Either bind run.wishes in R1 (or L0+snapshots) to
          slotEval applied to the tick's view/evaluator state (with side/reduceOnly/tif from prog.slots and cycle from the
          view's cycle) and project the emitted view-effect entries alongside worldBook in Arrival (checking them against arrive's


https://gemini.google.com/app/a92af3a5bd54ee7a                                                                                               2/6
11/22/26, 3:18 AM                                                         See attached instructions

          tags), or — if deferred to tests — remove the false claim in B2 that B4 and frozen slotEval hold wish values and explicitly list
          w.cycle, w.side, w.reduceOnly, w.tif, and arrive's view-side effects under test-only assurance.

    CONTINUE



    User prompt: continue

    Response: Finding 4. K1's exact fold: unguarded flip-to-short sale drives h < 0, and the reserve invariant
    is false after a funding-depleted buy (design defect)
          What it breaks: K1's exact test-ledger fold and its stated non-negativity and reserve invariants (B3 K1, A12, Step 10).
          Construction:
             1. Flip-to-short sale (q > 0, q + u < 0): K1's second bullet defines a sale row (u < 0, account position q = before)
                unconditionally as m = h when -u = q, else m = ⌊h · (-u) / q / L⌋ · L, updating C += m · k, B -= B · m /
                h, and h -= m. Only in the third bullet does K1 say "so does a fill that takes the account short." Suppose the account
                holds q = 5 (ledger holds h = 0.5, B = 50, C = 0.5) and a single fill sells u = -10 (flipping the account from +5 to
                -5). Because -u = 10 ≠ 5 = q, the literal else branch computes m = ⌊0.5 · 10 / 5 / L⌋ · L = 1.0 = 2h,
                driving h to -0.5 < 0, B to -50 < 0, and crediting phantom cash 2h · k (double the ledger's holdings). Additionally,
                because confirm returns cash and units after every row (Step 10), K1 does not specify whether an ending row (either a
                short-taking fill or a funding charge that would take C < 0) leaves (C, h, B) at its pre-row values or applies the
                update before setting ended = true.
             2. Unqualified reserve invariant after a zero buy: K1's second clause states: "after every buy its cash is at least 1/24 of what it
                has paid for the units it holds, and a buy made while a payment holds the cash below that buys nothing." Start from Step 10
                Test 2's state after buying A and B (h_A = 0.4, h_B = 0.464, ΣB = 0.864, C = 0.036 = ΣB / 24). Apply a funding
                charge of 0.01 on A: C drops to 0.026 > 0, so the ledger does not end, but 24 C = 0.624 < 0.864 = ΣB. Now feed
                any buy row. By K1's fold, max(0, (24 C - ΣB) / (25 k)) = 0, so n = 0 units are bought, leaving C = 0.026 <
                0.036 = ΣB / 24 after that buy — making K1's stated invariant literally false and unprovable in Lean.

          Outcome: K1's Lean theorem cannot be proved as stated at Step 10; an implementation following the unguarded sale order
          emits negative holdings and inflated cash on a flip-to-short row, affecting confirm's exported ledger trace (and CS2.1–CS2.2
          if any downstream check reads the ending row).
          Defect type & fix: Design defect (law statement). In K1's fold, check before + u < 0 before applying the trade formula
          (ending the ledger immediately without mutating C, h, or B, and specifying the same pre-mutation end for overdrawing funding
          payments), and qualify the reserve invariant as: whenever n > 0 (or 24 C_before ≥ ΣB_before), 24 C_after ≥
          ΣB_after, and whenever 24 C_before < ΣB_before, n = 0.

    Finding 5. Step 5x sub-step 2 contradicts Laws.lean's C1/C2/L1a — and leaves C2 disconnected from
    FinishResult.ok if finish is kept as-is (design defect)

          What it breaks: Step 5x sub-step 2's contract for typed completion (finish returning Rows × Except Fault Summary)
          and its frozen.txt diff gate; and, if resolved the wrong way, C2's guarantee that rejected and protected-date runs are never
          published.
          Construction:
                Step 5x sub-step 2 specifies that finish returns Rows × Except Fault Summary and that frozen.txt changes
                only in slotKeysAt, FinishResult, finishExported, the outcome type with its JSON, and orderRun ("checks that
                no other line changed").
                In b94e128's Laws.lean, however, C1 (lines 529–530, 545), C2 (lines 597–599, 610–612), and L1a's witness (lines 798–
                799, 822–823) all call Engine.Machine.finish directly and apply String.startsWith to final.2
                (final.2.startsWith "{\"ok\":true" and final.2.startsWith "{\"error\":"). Changing finish's return
                type breaks typechecking in all three frozen laws, so the frozen.txt diff gate as written is impossible to satisfy.
                Conversely, if a builder preserves finish : State → Rows × String to satisfy the frozen.txt gate and adds a
                parallel finishOutcome : State → Rows × Except Fault Summary for finishExported and orderRun, then
                C2 (admission and protected-window rejection) and C1 (chunking invariance) are proved only on finish, not on



https://gemini.google.com/app/a92af3a5bd54ee7a                                                                                                     3/6
11/22/26, 3:18 AM                                                      See attached instructions

                finishExported.ok — allowing a subject finishOutcome to return .ok (setting OCaml's publication flag ok = true)
                on a run containing an unreleased protected-window event while finish returns "{\"error\":..." to satisfy C2.
          Outcome: Either Step 5x sub-step 2 hits a guaranteed build wall, or C2 ceases to bind OCaml's publication flag
          FinishResult.ok, creating a potential holdout leak or chunking divergence on CS2.1–CS2.3.

          Defect type & fix: Design defect. Keep finish : State → Rows × Except Fault Summary as the single completion
          function called by finishExported, orderRun, C1, C2, L1a, and X1, and explicitly include finish, C1, C2, and L1a in sub-
          step 2's reviewed frozen.txt restatement (C2 asserting ∃ f, (finish after.1).2 = .error f, which via frozen
          finishExported directly implies (finishExported after.1).ok = false).

    Finding 6. Build boundary: packages.mm2 runs only the pre-build source check, leaving PolicyShadow
    and SorryAx unenforced on mm2 builds (design defect)
          What it breaks: B2's guarantee that no compiled engine (packages.mm2) is built from a source that fails the guard,
          specifically after Round 14 moved the PolicyShadow defense (Engine.Machine.policyText == fileBytes) to a post-
          build frozen-surface clause.
          Construction:
                Step 5x sub-step 1 puts check-source.lean (pre-build) in mm2For's shared build ("The flake's shared engine build
                (build in mm2For, which packages.mm2, checks.mm2-tests and checks.mm2-style run) runs the check and then
                Lake in the directory the check wrote, and nowhere else, as does check-proofs.sh").
                The three post-build clauses — collectAxioms (SorryAx), the frozen-surface print + Engine.Machine.policyText
                literal-value verification (PolicyShadow), and the export-rooted IR walk (StrippedCsimp) — live only in check-
                proofs.sh (checks.engine-proofs), not in mm2For's shared build.

                As the fresh Opus review demonstrated, PolicyShadow passes check-source.lean completely. Therefore nix
                build .#mm2 (and checks.mm2-tests), including a rebuild of packages.mm2 on a protected-window release commit,
                succeeds on PolicyShadow (or SorryAx or a stripped @[csimp]) unless checks.engine-proofs is explicitly run
                alongside it.
          Outcome: A mm2 or study2 binary with a shadowed policyText (admitting unreleased holdout dates) or sorryAx can be
          built and executed from packages.mm2.
          Defect type & fix: Design defect (small). Run all four clauses of check-proofs.sh inside mm2For's shared engine build
          derivation right after lake build (using that derivation's own protected-windows.json input for the policyText literal
          check). Because frozen.txt prints policyText by type alone, this preserves A13's stand-in derivation byte-for-byte identity
          while making it structurally impossible for packages.mm2 to emit an unchecked engine.

    What I accept (and minor notes)
          Policy constant binding (Engine.Machine.policyText): Provided the post-build check runs inside mm2For's shared
          build (Finding 6) and checks that Engine.Machine.policyText is a .defnInfo whose raw Expr value is literally
          Expr.lit (.strVal fileBytes) (no mdata or wrappers), windows (printed in full in frozen.txt) is pinned to that exact
          constant and cannot read a shadowed or coerced value.
          Plain import components and clean build environment: Restricting each import component to ASCII [A-Za-z][A-Za-z0-
          9_]* makes module names and Linux paths strictly 1-to-1, closing DotComponent and Engine.«.».PolicyText. Running
          check-source.lean and Lake under env -i with only explicitly named variables closes inherited
          LEAN_PATH/LEAN_SYSROOT/LAKE_*/ELAN_* hijacking. (Operational note: ensure LEAN_CC and LEAN_AR are never inherited
          from the caller's environment — pass only pinned store paths and NIX_CFLAGS_COMPILE/NIX_LDFLAGS, which do not affect
          Lean/Lake search paths.)
          Three-rule observation principle and frozen-surface split: Freezing start, startAdmission, initialState, bitsOps,
          cancelSlot, install, admission, the evaluator, observers, and (C symbol, Lean constant) export pairs — while
          keeping the machine editable as a subject under its laws and suite — is sound once Findings 2, 3, and 5 are closed.
          slotKeysAt semantics and Acct.apply: Deriving coins in view from moves via e.known ≤ τ matches A17 and A3's intra-
          millisecond class ordering (class 1 listing/ending before class 4 tick, so time = known = τ is out of view at tick τ), provided
          admission enforces e.time ≤ e.known (note that C2 in Laws.lean does not currently include an e.known < e.time fault
          clause; worth adding so an ending with e.known ≤ τ < e.time cannot make R1 false on a causal machine). Replacing
          arrive's returned book with worldBook st_after binds world-side order cancellations and placements; I cannot directly


https://gemini.google.com/app/a92af3a5bd54ee7a                                                                                              4/6
11/22/26, 3:18 AM                                                      See attached instructions

          verify the arrival lemma against b94e128's Acct.apply (order-list ordering and remainders) because Acct.apply's source
          was not included in this bundle.
          Step 10's recomputed reserve figures: Independently verified by exact arithmetic — Test 1 (0.04, 0.04), Test 2 (0.4 A,
          0.464 B, 0.036 cash, 0.864 cost, 0.4176 charge ending the ledger), Test 3 (⌊3T/14⌋, 1 - 7N/(3T)), Test 5 (1.00981,
          0.99010; 1.00250, 0.99502 at φ = 1/2), and Construction A (409.6 wealth, 0.9995 bid wealth, 409.2 bid wealth with
          following bids) all match K1's fold.
          Step 6 / A18 alignment and V13 wording: Accepted as written.

    Summary ledger

      Point                                       State                    Would a dispute change what is built or run?

      1. Build boundary name rule
                                                                           Yes: ban Lean/autoParam in any identifier component +
      (autoParam.eq_def /
                                                                           audit compiled Init .oleans for constants whose types
      autoParam.eq_1, dot-constructor             Disputed
                                                                           expose
      Lean.Syntax from compiled Init
                                                                           autoParam/Lean.Syntax/reduceBool/reduceNat
      .oleans)

      2. L0 clause 2 and L1a on snapshots
                                                                           Yes: extend L0 to tie finishExported.ok = true to
      untied to feed/finish/orderRun; Step
                                                  Disputed                 snapshots and equate snapshots's trace rows and
      7 R_SETTLEMENT_MISSING abort
                                                                           wishes with feed/finish and orderRun
      contradiction
      3. R1 leaves wish payloads (value,
                                                                           Yes: bind wish payloads to slotEval/view cycle/slot
      cycle, side, reduceOnly, tif) and
                                                                           specs (or fix B2's assurance limits and close w.cycle >
      arrive's delayed view-side effects          Disputed
                                                                           b.cycle in arrive), and project/check view-side arrival
      unbound; false B2 claim that B4 holds
                                                                           effects
      wish values
      4. K1 unguarded flip-to-short sale (q + u                            Yes: guard before + u < 0 before the trade step, define
      < 0) and false reserve invariant after      Disputed                 exact post-end state, and qualify K1's reserve clause for n >
      funding-depleted zero buy                                            0 / 24 C_before ≥ ΣB_before

      5. Step 5x sub-step 2 finish type                                    Yes: restate C1, C2, and L1a on typed finish in sub-step
      change vs C1/C2/L1a and frozen.txt          Disputed                 2's frozen.txt diff so C2 directly binds
      diff gate                                                            FinishResult.ok = false

      6. packages.mm2 running only pre-build
      check-source.lean, leaving                                           Yes: run all four clauses of check-proofs.sh inside
                                                  Disputed
      PolicyShadow/SorryAx out of                                          mm2For's shared engine build
      mm2For's shared build

      Policy constant binding                     Agreed (with Finding
      (Engine.Machine.policyText literal          6 and
                                                                           —
      value), plain import components, env -i     LEAN_CC/LEAN_AR
      clean build env                             note)
      Three-rule observation principle, frozen-
      surface split (start, evaluator, bitsOps,   Agreed (subject to
                                                                           —
      cancelSlot/install/admission,               Findings 2, 3, 5)
      export pairs)
                                                  Agreed (add e.known
      slotKeysAt (e.known ≤ τ), Step 10           < e.time check to
      recomputed reserve figures, Step 6/A18      C2; Acct.apply       —
      alignment, V13 wording                      uninspected — not in
                                                  bundle)

    Does any dispute change what is built or run? Yes — all six disputed findings change Step 5x's guard (check-source.lean,
    mm2For), Step 5x sub-step 2's laws (L0, R1, C1, C2, L1a, and frozen.txt), or Step 10's K1 statement before building.


https://gemini.google.com/app/a92af3a5bd54ee7a                                                                                             5/6
11/22/26, 3:18 AM                                See attached instructions




https://gemini.google.com/app/a92af3a5bd54ee7a                               6/6
```
