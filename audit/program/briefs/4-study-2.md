# Brief 4: study 2, the positive control of the confirmer

Written 2026-11-15 09:34 UTC (04:34 EST) by Claude Fable 5.2, and revised by it at 2026-11-15 19:17 UTC (14:17 EST) after round 1 by GPT and Argon (`ledger.md`), at 2026-11-15 19:48 UTC (14:48 EST) for the wealth at the bid (the human, `audit/decisions.md`), and at 2026-11-16 01:27 UTC (2026-11-15 20:27 EST) after the confirming read and the human's decision that CS2.2 reads the wealth at prices. The design is `audit/program/architecture.md` section 6, the draft criteria are CS2.1 to CS2.3 in `audit/program/criteria-notes.md`, and the engine and its instruments are brief 3's (`3-kernel-v2.md`). This brief orders what study 2 adds to them. **A draft:** nothing here is built until the criteria are committed.

## What it rests on, and how every step runs

- **Brief 3, whole:** its steps 0 to 10 built and their ★ laws proved, layer 1 with no difference and layer 2's wall with no failure (architecture 6.5). Its table "What the recorders must hold for the forward run" is this study's too, and the items it marks "add" are the advisor's.
- **Trades for the archive's dates** (`node_trades`), certified and on disk. Without them nothing before the freeze runs under `pessimistic`, and that is a blocker (architecture 6.4).
- **Every step runs as brief 3's do:** tests first by a session that does not build the step, from this brief alone; the builder makes them pass unedited, in one commit; a wall goes to the architect; Opus checks the commit. Steps marked **◆** decide a judged result, so their tests are another model's.
- **Binding:** maximal Lean, OCaml for the rest, no Rust or Python. The replica is data, a program in the kernel's JSON. Academic: no order is ever sent.
- **Data a builder may read:** the archive and the vault's fills dated before 2026-11-01, and in step 3's fit only those before 2026-09-01. Nothing dated in [2026-11-01, 2027-01-31) before its release, which the executable enforces (kernel A13).
- **Two valuations of one ledger** (architecture 6.1). `Wᵇ`, the wealth at the bid, is what the two rungs compare and what the bootstrap forecasts them by. `W`, the wealth at prices, is what `held` reads (CS2.2; the human, 2026-11-15) and what the proof speaks of. A table gives both, and no step says "the wealth" of one without naming it. The guard's rules and the bar read no bid.
- **A day's end** is the report's (`KERNEL.md` A19): the world after every event before that midnight and before any stamped with it. `confirm`, `guard` and every table read it there.
- **Nothing is chosen after a price is read.** The venue, the first buy, the starting cash, the pairs of `φ` and `d`, the rule that chooses among them, the bootstrap's draws and the guard's rules are all fixed below. A builder who finds one of them wrong stops and asks; none is tuned.
- **Layout:** `kernel2/lean/Engine/Study2.lean` for step 1; `study2/` for the rest, a dune project with the executable `study2` and the replica's program `study2/replica.json`; the registration and the reports under `audit/study2/`.

## The venue and the account

One venue, for every run before the freeze and after it.

| | Value | Why |
|---|---|---|
| Fill rule | `pessimistic` | architecture 6.1 |
| `λ`, `δ` | 1,000 ms each | The engine's least tick (kernel A4), and the first whole second at or above the recorder's design cadence of 0.55 s (`recorder/RECORDER.md`). Read from the recorder's specification and from no record. Nothing checks an account's delays (V9) |
| A second pair | 5,000 ms each | Run beside, and judges nothing (V9). It is near the archive's slow spacing of quotes, 5.4 s |
| Staleness `G` | 60,000 ms | The guard's tick: eight times the widest spacing of the archive's quotes on the days sampled outside its gaps, 7.6 s |
| Cap, minimum | 10,000 and 10 USD | kernel A6 |
| First buy | 100 USD | Level 1, 0.978 of it, meets the minimum from 10.22; a full ladder's close, 27.79 of it, stays under the cap up to 359.9 (`arithmetic.py.txt`) |
| Starting cash | 50,000 USD | 17 full ladders are 46,976 |
| Leverage | 1 | architecture 6.2 |

On the archive's slow period an order meets the first book after it, up to 5.4 s on, as A7 says of any order. Step 4's table is given by the archive's three periods of cadence as well as whole.

## The order

| | Step | Decides | Needs |
|---|---|---|---|
| 0 | The criteria, committed alone | what will be judged | the confirming read of this brief and the notes |
| 1 | ◆ The verdicts, in Lean | CS2.2, CS2.3, the guard's rules and its refusal | step 0; brief 3, step 0 |
| 2 | The ladder | the replica | step 0; brief 3, step 5 |
| 3 | The trigger, and its check on two months held back | the replica | steps 1 and 2; brief 3, step 6 |
| 4 | ◆ The replay before the freeze | whether rung 2 is registered | brief 3, step 10 |
| 5 | The bootstrap | `φ` and `d`; the forecast | step 4 |
| 6 | The registration: the freeze | everything after it | steps 1 to 5 |
| 7 | ◆ The forward replays and the report | the three results | step 6; the release of 2027-01-31 |

Step 0 is first: no other step of this brief starts before the criteria are committed (`CLAUDE.md`, Pre-registered criteria). Steps 1 and 2 can then be built beside brief 3's later steps.

## The steps

### 0. The criteria (the advisor)

After the confirming read of `criteria-notes.md`, CS2.1 to CS2.3 are committed alone as `criteria: study 2`, with the commit of this brief and of `architecture.md` that they name.

### 1. ◆ The verdicts, in Lean (CS2.1 to CS2.3, architecture 6.5)

- **Builds,** as pure functions of `Engine`, exported like `confirm`:
  - **`entries`,** from a report's rows and a span of time, to the fills that find their coin's position at zero: each `flow` row of a fill whose `before` is zero and whose `time` is in the span, as its coin and its time;
  - **`matched`,** from two lists of entries and a window, to the size of the largest set of pairs, one entry of each list, of one coin and at most the window apart, no entry in two pairs;
  - **`held`,** from `confirm`'s results on the replay and on the forward run (each one's `W` at its days' ends and the day its ledger ended, if it did), to "held", "did not hold" or "not judged" with its reason, and the two variances. It reads the forward run's first 212 days and the replay's every day, and of a ledger's end only whether it fell on one of those days. It reads no `Wᵇ`. A day's return is its `W` over the `W` before, less one, the first from 1; a variance is of a list of returns about its own mean, divided by its count;
  - **`rules`,** from a report's coin rows at a day's end, to the guard's two mixes for each span: equal weights over the span's coins; and the bar's own mix, each coin's weight in [0, 1] where its term of the bound is greatest at the least multiplier, the lesser at a tie, all divided by their sum when that is above 1. Each weight is then multiplied by 24/25;
  - **`refused`,** from the wealth over the bar of each of the guard's rules at each day's end of the replay, to whether rung 2 is refused: one of them is 20 or more at some day's end, or its 730th power at the last day's end is at least 20 raised to the count of days.
- **The tests must show:**
  1. **An entry is a first fill:** a cycle's first fill, a partial one included, is an entry and its later fills are none; a fill at the span's first millisecond is in and one at its last is out; a liquidation's or a settlement's row is none.
  2. **A window includes its end:** entries of one coin at 0 and at 360,000 ms match under a window of six minutes, and at 360,001 they do not. Entries of two coins never match.
  3. **No entry is in two pairs:** one entry of the vault's at 0 and two of the replica's at five minutes before and after give 1.
  4. **The count is the largest there is:** the vault's at 0 and 7 minutes and the replica's at 5 and 13 give 2. A function that pairs nearest first gives 1, and fails. On random lists of up to eight entries a side the count equals that of a search over every set of pairs, and it does not depend on the order of either list.
  5. **`held` is of the variance, exactly (GPT's finding 2).** The two variances are rationals and are compared by cross-multiplying. Replay returns of +0.01 and −0.01 in turn against forward returns of +0.03 and +0.01 in turn hold, though their mean squares are 5 apart. A forward variance of exactly half the replay's and one of exactly twice it hold. One of twice it and `10⁻⁴⁰` more does not, and both variances are returned.
  6. **What is not judged (GPT's finding 3, Argon's 2):** a forward list of 211 days; a ledger that ended, or a wealth of zero, within either list; a replay of no variance, whether the forward variance is zero or not. Each names its reason. A replay with variance and a forward list that never moved "did not hold". Of a forward list of 300 days the first 212 alone are read: changing a later day changes nothing, and a ledger that ended on day 213 is judged as one that never ended (Argon's F1).
  7. **`rules`:** every weight is at least zero, a span's weights sum to at most 24/25, and a coin that is not its span's has none. On brief 3's market of pairs the bar's own mix is 12/25 in each coin. Two coins with one return of 3 each, where the bound is greatest at both ends of a coin's term at once, give the lesser weight. On random sums no multiplier of a fine grid gives a lower bound than the one the mix is taken at.
  8. **`refused` is exact (Argon's finding 1):** over 212 days a rule that ends at `239/100` refuses and one at `238/100` does not; a rule that stood at 25 on day 10 and has nothing at the end refuses; four rules of which one refuses, refuse.
- **Laws ★:**
  - **M1** `matched` returns the size of a set of pairs that meets its three conditions, and no such set is larger.
  - **M2** `held` returns "held" exactly when both lists are judged and the forward variance is from half the replay's to twice it, and "not judged" exactly in the cases of test 6.
  - **M3** `refused` is true exactly when some rule meets one of its two conditions.
- **Foreseeable walls:** none.

### 2. The ladder (architecture 6.1; `facts-kernel-v2.md`, section 7)

- **Builds:** `study2/replica.json` without its trigger: for each coin of the universe, a first buy of 100 USD, five resting buys below the first fill, and one take-profit above the cycle's average entry. The header's leverage is 1.
- **Its constants** are read off the vault's fills before 2026-09-01: each level's price against the first fill's and its size in coins against the first buy's, and the take-profit's distance. The facts give them to three or four digits, over all seven months (levels at 2.25, 3.54, 5.04, 7.00 and 9.85% below; sizes of 1, 1.93, 3.80, 7.47 and 14.68 first buys; the exit 0.56% above). The builder fixes the digits and the anchor that reproduce the most orders exactly: the first order's limit or its fills' mean, and the rounding to the grid.
- **The tests must show:**
  1. On a synthetic market in which a first buy fills, the trace holds five resting buys at the constants' prices on the coin's grid, rounded down, and sizes in whole lots, rounded toward zero, and one sale of the whole position at the take-profit's price, rounded up.
  2. When a level fills, the take-profit moves to the new average entry's price and is one order for the whole position. When it fills, the cycle ends, every level is cancelled, and nothing of the old cycle fills after (kernel A6).
  3. **No order of a full ladder is refused (Argon's finding 4):** on a market where all 17 coins fall through every level together and then rise through their exits, the trace holds no `refused` row of any reason, every level and every exit fills, and the account's cash is never negative before funding.
  4. **The counter of test 5 counts:** a synthetic vault cycle generated from the constants is counted as exact at every level and at its exit; with one level a grid step lower it is counted as that level's price differing, and with one size a lot more as that level's size.
  5. **The ladder given real first buys (D14), a measurement:** for each of the vault's cycles from 2026-09-01 to 10-31, a synthetic market in which the replica's first buy fills at the real first buy's price and size. It prints, by level, how many of the real level orders have the replica's price exactly and how many its size exactly, and the same for the exits. Its passing shows that every real cycle was counted, and nothing about fidelity: the table does.
- **A wall, not a criterion:** at each level and at the exit, more than half of the real orders have the replica's price exactly, and more than half its size. If not, the table goes to the architect before the trigger is fitted.
- **Not replicated, and counted:** levels beyond the fifth (9 cycles), the vault's exits other than the take-profit (97 fills), a first buy whose size is not the constant notional.
- **Foreseeable wall:** an anchor or a rounding the language cannot say. It goes to the architect.

### 3. The trigger, and its check on two months held back (architecture 6.4, layer 3; CS2.3)

The trigger is the one part of the replica found through data, so it is fitted on one span and checked on another before the freeze, and judged only forward. The two months are held back from the fit and are not untouched: the facts' summaries, the six minutes among them, were computed over all seven months. CS2.3 is judged on days after the freeze, and nothing here stands in for it.

- **The fit's data.** `study2 export` writes the archive's events and the vault's fills with `time` before 2026-09-01 00:00 UTC (2026-08-31 20:00 EDT) into a fresh directory, through the engine's own admission under a horizon that ends there. The cut is by each record's `time`, never by a file's name.
- **The fit.** One builder session, started by the advisor where it can read the export, the executable and this repository's tracked files, and no other data: not the archive's directory, not the fills' file. No table or report of a run that read a date from 2026-09-01 on is committed before the check below has run: step 2's test 5 and brief 3's layers keep theirs under `data/` until then, so the fit does not meet them as tracked files (both reviewers, the confirming read). It writes the trigger into `study2/replica.json`: when a flat coin's first buy is wished, at what price and as what kind of order. It may use any input of kernel A5 and try anything on its span. It reports what it tried.
- **The fit's own wall.** On its span, under the venue, the matched count is more than half of the replica's entries and more than half of the vault's. A fit that cannot reach that goes to the architect, and the two months are not read.
- **The check.** Another session runs the replica from a flat account under the venue on [2026-09-01, 2026-11-01), takes `entries` of that run's report and of the vault's fills replayed through the ledger, and gives them to `matched` at a window of six minutes. The same under `optimistic` is printed beside.
- **The tests must show:**
  1. The check's runner on a synthetic vault: a replica that enters with each of its entries gives both shares 1; one that never enters gives 0 of the vault's; one that enters every minute matches every entry of the vault's and a small share of its own.
  2. **The export is cut by content (GPT's finding 9):** given a file named for August that holds a September record, the export holds no record with a `time` from 2026-09-01 on, and the test reads every record's `time`.
  3. **The fit cannot read past its span:** run inside the fit's own sandbox, opening the archive's directory and the fills' file each fails.
- **A wall, not a criterion:** on the months held back, under the venue, the matched count is more than half of the replica's entries and more than half of the vault's. If not, the shares by coin and by week, and those under `optimistic`, go to the architect before anything is registered. A second fit after a failed check has seen the months held back, and the registration says so.
- **Foreseeable walls:** a trigger that needs an input the language does not have; first buys that rest long before they fill, or that `pessimistic` credits late, so that entries match poorly under any trigger. Both go to the architect.

### 4. ◆ The replay before the freeze (architecture 6.5)

- **Builds:** `study2 replay`, which runs the replica over the archive from 2026-04-03 to 10-31 under the venue, under `optimistic` and at the second pair of delays, and a program with no slots at a tick of a minute for the guard's trace; then `confirm` for each of the 30 pairs of `φ` and `d`, `rules` at the last day's end, `guard` for each of the eight rules, and `refused`.
- **The 30 pairs.** `φ` is 1/16, 1/8, 1/4, 1/2 or 1. `d` is one of six depths: the notional, at the replica's own constants, of the first buy alone and of the first buy with its first one to five levels, each level's size times its price against the first fill's, in exact decimals times 100 USD (about 100, 198, 384, 745, 1,439 and 2,763 USD). At a depth of the first buy the ledger also follows a sliver of level 1, what lot rounding left of the first 100 USD: any depth is valid (law K1).
- **The tests must show,** on synthetic markets:
  1. One engine run serves every pair: the 30 results come from one report, and each equals `confirm` called alone with that pair.
  2. The table holds, for each pair, `Wᵇ` and `W` at every day's end, the day on which a ledger ended, and the volatility and Sharpe of each; and once, the least return of any settlement, the bar with its multipliers, each guard rule's wealth over the bar at every day's end, the count of taker fills near an earlier one, and the same under `optimistic` and at the second pair of delays.
  3. **The refusal:** on brief 3's market of pairs every five minutes, run for two days, `refused` is true by the bar's own mix at five minutes, and stays true when one coin charges 0.0001 a unit in the first hour, which ends a rule that kept no cash. With a charge a minute into the second day that the rule's cash cannot meet, it is true by the first day's end alone. **A day's end stands before its midnight (GPT's R1, Argon's F2):** with that charge stamped with the first midnight itself, the rule's figure at the first day's end is the one of the run cut back to that midnight, 20 or more, and the rule ends in the second day. On the market astride the minute it is false.
  4. Two runs of one identity give equal tables, and each run has its two ledger rows (kernel A13).
- **What it decides:** whether rung 2 is registered. Nothing else here has a pass mark. The table goes to the architect with the walls of architecture 6.5.
- **Foreseeable wall:** the guard's trace of minute ticks over 212 days (brief 3, step 10).

### 5. The bootstrap (architecture 6.3; D45)

It forecasts power and chooses `φ` and `d`. It judges nothing: every pair is valid (law K1), and CS2.2 is judged by `held`.

- **Builds,** in OCaml: from the replay's table, for each pair, 10,000 paths of 730 days made of the replay's days.
  - **A path** is 53 blocks of 14 consecutive days of the replay, the last cut to 2, each running past the replay's last day to its first. Block `j` of path `i`, both counted from 0, starts at the day whose place is the BLAKE2b-256 digest of the ASCII text `study2 bootstrap i j`, read as one whole number, most significant byte first, modulo the replay's days. No seed is registered, and the paths are the same for every pair.
  - **Why blocks of 14 days.** A choice: two weeks, and longer than the vault's longest cycle, 10.6 days, so that most cycles' days fall in one block. A block's edge can still cut a cycle, and a path does not keep the weekday. The forecast is also made at blocks of 7 and 28 days, reported beside.
  - **A day of the replay** gives a pair two numbers: its factor, `W` at its end over `W` at the end of the day before, the first from 1; and its share at the bid, `Wᵇ` over `W` at its end, which is from 0 to 1. A pair whose ledger ended on the replay, or was worth nothing at a day's end of it, has neither and no path.
  - **On a path,** `W` at a day's end is the product of the factors of its days so far, and `Wᵇ` is that `W` times that day's share at the bid. So a path's `Wᵇ` is never above its `W`, as on the record. A product of `Wᵇ`'s own factors is not that: a block that starts on the day after a bid was pulled takes the recovery without the fall, and on a book whose price never moved 0.197 of the paths reach 20 (GPT's R3, `arithmetic.py.txt`).
  - **A day's slice.** The report's coin rows hold running figures, since their span began (`KERNEL.md` A19): the count of events, the funding a unit paid and the three sums. A row adds its figure less that of the coin's row before it in the same span, or the whole figure where it is its span's first row. A day's slice of a figure is what the coin's rows after the day before's `day` row, up to its own, added. Each term of a sum was rounded before it was added (kernel A12), so a slice is exact. A day's price ratio is the coin's `price` in its `day` row over that in the day before's, and for the first day over the `first` of the coin's first row.
  - **The bar on a path** is `confirm`'s own, over one span of the coins that have a price in every day's rows of the replay; the forecast names any coin left out. Each such coin starts the path at its first price of the replay with figures of nothing. Each day of the path adds its slices of the count and of the three sums, moves the price by its ratio, and adds its slice of the funding times the path's price over the record's, which is one number at the day's start and at its end.
  - **The rungs on a path.** Rung 1 is reached where `Wᵇ` is 20 or more at a day's end, rung 2 where it is 20 times the bar or more. The bar is at least 1, so it is computed only where `Wᵇ` is 20 or more.
  - **The forecast:** each rung's share of the 10,000 paths, for each pair.
  - **The choice:** the pair with the greatest share at the top registered rung; ties to the greatest `Wᵇ` at the replay's end, then the smaller `φ`, then the smaller `d`. A pair with no path is never chosen.
- **The tests must show:**
  1. Two runs give the same paths. The digest of the empty text is the published one, and block 0 of path 0 starts where an independent computation of the digest says. Over 10,000 paths each day of a record of 212 starts a block within four standard errors of equally often.
  2. **Exact cases,** with every bid at its price. A record whose every day returns `r`: every path reaches 20 when `(1 + r)^730 ≥ 20` and none does below it. A record whose days all return nothing but one, whose `W` multiplies by 20: the share of paths that reach 20 is within three standard errors of `1 − (1 − 14/D)^52 (1 − 2/D)`, `D` the record's days.
  3. A record in which no coin's price moves and no funding is paid has a bar of 1 on every path, so the two rungs' shares are equal. One in which a coin doubles every day has no path at rung 2. A day's funding is scaled the same whether by the prices at its start or at its end.
  4. A coin with no price in some day's rows of the replay is left out of the bar and named.
  5. The choice, on tables built on each side of each tie; a pair whose ledger ended, and one worth nothing at a day's end, are passed over though their shares would be the greatest.
  6. **A day's slice (GPT's R2).** A coin that returns 0.01 on the first of 212 days and never moves again: its slices of the first sum are 0.01 and then nothing, and a path's first sum is 0.01 for each time it holds the first day, where the rows added as they stand give 7.3. A day with no event of a coin adds nothing to its count, its sums or its funding. Rows over three spans, one ending inside a day and one at a midnight, with first sums of 0.030, 0.007 and 0.001: the four days' slices are 0.010, 0.025, 0 and 0.003, and a span's row that stands after the last day's adds nothing (`arithmetic.py.txt`, `day_slices`).
  7. **A path's `Wᵇ` is never above its `W` (GPT's R3).** One coin held whole at a constant price, its bid a hundredth of a percent under it but for one midnight at a hundredth of the price: on every path `W` is 1 at every day's end, `Wᵇ` is at most 0.9999, and no path reaches a rung. A bootstrap that multiplies `Wᵇ`'s factors reaches 20 on about a fifth of the paths, and fails.
- **Foreseeable walls:**
  - 10,000 paths through `confirm`'s bar. If they do not finish within a day on one host, report the time to the architect. The count of paths is not the builder's to lower.
  - A replay with a return below minus one in any row has no bar from that day on (K2), and a slice does not say which day of a span held it. No path is made of such a replay: it goes to the architect.

### 6. The registration: the freeze (CS2.1 to CS2.3, "the registration")

- **Before it:** the walls of architecture 6.5; step 2's and step 3's walls; one fresh session's hunt for bugs in brief 3's code and this brief's (`CLAUDE.md`, Correctness).
- **What the freeze reads** is what it holds, below, and nothing dated from 2026-11-01 on. Of the recordings since then, the advisor reads only whether each recorder runs and where its gaps are (`CLAUDE.md`, Holdout). The vault's fills pulled since then are stored unread: no count of them, and no page of the vault's public record, is before anyone who decides whether or when to freeze, and the registration's reviewers check that its bundle and its entry in `audit/decisions.md` hold none (GPT's R5).
- **It holds:** the engine's build, which is the hash of its sources and of what compiles them, with the protected-windows file left out (kernel A13), and the windows that file holds; the hash of `study2/replica.json`; the universe, the vault's 17 coins; the venue, the first buy and the starting cash, as above; `φ` and `d`; whether rung 2 is registered, with step 4's table; the replay's report's hash and the variance `held` reads from it; the bootstrap's forecast; step 2's and step 3's counts; how many registrations came before.
- **Reviewed** as a decision that cannot be undone: two fresh reviewers, a Claude session and GPT, without the architect's conclusion, then Opus's last review. Then one commit, `registration: study 2`, pushed that day.
- **The tests must show (GPT's finding 10):** `study2 forward` refuses to run without a registration; with one whose build is not the executable's, any source but the protected-windows file having changed; and with a protected-windows file that differs from the registered windows by anything but the release of one of them: a window's start or end moved, a window added or taken away, a release undone (Argon's F3). With that file changed by such a release alone it runs, and reads the released days.

### 7. ◆ The forward replays and the report (architecture 6.6; CS2.1 to CS2.3)

- **Builds:** `study2 forward`, run once a month from February 2027. It fetches settled funding for the judged days it does not yet hold. It runs the replica from the first judged midnight to the last midnight the record reaches, and where the engine rejects the record or aborts at some time, again to the last midnight at or before that time. Over the days run it gives `confirm` at the registered pair, the guard's eight rules, and layer 2's measurement on the vault's forward fills; at the first replay with 61 days run, CS2.3; at the first with 212, CS2.2; and it writes the report. After "outgrew" it runs on until CS2.2 has been judged.
- **The tests must show,** on synthetic forward records run through the engine:
  1. A record on which `Wᵇ` first reaches 20 at day 40 is "earned" at day 40 in the replay of any later month, and each later replay names the same day. With rung 2 registered and reached at day 90 the test is "outgrew" at day 90 in every later replay. With rung 2 not registered no replay says "outgrew".
  2. **A crossing stands whatever follows (GPT's finding 11):** a record on which `Wᵇ` first reaches 20 at day 10 and a held coin's funding hour is missing on day 11 is "earned" at day 10, with ten days run and the engine's error in the report. A record whose first day cannot be run has no day run and names nothing.
  3. A day before the first judged midnight changes nothing: two records equal from that midnight on give equal reports.
  4. A gap in the recorder's streams is staleness, in which nothing fills, and the report gives its length.
  5. **CS2.3 is judged once, on the first 61 judged days:** a record of 60 days run does not judge it; a second call after the first returns the first result; a vault's fill missing from its chain is "not judged" with that reason; a replica with no entry is "not shown". The counts under `optimistic` are in the report and change no verdict.
  6. **CS2.2 is judged once, on the first 212 judged days (Argon's finding 2):** a record on which "outgrew" is reached at day 90 is still judged at day 212; a record that stops at day 150 is "not judged", with the ratio so far; a day after the 212th changes nothing, the ledger's end on one included, in the first replay to reach 212 days and in every later one. **It reads prices (the human, 2026-11-15; GPT's R4):** two forward records with the same prices, prints and fills and different bids give one verdict and the same two variances.
  7. **The report's sentences are the criteria's.** A claim's sentence holds the venue's rule and delays, "assuming our orders move nobody", V16's condition, and how the coins are valued, with the bid and its quote's time for each coin the ledger held at the end of the day the rung was reached, read from that day's rows. A forward record built as brief 3's construction A, the ask pulled up before a midnight and the bid left, names nothing at that day; "outgrew" holds its limit and the guard's greatest figure on the judged record, and where that is 20 or more, that the record rejected the null without the rule. A non-rejection is "not confirmed" and holds none of "no edge", "no skill" or "skill". Without CS2.3 met, the rule is called "a rule fitted to the vault's record".
  8. A non-rejection's report holds `Wᵇ` and `W`, the bar and its multipliers, the guard's figures, the equal-weight basket's wealth and BTC's, the volatility and Sharpe of `W` and of `Wᵇ`, the basket's own ratio of volatilities, and the power row (architecture 6.1).
- **Foreseeable walls:** the recorder's volume fills about 2027-05-20 and the human has deferred the choice (architecture 6.8); then the record stops, the test ends at the last day run, and CS2.2 is not judged if that is before the 212th.

## What the builder reports

For each step: its commit, its tests' count, the walls met. For steps 2 to 5 also their tables, which the registration holds.
