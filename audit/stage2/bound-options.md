# The holdout's loss bound B: options for the human's decision

Prepared 2026-10-28 for the human; GPT's review is appended below when it returns. Numbers marked *development* come
from the first round's 3,400 campaigns (`ops/screen_preview.py holdouts | truths | bounds`; `bound-options.json`):
never evidence, and none of these campaigns is judged.

## Why C2.6 fails

The holdout test bets λ_t ≤ 1/(2B) on each per-step return, valid when r_t ≥ −B; today B = 1 (I10: losses capped at
equity). Wealth then grows at most about half the per-step mean, so p ≤ 0.05 needs a mean near ln 20 / (n/2): about
0.11% per 4h step on N2-long's 5,400 holdout steps, 0.55% on the Sharpe cells' 1,080. The searchers' strategies are
small (0.02 to 0.1 per coin), so even a strong found edge has a tiny mean: c25-N2-long-0's best finalist made +381% over
the holdout at a per-step Sharpe near 0.24, yet scored p = 0.46. The preview (`screen-preview.json`) and round r2 agree:
the revised screen passes the planted edges; the holdout promotes almost none.

## What a smaller B can rest on

No per-step bound below equity follows from prices: a perpetual's price can gap arbitrarily far between observations,
and the venue's certified rules carry no price band. A smaller B needs a rule that caps the account's loss:

- the venue absorbing losses beyond a margin, as I10 already does at equity (Hyperliquid's isolated margin is this rule
  per position); or
- a modelled stop that fills at its threshold.

Either rule hands the strategy a free option under a true null (losses truncated, gains not), worth most to strategies
that win often and lose rarely. So each option's null false-discovery rate is measured, not assumed.

## Options

| | B, and how the kernel enforces it |
|---|---|
| O0 | B = 1 (today). |
| O1(B) | I10 generalized: a step whose equity falls to (1 − B) of the previous step's liquidates every position at its bar's adverse extreme, the venue absorbs the loss beyond B, and the account trades on with the rest: isolated margin worth B of equity. Realizable on the venue only while the required margin, Σ\|w_c\| / maxLeverage_c, is at most B, so the kernel scales a portfolio down to that, as it scales gross to 2 today. With this venue's leverage (3x to 40x): B = 0.2 fits every searcher size, 0.1 up to 0.05 per coin, 0.05 only 0.02, 0.02 none. |
| O2 | A kernel stop: positions close when the step's loss reaches B at the bar extremes, filled at the threshold. A modelled fill, not a venue rule (gaps are ignored); its trigger on the extreme makes stop-outs more frequent than O1's, so the floors below overstate its power. Not priced exactly; more kernel and model surface than O1. |
| O3 | B = 1, the searchers sized ten times larger (0.2 to 1 per coin; the kernel's gross cap binds above 2). No kernel change; it changes the frozen searchers. |
| Q | Stage 2 exits on round r2 with C2.6's failure as a recorded qualification (as stage 0 did with C0.7); the loss bound moves into stage 7's kernel rewrite and law set. |

Floors at −B price O1 exactly: its step return is max(r, −B), with the cut absorbed. *Development*, per cell (100
markets each; N2-long's finalist-bearing campaigns), the gate's frozen family rule:

| Option | Null: promoted of 900 (rate) | Null steps the floor cut | N2-long | N2-s1 | N2-s2 | N2-s3 | N3-s1 | N3-s2 | N3-s3 |
|---|---|---|---|---|---|---|---|---|---|
| O0 (B = 1) | 0 (0.00%) | 0.000% | 0.05 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| O1, B = 0.2 | 0 (0.00%) | 0.000% | 0.60 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| O1, B = 0.1 | 0 (0.00%) | 0.004% | 0.60 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| O1, B = 0.05 | 1 (0.11%) | 0.042% | 0.63 | 0.00 | 0.01 | 0.16 | 0.00 | 0.00 | 0.02 |
| O1, B = 0.02 | 13 (1.44%) | 0.313% | 0.61 | 0.00 | 0.04 | 0.45 | 0.00 | 0.04 | 0.16 |
| O3 (B = 1, 10x sizes) | 0 (0.00%) | 0.000% | 0.17 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |

Each cell gives power: the share of its 100 markets whose first promotion is true. Campaigns without finalists count
as 0. The same campaigns' first promotions judged false, per 100 markets: N2-long 0.31 (B = 0.2), 0.34 (0.1), 0.31
(0.05), 0.33 (0.02), 0.09 (O3), 0.01 (B = 1); every Sharpe cell at most 0.02. A first promotion is false when its mean over
5 fresh ten-year markets is not positive with a 99% interval, a strict test that calls a weak but real edge false.
**Calibration (`bound-recheck.jsonl`):** all 31 of N2-long's first promotions judged false at B = 0.2 are true on C2.5's
full 20 markets. The 5-market test's false share is its own strictness, so N2-long's power at B = 0.2 is 0.91 (every
promoting campaign), and the other bounds' N2-long figures understate it likewise; nothing points to false
discoveries in the mixed cells.

The null column is the share of 900 null campaigns (every third of round 1's 2,700) whose in-sample best strategy is
promoted on its own holdout under the option: a test-level false-rejection rate, the free option's effect included (the
binding column is how often the floor cut a null step). Under the gate the pipeline rate is lower still: no null campaign
of round 1 or round 2 produced a finalist. Power and FDR use C2.5's truth on 5 fresh ten-year markets instead of 20,
for the program each campaign promotes first.

## What O1 costs, and what round r3 strictly needs

| Work | Needed for r3 | Estimate |
|---|---|---|
| Rust: I10's threshold at (1 − B), the account continuing after a capped step, the margin feasibility cap, R_BOUND at −B | yes | 3 h |
| The Lean reference implementation (`reference/lean/Ref/Sim.lean`) to match | yes | 3 h |
| C6.4's corpus differential: a capped-loss edge market beside `liquidation` and `ruin`, a new frozen corpus, the run | yes | 3 h (2 h of it compute) |
| Mutants: I10's, at the new threshold | yes | 0.5 h |
| INVARIANTS I10, SEMANTICS, the gate's B, calibration v3's scope revision, the paper, NULLS | yes | 1.5 h |
| Gates as test 7: reproduction of recorded campaigns where the cap never binds; cross-machine on the cluster | yes | 1.5 h |
| Proofs: `ret_bounded`, `step_bounded` (`Proof/Bound.lean`, 54 lines), `L6_bounded`; stage 7's law L6 later | see below | 3 to 6 h; up to a day if the continuation case resists |
| Round r3 on the cluster (2,700 null, 700 mixed) | | 2 to 2.5 h |
| r3's truth checks (C2.5's 20 markets for every promotion) | | 1 to 3 h on the cluster: power makes promotions numerous |

So about a day of work, then about 5 hours of cluster time.

**Do the proofs gate r3?** C2.1 to C2.6 name no proof. But the frozen scope assumption that set B = 1 (calibration v3)
says the bound's kernel change "is stated as a Lean law and proved in the reference model" before any judged run records
the kernel hash. So, as written, the proofs come first. Running r3 while they are finished, with stage 3's freeze
waiting on them and r3 discarded if a proof fails or exposes a bug, needs a labelled revision of that sentence: the
human's call. It saves the proof time (3 h to a day) off the critical path.

## Option Q, honestly

- **Saves:** the day of kernel work, r3 and its judging now (about 1.5 to 2 days to stage 3), and doing the bound's proofs
  twice: stage 7 generalizes the kernel and restates its law set, L6 included, anyway.
- **Stages 3 to 5 and 10 depend on holdout power nowhere:** stage 3 states its expected power "close to zero" and accepts
  zero promotions (C3.1 to C3.4); stage 4 has no real holdout and its null series is a validity test (at most 1
  promotion); stage 5 has no holdout criterion; stage 10's skill claim rests on resolved forecast clusters.
- **Costs:** C2.6's purpose, showing the pipeline can detect an edge the holdout supports, stays unshown until stage 7.
  Until then a zero-promotion result in stages 3 to 5 cannot be told from blindness, so it says nothing about the pipeline's
  sensitivity. Stage 3's real campaign (1,080 holdout steps) would be blind under O1 too for realistic edges (the Sharpe
  cells promote nothing above B = 0.05), so Q costs least there.

## Recommendation

**Q, with O1 at B = 0.2 specified now for stage 7.** Reasons, from the table:

- **No option rescues C2.6 as written.** Its cell, N2-s3, has 1,080 holdout steps; power appears only at B = 0.05
  (0.16) and B = 0.02 (0.45). Every round r3 therefore still needs a waiver of C2.6 as written, so r3 buys only the
  amended long-cell criterion, at about a day of kernel work, five hours of cluster time and the proofs.
- **Small B is where the free option starts.** The null false-rejection rate is 0 down to B = 0.1, 0.11% at 0.05 and
  1.44% at 0.02, rising as the floor cuts more null steps (0.04%, then 0.31%). And the venue's isolated margin cannot
  carry the searchers' sizes there (B = 0.05 fits only 0.02 per coin, 0.02 fits none), so realizing it would shrink the
  strategies and the power the table shows.
- **Stage 3 stays blind under any safe option.** Its real campaign has a 1,080-step holdout, where B = 0.2 or 0.1
  promotes nothing in any Sharpe cell. Q costs stage 3 nothing it would otherwise have.
- **B = 0.2 is the right bound for long holdouts.** It is venue-realizable at every searcher size, the floor never cut
  a null step, no null campaign's best was promoted, and the long-holdout cell's power rises from 0.05 to 0.91. Stages
  7 to 9 bring the long histories it needs, and stage 7 rewrites the kernel and restates its law set (L6 among them)
  anyway, so the bound's proofs are done once.

Q's record: C2.6 failed as written and as amended under B = 1, on both rounds; the pipeline's detection at a long
holdout is shown in development only (B = 0.2: power 0.91, null 0 of 900), not as judged evidence; the bound is
specified as O1 at B = 0.2 and lands with stage 7's kernel and laws, judged there. Under Q there is no round r3.

## Round r3's plan (ready to submit once the human decides and the work above lands)

Fresh ids under round tag r3 (`gate/sweep.py` ROUND), the same 2,700 null and 700 mixed specs and C2.5's betas,
submitted as two Indexed Jobs (`python ops/jobs.py submit r3-null null <digest>` and `r3-mixed mixed <digest>`) on all
four nodes, the image rebuilt from the decided commit and pinned by digest, `mm` staged by hash, its plan record written
before any pod starts; collection, truth (in a memory-sized pool), `probes-top5` and `sweep-summary` as in r2. Under Q
there is no r3.
