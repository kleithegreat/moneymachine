import json
import shutil

import polars as pl
import pyarrow.parquet as pq
import pytest
from hypothesis import given, settings, strategies as st

from ingest.policy import DELTA, HOLDOUT_START, HOUR as H, POLICY
from ingest.store import Store, stores, write_split


def market_store(path, **policy):
    """A store holding venue datasets, with its own policy.json (the repository's, changed by `policy`)."""
    path.mkdir(parents=True, exist_ok=True)
    (path / "policy.json").write_text(json.dumps(POLICY | policy))
    return Store(path)


def rows(coins, hours, value=0.0):
    """Bars-like rows: the policy's rule makes each known at eventTime + DELTA."""
    return pl.DataFrame(
        [{"coin": c, "eventTime": h * H, "rate": value + h} for c in coins for h in hours],
        schema={"coin": pl.Utf8, "eventTime": pl.Int64, "rate": pl.Float64},
    )


@pytest.fixture
def store(tmp_path):
    s = market_store(tmp_path)
    s.write("bars_4h", rows(["A", "B"], range(10)), fetched_at=100, source="t")
    return s


def test_boundaries(store):
    t = 5 * H + DELTA
    assert store.as_of("bars_4h", t, 100).filter(pl.col("coin") == "A")["eventTime"].max() == 5 * H
    assert store.as_of("bars_4h", t - 1, 100).filter(pl.col("coin") == "A")["eventTime"].max() == 4 * H
    assert store.as_of("bars_4h", 5 * H, 100)["eventTime"].max() == 4 * H


def test_revision_after_cutoff_is_invisible(store):
    revised = rows(["A"], [3], value=1000.0)
    assert store.write("bars_4h", revised, fetched_at=200, source="t") == 1
    old = store.as_of("bars_4h", 9 * H, 100).filter((pl.col("coin") == "A") & (pl.col("eventTime") == 3 * H))
    new = store.as_of("bars_4h", 9 * H, 200).filter((pl.col("coin") == "A") & (pl.col("eventTime") == 3 * H))
    assert old["rate"].item() == 3.0
    assert new["rate"].item() == 1003.0


def test_identical_refetch_writes_nothing(store):
    assert store.write("bars_4h", rows(["A", "B"], range(10)), fetched_at=300, source="t") == 0


def test_files_are_immutable(store):
    with pytest.raises(FileExistsError):
        store.write("bars_4h", rows(["C"], [1]), fetched_at=100, source="t")
    assert all(not (p.stat().st_mode & 0o222) for p in store._files("bars_4h"))


@pytest.fixture(scope="module")
def revised(tmp_path_factory):
    s = market_store(tmp_path_factory.mktemp("s"))
    s.write("bars_4h", rows(["A", "B"], range(10)), fetched_at=100, source="t")
    s.write("bars_4h", rows(["A"], range(4, 8), value=0.5), fetched_at=200, source="t")
    return s


@settings(max_examples=1000, deadline=None)
@given(t=st.integers(min_value=-H, max_value=12 * H), version=st.sampled_from([50, 100, 200]))
def test_as_of_never_leaks(revised, t, version):
    s = revised
    got = s.as_of("bars_4h", t, version)
    assert (got["knownAt"] <= t).all() and (got["fetchedAt"] <= version).all()
    latest = s.revisions("bars_4h").filter(pl.col("fetchedAt") <= version).sort("fetchedAt").group_by(["coin", "eventTime"]).last()
    expect = latest.filter(pl.col("eventTime") + DELTA <= t).with_columns((pl.col("eventTime") + DELTA).alias("knownAt"))
    assert got.sort(["coin", "eventTime"]).equals(expect.sort(["coin", "eventTime"]).select(got.columns))


def test_a_view_is_the_latest_view_filtered_by_known_at(tmp_path):
    """ingest/witness.py relies on this: t enters as_of only through knownAt <= t, with corrections and tombstones."""
    s = market_store(tmp_path)
    s.write("bars_4h", rows(["A", "B"], range(10)), fetched_at=100, source="t")
    s.write("bars_4h", rows(["A"], range(4, 8), value=0.5), fetched_at=8 * H, source="t")
    s.write("bars_4h", rows(["A"], range(10)), fetched_at=9 * H, source="t", complete=pl.col("coin") == "B")
    for version in (100, 8 * H, 9 * H):
        latest = s.as_of("bars_4h", 2**62, version)
        for t in range(-H, 12 * H, H // 2):
            assert s.as_of("bars_4h", t, version).equals(latest.filter(pl.col("knownAt") <= t))


def test_knownat_is_never_stored(tmp_path):
    with pytest.raises(ValueError):
        Store(tmp_path).write("bars_4h", rows(["A"], [1]).with_columns(pl.lit(0).alias("knownAt")), 1, "t")


def test_a_later_revision_governs_its_key(tmp_path):
    """mm's resolution: the latest revision by the cutoff, known by its own fields, never an earlier one."""
    s = market_store(tmp_path)
    late = lambda r: pl.DataFrame({"coin": ["A"], "eventTime": [2 * H], "fundingRate": [0.0], "premium": [0.0], "reportedTime": [r]})
    s.write("funding", late(2 * H + 50), 100, "t")
    s.write("funding", late(2 * H + 887_645), 200, "t")
    assert s.as_of("funding", 2 * H + DELTA, 100)["knownAt"].to_list() == [2 * H + DELTA]
    assert s.as_of("funding", 2 * H + 887_645 + 60_000 - 1, 200).height == 0
    assert s.as_of("funding", 2 * H + 887_645 + 60_000, 200)["knownAt"].to_list() == [2 * H + 887_645 + 60_000]


def test_a_corrected_value_is_hidden_until_it_was_fetched(tmp_path):
    """Paper §5: a later correction hides a value rather than replacing it with something nobody had then; the
    original value, restored, is known by the rule again."""
    s = market_store(tmp_path)
    s.write("bars_4h", rows(["A"], [3]), fetched_at=100, source="t")
    s.write("bars_4h", rows(["A"], [3], value=7.0), fetched_at=50 * H, source="t")
    assert s.as_of("bars_4h", 3 * H + DELTA, 100)["rate"].to_list() == [3.0]
    assert s.as_of("bars_4h", 50 * H - 1, 50 * H).height == 0
    assert s.as_of("bars_4h", 50 * H, 50 * H)["knownAt"].to_list() == [50 * H]
    s.write("bars_4h", rows(["A"], [3]), fetched_at=60 * H, source="t")
    assert s.as_of("bars_4h", 3 * H + DELTA, 60 * H)["knownAt"].to_list() == [3 * H + DELTA]


def test_the_store_policy_governs_known_at(tmp_path):
    s = market_store(tmp_path, delta_ms=DELTA + 1000)
    s.write("bars_4h", rows(["A"], [3]), fetched_at=100, source="t")
    assert s.as_of("bars_4h", 2**62, 100)["knownAt"].to_list() == [3 * H + DELTA + 1000]


def test_search_store_refuses_holdout(tmp_path):
    search, holdout = stores(tmp_path)
    h0 = HOLDOUT_START // H
    df = rows(["A"], range(h0 - 5, h0 + 5))
    with pytest.raises(ValueError):
        search.write("bars_4h", df, fetched_at=1, source="t")
    assert write_split(search, holdout, "bars_4h", df, fetched_at=1, source="t") == (5, 5)
    assert search.revisions("bars_4h")["eventTime"].max() < HOLDOUT_START
    assert search.as_of("bars_4h", 2**62, 2**62)["eventTime"].max() < HOLDOUT_START
    assert holdout.revisions("bars_4h")["eventTime"].min() >= HOLDOUT_START


def posts(ids, content="a", key="forum"):
    return pl.DataFrame([{key: "f", "upstream_id": i, "eventTime": i * H, "sha": content} for i in ids],
                        schema={key: pl.Utf8, "upstream_id": pl.Int64, "eventTime": pl.Int64, "sha": pl.Utf8})


@pytest.mark.parametrize("key", ["forum", "space"])
def test_edits_tombstones_and_restorations_at_exact_boundaries(tmp_path, key):
    """C5.2: a raw source revision is known when fetched; content live at t is as_of(t, t), the latest fetched by t."""
    s = Store(tmp_path, key=[key, "upstream_id"])
    whole = pl.col(key) == "f"
    edited = pl.when(pl.col("upstream_id") == 3).then(pl.lit("b")).otherwise(pl.col("sha")).alias("sha")
    assert s.write("p", posts([1, 2, 3], key=key), 100, "t", complete=whole) == 3
    assert s.write("p", posts([1, 3], key=key).with_columns(edited), 200, "t", complete=whole) == 2
    assert s.write("p", posts([1, 2, 3], key=key), 300, "t", complete=whole) == 2
    assert s.write("p", posts([1], key=key), 400, "t", complete=pl.col(key) == "other") == 0
    view = lambda t, v=None: {r["upstream_id"]: r["sha"] for r in s.as_of("p", t, t if v is None else v).iter_rows(named=True)}
    assert view(99) == {}
    assert view(100) == view(199) == {1: "a", 2: "a", 3: "a"}
    assert view(200) == view(299) == {1: "a", 3: "b"}
    assert view(300) == {1: "a", 2: "a", 3: "a"}
    assert view(300, 299) == {1: "a", 3: "b"} and view(250, 199) == {1: "a", 2: "a", 3: "a"}
    tomb = s.revisions("p").filter(pl.col("tombstone").is_not_null())
    assert tomb.select("upstream_id", "eventTime", "fetchedAt").rows() == [(2, 2 * H, 200)]


def test_a_new_column_makes_every_row_a_revision(store):
    assert store.write("bars_4h", rows(["A", "B"], range(10)).with_columns(pl.lit("v2").alias("lineage")), 200, "t") == 20


def garble(path):
    """Every column chunk of a Parquet file but the event time's overwritten with garbage (its footer, and so its
    statistics, kept)."""
    meta, data = pq.ParquetFile(path).metadata, bytearray(path.read_bytes())
    for g in range(meta.num_row_groups):
        for j in range(meta.num_columns):
            col = meta.row_group(g).column(j)
            if col.path_in_schema != "eventTime":
                start = min(o for o in (col.dictionary_page_offset, col.data_page_offset) if o)
                data[start:start + col.total_compressed_size] = b"\xff" * col.total_compressed_size
    path.write_bytes(data)


CROSSING = HOLDOUT_START + H
FIXTURES = {"fetched after the version": (CROSSING, 200, None), "tombstone": (CROSSING, 50, True),
            "undecodable event time": (float(HOLDOUT_START - 2 * H), 200, None)}
VARIANTS = [({}, False), ({"coin": ["Z"], "rate": [-7.25], "source": ["u"], "hash": ["y"]}, False),
            ({"rate": [float("nan")]}, False), ({"rate": [[1.0, 2.0]]}, False), ({}, True)]


def staged(root, late, values, garbled):
    """C7.6's holdout-staging fixture under `root`: the search store's bars dataset, a row before the holdout fetched at
    100 and the row `late` (eventTime, fetchedAt, tombstone), one file each, `eventTime` of its value's type (Int64 or
    Double). The variant rewrites the late row's value columns with `values` and, if `garbled`, garbles its file's
    every chunk but the event time's: it differs from the others only outside the late row's event time. Version 100."""
    stores(root)
    d = root / "store" / "bars_4h"
    shutil.rmtree(d, ignore_errors=True)
    d.mkdir(parents=True)
    for i, (event, fetched, tombstone) in enumerate([(HOLDOUT_START - H, 100, None), late]):
        row = {"coin": ["A"], "eventTime": [event], "rate": [1.0], "fetchedAt": [fetched], "source": ["t"],
               "hash": ["x"], "tombstone": [tombstone]} | (values if i else {})
        pl.DataFrame(row, schema_overrides={"tombstone": pl.Boolean}).write_parquet(d / f"{i}.parquet")
    if garbled:
        garble(d / "1.parquet")


def outcome(as_of, capfd):
    """What a loader gives on a staged store: its refusal (type and message), or None if it gave a result, and what it
    printed."""
    try:
        as_of("bars_4h", 2**62, 100)
        refusal = None
    except Exception as e:
        refusal = type(e), str(e)
    printed = capfd.readouterr()
    return refusal, printed.out + printed.err


def refuses(fixture, refusal):
    """The fixture's refusal: a holdout crossing naming the boundary and the crossing event time, or the holdout
    check's own refusal of an event time it cannot check."""
    if refusal is None or not issubclass(refusal[0], ValueError):
        return False
    if fixture == "undecodable event time":
        return "the holdout check cannot be made" in refusal[1]
    return all(str(x) in refusal[1] for x in ("holdout", HOLDOUT_START, CROSSING))


def decides_on_event_times_alone(loader, root, fixture, capfd):
    """C7.6's named test 3: on every variant of the fixture the same refusal and output, and the fixture's refusal."""
    outcomes = []
    for values, garbled in VARIANTS:
        staged(root, FIXTURES[fixture], values, garbled)
        outcomes.append(outcome(loader(root), capfd))
    assert refuses(fixture, outcomes[0][0]) and all(o == outcomes[0] for o in outcomes), outcomes


@pytest.fixture
def root(tmp_path_factory):
    """A store root whose path names neither "holdout" nor the holdout boundary, so that no refusal naming a path
    passes for a holdout refusal."""
    return tmp_path_factory.mktemp("staged")


def files(root, dataset):
    return sorted((root / "store" / dataset).glob("*.parquet"))


def holdout_check(times):
    """The check on event times alone: its refusal, or None."""
    if times["eventTime"].dtype != pl.Int64:
        return "the holdout check cannot be made: an event time is not an Int64"
    if (late := times.filter(pl.col("eventTime") >= HOLDOUT_START)).height:
        return f"holdout crossing: event time {late['eventTime'][0]} at or after {HOLDOUT_START}"


def event_times(root, dataset):
    return pl.concat([pl.read_parquet(f, columns=["eventTime"]) for f in files(root, dataset)], how="diagonal_relaxed")


def resolving_first(root):
    """A control: it reads and resolves every file first, then refuses a crossing."""
    def as_of(dataset, t, version):
        frame = pl.concat([pl.read_parquet(f) for f in files(root, dataset)], how="diagonal_relaxed")
        resolved = frame.filter(pl.col("fetchedAt") <= version).group_by("coin", "eventTime").last()
        if refusal := holdout_check(frame.select("eventTime")):
            raise ValueError(refusal)
        return resolved
    return as_of


def eager(root):
    """A control, faithful to RULES.md §6 but for staging: it reads every column of every file, refusing a file that
    does not decode as an invalid dataset, and only then makes the holdout check."""
    def as_of(dataset, t, version):
        try:
            frame = pl.concat([pl.read_parquet(f) for f in files(root, dataset)], how="diagonal_relaxed")
        except pl.exceptions.PolarsError as e:
            raise ValueError(f"{dataset}: invalid dataset, a row does not decode") from e
        if refusal := holdout_check(frame.select("eventTime")):
            raise ValueError(refusal)
        return frame
    return as_of


def telling(root):
    """A control that checks event times alone first, but whose refusal carries the refused file's decoded `rate`."""
    def as_of(dataset, t, version):
        if refusal := holdout_check(event_times(root, dataset)):
            try:
                refusal += f" (rate {pl.read_parquet(files(root, dataset)[-1], columns=['rate'])['rate'][0]})"
            except pl.exceptions.PolarsError:
                pass
            raise ValueError(refusal)
        return event_times(root, dataset)
    return as_of


def surviving(root):
    """A loader that reads every column of every file, but survives a file that does not decode, reading its event
    times alone, until the holdout check has refused or passed (the round 6 and 7 reviews' probe). Its decision
    depends on event times alone, so it passes."""
    def as_of(dataset, t, version):
        frames, bad = [], []
        for f in files(root, dataset):
            try:
                frames.append(pl.read_parquet(f))
            except pl.exceptions.PolarsError:
                bad.append(f)
                frames.append(pl.read_parquet(f, columns=["eventTime"]))
        if refusal := holdout_check(pl.concat([f.select("eventTime") for f in frames], how="diagonal_relaxed")):
            raise ValueError(refusal)
        if bad:
            raise ValueError(f"{dataset}: invalid dataset, {len(bad)} files do not decode")
        return frames
    return as_of


FIXTURE = pytest.mark.parametrize("fixture", FIXTURES)


@FIXTURE
@pytest.mark.parametrize("control", [resolving_first, eager, telling])
def test_loaders_whose_refusal_depends_on_a_holdout_rows_values_fail_test_3(root, capfd, fixture, control):
    with pytest.raises(AssertionError):
        decides_on_event_times_alone(control, root, fixture, capfd)


@FIXTURE
def test_a_loader_deciding_on_event_times_alone_passes_test_3(root, capfd, fixture):
    decides_on_event_times_alone(surviving, root, fixture, capfd)


STAGING = "audit/stage7/holdout-staging.md: ingest/store.py has no holdout check on reads"


@pytest.mark.xfail(strict=True, reason=STAGING)
@FIXTURE
def test_holdout_check_decides_on_event_times_alone(root, capfd, fixture):
    """C7.6's named test 3 on the production loader: a holdout row, fetched after the version or a tombstone, is
    refused as a holdout crossing, and an event time that is not an Int64 by the check's own refusal, alike whatever
    the row's other columns hold."""
    decides_on_event_times_alone(lambda root: stores(root)[0].as_of, root, fixture, capfd)
