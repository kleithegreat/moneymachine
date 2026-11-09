# Meta-review: research intent versus execution

**Reviewer:** GPT-6.1 Sol  
**Written:** 2026-11-08 20:56:45 UTC (2026-11-08 15:56:45 EST; EST = UTC−5)

**Verdict:** The project has preserved much of the human's demand for honest research, but badly distorted its priority order. It is becoming an assurance system with a research project attached. There is substantial engineering evidence and very little evidence that the intended research loop works. This is not evidence that retail edges do not exist, or that agents cannot find them. It is evidence that this implementation has not yet answered those questions, despite considerable activity.

**Scope and evidence.** I read all 112 messages of `origin-chat.json` before reviewing execution. That export is one physical line; references below identify the original message number and speaker. I examined the paper, criteria, decisions, process, stage evidence, substantive reviews, git history and relevant branch work. The base is detached checkout `bbb2d9849ad21ebdebb5a9108aab6f06e9eb79ca`, not a moving `main`. Branch citations use `stage7@794860da` for `794860da3eb29b401308b116217af41d81d0c86f` and `refreeze@b29eb065` for `b29eb065a3760a77f352d5a4a93dda571073f5e5`. Later changes are outside this judgment.

I used `ctx` for retrieval and checked raw leaves 87, 305, 512 and 521 against the corresponding records; its summaries are not independent evidence. I did not inspect protected prices or returns, run campaigns or tests, deploy anything, or change project files other than this review. This is a project-level review, not a fresh verification of every implementation or archived experimental result.

## 1. What the human actually wanted

The original objective was not “prove a trading engine correct.” It was to exploit frontier agents' search and synthesis capabilities for retail research: propose and rapidly test strategies, ingest and triage catalysts, discover useful connections between disparate sources, and use formalism to make that search safer and less redundant. Statistics remained the empirical standard. Formalism was a means, not the finding (`origin-chat.json:1`, human message 1).

The human then made several priorities explicit:

- **Low coordination overhead and subscription-compatible autonomy.** Start one capable agent, let it call subagents and GPT as needed, use Nix, and minimize manual intervention. “Dead simple” documentation was part of that requirement, not a cosmetic preference (human messages 17, 19 and 21).
- **Not crypto-only technical mining.** Hyperliquid was a convenient venue, not the research thesis. Multi-asset markets, discretionary event-driven macro, weeks-long theses and agent-defined sources were human requests. So was the Lean/Bend comparison (human messages 35 and 39).
- **Free-first extensibility.** Broaden accessible data, including on-chain opportunities, without turning permission requests into the human's job (human messages 81, 95 and 111).
- **A coherent, minimal intent document.** The paper should be the sole source of truth for intent; scattered prose and a roughly 1,400-line status file were explicitly criticized (human message 103).
- **Rapid testing and iteration.** When the proposed holdout moved the real run to February, the human objected: “the whole point of this project is rapid testing and iteration” (human message 107).

These were not demands for careless backtests. The human also accepted honest negative outcomes and independent checks, and wanted unattended work rather than constant permission-seeking (human messages 39 and 75). But a negative result must be informative. A procedure that almost never detects plausible alternatives cannot turn repeated non-promotions into a useful answer.

Attribution matters. The fixed stage ladder, statistical stack and much implementation detail came through assistant proposals, not fully specified human requirements in message 1. Conversely, multi-asset scope, the thesis track's direction, proof-language comparison and subsequent Lean/OCaml replacement were not rogue agent scope creep. The later migration was explicitly human-directed on 2026-10-26 (`audit/decisions.md:300–303`). The cluster move, additional reviewing model and byte-identical-before-corrected port order also have explicit human authorization (`audit/decisions.md:272–281,697–701`; `stage7@794860da:audit/decisions.md:757–760`).

**The failure is therefore not simply disobedience. It is a jointly reinforced priority failure:** attractive local demands for rigor, extensibility and elegance kept winning over the global requirement to obtain an informative research result cheaply. Agents should have exposed that trade-off much earlier instead of presenting the growing prerequisite chain as the natural route to the original goal.

## 2. Where execution drifted, and what the results actually establish

### The feasibility gate did not govern investment

By human message 27, stages 0–5 were already built and tested while stage 0 was still unjudged. That message pasted a progress report; it was not an instruction to keep building ahead. The original conversation itself surfaced the ordering problem. Stage 6 was adopted on 2026-10-23, before stage 0's qualified exit on 2026-10-26 (`audit/decisions.md:5–10,118–127`).

Parallel work during recording waits was sensible. Building multiple downstream mechanisms before knowing whether the evidence and confirmation geometry were usable was not. It converted feasibility failures into expensive amendment, waiver and compatibility decisions because there was already a system waiting behind them.

The record does not conceal those failures. Stage 0's cost coverage failed and was carried as a qualification, not called a pass. That honesty is valuable. It does not recover the opportunity cost of building beyond an unresolved feasibility question.

### Sensitivity became a qualification instead of a design constraint

The statistical evolution is the clearest substantive drift. Rare-loss failures exposed a real weakness in bootstrap mean testing; replacing it with an explicitly scoped betting construction was not gratuitous mathematical decoration (`audit/criteria.md:240–251`). But the research task then became subordinate to preserving that construction.

Power failed as originally specified, was amended toward a much longer and stronger planted-edge scenario, failed again after the screen revision, and was finally waived by the human on 2026-10-28 (`audit/criteria.md:274–288`; `audit/decisions.md:259–263`). Round r2 contained 2,700 complete-null campaigns and 700 mixed campaigns. The ordinary Sharpe cells promoted nothing. Even the long, strong diagnostic achieved only 5/100 recovery against a 30% target (`audit/stage2/exit-r2.md:13–23,33–40`; campaign counts follow the cells in `audit/criteria.md:267–285`).

A waiver can authorize a machinery study. It cannot make the machinery useful for ordinary-edge discovery. The correct conclusion was: **the chosen confirmation design does not support the intended near-term research question.** The project instead retained that problem while continuing down the stage ladder.

There is an additional validity boundary. Absorbing losses at a reported −1 does not establish the conditional-mean premise. The current paper correctly requires a pre-absorption −2 bound that the frozen pilot and real markets do not establish (`docs/whitepaper.tex:325–333,577–588`; `audit/decisions.md:688–707`). Neither “all valid tests must be this powerless” nor “the reported floor proves validity” is defensible. The current paper explicitly corrects those overclaims (`docs/whitepaper.tex:597–600`). That correction is progress in understanding, not evidence that the pilot now answers its motivating question.

### The speed correction changed the question, not just the date

The February delay and reversal show the conflict directly. The later holdout protected against model-cutoff uncertainty and cost-table chronology, but imposed months of waiting. The human insisted on speed, and the revised historical run was explicitly labeled pipeline validation with near-zero power. An initial statement that no after-holdout information reached selection was then corrected: October-fitted costs were used for an earlier historical window (`audit/criteria.md:304–346`). Raw `ctx zoom 87` corroborates the human's rapid-iteration objection and the assistant's overconfident initial advice; the dated criteria, not that advice, govern the actual qualification.

The later choice was not an undisclosed abandonment of rigor. It was an approved change from edge testing to machinery testing. The drift is that the project continued to treat advancement through that machinery as advancement toward answering the original research question.

### The completed pilot did not exercise its decisive path

Stage 3's actual result was arm A making 9 evaluations and arm B making 100, with **zero finalists in both arms**. There was no candidate prediction, mechanism result or holdout batch. The release path was not exercised and the holdout remained unreleased. Its exit says this establishes neither edge, absence of edge nor generator superiority (`audit/stage3/exit.md:5–12`).

Stage 4 adds useful swarm-path evidence, not a rescue of that research result. Its final version ran ten campaigns, with zero promotions and one unresolved campaign. No finalist reached the holdout or betting path. Across versions, 22 campaigns started, 21 have known non-promotions and one crashed outcome is unknown; the final exit corrects the earlier pooled summary (`audit/stage4/exit.md:17–23`; `audit/decisions.md:738–745`).

This is not an accusation that the exits are falsely recorded. Their qualifications are unusually explicit. It is an accusation against the **project's progress metric**: stages can exit while the central research loop remains untested or insensitive. “Stages 0–6 exited” is administratively true and scientifically easy to overread (`PROGRESS.md:46–48`).

### The closest match to the intent remains operationally unstable

Forward thesis research is much closer to the requested slow-information, agent-in-the-loop work than exhaustive technical-expression search. Yet the thesis manifest has seven committed versions between 2026-10-26 and 2026-11-03: the initial version plus six replacements. This is reproducible with `git log bbb2d984 -- audit/stage10/manifest.json` (initial `464431a`, latest `29a25cb`). A further five-round repair bundle is not adopted at the reviewed snapshot.

Those rounds are not empty ritual. Round four found readiness lapsing at midnight, acquisition serialized behind sessions, and duplicate Monday snapshot acquisition. It also showed that an extreme scheduling envelope purchased roughly 19-hour-old information without protecting the very sessions it purported to protect (`audit/reviews/2026-11-08-opus-thesis-refreeze-round4.md:11–37,63–117`). These are real operational and experimental-design defects.

But they also show how far the experiment has been pulled into acquisition, account simulation and scheduling machinery. The next draft remains explicitly **not adopted**, and the round-five build record reports one suite failure followed by a capability skip and local pass—not a newly independently certified clean deployment (`refreeze@b29eb065:audit/stage10/criteria-revision-draft.md:3–25`; `refreeze@b29eb065:audit/reviews/2026-11-08-sonnet-refreeze-round5-build.md:29–31`). Raw `ctx zoom 521` was checked against that build record. Do not promote the status shorthand “suite green” into stronger evidence than this (`PROGRESS.md:28`).

## 3. Over-engineering, under-building and project-level slop

### Keep the assurance that protects actual evidence

The sandbox, causal availability, irreversible holdout accounting and durable recordings are not dispensable bureaucracy. Reviews found a writable client permitting code execution with network/environment exposure; holdout reporting that included search-period P&L; and missing funding treated as zero (`audit/decisions.md:34–85`). Later hunts identified delisting lookahead, unbudgeted held exposure and sizing from pre-fill equity (`audit/reviews/2026-11-03-gpt-hunt-kernel.md:16–52,87–143`). Recorder review found permanent torn-write failures, possible loss of the only surviving mirror bytes, incomplete successful backups and a request budget that could not meet its boundary deadline (`audit/reviews/2026-11-02-gpt-hunt-recorders.md:7–45,87–95`).

These findings justify independent, adversarial checking at consequential boundaries. They refute any recommendation to “just trust the agent and trade.” They do not justify every layer subsequently built around them.

### The generic certification system is ahead of demonstrated demand

Stage 7 is developing a declaration language, availability-rule language, certificates, transitive binding, resolver semantics, conformance corpora and several implementations. That can be justified for a reusable research platform. It is premature as a prerequisite to learning whether one or two useful external sources improve agent research.

B3 is the clearest symptom: rounds 3–11 repeatedly revised the contract and its measurement. The design oscillated from byte-read instrumentation to non-interference and back to a semantic decode restriction (`stage7@794860da:audit/decisions.md:712–748`). Round eight's reviewer actually reproduced disclosure channels, so “stop reviewing leaks” is the wrong lesson (`stage7@794860da:audit/stage7/b3-round8-review-gpt.md:7–68`, reviewing `f130354`). The final suite at `307c1de` still did not constitute a pass of the production loader criterion (`stage7@794860da:audit/decisions.md:775–804`).

The criticism is architectural: **too broad a general contract created too large a proof-and-review surface before a research use case earned it.** Even after this investment, stage 7 supports numeric coin-keyed fields only; enums, non-coin entities and many-to-many relationships remain excluded (`audit/criteria.md:980–985`). Those omissions are especially relevant to cross-domain macro research. More generic machinery is not automatically more useful extensibility.

### Frozen identities couple unrelated maintenance to experimental restarts

The rule that changed experiments require new evidence is right (`CLAUDE.md:48–50`). The dependency boundary is too coarse. Shared ingestion imports can make a recorder repair fork the thesis experiment (`audit/reviews/2026-11-02-gpt-hunt-recorders.md:5–25`). The record explicitly postpones an incomplete managed-return summary and a torn-UTF-8 recorder fix to avoid another window restart (`audit/decisions.md:668,686,690`).

The answer is not to edit a frozen identity secretly. It is to design the next protocol around explicit, narrow experimental components and immutable input artifacts, so recorder maintenance need not automatically invalidate unchanged forecasting claims. Historical versions and their limitations must remain intact.

### Formal reference work delivered something; full migration has not earned priority

The Lean reference is a real result: abstract laws and 3,372 bit-exact differential runs. It also has explicit boundaries: no binary64 theorem, a shared Rust loader outside the proof, and two earlier agreeing corpora that did not meet the criterion (`audit/stage6/report.md:17–45,70–85`). This is strong evidence for specified behavior, not a proof that the specification models trading correctly.

The human-requested Lean/Bend comparison was legitimate. Turning it into a full Lean engine plus OCaml plumbing is a much larger proposition. The fast Lean diagnostic was unproved, even though it matched the corpus and ran at roughly 33 ms versus Rust's 16 ms (`audit/decisions.md:300–303`). The current ordering additionally requires porting known-bug behavior byte-identically before correcting nine defects (`audit/decisions.md:697–707`). That ordering protects an approved frozen comparison; it is also costly evidence that historical compatibility has become a product in its own right.

Keep the reference and counterexamples. Defer the wholesale migration unless a near-term study requires a property the existing stack cannot provide economically. Language elegance is not presently the binding research constraint.

### Broad exclusion rules suppress the stated opportunity set

Stage 8's fifteen-year per-series and 750-consecutive-fix rules do not follow from a study-specific power calculation. They can admit fewer independent observations than they reject and can exclude an auxiliary feature merely for being new (`audit/stage8/scope-manifest.md:25,89,125,226–234`; checked counterexamples in `audit/reviews/2026-11-06-gpt-assumption-sweep.md:83–102`). No class is admitted (`PROGRESS.md:37`). Meanwhile, the on-chain ideas the human asked to prioritize mostly have two-to-seven-year histories and require separate scope revisions (`docs/future-work.md:19–30`).

Likewise, a universal 10–90% mechanism split is a poor fit to genuinely rare catalysts; thesis activity quotas do not establish forecasting skill or comprehensive operational coverage (`audit/reviews/2026-11-06-gpt-assumption-sweep.md:144–183`). Some thresholds must be policy choices. Calling for a derivation of every constant does not turn every policy into a theorem.

Under-building is therefore selective, not an absence of code: actual catalyst/source discovery, useful planted-edge recovery, research-facing DSL evaluation and informative baseline comparisons lag behind the platform. The earlier-cutoff-model arm remains “status unclear”; alternative-model research harnesses are parked (`PROGRESS.md:42`; `docs/future-work.md:9,12`). Cross-campaign memory is an explicitly deferred research question, not an accidental omission (`PROGRESS.md:44`; `docs/future-work.md:11`).

### Documentation has been compressed physically, not cognitively

The single-authority scheme is sensible (`CLAUDE.md:35–46`). Nevertheless, the base has 321 tracked audit files, including 92 files under `audit/reviews/`. Criteria are 233,984 bytes over 1,400 lines; decisions 159,981 bytes over 764; the paper 142,313 bytes over 756. Even the 79-line status file is 12,220 bytes, and the 116-line process file is 17,138 bytes. Counts are from the fixed git tree, before adding this review.

Short line counts conceal dense bundles of rules, caveats and pending actions. The human requested less coordination burden, not merely fewer newline characters. Append-only historical evidence must stay; the simplification target is the active decision surface.

There is also semantic slop. `docs/future-work.md:3` says later work waits until the pilot “answers whether the search controls false discoveries.” The pilot's actual exits establish conditional smoke evidence, not that broad answer. Independent implementations agreeing on a common mistaken rule—missing funding is the concrete example—do not settle correctness. Tests passing, reviews closing and stages exiting must not be used as interchangeable units of research value.

## 4. Economy of effort

I cannot reconstruct reliable total token spend, subscription consumption by workstream, human hours or monetary opportunity cost. Commit counts are not hours; elapsed proof time is not active labor. Any precise total would be fabricated.

What can be established:

- **Large iteration footprint:** 865 non-merge commits at the base; 153 additional non-merge commits reachable on the inspected stage-7 branch and 55 on the inspected refreeze branch but not the base. These branch counts can overlap and must not be added into a labor estimate (`git rev-list --count --no-merges` on the stated revisions).
- **Repeated evidence production:** stage 3 used three 20-attempt null cohorts, with its first failing before useful model evaluation; stage 4 started 2, then 10, then 10 campaigns across versions (`audit/stage3/exit.md:5–10`; `audit/decisions.md:742`). Stage 2 repeated substantial sweeps while retaining the underlying sensitivity problem.
- **Real quota contention:** the thesis's first day used about a tenth of its weekly account allowance; GPT had about 3% of its week left; work was shifted or delayed (`audit/decisions.md:651–658`). At the base, GPT and Argon allowances again constrained work (`PROGRESS.md:17`). Subscription compatibility has been achieved; economical allocation has not been demonstrated.
- **Weak effort instrumentation:** stage 6's recovered active-time proxy sums to 12.84 hours, but includes other work and excludes long tool runs. One milestone spans 41.16 elapsed hours with 1.63 proxy-active hours. Neither figure supports a clean estimate of proof cost (`audit/stage6/report.md:112–150`).

Some optimization decisions were excellent. Sharing test builds and retaining simple worksteal cut a reported 581-second baseline to approximately 228 seconds without dropping original coverage (`audit/2026-11-04-suite-speed.md:7–12,28–48`). The cluster test runner was rejected after a verified 298.75-second run lost to the existing 221-second SSH runner (`audit/decisions.md:754–756`). Those are measured keep/kill decisions. More infrastructure work should face that standard before, not only after, implementation.

The biggest avoidable cost is not the runtime of any one suite. It is the loop **broad promise → elaborate frozen criterion → implementation → review exposes spec defect → new mechanism or revision → rerun → further review**. Its output is often improved assurance, but its claim to priority is rarely priced against a simpler informative study.

The process amplifies this. Mandatory half-budget erasure, net-positive-diff justifications, full testing before every commit and elaborate reviewer-role routing all consume the same scarce plans as research (`CLAUDE.md:15–23,54,70,84–98`; `ops/commitcheck.py:17–27`). They were often human-requested responses to real failures. They are still not costless. A deletion quota is no more a research objective than a line-count growth target.

On balance, independent reviews have earned their place; **unbounded prerequisite growth has not**. The project needs a stopping rule for assurance investment tied to a concrete claim and experiment, not another universal process layered onto the existing ones.

## 5. Ranked recommendations

These are prospective changes, not authorization to amend frozen rules, pool versions, rerun spent evidence or inspect protected windows. Cost labels are reviewer estimates: **small** means a bounded change or decision; **medium** means several coordinated changes; **large** means architectural work. They are not measured schedules.

### 1. Finish one bounded forward thesis experiment; stop expanding its prerequisites

**Expected value: highest. Cost: medium.** Complete the current claim-bearing acquisition, readiness, durability and scoring repairs, independently check them, and adopt a new identity only through the existing prospective procedure. The branch's open request-budget and capability issues are not waived by this recommendation. Then hold scope stable long enough to obtain a report comparing main, no-reading and a simple baseline, with missed sessions and uncertainty explicit. An operational exit is not evidence of forecasting skill; inconclusive is an acceptable scientific result.

Stop adding assets, account features and generalized infrastructure to this experiment unless they are necessary to make its registered comparison interpretable. Do not force another restart for unrelated elegance work. The objective is the first defensible information gain about the user's central thesis, not a flawless miniature fund.

### 2. Make sensitivity and decisive-path coverage prerequisites to more calibration

**Expected value: very high. Cost: medium.** Before another large null sweep, run a small, fresh synthetic positive-control matrix: an oracle candidate, a simple baseline searcher and the agent, all under realistic costs and the intended observation budget. Identify separately failure to express, discover, select and confirm the planted edge. Force a synthetic finalist through freeze, release, holdout accounting and reporting; stage 3's empty release is not that test.

If plausible effects cannot be recovered, redesign the future study or explicitly narrow it to implementation testing. Do not buy more precision around zero false discoveries from a system that rejects almost everything.

### 3. Simplify the next selection protocol; retain one justified confirmation boundary

**Expected value: high. Cost: medium.** The paper already says DSR, SPA and StepM are selection, not three independent guarantees (`docs/whitepaper.tex:313–333`). Compare that stack with a simpler, predeclared candidate-ranking rule at fixed evaluation and finalist budgets, using fresh development evidence. Keep causal access controls, frozen finalists, a confirmation test whose premises are actually supported, and the required multiplicity correction. Stop preserving every search screen merely because it is already implemented.

Separately assess a better-powered betting design and its true loss-bound requirements; do not recycle the reported-floor argument or automatically scale the bet by a proposed smaller absorption floor.

### 4. Park wholesale language migration and broad stage-7 generalization

**Expected value per avoided effort: high. Cost: small to park; large if continued.** Preserve the Lean reference, differential harness, current branches and reproduced defects. Make the next source extension a vertical slice for an actual study, retaining availability, revision, authorization and lineage guarantees. Expand the language or entity model when that slice demonstrates the need. Avoid turning completion of a universal certification engine or Rust→Lean/Python→OCaml replacement into the admission price for all further research.

Because the human approved these plans, this requires an explicit priority decision, not silent agent noncompliance.

### 5. Replace broad future scope gates with study-specific evidence requirements

**Expected value: high. Cost: small–medium.** For new, unjudged protocols, specify the economic mechanism, usable independent events, relevant missingness, costs, dependence and detectable effect. Replace universal fifteen-year, consecutive-fixing and balanced-mechanism screens where they do not serve that claim. Start with one legally usable catalyst or on-chain family that fits available machinery, not another omnibus market inventory.

This does not relax source terms, erase exposure history or permit post-result selection. It makes the rule match the question rather than excluding the human's preferred questions by construction.

### 6. Decouple future forecast evidence from optional portfolio and recorder machinery

**Expected value: high over time. Cost: medium–large.** In the next protocol design, distinguish immutable information snapshots, registered forecasts, forecast scoring, execution simulation and account management. Define which dependencies can change each claim. Where appropriate, a narrowly specified forecast/Brier experiment should not require every portfolio-accounting feature to be complete first.

Do not retrofit that separation to salvage existing frozen days. Use it to prevent the next recorder fix or managed-return display fix from unnecessarily restarting an unchanged forecasting experiment.

### 7. Right-size review, tests and active documentation

**Expected value: medium–high. Cost: small–medium.** Keep independent reviews for leakage, irreversible evidence use, return-changing semantics, recording loss and consequential criteria. Keep the adversarial regressions they earned. Stop universal multi-model escalation for reversible housekeeping; use targeted tests there, with full suites at meaningful integration boundaries under an approved process revision.

Make the integration suite's capabilities and required fixtures explicit. A security test skipped on a node without its sandbox capability is not a security pass. Prefer small synthetic fixtures for routine checks and separately named historical differentials. Keep one measured runner rather than another orchestration migration.

Keep historical audit records unchanged. Reduce active rules and status to current decisions, the next experiment, real blockers and links. Replace mandatory half-budget erasure and line-count signaling with removal of obsolete mechanisms when evidence warrants it. Do not create a new bureaucracy to administer this simplification.

### 8. Budget for information gained, and kill work that cannot name its next decision

**Expected value: medium–high. Cost: small.** Reserve subscription capacity for the chosen study before scheduling platform builds and discretionary reviews. Record lightweight per-workstream usage, retries and blocked time from existing logs; do not build a new accounting service. Every proposed mechanism should state what near-term research decision it enables and what cheaper alternative was considered. Measure its effect, then keep, defer or stop it—as happened with the test runner.

Use a price-free operational heartbeat for missed acquisition, unavailable agents, recording integrity and quota exhaustion. No protected observations need to reach research merely to tell the human that the system is stalled.

**Bottom line:** Keep the evidence discipline. Cut the prerequisite machine. The next success should be an informative, bounded study of agent research or forecasting—not another stage exit whose decisive path never ran.
