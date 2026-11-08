# Thesis refreeze round four — GPT build record, 2026-11-08

Builder: GPT-6.1 Sol, branch `thesis-refreeze`, starting at `e04b8d4`. **Development build, not an independent review or authority to freeze/deploy.** Read `CLAUDE.md`, `PROGRESS.md` and the three requested reviews from `main`. No Hyperliquid endpoint was called; fixtures are synthetic. No protected prices/returns were manually inspected. Frozen criteria and manifest are unchanged; no push, deployment or freeze.

## Findings and failing-first evidence

All seven initial regressions in `thesis/tests/test_refreeze_round4.py` failed on the unchanged `e04b8d4` sources: **7 failed**, `/tmp/opencode/round4-failfirst.log`. The surviving review reproductions in `/tmp/opencode/test_gpt_refreeze_review.py` supplied the interval-starvation, cold-fill, legacy-row and excess-charge cases; the inventory test uses a real blocked worker rather than synchronously deadlocking inside a hold.

| Finding | Fix at its cause | Initial failing-first test (same module) |
|---|---|---|
| 1 | `Track.inputs` requires acquired comparator history for every requested leg before supplying registration inputs; raises the existing transport-availability failure. Snapshot eligibility is unchanged. Benchmark retries and eventually uses its existing missed-batch policy. No partial comparator is committed. | `test_registration_refuses_unacquired_comparator_history` |
| 2 | Repair freshness describes actual time intervals, separately for foreground/background. Widening finds old omitted rows. Freshness is never renewed merely because a range was read: only due/checked or actually fetched intervals advance. | `test_widened_covered_holes_are_not_starved_by_hourly_narrow_reads` |
| 3 | Plan acquisition and repairs once, before fetching, rather than immediately probing the prefix/tail just acquired. Clamp hole plans to the requested scope. Retain mandatory omission probes and terminal candle requests; withdraw the unsupported aggregate-fit claim and derive their cost in T3. | `test_cold_fill_does_not_reprobe_the_ranges_it_just_acquired` |
| 4 | Propagate background admission through core metadata, dex discovery and dex metadata, not only funding pages. | `test_session_hold_covers_background_inventory` |
| 5 | Expose one resumable `thesis-prewarm` pass without constructing/freezing a track; use the runner's exclusive root lock and SIGTERM stop. | `test_bootstrap_is_available_without_a_frozen_track` |
| 6 | Preserve legacy funding rows as first observations; legacy wins a conflicting refill, but contributes no acquired intervals. The requested what/why/reverse line is in `audit/decisions.md`. | `test_legacy_rows_survive_refill_without_claiming_range_coverage` |
| 7 | Reserve ceiling surcharges; excess accounting is the difference of total surcharges, not the surcharge of the row-count difference. Recorder accounting is not silently changed. | `test_excess_response_charges_difference_of_total_surcharges` |

Follow-ups also started red:

- The scope-bound test failed before filtering the repair plan's rows to its requested interval (`round4-holes-red.log`). Old cached rows must not widen a candle repair beyond its declared scope.
- The first interval fix still renewed untouched holes under frequent reads. `test_frequent_reads_do_not_renew_repairs_they_did_not_perform` failed on `b13fe40` (`round4-freshness-red.log`); `8500523` preserves the original expiry. Interval union now returns its own tuple representation, so successive unions are well-defined. The intermediate mixed-list/tuple implementation failed the targeted suite and was corrected before commit.
- Acquisition/start separation, late acquisition and outage cases failed before the new schedule (`round4-schedule-red.log`). A further late-publication test failed even when the HTTP reads were timely (`round4-publication-red.log`). The existing ledger now attests `snapshot_ready` only after atomic file publication, with cutoff, completion and exact-byte hash. Recovery requires that attestation and those bytes; it cannot reconstruct a timely snapshot after the deadline.

The old strict snapshot-tail xfail is removed only alongside these scheduling/request-path tests. It now charges ceiling tails against the proposed schedule, not the original eight-minute interval. This is **not** a pass of the old frozen timing criterion.

## T3 and proposed timing

The authoritative end-to-end derivation is `docs/whitepaper.tex`, appendix T3. `nix build .#whitepaper` succeeded and `result` was copied to `docs/whitepaper.pdf`; the copied bytes compare equal to the build result.

- Full funding scope: at most 55 calls / 2,475 reserved weight per market; the synthetic complete scope actually reserves 2,451. The 40-day reproduction drops from 153 to 89. The inclusive-slot inventory-wide bound is 19,140 calls / 861,300 weight, 159.5 hours of two-page allowance batches before interruptions. The former age-based 403,560 is not certified as an upper bound.
- Daily no-additional-hole funding upkeep: 20,166 weight; discovery at d <= 5 adds at most 13,440/day. Together 23.34/min **before** candles, other repairs, account reads, retries and marks. The former 45/min total-fit assertion is withdrawn.
- Snapshot tails: 524 × 21 = **11,004 weight**, 91.7 ideal minutes; five fit per rolling minute, so 105 batches. Full warm request envelope including discovery, prefixes and terminal empty responses: **1,509 calls / 50,590 weight**, under the stated inventory/no-interior-hole conditions. Cold candle caches are also derived, not assumed prewarmed.
- An order-independent 701-minute waiting bound, five extra attempts, total non-admission service allowance, retry backoff, mark interference and debt/scheduler allowances give **65,631 seconds = 18:13:51**. This is a **conditional** bound, not an HTTPX timeout guarantee or a daily availability certificate. All-six-attempts on every call, larger inventories, extra holes and competing foreground work can exceed a day.
- Proposed cutoff **00:05 UTC (19:05 EST on the preceding date)**; acquisition due then and completed by **19:00 UTC (14:00 EST)**. Cutoff + bound = 18:18:51; the first whole-hour start after it is 19:00. On-time main snapshot age is 18:55; every arm's maximum admission age is strictly below 23:55. Late/missing acquisition misses main/no-reading; model/canary availability may wait only within the date. Timely snapshots survive restart unchanged.

The dated proposal is `audit/stage10/criteria-revision-draft.md`, **not** an edit to `audit/criteria.md`. Adoption requires independent review, disposition of the remaining shared-IP/mark-capacity/foreground-service blockers and a new forward identity/window. No WebSocket close is used.

## Validation and environment

- Targeted final acquisition, market, runner, schedule, SIGKILL and strict-type checks: **238 passed**, 82.51 s (`round4-core6.log`). A separate recovery/commit-rule run passed 23 checks before the final repair follow-up.
- Initial full suite: **1,319 passed, 10 failed, 2 skipped, 19 xfailed**, 449.32 s (`round4-full.log`). Nine failures were crash fixtures still scheduled at the old hour; update the fixtures to acquire first and run at the proposed hour, retaining every once-only assertion. The other failure was the repository's UTC/Eastern pairing check; the draft now supplies the Eastern equivalents.
- That initial suite unexpectedly had `data/store` visible through a symlink to the main checkout. Its contents were not manually inspected and the link was not removed or changed. That run is **not data-less evidence**. Subsequent full runs mask this worktree's `data/` with a private tmpfs rather than changing unfamiliar user files. An initial mask invocation stopped before collection because the root bind made `/dev/null` inaccessible; bind `/dev` explicitly for the actual run. `TMPDIR=/tmp` is set inside `nix develop`; full runs use the requested `pytest -n auto -q`, in a memory-capped scope.
- `/tmp` was initially full; preserve the two scratch directories created by this build under `/home/kevin/.cache/mm-refreeze-round4` and use disk-backed scratch for focused tests. Do not delete other sessions' artifacts.

## Finished implementation commits

- `6bfe069` — findings 1–7: readiness, interval repair provenance, held discovery, bootstrap, legacy preservation, ceiling/excess accounting.
- `77ae9e7` — scope-bounded omission plans and actual cold/retry reservation pins.
- `b13fe40` — fixed-cutoff acquisition/attestation, proposed later schedule, crash fixtures, draft revision, T3 and rebuilt PDF.
- `8500523` — repair freshness advances only for intervals actually checked/fetched; frequent-read starvation regression.
- `1160c7b` — `day` consumes the prepared snapshot rather than acquiring/reconstructing it. A failing-first post-main cache-loss regression (`round4-lost-snapshot-red.log`) exposed a remaining recovery path that bypassed the attestation. Recovery now validates the published bytes for every remaining arm, and unavailable bytes cause missing arms rather than a replacement snapshot. Final focused run: **239 passed**, 81.80 s (`round4-core7.log`).

## Subsequent full-run evidence

- The first completed data-masked run (`round4-full-dataless-final.log`) reported **1,327 passed, 5 failed, 2 skipped, 19 xfailed**, 908.04 s. Two failures were genuinely absent-store inputs: `kernel/tests/cli/test_differential.py::test_kernel_matches_witness` and `reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit`. The other three were two ten-second multiprocessing startup timeouts in `gate/tests/test_compute.py` and an xdist worker crash during the synthetic positions differential. This run shared a 6 GiB-capped host workload with focused checks and spanned the repair follow-up; it is not final stable-tree evidence. No threshold or test is relaxed for those failures. The final run uses the stable committed implementation, an 8 GiB scope, no concurrent focused suite and the same private data mask.
- An additional 200 seeded permutations through the actual `WeightLimit(120)` packed below the 701-minute order-independent bound; the maximum shuffled wait was 603 minutes. The 632-minute ordered example remains separately pinned in the permanent test.

**Final run (recorded by the advisor, 2026-11-08 17:42 UTC (12:42 EST)):** the data-masked full suite at `1160c7b` (`/tmp/opencode/round4-full-final.log`): 1,332 passed, 2 failed, 2 skipped, 19 xfailed, 425 s. The two failures are the masked-store tests (`test_kernel_matches_witness`, `test_runs_agree_bit_for_bit`); no other failure.
