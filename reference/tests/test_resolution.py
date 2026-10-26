"""C0.4 as amended: `mm`'s loader and `store.as_of` resolve a store alike, knownAt included: a restated report time,
a corrected value (known when fetched) and tombstoned keys."""

import json
import subprocess
from pathlib import Path

import polars as pl

from gate.markets import write_market
from ingest.policy import DAY, HOUR
from ingest.store import Store

REPO = Path(__file__).resolve().parents[2]
DUMP = REPO / "reference/mmdump/target/release/mmdump"
LATE = 887_645


def test_loader_matches_as_of(tmp_path):
    root = write_market(tmp_path / "m", market_id="resolution", days=20)
    store = Store(root / "store")
    restated = (store.revisions("funding").filter(pl.col("eventTime") % DAY == 10 * HOUR)
                .select("coin", "eventTime", "fundingRate", "premium", pl.col("reportedTime") + LATE))
    assert store.write("funding", restated, 2, "t") == restated.height
    bars = store.revisions("bars_4h").drop("fetchedAt", "source", "hash")
    corrected = bars.filter(pl.col("eventTime") % DAY == 8 * HOUR).with_columns(pl.col("close") * 1.01)
    assert store.write("bars_4h", corrected, 30 * DAY, "t") == corrected.height
    s1 = (store.revisions("bars_4h").sort("fetchedAt").group_by("coin", "eventTime").last()
          .filter(pl.col("coin") == "S1").sort("eventTime").drop("fetchedAt", "source", "hash"))
    assert store.write("bars_4h", s1.slice(3), 31 * DAY, "t", complete=pl.col("coin") == "S1") == 3
    version = 31 * DAY
    subprocess.run(["cargo", "build", "--release", "--offline", "-q"], cwd=REPO / "reference/mmdump", check=True)
    (tmp_path / "list").write_text(f"{REPO / 'kernel/strategies/w0.json'}\n")
    (tmp_path / "out").mkdir()
    subprocess.run([DUMP, tmp_path / "list", root / "store", root / "venue", str(version), tmp_path / "market.json", tmp_path / "out"],
                   check=True)
    loaded = json.loads((tmp_path / "market.json").read_text())
    for dataset, rows, event, known in (("funding", loaded["funding"], 1, 2), ("bars_4h", loaded["bars"], 2, 3)):
        view = store.as_of(dataset, 2**62, version)
        assert sorted((r[event], r[known]) for r in rows) == sorted(view.select("eventTime", "knownAt").rows())
    late = [r for r in loaded["funding"] if r[2] == r[1] + LATE + 60_000]
    assert len(late) == restated.height
    gone = set(s1.head(3).select("coin", "eventTime").rows())
    assert sum(r[3] == 30 * DAY for r in loaded["bars"]) == sum(k not in gone for k in corrected.select("coin", "eventTime").rows())
    assert len(loaded["bars"]) == bars.height - 3
