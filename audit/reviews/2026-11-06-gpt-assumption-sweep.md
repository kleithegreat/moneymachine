# Assumption sweep: conditions and numbers not derived from their claims

GPT (`openai/gpt-6.1-sol#high`, opencode), from a clean read-only worktree at `3c25121`, under CLAUDE.md's rule of that commit (derive each criterion from the claim it supports); started 2026-11-06 20:30 UTC (15:30 EST), reply received 20:36 UTC (15:36 EST). The advisor checked two findings against the code: 15 (`ingest/hl.py`: `TIMEOUT`'s comment assumes one attempt, while `Info.post` makes six with 1+2+4+8+16 s of backoff) and 5 (C6.4's 550 days, 13,200 h, hold three nested 4,380 h lags but not four). The reply as given.


**The closest remaining analogues to C4.5’s failed floors are stage 8’s history screens, C6.4’s warm-up length, the mechanism check’s exposure-share floor, and C10.5’s activity quotas.** Each can reject a working procedure or accept evidence that does not establish the intended operational claim.

The most consequential assumptions concern loss bounds and execution costs. Several are already explicitly qualified; I distinguish those from newly identified gaps.

## Scope and interpretation

I read the complete criteria and revisions, checked judgment status against `PROGRESS.md`, and searched the supporting specifications, implementations, decisions and reviews for derivations.

- **“No derivation found”** means no claim-specific derivation was found in those searches—not that the constant has no conceivable justification.
- A counterexample below generally targets the **named condition**, not an assertion that every other stage requirement also passes.
- Explicit policy choices—such as choosing a 5% error budget—are not inherently faulty assumptions. The problem is treating a chosen cutoff as evidence for something it does not establish.
- This was static, read-only analysis. No tests or campaigns were run. The separate stage-7 worktree was permission-denied, so findings about its unfinished policy rely on this checkout’s criteria and audit documents, not its current implementation.

## Ranked findings

### 1. The real-market pre-absorption loss bound remains assumed, not established

**Place:** `docs/whitepaper.tex:330–354`; `reference/SEMANTICS.md:278–299`; `audit/criteria.md:484–488`.

**Claim served:** Conditional validity of holdout p-values, and consequently Holm’s false-promotion guarantee.

**Derivation:** A derivation exists for the **corrected, gapless synthetic markets**: `reference/SEMANTICS.md:278–295` and `gate/NULLS.md:63–74`. It explicitly does **not** cover real-market gaps. The frozen pilot does not establish the bound either (`audit/criteria.md:485`).

**Counterexample:** Consider one frozen finalist with independent pre-absorption returns of +1% with probability 0.999 and −999% with probability 0.001. Its conditional mean is zero. On 602 consecutive gains, the gate’s capped bet produces wealth approximately \(1.005^{601}>20\), a significant p-value and positive total return. That event has probability approximately 55%. Absorbing the eventual shortfall does not undo earlier wealth maxima.

This is **not** a counterexample to the stated theorem: it demonstrates why its unestablished −2 premise is load-bearing. Observing no excursions in a particular run cannot certify that premise.

**Outcome:** Whether promotions carry a valid error-control claim.

**Status:** Already acknowledged and human-approved as a qualification, not a new discovery. Pilot evidence is judged; C4.5 v3 has already started. Future corrected-engine real campaigns remain affected.

---

### 2. O1’s provisional \(B=0.2\) has development motivation, not a derivation of safety or venue equivalence

**Place:** `audit/stage2/bound-options.md:30–63,101–119`; `audit/decisions.md:261–262`; `PROGRESS.md:35`.

**Claim served:** Improve power while retaining meaningful no-edge calibration and realizable account mechanics.

**Derivation:** There is substantial supporting development work: margin arithmetic and fixed-trace power experiments. But the independent review explicitly rejects three stronger interpretations:

- flooring old returns exactly simulates O1;
- initial-margin feasibility establishes venue equivalence;
- the inspected null experiments establish that 0.2 is safe.

See `audit/stage2/bound-review-gpt-1.md:5–32`.

**Counterexample:** An uncapped zero-mean return is +1% with probability \(30/31\), −30% otherwise. Flooring losses at −20% gives expected return \(0.1/31>0\). A correctly implemented bound can therefore pass while the original economic no-edge claim is false for the **new scored process**.

Conversely, a better betting rule at \(B=1\) might improve power without changing account economics; that comparison is expressly required by the review.

**Outcome:** Promotions, measured power, strategy rankings and the economic interpretation of discoveries.

**Status:** **Still provisional and unjudged.** This is a free place to derive the actual mechanics and null before committing a replacement—not a justified reason to adopt 0.2 as written.

---

### 3. Execution-model acceptance measures snapshot coverage, not costs at the strategy’s trades

**Place:** `audit/criteria.md:36,58–67`; `ingest/execution.py:23–25,65–80`; thesis reuse at `audit/criteria.md:775–779`.

**Claim served:** Net returns remain meaningful after execution costs.

**Derivation:** The revised q90 statistic is derived precisely: it is the least constant covering 90% of the test snapshots. The choice of **90% coverage, 95th-percentile fitting, 70/30 split, one day and 3 bps slack** has no claim-specific derivation found connecting it to error in strategy returns.

The criteria themselves acknowledge that fixed-path cost monotonicity is not a full-replay bound (`audit/criteria.md:64`).

**Counterexample:** Fit a 5 bps constant. In validation, 90% of snapshots cost 4 bps and 10% cost 50 bps. Coverage is 90%, and excess above q90 is only 1 bp: the amended condition passes. A strategy trades exclusively in the expensive 10%; an apparent gross edge of 20 bps is actually negative after execution.

For thesis markets without calibration, the cell-wise maximum across unrelated coins likewise need not bound that market’s cost. It is correctly called **unvalidated**, not derived.

**Outcome:** Backtest promotions and thesis binary outcomes, Brier scores and paper returns.

**Status:** C0.7 is **already judged and qualified as failed**, not passed. Its thresholds and fallback remain dependencies of later stages. C8.3 explicitly permits inheritance, making the transfer relevant before its unjudged annexes are frozen.

---

### 4. Stage 8’s fifteen-year and 750-publication-date screens are not derived from the study they admit

**Place:** `audit/stage8/scope-manifest.md:25,89,125,226–234`; downstream exclusion in `docs/future-work.md:29`.

**Claim served:** Admit histories and universes suitable for statistically affordable research.

**Derivation:** The paper supplies the motivational \(h(N,T)\) approximation (`docs/whitepaper.tex:84–110`), but explicitly says it is **not a decision rule**. No derivation found for **15 years per series**, regardless of frequency or role, or **750 consecutive available fixings**.

C8’s own annex rule is better targeted: minimum years **or eligible observations chosen from the intended study** (`audit/criteria.md:1137–1146`).

**Counterexamples:**

- Fifteen years of monthly observations passes the history screen with only 180 observations; ten years of daily observations fails with thousands. Neither ordering follows from confirmation power.
- A newly available auxiliary feature is excluded even where a short, powerful prospective test is possible.
- One missing fixing among 750 excludes a currency despite otherwise adequate history; that exclusion can persist until the missing date leaves the approximately three-year lookback.
- Perfectly complete but highly dependent fixings pass without establishing adequate independent evidence.

**Outcome:** Which sources, assets and whole research families are admitted or blocked.

**Status:** **Unjudged research scope; revisable prospectively.** No class is admitted. Existing exposure must still be accounted for; chronology alone does not justify these numbers.

---

### 5. C6.4’s 550-day corpus is not necessarily long enough for admitted nested lags

**Place:** `audit/criteria.md:641–657`, especially line 646; inherited by C7.7 at `1092` and C8.4 at `1233`; `kernel/DSL.md:106–117`.

**Claim served:** Differential agreement exercises defined stateful outputs, including long windows and nested lags.

**Derivation:** The apparent reasoning is that 550 days exceeds the maximum **individual** window of 4,380 hours. No derivation accounts for composition.

**Counterexample:** Four nested legal `lag(..., hours=4380)` nodes require 17,520 hours before the outer output becomes defined. A 550-day market has only 13,200 hours. Two implementations can agree throughout that corpus while one becomes wrong when the outer lag finally produces values.

The same issue applies to compositions of windows with undefined warm-up.

**Outcome:** Acceptance of a reference engine or port whose long-memory behavior has not actually been exercised.

**Status:** Original C6.4 **already judged**. The fresh C7.7/C8 corpora are **unjudged and revisable**. Their required duration can be derived from each program’s dependency depth rather than inherited wholesale.

---

### 6. Percentage completeness can pass while all economically relevant observations are missing

**Place:** C0.2/C0.5, `audit/criteria.md:17,34`; inherited C8.3 at `1202–1208`.

**Claim served:** A dataset is sufficiently complete for the intended replay.

**Derivation:** No derivation found linking **1% missing**, **99% replay completeness**, or the pilot’s **24-hour maximum gap** to the witness family’s information needs or resulting return error.

**Counterexamples:**

- Of 1,000 eligible decisions, the five containing the entire event-driven opportunity are missing. Missingness is only 0.5%, and replay completeness is 99.5%; both conditions pass.
- A harmless 1.01% absence, outside every dependency of the intended study, fails.
- Missingness can be concentrated around stressed conditions, so a small unconditional share need not imply small execution or selection bias.

**Outcome:** Dataset certification, stage exit and which evidence becomes eligible for campaigns.

**Status:** Pilot thresholds **already judged**. Their automatic inheritance into **unjudged C8 annexes** remains revisable. C8’s explicit refusal to call unsupported assumptions “conservative” is appropriate but does not derive these inherited percentages.

---

### 7. The mechanism check’s 10–90% exposure rule excludes genuine rare mechanisms

**Place:** `audit/criteria.md:372–373`; `kernel/mm/src/main.rs:308–316`.

**Claim served:** The registered condition identifies exposures with higher mean net return.

**Derivation:** The positive-difference condition directly matches the **sample-mean** claim. No derivation found for requiring each branch to occupy **10–90%** of exposures, or linking that share to precision, power or non-vacuity.

**Counterexamples:**

- A real mechanism acts on 5% of 10,000 exposures, with clearly higher net returns there. It fails solely because 5% is below 10%.
- A balanced 50/50 split with a tiny positive sample difference passes despite providing essentially no evidence of a persistent difference.

The latter matters only if passing is interpreted as mechanism evidence beyond the registered sample comparison; the paper correctly calls these checks fallible.

**Outcome:** Finalist removal, holdout-family size and potentially promotions in either direction through Holm.

**Status:** No recorded candidate exercised the check, but it is **frozen into procedures already judged or running**. That is not unrestricted revision freedom. The replacement engine is unjudged and can receive a claim-derived rule. The closing-cost and undefined-denominator defects are already separately recorded; correcting them does not justify 10%.

---

### 8. C10.5’s activity quotas neither establish nor are necessary for live operational readiness

**Place:** `audit/criteria.md:884–899`.

**Claim served:** Stage 10’s expressly operational exit claim—not forecasting skill.

**Derivation:** No derivation found for **28 days, 20 accepted main theses, 10 resolved theses**, or why **four benchmark batches** suffice to establish the listed capabilities. Four weeks explains the calendar opportunity, not coverage of operational outcomes.

**Counterexamples:**

- A fully working agent finds only 19 defensible theses. Registration, retrieval, positions and scoring work, but the stage fails.
- Twenty main theses register; every conditional ablation is a reported failure; every full no-reading session is reported missed; all benchmark markets are skipped with reasons. Those allowances satisfy the corresponding activity bullets without demonstrating those live paths work.
- Ten resolved single-leg theses need not exercise live spread, builder-market or invalidation paths.

The unit fixtures provide separate evidence; activity counts do not replace live path coverage.

**Outcome:** Stage-10 pass/fail and time spent waiting for “enough” activity.

**Status:** **Exit unjudged, but the current frozen window has begun.** A revision cannot retrospectively judge its existing days; changed harness behavior also requires a new track.

---

### 9. The mapping precision threshold is expressly post-measurement and lacks the paper’s requested dilution derivation

**Place:** `docs/whitepaper.tex:249,253`; `criteria/test_stages3to5.py:73–78`; `ingest/labels.py:17,24–47,51–75`.

**Claim served:** A forum-to-coin mapping is good enough to bind a usable feature.

**Derivation:** The paper explicitly records that **0.8 was set after precisions were measured**, before returns existed. That prevents return-conditioned selection, but does not derive 0.8 from acceptable signal dilution. The **50-item sample** has no stated confidence/precision target.

The original C5.1 requires reporting precision and recall, not this universal acceptance threshold (`audit/criteria.md:521`). The stage-7 policy review also questions its provenance (`audit/stage7/policy-review-gpt.md:165–179`).

**Counterexamples:**

- Forty of fifty sampled items concern the coin: pass. The ten wrong items could contain all large feature spikes.
- A 79% mapping with harmless background noise and a strong, independently confirmed signal fails.
- Excellent sample-frame recall does not establish recall outside the selected forums; the exit review explicitly acknowledges that limitation.

**Outcome:** Feed admission and the population of event features available to research.

**Status:** Stage 5 **already judged**. A general stage-7 certification policy is **unjudged**, but must not silently present the old 0.8 as a claim-derived universal rule.

---

### 10. Recorder list limits and polling cadences assume event survival and bounded bursts

**Place:** `ingest/sources_record.py:20–22,43–59`; `ingest/events.py:36–46,58–81`; `venue/sources/datalayer.json:42–55,77–86`; `ingest/datalayer.py:97–109,147–155`.

**Claim served:** Successful polling establishes usable event coverage and preserves non-refetchable observations.

**Derivation:** Endpoint list limits and release cadence are documented facts. No derivation establishes that:

- at most 20 Snapshot proposals or the forum endpoint’s latest-page capacity arrive between polls;
- a 15-minute nominal interval always observes every GDELT release;
- three-hour sampling preserves every transient active alert or selected outcome-market record.

**Counterexamples:**

- Twenty-one proposals arrive between four-minute polls. The newest twenty are recorded, yet the poll is accepted as coverage.
- GDELT index reads at 12:14 and 12:30:01 miss the 12:15 release.
- An alert appears and disappears between three-hour reads; every HTTP request succeeds.

The first two are already documented in `audit/reviews/2026-11-02-gpt-hunt-recorders.md:57–75`.

**Outcome:** Lost recordings, understated counts and false covered-zero observations; later certification can inherit incomplete evidence.

**Status:** Stage-5 evidence **already judged**; C5.6 remains deferred. Stage-7 research certification is unjudged. Some recorder changes touch the frozen thesis manifest and require a new version.

---

### 11. Thesis eligibility, comparator availability and sizing have unrelated numeric screens

**Places and consequences:**

| Rule | Derivation search and concrete mismatch | Status |
|---|---|---|
| **90 completed daily bars**; horizons **72–1,440 hours** — `audit/criteria.md:755–761`; `thesis/registry.py:25,110–121` | No derivation found tying 90 bars to the permitted horizons or operational eligibility. A 60-day thesis with 90 days of history is eligible but cannot supply ten historical comparator windows. An otherwise usable 89-day market is refused. | Frozen current track; exit unjudged, evidence accruing. |
| Comparator uses **1,095 days**, needs **10 windows** — `thesis/SCORING.md:43–50`; `thesis/scoring.py:11–14,42–57` | No error/stability target derives either cutoff. Nine high-quality windows exclude a thesis from skill scoring; ten unstable windows admit it. Horizon choice therefore changes comparator coverage discontinuously. The comparator is correctly described as historical, not calibrated. | Frozen and implementation-tested; new rule needs fresh track evidence. |
| **1% risk**, **5% reservations**, \(L\in[1\%,50\%]\) — `audit/criteria.md:758,768–771`; `thesis/positions.py:29` | \(N=b/L\) is derived; the chosen percentages are not. At \(L=1\%\), five admitted two-leg spreads can have gross notional \(10E\). A simultaneous gap can lose far more than the nominal 5% reservation. No gap/dependence calculation derives these settings. | Frozen policy. The criteria correctly disclaim a realized-loss bound; the paper’s broader “total risk … capped” language is stronger. |
| **200 resolved clusters** before any skill claim — `audit/criteria.md:714` | The paper derives approximately 194 **independent Bernoulli trials for a particular hit-rate alternative**, not 200 graph clusters for paired Brier skill. A powerful paired comparison can need fewer; 200 dependent clusters can remain inadequate. | A conservative prohibition, not permission to claim skill at 200. A separate protocol is explicitly still required. |

These are mostly **underived scope/policy choices**, not evidence that the current descriptive scores are mathematically wrong.

---

### 12. Gate screens and power targets are calibrated choices, not consequences of the claims

**Place:** `audit/criteria.md:150–174,267–288`; future inheritance at `1252–1259` and `1373–1389`; implementation constants in `gate/gate.py:17–21`.

**Claim served:** Selection retains useful candidates without sending excessive noise to confirmation; calibration demonstrates useful sensitivity.

**Derivation:** The revised DSR reference scale has a qualified derivation. No derivation found for **DSR ≥0.95**, **bootstrap block 6**, **1,000 replications**, or the **30% power target** from a required operational loss, sensitivity or effect size.

They are honestly labeled selection heuristics, not inferential guarantees.

**Counterexamples:**

- A genuine persistent edge can miss an arbitrary search screen even though an untouched confirmation would establish it.
- A null search can screen nothing and make the complete-null criterion look excellent while the pipeline is blind. The existing C2.6 failures demonstrate this is not hypothetical.
- C9.5 can achieve 30% at an arbitrarily strong “strongest” planted signal while remaining useless at the effects the intended study concerns.

**Outcome:** Finalist selection and stage-8/9 exit through inherited calibration requirements.

**Status:** Stage 2 **already judged**, with sensitivity explicitly waived. C8/C9 are **unjudged**: their annexes can tie effect sizes, observation budgets and required sensitivity together instead of merely inheriting 30%.

---

### 13. C4.5 v3 still lets promotion mask non-establishment

**Place:** `audit/criteria.md:480,487`; `gate/agent/campaigns.py:191–209`.

**Claim served:** A smoke test of the swarm’s audited code paths.

**Derivation:** Two evaluating agents and cross-agent receipt directly witness multi-agent activity. But promotion takes precedence over unresolved or unestablished evidence. No derivation makes a promotion evidence of those missing operational properties.

**Counterexample:** Eight campaigns are established. One is not established. One promotes but has mismatched audit evidence and would otherwise be unresolved. Its class becomes `promoted`; totals are one promoted/unresolved and one not-established, so the series passes.

**Outcome:** A pass despite two campaigns lacking establishment, one with incomplete audit evidence.

**Status:** **Already explicitly acknowledged**, with reporting rather than a verdict repair (`audit/criteria.md:487–488`). V3 has judged evidence already; it is not freely revisable. This is another surviving proxy failure, not a newly discovered implementation bug.

---

### 14. Evaluation, history and pacing budgets lack a bound on the behavior they are sometimes said to guarantee

**Place:** `audit/criteria.md:145–148,300,356,450`; `gate/agent/{daemon,harness}.py`; `gate/agent/campaigns.py:33–34,306–340`.

**Claims served:** Bounded resource use, sufficient opportunity to research/share history, and avoiding subscription exhaustion.

**Derivation:**

- **100/400 evaluations, four agents, twenty history calls, 200 turns/two hours** define a frozen workload. No derivation found connecting their exact values to information exposure or useful search opportunity.
- **0.8 utilization ceiling** is a reservation policy; `campaigns.py:33` says the remainder stays with the human.
- The maximum previous campaign usage is measured, but **is not an upper bound on the next campaign**. The initial 0.5 estimate is explicitly assumed.

**Counterexamples:**

- Twenty early history calls contain nothing; a useful twenty-first call is refused. Twenty calls also do not bound bytes or repeated information exposure.
- Utilization 0.60 plus measured need 0.15 passes pacing; the next campaign consumes 0.45 and exhausts the account.
- Utilization 0.31 plus the unmeasured 0.50 fallback blocks a campaign that would use only 0.05.

**Outcome:** Refusals, campaign scheduling and crashes counted against smoke criteria.

**Status:** Search/history limits are already frozen into judged procedures. Pacing is operationally adjustable, but its no-exhaustion wording overstates a heuristic predictor. These are not substitutes for statistical error control, and the paper correctly says so.

---

### 15. Recorder timing rationales contain behavioral assumptions not supplied by their arithmetic

**Place:** `ingest/hl.py:16,36–50`; `ingest/record.py:24–27,88–101`; `audit/criteria.md:18,55`; `ingest/availability.py:175–187`.

**Claim served:** Polling and clock evidence distinguish source lateness from recorder failure.

**Derivation and counterexamples:**

- **10-second HTTP timeout:** its comment argues one timeout plus five-second backoff fits the gap limit. But `Info.post` makes six attempts with 1+2+4+8+16 seconds of backoff: approximately **91 seconds** of timeout/backoff alone, before limiter waits. The stated derivation omits the implemented retry path.
- **Three failed verification attempts:** bounds queue blockage, but no derivation establishes that three failures make the observation unrecoverable. An outage ending just after the third loses otherwise recoverable reference evidence.
- **Numerically changing NTP offsets every forty minutes:** the longest poll interval motivates a freshness interval, not the assumption that fresh measurements must differ numerically. A healthy clock repeatedly measured at exactly the same offset can fail this instrument.
- **120-second availability:** a one-day live check can validate that sampled window, not all historical or future release delays. The paper explicitly acknowledges historical transfer as an assumption (`docs/whitepaper.tex:247`).

**Outcome:** Window eligibility, dropped reference polls and historical availability grants.

**Status:** C0.3 **already judged**. Prospective C5 clock figures were amended to reporting-only. Recorder operational changes must preserve old judgments and respect manifest boundaries.

The deployed **480/min** budget is a separate, already proved capacity mismatch: 360 remains after L2 reservation versus at least 440 needed at four-hour boundaries (`audit/decisions.md:546`). It is not an unexplained guess; its derivation disproves suitability.

---

### 16. Mirror verification’s twenty-minute allowance and disk guard do not establish recording safety

**Place:** `ops/live.py:30,305–334`; `ops/diskguard.sh:2–9`; `CLUSTER.md:27–30,90–94`.

**Claim served:** Distinguish a healthy in-progress mirror publication from corruption, and warn before recording capacity is exhausted.

**Derivation:** Twenty minutes is explicitly **next ten-minute run plus ten minutes copying allowance** (`audit/decisions.md:680`). The first term follows the schedule; no throughput/backlog bound derives the second. No source-growth or response-time calculation derives the disk guard’s **20 GB**.

**Counterexamples:**

- A healthy large snapshot takes twenty-one minutes to publish. Verification can report corruption solely because the guessed allowance expires.
- Mirroring stops while the recorders continue. Verification checks old manifested prefixes, not a freshness requirement; valid old copies can continue to verify while new recordings remain unprotected.
- The local `data/` filesystem has ample free space while a cluster recording filesystem fills. `diskguard.sh` checks the former, not all recording volumes. `CLUSTER.md`’s “above 80%” warning is not what that script implements.

**Outcome:** False unhealthy reports or failure to warn about loss of new recordings.

**Status:** Operational, not a frozen scientific criterion; revisable. Existing copy-integrity checks should not be confused with a derived recovery-point or capacity guarantee.

## Lower-consequence acceptance constants

These also lack claim-specific derivations found, but warrant less alarm because the specifications mostly make **sampled or supporting claims**, not universal correctness claims.

| Exact place | Assumption and counterexample | Outcome/status |
|---|---|---|
| C1.7, `audit/criteria.md:118–119` | Sharpe **4** for admitted programs and **20** for the deliberate leak; fixed/random seed counts and twenty random programs. Martingale correction is derived, but these cutoffs are not calibrated to a stated simultaneous false-alarm/detection target. A leak triggered only by nonzero funding evades these zero-funding markets; a correct program can exceed a finite stochastic cutoff. | Supporting criterion, already judged. |
| C4.2, `audit/criteria.md:458`; `kernel/CANONICAL.md:7–10` | **99%** on 1,000 generated pairs, with **30 iterations/20,000 nodes**. Deterministic limits derive reproducibility, not those values’ equivalence-detection coverage. Generated short rewrites can pass while deeper valid equivalences remain undetected; 98.9% fails without implying unsoundness. | Canonicalization acceptance; stage 4 not exited, but implementation evidence exists. |
| C7.4/C7.6, `audit/criteria.md:1041,1081–1084`; C8.1 at `1162–1167` | First **200** baseline programs; **1,000** rule/query cases and **100** per operator category; **100** universe-audit dates. No coverage-risk or detectable-defect prevalence derives these counts. A defect confined to an unsampled composition/date can pass. Mandatory categories improve the design; mere volume does not derive adequacy. | Fresh C7/C8 judgments remain unjudged. C8 correctly limits its claim to sampled completeness. |
| I5, `kernel/INVARIANTS.md:13,21`; `kernel/mm/src/sim.rs:17–21` | Scaling tolerance with attained magnitudes has a rationale; the **1e−9 coefficient** has no operation-count/rounding-error bound found. At peak equity \(10^{16}\), a later accounting error of \(10^6\) passes the \(10^7\) tolerance even after equity collapses. | Accounting refusal/acceptance; already judged. |
| C6.4/C10.4, `audit/criteria.md:656,882,955` | Relative comparison tolerances have scale-based motivation, but no full error budget derives their coefficients. They must remain separate from discrete outcome decisions, which the current thesis revision correctly makes exact. | Differential acceptance; old evidence judged, fresh comparisons version-specific. |
| DSL limits, `kernel/mm/src/dsl.rs:8–12`; `kernel/INVARIANTS.md:34–36` | **4,096 nodes, depth 64, 4,380 hours, 1 MiB** are resource/scope policies, not causality requirements. A causal 4,381-hour lag is refused; a legal composition can consume much more history than 4,380 hours. | Refusal and resource budget; frozen judged language. No claim that causality itself needs these limits is justified. |

## Coverage qualifications

- C7’s unspecified future certificate thresholds and C8/C9’s not-yet-frozen annex parameters are **blocked prerequisites**, not existing guessed numbers. I have not reported their absence as a failed derivation.
- Stage 6’s Lean tie-break and approved dollar spending caps are explicit preference/budget decisions, not empirical assumptions about correctness.
- Stage 3’s historical holdout/training margin is already withdrawn as edge evidence through its pipeline-validation label and forward-confirmation requirement. It should not be restored as a guarantee.
- Stages 0–3, 5 and 6 have judged evidence; stage 4 is running; stages 7–9 have no judged stage evidence according to `PROGRESS.md`. Stage 10 has judged implementation checks and an accruing, unfinished live window. **“Stage not exited” does not mean its evidence is untouched.**

## Numbers excluded because their derivations are visible

- **Reported \(B=1\):** absorbing bankruptcy gives return −1, then zero; `audit/criteria.md:242,700–703`, I10 and `L6_bounded`. This proves the reported floor, not the economic conditional null.
- **Pre-absorption −2 and bet cap 1/2:** together make every stopped betting factor nonnegative; Ville then supplies the p-value bound; `gate/NULLS.md:50–61`, `docs/whitepaper.tex:342–354`.
- **Corrected synthetic envelopes:** ε≤0.3, wick≤0.1 and κ≤0.003 jointly imply carrying loss below 0.46 and \(r'\ge-2\); `gate/NULLS.md:63–74`. Sufficient design bounds, not uniquely necessary choices.
- **Execution-cost combination \(s+f+sf\):** fee is charged on the adversely moved fill price; `reference/SEMANTICS.md:268–280`.
- **Four-hour pilot fill delay:** first recorded opening price provably after \(B+\delta\); `audit/criteria.md:87`, `docs/whitepaper.tex:192`.
- **q90 order statistic:** \(\lceil0.9n\rceil\)-th cost is the least constant attaining 90% empirical coverage; `audit/criteria.md:61`.
- **59/299 zero-promotion campaigns:** solve \(1-0.05^{1/n}\) for upper bounds below 5%/1%; `docs/whitepaper.tex:356–360`.
- **At most eight promotions in 300:** derived from the registered one-sided Clopper–Pearson upper bound; C2.4, `audit/criteria.md:267–269`.
- **C2.5’s approximately 0.078 FDP cutoff:** \(0.20-\sqrt{\log(20)/(2\cdot100)}\); `audit/criteria.md:270–272`.
- **C9 mixed-cell penalty:** \(\sqrt{\log(M/0.05)/(2n)}\) follows Hoeffding plus a union bound; `audit/criteria.md:1383–1385`.
- **Approximately 194/780 independent forecasts:** the paper’s stated normal-approximation sample-size formula for its specified hit-rate alternatives; `docs/whitepaper.tex:486–490`, not a derivation for 200 thesis clusters.
- **DSR’s revised reference scale:** qualified zero-Sharpe asymptotic scale and expected-maximum approximation; `audit/criteria.md:156–169`, not a derivation of the 0.95 selection cutoff.
- **Nominal 600/min and 480+120 split:** half the documented 1,200 weight/min limit; `ingest/hl.py:11–13`, `ingest/record.py:122–124`. Capacity at a boundary requires the separate workload calculation.
- **Thesis \(N=b/L\) and \(p_{\rm ref}=(x+1)/(m+2)\):** respectively nominal invalidation sizing and add-one/Beta(1,1) smoothing; `audit/criteria.md:768–770`, `thesis/SCORING.md:50`. Neither derives the chosen risk percentages or ten-window eligibility floor.
