import polars as pl
import pytest
from hypothesis import given, settings, strategies as st

from ingest.store import DELTA, HOLDOUT_START, Store, stores, write_split

H = 3_600_000


def rows(coins, hours, value=0.0):
    return pl.DataFrame(
        [{"coin": c, "eventTime": h * H, "knownAt": h * H + DELTA, "rate": value + h} for c in coins for h in hours],
        schema={"coin": pl.Utf8, "eventTime": pl.Int64, "knownAt": pl.Int64, "rate": pl.Float64},
    )


@pytest.fixture
def store(tmp_path):
    s = Store(tmp_path)
    s.write("f", rows(["A", "B"], range(10)), fetched_at=100, source="t")
    return s


def test_boundaries(store):
    t = 5 * H + DELTA
    assert store.as_of("f", t, 100).filter(pl.col("coin") == "A")["eventTime"].max() == 5 * H
    assert store.as_of("f", t - 1, 100).filter(pl.col("coin") == "A")["eventTime"].max() == 4 * H
    assert store.as_of("f", 5 * H, 100)["eventTime"].max() == 4 * H


def test_revision_after_cutoff_is_invisible(store):
    revised = rows(["A"], [3], value=1000.0)
    assert store.write("f", revised, fetched_at=200, source="t") == 1
    old = store.as_of("f", 9 * H, 100).filter((pl.col("coin") == "A") & (pl.col("eventTime") == 3 * H))
    new = store.as_of("f", 9 * H, 200).filter((pl.col("coin") == "A") & (pl.col("eventTime") == 3 * H))
    assert old["rate"].item() == 3.0
    assert new["rate"].item() == 1003.0


def test_identical_refetch_writes_nothing(store):
    assert store.write("f", rows(["A", "B"], range(10)), fetched_at=300, source="t") == 0


def test_files_are_immutable(store):
    with pytest.raises(FileExistsError):
        store.write("f", rows(["C"], [1]), fetched_at=100, source="t")
    assert all(not (p.stat().st_mode & 0o222) for p in store._files("f"))


@settings(max_examples=1000, deadline=None)
@given(t=st.integers(min_value=-H, max_value=12 * H), version=st.sampled_from([50, 100, 200]))
def test_as_of_never_leaks(tmp_path_factory, t, version):
    s = Store(tmp_path_factory.mktemp("s"))
    s.write("f", rows(["A", "B"], range(10)), fetched_at=100, source="t")
    s.write("f", rows(["A"], range(4, 8), value=0.5), fetched_at=200, source="t")
    got = s.as_of("f", t, version)
    assert (got["knownAt"] <= t).all() and (got["fetchedAt"] <= version).all()
    all_ = s.revisions("f").filter((pl.col("knownAt") <= t) & (pl.col("fetchedAt") <= version))
    expect = all_.sort("fetchedAt").group_by(["coin", "eventTime"]).last()
    assert got.sort(["coin", "eventTime"]).equals(expect.sort(["coin", "eventTime"]).select(got.columns))


def test_search_store_refuses_holdout(tmp_path):
    search, holdout = stores(tmp_path)
    h0 = HOLDOUT_START // H
    df = rows(["A"], range(h0 - 5, h0 + 5))
    with pytest.raises(ValueError):
        search.write("f", df, fetched_at=1, source="t")
    assert write_split(search, holdout, "f", df, fetched_at=1, source="t") == (5, 5)
    assert search.revisions("f")["eventTime"].max() < HOLDOUT_START
    assert search.as_of("f", 2**62, 2**62)["eventTime"].max() < HOLDOUT_START
    assert holdout.revisions("f")["eventTime"].min() >= HOLDOUT_START


def posts(ids, content="a"):
    return pl.DataFrame([{"forum": "f", "upstream_id": i, "eventTime": i * H, "sha": content} for i in ids],
                        schema={"forum": pl.Utf8, "upstream_id": pl.Int64, "eventTime": pl.Int64, "sha": pl.Utf8})


def test_edits_tombstones_and_restorations_at_exact_boundaries(tmp_path):
    """C5.2: a raw source revision is known when fetched; content live at t is the latest fetched by t."""
    s = Store(tmp_path, key=["forum", "upstream_id"])
    whole = pl.col("forum") == "f"
    edited = pl.when(pl.col("upstream_id") == 3).then(pl.lit("b")).otherwise(pl.col("sha")).alias("sha")
    assert s.write("p", posts([1, 2, 3]), 100, "t", complete=whole) == 3
    assert s.write("p", posts([1, 3]).with_columns(edited), 200, "t", complete=whole) == 2
    assert s.write("p", posts([1, 2, 3]), 300, "t", complete=whole) == 2
    assert s.write("p", posts([1]), 400, "t", complete=pl.col("forum") == "other") == 0
    view = lambda t, v=10**9: {r["upstream_id"]: r["sha"] for r in s.as_of("p", t, v).iter_rows(named=True)}
    assert view(99) == {}
    assert view(100) == view(199) == {1: "a", 2: "a", 3: "a"}
    assert view(200) == view(299) == {1: "a", 3: "b"}
    assert view(300) == {1: "a", 2: "a", 3: "a"}
    assert view(300, 299) == {1: "a", 3: "b"} and view(250, 199) == {1: "a", 2: "a", 3: "a"}
    tomb = s.revisions("p").filter(pl.col("tombstone").is_not_null())
    assert tomb.select("upstream_id", "eventTime", "knownAt", "fetchedAt").rows() == [(2, 2 * H, 200, 200)]
