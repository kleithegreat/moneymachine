# Holdout staging: the Python loader fails C7.6's named test 3 (2026-11-04)

C7.6's draft revision (`b3-draft/c76-revision.md`, named test 3) says the holdout check reads only the event-time
column, of every row, before anything else is read, and that each refusal names its cause: a holdout crossing the
boundary and the crossing event time, an undecodable event time "the holdout check cannot be made". It tests what is
read: every Parquet read of `ingest/store.py` opens its file through `open_parquet`, which the tests in
`ingest/tests/test_store.py` wrap, recording the byte ranges read up to the refusal; none may meet a column chunk other
than the event time's. The tests (`test_holdout_check_reads_event_times_alone`, two rows: one fetched after the
version, one a tombstone; and the variant `test_an_undecodable_event_time_refuses_before_any_value`), each on the store
as written and on the same store with every other column chunk garbled, under a root whose path names neither
"holdout" nor the boundary, fail on `ingest/store.py` as it stands: `Store.revisions` reads every column of every file
(`pl.read_parquet` reads each whole file through `open_parquet`), and `as_of` has no holdout check on reads (the search
store refuses holdout rows only when writing). As written, all three return rows without a refusal; garbled, all three
fail inside the loader with `polars.exceptions.ComputeError: parquet: File out of specification: Invalid thrift: bad
data`. Their control, `test_loaders_reading_every_column_first_fail_test_3`, passes on every fixture: the event times
alone, read through the wrapped reader (footer, then the event time's chunk), meet no other chunk; and both control
loaders fail every case, the eager one, and the one that survives a decoding error until the holdout check, which only
the byte ranges catch on the garbled store.

The six are `xfail(strict=True)` naming this record. The fix is slice 5's (`rust-port-plan.md`): `store.as_of`'s
bitemporal replacement reads event times alone first, through `open_parquet`, and refuses as test 3 says; polars reads
a file object whole, so it reads them by the file's footer, as the control's reader does. No judged result rests on
this check yet.
