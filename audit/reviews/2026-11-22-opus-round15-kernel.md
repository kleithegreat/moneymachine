# Fresh Opus on round 15's kernel half

A fresh Claude Opus 5.5 subagent at maximum effort, labeled as `CLAUDE.md`'s fallback: GPT's filter refuses the build boundary and its budget is reserved (the human, 2026-11-22). Neon reads the round too (bundle with the human). Worktree `rearchitecture` at `78a35a3`; experiments under `~/.cache/mm-r15k-review/` on the pinned Lean 4.34.0. Run 2026-11-22 12:58 to about 17:25 UTC (07:58 to 12:25 EST), across one usage stop. The review, verbatim:

# Fresh Opus on round 15's kernel half (CLAUDE.md's fallback reviewer)

Claude Opus 5.5 at maximum effort, a fresh session that built none of round 15, reviewing it whole because GPT's filter refuses the build boundary; Neon reads it too. Worktree `/home/kevin/repos/mm-review-r15k` at `78a35a3`, nothing edited or committed; experiments on the pinned Lean 4.34.0 under `~/.cache/mm-r15k-review/`. 2026-11-22, 12:55 to 17:18 UTC (07:55 to 12:18 EST), a usage stop from about 13:15 to 17:00 costing no finding. No `data/holdout/`, no market data from 2026-11-01 on, no token or key file.

## Findings

### 1. The boundary: unification opens a closed trigger, so the walk's criterion is not what reaching a trigger needs (design; built)

**What it breaks.** B2's derivation that a term reaches a trigger "by naming the trigger, or by naming any constant whose statement holds a trigger whose evaluated argument a binder chooses", and the walk built on it. Command elaboration runs with first-order approximation on (`Lean.Elab.Command.mkMetaContext`, `foApprox := true`), and the partial application `autoParam α` is a subterm of every closed occurrence: comparing binder domains `F a s =?= autoParam (Nat → Nat → Bool) Array.insertionSort._auto_1` assigns `F := autoParam` and makes `S` `Lean.Syntax`. So every constant that holds `autoParam` at all exposes it. On 4.34.0, 220 constants of `Init` do (205 in their types, among them `Array.insertionSort`, `Array.qsort`, `Array.set` and twelve constructors); the walk flags none, by its criterion. No `Init` constant holds a closed `Lean.reduceBool` or `Lean.reduceNat`.

**Construction, built** (`~/.cache/mm-r15k-review/fo/N2.lean`): round 15's N1 with `autoParam.eq_def` replaced by `@Array.insertionSort Nat`, passed to `ofDom` and `mkTrigger` at `(_ : Array Nat → F a s → Array Nat)` with `{S : Type} {F : Type → S → Type}`; `smuggled` is N1's syntax unchanged; `trigger := mkTrigger (@Array.insertionSort Nat) smuggled rfl`. It compiles; the kernel proves `g = 4` (axioms: `propext`); the compiled `g` returns 999 (`N2eval.lean`). Every kind and atom it uses is one `b94e128` uses (literals aside: `N2.ka` against `b94.ka`), no identifier has a `Lean` or `autoParam` component, and its one key is `namespace Engine`. The constant need not be named: `@xs.insertionSort`, field notation on any `Array Nat`, gives the same type (`T4.lean`).

**Outcome.** All four clauses pass (the axioms clause sees `propext`, the frozen print shows a subject by its type, the production clause seeks only the four replaced originals) while the compiled engine departs from the proved one: any of CS2.1 to CS2.3. Round 13's `@[init]` variant runs `IO` during the build.

**Fix: the design.** The rule bounds names; what reaches a trigger is unification, which no reading of names bounds, and field notation defeats any list of names short of refusing `set`, `mk` and the like as components. The trigger has to be closed where it fires. Hypotheses for the architect: a pinned toolchain patched so `evalSyntaxConstant` (the auto-param handler's and the delaborator's) evaluates only the toolchain's own constants; or a re-derivation I have not found. A datum for either: in my tries only explicit mode (`@C`, `@x.f`) kept the binder unconsumed; an ascription, a `fun`, `exact` and `apply` each fill or strip it (`T5.lean`, `T6.lean`). Whether refusing explicit mode (written once in `b94e128`, in X3's statement, and in X6's) would be complete is a derivation, not a patch I propose. Independently, the boundary has no second line: a clause after the build that no library constant carries an `implemented_by`, `extern` or `init` entry, and every `export` is listed, would have failed N2's compiled half (not build-time `IO`, which only the sandbox contains).

### 2. The observation: admission's obligation reads the world's market state, which no law ties to the inputs (design, or at least text; not built)

**What it breaks.** B2's first rule (a law's obligations are the inputs' and the specification's) and its claim that "every part of that state a later step reads is checked", with its list of exceptions. R1's obligation at an arrival, A6's three conditions, is `arrive a.before a.wish`, and `a.before` is `worldBook`, whose margin and equity are at the adverse marks built from each coin's running `bid`, `ask` and `price` (`MachineCore.lean`, `worldBook`), with the rules `prepare` rounds by and the coins that ended. The arrival chain binds them within a millisecond only; L1c binds the account, which holds no mark; L1a is an invariance, which a deterministic error passes; no record observes a quote's effect on the world. It is the ledger's check 3 exactly: a value carried from a quote to a later arrival, read by a law at the second end only. The exception list names the rules and the ended coins only as C2's, and the marks not at all.

**Construction** (a reading, against laws not yet written): `applyPayload` keeps a coin's first best bid and never replaces it, records honest. Every arrival's before-book is the state's projection and its after-book `arrive`'s, so R1, the chain, L0, L1a, L1c, C1, C2, S1 and X1 hold, while a buy is admitted by margin at a stale adverse mark. B4's tick rows hold the world's price, not its bid or ask.

**Outcome.** Which orders are placed, so fills: CS2.1 to CS2.3. Round 15's A18 change widens it: a delisted coin now settles at the world's running price, which until this round was the ending record's number, an input C2 checked.

**Fix.** Preferably the design: the market part of an arrival's before-book as the specification's reading of the moves (each coin's latest admitted quote's best bid and ask, its A3 price, the rules in force and the ended coins), as `slotKeysAt` reads the coins in view; then admission's obligation is the inputs'. Otherwise the text: list the world's market state among the machine's word, with what holds it.

### 3. Study 2's ending: its `known` skips the listings' lag on the flagging copy (text, owed to study 2's half; not built)

A18 dates the ending at the later of its hour plus the listings' lag and the flagging copy's time. Any other change a copy carries is known no sooner than the copy's time plus that lag (A18's `lag`; admission rejects less), so an ending flagged after its hour plus the lag is known up to a lag (an hour in A18's example header) before a rules change in the same copy. `max(H_end, t_F) + lag` treats them alike. Only when the coin leaves the view moves, and so cross-coin inputs: I see no verdict it changes.

### Minor (text)

- L1c's "its position, `filled`, `resting`, `resting_price`, cycle and opening order all" is the account's; `age` reads a counter outside it (`vage`, set in `aged`), carried from tick to tick, which no law reads and B4's slot-free programs never reach. The exception for the evaluator's inputs should name it.
- B2's "every law observes a run through `orderRun`": C1 and C2 read `feed` and `finish`, production's own, which is stronger.
- Brief 3, step 10's summary of the sale (line 575) still reads "all of them when the account sold all"; K1 now says "or more".

## What I confirm

- **Neon 1 and 6 as answered:** the any-component rule closes `autoParam.eq_def`; `b94e128` writes no refused identifier; the shared build running all four clauses in one derivation, without `LEAN_CC` or `LEAN_AR`, closes `PolicyShadow`'s release binary.
- **The observation's cause and the fourth rule.** Each tick recording itself in the one fold, L0 both ways (by `RunSim`'s equality the flag and `orderRun` agree, an abort false on both sides), L1a on `orderRun` with the wire premise, and the typed flag through C1, C2 (after the suffix) and L1a's witness, close GPT-6.2's and Neon's findings at their cause.
- **L1c as a ★ law:** it fails `QueueDrop` and `LateRelease`; an early release leaves it true and fails L1a, which is universally quantified over markets that differ within `δ`.
- **R1:** `wishAt` is provable from the record (`slotEvalAt` reads only the node and exact values, and the cycle is `r.account`'s); the chain fails `ArrivalOrder` whether the records are in production's order (A6's order fails) or sorted after (`b.before = a.after` fails). Deleting the order clauses on admissions and placements loses nothing, though not as the chain's consequence: no law reads those lists' order but R1's comparison of the two with each other.
- **K1:** `m = h` at `−u ≥ q`, the ending row counted first, the reserve after a buy that buys; `~/.cache/mm-r15k/k1_fold.py` passes all its checks, Neon's flip included. Step 10's 3,411.1.
- **A18's end** where settlements stop, its hour not due, later events cut; settlement at zero is unreachable.

## Ledger

| Point | State | Changes what is built? |
|---|---|---|
| 1. Closed triggers opened by unification | Disputed: built on 4.34.0 | **Yes:** the boundary's rule |
| 2. Admission reads the world's market state | Disputed | **Yes** if bound; text if listed |
| 3. The ending's `known` | Open, study 2's half | Reader only |
| Minor texts | Disputed | No |
| Neon 1 and 6's answers, the fourth rule, L0, L1a, L1c, R1, C1, C2, K1, A18's end | Agreed | No |

**Does any dispute change what is built?** Yes: finding 1 changes the boundary before sub-step 1 can be built, and finding 2, if the architect binds rather than lists, changes R1 and sub-step 2's contract. Not converged.
