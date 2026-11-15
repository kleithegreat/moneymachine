# Brief 4: study 2, the positive control of the confirmer

Written 2026-11-15 09:34 UTC (04:34 EST) by Claude Fable 5.2, session "architect: study 1's calibration wall, kernel version 2's wording, study 2's criteria". The design is `audit/program/architecture.md` section 6, the draft criteria are CS2.1 to CS2.3 in `audit/program/criteria-notes.md`, and the engine and its instruments are brief 3's (`3-kernel-v2.md`). This brief orders what study 2 adds to them. **A draft for Argon and GPT:** nothing here is built until they have reviewed it with the criteria (`ledger.md`).

## What it rests on, and how every step runs

- **Brief 3, whole:** its steps 0 to 10 built and their ★ laws proved, layer 1 with no difference and layer 2's wall with no failure (architecture 6.5). Its table "What the recorders must hold for the forward run" is this study's too, and the items it marks "add" are the advisor's.
- **Trades for the archive's dates** (`node_trades`), certified and on disk. Without them nothing before the freeze runs under `pessimistic`, and that is a blocker (architecture 6.4).
- **Every step runs as brief 3's do:** tests first by a session that does not build the step, from this brief alone; the builder makes them pass unedited, in one commit; a wall goes to the architect; Opus checks the commit. Steps marked **◆** decide a judged result, so their tests are another model's.
- **Binding:** maximal Lean, OCaml for the rest, no Rust or Python. The replica is data, a program in the kernel's JSON. Academic: no order is ever sent.
- **Data a builder may read:** the archive and the vault's fills dated before 2026-11-01, and in step 3 only those before 2026-09-01. Nothing dated in [2026-11-01, 2027-01-31) before its release, which the executable enforces (kernel A13).
- **Layout:** `kernel2/lean/Engine/Study2.lean` for step 1; `study2/` for the rest, a dune project with the executable `study2` and the replica's program `study2/replica.json`; the registration and the reports under `audit/study2/`.

## The order

| | Step | Decides | Needs |
|---|---|---|---|
| 0 | The criteria, committed alone | what will be judged | the review of this brief and the notes |
| 1 | ◆ The two verdicts, in Lean | CS2.2, CS2.3, the guard's refusal | brief 3, step 0 |
| 2 | The ladder | the replica | brief 3, step 5 |
| 3 | The trigger, and its check on two months held back | the replica | steps 1 and 2; brief 3, step 6 |
| 4 | ◆ The replay before the freeze | whether rung 2 is registered | step 0; brief 3, step 10 |
| 5 | The bootstrap | `φ` and `d`; the forecast | step 4 |
| 6 | The registration: the freeze | everything after it | steps 1 to 5 |
| 7 | ◆ The forward replays and the report | the three results | step 6; the release of 2027-01-31 |

Steps 1 and 2 can be built beside brief 3's later steps. Step 0 comes before step 4 runs, because the replay judges the guard's refusal.

## The steps

### 0. The criteria (the advisor)

After Argon's and GPT's review of `criteria-notes.md`, CS2.1 to CS2.3 are committed alone as `criteria: study 2`, with the commit of this brief and of `architecture.md` that they name. Before step 4 reads a price.

### 1. ◆ The two verdicts, in Lean (CS2.2, CS2.3, architecture 6.5)

- **Builds,** as pure functions of `Engine`, exported like `confirm`:
  - **`matched`,** from two lists of entries (a coin and a time in milliseconds) and a window, to the size of the largest set of pairs, one entry of each list, of one coin and at most the window apart, no entry in two pairs;
  - **`held`,** from two lists of a ledger's wealth at days' ends, the replay's and the forward run's, each beginning with the 1 it started from, to "held", "did not hold" with the ratio, or "not judged";
  - **`refused`,** from the wealth over the bar of each of the guard's rules at the replay's last day's end, and the replay's count of days, to whether rung 2 is refused.
- **The tests must show:**
  1. **A window includes its end:** entries of one coin at 0 and at 360,000 ms match under a window of six minutes, and at 360,001 they do not. Entries of two coins never match.
  2. **No entry is in two pairs:** one entry of the vault's at 0 and two of the replica's at five minutes before and after give 1.
  3. **The count is the largest there is:** the vault's at 0 and 7 minutes and the replica's at 5 and 13 give 2. A function that pairs nearest first gives 1, and fails. On random lists of up to eight entries a side the count equals that of a search over every set of pairs, and it does not depend on the order of either list.
  4. **`held` is exact:** a day's return is its wealth over the wealth before, less one, a rational; the two mean squares are compared by cross-multiplying. A ratio of exactly 1/2 and one of exactly 2 hold. One of `2 + 10⁻⁴⁰` does not, and the ratio is returned.
  5. **What is not judged:** a forward list of 211 days; a wealth of zero on either list, which is a ledger that ended. 212 days are judged.
  6. **`refused` is exact:** a rule is on course when its wealth over the bar, raised to the 730th power, is at least 20 raised to the replay's days. Over 212 days a rule at `239/100` refuses and one at `238/100` does not; four rules of which one is on course refuse.
- **Laws ★:**
  - **M1** `matched` returns the size of a set of pairs that meets its three conditions, and no such set is larger.
  - **M2** `held` returns "held" exactly when both lists are judged and the forward mean square is from half the replay's to twice it.
- **Foreseeable walls:** none.

### 2. The ladder (architecture 6.1; `facts-kernel-v2.md`, section 7)

- **Builds:** `study2/replica.json` without its trigger: for each coin of the universe, a first buy of a constant notional, five resting buys below the first fill, and one take-profit above the cycle's average entry. The header's leverage is 1.
- **Its constants** are read off the vault's fills before 2026-09-01: each level's price against the first fill's and its size in coins against the first buy's, and the take-profit's distance. The facts give them to three or four digits (levels at 2.25, 3.54, 5.04, 7.00 and 9.85% below; sizes of 1, 1.93, 3.80, 7.47 and 14.68 first buys; the exit 0.56% above). The builder fixes the digits and the anchor that reproduce the most orders exactly: the first order's limit or its fills' mean, and the rounding to the grid.
- **The tests must show:**
  1. On a synthetic market in which a first buy fills, the trace holds five resting buys at the constants' prices on the coin's grid, rounded down, and sizes in whole lots, rounded toward zero, and one sale of the whole position at the take-profit's price, rounded up.
  2. When a level fills, the take-profit moves to the new average entry's price and is one order for the whole position. When it fills, the cycle ends, every level is cancelled, and nothing of the old cycle fills after (kernel A6).
  3. Starting cash covers every coin's full ladder at once: on a market where all 17 coins fall through every level together, no order is refused for margin, and the account's cash is never negative before funding.
  4. **The ladder given real first buys (D14):** for each of the vault's cycles from 2026-09-01 to 10-31, a synthetic market in which the replica's first buy fills at the real first buy's price and size. The test prints, by level, how many of the real level orders have the replica's price exactly and how many its size exactly, and the same for the exits. It asserts only that every real cycle is counted in one class.
- **Not replicated, and counted:** levels beyond the fifth (9 cycles), the vault's exits other than the take-profit (97 fills), a first buy whose size is not the constant notional.
- **Foreseeable wall:** an anchor or a rounding the language cannot say. It goes to the architect.

### 3. The trigger, and its check on two months held back (architecture 6.4, layer 3; CS2.3)

The trigger is the one part of the replica found through data, so it is fitted on one span and checked on another before the freeze, and judged only forward.

- **The fit.** One builder session, in a directory that holds the vault's fills and the archive dated before 2026-09-01 and nothing later. It writes the trigger into `study2/replica.json`: when a flat coin's first buy is wished, at what price and as what kind of order. It may use any input of kernel A5 and try anything on its span. It reports what it tried.
- **The check.** Another session runs the replica from a flat account under `optimistic` on [2026-09-01, 2026-11-01) and gives `matched` the replica's entries and the vault's there, at a window of six minutes.
- **The tests must show:**
  1. The check's runner on a synthetic vault: a replica that enters with each of its entries gives both shares 1; one that never enters gives 0 of the vault's; one that enters every minute matches every entry of the vault's and a small share of its own.
  2. An entry is a cycle's first fill, a partial one included, and a cycle's later fills are none.
  3. The fit's directory holds no file dated from 2026-09-01 on: the test lists it.
- **A wall, not a criterion:** on the months held back, the matched count is more than half of the replica's entries and more than half of the vault's. If not, the shares by coin and by week go to the architect before anything is registered. A second fit after a failed check has seen the months held back, and the registration says so.
- **Foreseeable walls:** a trigger that needs an input the language does not have; first buys that are orders resting long before they fill, so that entries match poorly under any trigger (the notes' second doubt). Both go to the architect.

### 4. ◆ The replay before the freeze (architecture 6.5)

- **Builds:** `study2 replay`, which runs the replica over the archive from 2026-04-03 to 10-31 under `pessimistic` and under `optimistic`, and a program with no slots at a tick of a minute for the guard's trace; then `confirm` for each of the 30 pairs of `φ` and `d`, the guard's best mix at each of the four clocks, and `refused`.
- **The tests must show,** on synthetic markets:
  1. One engine run serves every pair: the 30 results come from one report, and each equals `confirm` called alone with that pair.
  2. The table holds, for each pair, the wealth at every day's end, the days on which a ledger ended, and its volatility and Sharpe; and once, the least return of any settlement, the bar with its multipliers, each guard rule's wealth over the bar, the count of taker fills near an earlier one, and the same under `optimistic` and at the second pair of delays.
  3. The refusal: on brief 3's market of pairs every five minutes, run for long enough, `refused` is true and the table says which clock; on its market astride the minute it is false.
  4. Two runs of one identity give equal tables, and each run has its two ledger rows (kernel A13).
- **What it decides:** whether rung 2 is registered. Nothing else here has a pass mark. The table goes to the architect with the walls of architecture 6.5.
- **Foreseeable wall:** the guard's trace of minute ticks over 212 days (brief 3, step 10).

### 5. The bootstrap (architecture 6.3; D45)

It forecasts power and chooses `φ` and `d`. It judges nothing: every pair is valid (law K1), and CS2.2 is judged by `held`.

- **Builds,** in OCaml: from the replay's table, for each pair, paths of 730 days made of the replay's days.
  - **A path** is 53 blocks of 14 consecutive days of the replay, the last cut to 2, each block starting at a day drawn evenly from all of them and running past the last day to the first. The draws come from a registered seed and are the same for every pair.
  - **Why blocks of 14 days.** The vault's longest cycle is 10.6 days, so a cycle's days stay together, and two whole weeks keep the week in phase. The table of step 4 is also resampled at 7 and 28, reported beside.
  - **On a path,** a pair's wealth is the product of its days' factors. The bar is `confirm`'s own, on coin rows chained from the same days: prices by their days' ratios, funding in proportion to the price, the three sums added, the least return kept. Rung 1 is reached where the wealth is 20 or more at a day's end, rung 2 where it is 20 times the bar or more.
  - **The forecast:** each rung's share of 10,000 paths, for each pair; and for CS2.2's ratio, the 0.025 and 0.975 quantiles of a path's mean square over that of a second, independent draw of the replay's own length.
  - **The choice:** the pair with the greatest share at the top registered rung; ties to the greatest wealth at the replay's end, then the smaller `φ`, then the smaller `d`. A pair whose ledger ended on the replay is never chosen.
- **The tests must show:**
  1. A seed gives the same paths every time. Over every starting day, each day of the record stands at each place of a block equally often.
  2. **Exact cases.** A record whose every day returns `r`: every path reaches 20 when `(1 + r)^730 ≥ 20` and none does below it. A record whose days all return nothing but one, whose wealth multiplies by 20: the share of paths that reach 20 is within three standard errors of `1 − (1 − 14/D)^52 (1 − 2/D)`, `D` the record's days.
  3. A record in which no coin moves has a bar of 1 on every path, so the two rungs' shares are equal. One in which a coin doubles every day has no path at rung 2.
  4. The interval of a record whose daily returns all have one size is the point 1. It is the ratio of two draws: on 400 simulated records of independent days it covers the forward ratio in 0.90 to 0.97 of them, and an interval made of the forward draw alone, which covers 0.65, fails.
  5. The choice, on tables built on each side of each tie; a pair whose ledger ended is passed over though its share is the greatest.
- **Foreseeable wall:** 10,000 paths of 730 days through `confirm`'s bar. If they do not finish within a day on one host, report the time. The answer I foresee is fewer paths, since 1,000 give a share of 0.05 to within 0.007, and not a second bar in floats.

### 6. The registration: the freeze (CS2.1 to CS2.3, "the registration")

- **Before it:** the walls of architecture 6.5; step 3's wall; one fresh session's hunt for bugs in brief 3's code and this brief's (`CLAUDE.md`, Correctness).
- **It holds:** the engine's build and the protected-windows file's hash; the hash of `study2/replica.json`; the universe, the vault's 17 coins; the venue, `pessimistic`, with its delays, staleness length, cap and minimum; the first buy's notional and the starting cash; `φ` and `d`; whether rung 2 is registered, with step 4's table; the guard's four clocks; the replay's report's hash, from which `held` reads the record's wealth; the bootstrap's seed, its forecast and its interval; step 2's and step 3's counts; how many registrations came before.
- **The delays** `λ` and `δ` are each the first whole second at or above the slowest cadence of quotes in the forward record, since an account that reacts faster than the record resolves reacts to an order of events the record does not hold. A second pair, of five times each, is run beside and judges nothing (V9).
- **Reviewed** as a decision that cannot be undone: two fresh reviewers, a Claude session and GPT, without the architect's conclusion, then Opus's last review. Then one commit, `registration: study 2`, pushed that day.
- **The test must show:** `study2 forward` refuses to run without a registration, and with one whose hashes do not match the files.

### 7. ◆ The forward replays and the report (architecture 6.6; CS2.1 to CS2.3)

- **Builds:** `study2 forward`, run once a month from February 2027: it fetches settled funding for the judged days, runs the replica from the first judged midnight on the recorder's record, runs `confirm` at the registered pair, the guard on the judged record, and layer 2's measurement on the vault's forward fills; at its first run, CS2.3; at the test's end, CS2.2; and writes the report.
- **The tests must show,** on synthetic forward records:
  1. A record on which the wealth first reaches 20 at day 40 is "earned" at day 40 in the run of any later month, and each later run names the same day. With rung 2 registered and reached at day 90 the test is "outgrew" at day 90 and no later day is run. With rung 2 not registered no run says "outgrew".
  2. A day before the first judged midnight changes nothing: two records equal from that midnight on give equal reports.
  3. A missing hour of settled funding aborts the run. A gap in the recorder's streams is staleness, in which nothing fills, and the report gives its length.
  4. CS2.3 is judged on [2026-11-15, 2027-01-31) UTC from a flat account under `optimistic`, once: a second call returns the first result. Fewer than 100 entries of the vault's are "not judged".
  5. **The report's sentences are the criteria's.** A claim's sentence holds the venue's rule and delays and "assuming our orders move nobody"; "outgrew" holds its limit and the guard's greatest figure on the judged record, and where that is 20 or more, that the record rejected the null without the rule. A non-rejection is "not confirmed" and holds none of "no edge", "no skill" or "skill". Without CS2.3 met, the rule is called "a rule fitted to the vault's record".
  6. A non-rejection's report holds `W`, the bar and its multipliers, the guard's figures, the equal-weight basket's wealth and BTC's, the ledger's volatility and Sharpe with the bootstrap's interval, the basket's own ratio of volatilities, and the power row (architecture 6.1).
- **Foreseeable walls:** the recorder's volume fills about 2027-05-20 and the human has deferred the choice (architecture 6.8); then the test ends by a dated decision and is never run over the gap.

## What the builder reports

For each step: its commit, its tests' count, the walls met. For steps 2 to 5 also their tables, which the registration holds.
