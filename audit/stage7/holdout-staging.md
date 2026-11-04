# Holdout staging: the Python loader fails C7.6's named test 3 (2026-11-04)

C7.6's draft revision (`b3-draft/c76-revision.md`, named test 3) says the holdout check reads only the event-time
column, of every row, before anything else is read. Its tests, written against the production loader in
`ingest/tests/test_store.py` (`test_holdout_check_reads_event_times_alone`, two rows: one fetched after the version, one
a tombstone; and the variant `test_an_undecodable_event_time_refuses_before_any_value`), fail on `ingest/store.py` as it
stands: `Store.revisions` reads every column of every file (`pl.read_parquet`), and `as_of` has no holdout check on
reads (the search store refuses holdout rows only when writing). On the garbled fixture each fails with
`polars.exceptions.ComputeError: parquet: File out of specification: Invalid thrift: bad data` instead of a refusal.
Their control, `test_the_staging_fixture_refuses_every_column_but_event_time`, passes: any column but `eventTime` fails
to decode.

The three are `xfail(strict=True)` naming this record. The fix is slice 5's (`rust-port-plan.md`): `store.as_of`'s
bitemporal replacement reads event times alone first, refusing a holdout crossing with a `ValueError` naming the
holdout and an undecodable event time with one naming the dataset invalid. No judged result rests on this check yet.
