import json
import random
import sys

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


V = 100
EARLY = HOLDOUT_START - H
CROSSING = HOLDOUT_START + H
FIXTURES = {"own file": [CROSSING + H, CROSSING], "shared file": [CROSSING + H, CROSSING],
            "undecodable event time": [float(EARLY - H), float(EARLY - 2 * H)],
            "null event time": [CROSSING, None], "event time below range": [CROSSING, -2**62 - 1],
            "event time above range": [CROSSING, 2**62], "absent event time": [None, None]}
SCHEMA = {"coin": pl.Utf8, "eventTime": pl.Int64, "rate": pl.Float64, "fetchedAt": pl.Int64, "source": pl.Utf8,
          "hash": pl.Utf8, "tombstone": pl.Boolean}
RATES = [  # a value column's type, the early row's value of it in a shared file, and a draw of one
    (pl.Float64, 1.0, lambda r: r.choice([float("nan"), float("inf"), -float("inf")]) if r.random() < 0.2
     else r.choice([-1.0, 1.0]) * 10 ** r.uniform(-2, 8)),
    (pl.Int64, 1, lambda r: r.randrange(-2**63, 2**63)),
    (pl.Utf8, "1", lambda r: str(r.random())),
    (pl.List(pl.Float64), [1.0], lambda r: [r.random() for _ in range(r.randrange(3))]),
]


def plain(fetched, tombstone):
    return 0, [{"coin": "A", "rate": 1.0, "fetchedAt": fetched, "source": "t", "hash": "x", "tombstone": tombstone}] * 2, False


def drawn(r):
    kind = r.choice([0, 0, 0, 1, 2, 3])
    late = lambda: {"coin": r.choice([None, str(r.random())]), "rate": None if r.random() < 0.1 else RATES[kind][2](r),
                    "fetchedAt": r.choice([None, r.randrange(-2**63, V + 1), r.randrange(V + 1, 2**63)]),
                    "source": str(r.random()), "hash": str(r.random()), "tombstone": r.choice([None, True, False])}
    return kind, [late(), late()], r.random() < 0.3


def variants(fixture):
    """The late rows eligible and live, fetched after the version, tombstoned, then drawn: every column but the event
    time varied, their file garbled or not."""
    r = random.Random(f"20261104 {fixture}")
    return [plain(50, None), plain(200, None), plain(50, True), plain(None, None)] + [drawn(r) for _ in range(32)]


def staged(root, fixture, variant):
    """C7.6's holdout-staging fixture under `root`, in the search store's bars dataset: an early row, fetched at 100,
    and two late rows of the fixture's event times, in their own file or sharing the early row's; the variant gives
    the late rows' other columns and garbles their file, the last, but for its event-time chunk. Version 100."""
    stores(root)
    d = root / "store" / "bars_4h"
    d.mkdir(parents=True)
    kind, late, garbled = variant
    rate, same, _ = RATES[kind]
    late = [row | {"eventTime": e} for row, e in zip(late, FIXTURES[fixture])]
    early = {"coin": "A", "eventTime": EARLY, "rate": 1.0, "fetchedAt": V, "source": "t", "hash": "x", "tombstone": None}
    late_types = SCHEMA | {"rate": rate, "eventTime": pl.Float64 if fixture == "undecodable event time" else pl.Int64}
    if fixture == "absent event time":
        late_types.pop("eventTime")
    parts = [([early | {"rate": same}] + late, late_types)] if fixture == "shared file" else [([early], SCHEMA), (late, late_types)]
    for i, (part, schema) in enumerate(parts):
        pl.DataFrame(part, schema=schema).write_parquet(d / f"{i}.parquet")
    if garbled:
        garble(d / f"{len(parts) - 1}.parquet")


def outcome(as_of, capfd, dataset="bars_4h"):
    """What a loader gives on a staged store, its refusal (type and message) or its result, then its stdout and its
    stderr, apart."""
    try:
        got = as_of(dataset, 2**62, V)
        given = "result", got.columns, got.rows()
    except Exception as e:
        given = "refusal", type(e), str(e)
    printed = capfd.readouterr()
    return given, printed.out, printed.err


def decides_on_event_times_alone(loader, root, fixture, capfd):
    """C7.6's net: the exact refusal, silent channels, then an independent dataset through the same production API.
    Neither dataset changes; retaining the refused dataset's authorized event-time inventory is permitted."""
    diagnostic = ("the holdout check cannot be made: an event time is not a non-null Int64 in range"
                  if fixture not in ("own file", "shared file") else
                  f"holdout crossing: event time {CROSSING} at or after {HOLDOUT_START}")
    for i, variant in enumerate(variants(fixture)):
        snapshot = root / str(i)
        staged(snapshot, fixture, variant)
        clean = "events_clean"
        stores(snapshot)[0].write(clean, rows(["B"], [EARLY // H], value=7.0), V, "t")
        as_of = loader(snapshot)
        first = outcome(as_of, capfd)
        assert first[0] == ("refusal", ValueError, diagnostic), f"refusal: {first}"
        assert first[1] == "", f"stdout: {first}"
        assert first[2] == "", f"stderr: {first}"
        again = outcome(as_of, capfd, clean)
        fresh = outcome(loader(snapshot), capfd, clean)
        assert fresh[0][0] == "result" and fresh[0][2], f"state: {fresh}"
        assert again == fresh, f"state: {again} {fresh}"


@pytest.fixture
def root(tmp_path_factory):
    """A store root whose path names neither "holdout" nor the holdout boundary, so that no refusal naming a path
    passes for a holdout refusal."""
    return tmp_path_factory.mktemp("staged")


def files(root, dataset):
    return sorted((root / "store" / dataset).glob("*.parquet"))


def holdout_check(times):
    """The check on event times alone: its refusal, or None."""
    events = times["eventTime"]
    if len(events) and (events.dtype != pl.Int64 or events.null_count() or not events.is_between(-2**62, 2**62 - 1).all()):
        return "the holdout check cannot be made: an event time is not a non-null Int64 in range"
    if (least := times.filter(pl.col("eventTime") >= HOLDOUT_START)["eventTime"].min()) is not None:
        return f"holdout crossing: event time {least} at or after {HOLDOUT_START}"


@pytest.mark.parametrize("event", [None, -2**62 - 1, 2**62])
def test_uncheckable_int64_precedes_a_crossing(event):
    times = pl.DataFrame({"eventTime": [CROSSING, event]}, schema={"eventTime": pl.Int64})
    assert holdout_check(times) == "the holdout check cannot be made: an event time is not a non-null Int64 in range"


def test_holdout_check_accepts_the_inclusive_range_ends():
    assert holdout_check(pl.DataFrame({"eventTime": [-2**62]}, schema={"eventTime": pl.Int64})) is None
    assert holdout_check(pl.DataFrame({"eventTime": [2**62 - 1]}, schema={"eventTime": pl.Int64})) == (
        f"holdout crossing: event time {2**62 - 1} at or after {HOLDOUT_START}")


@pytest.mark.parametrize("dtype", [pl.Int64, pl.Float64])
def test_an_empty_event_column_contributes_no_event_times(tmp_path, dtype):
    empty, early = tmp_path / "empty.parquet", tmp_path / "early.parquet"
    frame = pl.DataFrame(schema={"eventTime": dtype})
    assert holdout_check(frame) is None
    frame.write_parquet(empty)
    pl.DataFrame({"eventTime": [EARLY]}, schema={"eventTime": pl.Int64}).write_parquet(early)
    assert holdout_check(event_times([early, empty])) is None


def event_times(pinned):
    """Project each pinned file; a missing column is null per row, including no nulls in an empty file."""
    frames = []
    for f in pinned:
        footer = pq.ParquetFile(f)
        frames.append(pl.read_parquet(f, columns=["eventTime"])
                      if footer.metadata.num_rows and "eventTime" in footer.schema_arrow.names else
                      pl.DataFrame({"eventTime": [None] * footer.metadata.num_rows}, schema={"eventTime": pl.Int64}))
    return pl.concat(frames, how="diagonal_relaxed")


@pytest.mark.parametrize("count", [0, 1])
def test_a_missing_event_column_is_null_per_row_not_a_footer_error(tmp_path, count):
    f = tmp_path / "0.parquet"
    pl.DataFrame({"fetchedAt": [200] * count}, schema={"fetchedAt": pl.Int64}).write_parquet(f)
    assert holdout_check(event_times([f])) == (
        "the holdout check cannot be made: an event time is not a non-null Int64 in range" if count else None)


def everything(root, dataset):
    return pl.concat([pl.read_parquet(f) for f in files(root, dataset)], how="diagonal_relaxed")


def projecting(root):
    """Positive control: pin each dataset's files and event times; decode only those files after the whole check passes."""
    inventories = {}
    def as_of(dataset, t, version):
        if dataset not in inventories:
            pinned = files(root, dataset)
            inventories[dataset] = pinned, event_times(pinned)
        pinned, times = inventories[dataset]
        if refusal := holdout_check(times):
            raise ValueError(refusal)
        return pl.concat([pl.read_parquet(f) for f in pinned], how="diagonal_relaxed").filter(pl.col("fetchedAt") <= version)
    return as_of


def resolving_first(root):
    """Rounds 4 to 8: reads and resolves every file first, then refuses."""
    def as_of(dataset, t, version):
        frame = everything(root, dataset)
        resolved = frame.filter(pl.col("fetchedAt") <= version).group_by("coin", "eventTime").last()
        if refusal := holdout_check(frame.select("eventTime")):
            raise ValueError(refusal)
        return resolved
    return as_of


def eager(root):
    """Rounds 5 to 8: reads every column of every file, refusing a file that does not decode as an invalid dataset,
    and only then makes the check."""
    def as_of(dataset, t, version):
        try:
            frame = everything(root, dataset)
        except pl.exceptions.PolarsError as e:
            raise ValueError(f"{dataset}: invalid dataset, a row does not decode") from e
        if refusal := holdout_check(frame.select("eventTime")):
            raise ValueError(refusal)
        return frame
    return as_of


def peek(f, column):
    """`column` of file f, decoded, or nothing if it does not decode."""
    try:
        return pl.read_parquet(f, columns=[column])[column].to_list()
    except pl.exceptions.PolarsError:
        return []


def statistic(f, column):
    """The footer's max statistic of `column`'s chunk, no page decoded."""
    meta = pq.ParquetFile(f).metadata.row_group(0)
    chunk = next(meta.column(j) for j in range(meta.num_columns) if meta.column(j).path_in_schema.split(".")[0] == column)
    return chunk.statistics.max if chunk.statistics is not None and chunk.statistics.has_min_max else None


def above(values, bound):
    return any(isinstance(v, float) and v > bound for v in values)


def amending(amend):
    """A loader shaped as `projecting`, whose refusal `amend(file, refusal)` amends from the late rows' file."""
    def loader(root):
        check = projecting(root)
        def as_of(dataset, t, version):
            try:
                return check(dataset, t, version)
            except ValueError as e:
                raise ValueError(amend(files(root, dataset)[-1], str(e))) from None
        return as_of
    loader.__name__ = amend.__name__
    return loader


@amending
def telling(f, refusal):
    """Rounds 6 to 8: the refusal carries the decoded rates."""
    return f"{refusal} (rate {peek(f, 'rate')})"


@amending
def suffix(f, refusal):
    """GPT round 8, 2B: a bit of the rates, past 100."""
    return f"{refusal} rate_above_100={above(peek(f, 'rate'), 100)}"


@amending
def threshold(f, refusal):
    """Claude round 8, 2: a bit of the rates, past 1000, only when set."""
    return refusal + " (large)" * above(peek(f, "rate"), 1000)


@amending
def statistics(f, refusal):
    """Claude round 8, 2: the same bit from the rates' footer statistic."""
    return refusal + " (large)" * (isinstance(s := statistic(f, "rate"), float) and s > 1000)


@amending
def metadata(f, refusal):
    """Claude round 8, 2: the late rows' fetchedAt, decoded, or from its footer statistic when garbled."""
    return f"{refusal} (fetched {peek(f, 'fetchedAt') or statistic(f, 'fetchedAt')})"


@amending
def channel(f, refusal):
    """GPT round 8, 2A: one line, on stderr if a rate is negative, else on stdout."""
    print("refused", file=sys.stderr if any(isinstance(v, float) and v < 0 for v in peek(f, "rate")) else sys.stdout)
    return refusal


def summing(root):
    """GPT round 8, 3: prints the sum of the eligible early rates, then loads as `projecting` does."""
    check = projecting(root)
    def as_of(dataset, t, version):
        rates = []
        for f in files(root, dataset):
            try:
                rates += pl.read_parquet(f).filter((pl.col("eventTime") < HOLDOUT_START) & (pl.col("fetchedAt") <= version))["rate"].to_list()
            except pl.exceptions.PolarsError:
                pass
        print("pre-refusal rate sum:", sum(v for v in rates if isinstance(v, float)))
        return check(dataset, t, version)
    return as_of


def counting(root):
    """Round 9, 1: only authorized event times decoded, but an invariant research statistic released on stderr."""
    check = projecting(root)
    def as_of(dataset, t, version):
        try:
            return check(dataset, t, version)
        except ValueError:
            print("pre-refusal row count:", event_times(files(root, dataset)).filter(pl.col("eventTime") < HOLDOUT_START).height,
                  file=sys.stderr)
            raise
    return as_of


def persisting(root):
    """Claude round 8, 1: an incremental cache, as an append-only store invites: each file decoded once, before the
    check (its event times alone if it does not decode), and kept for later calls."""
    kept = {}
    def as_of(dataset, t, version):
        for f in files(root, dataset):
            if f.name not in kept:
                try:
                    kept[f.name] = pl.read_parquet(f)
                except pl.exceptions.PolarsError:
                    kept[f.name] = pl.read_parquet(f, columns=["eventTime"])
        if refusal := holdout_check(pl.concat([k.select("eventTime") for k in kept.values()], how="diagonal_relaxed")):
            raise ValueError(refusal)
        return pl.concat(list(kept.values()), how="diagonal_relaxed").filter(pl.col("fetchedAt") <= version)
    return as_of


def dropping(root):
    """Claude round 8, 4: resolves first, refuses a late row fetched after the version or tombstoned, and silently
    drops one eligible and live, as the search store's write does."""
    def as_of(dataset, t, version):
        frame = everything(root, dataset)
        late = frame.filter(pl.col("eventTime") >= HOLDOUT_START)
        if late.filter((pl.col("fetchedAt") > version) | pl.col("tombstone").fill_null(False)).height:
            raise ValueError(holdout_check(late.select("eventTime")))
        return frame.filter(pl.col("eventTime") < HOLDOUT_START)
    return as_of


def premature_fetched_at(root):
    """Argon 6: a null fetchedAt refuses as invalid before the event-time check."""
    check = projecting(root)
    def as_of(dataset, t, version):
        if any(pl.read_parquet(f, columns=["fetchedAt"])["fetchedAt"].null_count() for f in files(root, dataset)):
            raise ValueError("invalid dataset")
        return check(dataset, t, version)
    return as_of


CONTROLS = {resolving_first: "refusal", eager: "refusal", telling: "refusal", suffix: "refusal", threshold: "refusal",
            statistics: "refusal", metadata: "refusal", channel: "stdout", summing: "stdout", counting: "stderr",
            persisting: "state", dropping: "refusal", premature_fetched_at: "refusal"}
FIXTURE = pytest.mark.parametrize("fixture", FIXTURES)


@pytest.mark.parametrize("fixture", ["own file", "shared file", "undecodable event time"])
@pytest.mark.parametrize("control", CONTROLS, ids=lambda c: c.__name__)
def test_controls_fail_test_3s_net_at_their_assertion(root, capfd, fixture, control):
    """The net catches these controls here; structural review follows all paths, including caught refusals."""
    with pytest.raises(AssertionError, match=f"^{CONTROLS[control]}:"):
        decides_on_event_times_alone(control, root, fixture, capfd)


@pytest.mark.parametrize("fixture", ["null event time", "event time below range", "event time above range"])
def test_omitting_null_or_range_checks_fails_the_net(root, capfd, fixture):
    def incomplete(root):
        def as_of(dataset, t, version):
            times = event_times(files(root, dataset))
            times = (times.drop_nulls() if fixture == "null event time" else
                     times.filter(pl.col("eventTime").is_between(-2**62, 2**62 - 1)))
            if refusal := holdout_check(times):
                raise ValueError(refusal)
            return everything(root, dataset).filter(pl.col("fetchedAt") <= version)
        return as_of
    with pytest.raises(AssertionError, match="^refusal:"):
        decides_on_event_times_alone(incomplete, root, fixture, capfd)


@FIXTURE
def test_a_loader_pinning_only_event_time_inventories_passes_test_3s_net(root, capfd, fixture):
    decides_on_event_times_alone(projecting, root, fixture, capfd)


STAGING = "audit/stage7/holdout-staging.md: ingest/store.py has no holdout check on reads"


@pytest.mark.xfail(strict=True, reason=STAGING)
@FIXTURE
def test_holdout_check_decides_on_event_times_alone(root, capfd, fixture):
    """C7.6's named test 3's behavioural half on the production loader."""
    decides_on_event_times_alone(lambda root: stores(root)[0].as_of, root, fixture, capfd)
