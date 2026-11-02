# The thesis bug bundle: findings shown, fixes, differential

Builder session on branch `thesis-fixes`, from `audit/decisions.md` ("GPT's bug hunt triaged"). Nothing here is frozen: no refreeze, no cluster, nothing on `main`.

## Each finding, by its failing test on the unfixed code (`8f6d446`)

All ten reproduced; none is reported as not reproducing. The tests ran against the unfixed modules, with one stand-in: `benchmarks`, the fix's entry point, was the old `schedule` with its sessions off.

| Finding | Failing test | How it failed |
|---|---|---|
| Thesis 1, funding | `test_a_missing_funding_hour_sizes_later_theses_from_the_equity_reconciled_before_it` | `assert 1010.0 == 1000`: N sized on unreconciled equity |
| Thesis 2, invalidation | `test_invalidation_reads_the_bars_close_never_the_next_open`, `test_an_open_that_crosses_the_loss_never_invalidates_before_its_close` | `'horizon' == 'invalidation'`; `'invalidation' == 'horizon'`: the next open decided both ways |
| Thesis 3, recovery | `test_a_runner_killed_mid_day_ends_that_session_on_the_record_and_runs_the_rest[main,ablation,noread]` (SIGKILL), `test_a_date_the_runner_was_down_for_is_disclosed_missed`, `test_a_restart_after_the_day_ended_discloses_the_rest_as_missed` | `[] == ['ablation', 'noread']`; no end on record; no missed date disclosed |
| Thesis 4, benchmark | `test_a_benchmark_market_that_fails_is_retried_with_the_rest_of_its_batch`, `test_a_benchmark_batch_cut_off_past_its_day_logs_each_market_left_as_missed`, `test_every_monday_the_runner_was_down_for_is_logged_missed` | the batch stayed `['BTC']`; older Mondays logged nothing |
| Thesis 5, deadline | `test_a_horizon_still_unresolved_gets_its_status_before_the_two_hour_deadline[all 5 phases]` | `assert 0 == 4`: no status by T + 2 h |
| Thesis 6, holes | `test_a_funding_row_the_venue_supplies_late_fills_its_hole`, `test_a_candle_the_venue_supplies_late_fills_its_hole` | the row never appeared |
| Thesis 7, partial spread | `test_a_partly_entered_spread_closes_its_open_leg_at_the_horizon_and_never_enters_the_other`, `test_a_partly_entered_spread_releases_its_reservation_at_the_horizon` | reservation `100.0 == 0` after the horizon |
| Thesis 8, listings | `test_a_market_delisted_after_the_snapshot_is_refused_at_registration` | `not True`: the delisted market was accepted |
| Recorders 1, torn line | `test_an_append_after_a_torn_record_starts_on_its_own_line`, `test_a_torn_tail_does_not_stop_a_read`, `test_a_torn_log_line_does_not_stop_a_restart`, `test_a_writer_killed_mid_append_leaves_a_directory_the_next_writer_and_reader_can_use` (SIGKILL) | `JSONDecodeError` on read, and on `last_polls`, the restart path |
| Recorders 2, body | `test_a_body_write_that_fails_leaves_nothing_a_later_poll_of_the_same_body_reuses` (a real short write, by RLIMIT_FSIZE) | the poisoned blob was reused and did not decompress |

Found while fixing these, each with its own failing test, and outside GPT's list:
- A market-data failure stopped `resolve` from writing any status, so an outage could pass C10.5's deadline silently (`test_a_market_data_failure_still_writes_the_status_by_its_deadline`).
- With two pending exits, the later one overwrote the earlier: the daemon allows a second exit until the first fills (`test_the_first_exit_committed_stands`).
- A horizon or discretionary exit could fall before an entry, which then opened a position after its exit (`test_no_leg_enters_at_or_after_its_exit`, `test_a_discretionary_exit_before_the_entry_means_no_trade`).

## Fixes, and the readings they rest on

- **Sizing with a funding gap:** E_r is the equity at the hour of the first missing row, computed before anything settles at that hour, until the row arrives; the hourly equity series ends there too. Reservations stay current, since they do not depend on the missing amount. A permanent gap holds E_r at that value for the rest of the track.
- **Partial spreads:** each leg exits on its own; a leg not entered by its exit never enters, and the thesis's managed return is null (e ≥ x leaves it unresolved) while the account keeps the open leg's PnL. A position with no bars at all closes at its horizon and frees its reservation.
- **Recovery:** each session runs once; a session with no end gets one on the record, and the rest of its date runs, on main's own snapshot (each session record names it). A SIGTERM after main now leaves the date to the next start instead of disclosing it as missed.
- **Holes:** a fetch starts at the first hole within 90 days (REPAIR). A hole that never fills repeats that fetch each call, a bounded cost; one older than 90 days is left alone, and a base-rate window keeps counting it incomplete.
- **Deadline:** `RESOLUTION_GRACE` is 90 minutes. A status can come before a score, and the score is still recorded later.
- **Benchmarks:** they run on their own thread, so a failing market can't hold up the day's sessions, and a batch stops at the failing market so commit order stays BENCHMARK order.

## The differential

`thesis/tests/test_positions_differential.py` runs `thesis/positions.py` against `thesis/tests/gpt_positions.py` on 150 generated sets in each of 9 classes (plain, exits, costs, price gaps, missing bars, missing funding, builder markets, long outages, everything). It compares sizing at each registration; each leg's entry and exit; reasons; as-registered and managed returns; outcomes; and final reconciled equity. It also asserts that the sets reach every exit reason, size-zero theses, spreads, suppressed legs, unresolved outcomes and missing funding. **All nine agree**, with GPT's file unchanged and the four readings below applied to its source inside the test.

Power, by mutating `positions.py` (12 sets per class):

| Mutation | Caught in |
|---|---|
| invalidation on the next open | gaps, holes, outages, everything |
| a leg enters after its exit | everything; also `test_no_leg_enters_at_or_after_its_exit` |
| no tolerance at ties | costs, funding holes, everything |
| sizing ignores a funding gap | funding holes, everything |
| discretionary exit without δ | gaps, holes, funding holes, builder |
| the later of two exits wins | 8 of 9 classes, all that have exits (caught only after the generator was changed to repeat exits) |
| funding at the wrong sign | all 9 |
| reservation never released | all 9 |
| a position waits on a leg that can't enter | **not caught at 12 sets**; `test_a_partly_entered_spread_releases_its_reservation_at_the_horizon` covers it |
| `seen <= now` removed from invalidation | **not caught**: with real data a close is absent until it is available, so this guard only matters for the fixtures |

### Code bugs it found, each fixed with a failing test first

1. **The $1000 cost cell.** `abs(q) * ref <= 1000` with q = 1000 / ref rounds above 1000 at 14,571 of the 100,000 prices from 0.01 to 1000.00, taking the $10k cell. N = $1000 is exactly E = $10,000 with L = 0.1, so it covers every benchmark registration at initial equity. Example: 50.36 filled at 50.400288 (8 bps), not 50.365036 (1 bp).
2. **A close exactly at L.** A short at 118.9 with a close at 130.79 is exactly −0.10, but float arithmetic gave a value above −0.10, so no invalidation fired and the exit came later.
3. **A core candle's open hidden until the candle completed.** `positions.py` was written for an open known at H + δ, but `Market.bars` dropped the candle until H + 1 h + δ. A position closed at its 00:00 horizon therefore still held its reservation, and its exit was still unbooked, during that day's 00:10 session, for up to 1 h 2 min. Near the cap this can refuse a thesis permanently. This was the largest source of disagreement: with that shape, `gaps` differed in 110 of 150 sets, and with the fix, none outside the funding reading below. Scores now also come at T + δ rather than T + 1 h + δ. **This is a design choice the review should look at:** the criteria don't say when a core open becomes known, and I took it as "from δ, once seen", matching builder opening references and the docstring in `positions.py`.

### Spec points GPT read differently; a difference is reported either way

Applied as readings in the test, with the code unchanged:
- **The quantity and R_gross use the open, not the fill.** GPT took P_e as the adverse fill. SCORING.md says `q = w · N / open(e)`, and C10.4 was judged on it. The criteria's "at price P_j,e" is ambiguous: *a dated revision should say P_j,e is the reference open.*
- **The funding mark after a missing core bar.** GPT used the latest earlier open, reading "the latest earlier reference" in the 2026-10-23 revision. SCORING.md's `mark` takes the last bar's close. The two texts differ for core markets: *the revision should name SCORING.md's rule.*
- **A leg that can no longer enter holds no reservation.** GPT released a spread's reservation only when the pending leg's next bar appeared, though that leg could never enter. The code releases at the exit, on "until its position is fully closed".

Differences left in place, outside the test:
- **Funding inside the lag.** For t_r in [h, h + lag), the code counts h's funding row if it is known and GPT waits for hour h's reconciliation; E_r differs by at most that one payment. The generator avoids this window. The criteria are silent, and a daily session at 00:10 is outside it.
- **Hypothetical N at E_r ≤ 0.** The code uses `RISK * initial / L`, GPT uses 0. It affects only the cost tier of a size-zero thesis in a bankrupt account, and was not exercised. The criteria are silent.
- **Reason labels on an exact tie of thresholds.** Label only: the exit's time and price are the same.
- **R_net exactly 0.** GPT is exact; the code and both C10.4 scorers use floats, so a true zero can round either way. It needs two legs with exactly offsetting moves and no fee, and the taker fee makes that practically unreachable. Noted, not fixed.

`gpt_scoring.py` keeps bug 1's rounding. C10.4's frozen generator passes with the fixed `fill`, so it doesn't reach the boundary; a future set at N = $1000 could disagree there, with the frozen scorer in the wrong.

## For the review and a refreeze

- **Forks:** every module here is under the manifest, so a refreeze makes a new track version and restarts C10.5's window. No harness hash or kernel changes. The running track carries all of these bugs until then, including bug 1 on its N = $1000 theses. I read no track data to count them.
- **Records:** a `session` record gains `taken`, and an exit's legs gain `market`. A new version writes under its own campaign, so old records are not read by the new `day`. The market cache needs no migration: in-progress rows are never cached, and its existing holes fill on first use.
- **New behaviour to check:** benchmarks now run on their own thread, beside the sessions; a SIGTERM after main no longer discloses the date's other sessions as missed; a market-data failure past 90 minutes writes "missing data", which a score can still follow.
- **Accepted limits:** a hole older than 90 days never fills. A permanent hole repeats its fetch from there (for funding, up to 5 pages each time). A pre-fix corrupt body already on the datalayer volume is not repaired, since only new writes are atomic. A mirror run that lists a body's `.tmp` just as it's renamed fails once and recovers on the next run.
- **Types:** `thesis/tests/test_types.py` pins `mypy --strict --follow-imports=skip` on the 7 fixed modules and `ingest/hl.py`, whose class `thesis/market.py` subclasses. `mark` now raises `LookupError` where it returned a `None` that every caller would have crashed on. `mypy` is added to `flake.nix`, not `flake.lock`.
- **Merge:** `main`, with the ops fixes, is merged into the branch, so review `main...thesis-fixes`. The two conflicts were both-sides appends, in `audit/decisions.md` and `ingest/tests/test_live.py`; `harness_hash` is the same on both.
- **Test suite:** on the merged tree, run under the flake with `TMPDIR=/tmp`: 476 passed. Everything passes except `test_kernel_matches_witness` and `test_runs_agree_bit_for_bit`, which need `data/store`, absent from this worktree by the task's rule. Nesting `nix develop` in a dev shell without that setting doubles `TMPDIR` and fails the socket tests with `AF_UNIX path too long`, unrelated to this change.
