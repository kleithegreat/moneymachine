> build · gpt-6.1-sol
[0m✱ [0mGrep "rename|N1|Renaming|renam" [90min . · 60 matches[0m
[0m✱ [0mGlob "**/*{Lang,Rewrite,Program}*.lean" [90min kernel2/lean · 0 matches[0m
[0m→ [0mRead reference/lean/Ref/Spec.lean [90m[offset=120, limit=170][0m
[0m→ [0mRead reference/lean/Ref/Laws.lean [90m[offset=90, limit=75][0m
> build · gpt-6.1-sol
[0m→ [0mRead kernel/CANONICAL.md [90m[offset=1, limit=170][0m
> build · gpt-6.1-sol
**Not ready for proof.** References below are to `kernel2/lean/Engine/Laws.lean`.

### 1. N1_renaming — impossible hypotheses make the law vacuous
**Lines 703–704.** `ρ` must be injective on **every string**, while every output must satisfy A17’s bounded name grammar. There are infinitely many strings but only finitely many legal names. No such `ρ` exists; any evaluator satisfies this implication.

**Smallest change:** require injectivity and legal, non-built-in outputs only on the finite set of source names being renamed—covering both program declarations and header observations. An identity renaming on valid names must be an available instance.

### 2. L1a — a constant machine satisfies the whole statement
**Lines 722–738.** A machine that never changes state and always emits the witness’s fixed tick row satisfies both the equality and the witness. Unlike step 3’s witnesses, this witness requires neither a changed state nor an output that changes with an input.

**Smallest change:** add a second admitted run with a different known input and require its corresponding probe value to differ. Require both runs to start and finish successfully. This rules out fixed-output witnesses without asserting that every event changes a view.

### 3. L1a — the premises match B3, but the conclusion does not
**Lines 724–731.** The two filters correctly express the requested conjunction:
- equality on events with `known ≤ τ`;
- equality on events with `time ≤ τ − δ`.

They must remain separate, not become equality merely on their intersection.

But `viewRows` retains only tick time, coin, view-staleness and probes. Equality there does **not** establish equality of the actual views or every evaluation. A future-dependent input or unprobed let could differ invisibly. B3 promises equal **views, evaluations and wishes**; wishes can legitimately be absent at this step.

**Smallest change:** conclude equality of the running view and all evaluated node values at each tick through `τ`, retaining trace-row equality as a consequence. Excluding the world’s price and staleness fields is correct.

### 4. L1a — its execution domain is not stated as the law’s domain
**Lines 723, 727–729.** `initial` ranges over arbitrary `State` records, not states obtained from `start` or reachable prefixes. Structural decoding does not establish that provenance. Conversely, requiring both *complete runs* to finish successfully narrows a tick-local causality statement to executions whose futures succeed.

**Smallest change:** state the law over a common successful `start` and admitted event streams, or explicitly reachable execution prefixes. Observe the actual states at ticks rather than using successful final publication as their proxy. If only successful complete markets are intended, say that restriction explicitly rather than presenting this as B3’s unrestricted delivery statement.

### 5. L5_binding — `start` may report the wrong error
**Lines 684–686.** When binding fails, the conclusion permits **any** error code. An implementation returning `E_HEADER` instead of `E_UNKNOWN_INPUT` passes. That does not implement A17’s specified verdict.

Also, the witness exercises `bind`, not `start`; a reject-all `start` satisfies this law’s integration clauses.

**Smallest change:** require `start program header = .error "E_UNKNOWN_INPUT"` under the appropriate preceding-check premises. Extend the concrete witnesses to include a successful compatible `start` and incompatible starts returning that exact code.

### 6. L2_checker and L3_rewrite — their individual non-vacuity claims are insufficient
**L2_checker, lines 627–633:** a parser and checker that reject every text with the same code satisfy the statement. `L2_units` supplies an acceptance witness elsewhere, but the interface’s claim that each law has its own witness is false.

**Smallest change:** add acceptance of a concrete legal float program here, or explicitly freeze and assess these statements jointly.

**L3_rewrite, lines 658–667:** twelve rules and one syntactically changed program do not require any evaluated value to exist. An always-undefined evaluator satisfies the semantic equalities; changing unused metadata can satisfy the syntactic witness.

**Smallest change:** make the rewrite witness concrete: an actual R-v1 rewrite of a checked program, with a defined, input-dependent rewritten expression whose corresponding values agree. Keep the abstract `N.Lawful` qualification; do not replace it with an unsupported binary64 theorem.

### 7. L1a’s witness crosses the step-4/step-5 boundary
**Lines 619–620, 736–738.** `step4Bid` probes `bid`, which A17 types as **exact**. Requiring its evaluated probe value already demands exact-expression functionality, while the interface declares only float numeric types and says exact expressions arrive in step 5.

**Smallest change:** use a declared float observation as the step-4 probe witness, with two differing values as above. Keep the exact `bid` probe witness for step 5. I found no explicitly named later-step order function; the premature dependency is this exact-probe requirement.

The core `L2_units` erasure/type claim has no evident transition contradiction, and its finite-source witness genuinely excludes an always-undefined evaluator. Arbitrary abstract ticks are not, by themselves, a reason to reject that structural typing theorem.

**not accepted**
