# Meta review by Claude Fable 5.2, 2026-11-09

Reviewer: Claude Fable 5.2 (`claude-fable-5-2`, effort xhigh), in an interactive Claude Code session on the Cornell account.
- It ran from a clean, detached worktree of `main` at `b3ad8e5` (`../mm-fable`), with no `data/` and no tokens.
- Its settings denied reads of `data/`, the token files and the Homelab, and denied ssh, kubectl, commits and pushes.
- The brief is reproduced at the end of this file. It asked for a blind meta review, with GPT's meta review of 2026-11-08 opened only after Fable's own verdict was on disk.

It is also Fable's first review here. Its section 6 (correctness risk) covered `thesis-refreeze` at `92f0b61`, the same code Argon reviewed in `2026-11-09-argon-web-refreeze-rounds13-14.md`. Argon's review was kept off every ref and path Fable could read until Fable finished, so the overlap between the two counts as a blind calibration.

Fable wrote the review to `FABLE-META-REVIEW.md` in that worktree at 20:23 UTC (15:23 EST), and section 7 at 20:26 UTC (15:26 EST). It is filed below verbatim. Its paired EST times are its own; the advisor inserted those in [brackets].

---

# Meta review, Claude Fable 5.2

Written 2026-11-09 20:23 UTC (15:23 EST), from a clean detached worktree of `main` at `b3ad8e5`, no `data/`. Read in full: `CLAUDE.md`, `PROGRESS.md`, the paper's sections 1 to 2, 8 to 9, 12 to 17 and appendices S and T, stage 10 of `audit/criteria.md`, the positive-control criteria draft and PC1 to PC6, `thesis/runner.py` and T3 on `thesis-refreeze` at `92f0b61`, and the first session leaf of `ctx`. Read in part: `audit/decisions.md` (headings and the entries cited; the 2026-11-08 21:22 UTC [16:22 EST] entry skipped until the last section) and the seventeen refreeze reviews (every verdict; rounds nine to twelve closely). Not read: most of the other 70 reviews, the positive-control reviews, `thesis/market.py`. Branches were read three-dot (`positive-controls` at `80d85d1`). Ran: two small scripts of my own (a cluster simulation, a statistics spot-check under `nix develop`) and one probe of the branch's transcript audit. No protected data, no cluster, no model. Sections 1 to 6 and the verdict were on disk before I opened GPT's meta review; section 7 was added at 20:26 UTC (15:26 EST). One leak into the blind part: an early grep over dated lines showed the first 220 characters of the skipped decision entry ("recommendations 2, 4 and 7 … stage 7 is parked once slice 4 is finished"), which the brief had already told me.

## Verdict

The project is honest and not on course. In three weeks and 1,273 commits it has produced one real-data research campaign, in which the agent made 9 evaluations in 407 seconds for $1.50 and neither arm had a finalist (`audit/stage3/real.json`), and seven frozen thesis-track versions, none of which lived longer than 6.1 days of the 28 that C10.5 needs (`audit/stage10/manifest.json`). Against that stand 277,000 words of audit record. Everything established so far is about the machinery, and the one finding that bears on the research question is negative and already derived in the paper: at the pilot's holdout lengths no ordinary edge can be confirmed (S4a; C2.6 failed twice and was waived). The refreeze is not converging, because its design materializes immutable history eagerly under a self-imposed rate budget, its identity makes every plumbing fix irreversible, and its criteria turn each rare operational miss into a blocking finding. Worse, the thing being frozen cannot answer the question even if it runs perfectly: its dependence rule yields at most one cluster per session and percolates, so the 200-cluster floor is years away or unreachable, and its reading arm may read four hosts. Change the identity rule, fix the three scientific parameters that only a freeze can fix, freeze, and stop reviewing plumbing. Run a cut-down positive control now; it no longer depends on the refreeze.

## Recommendations, ranked

1. **Split the thesis identity into a scientific manifest and an operational layer, then freeze.** Scientific: model, briefs, tools, limits, registry validation, sizing, `SCORING.md`, the comparator. Operational: acquisition, scheduling, retries, the limiter. An operational patch gets a decisions line and a targeted test, and the window continues, with the operational commit recorded per session. *Outcome changed:* countable forward days, now 0 of the 14 the track has run; the freeze stops being irreversible, so the review loop loses its reason. Only the human can decide this (it narrows "versions are never pooled").
2. **Before that freeze, decide the three scientific parameters that determine whether the track can ever inform** (section 3): what the reading arm may read, how many theses a day, and the dependence unit. Then pre-register a paired main-versus-ablation Brier protocol in the first week. *Outcome changed:* the first skill statement moves from years or never to about three to four months for a large effect.
3. **Fix two defects before anything is frozen** (section 6): the C10.2 tool audit cannot see server-side tool blocks, and the positive-control truth assay's Student interval is invalid at its tail level for skewed statistics. *Outcome changed:* C10.2 passing while its claim is false; a false "recovery" certification.
4. **Start the positive control now, cut to its one unknown.** Its dependency on the refreeze is stale since round thirteen. Keep discovery, drop the selected-recovery test and the 964,476-replay truth bank, run it sequentially. *Outcome changed:* the first agent-versus-baseline result in about two weeks instead of after the freeze and GPT's quota; roughly half the sessions.
5. **State the pilot's finding and stop building toward a confirmation that arithmetic forbids.** No further gate, kernel, Lean, O1 or nine-defect work until a study with a multi-year holdout or a forward window needs it. *Outcome changed:* all remaining pilot-infrastructure effort.
6. **Pre-register only what judges a number someone could game; make operational readiness a test suite.** And give fix-and-review loops a stop rule: two rounds, then `CLAUDE.md` §1 applies and the design is re-derived. *Outcome changed:* no more C3.2 v1 to v3, C4.5 v1 to v3, or C10.2's four rounds.
7. **Erase** (section 5).

## 1. Convergence

**It is not converging.** Evidence:

- **This is the eighth freeze, not the first refreeze.** `audit/stage10/manifest.json` chains seven versions frozen between 2026-10-26 and 2026-11-03. The longest ran 6.1 days (`thesis-310449610583`, stopped 2026-11-09 02:57 UTC (2026-11-08 21:57 EST), "its window incomplete, never pooled", `PROGRESS.md:13`). Each was replaced for plumbing or accounting defects: a missing CA store (27 of 27 fetches refused), runner and retrieval fixes, the hunt bundle of 2026-11-03, now a managed-return summary and six recorder and sampler fixes.
- **Verdicts do not trend to ready.** Rounds one to four: not ready. Five to seven: ready after fixes. Then the pre-freeze hunt (F1 to F4), Opus on round nine (N1 to N5), Argon on round ten ("DO NOT FREEZE", eight findings, four lost to a cut-off reply), Opus on eleven ("Not ready", two high), Argon on twelve ("fixes needed", four defects, two lost). Each new reviewer finds a new class.
- **The code under review only grows.** From `main` to `92f0b61`: `thesis/runner.py` 377 to 692 lines, `thesis/market.py` 195 to 556, `ingest/hl.py` 91 to 159, thesis tests about 4,400 to 7,900 lines. The one deletion was round thirteen removing the C10.2 mapping that rounds eight to twelve had built.
- **Fixes create the next round's findings.** Round two's finding 1 was a regression from Argon's suggested read-only open. Round nine's N1 is the hunt's F1 fix making one transient failure final for the date. Round eleven's R2 "introduces a Monday regression" (`2026-11-09-opus-thesis-refreeze-round11.md`). Round twelve's F1 is a `pop` that round eleven moved.

**Why, in order of weight.**

1. **The design.** A wall appeared in round three (the warm workload does not fit 120 weight a minute) and was patched around for eleven rounds, which `CLAUDE.md` §1 forbids. Paper T3 is now about 3,900 words fitting 348 listings, 1,125-day funding scopes and a 6.65-day cold fill into that budget, with a snapshot state machine (`draft`, `scoped`, `failed`, `failed_dexes`, `readiness_at`, retry cutoff 04:45) to manage it. Almost everything it acquires is immutable history: daily bars completed before the cutoff, the 00:00 hourly close, past funding. Immutable history gives the same bytes whenever it is fetched, so it does not need a point-in-time snapshot, an attestation or a deadline; it can be fetched when a session asks and cached for the date. The funding scope exists only because the base rate `p_ref` is computed synchronously at registration; it is a deterministic function of history before `t_r` and can be computed any time before scoring. The 120 itself is a choice three times over: a 600 self-commitment against the venue's 1,200, of which the cluster recorder takes 480, while the Oracle VM records the same venue at 600 from another address (`PROGRESS.md:17`).
2. **The identity.** One hash covers scoring and plumbing, so every plumbing defect costs the whole sample and every freeze "can't be undone". That triggers the heaviest review rule, which finds more plumbing.
3. **The criteria.** C10.5's counts ("exactly four executed benchmark batches") and C10.2's transcript mapping are operational, pass or fail, and unamendable once the window starts. So a transient `ReadTimeout` on BTC that heals at 04:44 while ZEC times out across 04:45 (Argon, round twelve, F1) ranks High. In the round nine to twelve findings I read, none changes a thesis's outcome or score; each changes whether a session or batch happens or whether an audit passes. C10.2's mapping cost four rounds and was then deleted, having failed closed on 40 of 40 honest sessions.
4. **The review process.** "Ready" has meant "no reviewer can construct a failure", against an open world of outages. That has no fixed point, and rotating models guarantees fresh constructions.
5. **The builders** least. Fixes were mostly at cause and failing-test-first. The regressions are a property of the state machine.

**The smallest refreeze that serves the claim.** The claim is: theses registered before their outcomes, every disclosure recorded, scored by a fixed rule. That needs the registry, positions and scoring fixes, record-before-reply, and a frozen scientific manifest. It does not need a live Monday benchmark: a deterministic rule on data fixed at Monday midnight can be replayed offline from recordings at report time, and its probability is the base rate, so its Brier skill is zero by construction (`thesis/runner.py`, `register_benchmark`, `p_is_base_rate=True`). It does not need the eager snapshot, readiness or the prewarm. It does not need C10.5's counts as gates; they are report lines.

**Sequencing.** Do not rebuild before freezing. With recommendation 1, freeze the current head once Argon's review of rounds thirteen and fourteen is in and the audit is fixed, then simplify acquisition as operational patches that do not reset the window. Without recommendation 1, expect version eight to die like the first seven.

## 2. Positive controls

**The arithmetic is right.** I recomputed independently: (33, 12) is the smallest design, size .02159, power .95993; `q = t(72, 1 − .01/(4·6606)) = 5.419` and n = 73 is the smallest with noncentral-t power ≥ .9975 at one SD (.99787; n = 72 gives .99741); validation `q = 3.174`; R screens with probability .338; the betting horizons 31,755 and 31,062 steps follow from S3.

**The size is wrong for what it must show**, for three reasons.

1. **Half its decision is already answered.** By the paper's own S2 formula, a true Sharpe 1 program passes the DSR screen with probability .338 at N = 1, .036 at N = 7 (the real agent's N), .006 at N = 30 and .002 at N = 100; Sharpe 3 at N = 100 passes at .31. And r2's nearest cell had G400 freezing finalists in 13 of 100 markets (PC2). So selected recovery sits at or below the "rare" anchor of .2 for both arms before any session runs, and confirmation is known to need 14.5 years (PC4). Only discovery is unknown; the selected-recovery test measures what formulas and r2 already give. PC5's forced release and PC.C6's kill tests check the release code. They need no model and no pre-registration, and belong in the test suite.
2. **The truth assay estimates what is known exactly.** In a synthetic market the plant's expected gross return for any predictable position is `β·Σ w·a` over the planted coins. That is a noise-free functional of a program's positions on the market it searched. The twin-market design is a noisier control variate for the same quantity, and it is what forces 73 pairs, `q = 5.419` and 964,476 replays (187 core-hours). I am unsure whether `mm eval` exports per-step positions and how liquidation enters; if it does not, export them.
3. **A fixed n = 33 where a sequential test would do.** Wald's test of p ≤ .2 against p = .5 at the same error rates stops after about 15 markets on average under either hypothesis. Sessions are isolated, so assaying each market before the next leaks nothing.

**One modelling error**, section 6: the Student interval at a one-sided 3.8·10⁻⁷ with n = 73 is not valid for skewed per-pair statistics.

**A stale dependency.** PC1 holds the manifest until the refreeze lands because round eleven forked the harness. Round thirteen undid the fork (`fee23e7`): `main...thesis-refreeze` now changes no file that `gate/agent/harness.py`'s `harness_hash()` covers (only `sandbox/canary.py` and tests differ), and the hash is `6a335714…` again. The study can pin that value today. Its accounts (TAMU, Cornell) are not the thesis's (PERSONAL).

Four rounds of design review have produced 3,656 words of paper and seven criteria, and no code.

## 3. Research value

**Established so far.**

- **The confirmation wall.** A 360 to 546 step holdout confirms only annualized Sharpe near 4.9 (S4a, `docs/whitepaper.tex:598`); C2.6 failed as written and amended; a Sharpe 1 finalist needs 14.5 years under the gate's bet. This is the minimum track record length of Bailey and López de Prado (2012), reached the long way. Because the holdout must also postdate the model's cutoff (June 2026), the backtestable track with a frontier model is limited to months of holdout by construction. That is a real finding about "rapidly test": for systematic strategies of ordinary Sharpe it is not possible honestly, on any venue, with any kernel.
- **The pipeline runs clean under the null.** Zero promotions in 300 campaigns per cell for cheap searchers. For agents, 0 of 20 single-agent campaigns (bound 14%) and 21 known non-promotions of 22 swarm campaigns (bound 13% to 20%).
- **Agents versus baselines on real data: nothing.** One session, 9 evaluations, maximum DSR 0.257, against a baseline's 100. The agent stopped by itself at 9% of its budget, which nobody has followed up.
- **Thesis skill: nothing**, by design and by attrition.

**Why the thesis track as specified cannot inform.** Three scientific parameters, all inside the frozen identity:

1. **The dependence unit percolates.** `SCORING.md:60-67` links theses of the same session, the same catalyst, or a common market with intersecting windows, and a cluster resolves only when every member has. So there is at most one new cluster per session, and chains through popular markets never close. I simulated it (one session a day, 1.4 or 2 theses, horizons 7 to 30 days, market choice Zipf over a pool). Resolved clusters after 365 days: 300 in the best case (uniform over all 278 markets, 1.4 a session); 152 with Zipf over 278; 86 or 18 with Zipf over 60 markets at 1.4 or 2 a session; 5 with Zipf over 30 at 2 a session, where after two years one component holds 1,437 of 1,460 theses. The 200 floor is seven to eight months away at best and unreachable under realistic concentration. The advisor can check this against the stopped tracks' cluster counts, which are counts, not prices. I am unsure of the agent's real concentration.
2. **Throughput.** At most two theses a day, when the agent's cost is not the constraint.
3. **The treatment is starved.** `thesis/brief.md:14-18` opens four hosts to `fetch`: GDELT, Treasury fiscal data, CFTC and Fed RSS. The human's aim was "news ingestion, catalyst triage … data mining … from the far corners of the internet". A null from this arm says little about that aim. A search API whose terms permit automated use, called through the daemon so every result is disclosed, is a certificate the human can grant.

**Shortest paths, by question.**

- *Do agents search better than cheap baselines?* The cut-down positive control, about two weeks. Free alongside it: publish each arm's search-period distribution from the existing stage 3 ledgers, and find out why the agent stopped at 9.
- *Does reading help the agent's forecasts?* A paired test of the main thesis against its conditional ablation: `d = (p − o)² − (p_abl − o)²`, same outcome, so outcome noise largely cancels, with blocks by registration week. With about 180 pairs in 13 weeks, a 0.03 Brier difference is detectable and 0.01 is not (my rough calculation, taking |p − p_abl| near 0.1; unsure). Halawi et al. (2024), already cited, found retrieval worth roughly that much on general questions (from memory; check). So a large effect is answerable in about three to four months after a freeze that sticks, sooner at higher throughput.
- *Does any proposed strategy have edge?* Not before 2027 at the earliest, and only for Sharpe near 5. The forward window has run nine days with nothing registered to confirm in it.

## 4. Process cost

| Rule or loop | Caught | Cost | Verdict |
|---|---|---|---|
| Pre-registered **statistical** criteria | Locked suite v1 at 0.0595 against 0.0625; C2.6's two failures; C0.7's cells. Honest negatives that would otherwise have been tuned away. | Moderate. | Keep. |
| Pre-registered **operational** criteria | Nothing about the question. | C3.2 v1 to v3; C4.5 v1 to v3 (2026-11-01 to 11-08 for a smoke test with no finalist); C10.2's mapping (four rounds, deleted); C10.5's counts driving the snapshot machine. | Replace with tests. There is no result to hack, so freezing buys nothing. |
| Fresh-session **bug hunts** | Nine reproduced kernel and gate defects; recorder persistence failures (2026-11-02, 11-03). | A few reviews. | Best yield in the project. Keep. |
| **Fix-and-review rounds** | Real defects each round, in code the round before added. | Fourteen rounds, three days, code doubled, the track dark since 02:57 UTC [21:57 EST] today. | Cap at two rounds, then re-derive. |
| **Frozen identity, never pooled** | Protects judged gate results. | Seven thesis versions, zero countable days. | Keep for the gate and harness; split for the thesis track. |
| **Lean reference kernel** (8,840 lines against the engine's 5,047 of Rust) | One checker hole (L3); three laws false as frozen. None of the nine hunt defects. | Stage 6, and much of stage 7's 180 commits. | Formalism here was a finding-substitute, against the aim. Already deferred; keep it so. |
| **Independent implementation** (C10.4) | A one-ulp disagreement. Missed the shared missing-funding gap, which a review found. | Small. | Keep where a score depends on it, expect little. |
| **Cross-model independence** | Each model caught what another missed. | The critical path now waits on quotas (GPT about 11-13, Argon about 11-14). Argon by web paste lost findings twice; the human is the courier. | Use it for judged results only. |
| **Opus gives the last review before anything irreversible** | Rounds five to seven, sound reviews. | Scales with how much is irreversible. | Fine once recommendation 1 shrinks that set. |
| **Append-only audit** | Kept failures visible (C4.5, C3.2). | 277,000 words; `audit/criteria.md` alone is 38,000, which every fresh reviewer partly loads. Usage is the binding cost. | Keep the rule; write less into it. |

One pattern sits under the table. Reviewers rank findings by the criterion they could trip, not by the score they could change. `CLAUDE.md` already says each finding "names the outcome it could change"; in practice "fails C10.5" has counted as an outcome. It should not, once C10.5 is a report.

## 5. Erasure

- **Criteria scope:** C10.5's counts and deadlines as exit conditions; C10.2's per-session mapping (gone in the draft; let the frozen text's successor say so plainly); positive-control PC.C6 as a criterion (keep its tests) and the selected-recovery half of PC.C5; PC.C7 down to one line (the account identity check).
- **Code, on `thesis-refreeze`, after the freeze under recommendation 1:** the live Monday benchmark (`benchmark`, `register_benchmark`, `benchmarks`, `known_at`, `unbenchmarkable`, `listings_at`, `BENCHMARK_GIVE_UP`, the Monday branch of `last_acquisition`); the snapshot state machine (`snapshot`, `draft_of`, `list_pass`, `read_pass`, `attested`, `acquire`); readiness and `prewarm`. Replace with lazy reads of immutable history.
- **Tests:** the eleven files named for review rounds (`thesis/tests/test_refreeze_round4.py` to `round14.py`, `test_refreeze_t3.py`). Fold what survives into tests named for what they hold; most go with the code above.
- **Paper:** T3's capacity derivation, about 3,900 words, down to the cost conventions; PC5; PC6's forecasts.
- **Rules in `CLAUDE.md`:** "GPT builds by default" and the Argon command block, while both quotas are spent, are dead text; the reviewer list under "Reviews" can shrink to the stop rule and the outcome rule.
- **Branches:** `stage7` (180 commits, +26,686 lines) and `claude/lean-l1-kernel-defects-h273e5` stay parked; delete worktree `../moneymachine-stage7` to stop it drawing attention. Stage 8 and 9 criteria (4,400 words) are frozen for stages that will not start as written; mark them superseded when a real study is defined, do not build to them.
- **Backlog items that serve no study:** the nine-defect corrected engine, O1's B = 0.2, the delisting corpus, C5.6 calibration, DSL.md's derivation prose.

## 6. Correctness risk

**A. C10.2's tool audit cannot see the tool it exists to catch** (`thesis-refreeze`, `sandbox/session.py:159-163`; `thesis/report.py:77-82`; wording (b) in `audit/stage10/criteria-revision-round11-draft.md`). `calls()` collects only content blocks of type `tool_use`, and skips undecodable lines silently. Wording (b) justifies the per-session condition by "a server-side WebSearch or WebFetch". In the API's message format a server-side tool is a `server_tool_use` block, and an MCP connector call is `mcp_tool_use`. Construction, run against the branch's functions: a transcript holding one honest `Bash` call, then `{"type":"server_tool_use","name":"web_search",…}` with its result, then an `mcp_tool_use`, then a torn final line naming `WebFetch`. Output: `{'tools': ['Bash'], 'outside_permitted': [], 'denials': 0}`, so `c10_2` passes. No test on the branch mentions either block type. I do not know whether the CLI can emit such blocks under `--tools Read,Write,Bash`; the condition exists for the case where the flags fail, and there it is blind. The fix is the builder's, from a failing test: fail on any content block type outside an allowlist, and on any undecodable line that is not the last. Note that `sandbox/session.py` is inside `harness_hash()`, so fixing it there forks the stage 3 harness; `thesis/harness.py`'s `audit` is thesis-only.

**B. The positive control's truth interval is not valid at its level** (`positive-controls`, PC4). For a mean-zero, left-skewed per-pair statistic (0.3 with probability 1 − ε, −0.3(1 − ε)/ε otherwise, plus small noise), the rate at which the lower endpoint exceeds zero at n = 73, q = 5.419 is 0.23 at ε = .02, 0.023 at .05 and 0.004 at .1, against a nominal 3.8·10⁻⁷. That shape is what a threshold program produces across markets with different volatility levels: quiet in most, churning in a few. So "the family misclassification allowance is .01" does not hold for the programs most likely to be misread, and a false recovery counts toward the cutoff of 12. Computing capture exactly (section 2) removes the interval.

**C. The 200-cluster floor is unreachable under plausible behaviour** (section 3). A run that operates perfectly never earns the right to a claim. This is in what is about to be frozen, and no later revision can reach theses already registered.

**D. Smaller.** A draft resumed after a kill undercounts `requests`, which the attestation and C10.6 report. A session missed because its attested bytes were lost after main ran is recorded as "the model or the sandbox canary was not ready" (`Track.day`, `why`). Neither changes a score.

I did not review `thesis/market.py`'s limiter or the registry in depth; absence of findings there is not evidence.

## Unsure

- The agent's market concentration and typical horizon, which set how badly clusters percolate.
- Whether lazy history survives venue behaviour I did not check: funding history for delisted coins, and revisions.
- The paired-Brier power figure, which rests on an assumed forecast spread and on my memory of Halawi's magnitudes.
- Whether an identity split can be drawn cleanly: acquisition failures change which markets the agent is shown, so the operational layer is not perfectly inert. I think recording the operational commit per session answers it for a descriptive track; an inferential protocol should say so explicitly.
- The four-host allowlist follows the Sources rule as written. Widening it is a terms decision, the human's.

## 7. Against GPT's meta review

Read after everything above was on disk: `audit/reviews/2026-11-08-gpt-meta-review.md` and the decision of 2026-11-08 21:22 UTC (16:22 EST).

**Where we agree.** The priority order is inverted ("an assurance system with a research project attached"). Stage exits are not research progress; stage 3's decisive path never ran. The thesis track is the closest match to the aim and the least stable. The frozen identity is too coarse. Stage 7 and the Lean migration should be parked. Hunts and boundary reviews earned their place; unbounded prerequisite growth did not.

**Where we differ.**

1. **GPT's first recommendation was the loop.** It said to complete the acquisition, readiness and durability repairs, check them independently, then hold scope. At its snapshot the bundle was five rounds old; it is now fourteen. GPT did name the cure, decoupling forecast evidence from recorder machinery, but ranked it sixth, costed it medium to large, and reserved it for "the next protocol", not to be retrofitted. The human adopted recommendations 2, 4 and 7, not 6. I rank it first: the eighth freeze is the next protocol, and nothing needs retrofitting, because no frozen day survives anyway.
2. **GPT did not ask whether the thesis experiment can inform if it runs perfectly.** The cluster rule, two theses a day and the four-host allowlist are absent from its review. I think this is the largest gap in the project and in both reviews of it before this one. "Inconclusive is an acceptable scientific result" is true, but an experiment that is inconclusive by construction is not an experiment.
3. **On sensitivity, the limit is the observation budget, not the test.** GPT asked for a better-powered betting design. Any valid test needs roughly three years for even odds of confirming Sharpe 1 (z = S√T), six for 80%. A redesign must change how many independent observations a claim gets; a cleverer bet cannot.
4. **On the positive control,** we agree on the matrix and the bottleneck attribution. I would make the forced finalist a test of the release code, and I would not spend sessions measuring selection and confirmation rates that S2, S4a and r2 already give.
5. GPT's recommendations 5 (study-specific scope gates) and 8 (budget by information gained) I did not examine. I have no disagreement with them.

**Is the adopted correction working?**

- **(a) Stage 7 parked: yes.** The branch's last commit is the slice 4 merge at 2026-11-09 04:33 UTC (2026-11-08 23:33 EST); nothing since.
- **(c) Reviews only at consequential boundaries: on paper yes, in effect no.** Reversible work now moves on targeted tests (the erasure sweep, the typing merge). But the freeze is still "can't be undone", so every refreeze round qualified as a boundary. In the 23 hours since the decision: refreeze rounds six to fourteen, seven refreeze reviews (one a bug hunt), three positive-control design reviews, and 143 commits across branches. The rule cut reviews where they were cheap and left them where they were expensive.
- **(b) A small positive-control study after the refreeze: no, twice.** "Small" became 33 markets by three arms, a 73-pair truth bank, seven criteria and four design rounds, with no code. "After the refreeze" queued it behind the least convergent work in the project, and behind GPT's quota. That ordering has had no technical basis since round thirteen restored the harness pin.
- **Net.** The correction removed work that was off the critical path and left the critical path's loop intact. Meanwhile the old track was stopped at 02:57 UTC [21:57 EST] today for a freeze that is not ready, with a prewarm bounded at 6.65 days. The project's only forward evidence stream is currently off.

The lesson I draw from the two reviews together: advice to "finish, then hold scope" does not stop a loop whose trigger is structural. What stops it is removing the trigger: make the freeze reversible for plumbing, and make the operational criteria reports.

---

## The brief (verbatim)

You are Claude Fable 5.2, the project's meta reviewer. This is a clean, detached worktree of `main` at `b3ad8e5` (2026-11-09 20:10 UTC, 15:10 EST). It has no `data/` and no tokens. Read `CLAUDE.md` and `PROGRESS.md` first.

## The question

Is this project on course to answer its research question cheaply and honestly, and what should change now?

The human's original aim, in short: use frontier agents' search and synthesis to propose and rapidly test retail trading strategies and theses, with statistics as the empirical standard and formalism as a means, not the finding. Judge the project against that aim, not against its own process.

## What to read

- `docs/whitepaper.tex`: intent, derivations and roadmap.
- `audit/decisions.md` and `audit/criteria.md`: what was decided and pre-registered. Both are append-only.
- The 90-odd reviews in `audit/reviews/`, and the stage evidence in `audit/stage*/`.
- `git log --all`. The active branches:
  - `thesis-refreeze` (rounds 1–14 of the stage 10 refreeze; worktree `../mm-thesis-rf`);
  - `positive-controls` (study design round four; `../mm-pos-controls`);
  - `stage7` (parked).
  Read them with `git show <branch>:<path>` and `git diff main...<branch>`, three-dot.
- History of the human's words and the sessions: `ctx --project -home-kevin-repos-moneymachine view | grep | zoom`. It is a retrieval aid. Before relying on a summary, read the leaf.

## Be blind first

Do NOT open `audit/reviews/2026-11-08-gpt-meta-review.md` until your own verdict section is written to disk. Also skip the `audit/decisions.md` entry of 2026-11-08 21:22 UTC [16:22 EST] that acts on it until then. After that, read both and add a final section:
- where you and GPT agree and where you differ;
- whether the course correction the human adopted from it (stage 7 parked; positive controls after the refreeze; reviews only at consequential boundaries) is working, judged by what happened since.

## Questions to answer, each with evidence (file:line, commit, or review)

1. **Convergence.** The stage 10 refreeze is at round 14 of fix-and-review. Is it converging? If not, why not:
   - the design;
   - the criteria;
   - the review process;
   - the builders?
   What is the smallest refreeze that serves the thesis track's claim? Would cutting C10 scope serve the aim better?
2. **Positive controls.** Is the positive-control design (branch `positive-controls`, round four) the right size for what it must show? Is its mathematics right? Spot-check the load-bearing numbers.
3. **Research value.** What has the project actually established about its research question so far? What is the shortest path to the first informative result, positive or negative?
4. **Process cost.** Which rules, roles and review loops in `CLAUDE.md` earn their cost, and which don't? Give each a name and the evidence of what it caught or cost.
5. **Erasure.** What should be deleted: code, criteria scope, docs, rules, branches? Name it concretely.
6. **Correctness risk.** Find anything you believe is wrong in what is about to be frozen or judged. This means the refreeze branch and the positive-control criteria draft. Give a concrete failing input or a construction.

## Output

Write `FABLE-META-REVIEW.md` in this worktree's root:
- start with `date -u` and the paired EST time (EST = UTC−5);
- a verdict paragraph;
- ranked recommendations, each naming the outcome it changes;
- then the sections above.

Keep it under 5,000 words. Say where you are unsure. The advisor (Opus 5.5) will file it verbatim in `audit/reviews/`.

After writing it, stay available. The human may ask follow-up questions as a meta advisor.

## Hard rules

- **Never read prices or returns** from holdout data, embargoes or the forward window [2026-11-01, 2027-01-31). This includes live recordings and anything under any `data/` directory.
- **Never read raw rows of kernel-only sources** (Databento/CME).
- **No cluster or homelab access:** no ssh, no kubectl, no reading `../Homelab`.
- **Run nothing heavy:** no campaigns, models, cluster jobs or `opencode`.
- **Write nothing** except `FABLE-META-REVIEW.md`: no commits, no pushes, no edits to other files or other worktrees.
- **Never `pkill -f`.**
- **Keep usage lean.** Read rather than spawn. If you use subagents, use few. This session runs on a limited Fable allowance.
