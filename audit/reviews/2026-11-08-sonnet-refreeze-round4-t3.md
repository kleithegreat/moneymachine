# Review: whitepaper appendix T3 timing derivation (refreeze round four)

- Reviewer: Claude Sonnet 5.5, **Claude-only; Argon queued** (stands in for an Argon mathematical review that is out of quota).
- Date: 2026-11-08 17:57 UTC (12:57 EST).
- Reviewed: `docs/whitepaper.tex` appendix T3 (`app:thesis-policy`, "Cold acquisition", "Steady state", "Daily snapshot and proposed completion bound", the draft-revision paragraph); `audit/stage10/criteria-revision-draft.md`; `thesis/market.py`, `thesis/runner.py`, `ingest/hl.py` (`WeightLimit`), `thesis/tests/test_snapshot_schedule.py`, `thesis/tests/test_refreeze_round4.py`. Worktree `/home/kevin/repos/mm-agy-rf` at 1160c7b, nothing edited. No `data/` read; no network call; the venue was a fake `httpx` stub.
- Scripts (rename `.py.txt` to `.py`; `adv.py` and `retry.py` import `sim.py`; `plan.py`, `fund.py` run under `nix develop -c python`): folder `2026-11-08-sonnet-refreeze-round4-t3/`.

## Verdict

**Correct with fixes.** Every count and weight reproduces. The 701-minute waiting bound and the 65,631 s completion bound are valid upper bounds under their stated conditions, and the 19:00 start follows from them. Three fixes are wording or slack, none changes a number that decides the schedule:

1. The "no-additional-hole" daily funding allowance has 62% of its weight unexplained.
2. The bound uses 19 mark intervals where 18 suffice (7 slack minutes).
3. The completion bound is a worst-case ceiling that is 4-7 times the plausible completion time. The paper presents it as the basis for the start time without saying so. Item 3 below treats the consequence.

## 1. Counts and weights (all reproduced)

| Claim | Arithmetic | Status |
|---|---|---|
| 524 x 21 = 11,004; 91.7 min; 105 batches | 348 + 176 = 524; 524 x 21 = 11,004; /120 = 91.7; 5 x 21 = 105 <= 120 < 6 x 21, so 524/5 = 104.8, 105 | correct |
| Warm envelope Q | 7 + 278 + 2(348) + 3(176) = 7 + 278 + 696 + 528 = 1,509 | correct |
| Warm envelope W | 140 + 278 x 39 + 348 x 42 + 176 x 142 = 140 + 10,842 + 14,616 + 24,992 = 50,590 | correct |
| Per-block weights | daily 39 + 21 + 21 = 81 (39 = 20 + ceil(1,126/60) = 20 + 19); hourly 100 + 21 + 21 = 142 (100 = 20 + 4,800/60) | correct |
| What dominates W | hourly blocks 24,992 (49.4%), daily tails and terminals 14,616 (28.9%), daily prefixes 10,842 (21.4%), metadata 140 (0.3%) | the hourly core blocks dominate |
| Cold candle | 348(39 + 21) + 176(100 + 21) + 140 = 20,880 + 21,296 + 140 = 42,316; 2 x 524 + 7 = 1,055 calls | correct |
| Cold funding, one market | 54 x 45 + 21 = 2,451 (planner run: 55 calls, 2,451 weight, 26.0 min at 0.3 s latency, `fund.py`) | correct |
| Inventory bound | 348 x 55 = 19,140; x 45 = 861,300; /2 per minute = 9,570 min = 159.5 h = 6.65 d; x 6 attempts = 5,167,800 | correct |
| Daily upkeep | 348 x 22 + 278 x 45 = 7,656 + 12,510 = 20,166; /1,440 = 14.00 per minute | arithmetic correct, derivation flagged (fix 1) |
| Discovery | 20(d + 2) = 140 at d = 5; x 96 = 13,440; /1,440 = 9.33; sum 23.34 per minute | correct |
| Hourly mark interval | H - 55 s to H + 300 s = 355 s, + 60 s = 415 s, rounded to 7 min | matches `MarkLimit.delay` (`HOUR - MARK_PREP`, `MARK_WINDOW - MARK_OFFSET`) |

**What the planner does, run on the real `Market`/`Exchange` code against a fake venue** (`plan.py`: 5 dexes, 176 + 40 core and 102 + 30 builder live listings, caches warm as of the previous cutoff, 0.3 s per request):

| Case | Calls | Weight | Completion, no marks | Reading |
|---|---|---|---|---|
| Typical: 70 of 278 eligible old, the rest 90-1,100 days | 644 | 16,666 | 154 min (2.57 h) | prefix probes (39) and tails (21) |
| Worst-prefix: every core eligible market younger than 200 days | 767 | 25,107 | 241 min (4.02 h) | hourly prefix probes added |
| Typical, venue omits the unclosed candle | 1,168 | 27,670 | 256 min (4.27 h) | every tail needs a terminal empty request |
| Worst-prefix, venue omits the unclosed candle | 1,291 | 36,111 | 343 min (5.72 h) | the largest case I could construct |

Both are inside the 1,509 / 50,590 envelope, so the envelope is a true upper envelope for the no-interior-hole case. When the venue returns the unclosed candle (the paper's own reservation assumption), the planner sends **no** terminal empty request at the 00:05 cutoff. The tail answer includes the open candle at t = D, so the next start equals D + step >= end and the loop stops. Terminal empties appear only if the venue omits the unclosed candle. The paper's phrase "uses `Info.candles`, which asks again after the last returned candle when the requested end has not been reached" is exact, but it should say the terminal request exists only in that case. Whether the venue returns the open candle is an unverified venue behaviour (the paper already calls pagination anchoring a code assumption). It moves the typical completion from about 2.6 h to about 4.3 h.

Prefix count 278: the 278 daily prefixes are the listings younger than the 1,125-day scope (348 live - 70 with full scope), whether eligible or not. Ineligible young listings (under 90 bars) also probe, since their cache starts after the scope start. The paper reaches 278 by the coincidence 278 = eligible. If the inventory's "70 full scope" were not the same set as the 70 non-eligible, the count could reach 348, and W rises by at most 70 x 39 = 2,730. The paper should justify 278 as "listings younger than the daily scope".

### Errors and fixes

**Fix 1 (location: "Steady state", daily funding allowance).** Labelled "no-additional-hole" yet 12,510 of 20,166 (62%) is 278 x 45, a full-page repair per eligible market per day. Nothing in the code does that on a hole-free day. `fund.py` runs the real `Market.prewarm` on a hole-free warm market: after midnight there is exactly one call of 22 weight and none in the following 15-minute passes. The hole-free daily upkeep is 348 x 22 = 7,656, i.e. 5.32 per minute, and the 45 is an allowance for one extra page per eligible market. Either label it an allowance with its reason, or drop it. The combined 23.34 per minute becomes 5.32 + 9.33 = 14.65 per minute on a hole-free day. It is background work, held during snapshots, so it does not enter the completion bound.

**Fix 2 (location: completion bound, "With 19 such intervals").** The marks inside (00:05, 00:05 + C] are those at H = 01:00, ..., 18:00, which makes 18. The 19:00 interval opens at 18:59:05, after 18:18:51. The 00:00 mark's residual is the separate "pre-existing history debt" minute. Using 19 is a 7-minute slack (possibly deliberate against circularity). With 18, C = 65,631 - 420 = 65,211 s = 18:06:51; cutoff + C = 18:11:51. The 19:00 start is unchanged. Recommend stating that 19 is slack rather than a count.

**Not errors, but state them.** (a) `lexical` in "the maximal-weight lexical example" is a per-market interleaving (daily block, then hourly for the first 176 markets), not code order; it is the worst ordering I found (below). (b) "Mark interference" is added in full per hour, while the real interference is the drain from H - 55 s to the early `release()` (typically about 70 s) plus up to 60 s of expiry. (c) The 10 s x 1,514 term (15,140 s, 23% of C) is a per-attempt service allowance with no bearing on the typical request, which took 0.3 s in my model.

## 2. The completion bound

### The 701-minute waiting bound is valid and order independent

The argument: every request is admitted within 60 s of the previous admission (all earlier reservations expire in 60 s and each weight <= 120), and a block whose total fits 120 is admitted together inside one fresh window. Blocks are sequential in code (`Track.snapshot` runs one thread, lists, then per market the daily block and the hourly block), so the argument applies. A block of 81 takes at most one minute, a block of 142 at most two (100 + 21 > 120 forces one wait, in any internal order), and the seven 20-weight metadata requests take one more (the seventh waits for the first). Total 348 x 1 + 176 x 2 + 1 = 701. Latency only shortens waits (a later next request meets older windows), so adding latency is conservative.

Checked by simulating the exact `WeightLimit` semantic (`sim.py`, `adv.py`; the simulator reproduces the repo test's 632 min on the paper's layout):

| Search | Maximum waiting found |
|---|---|
| Repo layout (interleaved) | 632 min |
| 300 random block orders | 591 |
| Hill-climb over block order and internal order, 3 seeds | 618, 619, 623 |
| Hand-built alternation of hourly and eligible daily blocks | 632 |
| 10 s latency after every request (adversarial order) | 619 min total, against bound 701 + 252 = 953 |

No ordering reached 701; the best is 632, so the waiting bound is valid and 11% loose, which is acceptable. The looseness comes from charging a full minute to each 42-weight no-prefix block and to each 81-weight block that could share a window with a neighbour.

### Retries

The bound says five extra attempts of at most 100 weight add at most five waiting minutes. `retry.py` hill-climbed the placement of five repeats (zero sleep, zero latency, repeat directly after the failed request) over 80 random orders: maximum extra **exactly 5.0 minutes**, never above. A retry of a 100 in a 142-block moves the following 21 to the next expiry, costing one minute, as the hand case 21, 21, 100, retry 100 confirms. It is an empirical result, not a proof, but I could not construct a retry that cost two minutes. The 31 s of back-off covers one six-attempt chain (1 + 2 + 4 + 8 + 16); five separate one-retry failures need only 5 s, so it is conservative. Sleep time overlaps window expiry, so adding it is conservative.

### Composition of C

(701 + 5 + 19 x 7 + 2) x 60 + 1,514 x 10 + 31 = 841 x 60 + 15,140 + 31 = 50,460 + 15,171 = **65,631 s = 18:13:51**. Cutoff + C = 18:18:51; the first whole hour is 19:00. All arithmetic is right. 1,514 = 1,509 + 5. Shares of C: waiting 64.1%, service allowance 23.1%, marks 12.2%, retries and debt 0.6%. No double counting: waiting excludes latency, the service allowance excludes waiting, and marks are a disjoint time interval. Omissions: none inside the stated conditions. The conditions exclude the Monday benchmark and resolutions, other consumers of the shared IP (the recorder's 480 and any 600/min script), more than 5 dexes, interior holes, and a process restart (which makes every cache's first read in a process a repair read: prefix probes happen on all of them anyway in this envelope).

### Tight or loose

The chain from tight to loose: the zero-latency ordering maximum (632 min = 10.5 h) is the real worst for this inventory without retries or marks; adding the 18 marks at their real 415 s (about 2 h) and a realistic 0.3-1 s latency gives about 12.5 h; the bound is 18.2 h. A defensible typical completion (no retries, warm caches, marks at their real width), from the planner run above:

- 2.6-2.75 h when the venue returns the open candle (154 min without marks, 164-165 min with the 295 s mark window charged per hour). That is about 02:50 UTC (21:50 EST, the day before).
- 4.0 h with all core markets young, and 4.3-5.7 h if the venue omits the open candle.

So the 19:00 start has 14-16 hours of slack over the plausible typical case, and about 13 hours over the largest case I could construct (5.7 h).

## 3. Start sized to the worst-case bound versus an earlier start at a typical-case quantile

### What the two choices are

Fixed start s = 19:00 (the proposal): zero miss probability from slowness inside the envelope, but forecasts run on a snapshot 18 h 55 min old, and the four one-hour sessions then occupy 19:00-23:00 with one hour of calendar left. The latest feasible start is 20:00 (four sessions before the date ends), so a bound-sized start is already within one hour of the latest start possible. It spends nearly all the day to buy certainty against a 701-minute packing that the system's own planner reaches 3-7 times faster.

Earlier start s_q at the q-quantile of completion time: staleness falls by up to 14 h, but a snapshot that completes after s_q consumes main and no-reading as missed, so the miss probability is P(C > s_q - 00:05).

### What the miss probability depends on

C is not a constant, and its distribution is set by quantities the revision must name:

1. **Inventory and cache state at the cutoff**: the number of listings, the number younger than the daily and hourly scopes (each is a 39- or 100-weight prefix probe the next day, repeated daily because empty prefixes are not remembered), new listings, the first read per process (a crash or restart renews every repair interval).
2. **Venue behaviour**: whether the open candle is returned (+1,100 calls and +4.3 h in the closed-only case), and the venue's page and weight behaviour.
3. **Quota contention**: the recorder's 480 and any other co-egress job (the factor is the share left, not the full 120), the Monday benchmark acquisition and resolutions.
4. **Failure rate and latency**: 429/5xx probability per request and its clustering, because retries add one minute each in the worst case and sleeps add seconds.
5. **Mark interference**: dex count d (above 5 the sample capacity alarm fires), and the early-release distribution.
6. **Runner availability at the cutoff**: a runner down at 00:05 starts late, consuming the whole slack. This, not slow acquisition, is the likeliest cause of a miss in practice, and it is independent of the choice of s_q.

Misses are positively correlated across days (the same outage, the same inventory growth, the same venue change), so a binomial calculation understates the spread. For orientation only: with independent days, the probability of 9 or more misses in 28 days is 1.2e-3 at p = 0.10, 1.8e-2 at p = 0.15 and 0.25 at p = 0.25.

### What the quota allows (so the revision can state the tolerance without touching any threshold)

C10.5 needs at least 20 accepted main theses in 28 days, at most two per main session, and every due no-reading session run or reported missed. A missed day costs up to two registrations, and a missed no-reading session is reportable, not a failure. If r is the mean accepted registrations per on-time main session, the tolerable misses are m_max = 28 - 20/r, i.e. 8 at r = 1 and 14 at r = 1.4. The revision should fix r from the pilot's observed rate with its sample size, because the 28-day window cannot be extended. This only expresses the existing criterion as a miss budget; it loosens nothing.

### Quantities the criteria revision must state

1. **The objective.** Which cost is minimised (staleness at start, or miss probability) and which constraint holds (miss budget derived from C10.5 as above, or the fixed 19:00 bound). Without it the choice between 19:00 and an earlier hour is a taste, not a derivation.
2. **The decision rule for s.** Either a fixed start (s = 19:00 by the bound, or s_q by a quantile) or a rule that starts when the attested completion arrives and no later than a fixed deadline. The latter keeps miss probability at P(C > deadline) and cuts typical staleness from 18 h 55 min to about 3-4 h, but a variable start time depends on API conditions. Its effect on registration time and scoring (entry marks, horizons anchored at t_r, the Monday batches) must be argued, because on volatile days the venue may be slower and sessions would then start later. The revision should say if the start time may vary and, if so, that the forecast sees only the fixed snapshot.
3. **The measured completion distribution.** From how many timed dry runs, with what quantile and confidence: a nonparametric 95th percentile bound at 95% confidence needs 59 runs, a 99th at 95% needs 299, which is more days than the window holds, so an earlier start can only be justified by a parametric model or by the bound-sized fallback. The runs must record timing only (counts, weights, seconds, status), per the repo's rule that anything from the forward window stays out of research. The 2026-11-08 date is inside [2026-11-01, 2027-01-31), so no price, return or candle content may be kept from a timing run.
4. **The miss tolerance and its correlation structure.** The m_max above, the assumed autocorrelation of misses, and what is counted as a miss (main and no-reading both, per the draft).
5. **The cause attribution.** Whether a miss caused by runner downtime counts the same as one caused by slow acquisition; they have different causes and different cures.
6. **A reduction that shortens C by design, not by assumption.** The daily prefix probes (about one third of typical weight) re-ask a range that is known to be empty. Recording "no earlier candles before t0" per market (as `ready` does for funding) would cut typical weight from about 16,700 to about 11,300 (about 94 ideal minutes). That is a change to the snapshot's request plan and would need its own regression and a hash fork like any other, so it is a suggestion, not part of this review.

### Recommendation within the current thresholds

Keep 19:00 as a *deadline* (the proposal's own acquisition-complete-by rule) and separate the *start*: state whether the main session may begin as soon as the attested snapshot, the model gate and a stated minimum (for example the first whole hour after completion) allow. Under a fixed 19:00 start the paper should say plainly that the 18 h 13 min is a ceiling that the planner reaches about 4-7 times faster, and that the choice costs 14-16 hours of data age in exchange for zero slowness misses. If the variable start is not adopted, the revision should still record the measured typical completion so the human can see the price of the fixed hour.
