# Study 1, the positive control of the search: build plan

Written 2026-11-11 21:38 UTC (16:38 EST) by Claude Fable 5.2, session "architect: revision 4, finish". It replaces the brief written for revision 2 (`git show 9e5240b:audit/program/briefs/1-positive-control.md`). The design is `audit/program/architecture.md`, revision 4, section 5, approved by the human on 2026-11-11 21:26 UTC (16:26 EST). This file is the plan `CLAUDE.md`'s Orchestration asks for: ordered steps, each stating the behaviour its tests must show.

## How to use it

- **The test writer** works from this file and `architecture.md` section 5, without reading any code under `gate/control/`. It may read the signatures of the existing functions named under "What exists".
- **The builder** (Sonnet) makes each step's tests pass without editing them, one commit a step, in order.
- **Steps 2 and 6 carry the judged number.** Their tests are written by a different model (GPT; a fresh Opus session, labeled, if GPT is unavailable).
- **A wall goes back to the architect** as a question and is never patched around: a behaviour below that the existing code cannot give, a model-free wall of step 5 that fails, or a number here that the tests contradict.
- **Nothing frozen changes.** No file that `harness_hash` reads, no kernel source, no DSL, no gate code. The first test of step 1 asserts that `harness_hash()` begins `6a335714` and fails otherwise.
- **The forward window stays unread.** The study uses synthetic markets only and reads nothing under `data/holdout/` or any recording.

## What exists, and is used unchanged

- `gate.markets.generate(model, params, market_id, days, planted, beta)`: arrays for one market. Every random draw is seeded from `market_id`, and `planted` and `beta` change no draw. The plant adds `beta × signal` to each planted coin's bar return before the clip, where `signal = −clip((f − 1.25e-5) / 1e-4, −1, 1)` and `f` is that coin's funding four hours before the bar.
- `gate.markets.write(root, arrays, holdout_days, cost_cells)`: a market in the kernel's store format.
- `gate.agent.campaigns.series_inputs()`: N2's parameters with the frozen funding blob, the cost cells, and the kernel's hash. `gate.sweep.DAYS = 730`, `HOLDOUT_DAYS = 180`.
- `gate.search.run("G100", market, ledger, campaign, seed)`: the searcher, 100 evaluations, every one in the ledger. `gate.search.Evaluator` streams programs through `mm eval` and returns the disclosed `sharpe_annualized`.
- `gate.agent.harness.run_agent(market, ledger, campaign, run_dir)`: one agent session under the frozen harness, model `claude-opus-5-5`. Its run record has `spent`, `stopped`, `exit` and `transcript_sha256`.
- `gate.agent.campaigns.evaluations_made`, `wait_for_room`, `windows`: evaluations in a ledger, and pacing on the subscription accounts.

## Definitions the tests rest on

Constants, all in one place (`gate/control/constants.py`) and all copied into the manifest:

| Name | Value | Reason |
|---|---|---|
| `PAIRS` | 32 | Architecture 5.1 |
| `MAJORITY` | 24 | A chance of one half passes with probability 0.0035 |
| `SHARE` | 0.5 | Half the reference's effect |
| `THETA1` | 0.7 | The sign test's alternative |
| `ALPHA`, `BETA_ERROR` | 0.05, 0.05 | Nominal errors |
| `MAX_MARKETS` | 100 | The human, 2026-11-11 |
| `BAND` | 0.13 to 0.17 | G100's calibrated rate |
| `PLANTED` | coins 0 to 5 of 12 | A choice: half the coins, so each market keeps unplanted coins that wall 1 can compare |
| `MAX_VOIDS` | 3 | Architecture 5.2 |

- **Ids.** A study market is `control-1-m000` to `control-1-m099`. Its fresh pairs are `<market id>/fresh/0` to `/fresh/31`. Calibration markets are `control-1-cal-a-000` to `-399` and `control-1-cal-b-0000` to `-1999`. Wall 3's markets are `control-1-blind-000` to `-199`. No two sets share an id, so none shares a seed.
- **A market at strength `b`** is `generate("N2", params, id, 730, PLANTED, b)` written with 180 holdout days and the series' cost cells. **Its twin** is the same call with strength 0.
- **A program's score on a market** is the `sharpe_annualized` that `mm eval` discloses for it on that market's search period, in a scratch ledger. A program that the kernel rejects, or whose disclosure lacks the statistic, has no score.
- **A program's effect on a pair** is its score on the planted market minus its score on the twin. It is undefined when either score is missing or not finite.
- **A program wins a pair** when its effect and the reference's are both defined, the reference's is positive, and the program's is at least `SHARE` times the reference's.
- **A program earns from the plant on market `m`** when it wins at least `MAJORITY` of `m`'s `PAIRS` fresh pairs.
- **A session's pick** is, among the programs that session evaluated on its study market, the one with the highest disclosed search-period `sharpe_annualized`. Ties go to the earliest evaluation. A program with no disclosed statistic is not a candidate. A session with no candidate has no pick, and that arm misses the market.
- **G100's seed on a market** is the first eight bytes, as an unsigned integer, of `sha256("<manifest seed>:<market id>:G100")`.

## Step 0. The criterion (the advisor, before step 7)

`CLAUDE.md` asks that a condition judging a number be pre-registered. The study has one. The advisor has this draft reviewed and commits it alone, as `criteria: study 1`, before any G100 run or session on a study market. Steps 1 to 6 are model-free tooling and may be built first.

> **CS1.1.** Claim: on synthetic N2 markets carrying a planted funding edge at the manifest's strength, the frozen agent's session ends on a program that earns from the plant with a higher chance than G100's 100 evaluations do. Judged by Wald's sequential sign test on discordant markets, `θ ≤ 1/2` against `θ = 0.7`, nominal errors 5%, in the manifest's order, ending at 100 markets. Met when the upper boundary is crossed. The lower boundary and the end at 100 markets are reported as "not shown" and "inconclusive", never as "no better". Definitions: this file's, by commit hash. Size at most 0.043 by exact enumeration (`audit/program/arithmetic.py.txt`, `sign_test`).
> - *Passes while the claim is false:* only by chance, at most 0.043, or by a measure that pays something other than the plant. Wall 3 bounds the second before any session.
> - *Fails while the claim holds:* an agent at 0.3 against G100 at 0.15 ends without the claim with probability 0.33 to 0.43, unless the arms' successes overlap almost entirely. The study states that it is not powered there.

Everything else in this plan is a test or a wall, not a criterion.

## Step 1. Markets and twins (`gate/control/pairs.py`)

Behaviour:
1. `harness_hash()` begins `6a335714`.
2. `fresh_ids(m)` returns the 32 ids `m/fresh/0` to `m/fresh/31`, in order.
3. `arrays(id, b)` returns `generate` for the study's model, parameters, days and `PLANTED`. Called twice with the same arguments it returns equal arrays.
4. **Wall 1, as a test.** For 20 ids and a positive strength, between `arrays(id, b)` and `arrays(id, 0)`: funding, premium and volume are equal for every coin; open, high, low and close are equal for every coin not in `PLANTED`; and the close differs somewhere for every coin in `PLANTED`.
5. `write_pair(root, id, b)` writes the planted market and the twin under two directories of `root` and returns both paths. A market whose id contains `/` is written without error.
6. Two different ids give different funding arrays.

## Step 2. The measure (`gate/control/measure.py`). Judged: tests by another model

Two layers. The pure layer takes numbers and is tested exhaustively; the kernel layer is thin.

Pure behaviour, `classify(pick, reference)`, each argument a list of 32 `(planted score, twin score)` with `None` for a missing score:
1. It returns the count of pairs won and whether that count is at least 24.
2. A pair is won exactly when the definition above says so. Tests cover: an effect equal to half the reference's (won); just below (lost); a reference effect of zero or below (lost, whatever the pick's); a missing or non-finite score on either side of either program (lost); a pick with a large positive effect where the reference's is negative (lost).
3. 23 pairs won is false; 24 is true.
4. Adding the same number to a program's two scores on a pair changes nothing.
5. A list that is not 32 long is an error.

Kernel behaviour:
6. `score(program, market)` returns the disclosed statistic, or `None` for a program the kernel rejects. Scoring the same program on the same market twice gives the same number. It writes to a scratch ledger, never to a study ledger.
7. `scores(program, pairs)` returns the 32 score pairs for a list of fresh pairs.
8. A program that never trades has equal scores on a market and its twin, or none on both.
9. On a market at strength zero, a program's effect on every pair is exactly zero: the planted market and the twin are the same market.

## Step 3. The pick (`gate/control/pick.py`)

Behaviour:
1. From a ledger holding one campaign's evaluations by one agent, `pick` returns the program with the highest disclosed search-period `sharpe_annualized`, as JSON the kernel accepts.
2. Re-scored on the same market with step 2's `score`, the pick's score equals the ledger's.
3. Two programs with equal scores: the earlier evaluation is returned.
4. Evaluations without a disclosed statistic are ignored. A ledger with none returns `None`.
5. The function is the same for both arms: after `search.run("G100", …)` it returns a program among G100's 100, and no evaluated program has a higher disclosed score.
6. It reads only the campaign and agent it is given, in a ledger that holds two.

## Step 4. The reference and the funding-blind set (`gate/control/programs/`)

Locked DSL programs, each a JSON file, each hash in the manifest.

- **The reference** holds, on every coin and every bar, a position in the direction of the plant's signal and proportional to it: short when the coin's funding four hours before the bar is above `1.25e-5`, long when below, at full size from a distance of `1e-4`. It uses only inputs available at the bar's decision time. If PC2's reference program on branch `positive-controls` meets the tests it is reused.
- **The funding-blind set,** seven programs: constant long and constant short on every coin, each at the highest leverage the DSL allows; momentum and reversal on the last day's close-to-close return; one fixed pseudo-random position a coin at three leverages (lowest, middle, highest).

Behaviour:
1. Every program type-checks in the frozen kernel and has a score on a calibration market.
2. No funding-blind program reads funding or premium: the test walks each program's JSON and finds no such input.
3. On 50 calibration pairs at a strength of 0.005, the reference's effect is positive on at least 45. This is a smoke check; wall 2 judges the reference at the study's strength.

If no DSL program can express the reference with inputs the kernel allows at decision time, that is a wall.

## Step 5. Calibration and the model-free walls (`gate/control/calibrate.py`)

Entry point `python -m gate.control.calibrate`, a batch job (`ops/jobs.py`), writing `audit/control-1/calibration.json` and one JSON line a market as it goes, so a stopped run resumes without recomputing.

- **G100's rate at strength `b` on a set of markets** is the share on which G100's pick earns from the plant: per market, the market at `b`, G100 with its derived seed, the pick, the 32 fresh pairs at `b`, the pick and the reference classified.
- **Bisection.** Bracket `[0, 0.01]`. Eight steps on the same 400 markets `cal-a`: evaluate the midpoint, and move the upper end down when the rate is above 0.15, otherwise the lower end up. The same markets at every step make the rate one fixed function of strength.
- **The strength** is the last midpoint. Its rate is then measured on the 2,000 markets `cal-b`.

Behaviour, on a stub rate function, without the kernel:
1. For a rising function crossing 0.15 inside the bracket, the result is within `0.01 / 256` of the crossing.
2. The rate at the bracket's upper end is evaluated first, on `cal-a`. At or below 0.15 there, the run stops and reports wall 4 failed: no strength in the bracket reaches the target.
3. A stopped run, restarted, evaluates no market twice and returns the same strength.

The walls, reported in `calibration.json` with their counts. Each is a pass or a stop, and a stop goes to the architect:
- **Wall 2.** Over the `cal-b` pairs, the reference's effect is positive on at least 95%.
- **Wall 3.** Each funding-blind program is classified, as if it were a pick, on the 200 `blind` markets at the strength. At most 14 of the 1,400 classifications earn from the plant.
- **Wall 4.** G100's rate on `cal-b` is inside `BAND`.

4. The report holds, for each wall, the count, the denominator and pass or stop; a test builds each from stub scores on both sides of its threshold.
5. Before the first kernel run the job times 20 evaluations and prints the projected time for the whole job: nine strengths on 400 markets and one on 2,000 at 228 evaluations a market, 1,276,800, plus wall 3's 102,400.

## Step 6. The sequential rule (`gate/control/sequential.py`). Judged: tests by another model

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

## Step 7. The manifest and the searcher's arm (`gate/control/manifest.py`)

`audit/control-1/manifest.json`, written once after step 5 passes, then committed alone. It holds: the seed; the 100 market ids in order; `PLANTED` and the strength; every constant above; the hashes of the kernel binary, the harness, the funding blob and N2's parameters; the reference's and the funding-blind programs' hashes; the hash of `gate/control/`; the pinned model id; `calibration.json`'s hash.

Behaviour:
1. Writing a manifest where one exists is an error.
2. `verify()` recomputes every hash and fails naming the first that differs. Every entry point of steps 7 to 9 calls it first.
3. After the manifest's commit and CS1.1's, `python -m gate.control.searcher` runs G100 on each study market in a ledger of its own, classifies its pick, and appends one line a market to `audit/control-1/searcher.jsonl`: the id, the seed, the evaluations spent, the pick's hash, its count of pairs won, the reference's median effect, and whether it earns.
4. It refuses to run when a study market has an agent run directory: G100's arm is complete before the first session.
5. Run twice, it gives the same file.

## Step 8. The runner (`gate/control/runner.py`)

Entry point `python -m gate.control.runner`, one market at a time in the manifest's order, on the TAMU and Cornell accounts through `wait_for_room`, never the personal account. For market `i`:

1. Write the market at the strength. Run `harness.run_agent` with a ledger and run directory of that market's own. G100's ledger for the market is not readable from the session.
2. **Void.** The session is void when the harness exits non-zero and the ledger holds no evaluation by it. Its directory is kept under a numbered name and the market is run again. Three voids on one market stop the runner with the state "paused", and a restart resumes at that market.
3. **Model.** Every model id in the session's transcript is recorded. If any differs from the manifest's, the session is not counted, the runner stops with the state "model changed", and no later market runs.
4. Every other session counts: no pick is a miss; a session cut off after an evaluation is judged on its pick.
5. Classify the pick on the market's fresh pairs with the reference. Append one line to `audit/control-1/results.jsonl` and flush it to disk before anything else happens: the id, the run record, the model ids, the evaluations spent, why the session stopped, the pick's hash and count of pairs won, the reference's and the pick's median effects, whether each arm earns, the outcome, the running wins and losses, and the decision.
6. Stop at `claim`, `futility` or `undecided`. With `continue`, go to market `i + 1`.

Behaviour, with the harness and the kernel replaced by stubs in tests:
1. A sequence of stub outcomes produces the decisions step 6 gives, and the runner launches no session after a stop.
2. A void session is rerun on the same market, and its outcome is not in `results.jsonl`. The third void pauses.
3. A session with a non-zero exit and one evaluation is judged, not rerun.
4. A foreign model id stops the study, and the market has no result line.
5. **Killed between a session's end and its result line** (the test kills the process): on restart the session is not run again, the pick is classified from the kept ledger, and one line is written.
6. **Killed during a session:** on restart, a ledger with an evaluation is judged on its pick; a ledger with none is a void.
7. A market with a result line is never run again, and `results.jsonl` is never rewritten, only appended.
8. A session's working directory holds no file of another market, of G100's arm, or of `audit/control-1/`.
9. `verify()` failing stops the runner before any session.

## Step 9. The report (`gate/control/report.py`)

`python -m gate.control.report` writes `audit/control-1/report.md` from the manifest, `searcher.jsonl` and `results.jsonl`, and reads nothing else.

Behaviour:
1. It states the decision and the name architecture 5.4 gives it, word for word, and never "no better".
2. Each arm's rate with its exact (Clopper-Pearson) 95% interval; the discordant counts; the power table's row nearest the observed rates.
3. Reported, never judged: each pick's count of pairs won by arm; each pick's median effect and the reference's; G100's pick among its first `k` evaluations, `k` being the agent's count on that market, classified the same way; evaluations used and why each session stopped; void sessions and their causes; every model id; evaluations that named an input N2 lacks.
4. Sessions run beyond the stop, if any, appear in a separate table and in no rate.
5. On a results file that ends "paused" or "model changed" it reports what there is and says the study has not ended.

## Before the first session

- A fresh session hunts bugs in `gate/control/` (`CLAUDE.md`, Correctness).
- Opus checks each commit against its step, and gives the last review before step 7's manifest commit.
- The advisor adds the runner's workload to `CLUSTER.md`.

## What the builder reports

For each step: the commit, and the tests' result. For step 5: the timing, the strength, and each wall's counts. Any wall, at the top.
