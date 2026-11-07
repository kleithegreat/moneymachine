"""C7.6's named test 2 (audit/criteria.md, B3 revision): Parquet as cells, on both production loaders. Each scenario writes
files by hand under SOURCES.md §2's mapping and states the outcome it prescribes: a dataset that resolves (and to which
cells) or an invalid one."""

import base64
import math
import shutil
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq
import pytest

from kernel.tests.rules import lean_check, loaders
from kernel.tests.rules import resolver_suite as suite

pytestmark = pytest.mark.usefixtures("built_kernel")
E, K = suite.E, suite.K
SOURCES = [suite.src("bars", values=("close",), times=("eventTime",))]
CASE = {"universe": ["BTC"], "sources": SOURCES, "version": 100, "queries": [K]}


def table(close=None, fetched=100, event=E, extra=None, rows=1, names=("fetchedAt", "coin", "eventTime", "close")):
    """One row of a bar: `close` as a pyarrow array of `rows` entries (default one Double 1.5)."""
    close = pa.array([1.5] * rows) if close is None else close
    columns = {"fetchedAt": pa.array([fetched] * rows, pa.int64()), "coin": pa.array(["BTC"] * rows, pa.large_string()),
               "close": close}
    if event is not None:
        columns["eventTime"] = pa.array([event] * rows, pa.int64()) if not isinstance(event, pa.Array) else event
    return pa.table({**columns, **(extra or {})})


def outcomes(tmp_path, files, version=100):
    """Both loaders' results on the files, a dict from file name to table, or (name, table, writer arguments)."""
    case = {**CASE, "version": version}
    out = {}
    for name, run in (("python", loaders.python), ("mm", loaders.rust)):
        root = tmp_path / name
        (root / "bars").mkdir(parents=True)
        for i, f in enumerate(files):
            if isinstance(f, Path):
                shutil.copy(f, root / "bars" / f"{i}.parquet")
                continue
            t, kwargs = (f, {}) if isinstance(f, pa.Table) else f
            pq.write_table(t, root / "bars" / f"{i}.parquet", **kwargs)
        out[name] = run(case, root)["result"]
    assert lean_check.same(out["python"], out["mm"]), out
    return out["python"]


def cells(result, column="close"):
    """The cells of `column` along the one key's timeline, with their kinds."""
    return [(type(e[4][column]).__name__, e[4][column]) for e in result["keys"][0]["timeline"]]


TYPES = {"UInt64": pa.array([1], pa.uint64()), "Int32": pa.array([1], pa.int32()), "Decimal": pa.array([1], pa.decimal128(5, 1)),
         "Timestamp": pa.array([1], pa.timestamp("ms")), "Null": pa.array([None], pa.null()),
         "List": pa.array([[1.0]], pa.list_(pa.float64())), "Struct": pa.array([{"a": 1}], pa.struct([("a", pa.int64())]))}


@pytest.mark.parametrize("name", TYPES)
def test_a_type_outside_the_mapping_makes_the_dataset_invalid_in_a_declared_column_only(tmp_path, name):
    assert outcomes(tmp_path / "a", [table(TYPES[name])]) == "INVALID"
    ignored = outcomes(tmp_path / "c", [table(TYPES[name], fetched=200), table(pa.array([2.5]), fetched=50)])
    assert cells(ignored) == [("float", 2.5)]
    assert cells(outcomes(tmp_path / "d", [table(extra={"unused": TYPES[name]})])) == [("float", 1.5)]


@pytest.mark.parametrize("bad", [math.nan, math.inf, -math.inf])
def test_non_finite_doubles_are_not_cells(tmp_path, bad):
    assert outcomes(tmp_path / "a", [table(pa.array([bad]))]) == "INVALID"
    assert cells(outcomes(tmp_path / "b", [table(extra={"unused": pa.array([bad])})])) == [("float", 1.5)]


@pytest.mark.parametrize("array, kind, value", [
    (pa.array([7], pa.int64()), "int", 7), (pa.array([1.5]), "float", 1.5), (pa.array(["x"], pa.utf8()), "str", "x"),
    (pa.array(["x"], pa.large_string()), "str", "x"), (pa.array([True]), "bool", True),
    (pa.array([None], pa.int64()), "NoneType", None), (pa.array([None], pa.float64()), "NoneType", None),
    (pa.array([None], pa.utf8()), "NoneType", None), (pa.array([None], pa.bool_()), "NoneType", None)])
def test_each_type_of_the_mapping_gives_its_cell(tmp_path, array, kind, value):
    assert cells(outcomes(tmp_path, [table(array)])) == [(kind, value)]


def test_one_column_as_int64_in_one_file_and_double_in_another_keeps_both_kinds(tmp_path):
    result = outcomes(tmp_path, [table(pa.array([1], pa.int64()), fetched=60), table(pa.array([1.0]))])
    assert cells(result) == [("int", 1), ("float", 1.0)]


def test_a_file_without_a_tombstone_column_holds_no_tombstone_and_a_null_is_false(tmp_path):
    live = table(extra={"tombstone": pa.array([None], pa.bool_())})
    assert [e[2] for e in outcomes(tmp_path / "a", [live])["keys"][0]["timeline"]] == [False]
    assert [e[2] for e in outcomes(tmp_path / "b", [table(fetched=60), table(extra={"tombstone": pa.array([True])})])["keys"][0]["timeline"]] == [False, True]


@pytest.mark.parametrize("bad", [pa.table({"fetchedAt": pa.array([1.0]), "coin": ["BTC"], "eventTime": [E], "close": [1.5]}),
                                 pa.table({"fetchedAt": pa.array([1], pa.int32()), "coin": ["BTC"], "eventTime": [E], "close": [1.5]}),
                                 pa.table({"coin": ["BTC"], "eventTime": [E], "close": [1.5]}),
                                 table(extra={"tombstone": pa.array([1], pa.int64())})])
def test_the_footer_checks_reject_fetched_at_and_tombstone_of_another_type_whatever_the_version(tmp_path, bad):
    assert outcomes(tmp_path / "a", [bad]) == "INVALID"
    assert outcomes(tmp_path / "b", [bad], version=0) == "INVALID"


def test_a_null_fetched_at_makes_the_dataset_invalid_whatever_the_version(tmp_path):
    null = table().set_column(0, "fetchedAt", pa.array([None], pa.int64()))
    assert outcomes(tmp_path / "a", [null]) == "INVALID" and outcomes(tmp_path / "b", [null], version=0) == "INVALID"


def test_top_level_names_must_be_unique_and_equal_in_both_schemas_but_leaf_names_may_repeat(tmp_path):
    duplicate = pa.Table.from_arrays([pa.array([100], pa.int64()), pa.array([E], pa.int64()), pa.array([1.5]), pa.array([2.5])],
                                     names=["fetchedAt", "eventTime", "close", "close"])
    assert outcomes(tmp_path / "a", [duplicate]) == "INVALID"
    t = table()
    swapped = pa.schema([t.schema.field(i) for i in (3, 2, 1, 0)])
    forged = {"ARROW:schema": base64.b64encode(swapped.serialize().to_pybytes()).decode()}
    assert isinstance(outcomes(tmp_path / "b", [(t.replace_schema_metadata(None), {"store_schema": False})]), dict)
    path = tmp_path / "forged.parquet"
    with pq.ParquetWriter(path, t.schema, store_schema=False) as writer:
        writer.add_key_value_metadata(forged)
        writer.write_table(t)
    assert outcomes(tmp_path / "c", [path]) == "INVALID"
    nested = table(extra={"a": pa.array([{"x": 1}], pa.struct([("x", pa.int64())])), "b": pa.array([{"x": 1}], pa.struct([("x", pa.int64())])),
                          "l": pa.array([[1]], pa.list_(pa.int64()))})
    assert cells(outcomes(tmp_path / "d", [nested])) == [("float", 1.5)]


def test_an_absent_event_time_is_null_per_row(tmp_path):
    assert outcomes(tmp_path / "a", [table(event=None)]) == "INVALID"
    ignored = outcomes(tmp_path / "b", [table(event=None, fetched=200), table(fetched=50)])
    assert cells(ignored) == [("float", 1.5)]
    empty = table(rows=0, event=None)
    assert cells(outcomes(tmp_path / "c", [empty, table()])) == [("float", 1.5)]


def derived(tmp_path, upstream, tombstone=False, fetched=suite.P + 3000):
    """The suite's evidence and derived sources on files by hand: a poll, and a count over it whose `upstream` column is
    `upstream` (a pyarrow array, or None for no column)."""
    case = {**CASE, "sources": list(suite.derived), "version": fetched}
    out = {}
    for name, run in (("python", loaders.python), ("mm", loaders.rust)):
        root = tmp_path / name
        for source in ("poll", "events"):
            (root / source).mkdir(parents=True)
        pq.write_table(pa.table({"fetchedAt": [suite.P + 1000], "host": ["h"], "recv": [suite.P]}), root / "poll/0.parquet")
        columns = {"fetchedAt": [fetched], "coin": ["BTC"], "eventTime": [E], "count": [0.0], "slot": [E]}
        if upstream is not None:
            columns["upstream"] = upstream
        if tombstone:
            columns["tombstone"] = [True]
        pq.write_table(pa.table(columns), root / "events/0.parquet")
        out[name] = run(case, root)["result"]
    assert lean_check.same(out["python"], out["mm"]), out
    return out["python"]


LINEAGE = '{"recording": [["poll", ["h"], %d]]}' % suite.P


@pytest.mark.parametrize("kind", [pa.string(), pa.large_string()])
def test_lineage_is_read_from_either_string_type(tmp_path, kind):
    result = derived(tmp_path, pa.array([LINEAGE], kind))
    assert [len(k["timeline"]) for k in result["keys"]] == [1, 1]


@pytest.mark.parametrize("upstream", [pa.array([None], pa.string()), None, pa.array([1], pa.int64())])
def test_a_null_absent_or_non_string_lineage_on_a_derived_revision_is_invalid_and_never_read_on_a_tombstone(tmp_path, upstream):
    assert derived(tmp_path / "a", upstream) == "INVALID"
    tombstoned = derived(tmp_path / "b", upstream, tombstone=True)
    assert tombstoned != "INVALID" and [k["timeline"] for k in tombstoned["keys"] if k["source"] == "events"] == [[]]
