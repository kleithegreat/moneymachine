# GPT on round 12, item 1 (kernel v2's guard, the frozen laws, routing)

Model `openai/gpt-6.1-sol#high` (opencode), read-only, from a clean worktree of `rearchitecture` at `f19ffb8` with step 5's code copied in and the round 12 brief and report (item 1 finished, item 2 in progress) attached. Run 2026-11-21 15:00 UTC (10:00 EST). Its last line, a cancelled web search it was not allowed, is dropped. The prompt is below the reply. The reply, verbatim:

## Verdict

**Accept the incremental arithmetic and most of round 12’s corrections. Do not yet accept the guard’s completeness or the claim that the frozen surface fixes every law’s meaning.**

This was a read-only, theoretical review. I did not execute the constructions below or review item 2.

## What I accept

- **Provenance:** checking the build directory before importing, then checking loaded artifact paths, closes my namespace construction at its cause. The reported search-path accident does not weaken that correction.
- **`@[init]`:** rejecting its persisted extension closes the architect’s demonstrated bypass. An allowlist is materially better than checking three known attributes.
- **X4–X6:** with the present decoding vocabulary fixed, X5 determines `nearestBits`, X4 determines `exp` and `log`, and X6 transfers those functions to the twins universally. I found no new recurrence, rounding or count counterexample.
- **Legitimate subject fixes:** leaving `nearestBits`’s body mutable is correct. Its negative-underflow correction can land without changing X5.
- **IR reachability:** starting at exports and traversing all project modules closes the `Engine.Exact` exemption. Its numerical consequence remains none; this is a speed check.
- **Routing:** brief 3’s “How every step runs,” item 4, now supplies the two fresh reviewers required by `CLAUDE.md`, including separation from the test writer. Option A’s omission is closed.
- **Timing:** recording measurements rather than enforcing an extrapolated three-hour budget is appropriate. The revised trigger qualification is accurate.

## 1. Persisted extensions do not cover temporary elaborator state

**Breaks:** B2’s inference that absence of persisted project syntax leaves literal `#eval` as the only executable source form needing inspection.

**Construction:** use a **local command macro**, inside a section, that emits the parser’s evaluation-command syntax. Construct the command atom as `"#" ++ "eval"` rather than putting the contiguous forbidden text in the source. End the section afterwards.

Local parser/macro registrations are scoped elaborator state; they need not survive into the module’s exported extension entries. The generated macro implementation is an ordinary declaration. Consequently:

- the source need contain neither forbidden substring;
- no project `Lean.*` import is required merely to construct syntax;
- the evaluation command runs during elaboration;
- inspecting the final module’s persisted entries does not establish that this never happened.

The emitted command can execute ordinary `IO`, including starting a process or modifying build outputs. Use that capability to replace a compiled implementation while retaining its kernel declarations and the inspected IR. Put the numerical corruption at an argument absent from Test 12 and B4.

This is a theoretical construction, **not a fixture I ran on 4.34.0**. In particular, the precise locally generated declarations and exported entries should be checked before claiming this route closed.

**Outcome:** a corrupted compiled `exp` can return `1` at an otherwise untested input in `[1,2]`. A trigger `exp(x) > 2` then changes an entry; suitable admitted market events change wealth and CS2.1–CS2.3. Identical deterministic corruption on both hosts passes the cross-host comparison.

**Classification:** an acceptance-design gap, not an arithmetic defect. It violates the intended pure-engine policy, but the proposed algorithm does not establish that policy. Trusting the flake’s build script does not establish that project elaboration executed no additional code.

**Required resolution:** cover code executed during elaboration, including temporary registrations and expanded commands—not merely source substrings and final persisted entries. Add a local-macro-generated evaluation fixture. Adding another forbidden spelling would repeat the same cause.

## 2. File ownership still substitutes for semantic ownership

**Breaks:** the assertion that the frozen print fixes a law’s meaning while excluding only its constrained subjects.

Brief 3:189 freezes definitions **declared in `Laws.lean`**, plus three encoding definitions and exported declarations. That is not a classification of specification vocabulary.

**Concrete example:** `review-inputs/step5/Laws.lean:1386–1388` defines R1’s required deciding timestamps using:

```lean
orderHorizon initial
orderClock initial
slotKeysAt initial moves τ
```

Those definitions are outside `Laws.lean`. R1 does not itself equate `orderClock` with the program’s declared clock.

**Construction:** for an untested declared tick—say 17 seconds—make `orderClock` report 34 seconds and make the running scheduler use that clock. Leave other clocks and the concrete witnesses unchanged. R1 still requires, and receives, precisely the wishes at the newly defined timestamps.

The theorem’s kernel expression still names the same `orderClock`; no frozen line needs to change. X4–X6 are untouched. Test 12 exercises numerical functions, and B4’s one-hour programs miss this case. The compiler can faithfully execute the wrong kernel definitions: no unsafe mechanism is necessary.

**Outcome:** the strategy misses a deciding tick and its order. A price move between the intended and substituted ticks changes fills and wealth, potentially changing CS2.1–CS2.3.

**Classification:** a design defect in semantic freezing and characterization. The original X4 helper attack is closed for today’s law-owned formulas, but **its general cause is not closed**: the check still excludes vocabulary because of where its definition lives.

The needed distinction is:

- fixed specification vocabulary;
- mutable subjects whose obligations are expressed over that fixed vocabulary;
- implementation helpers.

A name’s module does not decide which category it occupies. `orderClock` must either have its specification meaning fixed or be universally constrained to the declared clock. Apply the same examination to the other non-`Laws.lean` specification dependencies; do not indiscriminately freeze every reachable implementation body.

## 3. “Uses `bitsOps`” does not establish all of `bitsOps`

**Breaks:** the report’s claim that the machine’s use of `bitsOps` supplies the remaining binding “by definition under the laws.”

X4 explicitly binds four fields: `exp`, `log`, `ofExact` and `toExact`. It does not characterize every other field.

**Construction:** change `bitsOps.add` at one untested operand pair, preserving its ordinary definition elsewhere. A symmetric exceptional pair can preserve commutativity if that matters. Do not change the four X4-bound fields.

The supplied language laws are largely parametric in `NumOps`; proving a property for arbitrary operations does not establish that the concrete addition is IEEE addition. The frozen surface does not include `bitsOps`’s body. X6 and Test 12 remain unchanged, and a pair absent from B4 leaves B4 unchanged.

**Outcome:** use the exceptional sum in a trigger comparison or an `exact(·)` crossing. That changes an order and can change CS2.1–CS2.3.

**Classification:** a characterization/binding gap, **not** a new compiled-versus-kernel bypass. The guard can correctly establish that compiled code implements the kernel definitions while both implement the wrong arithmetic.

This does not justify freezing all evaluator internals. It requires either a fixed concrete-operation specification with proved bindings, or an explicit acknowledgment that these fields remain held by finite testing and review rather than universally by the laws.

## Freeze precision and remaining qualifications

For **X4/X5 specifically**, the revised surface appears appropriately chosen: today’s `decode` and `magValue` bodies reach trusted core arithmetic, and the law-owned series definitions are fixed. I found no way to move those formulas unseen without another bypass.

Freezing exported **bodies** also rejects some semantics-preserving wrapper refactors. That is administrative overrestriction, not a demonstrated judged-result defect, so I do not press it.

Likewise, I found no actual cap-exhaustion input. The existing qualification remains sufficient; I ask for no ball twin or additional numerical method.

## Ledger

| Point | Position | Would a dispute change what is built or run? |
|---|---|---|
| Incremental twins, rounding and X6 counts | **Agreed** | No arithmetic change |
| Artifact provenance; rejection of demonstrated `@[init]` | **Agreed** | Existing corrections retained |
| Export-rooted IR walk | **Agreed**, speed only | No additional demand |
| Two-reviewer routing; timing as measurement | **Agreed** | Existing corrections retained |
| Temporary syntax and generated build-time evaluation | **Disputed/open**; pinned-toolchain fixture not run here | **Yes:** guard boundary and fixture |
| Non-law-file specification vocabulary, exemplified by R1’s clock | **Disputed/open** | **Yes:** frozen surface or characterization |
| Concrete `bitsOps` fields beyond X4’s bindings | **Disputed/open** | **Yes:** binding obligations or narrower assurance claim |

**Not converged:** the open points affect what acceptance checks establish and therefore what must be built or checked.

## Prompt

You are an adversarial reviewer of the project's architect, a fresh Claude Opus 5.5 session. This directory is the repository at branch `rearchitecture` (read CLAUDE.md for the process); it is read-only for you.

You reviewed rounds 10 and 11 (`audit/reviews/2026-11-21-gpt-round10-11.md`): you accepted the incremental exact twin and found a module named into a trusted namespace carrying `@[implemented_by]`, X4's statement text unchanged while the law-owned definitions it names change, the IR scan's blind spot inside `Engine.Exact`, and review routing Option A. Round 12's first item answers you (brief `review-inputs/architect-r12.txt`; report `review-inputs/architect-r12-report.md`, item 1; its second item, on study 2's record, is still in progress and not yours to review here). Its revisions: `audit/program/kernel-v2.md` B2 (the guard re-derived from artifacts: provenance by loaded file, listed extensions only, the frozen kernel meaning of the laws, the walk from the exports; commit 9590d3f) and `audit/program/briefs/3-kernel-v2.md` step 5x (commit f19ffb8). Step 5's code as built is in `review-inputs/step5/`.

Try to break item 1 at the theoretical level: can a twin or any engine code that is wrong at an argument a study reads pass the revised guard, X6, test 12 and B4; does the frozen meaning of the laws pin what it must and nothing it must not (can a legitimate fix to a subject still land; can a law's meaning move unseen); is the review routing now `CLAUDE.md`'s; and are your earlier findings closed at their cause. The architect found one more bypass itself (`@[init]`); check its answer too.

Each finding: what it breaks, a construction, the outcome it could change (a judged result of CS2.1 to CS2.3), and whether it is a defect of the design or only of the text. A finding that cannot change an outcome is noted, not pressed. Say plainly what you accept. Under 2,000 words. End with a ledger: agreed, disputed, and whether any dispute would change what is built or run.
