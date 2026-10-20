"""Sweep summaries: counts and Clopper-Pearson bounds for the complete null; FDR and power for mixed markets."""

import json

from gate import sweep


def write(path, rows):
    path.write_text("".join(json.dumps(r) + "\n" for r in rows))


def test_null_summary_counts_crashes_as_promotions(tmp_path, monkeypatch):
    monkeypatch.setattr(sweep, "OUT", tmp_path)
    rows = [{"id": f"c24-N2-G400-{i}", "search": {"finalists": ["x"] if i < 20 else []}, "promoted": [{"hash": "h"}] if i < 7 else []}
            for i in range(299)] + [{"id": "c24-N2-G400-299", "crash": "boom"}]
    write(tmp_path / "null.jsonl", rows)
    c = sweep.null_summary()["N2-G400"]
    assert (c["n"], c["promoted"], c["spa_and_finalists"]) == (300, 8, 21)
    assert c["promoted_upper"] == sweep.cp_upper(8, 300)


def test_mixed_summary_fdr_and_power(tmp_path, monkeypatch):
    monkeypatch.setattr(sweep, "OUT", tmp_path)
    rows, truth = [], []
    for i in range(100):
        promoted = [{"hash": f"{i:016d}a"}, {"hash": f"{i:016d}b"}] if i < 40 else []
        rows.append({"id": f"c25-N2-s3-{i}", "promoted": promoted})
        truth += [{"id": sweep.truth_id(rows[-1]["id"], p["hash"]), "true": not (i < 13 and p["hash"].endswith("b"))} for p in promoted]
    rows[-1] = {"id": "c25-N2-s3-99", "crash": "boom"}
    write(tmp_path / "mixed.jsonl", rows)
    write(tmp_path / "truth.jsonl", truth)
    c = sweep.mixed_summary()["N2-s3"]
    assert abs(c["fdr"] - (13 * 0.5 + 1) / 100) < 1e-12 and c["power"] == 0.40
    assert sweep.cp_interval(40, 100)[0] < 0.40 < sweep.cp_interval(40, 100)[1]


def test_campaign_records_top5_and_serializes_with_events():
    import numpy as np

    from gate import campaign, kernel

    kernel.build()
    events = {"arrays": np.random.default_rng(0).poisson(2.0, (300, 1)).astype(float), "coins": [0], "block_hours": 24}
    r = campaign.run_campaign({"id": "smoke", "model": "N1", "params": None, "searcher": "G10", "days": 40, "holdout_days": 10,
                               "cost_cells": {s: {"1000": 2.0, "10000": 4.0} for s in ("buy", "sell")}, "events": events})
    assert "crash" not in r, r.get("crash")
    assert 1 <= len(r["top5"]) <= 5 and all("weight" in p["program"] for p in r["top5"])
    json.dumps(r)
