# Fresh Opus on round 16's kernel half

Claude Opus 5.5 at maximum effort, a fresh session that built none of round 16, reviewing it whole: Neon architected it, and GPT's filter refuses the build boundary. Worktree `/home/kevin/repos/mm-review-r16k` at `926855d`, nothing edited or committed. Experiments on the pinned Lean 4.34.0 under `~/.cache/mm-r16k-review/`, running copies of the architect's own `stage1_export.lean` and `stage2_end2end` unedited. 2026-11-22, 23:07 to about 23:55 UTC (18:07 to 18:55 EST). No `data/holdout/`, no market data from 2026-11-01 on, no token or key file.

## Findings

### 1. The boundary: a safe subject can keep hidden state through `Init`'s ST primitives (design; built)

**What it breaks.** B2's claim that the two stages fail closed ("no source construct ... can make the shipped binary depart from the kernel-replayed definitions or violate any frozen law"), and D1's "in Lean this is purity". In 4.34.0 `Void.mk : σ → Void σ` is a safe `@[extern, never_extract] opaque`, and `ST.Prim.mkRef`, `Ref.get` and `Ref.set` are safe externs. To the kernel each is a function of its token; at run time each touches a cell. Safe code may mint tokens at `σ := Unit` and reuse them, so the kernel's model holds only under a discipline nothing checks.

**Construction, built** (`st/`): a module-level `cell := (ST.Prim.mkRef (σ := Unit) 0 (Void.mk ())).val`; `counted x` reads it, sets it one higher, reads it again through the returned token and returns the first read plus `w - w`; `feedLike x = x * 1000 + counted x`, exported. `∀ x y, counted x = counted y` and `∀ x, feedExported x = x * 1000 + counted 0` prove (`propext`, `Classical.choice`). Stage 1 exports it; Stage 2 replays it, passes the policy literal and the axioms, compiles and emits C; linked, three calls of `mm2_feed_like(5)` return 5000, 5001, 5002. No attribute, reserved name or forbidden constant; inside a subject, printed by type, `frozen.txt` would not show it. Round 15's name rule would not have refused it either (no `Lean` or `autoParam` component); round 16 is the first to claim it is stopped.

**Outcome.** A subject's compiled behaviour can depend on its call history, so a law comparing two runs or two cuttings (C1, L1, L1a) holds of the kernel's `feed` and not of the binary: how OCaml cuts chunks could change the published report. Any of CS2.1 to CS2.3, through the machine's under-constrained parts.

**Fix (design, small).** A token is minted only by `Void.mk`, `runST` and `runEST` (nothing else in `Init` names `Void.mk`), but the fail-closed form is an allowlist: Stage 2 fails unless every toolchain constant the compiled closure's definitions reference is on a reviewed list taken from `b94e128`, reviewed again at a toolchain bump. Of the 1,344 toolchain constants `b94.kexp` references, none is `Void`, `ST`, `EST`, `runST`, `IO`, `EIO`, `BaseIO`, `Task` or a pointer primitive, so `b94e128` pays nothing. This construction becomes a fixture.

### 2. The boundary: the specializer's names are not on the filter's list, and Stage 2 carries on after the compiler panics (design; built)

**What it breaks.** The pre-replay filter's claim to close LCNF auxiliary-name collisions by refusing final components `_redArg`, `_boxed`, `_closed*`, `_spec*`, `_lam*`, `_jp*`. The specializer names its copies `f._at_.g.spec_N` (`LCNF/Specialize.lean`, `mkSpecDecl`), final component `spec_N`, without checking the name is free; Stage 2 refuses only names `Init` holds, not new names in its namespaces.

**Construction, built** (`spec/`, `spec2/`): `foo n l := l.foldl (fun acc x => acc + x * n) 0`, and a library constant `List.foldl._at_.Engine.Machine.foo.spec_0` returning 999, which an export names. Stage 2 accepts both, prints `getImpureDeclIndices: assertion violation` and 120 to 198 `key is not present` panics, exits 0, and emits one C function for the shared symbol: the impostor's when it compiles after `foo` (so `foo`, proved `fooExported 2 = 12` by `decide`, calls the 999 body), the specialization's when before (so the impostor's export, proved 999, runs `foldl` and returns 0). In both, the panics also misordered static closed terms and `leanc` rejected the C: closed by accident, by no check.

**Outcome.** Where the C compiles, a kernel-checked constant runs another's body: any of CS2.1 to CS2.3.

**Fix (design).** Two checks that need no list of the compiler's names: Stage 2 runs with panics fatal (`LEAN_ABORT_ON_PANIC=1`, which `env -i` drops) and fails on any message `Compiler.compile` logs; and after compiling it fails unless no name is recorded twice in `declOrderExt` and no library constant bears a name the compiler made for another. The suffix list then goes (`CLAUDE.md` §2). `_elam` is unlisted too but cannot arise in Stage 2, which holds no class instances (`elam/`).

### 3. The observation: R1's provenance clause is step 5's machine, closed with `False` (design or plan; not built)

**What it breaks.** Brief 3 step 6's "S1, R1 and X1 need no new proof but that each order's fill at an event is one `offer`", and step 7, which does not list R1. R1 admits an effect only in an arrival's slice (exactly `arrivalEffectsOf`), as a `cancelled … "rules"`, or in a step as a fill its trigger names, a `cycle_end` cancel or a `cycleEnd`; anything else is `False`. `KERNEL.md` A19 lists what steps 6 and 7 emit: `refused … post_only` at the arrival quote; cancels `inactive`, `ioc`, `listing_end` and `liquidation`; a liquidation's and a settlement's fills, with no slot; `paid`, `liquidated`, `bankrupt`. None has a clause, and `arrivalEffectsOf` writes an inactive slot's cancel as `replaced`, which A19 calls `inactive`.

**Outcome.** None directly: R1 becomes unprovable at step 6, a wall the plan says is not there, and the risk is a machine fitted to the clause (an `ioc` cancel logged inside a fabricated fill step).

**Fix.** State the partition now for the whole machine, a clause per source of effects with what binds it; or schedule R1's reviewed restatement in steps 6 and 7 and correct step 6.

### 4. The observation: a fabricated liquidation of a flat account cancels what R1 now forbids (text until step 7; not built)

Clause (c) and S1 both take a step's trigger from the machine's record. A step with trigger `.liquidation`, recorded while every position is zero, ending every coin and holding a `cycle_end` cancel of each resting order and a `cycleEnd` of each coin, meets clause (c) (every coin is in `ended`, both books match `acctAt`) and every clause of S1 (positions zero, cycles up by one, no orders after, no old-cycle placement or fill, the new cycle `δ + λ` later); L1c, L0, L1a, C1, C2 and X1 hold if a deterministic rule of the events fires it. That is `UnnecessaryReplace`'s outcome, a resting order silently gone, under another label. Only M1, built in step 7, says when a liquidation happens, so round 16 closes Neon's finding 4 when M1 binds `.liquidation` steps, not at step 5x as the ledger says. No judged run precedes step 7, so I see no verdict if M1 does; the text should say so and step 7's review check it.

### 5. The observation: no law requires a rule change's cancels (design, small; not built)

The partition binds the effects present, not those owed. A6 cancels a coin's orders at a listing that changes its rules; a machine that cancels none passes R1 (nothing to account for), S1 (an `.other` step ends nothing) and L1c, and the order rests on the old grid and can fill. Arrival slices are exact both ways and S1 forces a cycle end's cancels; rule changes alone are one-way. One clause closes it: no order in an arrival's or a step's before-book was placed before a `t` at or before that time at which `rulesChangedAt` holds for its coin. Outcome: fills of stale orders after a venue's rule change, so CS2.1 to CS2.3, rarely.

### 6. Study 2: the ending is known before the last fact its rule reads (text, owed to study 2's half; not built)

`known = max(R, t_F) + listings.lag` is called uniform with every other change a copy carries, but unlike a rules change the ending reads later records: it needs `B(e)`, the first whole hour after `t_F + 1 h`, to hold no settlement, knowable at `B(e) + late`. With A18's example header (lag 1 h, `late` 10 min) the view learns the end 10 to 70 minutes before that fact exists. Only view membership moves (wishes for the coin place nothing after `R`), so I see no verdict for the ladder, which reads no cross-coin input; `max(R, t_F, B(e) + late) + listings.lag` is causal.

## What I confirm

- **`marketAt` is `worldBook`'s market at every arrival.** `advanceRec` settles strictly before each event, so a millisecond's events precede its tick and the tick its arrivals; an arrival at `t` is drained only by a later event or by `finish`, after every event with `time ≤ t`. `offer` touches no market; `checkPrice` reads by `readInt 8` as `marketEvent` does; one-sided quotes are refused; both prepend `ended`. Holds at `λ = 0` and `δ = 0`.
- **L1c's split** is `releaseEffects`, and both bounds hold: before a tick every effect is at or before it (arrivals before it, events and offers at or before the previous event), after it none is earlier. At `δ = 0` the queue is empty.
- **`arrivalAdmission` and `arrivalEffectsOf`** are `arriveWish`'s admissions and `arrivalEffects` exactly, and one `drain` takes a millisecond's arrivals together, so the chain's equality holds.
- **The `brecOn` synthesis cannot change a value.** The kernel proves `foo = Φ foo`, so a compiled `_unsafe_rec` that returns gives `foo`'s value, by induction on its finite calls; strict descent buys only termination, and every occurrence of the recursive constant is checked, lambdas included. I found nothing passing both checks; nested, mutual and indexed cases throw.
- **`_sparseCasesOn`** is compared with a real regeneration (Stage 2's cache is empty, the fresh name differs); `@[csimp]` replaces only by kernel-proved equalities; 4.34.0 escapes C string literals in octal; library symbols carry `lp_engine_`, meeting none of `Init`'s or the runtime's.
- **Two derivations and a text DAG are needed:** Stage 1's build-time `IO` must not reach Stage 2's process, and an untrusted `.olean` would reach C++ as a compacted region. The `brecOn` synthesizer is the largest trusted piece; rewriting the 18 recursions would delete it, a judgment and not a finding.
- **Study 2:** `R_OFF_RULES` is gone from every live text; the reach rule matches A12 and K2.

## Ledger

| Point | State | Changes what is built? |
|---|---|---|
| 1. ST tokens give a subject hidden state | Disputed: built | **Yes:** an allowlist clause in Stage 2, a fixture |
| 2. Name collisions; panics not fatal | Disputed: built | **Yes:** fatal panics and errors, a uniqueness check in place of the suffix list |
| 3. R1's provenance clause ends at step 5 | Disputed | **Yes:** the partition, or the plan of steps 6 and 7 |
| 4. Fabricated liquidation while flat | Disputed | Text now; M1's statement at step 7 |
| 5. Rule-change cancels unbound | Disputed | **Yes:** one clause of R1 |
| 6. The ending's `known` | Open, study 2's half | Reader only |
| `marketAt`, L1c's split, `arrivalAdmission`, `arrivalEffectsOf`, the chain, `brecOn`, `_sparseCasesOn`, `@[csimp]`, two derivations, `R_OFF_RULES`'s erasure, the reach rule | Agreed | No |

**Does any dispute change what is built?** Yes: findings 1 and 2 change Stage 2 before sub-step 1 is built, and 3 and 5 change R1 before sub-step 2's statements are committed. Not converged.
