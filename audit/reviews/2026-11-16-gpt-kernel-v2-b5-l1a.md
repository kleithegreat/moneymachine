# GPT on B5's wall and L1a (D125 to D129, `rearchitecture` `e5b8d3f`)

Model `openai/gpt-6.1-sol#high` (opencode), read-only, from a clean worktree of `rearchitecture` at `e5b8d3f` with the step 4 builder's Lean tree (`kernel2-step4-wip` `d0edd91`), the architect's brief and report, and the B5 profile. Prompt: `PROMPT.md` below the reply. The reply, verbatim:

**I accept D126–D129 as semantic design decisions. I accept D125 as a budget choice, not a derived necessity. I found no two admitted markets satisfying L1a’s premises whose ticks through τ differ. The main weakness is what the proposed tests establish.**

## 1. D128: the derivation is sound

In `step4-wip/kernel2/lean/Engine/Laws.lean:931–940`, **both streams must be admitted**. Admission enforces `known = time + δ` for quotes and prints (`Machine.lean:367,382`). Consequently:

\[
known \le τ \implies time \le τ-δ.
\]

This follows from admission—not from equality of the filtered lists alone.

Every listing governing that event precedes it in world order and has `time ≤ τ−δ`; the second premise therefore includes it in both markets. This covers a listing sharing the quote’s millisecond and a listing whose `time` and `known` straddle the boundary.

The remaining attacks do not break the statement:

- A listing after `τ−δ` cannot govern a quote visible by τ.
- A visible tail ending only changes the view’s ended flag.
- Tail funding carries its rate and optional oracle read at fixed scales 12 and 8. The world-price fallback affects its trace row, **not** its view oracle.
- Observations carry their own bits.
- Known-time ties preserve world order.
- A rejection in one market makes `snapshots = none`, violating the theorem’s premises.

**Text defect:** rejection after deleting an unknown listing does **not** demonstrate that L1a without its second premise is false while retaining both admitted-stream premises. It demonstrates that deletion need not preserve admission. That mistaken argument changes no judged result.

## 2. D126 and D127: accepted, with a precise boundary

Reading once preserves the built machine’s values: admission and `applyPayload` use the same rules. The intervening `fireRec` runs ticks, which do not change `s.rules`. Thus no reading moves to another event-time scale.

With the captured scale retained, replacing rational sign/order comparisons by integer comparisons is exact because `10^scale > 0`. Prices remain scale 8; sizes use the event’s governing `szDecimals`; funding rates use 12; tier bounds use 2.

X3’s two universal equalities are suitable bridges for reproving **unchanged** C1, C2 and X2. In particular, its grid equality includes the scale argument, negative decimals, zero figures and nonpositive integers. There is no implemented `onGridAt` here to certify; the specified equality is adequate.

**But these laws are not an old-machine/new-machine observational-equivalence theorem.** C1 establishes chunk independence; C2 requires rejection of listed faults; neither fixes every successful value or first-fault diagnostic.

## 3. Concrete test gaps

### A. A leaking carrier implementation can pass the proposed examples

Take δ = 1,000 ms, τ = H + 2,000, initially `szDecimals = 2`:

- Both markets contain a quote at `H + 1,000`, known at τ, with size `1.23`.
- Only market B contains a listing at `H + 1,500`, known well after τ, changing `szDecimals` to 3.

Both markets are admitted and satisfy both L1a premises.

A wrong implementation caches integer `123` but converts it using the **current world scale at release**. At τ, A exposes `1.23`, B exposes `0.123`.

This mutant passes step 4 test 6’s particular construction: there, the scale changes **before** the quote, with no subsequent change while it waits. Test 7 checks numeric readers, not the carrier. Admission-only speed and grid tests do not exercise this path.

**Outcome:** an unknown listing leaks into `bid_size`, potentially changing order sizes and judged results.  
**Classification:** test-coverage defect, not a defect in D126/D129. A genuine proof of L1a rejects this mutant. Add the pending-quote/later-listing pair explicitly.

### B. First-fault preservation is insufficiently tested

Feed a trade with price zero and an unreadable size. The built machine checks price first and returns `R_MARKET`. An optimizer that reads every field before validating returns `E_DECIMAL`.

Both reject permanently; C2’s statement still holds. The proposed isolated-fault tests and X3 need not distinguish them.

**Outcome:** a different published rejection diagnostic; no numerical criterion change demonstrated for this construction.  
**Classification:** verification gap only. D126 explicitly requires preserving fault order; test simultaneous faults and compare the complete fault.

## 4. D125: sound separation, chosen budget

Separately budgeting strings and doubles is correct. Dividing the approximate quote counts by 12 and 24 hours gives the stated approximate rates. The supplied profile supports removing repeated reads and rational construction, but does not measure the proposed string implementation.

“One day per run” and allocating half to admission are **choices**, not consequences of the account’s semantics. The archive relaxation changes readiness and fitting cost, not CS2’s frozen thresholds or a completed deterministic run’s numbers. It must not silently become permission to shorten evidence or reduce trials; none is specified here.

## Ledger

**Agreed:** D126, D127, D128 and D129’s semantics; D125’s separate budgets; no demonstrated semantic counterexample; no demonstrated lost recording.

**Disputed:** calling D125’s day allocation derived; using a rejected stream to refute an admitted-stream theorem; treating the proposed tests and X3 as establishing complete observational preservation.

## Prompt

You are an adversarial reviewer of the project's architect (Claude Fable). The repository here is branch `rearchitecture` at e5b8d3f (read CLAUDE.md for the process). The architect was given `brief.txt` and answered in `architect-b5-report-1.md`, committing e5b8d3f (`git show` is not available to you; the changed files are audit/program/briefs/3-kernel-v2.md steps 3 and 4 and step 6 test 11, audit/program/kernel-v2.md B1, B5, L1a, X3 and part G, kernel2/KERNEL.md A18, audit/program/ledger.md D125 to D130 and O21 to O23). The step 4 builder's Lean tree, which the architect read, is in `step4-wip/kernel2/lean/` (Engine/Machine.lean holds `admit`, `applyPayload`, `advanceRec`; Engine/Laws.lean holds L1a's statement, still `sorry`). The profile the decision rests on is in `profile/`.

Try to break D125 to D129 at the theoretical level. In particular:
1. **D128 (L1a by its second premise):** is the derivation sound for L1a's statement as written in Laws.lean? Construct, if you can, two admitted markets equal in what is known by τ whose ticks through τ differ under the machine D126 describes (a listing, an ending, funding, an observation, a quote sharing a millisecond, a listing whose `time` and `known` straddle τ − δ, a rejection in one market only). Check the claim "a quote or print known by τ has time ≤ τ − δ" against the premises.
2. **D126 (the machine keeps its readings):** does reading once at admission and carrying integers at their scales change any value a judged run can see (a row, a view value, a fault and its order), relative to the machine as built? Is any reading now made at a scale other than the one in force at the event's time?
3. **D127 (X3's two equalities):** do they suffice for C1, C2 and X2 to be proved of the integer machine unchanged in statement; is `onGridAt` equal to `onGrid` on every input the machine passes, scale included?
4. **D125 (the wall per run):** is the derivation of the two rates from what each run is for sound, and can it change any judged result or criterion?
5. **D129 (the view does not read)** and the tests the architect asks for (step 3 tests 6 to 8, step 4 tests 6 and 7): would a machine that is wrong pass them?

Each finding: what it breaks, a concrete construction, the outcome it could change (a judged result, a leak, a lost recording), and whether it is a defect in the design or only in the text. Say plainly which decisions you accept. End with a ledger: agreed, disputed. Be concise.
