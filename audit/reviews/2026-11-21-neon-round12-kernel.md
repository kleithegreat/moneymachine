# Neon on round 12's kernel half (item 1b)

Model Gemini 4 Neon, through the Gemini web UI (the human pasted the bundle neon-r12-kernel-bundle.md (rearchitecture 3139e64) and its prompt from `~/Downloads`, and saved the reply as a PDF, 2026-11-21 23:21 to 23:25 UTC (18:21 to 18:25 EST)). Neon did not author round 12. The web UI truncated the 603 KB bundle partway through the GPT round 10 and 11 review, so the round 12 GPT review, the architect's report and the step 5 Lean files did not reach the model; it says so in its scope note. The reply, as extracted from the PDF by `pdftotext -layout` (page headers and footers kept):

```text
11/21/26, 6:21 PM                                                   See attached instructions


     See attached instructions
     https://gemini.google.com/app/c5c5f9d87e7b802b

     User prompt: See attached instructions
     Response: Scope note: This is a read-only theoretical review of round 12's kernel half, item 1b. The attached bundle
     truncated mid-sentence near the end of audit/reviews/2026-11-21-gpt-round10-11.md, so 2026-11-21-gpt-
     round12-kernel.md, architect-r12-report.md, and the step 5 .lean files were not included; every finding below is
     derived from the complete CLAUDE.md, audit/program/kernel-v2.md, audit/program/briefs/3-kernel-v2.md,
     and audit/program/ledger.md (rounds 10–12) specs in the bundle.

     Finding 1. sorryAx breaks the purity claim for Lean.reduceBool/Lean.reduceNat, allowing
     arbitrary IO during lake build to poison compiled .o artifacts and exit 0
           What it breaks: kernel-v2.md B2's core soundness boundary for the parse-time guard ("The one route by which the
           build runs the project's code ... That code is safe, so pure: on the pinned toolchain an IO action runs only on a world,
           IO.RealWorld is built from an opaque type with only a Nonempty instance, so no computable code holds one ... It
           returns a value, writes at most to standard error, and changes no file") and ledger.md round 12's claim that post-build
           collectAxioms plus warningAsError contain native reduction.

           Construction: The architect tested default, Classical.choice, and runST to fabricate a world token and missed
           sorryAx, which is a plain Init constant (an ident, not a forbidden syntax form) and is neither unsafe nor
           noncomputable. Indeed, briefs/3-kernel-v2.md step 5x sub-step 1 lists both SorryAx and NativeReduce
           under the axioms fixtures rather than the source fixtures, confirming that both sorryAx and Lean.reduceBool pass
           check-source.lean. Add a module Engine/Z_Poison.lean importing Engine.Exact (and imported by
           Engine.lean) using only syntax kinds already in syntax.txt (def, theorem, let, fun, match, Bind.bind, string
           literals, by decide or rfl, no do notation needed):
               1. Define a computable def evil : Bool that builds an IO Bool action with Bind.bind and applies it to
                  sorryAx _ true (specifically synthetic := true):

                      sorryAx (Void IO.RealWorld) true (or sorryAx IO.RealWorld true) typechecks in safe,
                      computable code. Passing synthetic := true suppresses Lean 4's "declaration uses 'sorry'"
                      warning (the reason the SorryAx fixture in brief 3 explicitly writes sorryAx _ false), so def evil emits
                      zero warnings and zero errors under warningAsError, passes addDecl, and compiles cleanly to IR. In
                                                                            ◾
                      LCNF/IR, the world token is computationally erased ( / lean_box(0)), and even without erasure
                      sorryAx compiles to lean_sorry, which returns lean_box(0)—the exact runtime representation of
                      IO.RealWorld.

                      Inside the IO action, evil reads /proc/self/cmdline via IO.FS.readFile to obtain Lake's -o
                      <Z_Poison.olean> and -c <Z_Poison.c> output paths; invokes /proc/self/exe (the pinned lean
                      binary) via IO.Process.output on a 1-line empty temp file to write a genuine, axiom-clean
                      Z_Poison.olean and Z_Poison.c to those paths; waits until
                      .lake/build/ir/Engine/Exact.o.trace exists (in Lake's DAG, Exact.olean and Exact.c already
                      exist because Z_Poison imports Engine.Exact, while libEngine.a cannot start until Z_Poison.lean
                      exits—so there is no race); compiles a patched Exact.c (altering expFast on one untested input x₀) via
                      leanc and atomically renames it over .lake/build/ir/Engine/Exact.o; and finally calls
                      IO.Process.exit 0.

               2. Follow def evil with theorem runEvil : Lean.reduceBool evil = true := by decide. During
                  elaboration/kernel reduction of runEvil, Lean executes evil via evalConst. IO.Process.exit 0 terminates
                  the lean process immediately with exit status 0 before Lean.Elab.Frontend ever checks
                  messages.hasErrors (bypassing Lean.reduceBool's deprecation warning under warningAsError).

               3. Lake sees exit code 0 plus valid Z_Poison.olean and Z_Poison.c, compiles Z_Poison.c to Z_Poison.o,
                  and archives the poisoned Exact.o into libEngine.a and mm2.




https://gemini.google.com/app/c5c5f9d87e7b802b                                                                                        1/7
11/21/26, 6:21 PM                                                      See attached instructions


               4. Post-build check-proofs.sh inspects the .oleans: Z_Poison.olean is empty and clean (zero sorryAx, zero
                  Lean.trustCompiler), Exact.olean and Laws.olean are untouched, frozen.txt matches byte for byte,
                  the IR walk (Lean.IR.declMapExt, read from .oleans) matches byte for byte, and both Nix build hosts
                  execute the exact same deterministic evil, yielding byte-identical poisoned mm2 binaries. Test 12 and B4 miss
                  x₀.

           (Verification note: because this review is read-only without a live Lean 4.34.0 binary, verify on pinned 4.34.0 whether
           evalConst under Lean.reduceBool performs any axiom/hasSorry pre-check on evil before executing it; in
           standard Lean 4 it checks only safety/IR availability, not transitive axioms.)
           Outcome it could change: Ships a poisoned Exact.o returning wrong exp bits at an untested x₀ inside mm2 while
           passing every clause of checks.engine-proofs, two-host reproducibility, Test 12, and B4. A strategy trigger reading
           exp(x₀) flips entry/exit decisions on admitted events, changing wealth and CS2.1–CS2.3.

           Classification: Defect of the design. Relying on post-build collectAxioms and warningAsError to contain a
           build-time execution primitive fails whenever build-time code can forge artifacts and exit 0. The cause is allowing
           Lean.reduceBool, Lean.reduceNat, Lean.ofReduceBool, Lean.ofReduceNat, and sorryAx to pass check-
           source.lean at all: because open is already restricted to Engine.*, rejecting those identifiers at parse time closes
           the native-reduction route before lake build starts.

     Finding 2. Classifying the evaluator as a subject while freezing bitsOps as specification defeats
     the BitsOpsAdd fix and decouples Eval from X4
           What it breaks: kernel-v2.md B2's subject/specification boundary ("A subject is engine code a law constrains ... the
           evaluator, which X1, L2, L3, L5 and N1 constrain") and its claim that freezing bitsOps closes GPT's BitsOpsAdd attack
           while X4 holds the evaluator to Exact.exp and Exact.log.
           Construction: Round 12 moved bitsOps into specification specifically so that altering bitsOps.add at one untested
           operand pair fails frozen.txt (BitsOpsAdd fixture). Yet B2 simultaneously leaves the evaluator
           (Engine.Lang.Eval) on the subject list (printed by type alone in frozen.txt), while candidly noting two
           paragraphs later that "L3, L5 and N1 are invariances, and X1 compares two evaluators"—meaning no law constrains the
           evaluator's actual values. Move the exact same corruption one layer up, from bitsOps into the polymorphic
           evaluator (Eval.lean), leaving bitsOps, Exact.exp, Exact.log, and every law completely untouched. Because
           NumOps α already exposes toExact : α → Option Rat and ofExact : Rat → α (step 5, wall 4), write in Eval's
           .exp branch (polymorphically over any [N : NumOps α]):

           | .exp i =>
               match vals[i] with
               | some a =>
                   match N.toExact a with
                   | some q =>
                       if (1234567 : Rat) / 1000000 < q && q < (12345670001 : Rat) / 10000000000 then
                         some (N.ofExact 1)
                       else N.exp a
                   | none => N.exp a

           (Alternatively, corrupt .std only when windowLen == 17, which needs neither toExact nor an input-range search.)
           Check every guard and law:
                    check-source.lean, collectAxioms, and the compiled IR walk all pass (bitsOps.exp still points to
                    Exact.expFast, with zero references to Exact.exp).

                    frozen.txt is byte-identical: Eval is a subject (printed by type alone), and bitsOps is unchanged.

                    X4, X5, and X6 all hold: X4 binds bitsOps.exp = Exact.exp, never proving that Eval's .exp branch actually
                    invokes N.exp.
                    X1 holds (compares two NumOps on the same Eval); L2 holds (exp still maps dimensionless float to
                    dimensionless float); L3 holds (no algebraic rewrite touches .exp or .std); L5 (binding) and N1 (renaming) hold;


https://gemini.google.com/app/c5c5f9d87e7b802b                                                                                         2/7
11/21/26, 6:21 PM                                                      See attached instructions


                    L0, L1, L1a, R1, S1, C1, C2, A1, U1 all hold.

                    Test 12 (x4-counts calls Exact.expFastCount directly, never Eval; x4_local runs 3.27M draws that trivially
                    miss a 10−10 -wide interval in [1, 2)) and B4 (3,120 fixed streams) both pass bit for bit. (The same structural
                    issue applies to check if the internal checker subject transforms/resolves an AST rather than returning a pure
                    Unit verdict, since L2 only guarantees unit/sort soundness of the output and not preservation of expressions.)

           Outcome it could change: A strategy's when trigger or exact(f) crossing evaluates to the wrong value on admitted
           market events, changing orders, fills, wealth, and CS2.1–CS2.3.
           Classification: Defect of the design. The subject criterion in B2 conflates "a law mentions f (e.g., an invariance law)"
           with "the laws functionally determine f". Only functions whose full input-output behavior is determined by frozen laws
           (readBits, onGridAt, nearestBits, exp, log, and their twins) can safely be unfrozen as subjects; functions held
           only by invariance laws plus finite tests (Eval, and any AST-building part of check) must be frozen as specification if
           frozen.txt is meant to prevent silent drift of what bitsOps and X4 feed into.

     Finding 3. L0 and the type-only handling of policyText and Machine.State leave protected
     windows, startAdmission, and most of the initial state unbound
           What it breaks: kernel-v2.md B2 & B3 (L0 ★, A13, C2, L1a, R1, S1) and the claim that L0 closes what laws read
           from the start state while frozen.txt protects A13's holdout boundary.
           Construction: Three related gaps stem from the same choice—printing policyText and Machine.State by type
           alone in frozen.txt and binding only three fields of Machine.start in L0:
               1. policyText is unconstrained by frozen.txt: briefs/3-kernel-v2.md step 5x sub-step 1 lists
                  policyText as an input printed by its type alone (policyText : String) so that releases to protected-
                  windows.json do not churn frozen.txt. Meanwhile, check-source.lean only restricts the path argument
                  when include_str is called. Defining:
                    def policyText : String :=
                      let raw := include_str "../../protected-windows.json"
                      -- validate/pass through stand-in "[]" and currently tested windows,
                      -- but strip any window whose start is >= 2027-02-01 (a future holdout)
                      stripFutureWindows raw

                    passes check-source.lean (include_str names ../../protected-windows.json), passes frozen.txt
                    (policyText is type-only), satisfies L0 and C2 (since Machine.prepare reads policyText), passes Step 3
                    test 2 (malformed JSON fails; current windows reject), and passes Step 9 test 10's stand-in derivation check
                    (raw = "[]"). Yet any future unreleased holdout window added to protected-windows.json is silently
                    admitted.
               2. L0 omits Machine.startAdmission and binds only 3 of the start state's fields: L0 states only
                    Machine.start program header = .ok s → ... s.cfg = ... ∧ s.prog = some p ∧ s.rules =
                    cfg.initialRules.

                         Machine.startAdmission (listed as a separate subject in B2, used for admission-only / program-less
                         runs under C2) is not bound by L0 at all.
                         Even on Machine.start, L0 leaves s.pending, s.wishes, s.orders, s.account (starting cash,
                         positions, cycles), s.quotes (staleness history), s.views, s.evalState, s.nextTick, s.lastTime, and
                         s.log completely unbound. A start that pre-seeds s.quotes (defeating pre-first-quote staleness under
                         A3), pre-seeds s.pending with a delayed observation, pre-seeds s.evalState windows, or shifts
                         s.account.cash away from cfg.startingCash still satisfies L0, L1a (both runs start from the same
                         seeded s), C1 (both chunkings start from s), C2 (only checks fed events), and L1 (both horizons start from s).
               3. Machine.State as a type-only subject permits shadow fields: Because Machine.State (with its
                  constructors and projections) is printed by type alone in frozen.txt, adding a hidden field (e.g., shadowRules
                  or shadowCfg) leaves frozen.txt byte-identical (neither L0, nor the exports, nor any projection-reading
                  observer reaches State.mk). While B2 already discloses that s.log is untied to transitions before P1, shadow

https://gemini.google.com/app/c5c5f9d87e7b802b                                                                                            3/7
11/21/26, 6:21 PM                                                   See attached instructions


                    fields on Machine.State also decouple L0-bound fields (s.cfg, s.rules) from transitions that are never
                    logged (e.g., nextTick on non-deciding ticks, staleness G on view marks, or initial cash).
           Outcome it could change: (1) Unreleased holdout data leaks into reports/traces/selection in violation of A13 and
           CLAUDE.md Holdout; (2) corrupted initial cash, pre-seeded observations/quotes, or an unbound startAdmission
           alters staleness, orders, fills, wealth, and CS2.1–CS2.3.
           Classification: Defect of the design. Fix at the cause: (a) check policyText's exact AST in check-source.lean
           (or verify its kernel value equals the raw bytes of protected-windows.json on disk inside check-proofs.sh),
           closing tampering without churning frozen.txt on releases; (b) extend L0 to cover both Machine.start and
           Machine.startAdmission and to bind every observable initial-state component (empty
           pending/wishes/orders/views/quotes/log, lastTime = none, rejected = none, account at
           cfg.startingCash and flat, nextTick from wStart, fresh evalState).

     CONTINUE



     User prompt: continue

     Response: Finding 4. Two enforcement holes in the guard: unfrozen @[export] symbol bindings
     and depth-sensitive include_str path checks
           What it breaks: kernel-v2.md B2's claim that frozen.txt binds the laws' functions to what OCaml calls and that
           check-source.lean restricts include_str to protected-windows.json.

           Constructions:
               1. Unfrozen export-symbol table: check-source.lean allows @[export mm2_*] on any declaration, while
                  frozen.txt uses getExportNameFor? only to seed root constants and then prints each reached constant's
                  Expr sorted by constant name—never printing the (exportSymbol, constantName) mapping itself.

                         Swapping @[export mm2_*] between any two exported constants of compatible ABI/type leaves the root
                         set and frozen.txt byte-identical while routing OCaml calls to the wrong Lean function.
                         Adding @[export mm2_<stub_symbol>] to any constant already printed in frozen.txt (a specification
                         function or subject) adds zero new roots, leaves frozen.txt byte-identical, passes check-source.lean,
                         and emits an external C symbol in libEngine.a under the project's own mm2_ C namespace (the same
                         prefix used by OCaml/C stubs and test stubs such as mm2_test_mpfr*), allowing symbol shadowing or
                         unintended entry points depending on link order.
                         The Repointed fixture in brief 3 (mm2_machine_feed moved to a new copy of feedExported) only
                         catches this because the copy introduces a new constant name, not because the export symbol binding is
                         checked.
               2. Depth-sensitive include_str literal check: check-source.lean checks only that include_str names the
                  literal string "../../protected-windows.json". In Lean 4, include_str resolves its path relative to the
                  directory of the .lean file containing it: in Engine/Policy.lean that resolves to kernel2/protected-
                  windows.json, whereas in Engine/Lang/Foo.lean it resolves to kernel2/lean/protected-
                  windows.json, and in Engine.lean to <repo-root>/protected-windows.json. A policy read moved to (or
                  placed in) a different directory depth silently reads a different file while passing check-source.lean.
           Outcome it could change: Swapped or shadowed C exports can invoke the wrong engine entry point or bypass a C-
           stub check (such as E_FPENV), altering orders, wealth, and CS2.1–CS2.3; a mis-resolved include_str can silently
           read a wrong or empty protected-windows file, defeating A13's holdout refusal.
           Classification: Defect of the design (enforcement mechanism). Fix at the cause: (a) print the sorted
           (exportSymbol, constantName) table directly in frozen.txt (and check that no two exports collide and no
           unexpected mm2_* symbol is added); (b) restrict include_str in check-source.lean to the single designated file
           (e.g., Engine/Policy.lean) whose canonical resolved path equals protected-windows.json.

https://gemini.google.com/app/c5c5f9d87e7b802b                                                                                    4/7
11/21/26, 6:21 PM                                                   See attached instructions


     Finding 5. Legitimate subject fixes and Step 5a refactors are needlessly blocked by whole-file
     Laws.lean rooting and b94e128-frozen tactic syntax

           What it breaks: kernel-v2.md B2's operational goal that "A subject's body may change while the laws hold" without
           requiring a reviewed restatement of frozen.txt, and Step 5a's contract that "No frozen law statement in
           Engine/Laws.lean changes".

           Constructions:
               1. Every theorem in Laws.lean is a frozen.txt root: briefs/3-kernel-v2.md step 5x sub-step 1 roots
                  frozen.txt at "every theorem Laws.lean states" rather than an explicit list of the named ★ laws. When a
                  legitimate fix to a subject (e.g., Machine.feed, Orders.admit, or Step 5a's MachineCore.lean optimizations)
                  requires adding, renaming, or removing a helper lemma inside Laws.lean to re-prove an unchanged ★ law,
                  frozen.txt fails even though zero law statements changed.

               2. Specification functions referencing refactored subject structures: Machine.State is a subject (type-only),
                  while orderRun, snapshots, orderClock, Orders.admission, and Machine.prepare are specification
                  (printed in full). Step 5a replaces s.pending : List Pending with a binary min-heap Array (Nat ×
                  Pending) and c.quotes with a FIFO queue. Any specification function that constructs or updates
                  Machine.State via { s with ... } (which elaborates to positional State.mk over every field) or reads a
                  refactored field changes its elaborated Expr and breaks frozen.txt on a purely internal optimization.
               3. Freezing syntax.txt strictly to b94e128's 269 kinds: While allowlisting syntax genuinely fails closed against
                  new metaprogramming forms, restricting syntax.txt solely to whichever syntax kinds happened to appear in
                  b94e128 means any benign Init proof tactic or construct absent from b94e128 (for instance omega, calc,
                  rcases, conv, subst, or @[simp] on a local proof helper) blocks Step 5x's new proofs, Step 5a's proofs, or
                  routine subject fixes, forcing repeated architect walls.
           Outcome it could change: None directly on judged numbers (this fails safe, not unsafe). The operational cost is real:
           frequent false rejections on valid subject fixes create pressure to churn frozen.txt (diluting the signal of a reviewed
           restatement) or rubber-stamp ad-hoc syntax.txt additions.
           Classification: Defect of the design (scoping/usability, not soundness). Fix at the cause: (a) root frozen.txt at
           an explicit manifest of the named laws (L0, L1, L1a, ..., X6) plus the frozen (exportSymbol, constantName) table,
           leaving helper lemmas in Laws.lean free; (b) keep specification observers decoupled from Machine.State.mk and
           internal queue fields; and (c) review and admit the clean pure subset of Init proof tactics up front rather than gating
           on b94e128's incidental tactic usage.
     (Minor implementation checks to note while building check-source.lean, not promoted to separate findings: ensure
     namespace resolution rejects _root_ escapes inside Engine; ensure file discovery recurses properly into all subdirectories
     of Engine/ rather than relying on non-recursive globbing; and verify that collectAxioms iterates over all declarations
     emitted by library modules rather than filtering constant names by an Engine. prefix, which def _root_.Foo would evade.)

     What I accept
           The parse-time allowlist is a genuine boundary change, not just the next denylist—once Finding 1
           (Lean.reduceBool/Lean.reduceNat/sorryAx) and Finding 4 (export table, include_str path) are closed.
           Restricting library imports to Engine.*, banning prelude, restricting namespace/open to Engine.* (where Init
           defines no scoped syntax), pinning lakefile.lean's SHA-256, and running check-source.lean inside the flake's
           shared engine build before lake build genuinely eliminates the rounds 10–12 whack-a-mole over
           @[implemented_by], @[extern], @[init], unsafe, partial, disguised Std.* modules, and local macros.

           Splitting frozen.txt by meaning (subjects vs. specification) rather than by file (Laws.lean) is the right re-
           derivation. Printing specification in full across all modules stops GPT's FrozenVocab, Shadow, MovedClock, and
           AdmissionEquity attacks cleanly. The remaining error is classification (Findings 2 and 3), not the mechanism itself.

           Making Orders.cancelSlot, Orders.install, and Orders.admission specification closes the
           AdmissionEquity hole for R1.



https://gemini.google.com/app/c5c5f9d87e7b802b                                                                                       5/7
11/21/26, 6:21 PM                                                    See attached instructions


           Retracting the claim that bitsOps's Float operations hold by definition under the laws, and stating plainly what
           rests on the trust boundary and finite tests (Float arithmetic, input parsers, and unproved log/view/post-listing
           records until P1).
           Export-rooted compiled IR walking (Lean.IR.declMapExt) over .fap/.pap across all library modules is
           complete for Lean 4 IR function references (including 0-ary closed constants) and correctly scoped as a speed check
           rather than a soundness check.
           Adding L0 to tie Machine.start to Machine.prepare is the right idea; it just needs to cover startAdmission,
           policyText, and the rest of the initial state (Finding 3).

           The incremental exact twins, X6 count clauses, Test 12 timing as a recorded measurement, and Step 5x's
           internal commit ordering (L0 in sub-step 1, X6 in sub-step 4). (Also note that Machine.bind has the same
           invariance-only classification issue as Eval and check in Finding 2: L5 enforces binding invariance, not functional
           identity.)

     Ledger
     Agreed
           Pre-build parse-time allowlisting over Init's parser inside the flake's shared engine build is the right architectural
           boundary (replacing round 12's first post-build denylist).
           Meaning-based frozen.txt (subjects by type, specification in full, stopping at Init modules) replaces file-based
           freezing and closes FrozenVocab, Shadow, MovedClock, and AdmissionEquity.
           Orders.cancelSlot, Orders.install, and Orders.admission belong in specification.

           bitsOps's Float ops, input parsers, and unproved log/state records are honestly attributed to the trust boundary and
           finite tests rather than laws.
           Export-rooted IR walking over .fap/.pap across all library modules is sound for detecting non-firing @[csimp]
           (speed only).
           X6 incremental exact twins, L0's purpose, Test 12 timing as a measurement, and Step 5x's sub-step ordering.

     Disputed

      # Dispute                                                       Classification      Would change what is built or run?

          Native reduction purity (sorryAx +                                              Yes. Ban Lean.reduceBool,
          Lean.reduceBool/ofReduceBool): sorryAx is a                                     Lean.reduceNat,
          safe, computable Init constant passing check-                                   Lean.ofReduceBool,
          source.lean, letting build-time native reduction run        Design defect       Lean.ofReduceNat, and sorryAx in
      1
          arbitrary IO, poison .o files, write clean .oleans, and     (soundness)         check-source.lean (closing build-time
          IO.Process.exit 0 before warningAsError or                                      execution completely rather than relying
          collectAxioms runs (verify 4.34.0 interpreter                                   on post-build checks), and add a negative
          behavior on sorryAx).                                                           fixture.
                                                                                          Yes. Move Eval (and any non-
          Eval (plus check and Machine.bind) classified as
                                                                                          determined AST-handling part of
          subjects while bitsOps is specification: No law
                                                                                          check/Machine.bind) out of the
          functionally determines Eval's values; corrupting Eval
                                                                      Design defect       subject list into specification—or
      2   polymorphically via N.toExact/N.ofExact (or .std
                                                                      (soundness)         explicitly acknowledge in B2 that
          window length) leaves bitsOps, frozen.txt, X4–X6,
                                                                                          freezing bitsOps alone does not freeze
          Test 12, and B4 untouched and defeats the
                                                                                          what Eval computes—and add an Eval-
          BitsOpsAdd fix.
                                                                                          corruption fixture.



https://gemini.google.com/app/c5c5f9d87e7b802b                                                                                        6/7
11/21/26, 6:21 PM                                                See attached instructions


      # Dispute                                                   Classification      Would change what is built or run?

          policyText type-only, L0 omitting
                                                                                      Yes. Verify policyText's exact AST in
          startAdmission and initial state fields, and
                                                                                      check-source.lean (or kernel equality
          Machine.State shadow fields: policyText can
                                                                  Design defect       to protected-windows.json bytes on
          strip future holdout windows; startAdmission is
      3                                                           (soundness &        disk in check-proofs.sh); extend L0 to
          unbound; L0 binds only cfg/prog/rules and leaves
                                                                  holdout)            cover both Machine.start and
          account (starting cash), quotes, pending, wishes,
                                                                                      Machine.startAdmission and bind all
          orders, views, evalState, nextTick, lastTime,
                                                                                      observable initial-state components.
          rejected, and log unbound.

        Unfrozen @[export] symbol table and depth-
        sensitive include_str check: frozen.txt omits                                 Yes. Print the sorted (exportSymbol,
        (exportSymbol, constantName) bindings,                                        constantName) table in frozen.txt,
                                                                  Design defect
      4 enabling export swaps or mm2_* C-symbol collisions                            and check include_str's source file
                                                                  (enforcement)
        without changing frozen.txt; include_str literal                              and canonical resolved path in check-
        string "../../protected-windows.json" resolves                                source.lean.
        to different files by directory depth.
        Legitimate subject fixes blocked by whole-file                                Yes. Root frozen.txt at an explicit
        Laws.lean rooting, State.mk coupling, and                                     named-laws manifest rather than every
                                                                  Design defect
        b94e128-only syntax.txt: Helper lemmas in                                     theorem in Laws.lean, decouple spec
      5                                                           (usability, fails
        Laws.lean, Step 5a's Machine.State refactors, and                             observers from State.mk/internal fields,
                                                                  safe)
        benign Init proof tactics break frozen.txt or                                 and admit a reviewed pure Init tactic
        syntax.txt without changing any law or semantics.                             set up front.

     Would any open dispute change what is built or run? Yes—Findings 1 through 4 each change check-source.lean,
     check-proofs.sh/frozen.txt, L0, and checks.engine-proofs-fixtures on soundness or holdout grounds, and
     Finding 5 changes frozen.txt's rooting and syntax.txt's initial list so legitimate subject fixes and Step 5a can land
     cleanly. Round 12's kernel half has not yet converged; Step 5x should wait until these are resolved.




https://gemini.google.com/app/c5c5f9d87e7b802b                                                                                   7/7
```
