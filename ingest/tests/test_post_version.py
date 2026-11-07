"""What lies beyond the version or the boundary stays unread (kernel/SOURCES.md §2): a file whose rows are all fetched
after V changes nothing at V whatever its other columns hold, and a failing decode is a refusal by RULES.md §7's code.
Argon's review of slice 5 (`audit/stage7/slice5-review-argon.md`), F3, F5 and F6."""

import os

import pyarrow as pa
import pyarrow.parquet as pq
import pytest

from ingest import resolve
from ingest.policy import HOLDOUT_START
from ingest.tests.test_store import market_store, rows

DATASET = "bars_4h"


def post_version_file(store, rate, fetched=200):
    """A file of the dataset, fetched after the version, holding `rate` (a pyarrow array) for one row."""
    table = pa.table({"coin": ["A"], "eventTime": pa.array([3 * 3_600_000], pa.int64()), "rate": rate,
                      "fetchedAt": pa.array([fetched], pa.int64())})
    path = store.root / DATASET / f"{fetched}.parquet"
    pq.write_table(table, path)
    return path


def garble(path, keep):
    """Every column chunk of a Parquet file not in `keep` overwritten with garbage (its footer kept)."""
    meta, data = pq.ParquetFile(path).metadata, bytearray(path.read_bytes())
    for g in range(meta.num_row_groups):
        for j in range(meta.num_columns):
            col = meta.row_group(g).column(j)
            if col.path_in_schema not in keep:
                start = min(o for o in (col.dictionary_page_offset, col.data_page_offset) if o)
                data[start:start + col.total_compressed_size] = b"\xff" * col.total_compressed_size
    os.chmod(path, 0o644)
    path.write_bytes(data)


@pytest.fixture
def early(tmp_path):
    store = market_store(tmp_path)
    store.write(DATASET, rows(["A", "B"], range(10)), fetched_at=100, source="t")
    return store


@pytest.mark.parametrize("rate", [pa.array([[1.5]], pa.list_(pa.float64())), pa.array(["1.5"]), pa.array([1], pa.int64())],
                         ids=["list", "string", "int"])
def test_a_file_fetched_after_the_version_leaves_the_view_alone(early, rate):
    t = 9 * 3_600_000
    before = early.as_of(DATASET, t, 100), early.entries(DATASET, 100)
    post_version_file(early, rate)
    early._cache.clear()
    after = early.as_of(DATASET, t, 100), early.entries(DATASET, 100)
    assert after[0].equals(before[0]) and after[1].equals(before[1])
    assert after[0].schema == before[0].schema


def test_an_undecodable_column_of_a_file_fetched_after_the_version_is_not_decoded(early):
    t = 9 * 3_600_000
    before = early.as_of(DATASET, t, 100)
    garble(post_version_file(early, pa.array([1.5])), keep={"eventTime", "fetchedAt"})
    early._cache.clear()
    assert early.as_of(DATASET, t, 100).equals(before)


def test_an_undecodable_column_of_a_file_read_at_the_version_refuses_as_invalid(early):
    garble(early._files(DATASET)[0], keep={"eventTime", "fetchedAt"})
    with pytest.raises(resolve.Refusal) as e:
        early.as_of(DATASET, 9 * 3_600_000, 100)
    assert e.value.code == "INVALID"


def test_an_undecodable_event_time_of_another_type_is_uncheckable_not_a_decode_error(tmp_path):
    store = market_store(tmp_path)
    store.write(DATASET, rows(["A"], range(3)), fetched_at=100, source="t")
    table = pa.table({"coin": ["A"], "eventTime": pa.array(["x"]), "rate": [1.5], "fetchedAt": pa.array([200], pa.int64())})
    path = tmp_path / DATASET / "200.parquet"
    pq.write_table(table, path)
    garble(path, keep={"fetchedAt"})
    searching = type(store)(tmp_path, event_before=HOLDOUT_START)
    with pytest.raises(ValueError) as e:
        searching.as_of(DATASET, 9 * 3_600_000, 100)
    assert type(e.value) is ValueError and str(e.value) == resolve.UNCHECKABLE


def test_a_retraction_delivers_no_stored_value(tmp_path):
    store = market_store(tmp_path)
    store.write(DATASET, rows(["A"], [2]), fetched_at=100, source="t")
    table = pa.table({"coin": ["A"], "eventTime": pa.array([2 * 3_600_000], pa.int64()), "rate": [0.99],
                      "tombstone": [True], "fetchedAt": pa.array([200], pa.int64())})
    pq.write_table(table, tmp_path / DATASET / "200.parquet")
    entries = store.entries(DATASET, 200)
    assert entries["retraction"].to_list() == [False, True]
    assert entries["rate"].to_list() == [2.0, None]
    assert entries["coin"].to_list() == ["A", "A"] and entries["eventTime"].to_list() == [2 * 3_600_000] * 2


def test_a_search_store_reads_the_bytes_it_checked(tmp_path):
    """SOURCES.md §7: evaluation reads the admitted bytes, never a reopened path. A file overwritten in place with
    the same size and mtime after the holdout check passed does not put a holdout row into a later view."""
    from ingest.policy import HOLDOUT_START
    from ingest.store import Store
    market_store(tmp_path)
    (tmp_path / DATASET).mkdir()
    table = pa.table({"coin": ["A"], "eventTime": pa.array([2 * 3_600_000], pa.int64()), "rate": [1.5],
                      "fetchedAt": pa.array([100], pa.int64())})
    pq.write_table(table, tmp_path / DATASET / "100.parquet", compression="NONE", use_dictionary=False, write_statistics=False)
    search = Store(tmp_path, event_before=HOLDOUT_START)
    path = search._files(DATASET)[0]
    assert search.as_of(DATASET, 9 * 3_600_000, 100).height == 1
    data, stat = bytearray(path.read_bytes()), path.stat()
    old, new = (2 * 3_600_000).to_bytes(8, "little"), (HOLDOUT_START + 3_600_000).to_bytes(8, "little")
    assert data.count(old) == 1
    path.chmod(0o644)
    path.write_bytes(bytes(data).replace(old, new))
    os.utime(path, ns=(stat.st_atime_ns, stat.st_mtime_ns))
    assert search.as_of(DATASET, HOLDOUT_START * 2, 101)["eventTime"].to_list() == [2 * 3_600_000]
