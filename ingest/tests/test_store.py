import io
import json
from pathlib import Path

import polars as pl
import pyarrow as pa
import pyarrow.parquet as pq
import pytest
from hypothesis import given, settings, strategies as st

from ingest.policy import DELTA, HOLDOUT_START, HOUR as H, POLICY
import ingest.store
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


def chunks(path, keep="eventTime"):
    """The byte ranges of every column chunk of a Parquet file but `keep`'s, as its footer gives them."""
    meta = pq.ParquetFile(path).metadata
    for g in range(meta.num_row_groups):
        for j in range(meta.num_columns):
            col = meta.row_group(g).column(j)
            if col.path_in_schema != keep:
                start = min(o for o in (col.dictionary_page_offset, col.data_page_offset) if o)
                yield start, start + col.total_compressed_size


def garble(path):
    """Every column chunk of a Parquet file but the event time's overwritten with garbage."""
    data = bytearray(path.read_bytes())
    for a, b in list(chunks(path)):
        data[a:b] = b"\xff" * (b - a)
    path.write_bytes(data)


OPEN = ingest.store.open_parquet


class Recorded(io.RawIOBase):
    """A file opened by the store's reader, recording the byte range of each read into `reads`."""

    def __init__(self, path, reads):
        self.path, self.file, self.reads = Path(path), OPEN(path), reads

    def readable(self):
        return True

    def seekable(self):
        return True

    def seek(self, offset, whence=0):
        return self.file.seek(offset, whence)

    def tell(self):
        return self.file.tell()

    def readinto(self, b):
        start, n = self.file.tell(), self.file.readinto(b)
        self.reads.append((self.path, start, n))
        return n

    def close(self):
        self.file.close()
        super().close()


def recording(monkeypatch):
    """Every file the store's reader opens from now on, recorded: the list of (path, start, length) it reads."""
    reads = []
    monkeypatch.setattr(ingest.store, "open_parquet", lambda path: Recorded(path, reads))
    return reads


def met(reads):
    """The reads that meet a column chunk other than the event time's."""
    return [(p.name, s, n) for p, s, n in reads if n and any(s < b and a < s + n for a, b in chunks(p))]


@pytest.fixture
def root(tmp_path_factory):
    """A store root whose path names neither "holdout" nor the holdout boundary, so that no refusal naming a path
    passes for a holdout refusal."""
    return tmp_path_factory.mktemp("staged")


def staged(root, late, garbled):
    """C7.6's holdout-staging fixture: the search store's bars dataset, a row before the holdout fetched at 100 and the
    row `late` (eventTime, fetchedAt, tombstone), one file each, `eventTime` of its value's type (Int64 or Double), and
    if `garbled` every other column garbled. Its version is 100."""
    search, _ = stores(root)
    d = root / "store" / "bars_4h"
    d.mkdir(parents=True)
    for i, (event, fetched, tombstone) in enumerate([(HOLDOUT_START - H, 100, None), late]):
        pl.DataFrame({"coin": ["A"], "eventTime": [event], "rate": [1.0], "fetchedAt": [fetched], "source": ["t"],
                      "hash": ["x"], "tombstone": [tombstone]},
                     schema_overrides={"tombstone": pl.Boolean}).write_parquet(d / f"{i}.parquet")
        if garbled:
            garble(d / f"{i}.parquet")
    return search, sorted(d.glob("*.parquet"))


CROSSING = HOLDOUT_START + H
IN_HOLDOUT = [(CROSSING, 200, None), (CROSSING, 50, True)]
UNDECODABLE = (float(HOLDOUT_START - 2 * H), 200, None)


def refuses_crossing(as_of):
    """Refused as a holdout crossing, naming the boundary and the crossing event time."""
    with pytest.raises(ValueError) as refusal:
        as_of("bars_4h", 2**62, 100)
    assert all(str(x) in str(refusal.value) for x in ("holdout", HOLDOUT_START, CROSSING)), refusal.value


def refuses_uncheckable(as_of):
    """Refused by the holdout check's own refusal, not as an invalid dataset."""
    with pytest.raises(ValueError, match="the holdout check cannot be made"):
        as_of("bars_4h", 2**62, 100)


def reads_event_times_alone(monkeypatch, as_of, files, check):
    """C7.6's named test 3: `check`'s refusal, every file opened through the store's reader, and no byte read before
    the refusal in a column chunk but the event time's."""
    reads = recording(monkeypatch)
    check(as_of)
    assert {p for p, _, _ in reads} == set(files) and not met(reads), met(reads)


def event_times(path):
    """A file's event times alone, through the store's reader: its footer by the length the file states, then the
    event time's column chunk."""
    with ingest.store.open_parquet(path) as f:
        f.seek(-8, 2)
        n = int.from_bytes(f.read(4), "little")
        f.seek(-8 - n, 2)
        meta = pq.read_metadata(pa.BufferReader(b"PAR1" + f.read(n + 8)))
        return pq.ParquetFile(f, metadata=meta).read(columns=["eventTime"])["eventTime"].to_pylist()


def read(path, columns=None):
    with ingest.store.open_parquet(path) as f:
        return pl.read_parquet(f, columns=columns)


def holdout_check(frame):
    if frame["eventTime"].dtype != pl.Int64:
        raise ValueError("the holdout check cannot be made: an event time is not an Int64")
    if (late := frame.filter(pl.col("eventTime") >= HOLDOUT_START)).height:
        raise ValueError(f"holdout crossing: event time {late['eventTime'][0]} at or after {HOLDOUT_START}")
    return frame


def eager(root):
    """A control, faithful to RULES.md §6 but for staging: it reads every column of every file, refusing a row that
    does not decode as an invalid dataset, and only then makes the holdout check."""
    def as_of(dataset, t, version):
        try:
            frame = pl.concat([read(f) for f in sorted((root / "store" / dataset).glob("*.parquet"))],
                              how="diagonal_relaxed")
        except pl.exceptions.PolarsError as e:
            raise ValueError(f"{dataset}: invalid dataset, a row does not decode") from e
        return holdout_check(frame)
    return as_of


def surviving(root):
    """A control that reads every column of every file too, but survives a file that does not decode, reading its
    event times alone, until the holdout check has refused or passed (the round 6 reviews' probe)."""
    def as_of(dataset, t, version):
        frames, bad = [], []
        for f in sorted((root / "store" / dataset).glob("*.parquet")):
            try:
                frames.append(read(f))
            except pl.exceptions.PolarsError:
                bad.append(f)
                frames.append(read(f, ["eventTime"]))
        frame = holdout_check(pl.concat(frames, how="diagonal_relaxed"))
        if bad:
            raise ValueError(f"{dataset}: invalid dataset, {len(bad)} files do not decode")
        return frame
    return as_of


CASES = pytest.mark.parametrize("late, check", [(IN_HOLDOUT[0], refuses_crossing), (IN_HOLDOUT[1], refuses_crossing),
                                                (UNDECODABLE, refuses_uncheckable)],
                                ids=["fetched after the version", "tombstone", "undecodable event time"])
GARBLED = pytest.mark.parametrize("garbled", [False, True], ids=["as written", "garbled"])


@CASES
@GARBLED
@pytest.mark.parametrize("control", [eager, surviving])
def test_loaders_reading_every_column_first_fail_test_3(root, monkeypatch, late, check, garbled, control):
    """Test 3's controls: on its fixture the event times alone can be read, the footer and the event time's chunk
    only, and each loader reading every column first fails."""
    _, files = staged(root, late, garbled)
    reads = recording(monkeypatch)
    assert [event_times(f) for f in files] == [[HOLDOUT_START - H], [late[0]]] and not met(reads)
    with pytest.raises(AssertionError):
        reads_event_times_alone(monkeypatch, control(root), files, check)


STAGING = "audit/stage7/holdout-staging.md: ingest/store.py has no holdout check on reads, and reads every column first"


@pytest.mark.xfail(strict=True, reason=STAGING)
@GARBLED
@pytest.mark.parametrize("late", IN_HOLDOUT, ids=["fetched after the version", "tombstone"])
def test_holdout_check_reads_event_times_alone(root, monkeypatch, late, garbled):
    """C7.6's named test 3: one row's event time in the holdout is refused as a holdout crossing, reading event times
    alone, whatever the row (here fetched after the version, or a tombstone)."""
    search, files = staged(root, late, garbled)
    reads_event_times_alone(monkeypatch, search.as_of, files, refuses_crossing)


@pytest.mark.xfail(strict=True, reason=STAGING)
@GARBLED
def test_an_undecodable_event_time_refuses_before_any_value(root, monkeypatch, garbled):
    """Test 3's variant: an event time that is not an Int64, here in a row fetched after the version, is refused by the
    holdout check before any other column is read."""
    search, files = staged(root, UNDECODABLE, garbled)
    reads_event_times_alone(monkeypatch, search.as_of, files, refuses_uncheckable)
