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
