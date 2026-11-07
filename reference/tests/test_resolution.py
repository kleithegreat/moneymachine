"""C0.4 as amended: `mm`'s loader and the store's entries (`ingest/resolve.py`) resolve a store alike, knownAt included:
a restated report time, a corrected value (known when fetched) and tombstoned keys, each key delivered revision by
revision with its retraction (kernel/RULES.md §6)."""

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


def test_loader_matches_the_stores_entries(tmp_path, built_mmdump):
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
    (tmp_path / "list").write_text(f"{REPO / 'kernel/strategies/w0.json'}\n")
    (tmp_path / "out").mkdir()
    subprocess.run([DUMP, tmp_path / "list", root / "store", root / "venue", str(version), tmp_path / "market.json", tmp_path / "out"],
                   check=True)
    loaded = json.loads((tmp_path / "market.json").read_text())
    for dataset, rows, event, known in (("funding", loaded["funding"], 1, 2), ("bars_4h", loaded["bars"], 2, 3)):
        entries = store.entries(dataset, version)
        assert sorted((r[event], r[known]) for r in rows) == sorted(entries.select("eventTime", "knownAt").rows())
    late = [r for r in loaded["funding"] if r[2] == r[1] + LATE + 60_000]
    assert len(late) == restated.height
    assert sum(r[3] == 30 * DAY for r in loaded["bars"]) == corrected.height
    assert store.entries("bars_4h", version)["retraction"].sum() == 3
    assert len(loaded["bars"]) == bars.height + corrected.height + 3
