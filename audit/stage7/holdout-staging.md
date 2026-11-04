# Holdout staging: the Python loader fails C7.6's named test 3 (2026-11-04)

C7.6's draft revision (`b3-draft/c76-revision.md`, named test 3) says the holdout check decides on the event-time
column alone, of every row, after the schema checks, and that each refusal names its cause: a holdout crossing the
boundary and the crossing event time, an undecodable event time "the holdout check cannot be made". It is tested as
non-interference: `test_holdout_check_decides_on_event_times_alone` in `ingest/tests/test_store.py` builds, for each of
three fixtures (a late row in the holdout fetched after the version, or a tombstone; or a late row whose event time is
a Double), variants of the store differing only outside the late row's event time (other values, a NaN, a List, its
file garbled but for the event time's chunk), under a root whose path names neither "holdout" nor the boundary, and
requires one refusal and one output across them. It fails on `ingest/store.py` as it stands, which has no holdout check
on reads (the search store refuses holdout rows only when writing): as written, `as_of` returns rows without a refusal, and its other variants fail inside polars (garbled,
`ComputeError: Invalid thrift: bad data`; a List, `SchemaError`).
Its controls (a loader resolving first and refusing after, the eager loader, and one whose refusal carries a decoded
value) fail every fixture, and the loader surviving a decoding error until the check passes it.

The three are `xfail(strict=True)` naming this record. The fix is slice 5's (`rust-port-plan.md`): `store.as_of`'s
bitemporal replacement makes the schema checks, then the holdout check on the event times alone, and refuses as test 3
says. No judged result rests on this check yet.
