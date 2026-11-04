<!-- GPT (openai/gpt-6.1-sol#high), fresh session consulted without the advisor's view; finished by 2026-11-03 04:19 UTC (2026-11-02 23:19 EST). Static reading of 9d70c7d. -->
# Consultation

**Findings 1 and 2 identify real mechanism-check defects, but the records show neither changed an already judged outcome. Both could affect C4.5 v3 or a later campaign.** They change selection, not the holdout return calculation; nevertheless, selection changes can increase **or decrease** actual false promotions through the finalist family and Holm correction.

**My recommendation:** retain the frozen kernel for the remaining null-only pilot, record a precise qualification before v3 starts, and require both defects corrected under the new engine’s pre-registered criteria. Do not carry this qualification into another real campaign indefinitely.

This is a static assessment: no execution, edits, or holdout access.

## 1. Are findings 1 and 2 correct?

### Finding 1: yes, for ordinary fills that flatten a position

The relevant sequence is:

1. Compute equity and attribute per-coin value changes to exposures.
2. Update `value_prev`.
3. Execute ordinary boundary fills.
4. Set `held_prev` from the resulting positions.

A closing fill therefore changes cash **after** attribution. At the next mark, its coin has no position, so `held_prev[c]` prevents attribution; `value_prev[c]` is nevertheless advanced. The closing fee and slippage are never recovered in either mechanism branch.

Evidence: `kernel/mm/src/sim.rs:365–392,394–428`; cash and per-coin accounting at `sim.rs:104–144`. `main.rs:308–316` averages only those recorded exposures, and `gate/agent/campaigns.py:104–109` trusts the resulting `pass`.

I tried three refutations:

- **“The costs appear in the next interval.”** They appear in **portfolio returns**, but the exposure guard excludes that coin.
- **“Cumulative per-coin cash eventually recovers them.”** No: the unconditional `value_prev[c] = v` consumes the difference.
- **“All closes suffer this.”** No. Liquidation and delisting closeouts happen **before** attribution (`sim.rs:335–375`), so the finding should not be generalized to every close.

Thus the finding’s core claim and reversal example stand. The example is illustrative, not evidence that a recorded strategy encountered it. On discontinuous prices, the missed boundary value change can also include a reference-price gap, not just execution costs.

This violates the specified comparison of **net return per exposure**, not the portfolio’s net-return accounting (`audit/criteria.md:372`; paper §8, `docs/whitepaper.tex:336`).

### Finding 2: yes; type-checking does not establish totality

A boolean prediction can be well-typed yet undefined:

- division by zero returns `None`;
- comparisons propagate undefined inputs;
- an `if` can select a boolean expression containing such a comparison;
- `condition()` preserves undefinedness rather than converting it to false.

Evidence: `kernel/mm/src/machine.rs:241–294,311–313`; boolean checking at `kernel/mm/src/dsl.rs:401–408`.

`sim.rs:373–376` then drops that exposure, and `main.rs:313–316` uses only `n_true + n_false` as its denominator.

Consequently, the stated example reports 50% true although true and false each cover only 0.5% of all held exposures. That fails the frozen 10% requirement (`audit/criteria.md:372`).

Two qualifications emerged from attempted refutation:

- An **entirely absent event dataset** aborts before simulation; that particular route is not silently accepted (`sim.rs:244–247`). Arithmetic and window missingness remain sufficient.
- The finding’s statement that counting undefined exposures **requires a kernel identity change is too strong**. An external calculation can recover the denominator using existing outputs, as discussed below. Native reporting would require a kernel change; correcting the gate need not.

## 2. Which outcomes could change?

### Already judged: neither defect changes the recorded judgments

The decisive fact is **where the procedure stopped**, not merely that nothing promoted.

| Evidence | Why these defects cannot change its recorded judgment |
|---|---|
| **Stage 3 real run** | Arm A had no screened candidates, no pre-mechanism finalists, and `mechanism: {}`. Arm B also had none. Both kept families were empty; no holdout was released. (`audit/stage3/real.json:65–108,109–158`) |
| **C3.2 v1** | All 20 campaigns crashed before any model call because an input was missing. Mechanism attribution cannot remove those counted crashes. (`audit/criteria.md:388–393`) |
| **C3.2 v2** | No campaign made an evaluation; the registered procedure was not established. Neither defect repairs the Write denial. (`audit/criteria.md:394–399`; `audit/stage3/null-summary-v2.json:271–323`) |
| **C3.2 v3** | All 20 had zero screened candidates; maximum DSR was about 0.897, below 0.95. The raw records show empty mechanism results. (`audit/stage3/null-summary.json:315–333`; `audit/stage3/null-v3.jsonl:1–20`) |
| **C4.5 v1** | Both completed gates screened nothing. Its failure was independently fixed by the 33/36 evaluations being below the 200 floor. (`audit/stage4/null-summary-v1.json:113–139`; `audit/criteria.md:473`) |
| **C4.5 v2** | Nine recorded gates screened nothing. The tenth has no completed gate outcome; I do not infer one. The two no-evaluation agents independently establish the recorded failure. (`audit/stage4/null-summary-v2.json:610–628`; `audit/stage4/null-v2.jsonl:10`; `audit/decisions.md:611–615`) |

This does **not** validate the mechanism implementation. Stage 3 explicitly exited under the zero-finalist revisions, with the release path unexercised (`audit/criteria.md:301–302`; `audit/stage3/exit.md:7–10`).

A repair that changes only mechanism reporting/selection cannot create an upstream screened candidate in these records. Rebuilding or changing broader simulator semantics would be a different counterfactual.

### C4.5 v3 and later campaigns: yes

There is no evidence-based guarantee that v3 will again screen nothing.

If a candidate reaches the mechanism check:

- **Finding 1 can wrongly admit or wrongly reject it**, depending on which branch bears more omitted closing costs.
- **Finding 2 can wrongly admit it** through inflated branch coverage. Correcting that denominator, while preserving the existing requirements, can only remove candidates from the mechanism-passing set.

Those changes can propagate into the actual promotion list. In v3, a promotion determines the campaign’s `promoted` class and contributes to the series’ pass/fail count (`audit/criteria.md:479–481`; `gate/agent/campaigns.py:186–204,241–259`).

### Direction: selection directly; false promotions in either direction

Neither defect alters `results.returns` or the betting calculation. `promote()` reads net holdout returns and total return, then applies Holm (`gate/gate.py:138–153,245–254`).

But **“only selection” does not mean “cannot change false discoveries.”**

For example, with positive holdout total returns:

- Candidate A has \(p=0.03\).
- An additional finalist B has \(p=1\).

A fails Holm in the two-member family but passes alone. Removing an invalid mechanism candidate can therefore **enable** another promotion—even a false one. Conversely, incorrectly admitting a candidate can itself produce a false promotion.

The repository already records this non-monotonicity (`audit/criteria.md:173–177`). It prevents calling either repair automatically false-discovery-reducing merely because it removes candidates.

What survives is the **conditional error bound**: search-only selection, however imperfect, does not by itself invalidate valid conditional holdout p-values and Holm. The guarantee still requires the actual conditional-null assumption, loss bound, predictable bets, and an untouched selection boundary—not just an unread directory (`docs/whitepaper.tex:330,342–354`). Stage 3’s historical-cost and training-channel qualifications also remain (`audit/criteria.md:343–354`).

## 3. What should the project do?

### My choice: finish the frozen null pilot, qualified; fix the replacement properly

I would record, before v3 starts:

- mechanism branch returns omit certain ordinary closing costs;
- coverage excludes undefined predictions;
- past judgments are unchanged for the upstream reasons above;
- v3 tests the frozen implementation’s code paths, **not faithful implementation or validation of the intended mechanism test**.

Then run v3 unchanged. Report its actual gate decisions and classes; do not excuse promotions, silently change its family, or repair it midway.

This is proportionate because:

1. The remaining active campaign series is **null-only infrastructure smoke testing**, not a real edge claim (`audit/criteria.md:427,479–481`).
2. No already judged mechanism decision needs rescuing.
3. Keeping one pilot kernel preserves the registered comparison.
4. A replacement is explicitly scheduled between stages 7 and 8, after which Rust and Python are deleted (`CLAUDE.md:47–49,102`; `audit/decisions.md:302`).

The qualification must not be described as a successful test of the literal net-return/coverage specification. It also must not silently rewrite frozen criteria. Record the reviewed decision under `CLAUDE.md:51–65`, preserving the original evidence.

### Alternatives weighed

#### A. Fork the kernel now

This is technically clean and fixes the defect at its authoritative source. Because v3 has not started, no v3 campaign evidence would be lost.

Its cost is a genuine version boundary, not just rebuilding a binary:

- an explicitly revised procedure and fresh null campaign identities;
- independent specification-based tests and review;
- no retrospective replacement of old judgments;
- a new, later holdout for a real arm under the fork—even though stage 3 released no results;
- explicit treatment of departure from the single-kernel pilot.

These follow from `CLAUDE.md:47–49,63–75` and v3’s unchanged-kernel/whole-gate registration (`audit/criteria.md:479`). A kernel fork need not change `harness_hash`, but that does not exempt it from those obligations (`gate/agent/harness.py:26–31`).

**I would not pay that versioning cost solely to improve a remaining null smoke test shortly before an already planned replacement.** I would pay it before another real campaign if the replacement were not ready.

#### B. Correct outside the kernel

There is a useful distinction between **missing information** and **information available through another existing output**.

**Finding 2 has a feasible external denominator correction.** Evaluate the same trading strategy on the same search inputs with an auxiliary, always-defined true prediction—for example, a comparison of finite constants. Its reported true-exposure count supplies \(N_{\text{all}}\), because every `held_prev` exposure now passes the `Some(cond)` guard. Then compute:

\[
N_{\mathrm{undefined}}=N_{\mathrm{all}}-N_T-N_F
\]

and apply both branches’ coverage requirements against \(N_{\mathrm{all}}\).

Prediction is separate from the weight and excluded from strategy identity (`kernel/DSL.md:36`; `dsl.rs:395–416`); counts are already reported (`main.rs:308–316`). The original registered prediction remains the tested claim: the constant condition is only a denominator instrument. Such a method would need tests establishing identical trading results, explicitly logged probe provenance, no agent disclosure, and correct trial/budget treatment.

However:

- this requires an **additional search evaluation**, not arithmetic on the existing mechanism summary alone;
- it fixes no closing-cost attribution;
- adopting it changes the registered **whole gate**, despite leaving both named hashes unchanged.

**Finding 1 has no general exact correction from the ordinary aggregate summary.** Total fees and slippage do not identify their missing branch allocation or the relevant equity denominators (`main.rs:156–195`). The trace adds fills and equity, but not the prediction-label stream (`main.rs:199–212`). An independent replay could reconstruct more, but that starts duplicating the interpreter and attribution machinery being replaced.

A conservatively bounded screen might be designed for a carefully restricted case. It would not be a general exact repair, and it would need its own derivation, including price gaps and bankruptcy treatment.

**I would not add this partial compensation layer to v3.** It adds another procedure to qualify and later remove, conflicts with the project’s preference against shims, and cannot be justified as automatically reducing false promotions.

#### C. Repair under the new engine’s criteria — preferred

The new engine should have explicit, independently tested obligations for:

- **Complete exposure counting:** true, false and undefined counts reconcile to total held exposures; coverage uses that total.
- **Net attribution:** fees and execution effects are accounted for under a specified causal allocation, covering entry, reduction, full close, reversal, forced close and boundary gaps.
- **Unambiguous denominators and labels:** delayed/unfilled orders, held positions, undefined conditions and terminal intervals have defined treatment.
- **Reconciliation:** attributed and explicitly unassigned components reconcile to portfolio accounting, including any bankruptcy absorption.
- **Adversarial fixtures:** both directions of cost-driven branch-order reversal, extreme undefined coverage, and exact 10%/90% boundaries.

The language change alone proves none of these. SQLite also remains in the language plan.

The planned bit-identical corpus comparison must state its output projection explicitly. Preserve unchanged trading semantics where intended; do not make bug-for-bug mechanism-report identity an accidental acceptance condition. Any changed specification belongs in a dated, reviewed revision **before** its judged evidence—not a legacy-mode switch.

### What would change my recommendation?

I would favor an earlier clean fork if:

- another real campaign must run before the replacement;
- the replacement is substantially delayed while this kernel remains operational research infrastructure;
- synthetic or search-only evidence shows these defects materially determining active finalist decisions;
- the defect is found to affect portfolio returns, the loss bound, or holdout isolation rather than attribution alone.

An affected v3 result would remain evidence about v3’s frozen procedure, not permission to rerun its campaigns after repair.

## 4. Finding 4: anything needed before the new engine?

**The SQLite defect is real, but it does not presently justify a kernel fork.**

`ledger.rs:68–77` installs only UPDATE/DELETE triggers. With recursive triggers off, replacement insertion can bypass the implicit-delete trigger. `committed_holdout()` then trusts stored returns and summary without verifying `result_hash` (`gate/gate.py:229–234`). The proposed promotion consequence follows from `promote()`.

However, the attack requires a writable database connection issuing replacement SQL:

- kernel writers use ordinary INSERT, plus non-replacing `INSERT OR IGNORE` for strategies (`ledger.rs:93–117,123–145`);
- the agent has no ledger access (`audit/criteria.md:356–364`);
- nothing in the supplied evidence establishes an actual replacement or corrupted judgment.

**Before the new engine:** record the narrower guarantee—append-only under the trusted, conforming writer paths, not protection against arbitrary writable SQLite access—and preserve that access boundary. No holdout inspection or retrospective rerun is warranted.

The replacement’s criteria should test replacement attempts with `recursive_triggers=OFF` from a separate connection, across every protected table and conflict key. A repair must preserve intentional harmless duplicate-strategy insertion; a blanket duplicate-insert abort would break the existing `INSERT OR IGNORE` path.

Enabling recursive triggers only on the kernel connection is insufficient. Hash verification can catch inconsistent accidental changes, but an unkeyed hash is not protection against a writer that can replace the content and hash together.

**I would act before the new engine if a supported writer uses replacement, an untrusted party can obtain SQL write access, or record inconsistency is demonstrated.** Otherwise, document the limitation now and fix it once, in the replacement’s ledger design.
