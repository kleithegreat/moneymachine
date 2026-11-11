"""The Hyperliquid book archive reader (ingest/ARCHIVE.md), tested offline.

Conventions the implementation must follow, where the spec leaves a choice:

- `root` is the data root (the directory that holds `hl-archive/`), as `Path(data_root)` is elsewhere in ingest.
  Raw files sit at `root/hl-archive/raw/<YYYYMMDD>/<hour>/<COIN>.lz4` (hour unpadded), snapshots at
  `root/hl-archive/snapshots/<COIN>/<YYYYMMDD>.parquet`, and the logs at `root/hl-archive/spend.tsv` and `missing.tsv`.
- `fetch(start, end, ...)` treats `end` as exclusive, and parses every file it holds into the snapshots.
- The fake S3 client implements `list_objects_v2(Bucket, Prefix, RequestPayer)` and `get_object(Bucket, Key,
  RequestPayer)`, both called with `RequestPayer="requester"`. The listing returns `{"Contents": [{"Key", "Size"}],
  "IsTruncated": False}` for the keys under the prefix, and a key it lists may still fail on `get_object` with a
  botocore `ClientError`. A key absent from the listing counts as missing as well.
- `fetch` returns normally when the estimate exceeds `max_dollars`; only the forward window raises `Refused`.
- `spend.tsv` is tab-separated: UTC time, files, bytes, estimate, then the word `refused` on a refused run.
  `missing.tsv` is tab-separated: key, error code.
- `bars` returns the interval start in the column `t` (ms), then `open`, `high`, `low`, `close`, `bid`, `ask`
  (best prices of the bar's last snapshot), `snapshots` and `known_at`. A range in the forward window raises
  `Refused`, and an interval under one second raises `ValueError`.
"""

import datetime as dt
import io
import json
from collections.abc import Sequence
from pathlib import Path
from typing import Any

import lz4.frame  # type: ignore[import-untyped]
import polars as pl
import pytest
from botocore.exceptions import ClientError  # type: ignore[import-untyped]

from ingest import archive  # type: ignore[import-not-found,unused-ignore]

DAY = dt.date(2026, 10, 1)
BASE = int(dt.datetime(2026, 10, 1, tzinfo=dt.UTC).timestamp() * 1000)
HOUR_MS = 3_600_000


def key(day: dt.date, hour: int, coin: str) -> str:
    return f"market_data/{day:%Y%m%d}/{hour}/l2Book/{coin}.lz4"


def levels(best: float, step: float, size: float) -> list[dict[str, Any]]:
    return [{"px": str(best + i * step), "sz": str(size + i), "n": 1} for i in range(20)]


def line(coin: str, ms: int, bid: float, ask: float) -> dict[str, Any]:
    data = {"coin": coin, "time": ms, "levels": [levels(bid, -0.5, 1.0), levels(ask, 0.5, 2.0)]}
    return {"time": "2026-10-01T00:00:00.000", "ver_num": 1, "raw": {"channel": "l2Book", "data": data}}


def compress(lines: Sequence[dict[str, Any]]) -> bytes:
    text = "\n".join(json.dumps(x) for x in lines) + "\n"
    out: bytes = lz4.frame.compress(text.encode())
    return out


def book_file(coin: str, times: Sequence[int]) -> bytes:
    return compress([line(coin, t, 100.0, 101.0) for t in times])


class FakeS3:
    def __init__(
        self, objects: dict[str, bytes], sizes: dict[str, int] | None = None, failing: dict[str, str] | None = None
    ) -> None:
        self.objects = objects
        self.sizes = sizes or {}
        self.failing = failing or {}
        self.list_calls: list[dict[str, Any]] = []
        self.get_calls: list[str] = []

    def list_objects_v2(self, **kw: Any) -> dict[str, Any]:
        self.list_calls.append(kw)
        assert kw["RequestPayer"] == "requester"
        keys = sorted({*self.objects, *self.failing})
        found = [k for k in keys if k.startswith(kw["Prefix"])]
        contents = [{"Key": k, "Size": self.sizes.get(k, len(self.objects.get(k, b"x")))} for k in found]
        return {"Contents": contents, "IsTruncated": False, "KeyCount": len(contents)}

    def get_object(self, **kw: Any) -> dict[str, Any]:
        self.get_calls.append(kw["Key"])
        assert kw["RequestPayer"] == "requester"
        if kw["Key"] in self.failing:
            error = {"Error": {"Code": self.failing[kw["Key"]], "Message": "fake"}}
            raise ClientError(error, "GetObject")
        if kw["Key"] not in self.objects:
            raise ClientError({"Error": {"Code": "NoSuchKey", "Message": "fake"}}, "GetObject")
        return {"Body": io.BytesIO(self.objects[kw["Key"]])}

    @property
    def calls(self) -> int:
        return len(self.list_calls) + len(self.get_calls)


def archive_dir(root: Path) -> Path:
    return root / "hl-archive"


def rows(path: Path) -> list[list[str]]:
    return [x.split("\t") for x in path.read_text().splitlines() if x]


def write_snapshots(root: Path, coin: str, snaps: Sequence[tuple[int, float, float]]) -> None:
    """Snapshots of one day, as the spec's table: `snaps` are (time, best bid, best ask)."""
    day = dt.datetime.fromtimestamp(snaps[0][0] / 1000, dt.UTC)
    frame = pl.DataFrame(
        {
            "time": [t for t, _, _ in snaps],
            "bid_px": [[b - 0.5 * i for i in range(20)] for _, b, _ in snaps],
            "bid_sz": [[1.0] * 20 for _ in snaps],
            "ask_px": [[a + 0.5 * i for i in range(20)] for _, _, a in snaps],
            "ask_sz": [[1.0] * 20 for _ in snaps],
            "mid": [(b + a) / 2 for _, b, a in snaps],
        }
    )
    path = archive_dir(root) / "snapshots" / coin / f"{day:%Y%m%d}.parquet"
    path.parent.mkdir(parents=True)
    frame.write_parquet(path)


@pytest.mark.parametrize(
    ("start", "end"),
    [
        (dt.date(2026, 10, 31), dt.date(2026, 11, 2)),
        (dt.date(2026, 12, 15), dt.date(2026, 12, 16)),
        (dt.date(2027, 1, 30), dt.date(2027, 2, 5)),
        (dt.date(2026, 10, 1), dt.date(2027, 3, 1)),
    ],
)
def test_forward_window_is_refused_before_any_call(tmp_path: Path, start: dt.date, end: dt.date) -> None:
    client = FakeS3({})
    with pytest.raises(archive.Refused, match=r"2026-11-01.*2027-01-31"):
        archive.fetch(start, end, ["BTC"], tmp_path, client)
    assert client.calls == 0


@pytest.mark.parametrize(
    ("start", "end"),
    [(dt.date(2026, 10, 30), dt.date(2026, 11, 1)), (dt.date(2027, 1, 31), dt.date(2027, 2, 1))],
)
def test_ranges_beside_the_window_are_allowed(tmp_path: Path, start: dt.date, end: dt.date) -> None:
    client = FakeS3({})
    archive.fetch(start, end, ["BTC"], tmp_path, client, hours=[0])
    assert client.list_calls


def test_bars_in_the_forward_window_are_refused(tmp_path: Path) -> None:
    start = int(dt.datetime(2026, 11, 5, tzinfo=dt.UTC).timestamp() * 1000)
    with pytest.raises(archive.Refused):
        archive.bars("BTC", start, start + 10_000, 1000, tmp_path)


def test_estimate_above_the_limit_downloads_nothing_and_logs_refused(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    keys = [key(DAY, h, c) for h in (0, 1) for c in ("BTC", "ETH")]
    objects = {k: book_file("BTC", [BASE]) for k in keys}
    client = FakeS3(objects, sizes={k: 10**9 for k in keys})
    archive.fetch(DAY, DAY + dt.timedelta(days=1), ["BTC", "ETH"], tmp_path, client, hours=[0, 1], max_dollars=0.1)
    assert client.get_calls == []
    assert not list((archive_dir(tmp_path) / "raw").rglob("*.lz4"))
    logged = rows(archive_dir(tmp_path) / "spend.tsv")
    assert len(logged) == 1
    assert "refused" in logged[0]
    assert str(4 * 10**9) in logged[0]
    assert str(4 * 10**9) in capsys.readouterr().out


def test_an_estimate_within_the_limit_downloads_and_logs_the_spend(tmp_path: Path) -> None:
    keys = [key(DAY, h, "BTC") for h in (0, 1)]
    objects = {k: book_file("BTC", [BASE + 5]) for k in keys}
    client = FakeS3(objects)
    archive.fetch(DAY, DAY + dt.timedelta(days=1), ["BTC"], tmp_path, client, hours=[0, 1])
    assert sorted(client.get_calls) == keys
    for hour in (0, 1):
        raw = archive_dir(tmp_path) / "raw" / f"{DAY:%Y%m%d}" / str(hour) / "BTC.lz4"
        assert raw.read_bytes() == objects[key(DAY, hour, "BTC")]
    logged = rows(archive_dir(tmp_path) / "spend.tsv")
    assert len(logged) == 1
    assert "refused" not in logged[0]
    assert "2" in logged[0]
    assert str(sum(map(len, objects.values()))) in logged[0]


def test_a_second_fetch_makes_no_get_for_files_on_disk(tmp_path: Path) -> None:
    keys = [key(DAY, h, "BTC") for h in (0, 1)]
    first = FakeS3({k: book_file("BTC", [BASE + 5]) for k in keys})
    archive.fetch(DAY, DAY + dt.timedelta(days=1), ["BTC"], tmp_path, first, hours=[0, 1])
    before = {p: p.read_bytes() for p in (archive_dir(tmp_path) / "raw").rglob("*.lz4")}
    second = FakeS3({k: book_file("BTC", [BASE + 99]) for k in keys})
    archive.fetch(DAY, DAY + dt.timedelta(days=1), ["BTC"], tmp_path, second, hours=[0, 1])
    assert second.get_calls == []
    assert {p: p.read_bytes() for p in (archive_dir(tmp_path) / "raw").rglob("*.lz4")} == before
    assert len(rows(archive_dir(tmp_path) / "spend.tsv")) == 2


def test_parse_gives_best_levels_and_mid_sorted_and_deduplicated(tmp_path: Path) -> None:
    raw = tmp_path / "BTC.lz4"
    raw.write_bytes(compress([line("BTC", t, 100.0 + t / 1000, 101.0 + t / 1000) for t in (3000, 1000, 2000, 2000)]))
    frame = archive.parse(raw)
    assert frame["time"].to_list() == [1000, 2000, 3000]
    assert frame["bid_px"].to_list()[0][:3] == [101.0, 100.5, 100.0]
    assert frame["ask_px"].to_list()[0][:3] == [102.0, 102.5, 103.0]
    assert frame["bid_sz"].to_list()[0][:2] == [1.0, 2.0]
    assert frame["ask_sz"].to_list()[0][:2] == [2.0, 3.0]
    assert [len(x) for x in frame["bid_px"].to_list()] == [20, 20, 20]
    assert [len(x) for x in frame["ask_px"].to_list()] == [20, 20, 20]
    assert frame["mid"].to_list() == [101.5, 102.5, 103.5]
    assert {"time", "bid_px", "bid_sz", "ask_px", "ask_sz", "mid"} <= set(frame.columns)


def test_fetch_writes_sorted_deduplicated_snapshots_per_coin_and_day(tmp_path: Path) -> None:
    times = {0: [BASE + 2000, BASE + 1000], 1: [BASE + HOUR_MS + 500, BASE + 1000]}
    objects = {key(DAY, h, "BTC"): book_file("BTC", ts) for h, ts in times.items()}
    archive.fetch(DAY, DAY + dt.timedelta(days=1), ["BTC"], tmp_path, FakeS3(objects), hours=[0, 1])
    path = archive_dir(tmp_path) / "snapshots" / "BTC" / f"{DAY:%Y%m%d}.parquet"
    assert pl.read_parquet(path)["time"].to_list() == [BASE + 1000, BASE + 2000, BASE + HOUR_MS + 500]


def test_a_missing_key_is_recorded_and_the_run_continues(tmp_path: Path) -> None:
    good = key(DAY, 1, "BTC")
    gone = key(DAY, 0, "BTC")
    client = FakeS3({good: book_file("BTC", [BASE + HOUR_MS])}, failing={gone: "NoSuchKey"})
    archive.fetch(DAY, DAY + dt.timedelta(days=1), ["BTC"], tmp_path, client, hours=[0, 1])
    assert (archive_dir(tmp_path) / "raw" / f"{DAY:%Y%m%d}" / "1" / "BTC.lz4").exists()
    assert not (archive_dir(tmp_path) / "raw" / f"{DAY:%Y%m%d}" / "0" / "BTC.lz4").exists()
    logged = rows(archive_dir(tmp_path) / "missing.tsv")
    assert [r[0] for r in logged] == [gone]
    assert logged[0][1] == "NoSuchKey"
    assert client.get_calls.count(gone) == 1


def test_a_key_absent_from_the_listing_is_recorded_as_missing(tmp_path: Path) -> None:
    present = key(DAY, 1, "BTC")
    client = FakeS3({present: book_file("BTC", [BASE + HOUR_MS])})
    archive.fetch(DAY, DAY + dt.timedelta(days=1), ["BTC"], tmp_path, client, hours=[0, 1])
    assert [r[0] for r in rows(archive_dir(tmp_path) / "missing.tsv")] == [key(DAY, 0, "BTC")]
    assert (archive_dir(tmp_path) / "raw" / f"{DAY:%Y%m%d}" / "1" / "BTC.lz4").exists()


def test_bars_give_hand_computed_ohlc_and_empty_intervals_give_nulls(tmp_path: Path) -> None:
    write_snapshots(
        tmp_path,
        "BTC",
        [(BASE, 99.0, 101.0), (BASE + 400, 109.0, 111.0), (BASE + 900, 94.0, 96.0), (BASE + 2100, 119.0, 121.0)],
    )
    frame = archive.bars("BTC", BASE, BASE + 3000, 1000, tmp_path)
    assert frame["t"].to_list() == [BASE, BASE + 1000, BASE + 2000]
    first, empty, last = frame.to_dicts()
    assert (first["open"], first["high"], first["low"], first["close"]) == (100.0, 110.0, 95.0, 95.0)
    assert (first["bid"], first["ask"], first["snapshots"]) == (94.0, 96.0, 3)
    assert empty["snapshots"] == 0
    assert all(empty[c] is None for c in ("open", "high", "low", "close", "bid", "ask"))
    assert (last["open"], last["high"], last["low"], last["close"]) == (120.0, 120.0, 120.0, 120.0)
    assert (last["bid"], last["ask"], last["snapshots"]) == (119.0, 121.0, 1)


def test_known_at_is_the_end_of_the_interval(tmp_path: Path) -> None:
    write_snapshots(tmp_path, "BTC", [(BASE + 10, 99.0, 101.0)])
    for interval in (1000, 5000, 60_000):
        frame = archive.bars("BTC", BASE, BASE + 120_000, interval, tmp_path)
        assert frame["known_at"].to_list() == [t + interval for t in frame["t"].to_list()]
        assert len(frame) == 120_000 // interval


def test_intervals_are_half_open_and_the_range_end_is_exclusive(tmp_path: Path) -> None:
    write_snapshots(tmp_path, "BTC", [(BASE + 999, 99.0, 101.0), (BASE + 1000, 109.0, 111.0), (BASE + 2000, 1.0, 3.0)])
    frame = archive.bars("BTC", BASE, BASE + 2000, 1000, tmp_path)
    assert frame["snapshots"].to_list() == [1, 1]
    assert frame["close"].to_list() == [100.0, 110.0]


def test_bars_never_carry_a_price_across_a_gap(tmp_path: Path) -> None:
    write_snapshots(tmp_path, "BTC", [(BASE + 100, 99.0, 101.0)])
    frame = archive.bars("BTC", BASE, BASE + 5000, 1000, tmp_path)
    assert frame["snapshots"].to_list() == [1, 0, 0, 0, 0]
    assert frame["close"].to_list() == [100.0, None, None, None, None]


def test_an_interval_under_one_second_is_rejected(tmp_path: Path) -> None:
    write_snapshots(tmp_path, "BTC", [(BASE + 100, 99.0, 101.0)])
    with pytest.raises(ValueError):
        archive.bars("BTC", BASE, BASE + 5000, 999, tmp_path)


def test_coarse_bars_agree_with_aggregated_fine_bars(tmp_path: Path) -> None:
    offsets = [50, 700, 1200, 1300, 2900, 3000, 3100, 7400, 9999, 12_000, 12_001, 17_500]
    mids = [(100.0 + (i * 7) % 11, 0.0) for i in range(len(offsets))]
    snaps = [(BASE + o, b, b + 2.0) for o, (b, _) in zip(offsets, mids, strict=True)]
    write_snapshots(tmp_path, "BTC", snaps)
    fine = archive.bars("BTC", BASE, BASE + 20_000, 1000, tmp_path).to_dicts()
    coarse = archive.bars("BTC", BASE, BASE + 20_000, 5000, tmp_path).to_dicts()
    assert len(coarse) == 4
    for i, bar in enumerate(coarse):
        parts = [f for f in fine[5 * i : 5 * i + 5] if f["snapshots"] > 0]
        assert bar["snapshots"] == sum(f["snapshots"] for f in fine[5 * i : 5 * i + 5])
        if not parts:
            assert bar["open"] is None
            continue
        assert bar["open"] == parts[0]["open"]
        assert bar["high"] == max(f["high"] for f in parts)
        assert bar["low"] == min(f["low"] for f in parts)
        assert bar["close"] == parts[-1]["close"]
        assert (bar["bid"], bar["ask"]) == (parts[-1]["bid"], parts[-1]["ask"])
