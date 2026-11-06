# Holdout staging: the Python loader fails C7.6's named test 3 (2026-11-04)

C7.6's draft revision (`b3-draft/c76-revision.md`, named test 3) says that before the holdout check passes a loader
decodes no column chunk but the event time's, uses no footer statistic of another column and keeps nothing derived
from them; that the check reads the event-time column of every row, after the schema checks; and that each refusal
names its cause: a holdout crossing the boundary and the least crossing event time, an undecodable event time "the
holdout check cannot be made". Its structural half is decided by review; its behavioural half,
`test_holdout_check_decides_on_event_times_alone` in `ingest/tests/test_store.py`, stages three fixtures (two late rows
in their own file or sharing the early row's, or two Double event times) under 35 variants each, and requires the
fixture's refusal, alike across them, nothing on stdout, one stderr, and no state carried to a later call.

It fails on `ingest/store.py` as it stands, which has no holdout check on reads (the search store refuses holdout rows
only when writing): on the first variant of every fixture, late rows eligible and live, `as_of` returns them without a
refusal. Structurally it fails too: `revisions()` decodes and caches every column of every file before anything could
check. Its eleven controls fail the net at their named assertions and the projecting loader passes it.

The three are `xfail(strict=True)` naming this record. The fix is slice 5's (`rust-port-plan.md`): `store.as_of`'s
bitemporal replacement makes the schema checks, then the holdout check on the event-time column alone, by projection,
before anything else is decoded, and refuses as test 3 says. No judged result rests on this check yet.

## Round 10 (2026-11-06)

The net now requires exact refusal diagnostics and empty stdout and stderr, replacing stderr invariance. It replaces
file deletion with a call on a distinct, unchanged early-only dataset through `as_of` on the same loader, compared with
a fresh loader. Dataset-scoped caching of authorized event-time inventories passes. Twelve negative controls fail at
their named assertions, including an invariant early-row count on stderr; the production loader's three strict xfails
remain. Structural review now follows every refusal, diagnostic and cleanup path through exit, requiring successful
completion of the whole holdout check before any non-event-time decode or statistic use.

Validation through the flake, with `TMPDIR=/dev/shm/b3r10` and pytest's `--basetemp=/dev/shm/b3r10/pt`:
`pytest ingest/tests/test_store.py ops/test_progress.py -p no:cacheprovider` gives 54 passed, 3 expected strict xfails;
`python audit/stage7/b3-draft/lean_check.py` passes the full hand/generated-file and Lean checks.
