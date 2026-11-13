# Study 1, the positive control of the search: build plan

Written 2026-11-12 01:25 UTC (20:25 EST) by Claude Fable 5.2, session "architect: study 1 fix", after Argon's round 4, and revised later that day as the next section says. The design is `audit/program/architecture.md`, section 5. This file is the plan `CLAUDE.md`'s Orchestration asks for: ordered steps, each stating the behaviour its tests must show and the laws that hold for every input.

## What is built, and what this text changes

Revised 2026-11-13 17:28 UTC (12:28 EST) by Claude Fable 5.2, session "architect: study 1 calibration cost", after the advisor measured that step 5 could not run as written. The text before it is at `git show 960cfc9:audit/program/briefs/1-positive-control.md`, and those before that at `54c11fb`, `be96683` and `c46c786`.

- **Built,** from that text: steps 1 to 9, on branch `study1-build` at `a3fc471`.
- **The wall.** The calibration was costed at 20 core-hours, by its kernel evaluations. It costs about 1,200 to 1,400, and its twins 1.21 TB of disk (`arithmetic.py.txt`, `calibration_cost`).
- **The cause.** A fresh pair took 4.2 s, and 3.4 s of that was `ingest/store.py` hashing every row of its two markets in Python, into a column that the kernel never reads (`kernel/mm/src/market.rs`, `UNREAD`). The revision store is the recorders' archive, and its row hash tells one fetch's revision of a row from the next. A market made once from its id has no revisions, and a fresh pair exists only for the kernel to score.
- **The change.** A fresh pair is written with the columns the kernel reads, which takes 0.85 s for the same scores (step 1, behaviour 5 and L1.5). No twin and no score is kept, so a trial is a function of its market and its strength alone, and the job spreads over hosts (step 5).
- **What does not change.** Every definition, constant, wall and size above step 1, and so everything CS1.1 names. `gate/markets.py`, `ingest/store.py`, the kernel, the harness and the recorders are not touched. A market that a session or G100 searches is still written by `gate.markets.write`, as the pilot's were.

| Change | Why | Code that changes | Tests |
|---|---|---|---|
| A fresh pair is written for scoring | The row hash was four fifths of a pair's time and, with the holdout rows, most of its bytes | `pairs.py` (`write_pair`); `judge.py`, whose `fresh_scores` becomes `write_pair` and step 2's `scores` | New: L1.5, by a model other than the builder's. The two built tests of `write_pair` stand |
| Nothing is kept between trials | A kept twin is 13.3 MB, and it saved time only while a write was slow | `judge.py`: `twin_in`, `twin_scores` and the `twins` argument go, and with it the argument in `calibrate.py`, `searcher.py` and `runner.py` | Obsolete, below |
| The job spreads over hosts | 352 to 443 core-hours | `calibrate.py` | New: step 5's behaviours 7 and 8, L5.6 |

**Tests that this revision makes obsolete.**
- `test_calibrate.py`: `test_a_twin_is_made_once_across_strengths` is deleted, with the behaviour it tested. It ran for about 780 s against the repository's 600 s limit, so nothing is split and no limit rises. The module's note loses its words on a cold twin cache.
- No other test names a twin's cache. A test that passes `twins` to `judge`, `fresh_scores` or `g100_trial` drops the argument.

## How to use it

- **The test writer** works from this file and `architecture.md` section 5, without reading any code under `gate/control/`. It may read the signatures of the existing functions named under "What exists", and `kernel/DSL.md`.
- **Laws first.** A law is a property that holds for every input. The test writer writes each step's laws as property tests on random inputs (`hypothesis`, already in the flake), in `test_<step>_laws.py`, before the step's code exists. Where a law's domain is finite and small, the test checks all of it.
- **The builder** (Sonnet) makes each step's tests and laws pass without editing them, one commit a step, in order.
- **Steps 2 and 6 carry the judged number.** Their tests and laws are written by a different model (GPT; a fresh Opus session, labeled, if GPT is unavailable). Their laws marked **Lean** are also stated under `reference/lean` by that writer and proved there. Anyone may write a proof, since Lean checks it; only the statement needs an independent author. The proofs are owed before step 9's report and hold up no session, because the same laws already run as property tests.
- **A wall goes back to the architect** as a question and is never patched around: a behaviour or law below that the existing code cannot give, a model-free wall of step 5 that fails, or a number here that the tests contradict.
- **Nothing frozen changes.** No file that `harness_hash` reads, no kernel source, no DSL, no gate code. The first test of step 1 asserts that `harness_hash()` begins `6a335714` and fails otherwise.
- **The forward window stays unread.** The study uses synthetic markets only and reads nothing under `data/holdout/` or any recording.

## The order, against the accounts' window

Cornell and TAMU are free until about 2026-11-25, TAMU's week resets on 2026-11-14 04:00 UTC (2026-11-13 23:00 EST), and each day before the first session costs three markets (architecture 5.3). So the work is ordered by what the first session needs:

1. **On the path:** L1.5 and step 5's new tests, then the change to `pairs.py`, `judge.py` and `calibrate.py`; the calibration run, 352 core-hours and at most 443, which is 12 to 15 hours on 30 cores (`calibration_cost`); the manifest's commit and G100's arm, 2 core-hours; the bug hunt and Opus's last review.
2. **Off the path, after the first session starts:** step 9, the Lean proofs, and the laws of steps 3 and 6, whose code already passes its tests.
3. **If the window ends before a boundary,** the runner is left stopped, and the study resumes later on another account under the same manifest (the human, 2026-11-12 01:41 UTC (2026-11-11 20:41 EST)).

## What exists, and is used unchanged

- `gate.markets.generate(model, params, market_id, days, planted, beta)`: arrays for one market. Every random draw is seeded from `market_id`, and `planted` and `beta` change no draw. The plant adds `beta × signal` to each planted coin's bar return before the clip, where `signal = −clip((f − 1.25e-5) / 1e-4, −1, 1)` and `f` is that coin's funding four hours before the bar.
- `gate.markets.write(root, arrays, holdout_days, cost_cells)`: a market in the recorders' revision store, as the pilot's sessions were given theirs.
- `gate.agent.campaigns.series_inputs()`: N2's parameters with the frozen funding blob, the cost cells, and the kernel's hash. `gate.sweep.DAYS = 730`, `HOLDOUT_DAYS = 180`.
- `gate.search.run("G100", market, ledger, campaign, seed)`: the searcher, 100 evaluations, every one in the ledger. `gate.search.Evaluator` streams programs through `mm eval` and returns the disclosed `sharpe_annualized`.
- `gate.agent.harness.run_agent(market, ledger, campaign, run_dir)`: one agent session under the frozen harness, which asks for `claude-opus-5-5` (`harness.MODEL`). Its run record has `spent`, `stopped`, `exit` and `transcript_sha256`.
- `gate.agent.campaigns.crashed(run)`: whether a session missed every designed end. `evaluations_made`, `wait_for_room`, `windows`: evaluations in a ledger, and pacing on the subscription accounts.

## Definitions the tests rest on

Constants, all in one place (`gate/control/constants.py`) and all copied into the manifest. Each derived value is printed by `audit/program/arithmetic.py.txt`.

| Name | Value | Reason |
|---|---|---|
| `PAIRS`, `MAJORITY` | 57, 39 | The smallest rule that classes a pick with a chance of 1/2 on a pair as earning at most 0.005 of the time, and one with 3/4 at least 0.9 of the time: 0.0038 and 0.901 |
| `SHARE` | 0.5 | Half the reference's effect |
| `THETA1` | 0.7 | The sign test's alternative |
| `ALPHA`, `BETA_ERROR` | 0.05, 0.05 | Nominal errors |
| `MAX_MARKETS` | 100 | The human, 2026-11-11 |
| `TARGET`, `TOLERANCE`, `MAX_STEPS` | 0.15, 0.005, 12 | The search stops at a strength where G100's rate is within the tolerance of the target |
| `SEARCH_MARKETS`, `CHECK_MARKETS` | 1,600, 10,000 | A check that fails by sampling alone has probability 0.005 |
| `BAND` | 0.12 to 0.18 | The check's rate; the true rate is then 0.11 to 0.19 at 2.5 standard errors |
| `BLIND_MARKETS`, `EVEN_ALLOWED` | 200, 4 | Wall 3: each of five mirror pairs on 200 markets; some pair above 4 has probability 0.005 under the rule's bound |
| `CONSTANT_ALLOWED` | 14 | Wall 5: a constant position that earns at the bottom of G100's band, 0.11, earns on at most 14 of 200 markets with probability 0.039 |
| `PLANTED` | coins 0 to 5 of 12 | A choice: half the coins, so each market keeps unplanted coins that wall 1 can compare |
| `SERVED` | `claude-opus-5-5`, `claude-opus-4-8` | The ids that answered the pilot's sessions: the one the harness asks for, and the client's fallback (architecture 5.2) |
| `NOTICE` | `<synthetic>` | The id under which the frozen client writes a line of its own when a request fails (`audit/decisions.md`, 2026-11-12 15:29 UTC (10:29 EST)) |

- **Ids.** A study market is `control-1-m000` to `control-1-m099`. Its fresh pairs are `<market id>/fresh/0` to `/fresh/56`. The search's markets are `control-1-cal-a-0000` to `-1599`, the check's `control-1-cal-b-0000` to `-9999`, wall 3's `control-1-blind-000` to `-199`. No two sets share an id, so none shares a seed.
- **A market at strength `b`** is `generate("N2", params, id, 730, PLANTED, b)` written with 180 holdout days and the series' cost cells. **Its twin** is the same call with strength 0.
- **A program's score on a market** is the `sharpe_annualized` that `mm eval` discloses for it on that market's search period, in a scratch ledger. A program that the kernel rejects, or whose disclosure lacks the statistic, has no score.
- **A program's effect on a pair** is its score on the planted market minus its score on the twin. It is undefined when either score is missing or not finite.
- **A program wins a pair** when its effect and the reference's are both defined, the reference's is positive, and the program's is at least `SHARE` times the reference's.
- **A program earns from the plant on market `m`** when it wins at least `MAJORITY` of `m`'s `PAIRS` fresh pairs. What it reads plays no part.
- **A program's mirror** is the same program with every target position negated. **A mirror pair's even part** on a pair of markets has, as its two scores, the means of the two members' scores on the planted market and on the twin. It is classified like a program, and has no score where either member has none.
- **A session's pick** is, among the programs that session evaluated on its study market, the one with the highest disclosed search-period `sharpe_annualized`. Ties go to the earliest evaluation. A program with no disclosed statistic is not a candidate. A session with no candidate has no pick, and that arm misses the market.
- **A session's model ids** are the `message.model` of its transcript's assistant lines, each with its count of lines, in order of first appearance. A line that does not parse is passed over, and so is an assistant line whose id is `NOTICE`. No other line of the transcript is read: the ids do not depend on a `model_refusal_fallback` line, or on where it stands (architecture 5.2).
- **A designed end** of a session is a finish with a zero exit, the turn limit, or the wall time: `crashed(run)` is false. A session that left no run record did not end. **A session is the agent's** when every one of its model ids is in `SERVED`.
- **G100's seed on a market** is the first eight bytes, as an unsigned integer, of `sha256("<manifest seed>:<market id>:G100")`.

## Step 0. The criterion (the advisor, before step 7's manifest)

`CLAUDE.md` asks that a condition judging a number be pre-registered. The study has one, committed alone on `main` as `criteria: study 1` (`10fedc5`), with its definitions at `ce7ff38`. The revision of 2026-11-13 changes no word of it and nothing it defines: the definitions above, the constants, the walls and the sizes are as they were at `ce7ff38`, and L1.5 makes every score the same number.

> **CS1.1.** Claim: on synthetic N2 markets in which six coins carry a planted drift at the manifest's strength, the frozen agent's session ends on a program that earns from the plant with a higher chance than G100's 100 evaluations do.
> - **The agent** is the stage 3 harness, `harness_hash` `6a335714…`, as served while the study runs: it asks for `claude-opus-5-5`, and each response comes from `claude-opus-5-5` or from `claude-opus-4-8`, the client's fallback when the provider's safeguards refuse. A session is the agent's when every response in its transcript names one of the two.
> - **Judged by** Wald's sequential sign test on discordant markets, `θ ≤ 1/2` against `θ = 0.7`, nominal errors 5%, in the manifest's order, ending at 100 markets. Each market has one session, which is never run again. The market is judged on the pick in that session's ledger, however the session ended. A session that leaves no pick, or that is not the agent's, is the agent's miss.
> - **Met** when the upper boundary is crossed.
> - **Otherwise** the result is named "Not shown" at the lower boundary, "Inconclusive" at 100 markets, and "Inconclusive at the markets judged" at an early end. It is never named "no better".
> - **Definitions:** `audit/program/architecture.md`, section 5, and `audit/program/briefs/1-positive-control.md`, at the commit this criterion's commit names. Size at most 0.043 by exact enumeration (`audit/program/arithmetic.py.txt`, `sign_test`).
> - *Passes while the claim is false:*
>   - by chance, at most 0.043. No failure of a session adds to that: a failure can only turn a market into the agent's miss, and a miss in place of any outcome never makes a claim;
>   - by a measure that pays something other than the drift captured. Wall 3 bounds it before any session;
>   - by a program that reads nothing, submitted with no search. Wall 5 passes a constant position that earns as often as G100 does with probability at most 0.039 (`walls`).
> - *Fails while the claim holds:*
>   - an agent at 0.3 against G100 at 0.15 to 0.19 ends without the claim with probability 0.33 to 0.68, unless the arms' successes overlap almost entirely. The study states that it is not powered there;
>   - a session that an outage ends is judged on what it left, and is a miss if it left no evaluation. With 0.07 of sessions lost, an agent at 0.5 against G100 at 0.19 claims with probability 0.896, for 0.943 with none lost; with one in five lost, 0.734;
>   - a study ended early fails more often at every rate.
> - *Not claimed:*
>   - anything about `claude-opus-5-5` or `claude-opus-4-8` alone, or about one against the other. The report's rate for each set of ids is confounded by how long a session runs;
>   - the agent at a share of fallback other than those the report shows, the pilot's included. Where the share moved during the study, the claim is of the agent at some share it met;
>   - the rest of architecture 5.4's list. A change of model that the provider does not disclose is invisible to this study.

Everything else in this plan is a test, a law or a wall, not a criterion.

## Step 1. Markets and twins (`gate/control/pairs.py`)

Behaviour:
1. `harness_hash()` begins `6a335714`.
2. `fresh_ids(m)` returns the 57 ids `m/fresh/0` to `m/fresh/56`, in order.
3. `arrays(id, b)` returns `generate` for the study's model, parameters, days and `PLANTED`.
4. **Wall 1, as a test.** For 20 ids and a positive strength, between `arrays(id, b)` and `arrays(id, 0)`: funding, premium and volume are equal for every coin; open, high, low and close are equal for every coin not in `PLANTED`; and the close differs somewhere for every coin in `PLANTED`.
5. `write_pair(root, id, b)` writes the planted market and the twin for scoring, under two directories of `root`, and returns both paths. A market whose id contains `/` is written without error.
   - **Written for scoring,** a market holds its search period as the kernel reads it: the rows and values of the `store/` that `gate.markets.write` gives for the same arrays, holdout days and cost cells, with `fetchedAt`, and the same policy, venue and version. It has no `hash` and no `source` column, and no `holdout/`.
   - **Why the score cannot differ.** The frozen kernel skips both columns as it reads (`kernel/mm/src/market.rs`, `UNREAD`), and in search mode it reads `store/` alone and refuses any row at or after the holdout's start. What differs is the files' bytes, which enter an evaluation's identity in its scratch ledger and not its statistic. L1.5 tests it.
   - **Only pairs are written so.** `write_market(root, id, b)` is `gate.markets.write`, for the market that a session or G100 searches.
6. Two different ids give different funding arrays.

Laws, for every id and every strength in the bracket:
- **L1.1** `arrays(id, b)` called twice returns equal arrays.
- **L1.2** The strength changes no draw: between any two strengths, funding, premium, volume and every unplanted coin's open, high, low and close are equal.
- **L1.3** `arrays(id, 0)` equals `generate` with no planted coin.
- **L1.4** The fresh ids of two different markets share no id, and no fresh id is a study, calibration or blind id.
- **L1.5** A market written for scoring scores as the market does. For every id, every strength, zero included, and every program drawn from G100's generator, the reference and the mirror set: the statistic that `mm eval` discloses on `write_pair`'s market equals, bit for bit, the one it discloses on `write_market`'s, and it is missing on both or on neither. The judged number rests on this law, so its test is written by a model other than the builder's.

## Step 2. The measure (`gate/control/measure.py`). Judged: tests and laws by another model

Two layers. The pure layer takes numbers and is tested exhaustively; the kernel layer is thin. Only the kernel layer's `score` exists.

Pure behaviour, `classify(pick, reference)`, each argument a list of `PAIRS` `(planted score, twin score)` with `None` for a missing score:
1. It returns the count of pairs won and whether that count is at least `MAJORITY`.
2. A pair is won exactly when the definition above says so. Tests cover: an effect equal to half the reference's (won); just below (lost); a reference effect of zero or below (lost, whatever the pick's); a missing or non-finite score on either side of either program (lost); a pick with a large positive effect where the reference's is negative (lost).
3. 38 pairs won is false; 39 is true.
4. A list that is not `PAIRS` long is an error.
5. `even(member, mirror)` returns the even part's `PAIRS` score pairs from two programs' score pairs, with `None` where either is missing.

Kernel behaviour:
6. `score(program, market)` returns the disclosed statistic, or `None` for a program the kernel rejects. Scoring the same program on the same market twice gives the same number. It writes to a scratch ledger, never to a study ledger.
7. `scores(programs, pairs)` returns, for each program, the `PAIRS` score pairs for a list of fresh pairs. It runs one evaluator process a market and streams every program through it, so a pick and the reference share it: a process an evaluation would multiply the calibration's 8 million evaluations by the kernel's start-up time, 0.18 s.
8. A program that never trades has equal scores on a market and its twin, or none on both.

Laws of the pure layer, for every pair of lists. Finite scores are drawn as `k × 2^-16` with `|k| ≤ 2^20`, so that sums, differences and halves are exact in binary64; in L2.7, `c` is a multiple of 1/4 and the reference's effects are multiples of `2^-14`.
- **L2.1** The count is between 0 and `PAIRS`, and the verdict is true exactly when the count is at least `MAJORITY`.
- **L2.2** Adding one number to both scores of a pair, for either program, changes nothing.
- **L2.3** One permutation applied to both lists changes nothing.
- **L2.4** Raising a pick's planted score, or lowering its twin score, on any pair never lowers the count.
- **L2.5** Replacing any score by `None` or a non-finite number never raises the count.
- **L2.6** The reference classified against itself wins exactly the pairs where its effect is positive.
- **L2.7** A pick whose effect on every pair is `c` times the reference's wins exactly the pairs where the reference's effect is positive, when `c ≥ SHARE`, and none when `c < SHARE`.
- **L2.8, Lean.** A pick and its exact negation (each effect negated) never win the same pair; so their counts sum to at most `PAIRS`, and they never both earn, because `2 × MAJORITY > PAIRS`.
- **L2.9** `even` is symmetric in its arguments; `even(a, a)` classifies as `a` does; the even part of a pick and its exact negation has effect zero on every pair and wins none.
- **L2.10, Lean.** The rule's bound, as exact rationals: the sum of `C(57, k)` for `k` from 39 to 57 is at most `2^57 / 200`. As a property test: the chance of at least `MAJORITY` wins in `PAIRS` trials does not fall as `q` rises, is at most 0.005 at `q = 1/2`, and is at least 0.9 at `q = 3/4`.

Laws of the kernel layer, for programs drawn from G100's own generator and random market ids:
- **L2.11** `score` is a function: the same program and market give the same number.
- **L2.12** On a pair at strength zero every program's effect is exactly zero: the planted market and the twin are the same market.

## Step 3. The pick (`gate/control/pick.py`). Built

Behaviour:
1. From a ledger holding one campaign's evaluations by one agent, `pick` returns the program with the highest disclosed search-period `sharpe_annualized`, as JSON the kernel accepts.
2. Re-scored on the same market with step 2's `score`, the pick's score equals the ledger's.
3. Two programs with equal scores: the earlier evaluation is returned.
4. Evaluations without a disclosed statistic are ignored. A ledger with none returns `None`.
5. The function is the same for both arms: after `search.run("G100", …)` it returns a program among G100's 100, and no evaluated program has a higher disclosed score.
6. It reads only the campaign and agent it is given, in a ledger that holds two.

Laws, for every ledger built from a random list of evaluations, some without a statistic:
- **L3.1** The pick's score is the greatest disclosed score, the pick is the earliest evaluation with it, and there is no pick exactly when no score is disclosed.
- **L3.2** Adding evaluations by another agent or campaign, or a later evaluation whose score is not higher, changes nothing.

## Step 4. The reference and the mirror set (`gate/control/programs/`)

Locked DSL programs, each a JSON file, each hash in the manifest.

- **The reference** holds, on every coin and every bar, a position in the direction of the plant's signal and proportional to it: short when the coin's funding four hours before the bar is above `1.25e-5`, long when below, at full size from a distance of `1e-4`. It uses only inputs available at the bar's decision time. If PC2's reference program on branch `positive-controls` meets the tests it is reused.
- **The mirror set,** five mirror pairs, ten programs: constant long and constant short on every coin, each at the highest leverage the DSL allows; momentum and reversal on the last day's close-to-close return; one position blind to the plant at three leverages, each with its negation.
- **The blind position** is `sign(xs_demean(mean(volume, 168)))` times 0.01, 0.05 or 2/12 (`random_low`, `random_mid`, `random_high`, the builder's encoding, accepted). The DSL has no per-coin constant, so a fixed random position cannot be written. What the wall needs from one is that it carries nothing of the plant, and this has it: `generate` draws volume independently of funding, returns and the plant, and twins share it. It turns over about weekly, which wall 3 needs and a fixed position lacks.

Behaviour:
1. Every program type-checks in the frozen kernel and has a score on a calibration market.
2. No program of the mirror set reads funding or premium: the test walks each program's JSON and finds no such input.
3. On 50 calibration pairs at a strength of 0.005, the reference's effect is positive on at least 45. This is a smoke check; wall 2 judges the reference at the study's strength.

Law:
- **L4.1** The two members of every mirror pair are the same JSON tree apart from the sign of the target position.

If no DSL program can express the reference with inputs the kernel allows at decision time, or a program's exact mirror, that is a wall.

## Step 5. Calibration and the model-free walls (`gate/control/calibrate.py`)

Entry point `python -m gate.control.calibrate`, a batch job (`ops/jobs.py`), writing `audit/control-1/calibration.json` and one JSON line a market as it goes, so a stopped run resumes without recomputing.

- **G100's rate at strength `b` on a set of markets** is the share on which G100's pick earns from the plant: per market, the market at `b`, G100 with its derived seed, the pick, the `PAIRS` fresh pairs at `b`, the pick and the reference classified.
- **The search.** Bracket `[0, 0.01]`, on the 1,600 markets `cal-a`. The first candidate is the bracket's upper end, and after it each bracket's midpoint, at most `MAX_STEPS` midpoints. A candidate whose rate is at most `TOLERANCE` from `TARGET`, the ends included, is the strength, and the search ends. Otherwise the upper end with a rate below the target ends the search with no strength; a midpoint with a rate above the target becomes the upper end, and one below it the lower end. The same markets for every candidate make the rate one function of strength.
- **The check.** G100's rate at the strength on the 10,000 markets `cal-b`.

Behaviour, on a stub rate function, without the kernel:
1. For a rising function that is below `TARGET − TOLERANCE` at strength zero, above `TARGET` at the upper end, and rises by at most 0.01 over any 0.01/4096 of strength, the search returns a strength.
2. With the rate at the upper end below `TARGET − TOLERANCE`, or with no candidate inside the tolerance, the run stops and reports wall 4 failed.
3. A stopped run, restarted, evaluates no market twice and returns the same strength.

The walls, reported in `calibration.json` with their counts. Each is a pass or a stop, and a stop goes to the architect:
- **Wall 2.** Over the `cal-b` pairs, the reference's effect is positive on at least 95%.
- **Wall 3.** On each of the 200 `blind` markets at the strength, each mirror pair's even part is classified as if it were a pick. For each of the five mirror pairs, at most `EVEN_ALLOWED` of its 200 classifications earn. The report holds the five counts.
- **Wall 4.** The search returns a strength, and G100's rate on `cal-b` is inside `BAND`.
- **Wall 5.** On the `blind` markets, constant long and constant short, each classified as a pick, each earn on at most `CONSTANT_ALLOWED`.

4. The report holds, for each wall, the count, the denominator and pass or stop; a test builds each from stub scores on both sides of its threshold.
5. The report also holds, never judged: each mirror-set program's own rate of earning on the `blind` markets, and the number of G100's `cal-b` picks at each count of pairs won, 0 to 57.
6. Before the search the job times one whole `cal-a` market at the bracket's upper end, with everything a market costs: generating and writing it and its 57 pairs, each evaluator's start, G100's 100 evaluations, and the classification. It prints the projected time for the whole job on the hosts it will use: at most 13 strengths on 1,600 markets and one on 10,000, plus wall 3. A projection above 24 hours stops the job: a wall.
7. A twin does not depend on the strength. Over a search of several strengths, each `cal-a` twin is generated once and the reference is scored on it once.

Laws, on stub rate functions:
- **L5.1** For every rate function, rising or not, a returned strength has a rate within `TOLERANCE` of `TARGET` on the search's markets. Otherwise the search reports that it found none.
- **L5.2** The search evaluates at most 13 strengths, the upper end first, none twice, all inside the bracket.
- **L5.3** A run interrupted after any number of markets and restarted gives the same report as an uninterrupted one and evaluates no market at a strength twice.
- **L5.4** A rate does not depend on the order in which its markets finish or on the number of workers.
- **L5.5** For every count, a wall passes exactly when the count is on the passing side of its threshold.

## Step 6. The sequential rule (`gate/control/sequential.py`). Built. Judged: tests and laws by another model

Pure behaviour:
1. `decide(wins, losses, markets)` returns `claim`, `futility`, `undecided` or `continue`. A win adds `log(0.7 / 0.5)` and a loss `log(0.3 / 0.5)` to a sum that starts at zero. `claim` at or above `log 19`; `futility` at or below `−log 19`; otherwise `undecided` when `markets` is 100, else `continue`.
2. Nine straight wins claim and eight do not. Six straight losses stop and five do not.
3. Concordant markets move nothing but count toward the 100.
4. `outcome(agent_earns, searcher_earns)` is a win only for (true, false) and a loss only for (false, true).
5. The rule is applied in order: given a sequence that crosses a boundary at market `k`, the decision is the one at `k`, whatever follows.
6. By exact enumeration over (wins, losses), which the test implements itself:

| Chance only the agent earns, only G100 earns | Claim | Futility | Undecided | Expected markets |
|---|---|---|---|---|
| 0.5, 0.5 | 0.043 | 0.936 | 0.021 | 33 |
| 0.1275, 0.1275 | 0.020 | 0.453 | 0.527 | 82 |
| 0.5, 0.19 | 0.943 | 0.017 | 0.041 | 41 |
| 0.425, 0.075 | 0.999 | 0.000 | 0.001 | 29 |

   Probabilities to within 0.0006, expected markets to within 0.6.

Laws. A sequence's decision is the decision at its shortest prefix that is not `continue`.
- **L6.1** For every `wins` and `losses` up to 100, checked exhaustively, `decide` agrees with the rule in whole numbers: `claim` exactly when `7^wins × 3^losses ≥ 19 × 5^(wins + losses)`, `futility` exactly when `19 × 7^wins × 3^losses ≤ 5^(wins + losses)`. **Lean:** neither is ever an equality, so no state sits on a boundary where rounding could decide.
- **L6.2** `claim` and `futility` do not depend on `markets`. One more win never moves a decision away from `claim`, and one more loss never away from `futility`.
- **L6.3** Exchanging the arms exchanges wins and losses: `outcome(a, b)` is a win exactly when `outcome(b, a)` is a loss.
- **L6.4, Lean.** Dominance: replace any outcomes of a sequence that claims by better ones (a loss by a concordant market or a win, a concordant market by a win), and it still claims.
- **L6.5, Lean.** Remove any concordant markets from a sequence that claims, and it still claims.
- **L6.6, Lean.** The size, as an exact rational: when each of 100 markets is a win or a loss with chance one half, the chance of `claim` is below `43/1000`. With L6.4 and L6.5 this bounds the size under every joint law of the arms (architecture 5.2).
- **L6.7** For random chances `a ≤ s` with `a + s ≤ 1` that only the agent and only G100 earn, the chance of `claim` by the test's own enumeration is at most its value at (0.5, 0.5).

## Step 7. The manifest and the searcher's arm (`gate/control/manifest.py`)

`audit/control-1/manifest.json`, written once after step 5 passes, then committed alone. It holds: the seed; the 100 market ids in order; `PLANTED` and the strength; every constant above, `SERVED` and `NOTICE` among them; the model the harness asks for; the hashes of the kernel binary, the harness, the funding blob and N2's parameters; the reference's and the mirror set's hashes; `calibration.json`'s hash; `flake.lock`'s hash; and the hash of each file of the judged path.

- **The judged path** is every file of this repository that the searcher's or the runner's module imports, directly or through another module, whatever its directory, and `gate/control/programs/`. These are the files that can change a line of `searcher.jsonl` or `results.jsonl`. Beyond `gate/control/` they include `gate/search.py` (G100), `gate/markets.py` (the generator), `gate/sweep.py` and `gate/agent/campaigns.py`, which the text before this left out.
  - **No exception for the harness's files.** The harness hash covers some of them already. A file is hashed because an arm imports it, so nobody keeps a list of what something else covers.
  - **`flake.lock`** fixes the interpreter and the libraries. The generator draws through them, so a moved lock could give a session a market that G100 never searched.
- **Outside it:** `tests/`, the report, and any module neither arm imports. The report recounts lines and judges nothing (L9.2). So laws, proofs and step 9 may land after the first session without failing `verify()`.
- **Both arms run from a worktree of their own at the manifest's commit,** so that the hashed files stay still while `main` moves.

Behaviour:
1. Writing a manifest where one exists is an error. So is writing one from a calibration that has no strength or in which a wall stopped.
2. `verify()` recomputes every hash and fails naming the first that differs. Every entry point of steps 7 to 9 calls it first.
3. After the manifest's commit and CS1.1's, `python -m gate.control.searcher` runs G100 on each study market in a ledger of its own, classifies its pick, and appends one line a market to `audit/control-1/searcher.jsonl`: the id, the seed, the evaluations spent, the pick's hash and the inputs it reads, its count of pairs won, the reference's median effect, whether it earns, and its earlier bests. An earlier best is a program that was G100's pick after some evaluation: the line gives that evaluation's number, the program's hash, its count of pairs won and whether it earns, so that G100's pick among its first `k` evaluations can be read for any `k`.
4. It refuses to run when a study market has an agent run directory: G100's arm is complete before the first session.
5. Run twice, it gives the same file.

Laws:
- **L7.1** `verify()` passes on an untouched tree and, after a change to any one byte of any hashed file, fails naming that file.
- **L7.3** The hashed files are exactly the judged path, found by the test from the modules' imports: a new module that an arm imports is hashed without being listed, in `gate/control/` or anywhere else in the repository, and a new file under `tests/` is not.
- **L7.4** Each earlier best is the pick of the ledger cut at its evaluation, and the last one is the pick.
- **L7.2** The searcher's file does not depend on the order in which markets run or on the number of workers.

## Step 8. The runner (`gate/control/runner.py`)

Entry point `python -m gate.control.runner`, one market at a time in the manifest's order, on the TAMU and Cornell accounts through `wait_for_room`, never the personal account. Each market gets one session (architecture 5.2). For market `i`:

1. Write the market at the strength. Run `harness.run_agent` with a ledger and run directory of that market's own. G100's ledger for the market is not readable from the session.
2. **The model.** The session's model ids are read and recorded. A session whose every id is in the manifest's `SERVED` is the agent's, whatever the ids' order or mix, and whether or not its transcript holds a fallback event. A session with an id outside `SERVED` is not the agent's: it is the agent's miss whatever its ledger holds, and its line holds the ids and no pick.
3. **The pick.** Every other session is judged on the pick in its ledger, however it ended: by its own choice, at the turn limit or the wall time, by a crash, or with the runner killed under it. No pick is a miss.
4. Classify the pick on the market's fresh pairs with the reference. Append one line to `audit/control-1/results.jsonl`, in one write, before anything else happens: the id, the run record (none for a killed session), the model ids with their counts, whether the session is the agent's, the evaluations spent, how the session ended (the run's `stopped`, "crashed" or "killed"), the pick's hash and the inputs it reads, its count of pairs won, the reference's and the pick's median effects, whether each arm earns, the outcome, the running wins and losses, and the decision.
   - **No fsync is asked for.** A line is a function of files that are kept: the run record, the transcript, the ledger and `searcher.jsonl`. A line lost with the machine is written again on restart, by behaviours 5 and 6, and those are tested by killing the process.
5. Stop at `claim`, `futility` or `undecided`.
6. **A person looks.** With `continue`, when the session crashed or is not the agent's, the runner exits with an error that names the market and the cause, and writes nothing more. The next start goes on at market `i + 1`. Otherwise go to market `i + 1`. A killed session needs no exit: its line is written by the start that a person made.
7. **An early end.** `python -m gate.control.runner --end` appends a last line with the state "ended early" and the count of markets judged. After it the runner starts no session.

Behaviour, with the harness and the kernel replaced by stubs in tests:
1. A sequence of stub outcomes produces the decisions step 6 gives, and the runner launches no session after a stop.
2. No market gets a second session, whatever its session did.
3. A crashed session with an evaluation in its ledger is judged on its pick. A crashed session with none is a miss. After either, the runner exits without starting the next market, and the next start begins there. A session that finishes with a zero exit and no evaluation is a miss, and one that ends at the turn limit with evaluations is judged: the runner goes on after both.
4. A session answered by `claude-opus-5-5` throughout, one answered by `claude-opus-4-8` throughout and one answered by both are all judged, and their lines record the ids and the counts. A `model_refusal_fallback` line changes nothing: with it after the first responses, as the pilot's client wrote it, before them, last, or absent, the session gives the same ids, the same line and the same decision. An assistant line whose id is `NOTICE` is not an id. A session with an id outside `SERVED` is a miss even when its ledger's pick would earn, in a session that reached a designed end and in one that crashed alike: its line holds the ids, the decision counts the miss, the runner exits, and the next start goes on at the next market.
5. **Killed between a session's end and its result line** (the test kills the process): on restart the session is not run again, the pick is classified from the kept ledger, and one line is written.
6. **Killed during a session:** on restart that session is not run again. It is judged on its kept ledger, its line holding no run record and "killed" as how it ended, and with no evaluation it is a miss. The restart then goes on to the next market, unless the session is not the agent's.
   - **The kept ledger is read only once it is final.** The session's `claude` dies with the runner, by the sandbox's `--die-with-parent`. The daemon's kernel process (`mm eval -`, `gate/agent/daemon.py`) does not: it may still commit the evaluation it was given, and it exits when its input ends. Its command line names the ledger. So before a restart reads a kept ledger, it waits until no process's command line names that ledger (`/proc`). The only process that starts one is dead, so one scan that finds none is final.
   - **The test** kills the runner while a stand-in for the kernel process, started with the ledger's path among its arguments, has an evaluation still to commit. The restart's line is the line of the ledger after that commit, however long the commit takes.
7. A market with a result line is never run again, and `results.jsonl` is never rewritten, only appended.
8. A session's working directory holds no file of another market, of G100's arm, or of `audit/control-1/`.
9. `verify()` failing stops the runner before any session.
10. After `--end`, a restart launches nothing.

Laws, for every random script of stub sessions (outcomes, crashes, unnamed ids) and every set of points at which the runner is killed and restarted:
- **L8.1** `results.jsonl` only grows: its content at any moment is a prefix of its content at every later one.
- **L8.2** Its market lines are in the manifest's order with no gap and no market twice.
- **L8.3** Each line's running wins and losses equal a recount of the lines above it, and its decision equals `decide` on them.
- **L8.4** No session starts after a line whose state or decision ends the study.
- **L8.5** A kill outside a session changes no line. A kill during a session gives that market the line of its kept ledger, with "killed" as how it ended, and changes no other line.
- **L8.6** Every session launched is one market line, or the one in flight: the sessions launched never exceed the market lines by more than one.
- **L8.7** A session's model ids are a function of its assistant lines whose id is not `NOTICE`, in their order: adding, removing or moving any other line of the transcript changes no id and no count.
- **L8.8** A line whose session is not the agent's, or has no pick, says that the agent does not earn.

## Step 9. The report (`gate/control/report.py`)

`python -m gate.control.report` writes `audit/control-1/report.md` from the manifest, `calibration.json`, `searcher.jsonl` and `results.jsonl`, and reads nothing else: no ledger, and no kernel.

Behaviour:
1. It states the decision and its name, word for word from the second column of architecture 5.4's table, and never "no better". Under a claim it names the models that answered.
2. Each arm's rate with its exact (Clopper-Pearson) 95% interval, and the discordant counts. It points to architecture 5.3's power table and quotes no row of it: a row chosen by the observed rates restates the result as power (Hoenig and Heisey, "The abuse of power", 2001).
3. Reported, never judged, all from the lines:
   - each pick's count of pairs won, by arm; each pick's median effect and the reference's; the inputs each pick reads;
   - G100's pick among its first `k` evaluations, `k` being the agent's count on that market: the last earlier best at or before `k`, and none when `k` is 0;
   - evaluations used and how each session ended;
   - each session's model ids with their counts; the agent's rate, with its exact interval, for each set of ids that answered a session, and each set's share of the sessions. Beside them, the sentence "The sets are not arms: which ids answer a session depends on how long it runs".
4. The sessions that reached no designed end, with their evaluations, how they ended and their outcomes. The sessions that an unnamed id answered, with the ids.
5. Sessions run beyond the stop, if any, appear in a separate table and in no rate.
6. On a results file that has reached no end, it reports what there is and says the study has "not ended". On one that ends "ended early" it reports "Inconclusive at the markets judged".

Laws, for every random set of input files that the runner could have written:
- **L9.1** The report is a function of its inputs: the same files give the same bytes.
- **L9.2** Every rate and count in it equals a recount of the lines.
- **L9.3** It never contains "no better", and lines after a stop enter no rate.

## Before the first session

- A fresh session hunts bugs in `gate/control/` (`CLAUDE.md`, Correctness).
- Opus checks each commit against its step, and gives the last review before step 7's manifest commit.
- The advisor adds the runner's workload to `CLUSTER.md`, with the worktree it runs from (step 7), and names the manifest among `CLAUDE.md`'s frozen identities.

## What the builder reports

For each step: the commit, and the tests' and laws' result. For step 5: the timing, the strength, each wall's counts, the mirror set's rates and the counts of pairs won. Any wall, at the top.
