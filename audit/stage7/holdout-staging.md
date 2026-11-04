# Holdout staging: the Python loader fails C7.6's named test 3 (2026-11-04)

C7.6's draft revision (`b3-draft/c76-revision.md`, named test 3) says the holdout check reads only the event-time
column, of every row, before anything else is read, and that each refusal names its cause: a holdout crossing the
boundary and the crossing event time, an undecodable event time "the holdout check cannot be made". Its tests, in
`ingest/tests/test_store.py` against the production loader, on a store root whose path names neither "holdout" nor the
boundary (`test_holdout_check_reads_event_times_alone`, two rows: one fetched after the version, one a tombstone; and the
variant `test_an_undecodable_event_time_refuses_before_any_value`, its Double event time written before garbling), fail
on `ingest/store.py` as it stands: `Store.revisions` reads every column of every file (`pl.read_parquet`,
`store.py:72`, called from `as_of`), and `as_of` has no holdout check on reads (the search store refuses holdout rows
only when writing). All three fail there, inside the loader, with `polars.exceptions.ComputeError: parquet: File out of
specification: Invalid thrift: bad data`. (Round 5's variant failed in its own setup instead: `b3-round5-review-gpt.md`
finding 4.) Their control, `test_a_loader_reading_every_column_first_fails_test_3`, passes on all three fixtures: the
event times alone read, and a loader that reads every column first, refusing an undecodable row as an invalid dataset,
fails each test.

The three are `xfail(strict=True)` naming this record. The fix is slice 5's (`rust-port-plan.md`): `store.as_of`'s
bitemporal replacement reads event times alone first and refuses as test 3 says. No judged result rests on this check
yet.
