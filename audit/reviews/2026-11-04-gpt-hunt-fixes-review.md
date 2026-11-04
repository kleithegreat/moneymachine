# Review of the stage 7 hunt fixes (a095bab)

GPT (`openai/gpt-6.1-sol#high`, opencode), independent review from a clean worktree (no `data/`), at `a095bab`; started 2026-11-04 10:01 UTC (05:01 EST), reply received 10:09 UTC (05:09 EST). The reply as given, tool transcript omitted.

## Findings

1. **High — The admission differential crashes before comparing anything.**  
   `reference/admission_differential.py:47–58` deletes the non-evidence branch’s only assignment to `cadence`, but still returns it. Reproduced: seeds **1, 2 and 3 each raise `UnboundLocalError` on their first case**. Neither advertised normalization is implemented: fields still receive unit `1`, including when settlement maps `rate` to `c0`. The 15,000-case “no disagreement” claim at `audit/stage7/laws-frozen.md:221` therefore cannot validate this committed generator.  
   **Judged outcome:** **C7.7**, exact admission differential; the evidence rule treats crashes as failures. This script is explicitly developmental, so it is not itself a judged failure, but its recorded result is not reproducible evidence for this revision.

2. **Medium — The bars-grid check can validate the wrong timestamp column.**  
   `kernel/mm/src/source.rs:214–215` matches `slot: _`. A bars declaration with `times = ["eventTime", "reportedTime"]`, period 14,400,000, phase zero and **slot `reportedTime`** is accepted; reproduced against the new parser. Certification checks the declared slot column (`kernel/SOURCES.md:106–108`), while execution constructs bars from **`eventTime`**. Consequently, aligned `reportedTime` values do not establish that execution’s event times lie on the required grid. The original grid defect remains reachable through another legal slot selection.  
   **Judged outcome:** **C7.3** coverage certification and **C7.7** execution correctness; fills and marks can still use an off-grid provider.

3. **Medium — Lean still accepts role contracts that Rust now rejects; narrowing inputs would conceal that disagreement.**  
   `reference/lean/Ref/Source.lean:129–131` checks role count and column names, but neither role/field unit consistency nor bars’ held cadence. Reproduced: `Registry.valid` returns `true` for a settlement `rate` exposed as `usd/coin`, and for an event-cadence bars provider. Rust rejects both. Missing period information explains only the numeric grid abstraction: Lean **does** model cadence and field dimensions (`Source.lean:42,49`). Moreover, `reference/lean/Main.lean:106` discards fields in the admission harness, making unit validation invisible there.  
   Generating role-valid 4h positive controls is reasonable, but excluding these refusal cases cannot establish agreement at the declaration/admission boundary. They need explicit coverage and consistent validation, not merely normalized generator inputs.  
   **Judged outcome:** **C7.7** reference agreement and the **C7.1** typed-declaration contract.

## Revision and regression assessment

The **one-role revision is legitimate in substance**. `audit/stage7/laws-frozen.md:212–227` appends rather than rewrites the freeze, and its hashes match. Exactly what changes: every registry containing a declaration with more than one role becomes invalid—even if that declaration is unused—and text-entry admission refuses it at position zero. `rolePayload` itself is unchanged. Thus “statements unchanged” is textual: `Registry.Valid`/`CheckerAccepted` hypotheses become stronger. No threshold is loosened, and remaining admitted declarations retain their guarantees. Post-review freezing and proof revalidation remain necessary.

The regression assertions discriminate against the parent: Lean’s dual-role examples change from `"true 1 0"` / `"true 0 1"` to refusal; the parent parser accepts the newly rejected period, phase, dual-role and settlement-unit mutations. Those tests do **not** cover the remaining failures above.

**fix first**
