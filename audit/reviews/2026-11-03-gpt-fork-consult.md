<!-- GPT (openai/gpt-6.1-sol#high), fresh session consulted on forking the kernel before C4.5 v3, without the advisor's view; finished by 2026-11-03 15:28 UTC (10:28 EST). Static reading of c1082bc. -->
# Consultation

**I recommend delaying the series, making an explicit corrective Rust fork, and running a newly registered ten-campaign cohort on that fork.** Fix the reproduced defects together rather than adding gate-side compensation or beginning the Lean replacement early.

This is a recommendation about obtaining useful evidence—not a conclusion that every return-changing defect invalidates the betting test. Most do not. The decisive considerations are that v3 has not started, delay is acceptable, several defects affect execution exercised by null markets, and the replacement is not demonstrably imminent.

*Static reading only; I ran nothing, changed nothing, and accessed no holdout data. Reproduction claims below come from the committed tests and audit record.*

## 1. Effects on null promotions and the holdout guarantee

### What the betting test actually guarantees

The tested null is about the **actual return stream supplied to the test**:

\[
E[r_t\mid\mathcal F_{t-1}]\le0,\qquad r_t\ge-1,
\]

with search information included in the filtration. Predictable betting fractions then make betting wealth a nonnegative supermartingale; Ville gives valid p-values, and Holm controls family-wise false promotions. Positive total return is an additional promotion requirement.

Evidence: paper §8, `docs/whitepaper.tex:330–354`; implementation, `gate/gate.py:138–153,245–254`.

Three distinctions matter:

- **Search-only selection errors** can change the observed promotion probability without invalidating otherwise valid conditional holdout p-values. Holm families change too: removing a finalist can enable another promotion.
- **Causal but mis-specified execution** does not automatically invalidate the theorem. It changes the process being tested. If that process still satisfies the conditional-mean null and loss bound, the guarantee survives—but it concerns the buggy simulator, not faithful venue execution.
- **Acausal execution** defeats the usual derivation that predictable holdings multiplied by fresh, zero-mean innovations have zero expected gross P&L. A loss bound alone cannot repair that. This does not prove every acausal strategy has positive expected returns; it removes the general justification for treating it as null.

N1–N3 specifically construct gross bar P&L as \(q\,o\,\epsilon\), with fresh conditionally symmetric innovations. Predictable sizing need not be *correct* sizing for that cancellation to work. Fees and adverse liquidation subtract P&L. Evidence: `gate/NULLS.md:11–40`; `gate/markets.py:179–198`.

**Bankruptcy is an important exception.** Limited liability can add positive expected absorbed shortfall. Therefore causality plus bounded returns does **not** establish the conditional-mean null for every generated campaign. Additional exposure can worsen this exception. Nor does observing no bankruptcy on one realized path prove its prospective conditional mean was nonpositive: rare absorbed losses can affect that expectation without occurring on the observed path. The records acknowledge the shortfall qualification, although “evaluations that never go bankrupt” should not be read as a survivor-conditioned theorem (`gate/NULLS.md:42–49`; `audit/criteria.md:354`).

### Defect-by-defect assessment

“Can raise” below means a credible route to a higher promotion probability, **not** a measured increase under the frozen parameters. The reproductions establish wrong behavior, not its campaign-frequency effect.

| Defect | Can it raise null promotions under N1–N3? | Consequence for the guarantee |
|---|---|---|
| **Mechanism closing costs omitted** | **Yes, through selection.** It can wrongly admit or reject candidates; either change can enable a promotion through the candidate itself or the changed Holm family. Portfolio holdout returns still include the costs. | Does not itself invalidate valid conditional holdout p-values. Reproduction: `gate/tests/test_mechanism_defects.py:62–85`; attribution: `kernel/mm/src/sim.rs:371–428`. |
| **Undefined predictions excluded from coverage denominator** | **Yes, through selection.** Sparse defined branches can wrongly pass. The fixture passes with each branch covering about 0.495% of all exposures. Complete finite market inputs do not make DSL arithmetic total. | Again, selection changes—not a direct alteration of holdout returns or betting mathematics. Removing these candidates is not automatically promotion-reducing because Holm changes. `gate/tests/test_mechanism_defects.py:88–115`; `kernel/mm/src/main.rs:308–316`. |
| **SQLite `REPLACE` bypasses append-only triggers** | **Yes, if a writer issues replacement SQL.** Fabricated positive returns and summary can produce promotion regardless of the underlying null market. This is not an agent-access exploit: supported kernel writers do not use replacement SQL. | Validity of authentic returns offers no protection against substituted inputs. The test proves the write bypass; the hunt supplies the promotion construction. `gate/tests/test_mechanism_defects.py:118–143`; `audit/reviews/2026-11-03-gpt-hunt-gate.md:69–81`; `gate/gate.py:229–254`. |
| **Future last-trade time changes current allocation** | **No in N1–N3 as generated.** They have no delistings and every bar trades. On real or delisting fixtures, future-dependent allocation can generate spurious performance. | Violates non-interference and removes the predictable-holdings justification. It is not an I8 filesystem bypass, but filesystem isolation is insufficient. `gate/NULLS.md:3–7`; `gate/markets.py:211–236`; reproduction: `gate/tests/test_kernel_defects.py:83–116`. |
| **Pending flattening order reopens after liquidation** | **Can raise or lower it.** The reproduced direction increases losses, but the unintended opposite position can subsequently profit. Liquidation is possible in N1–N3: their wicks are unbounded. | The new position is determined before the *next* bar’s innovation, so this is not demonstrated lookahead. Conditional-null validity can survive; excess exposure and absorbed shortfall remain concerns. `gate/tests/test_kernel_defects.py:119–143`; `kernel/mm/src/sim.rs:344–348,394–413`; `gate/markets.py:195–197`. |
| **Held positions reserve no gross budget** | **Can raise it.** Unintended leverage changes search results and holdout trajectories, potentially making large positive excursions more attainable. No monotone rate increase is established. | Predictable excess holdings do not themselves create positive expected uncapped gross P&L. They do undermine the advertised risk control and the argument that bankruptcy is rare. Literal I9’s emitted-vector check still passes. `gate/tests/test_kernel_defects.py:146–169`; `kernel/INVARIANTS.md:17`; `gate/NULLS.md:42–49`. |
| **Next orders use pre-fill equity** | **Can raise or lower it.** Wrong quantities change costs, exposure and eventual betting wealth. Costs make it routinely reachable, although rounding may suppress an order difference. | Still causal on these generators. No automatic theorem failure, but the tested execution differs from the stated target-weight semantics. `gate/tests/test_kernel_defects.py:172–187`; `kernel/mm/src/sim.rs:365–413,430–467`. |
| **Reporting resurrects an account bankrupt before the window** | **Not through the demonstrated promotion path.** The retained returns are all zero, giving p = 1, while reported total return is zero, failing the positive-return rule. | Serious equity/reporting inconsistency, but no demonstrated false promotion. Normal search mode does not slice away its prefix, so this example should not be generalized into a search-feedback defect. `gate/tests/test_kernel_defects.py:190–206`; `kernel/mm/src/main.rs:107–120,258–266`; `gate/gate.py:245–254`. |
| **Boundary fills omitted from holdout trace/cost summaries** | **No direct effect in the registered procedure.** Judged net returns include the costs; the diagnostic summaries do not determine promotion. | Reporting/reconciliation defect, not a change to the tested return stream. `gate/tests/test_kernel_defects.py:209–234`; `audit/criteria.md:420`; `gate/gate.py:245–260`. |

The gate hunt also reproduced **kernel-identity inconsistency**, now repaired in source. That defect could falsely establish a campaign and change the series verdict; it does not inherently create a strategy promotion. The repaired classifier preserves promotion precedence and treats identity mismatches as unresolved. Before any series, deploy this repair—the audit explicitly says it was **not deployed** when recorded.

Evidence: `audit/decisions.md:683`; `gate/agent/campaigns.py:209–234`; regressions in `gate/tests/test_agent_campaigns.py:175–195,365–403`.

## 2. What should happen before v3?

The earlier consultation reasonably distinguished selection defects from return defects. Its recommendation is not binding, and its premise has changed: six execution/reporting defects now reproduce. The recorded reversal condition is met, but that fact alone does not decide the engineering tradeoff (`audit/decisions.md:670–684`).

### The options

| Option | Evidence, time and identity costs | What the result would mean |
|---|---|---|
| **(a) Run the frozen kernel, with wider qualification** | Least immediate engineering work; preserves the single-kernel pilot and direct continuity with its existing sweeps. Does not lose evidence. But spends ten campaigns on execution already known to depart from intent. All defects must be disclosed; a qualification cannot silently turn a failed requirement into an original-specification pass. | Smoke evidence for that exact legacy implementation, including its mistakes. Not validation of the intended mechanism, portfolio controls or real execution. It would not establish the corrected engine’s behavior. |
| **(b) Corrective Rust fork now** | Requires design decisions, repairs, independent tests/review, fresh identities, deployment and targeted revalidation. Old simulator-dependent results cannot certify the fork. However, no started v3 evidence is lost, and independent mathematical/component evidence need not be discarded. Breaks single-kernel pilot continuity explicitly. | Smoke evidence for the corrected, newly frozen procedure—not retrospective vindication of the old pilot, and still not a calibrated swarm error-rate or power claim. |
| **(c) Wait for Lean** | Avoids maintaining the repaired semantics in two successive implementations. But there is no supported short completion estimate. More importantly, current ordering makes this circular: stage 7 cannot reach `main` before the pilot’s judged swarm runs finish; Lean comes after stage 7. This option needs an explicit roadmap/criteria revision, not merely waiting. | A newly registered smoke test of the replacement stack. It would not complete the unchanged-kernel v3 experiment as registered. |

Ordering evidence: `audit/criteria.md:976–977,1118–1119`; language plan, `audit/decisions.md:302`; current unfinished work, `PROGRESS.md:20–35`. The Lean benchmark establishes feasibility, not readiness or correctness.

### My choice: a complete corrective fork, then fresh cohort

I would:

1. **Hold the scheduled series.** Preserve its registration and record why it was superseded before starting.
2. **Repair the authoritative Rust implementation**, covering all nine outstanding reproduced defects above—not just those likely in N2. Specify cancellation, held-exposure budgeting, causal lifecycle handling and complete net attribution rather than layering external corrections over them.
3. **Freeze and independently check the corrected procedure**, then run ten fresh campaigns under a dated registration with unchanged numerical acceptance thresholds and the same honest promotion/unresolved accounting.
4. **Carry those corrected semantics into stage 7 and Lean**, rather than retaining a legacy execution mode.

Why pay this cost? The null smoke test is intended to exercise a procedure the project can trust and use. Several defects now affect that procedure’s common execution paths; no v3 campaign has started; the human accepts delay; and “soon replaced” is not established by the current stage-7 status. This is stronger justification than simply counting bugs or observing that they change returns.

I would not add the external denominator probe suggested in the earlier consultation. It fixes only one selection defect while introducing another evaluation/provenance procedure. Its limitations are already documented (`audit/reviews/2026-11-03-gpt-mechanism-consult.md:142–166`).

### What the fork requires

Under `CLAUDE.md:47–85`:

- Explicit new kernel identity and **fresh null campaign IDs/markets**; do not rerun old judged campaigns to replace their outcomes.
- A real arm needs a **new, later holdout**, notwithstanding stage 3’s unreleased holdout.
- Fresh Claude and GPT review, an append-only decision explaining consequences and reversal, and human review.
- Reviewed criteria/specification revisions committed before their judged evidence; no silent edits or threshold loosening.
- Independent specification-based tests, permanent reproductions, failure-path checks, and a fresh bug hunt before refreeze.

An unchanged `harness_hash` is not an exemption: it does not hash the kernel or the entire gate (`gate/agent/harness.py:26–31`).

**Do not discard all earlier evidence.** Keep the old results attached to their old identity. Re-establish affected execution-dependent prerequisites for the fork; retain independently applicable evidence such as the betting argument and unchanged component checks. Do not describe the repairs as automatically false-discovery-reducing: changed returns and Holm families make that unsupported.

Two downstream contracts also need explicit treatment:

- **C7.4 behavior preservation:** a correction cannot simultaneously reproduce a buggy baseline on affected cases. Register exact, explained exceptions or a revised baseline before judgment; retain exact agreement elsewhere (`audit/criteria.md:1022–1041`).
- **Lean bit-identity:** identify the corrected Rust target and revised semantics. A language change plus differential agreement can reproduce the same bugs; it cannot resolve this specification conflict by itself (paper §6, `docs/whitepaper.tex:269–305`; language plan, `audit/decisions.md:302`).

## 3. Before any real campaign, and consequences for existing records

### Required before another real campaign

**All outstanding reproduced defects should be repaired before starting another real campaign.** Their urgency differs:

- **Causal validity:** eliminate retrospective delisting information. Do not substitute “exclude today’s delisted assets,” which creates its own universe-selection problem.
- **Execution and risk:** resolve liquidation/order interaction, budgeting of held exposure, and post-fill sizing.
- **Selection contract:** reconcile net mechanism attribution and count undefined exposures against total coverage.
- **Audit integrity:** prevent replacement overwrites across protected tables while preserving harmless `INSERT OR IGNORE`.
- **Reporting integrity:** preserve bankruptcy through slicing and reconcile boundary-fill costs with disclosed traces.

The last two reporting defects are not demonstrated false-promotion paths. They nevertheless must not become permanent exceptions in a real campaign’s claimed accounting and audit trail. Paper §6 expressly separates accounting/implementation assurance from economic-model accuracy (`docs/whitepaper.tex:285–305`).

Also deploy identity enforcement. Separately, preserve the existing bankruptcy qualification or establish a stronger prospective conditional-null argument: fixing the advertised gross budget does not itself remove limited-liability effects.

### Existing results: distinguish recorded outcomes from repaired counterfactuals

**Stage 3 real run:** the record proves zero screened candidates and finalists in both arms, no mechanism evaluation, and no holdout release. Therefore neither mechanism defect nor either holdout-reporting defect changed an exercised decision there. There is no real promotion to retract.

Evidence: `audit/stage3/real.json:65–158`; ledger inventory, `audit/stage3/real-ledger-inventory.json:40–50`; `audit/stage3/exit.md:7–10`.

**But that does not prove its search execution was unaffected.** Return-changing defects operate upstream of screening. FTM is marked delisted in the real venue metadata (`venue/hyperliquid/rules.json:180–189`). The available records do not establish whether affected orders or allocation differences occurred. The real run remains the recorded legacy pipeline run—not evidence of what repaired execution would have selected. Its empty bankruptcy list rules out recorded bankruptcy, not all execution defects.

**Recorded agent/swarm null series:**

- C3.2 v1 failed before model calls; v2 made no evaluations. These execution defects cannot rescue those procedure failures (`audit/criteria.md:389–400`).
- C3.2 v3’s twenty campaigns screened nothing (`audit/stage3/null-summary.json:315–333`).
- C4.5 v1’s two campaigns screened nothing and independently failed their evaluation floor (`audit/stage4/null-summary-v1.json:113–139`; `audit/criteria.md:474`).
- C4.5 v2’s nine completed gates screened nothing; do not infer a completed tenth gate. Its recorded failure rests on two agents making no evaluation (`audit/stage4/null-summary-v2.json:610–628`; `audit/criteria.md:479`).

Thus the mechanism defects did not decide those completed gates. Delisting lookahead cannot affect these synthetic markets. **Execution defects could still have changed their search trajectories; empty finalist sets do not establish counterfactual invariance.**

**Stage 2 null evidence also remains legacy evidence.** Its nine complete-null cells recorded zero promotions and zero finalist-bearing campaigns, with one bankrupt evaluation in N3-G400 (`audit/stage2/exit-r2.md:3–15,33–35`). Nothing read establishes corrupted records or requires rewriting those observations. Nothing establishes identical results under repaired execution either.

There is no evidence here of an actual SQLite replacement or historical identity substitution. Record vulnerabilities and limits; do not invent an affected campaign.

## 4. What would change my recommendation?

I would favor **finishing the frozen null pilot** if a reviewed work estimate showed that repairing Rust would substantially duplicate a genuinely imminent replacement, and the project explicitly wanted evidence about the legacy procedure alone. That remains scientifically defensible under narrow claims—not because causal bugs are harmless.

I would favor **waiting for Lean** if its readiness became credible and the project explicitly revised the stage-ordering dependency, closed or superseded the legacy pilot honestly, and registered the replacement test before seeing its results.

I would make intervention more urgent if synthetic, non-holdout evidence demonstrated:

- positive conditional expected returns introduced by execution or absorption;
- acausal allocation reachable in the actual null generators;
- returns below −1 or another holdout/selection leakage path;
- supported replacement SQL, ledger inconsistencies, or identity drift;
- a real campaign planned before the replacement.

Finally, a reproduction overturned by an independent specification-based check would change its repair obligation. **Neither an anticipated zero-promotion result nor another empty finalist family would demonstrate that the defect is safe.**
