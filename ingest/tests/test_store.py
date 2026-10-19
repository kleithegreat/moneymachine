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
