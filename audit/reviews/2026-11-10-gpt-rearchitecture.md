# Adversarial review of the rearchitecture by GPT (gpt-6.1-sol, high), 2026-11-10

Reviewer: GPT through opencode, the one review the human unpaused it for (2026-11-10). It ran locally from a clean, detached worktree of `rearchitecture` at `51fd365` (`../mm-gpt-review`, no `data/`, no tokens).
- **Prompt:** `data/builder/gpt-review-prompt.txt`. GPT was asked to break the architecture as Fable's adversarial reviewer, and to dispose of each of Argon's 14 paper findings (`2026-11-10-argon-web-paper-math.md`), which Fable had not seen.
- **Tools:** its web searches were cancelled; it fetched official pages directly.
- **Run:** finished 2026-11-10 at about 22:58 UTC (17:58 EST). The file `GPT-REVIEW.md` it wrote is reproduced below verbatim.

The advisor verified finding 9's terms claim against https://polymarket.com/tos ("Effective as of August 11, 2026"). Section 4.2 prohibits using "data mining tools, robots, crawlers, or similar data gathering and extraction tools to scrape" and to "harvest or otherwise collect information … for any unauthorized purpose".

---

# Adversarial review of the rearchitecture

**Verdict: do not approve this architecture as a statistically specified program yet.** The positive-control ordering and removal of unused platform work are sensible, and the SPRT arithmetic is correct. But Study 2's admission rules permit a no-skill portfolio to pass with probability over 40%, even with every entry at 0.50; “simulate the worst admissible null” cannot supply the promised usable critical values without additional assumptions. Study 1 also confuses rejecting a 0.20 discovery rate with establishing a 0.50 rate. Argon's cap correction separates a genuine information constraint from a much worse, avoidable gate constraint. Together with unproved throughput and invalid negative-result interpretations, these defects mean the proposed studies cannot support the program's advertised abandonment decision.

Reviewed checkout `51fd365`, all requested documents, the specified paper diff, and Argon's 14 findings from `main`. Ran the arithmetic and an independent rational-probability SPRT enumeration. No protected data, campaigns, models, or remote machines were accessed. Only this review was edited.

## Ranked findings

### 1. Critical — A balanced-price null defeats the proposed Student protocol

**Where:** `audit/program/architecture.md` §§2.4, 5.2, 5.5: “Dependence … cannot invalidate the test”; “each look's critical value is set by simulation at the worst null the admission rules allow.” Also `criteria-notes.md`, Stage 10, and paper §10/T4.

**Construction:** Each week buy one share in each of 60 distinct events, all at 0.50. With probability 30/31, exactly 31 randomly selected events pay 1; otherwise all pay 0. Each individual event has probability `(30/31)(31/60)=0.5`: there is no forecasting edge. Weekly gross profit is +1 or −30, with mean zero. Allocate event labels across categories to respect the caps; nothing in the rules forbids this common shock. All positions can resolve within the week, so even the proposed 28-day cap is satisfied.

With no catastrophic week the Student statistic is infinite. This happens with probability `(30/31)^26=0.4263` and `(30/31)^52=0.1818`, not 1% and 4%. Deterministic aggregate fees below $1/week leave the common outcome positive and make the null mean *negative*. Small perturbations give arbitrarily large finite statistics instead of division by zero. A price band including 0.50 does nothing; category labels do not bound cross-category dependence.

**Outcome:** false edge claims. The quoted favorites simulations reproduce, but their independent-binomial family is not least favorable. The size surface is not even monotone in their price parameter. A genuinely worst-case critical value may be infinite, destroying power against steady positive profits. Bonferroni handles dependence **between looks**, not invalid individual looks. Martingale differences alone do not give Student finite-sample validity. Also, rejecting “every conditional weekly mean ≤0” does not establish a positive window-average expectation: it negates a stronger null. The judged claim and null must match.

### 2. Critical — Missing marks and quote fills can manufacture the judged result

**Where:** `architecture.md` §§5.5–5.6: “A missing mark carries the last one forward, which moves return between weeks and never changes the total”; an operational patch “may change which bytes exist.”

**Construction:** A portfolio gains $1 in each of 25 weeks, then loses $25 in week 26. Recording that last mark gives mean zero; missing it and carrying the old bid gives an overwhelmingly positive statistic at the stopping look. Receiving the correction in week 27 preserves the eventual total but not the rejection. “Never obtained loses its stake” needs a fixed valuation deadline, including at both looks; “never” is not an observable stopping time.

Separately, suppose Gamma reports an ask of 0.50 that is stale or has one share behind it. Paper-buying 100 shares before a known payout produces $50, although only $0.50 of gross profit was available. A three-hourly witness and a later-quote replay cannot establish contemporaneous executability.

**Outcome:** false paper-edge judgments or a skilled procedure failing because winning resolutions were not acquired. A deterministic scorer can faithfully reproduce selectively missing bytes. Score equality on the *same* record proves neither acquisition invariance nor preservation of the scientific treatment. Freeze the missingness/terminal valuation policy and the acquisition behavior that can change judged observations. Depth and freshness are needed before interpreting rejection as a retail candidate, not merely a scaling qualification.

### 3. High — “Exact capture” is not the claimed expected net return

**Where:** `architecture.md` §6: “the plant's expected gross return … is the plant's strength times the sum of position times signal”; `briefs/1-positive-control.md` question 1: “positive expected net return, using the trace's realized fees, slippage and funding.”

**Construction:** `gate/markets.py:213` clips *after* adding the plant. For signal 1, strength 0.50, volatility 0.02, and N2 with loading zero, the actual standardized truncated-t5 innovation gives

`E[clip(0.50 + 0.02 X, −0.50, 0.50)] = 0.49256435`,

not 0.50. I integrated the code's truncated distribution. The discrepancy depends on signal and volatility, so it is not generally canceled by dividing by reference capture. Liquidation adds outcome-dependent losses; realized funding and costs on an adaptively generated position path are not their population expectations. A trace is an exact accounting record, not an expectation operator.

`Decision.qty` is an order delta, not the held quantity; rejected/unfilled orders and liquidation require reconstructing holdings from fills. Scaling also cannot preserve executable behavior across the $10 minimum, quantity rounding, margin admission, and cost cells.

**Outcome:** changed discovery labels, baseline calibration, and SPRT decisions. The brief recognizes these issues but has not solved them; they are a pre-Study-1 mathematical prerequisite, not implementation detail. Distinguish a pathwise alignment definition from a proved positive-expected-net-return definition. A zero-plant check using actual strength zero and positive costs would be tautologically negative; score a precisely specified counterfactual plant instead, at the **session-any-evaluation** level. A 1% per-evaluation chance becomes `1−0.99^100=63.4%` per session. Zero discoveries require 299 independent markets for a one-sided 95% upper bound below 1%.

### 4. High — The SPRT establishes neither advertised endpoint

**Where:** `architecture.md` §§4, 6, 8: “discovers it in at least half”; “accepts 0.2 … searches no better than G100”; “found absent.”

Independent enumeration using exact likelihood ratios `(5/2)^s(5/8)^(n−s)`, boundaries 19 and 1/19, maximum 33, terminal cutoff 12, gives:

| True discovery rate | Probability of upper decision | Expected markets |
|---|---:|---:|
| 0.10 | 0.001071 | 9.958 |
| 0.20 | 0.041095 | 15.263 |
| 0.30 | 0.301421 | 19.927 |
| 0.35 | 0.519466 | 20.017 |
| 0.50 | 0.948579 | 13.333 |
| 0.60 | 0.994851 | 9.198 |

The terminal rule makes Type II error **5.1421%**, so “both error rates 5%” is not literally met despite the correct rounded power.

**Counterexamples:** At 0.35, the agent is declared “0.5” 52% of the time although “at least half” is false. At 0.30 versus a 0.20 baseline, a genuinely superior agent receives the lower decision 69.9% of the time. These are the test's indifference region, not errors controlled at 5%.

**Outcome:** false capability and abandonment statements. The valid upper conclusion is evidence against a rate ≤0.20, with power stated at 0.50. The lower conclusion is failure to meet the target alternative, not equality to the baseline. Counting crashes is sound intention-to-treat accounting, but then the estimand includes operational reliability. “Discovery by evaluation” can also reward an agent that evaluates a memorized reference and discards it; it does not demonstrate selection or deployment skill. Those narrower claims are acceptable if named honestly.

### 5. High — Baseline calibration does not turn a policy choice into a known null

**Where:** `architecture.md` §6: “discovers in a fifth … 95% upper bound … at most 0.2”; `briefs/1-positive-control.md` question 3: “largest grid value whose 95% upper bound … is at most 0.2.”

**Construction:** At 200/1,000 discoveries the one-sided exact upper bound is 0.22195, not 0.20. To certify ≤0.20 requires at most 178/1,000. Thus “in a fifth” and “upper bound ≤a fifth” are different requirements. Selecting a strength using pointwise intervals also invalidates their advertised post-selection coverage. For example, 1,000 independent candidate calibrations each with true rate 0.21 produce at least one falsely qualifying cell with probability 0.99846; an equally capable agent at 0.21 then gets the upper SPRT decision with probability 0.05354. The brief puts no bound on this selection search.

**Outcome:** an unsupported agent-versus-baseline error guarantee. Use independently validated selection or simultaneous coverage and explicitly allocate calibration uncertainty. Even a single 95% certificate plus a 4.11% test yields only a crude 9.11% union-bound guarantee, not the advertised 5%. A certified rate ≤0.20 is not equality to 0.20; comparison with the actual baseline remains unjudged. Choosing 0.20 as useful difficulty is still a utility choice. Moreover, with a scale-invariant alignment threshold, discovery probability need not vary continuously or monotonically with plant strength: the proposed calibration point may not exist.

### 6. High — The wall incorrectly identifies gate failure with an information limit

**Where:** paper §10: “The second fact is arithmetic, not a defect of the gate”; `architecture.md` §2.2: “the gate's betting test needs about 4.9”; `arithmetic.py.txt:26–27`.

**Construction:** At per-step volatility 0.02 and annual Sharpe 4.9, the unconstrained Kelly fraction is about 5.24, but the gate allows at most 0.5. Its saturated second-order expected log wealth over 546 steps is about 0.544, versus `log(20)=2.996`. Solving the capped equation gives Sharpe approximately **26**, consistent with the advisor's 25.9, not 4.9. Analogous capped log-drift thresholds are approximately 39.3, 13.2, and 2.83 at 360, 1,080, and 5,400 steps. These are not 80%-power calculations; the plug-in and boundary crossing require their own analysis.

**Outcome:** false explanation of C2.6 and unsupported claim that the systematic line “lacks only a confirmer.” A positive discovery control does not repair this gate. The *Gaussian fixed-horizon* yardstick—Sharpe 4.98 for 80% power over 91 days—survives. It is neither a distribution-free impossibility theorem nor evidence that every valid test differs only by “tens of percent.” Keep the calendar constraint; erase the identification of this gate with an efficient test. Older-model numbers 1.7–2.2 likewise describe the Gaussian yardstick, not this gate.

### 7. High — Counts, weighting, and capital do not establish the claimed information rate

**Where:** `architecture.md` §§3G, 5.2–5.3, 8: “Distinct events are close to independent by construction”; “roughly 180 open stakes”; “realized breadth … under half the admitted count.”

**Construction:** Sixty new positions/week held 28 days imply approximately **240**, not 180, concurrent stakes. At 0.5% initial equity each, they require 120% before fees. A hard cash constraint will reduce admissions or alter sizing, invalidating the power scenario. Disputed resolutions extend this further.

With fixed dollars staked, a fair contract's return variance is `(1−a)/a`: 0.25 at price 0.80, but 4 at 0.20. Twenty independent 0.80 bets plus one 0.20 bet have variance 9, versus 5.25 for 21 favorites. Equal stakes do not give `d√m` for heterogeneous effects/variances. The stated “summed variances / portfolio variance” is **1 for independent unweighted contributions**, not their count (or `m²` if the denominator uses an equal-weight average). The proposed breadth report lacks a usable definition.

**Outcome:** underpowered freezes and invalid futility claims. Metadata counts of closed markets are only an upper bound: collapse ladders, repeated underlyings, common resolutions, and duplicate events; exclude already-known outcomes; then apply price, liquidity, category, and horizon rules. The existing top-500 active/latest-500-closed feeds are censored inventories, not a venue census. One shakedown week cannot estimate a return covariance matrix for mostly unresolved 28-day positions, nor cover seasonality. Neither 600 queries/day nor two-to-four sessions/day proves 60 *skilled* opportunities. No such count was established here; I fetched no market data.

### 8. High — Non-rejection is not evidence that reading or retail edge is absent

**Where:** `architecture.md` §§4, 8: “Reading agents of this generation do not beat event markets”; “both capabilities … found absent”; §5.1 cuts the no-reading arm.

**Skilled failure:** For genuine net effect `d=0.02`, even 60 independent homogeneous bets/week give only approximately **25.8%** power at the final 4% Student look, before futility. A run of modestly skilled agents therefore usually “fails.” Restricting the price band can exclude its only profitable favorites; imposing throughput can dilute a sparse edge with bad bets.

**Unattributed success:** A no-reading rule buying a known risk premium with `q=0.55`, ask 0.50 earns 10% gross on stakes, even if reading adds nothing. This supports procedure-level profitability, not reading capability. A delayed no-reading instance runs in a different market regime and cannot retrospectively attribute the first instance's gains.

**Outcome:** abandonment despite real skill, or a false reading-capability claim. Dropping paired Brier is defensible for Q3, but then Q2 is not answered. Report confidence bounds against an economically chosen minimum edge, not “absent.” Futility at zero is conservative for false positives, not proof of ineffectiveness. Repeated new-model/instance tests also need lifetime error accounting: twenty independent 5% null reruns have a 64% chance of at least one rejection.

### 9. High — Venue portability and the certificate premise need reconsideration now

**Where:** `architecture.md` §§3G, 11: Kalshi status is a “lead”; order-book access may be replaced by “top-of-book fills with a stated qualification”; `venue/sources.toml` `[polymarket]`: “no API terms were found.”

**Construction/facts:** The current international [Polymarket terms](https://polymarket.com/tos), effective August 11, 2026, expressly cover API access and forbid automated scraping/data extraction. They continue to exclude US persons from trading. The [CFTC directory](https://www.cftc.gov/IndustryOversight/IndustryFilings/TradingOrganizations?Status=Designated&Show_All=1) separately lists **QCX LLC d/b/a Polymarket US**, designated July 9, 2025, and **Kalshi**, designated November 3, 2020. Thus “Polymarket” is not one execution venue. The international Gamma record does not establish fills, inventory, fees, or eligibility on either US venue.

**Outcome:** an untradeable “candidate,” or collection outside the certificate's evaluated premises. The human must revisit that certificate; I made no venue-data requests. Kalshi's [signup requirements](https://help.kalshi.com/en/articles/13823778-signing-up-as-an-individual) confirm adult, verified individual accounts, subject to approval and legal eligibility—not blanket permission for every US resident and contract. Study 2 needs an explicit portability limitation or the intended executable venue from the start.

### 10. Medium — “The market price” is not an exact comparator or a net edge

**Where:** `architecture.md` §§2.3, 3G, 5.1: “comparator is free and exact”; “three-point net edge … d=0.06”; Brier effect “at most `2|e|`.”

**Construction:** With true probability 0.53, bid 0.48 and ask 0.52, a perfect forecast improves expected Brier score over midpoint 0.50 by 0.0009. But an economics taker fee of `0.05×0.52×0.48=0.01248` per share makes its expected profit **−0.00248/share**. Forecast skill and net trading edge diverge. Current official documentation says displayed prices use midpoint, or last trade when spread exceeds $0.10; neither is an exact crowd probability.

For the Brier derivation, at `q=0.01`, ablation 0.06 and accurate main forecast 0.01, `|e|=0.05` gives standardized paired improvement **0.2513**, not ≤0.10: about 98 Gaussian-approximation pairs, not 618–2,473. The claimed cap implicitly requires `q≈0.5` and should not be generalized.

**Outcome:** wrong power/exclusion arguments and misleading diagnostics. Fees must be included before defining `d`; the coin-flip replay has no universally negative conditional return without an efficient-price assumption—it is not an accounting oracle. Longshots additionally dominate variance; favorites hide losses. Neither is addressed merely by reporting Brier scores.

### 11. Medium — Forward registration must mean unknown outcome, not pending settlement

**Where:** `briefs/2-thesis-track.md`, question 9: “The forward design makes its cutoff irrelevant to validity”; `architecture.md` §3G calls resolution exact.

**Construction:** A contract concerns a 2025 result remembered by the June-2026-cutoff model, but remains discoverable while settlement is pending. If admission treats the venue's pending status or an updated scheduled end as evidence of an unknown outcome, a forecast of 1 against a stale 0.50 quote gets Brier 0 and paper profit 100%. It tests recall and the quote adapter, not foresight. Official market documentation distinguishes active, closed, and accepting-orders states; these are not knowledge-cutoff certificates.

**Outcome:** contaminated forecasting claims, potentially combined with finding 2's fictitious fills. Require the substantive outcome to be unknown at actual registration, with no backdated catch-up forecasts or retrospective substitution. If such a known-fact quote really is executable, exploiting it is legitimate economic edge—not a statistical leak in Q3. Conversely, genuinely future unknown outcomes cannot already be memorized, so no blanket cutoff exclusion is needed for a properly enforced forward design. Pin an immutable model version if the result is attributed to one generation.

## Remaining numerical and public-fact checks

The script's `6.18/d²`, Gaussian track-length table, Holm-three constant 2.97, IC/breadth arithmetic, and information-rate table reproduce **conditional on their assumptions**. Their empirical inputs—15–40 or 100–400 independent monthly bets, residual correlation 0.05, usage, and reachable older models—remain estimates, not verified facts. A monthly-count table is not the power of the proposed weekly marked portfolio.

Even under independent Gaussian weeks, exact noncentral-t 80%-power effects at 60 bets/week are **0.08486** and **0.04712**, annual Sharpes **4.74** and **2.63**, versus the script's normal approximations 0.080/0.046 and 4.5/2.6. Any worst-null calibration and futility must enter the final power calculation. A3's effect cap is explicitly a prior; it cannot justify a universal 600–2,500-bet requirement.

Public sources checked directly; web search was unavailable:

- **Polymarket fees:** [official fee documentation](https://docs.polymarket.com/trading/fees) gives `C×rate×p(1−p)`, taker-only; rates 0.07 crypto, 0.04 finance/politics/tech, 0.05 economics/culture/weather, and zero geopolitics. At 0.50 these are 1.75, 1, and 1.25 cents/share. Freeze the rule for reading contemporaneous market-specific fee parameters, not a remembered venue-wide fee. [Resolution documentation](https://docs.polymarket.com/concepts/resolution.md) also permits 50/50 redemption and disputed outcomes; “exactly resolved” does not always mean binary or immediate.
- **Kalshi fees:** [official help](https://help.kalshi.com/trading/fees) confirms transaction fees, market-specific exceptions, and some maker fees. The fee-schedule and regulatory landing pages returned **429**; I did not circumvent them. The exact current coefficient/rounding schedule remains unverified here; do not promote a remembered formula to a frozen assumption.
- **Prophet Arena:** [paper v1, Table 2](https://arxiv.org/html/2510.17638v1#S3.T2) confirms GPT-5 Brier **0.184±0.006**, market **0.187±0.006**, gross payout ratio **0.943±0.042** on 1,367 events/72,136 markets. The quoted values are correct, but 0.943 is not a demonstrated net tradable return; its simple rule buys every supplied market. It does not establish the supply of selective independent opportunities.
- **ForecastBench:** [original paper v1, Table 2](https://arxiv.org/html/2409.19839v1#S5.T2) reports superforecaster aggregate **0.093**, public **0.107**, best displayed LLM **0.111**, paired p=0.01 against superforecasters. It uses 1,000 questions, a 200-question human subset, multiple horizons, and crowd proxies for unresolved questions. That supports the historical comparison, not today's frontier parity or thousands of resolved independent tradable bets. I did not inspect a current leaderboard.

## Argon's 14 findings: architectural disposition

1. **Changes the wall's gate numbers and C2.6 explanation:** approximately 26, not 4.9, under the stated cap/volatility; Gaussian track lengths survive.
2. **Must be addressed before Study 1's capture claim:** absorption/liquidation semantics matter. Bankrupt running-maximum promotion is moot to its discovery-only judgment; a running maximum alone is not a Type-I-error defect under valid supermartingale assumptions.
3. **Moot to the active judged tests:** neither judges the old pre-absorption betting bound. E1/E2's chronological-settlement discrepancy blocks a revived gate; Study 1 must specify its actual simulator's capture semantics.
4. **Changes historical calibration wording:** redesigned/optionally stopped versions do not certify one current procedure. Zero-evaluation crashes are not automatically invalid intention-to-treat observations; Argon's proposed exclusion is not universally justified.
5. **Moot to discovery-only judgment:** no mechanism filter is judged. Its selection-conditioned check cannot be called independent mechanism evidence.
6. **Changes interpretation, not the FDR definition:** FDR and positive FDR differ; 5% promotion of entirely false discoveries can satisfy unconditional FDR. C9 is superseded; “promotions are reliable” does not follow.
7. **Moot to judged discovery:** DSR is not its endpoint. Raw-N dominance makes the sensitivity maximum redundant; Argon's infinite-Sharpe limit alone does not prove its asserted global supremum.
8. **Changes N2's description, not automatically its validity:** mixtures are not t5. Actual `gate/markets.py` truncates innovations and caps variance, so the infinite-fourth-moment objection does not apply to the implemented generator.
9. **Changes gate-power motivation:** the capped rule has a finite jump, not an infinite output. Predictability preserves validity when the return bound/null hold; it does not preserve oracle power.
10. **Moot to active judged endpoints:** neither inherits the old betting suite as its statistical certificate. Its slack still cannot certify exact nominal size.
11. **Moot to discovery judgment:** SPA/StepM are not judged. Persistent funding alone does not prove persistent *null return means*, so Argon's factor 8.5 is a scenario, not a demonstrated defect here.
12. **Moot for these two public/synthetic studies; must be fixed before kernel-only disclosures:** minimum cell counts do not block three-query reconstruction. Superseding stage 8 does not dissolve the retained licensing boundary.
13. **Changes paper Table 1:** Gaussian expected maximum at N=10 is 1.5388, not 2.146; does not change `6.18/d²` or the SPRT.
14. **Changes assurance before Study 1:** an S=2 leak escapes the single-run S=4 alarm about 99.3% of the time. Trace-level timing/capture checks are needed; the old canary is no no-leak certificate.

**Program consequence:** keep the recording, isolation, and discovery-control idea; keep unused Lean/platform expansion parked. Do not park mathematical capture correctness, scientific acquisition semantics, executable venue feasibility, or a genuinely calibrated inferential protocol. The program can test narrow synthetic discovery and one frozen procedure's forward performance. It cannot yet test “reading absent,” rule out sparse retail edges, or turn a null result into the proposed verdict on an entire model generation.
