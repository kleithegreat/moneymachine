**Do not launch `agent-real` yet.** The blocker is justified, but its proposed remedy **(b) contradicts the frozen failure rule**, and **(c) promises more recovery than the ledger can provide**. Stage7 needs a dated definition revision—not a weaker law—and totalizing `mentions` alone leaves another proof-interface gap.

References below use main snapshot **`65902b2`** and stage7 snapshot **`0c38ec2`**. I made no changes, started no workloads, and accessed neither withheld category.

## Review 1

### Findings, ranked by consequence

#### 1. A second copy can authorize another release — **(d) is real; copying the claim afterward is insufficient**

`claim_holdout` locks and checks only the `spent.jsonl` inside its supplied store (`kernel/mm/src/main.rs:272–289`). Two copied stores have independent claims. `CLUSTER.md:94–99` explicitly acknowledges this.

Appending the cluster claim locally afterward is useful reconciliation, but leaves a window in which the cluster has claimed the holdout and the local copy still authorizes it—including indefinitely if the runner dies before reconciliation.

**Required:** one authoritative release location, with other copies prohibited from authorizing overlapping evaluation **before** release; reconcile the actual claim afterward. This does not require a distributed service, but it does require an enforceable operating rule, not merely eventual copying.

#### 2. A claimed batch can leave no results or only a prefix — **(c) is real, but its proposed recovery is incomplete**

The kernel claims before entering the evaluation loop:

- Claim: `kernel/mm/src/main.rs:433–435`.
- Per-program evaluation and emission: `main.rs:470–505`.
- Each result commits separately: `kernel/mm/src/ledger.rs:82–119`.

A kill immediately after the claim leaves zero results. A later kill, evaluator abort, or ledger failure can leave only some finalists evaluated. Moreover, `gate.holdout_run` raises on **any** nonzero kernel exit before reading committed results (`gate/gate.py:206–216`).

Therefore:

- **Complete committed batch, missing report:** recoverable without another evaluation.
- **Incomplete batch:** committed results are recoverable, but the complete registered result is not.
- Missing finalists must not be dropped, or Holm recomputed over the surviving subset.

The existing no-rerun protection is **fine**. A reporting/reconstruction command should bypass neither it nor the spent claim. Incomplete execution remains a spent, incomplete campaign—not a license to finish it later under the current rules.

The claim-before-evaluation design itself is also **fine**: moving the claim after evaluation would weaken the one-use protection. It conservatively sacrifices availability.

#### 3. The deployed report destination is unwritable — **(a) is real and deterministic**

`real()` writes `audit/stage3/real.json` only after holdout evaluation and promotion calculations (`gate/agent/campaigns.py:238–248`).

The pod has a read-only root; only its explicit volumes and scratch directories are writable (`ops/live.py:66–90`). `audit/` is not a writable mount.

**Fix:** write the recoverable report under the campaign’s persistent `work` directory, then copy it into the audit record externally. This is ordinary output plumbing, not a criteria change.

Original orchestration: `f8344f1`; incompatible deployment introduced by the live-pod layout and exposed by `65902b2`.

#### 4. Even a successful execution violates the frozen diagnostic-release order

C3.4 requires diagnostics to be recorded **after promotion decisions are committed** (`audit/criteria.md:394–396`); the retained release rule says the same (`:320,337`).

Actual order:

1. Kernel computes diagnostics (`kernel/mm/src/main.rs:360–362`).
2. Kernel commits them with the primary result (`:385–387`).
3. Python computes promotions afterward (`gate/agent/campaigns.py:239–240`).
4. No promotion-decision ledger commit occurs.

`with_diagnostics()` attaching fields after calling `promote()` does not repair the earlier recording and disclosure.

This originates in `45cfc5a`. The diagnostics do not feed the current promotion calculation, which is good, but **non-use is weaker than the frozen ordering requirement**. Diagnostic work also occurs before the primary result’s commit, creating another opportunity to lose that result.

#### 5. The audit can fail after release for ordinary permitted behavior

Two concrete paths are missing from the blocker file:

- **No daemon calls:** `daemon.log` is created only when a call is logged (`gate/agent/daemon.py:51–54`). A dead session making no calls can therefore reach the post-release `open("daemon.log")` and raise (`gate/agent/campaigns.py:54,241`).
- **A rejected free check:** the audit counts daemon `eval` calls, but its ledger query includes every `reject` disclosure for A (`campaigns.py:55–59`). A failed `mm check` also records kind `reject` (`kernel/mm/src/main.rs:231–233`). Thus a normal failed type-check can produce a false mismatch.

The audit logic dates to `f8344f1`. It is insufficient even as a one-to-one check: matching totals do not establish correspondence.

**Fix the accounting, then audit before claiming.** A genuinely missing/unreconcilable record blocks release; a verifiably empty call history must be representable as empty, rather than crashing.

#### 6. Required holdout mechanism evidence is absent

The criteria require each finalist’s mechanism difference on the holdout (`audit/criteria.md:365`).

`holdout_run` supplies no `--mechanism` option (`gate/gate.py:205–207`), and the kernel computes that report only when requested (`kernel/mm/src/main.rs:343–345`).

Simply adding the option is insufficient: `reported()` slices returns and trace but preserves **all** exposures (`main.rs:107–120`); exposures themselves have no timestamp (`kernel/mm/src/sim.rs:371–375`). The resulting mechanism statistic would cover the full replay, not just the reported holdout.

Without additional recorded evidence, a report-only recovery cannot supply this missing statistic.

#### 7. Account identity is missing — **(e) is real, but lower consequence**

`wait_for_room()` returns the selected account and its windows; `real()` discards that return (`gate/agent/campaigns.py:155–175,223`). Unlike the null-series path (`:211–212`), its report records neither.

Record the account **name**, never the token, and preserve the pacing receipt before launching A. This repairs provenance; it does not determine whether the statistical result is valid.

### What a dead or partial arm A means

**It is a terminal arm outcome, not a void attempt and not automatically a release blocker.**

The decisive rule is explicit:

> “A crash, timeout or early stop ends the arm with whatever it evaluated. A rerun would need a new, later holdout.”  
> `audit/criteria.md:363`

Read C3.3’s “both arms complete once” (`:380`) together with that rule. “Complete” cannot silently become “successful CLI exit and positive evaluation count.”

Consequently, blocker **(b)’s premise is wrong**:

- A timeout after several evaluations proceeds with those evaluations.
- An authentication failure producing zero evaluations can leave A with an empty candidate family.
- Clean exit is not necessary: the frozen turn/wall limits can intentionally kill the CLI (`sandbox/session.py:128–148`).
- A budget is a ceiling, not a minimum-use requirement.
- Zero finalists or zero promotions is an acceptable outcome.

**What blocks release is inability to establish the registered procedure:** missing transcript/disclosure evidence, genuine isolation/audit failure, unfinished selection processing, or unmet prerequisites. An unreconstructible runner failure may cause such a block; the model’s nonzero exit alone does not.

Do not import stage 2’s infrastructure-rerun exception into stage 3: it revises stage 2’s Runs rule, not stage 3’s explicit one-attempt rule.

### Simplest correct design

Keep the statistical procedure unchanged and separate three operations:

1. **Prepare once.** Check prerequisites, both pins, input identities and writable destinations before starting A. Currently the G100 pin is checked only after A has finished (`campaigns.py:231–232`), so a detectable mismatch can waste A’s sole attempt. Recheck the harness after any long pacing wait.
2. **Finish and freeze both arms.** Preserve A’s actual terminal status and evidence, including partial/empty outcomes; perform the corrected audit before release. Persist both arm families and all report inputs.
3. **Release once; report from committed evidence.** Validate batch completeness by finalist identity, not stdout position alone. Persist promotion decisions. A separate reporting operation reconstructs an already-complete batch without calling the evaluator. Incomplete batches remain explicitly incomplete and spent.

Also settle the diagnostic ordering and missing mechanism evidence before release. Those are not solved by moving the report file.

If both finalist families are empty, the current `holdout_run` returns without accessing the holdout (`gate/gate.py:201–202`). **That is fine:** report the empty outcome honestly; do not burn the holdout merely to make an empty query.

### Which changes require revision or the human?

- **No criteria revision needed:** writable report destination; deterministic report recovery; account recording; earlier preflight checks; correcting audit accounting to implement C3.1.
- **Dated criteria revision needed:** requiring clean exit/minimum evaluations, declaring partial A void, allowing replacement A sessions, or authorizing completion/re-evaluation of a partial holdout batch. Those change the procedure.
- **Human involvement:** changes affecting false-discovery/leakage outcomes, and any exception to the frozen pilot-kernel identity. Correcting diagnostic/mechanism handling in Rust would change that kernel; do not silently replace the seeded binary.
- **No failure has yet triggered the special post-failure restriction.** A prospective code review finding is not a failed judged campaign. The rule reserving repair of a failure-exposed procedure defect to the human does not prohibit ordinary pre-run implementation repairs. But it also does not authorize silently rewriting the frozen procedure.

**None of the plumbing fixes inherently changes `harness_hash()`.** Its inputs are enumerated in `gate/agent/harness.py:26–31` and `sandbox/session.py:173–179`; `campaigns.py`, `gate.py`, `ops/live.py`, and Rust are outside that hash. Editing the hashed harness/daemon/sandbox would fork it. An unchanged harness hash does **not** establish an unchanged procedure or kernel.

## Review 2: stage7 `L5_text`

### The recorded blocker is real; stopping was correct

`L5_text` connects textual references to the required-source closure (`stage7:reference/lean/Ref/Laws.lean:239–243`).

Its antecedent depends on `Json.Value.mentions`, declared `partial def` (`Ref/Spec.lean:215–229`, introduced in `2790140`). The compiler does not use that function. Without equations or characterization lemmas, the logical interface supplies no connection between its Boolean answer and compiled input nodes.

Commit **`9bfa1c0`** correctly records a proof-interface blocker, not a runtime counterexample. Leaving the law unproved is honest; a successful build containing its `sorry` is not evidence that it holds.

### Recommended action: a total definition **and** a dated revision

Replace the traversal with a terminating, proof-visible definition, preserving its intended occurrence semantics. Then prove:

1. A referenced input in accepted syntax survives compilation as an input node.
2. Its source belongs to `Program.sources`.
3. Required-source closure contains that source.

The frozen-definition rule explicitly requires a dated revision even if the displayed theorem type stays unchanged (`stage7:audit/stage7/laws-frozen.md:3–4`, freeze commit `ba24406`). Independently review and freeze the revised definitions before judging dependent proofs, as C7.7 requires (`audit/criteria.md:962–965`).

### Further blocker: totalizing `mentions` alone is not enough

The blocker document says sharing the partial parser result lets the proof avoid parser internals. **That is only partly true.**

- `InputRef` searches **all** matching object members (`Ref/Spec.lean:225–227`).
- The compiler retrieves the **first** matching member (`Ref/Syntax.lean:164,303–318`).
- `fields` checks allowed and required names, but not uniqueness (`:155–162`).
- Duplicate-key rejection is inside the opaque partial parser (`Ref/Json.lean:145–165`).

Consider an abstract JSON object containing two `weight` members: first a dimensionless constant, second an input reference. Compilation uses the constant; the occurrence traversal sees the input.

The executable parser rejects such text, so this is **not a demonstrated runtime exploit**. It is another missing logical invariant: sharing an opaque parse result does not prove that result has unique keys.

The revised proof boundary must therefore also expose duplicate-freedom—for example through a proved parser property or a total validation layer whose successful result both definitions consume. Do not assume that property merely because the executable parser implements it.

### Could a different definition weaken the guarantee?

**Yes.**

Defining “reference” as “an input already present in the compiled program” makes the law easier but removes its protection against a compiler dropping a textual dependency. Counting only reachable or active expressions similarly loses the explicit guarantees for:

- unused lets;
- inactive branches;
- prediction conditions.

A grammar-directed syntactic occurrence predicate can be a good design, provided it retains those cases and its correspondence to accepted program text is established. A same-traversal total definition should preserve the intended runtime guarantee, but that preservation must be examined—not inferred from an unchanged theorem name.

**Bottom line:** retain the blocker, revise the proof-visible definitions with a dated record, close the parser-invariant gap, and prove the original strength. No axiom, compiler-defined antecedent, or silent weakening should count as proving frozen `L5_text`.
