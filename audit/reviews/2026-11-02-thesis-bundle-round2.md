# The thesis bundle, round 2: GPT's F1 to F9

Builder session on branch `thesis-fixes`, from `audit/decisions.md` ("the thesis bundle isn't refrozen") and `audit/reviews/2026-11-02-gpt-thesis-fixes.md`. Nothing here is frozen: no refreeze, no cluster, nothing on `main`, no track data read. Next: GPT and a fresh Opus on this round.

## Each finding, by its failing test before the fix

| Finding | Failing tests | How it failed | The fix |
|---|---|---|---|
| F1, widened thresholds | `test_a_notional_just_above_a_thousand_dollars_takes_the_dearer_cell`, `test_a_loss_just_short_of_L_does_not_invalidate` | the cheap cell gave o = 1; invalidation fired short of L | exact arithmetic; `ROUNDING` deleted |
| F2, exactly zero | `test_a_return_of_exactly_zero_with_a_fee_and_one_leg_has_outcome_zero` | `assert (1 == 0)` | the same; `R_net` is exact, then reported as a float |
| F3, inside the lag | `test_sizing_inside_an_hours_lag_waits_for_its_reference[both markets]`, `test_an_hour_reconciles_only_when_every_open_legs_reference_is_available`, `test_data_fetched_before_a_boundary_never_reconciles_an_hour_past_its_cutoff` | N of 999.9 or 1010, not 1000 | E_r is the latest reconciled hour's equity; a read's cutoff bounds what it can establish missing |
| F4, warm cache | `test_a_cached_candle_read_at_an_earlier_cutoff_shows_its_open_with_a_null_close`, `test_a_reference_as_of_a_cutoff_is_the_same_whatever_was_read_before` | the open vanished at an earlier cutoff | cached rows are projected to the cutoff |
| F5, resolution | `test_a_resolvable_thesis_is_scored_though_an_unrelated_market_fails`, `test_a_managed_replay_that_fails_still_scores_the_outcome_and_the_remaining_theses`, `test_a_market_that_hangs_holds_up_no_status`, `test_a_record_carries_the_time_it_was_written_beside_its_data_cutoff`, `test_the_runner_runs_the_deadlines_on_their_own_loop` | no score; an escaping exception; no status; `at` was the pass's start | each thesis resolves from its own markets; `deadlines` reads only the ledger, each minute; `at` is the write |
| F6, benchmark p | `test_a_benchmark_resumed_after_its_equity_moved_registers_the_base_rate_of_its_own_notional` | p was the probe's 11/12-side estimate | p is computed in the commit; the probe is deleted |
| F7, holes | `test_a_hole_of_any_age_is_retried_until_the_venue_fills_it`, `test_rows_missing_before_the_first_cached_row_are_retried` | the row never appeared | holes are retried hourly with no age limit; `REPAIR` and `fetch_start` deleted |
| F8, legacy bodies | `test_a_truncated_final_body_is_rewritten_when_its_content_returns`, `test_a_damaged_body_keeps_its_bytes_and_the_repair_is_on_the_record`, `test_a_body_with_other_content_under_its_name_is_repaired_too`, `test_a_damaged_discovery_index_does_not_stop_the_poll` | the damaged body was reused; the discovery poll raised | a stored body is compared before reuse; a damaged one is moved aside, on a `repairs` log |
| F9, eligibility | `test_a_market_delisted_while_its_inputs_are_prepared_is_refused`, `test_a_thesis_records_the_listing_read_its_eligibility_came_from` | the delisted market was accepted | listings are read under the commit's lock, with t_r as that read returns; the read is recorded |

A few of these tests also failed for a lesser reason before the fix, which I did not separate out: the F7 tests pass `repair_every`, a parameter the old code lacked, and the F3 tests at the lag's far side (`test_sizing_at_the_end_of_an_hours_lag_counts_its_funding`, `test_a_reference_established_missing_...`) failed only on float rounding. GPT's F7 counterexample is a matter of the old code's 90-day limit, which the first-named test states, but that test never ran against the old code without the parameter. `test_five_reservations_of_an_equity_no_float_can_hold_fit_the_cap_exactly`, `test_a_thesis_scored_alone_has_the_managed_return_of_its_whole_account` and `test_a_benchmark_without_a_base_rate_at_its_commit_is_skipped` passed before the fix and guard the new code rather than show a bug. The kill test of F8 is `test_a_recorder_killed_during_a_repair_keeps_the_damaged_bytes_and_repairs_on_restart`.

### Found along the way, outside GPT's list

1. **At the cap, a float b refuses a thesis that fits.** With theses recording floats, the differential's `funding_holes` class showed a thesis at exactly 5% refused. So N, size and b are recorded as exact rationals' text, and the agent still sees numbers.
2. **Exact money grew slow with the account:** 1.27 s per `admit` at 60 theses over a year. Funding now accrues per unit and reaches the books at a leg's close, closed positions leave `live`, and the equity is computed once per replay unless `hourly` asks for every hour: 0.19 s at 60 theses and 0.62 s at 300, on synthetic data.
3. **My F4 fix had a bug of its own.** A merged repair request returns rows already cached, and an earlier cutoff counted them as in progress, so a row appeared twice (`test_a_repair_spanning_a_cached_row_at_an_earlier_cutoff_shows_that_row_once`).
4. **A tie between exits took the alphabetical reason.** A boundary case the mutants asked for (a discretionary exit requested at the hour whose close invalidates) disagreed with GPT: ours said discretionary, GPT's invalidation. GPT's order is adopted (`PRECEDENCE`, `audit/stage10/readings-draft.md`); only the label changes.

## The differential

`thesis/tests/test_positions_differential.py`. Each side now sizes its own theses. Money compares as exact rationals, not within a relative 1e-9. New comparisons: entry quantity, reference and fill; exit reference and fill; the hourly equity; reservations one second either side of each release. The generator no longer avoids the first minutes of an hour, and its cost cells differ by side. `BOUNDARIES` holds fixed cases on each boundary, including registrations at 0, 1, lag − 1, lag and lag + 1 seconds into an hour for core, builder and mixed accounts. `production` reads prices through `Market` and `Track.data`, checks them equal to the synthetic view at each registration, and repeats the comparison. It does not exercise the ledger, scheduling or restart; those have their own tests.

**Approved-spec agreement** (GPT's file with the readings of `audit/stage10/readings-draft.md` applied in the test): no disagreement on 150 sets in each of 9 classes, on every boundary case, or on 20 production-adapter sets per class.

**Raw disagreement** (GPT's file untouched; `PYTHONPATH=. python thesis/tests/test_positions_differential.py`), differences by kind over 150 sets (`no fixed point`: GPT's entry tier has no self-consistent choice, its docstring's choice 5, so it has no fill to compare):

| class | R_net | admit | entry fill | equity | exit | exit fill | hourly equity | managed | no fixed point | reason | reserved |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `plain` |  |  |  |  |  |  |  |  |  |  |  |
| `exits` |  |  |  |  |  |  |  |  |  |  |  |
| `costs` | 781 | 1855 | 1020 | 147 | 59 | 633 | 87039 | 762 | 3 | 6 | 560 |
| `gaps` |  |  |  |  |  |  |  |  |  |  | 5 |
| `holes` |  |  |  |  |  |  |  |  |  |  | 1 |
| `funding_holes` |  |  |  |  |  |  |  |  |  |  | 1 |
| `builder` |  |  |  |  |  |  |  |  |  |  | 1 |
| `outages` |  |  |  |  |  |  |  |  |  |  | 16 |
| `everything` | 87 | 1606 | 902 | 149 | 22 | 616 | 26975 | 452 | 1 | 2 | 548 |

`plain` and `exits` agree raw. `costs` and `everything` carry most of it because GPT's quantity comes from the fill and its data shape has one cost table per leg rather than one per side. `reserved` alone in `gaps`, `holes`, `funding_holes`, `builder` and `outages` is the suppressed-leg reading. `test_every_reading_is_needed_on_some_scenario` holds for each of the five patches' readings, so none is decoration. **This agreement is with GPT's file as read, not with its file as written:** the side-specific cost cells are a fifth patch beyond GPT's four readings, because GPT's data shape never carried them.

**Power,** by mutating `positions.py` (`MUTANTS`): how many of the 28 boundary cases and 20 sets in each class catch each mutant, by a disagreement or an error:

| mutant | caught by |
|---|---:|
| the cheap cell includes nothing at $1000 | 10 of 208 |
| a return of zero counts as a success | 24 of 208 |
| invalidation needs a loss beyond L | 1 of 208 |
| the cap excludes its own boundary | 1 of 208 |
| a cost cell ignores the side | 38 of 208 |
| entry needs no delay | 28 of 208 |
| an outcome enters without delay | 27 of 208 |
| a discretionary exit acts at its request | 10 of 208 |
| the last discretionary exit wins | 42 of 208 |
| an exit at an entry's hour lets it enter | 1 of 208 |
| simultaneous exits take the first set | 2 of 208 |
| simultaneous exits take their reasons in alphabetical order | 1 of 208 |
| a bar's close counts before it ends | 12 of 208 |
| funding is received, not paid | 194 of 208 |
| an outcome skips the exit hour's funding | 151 of 208 |
| an outcome ignores missing funding | 40 of 208 |
| an hour reconciles before its reference | 6 of 208 |
| an hour reconciles without its funding | 24 of 208 |
| reservations are never released | 208 of 208 |

Every mutant is caught (`test_every_mutant_is_caught`). Four are caught only by their boundary case, never by a random set: invalidation at a loss beyond L, the cap's own boundary, an unentered leg at the horizon hour, and the alphabetical tie order; the random sets do not land on exact boundaries, which is what `BOUNDARIES` is for. Two defects the comparison cannot see are not in the list: invalidation acting at close + δ rather than after the seal acts in the same hour, since both lags are under an hour, so it is the same code; funding settling inside its reference's lag shows only in a count of missing rows taken mid-lag, which GPT's file does not report, so `test_a_funding_row_not_yet_returned_inside_an_hours_lag_is_not_yet_missing` checks it.

## For the review

- **Readings:** `audit/stage10/readings-draft.md`, with the four rulings and six further points stated apart. The likeliest to draw comment are the reconciliation rule, the first-daily-row limit and the rational text in thesis records.
- **New ledger shape:** a thesis's `N`, `size` and `b` become text; it gains `listings` and `listings_read`; a resolved record gains `cutoff` and possibly `managed_failure`. A refreeze writes under a new campaign, so old records aren't read by the new code.
- **Equity series:** an hour is stamped after it settles, and `run` gives only the latest reconciled hour unless `hourly` is set. C10.3's test reads every hour.
- **Repair cost:** a hole costs a request per pass, each hour, per market and kind, for as long as it stays a hole. Holes closer than 500 rows share a request. A snapshot makes one such pass per market with holes, within the adapter's budget; I did not measure this against live data.
- **Limits left in place:**
  - A repaired body on the Oracle VM stops that file's pull with a divergence blocker, by `publish.py`'s refusal; the bytes stay on both sides. No such damage is known, and no recording was inspected.
  - A process killed between moving a damaged body aside and writing its `repairs` record leaves a `.damaged-<t>` file with no record. Its name holds the digest and time.
  - `gpt_scoring.py` still has floats and the old rounding, so C10.4's next judged run needs its update from GPT or must stay off those boundaries.
  - Listing reads now hold the ledger's lock for as long as they take, which delays another account's registration behind a slow venue, never backdates it.
- **Forks:** as before, every module here is under the manifest, so a refreeze makes a new track version and restarts C10.5's window.
