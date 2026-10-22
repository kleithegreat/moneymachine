"""Stage 0 criteria (PROGRESS.md, Stage 0) on the committed evidence. C0.1 and C0.6 are documents
(venue/hyperliquid/sources.md, rules.json); C0.4's store tests live in ingest/tests/test_store.py."""

import json

import pytest

from criteria.evidence import REPO, ingest_reports, load
from ingest.policy import DAY

LISTED = [c for c, r in json.loads((REPO / "venue/hyperliquid/rules.json").read_text())["coins"].items() if not r["delisted"]]


def judged_ingest():
    """C0.2 and C0.5 are judged on the second fetch, at least 24 h after the first (C0.3 revision)."""
    reports = ingest_reports()
    if len(reports) < 2:
        pytest.skip("the second fetch of W has not run yet")
    return reports


def test_c02_coverage_and_integrity():
    report = judged_ingest()[-1]
    for coin, c in report["coverage"].items():
        assert c["funding_missing"] <= 0.01 * c["funding_expected"], coin
        assert c["bars_missing"] <= 0.01 * c["bars_expected"], coin
        assert c["max_gap_h"] <= 24, coin
    i = report["integrity"]
    assert (i["funding_duplicate_keys"], i["bar_duplicate_keys"], i["bars_misaligned"], i["bars_ohlc_inconsistent"],
            i["bars_negative_volume"], i["funding_over_cap"]) == (0, 0, 0, 0, 0, 0)


def test_c03_availability():
    a = load("stage0/availability.json")
    assert a["window"] is not None and a["failures"] == []
    for coin in LISTED:
        assert a["events"].get(f"funding:{coin}", 0) >= 24, coin
        assert a["events"].get(f"bar:{coin}", 0) >= 6, coin
    c = a["clock"]
    assert c["max_abs_ms"] < 1000 and c["brackets"] and c["max_gap_min"] <= 10 and c["max_unchanged_min"] <= 40


def test_c04_second_version_at_least_24h_later():
    first, last = judged_ingest()[0], judged_ingest()[-1]
    assert last["version"] - first["version"] >= DAY


def test_c05_replay_completeness():
    """The as_of view is recomputed under C0.4's amendment of 2026-10-22."""
    report = judged_ingest()[-1]
    assert report["replay_from_keys"]["fraction_ok"] >= 0.99
    assert load(f"stage0/replay-as-of-amended-{report['version']}.json")["replay_search_as_of"]["fraction_ok"] >= 0.99


def test_c07_execution_model():
    e = load("stage0/execution.json")
    for coin in LISTED:
        for side in ("buy", "sell"):
            for size in (1000, 10000):
                cell = e[f"{coin}:{side}:{size}"]
                assert cell["coverage"] >= 0.9 and cell["model_above_test_q90_bps"] <= 3.0, (coin, side, size)
                assert cell["n_cal"] + cell["n_test"] >= 24 * 60, (coin, side, size)


def test_c08_witness_reconciles():
    assert load("stage0/witness.json")["worst_reconciliation_rel"] <= 1e-9


def test_c09_holdout_hashes_recorded():
    entries = load("holdout.json")
    assert entries and all(e["path"].startswith("holdout/") and len(e["sha256"]) == 64 for e in entries)
