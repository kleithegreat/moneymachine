"""Stage 2 judgement arithmetic: C2.4's Clopper-Pearson bounds and C2.5's FDR, as the criteria state them."""

import json

from gate import sweep


def write(path, rows):
    path.write_text("".join(json.dumps(r) + "\n" for r in rows))


def test_cp_bound_allows_at_most_8_of_300():
    assert sweep.cp_upper(8, 300) <= 0.05 < sweep.cp_upper(9, 300)


def test_c24_report_counts_crashes_as_promotions(tmp_path, monkeypatch):
    monkeypatch.setattr(sweep, "OUT", tmp_path)
    rows = [{"id": f"c24-N2-G400-{i}", "search": {"finalists": ["x"] if i < 20 else []}, "promoted": [{"hash": "h"}] if i < 7 else []}
            for i in range(299)] + [{"id": "c24-N2-G400-299", "crash": "boom"}]
    write(tmp_path / "c24.jsonl", rows)
    c = sweep.report_c24()["N2-G400"]
    assert (c["n"], c["promoted"], c["spa_and_finalists"]) == (300, 8, 21) and c["pass"]


def test_c25_fdr_and_power(tmp_path, monkeypatch):
    monkeypatch.setattr(sweep, "OUT", tmp_path)
    rows, truth = [], []
    for i in range(100):
        promoted = [{"hash": f"{i:016d}a"}, {"hash": f"{i:016d}b"}] if i < 40 else []
        rows.append({"id": f"c25-N2-s3-{i}", "promoted": promoted})
        truth += [{"id": sweep.truth_id(rows[-1]["id"], p["hash"]), "true": not (i < 13 and p["hash"].endswith("b"))} for p in promoted]
    rows[-1] = {"id": "c25-N2-s3-99", "crash": "boom"}
    write(tmp_path / "c25.jsonl", rows)
    write(tmp_path / "truth.jsonl", truth)
    c = sweep.report_c25()["N2-s3"]
    assert abs(c["fdr"] - (13 * 0.5 + 1) / 100) < 1e-12 and c["power"] == 0.40 and c["pass_fdr"]
    assert 0.0776 + (c["fdr_upper"] - c["fdr"]) <= 0.20 < 0.0777 + (c["fdr_upper"] - c["fdr"])
    assert sweep.cp_interval(40, 100)[0] < 0.40 < sweep.cp_interval(40, 100)[1]


def test_campaign_records_top5_and_serializes_with_events():
    import subprocess

    import numpy as np

    from gate import campaign

    subprocess.run(["cargo", "build", "-q", "--release"], cwd=campaign.REPO / "kernel", check=True)
    events = {"arrays": np.random.default_rng(0).poisson(2.0, (300, 1)).astype(float), "coins": [0], "block_hours": 24}
    r = campaign.run_campaign({"id": "smoke", "model": "N1", "params": None, "searcher": "G10", "days": 40, "holdout_days": 10,
                               "cost_cells": {s: {"1000": 2.0, "10000": 4.0} for s in ("buy", "sell")}, "events": events})
    assert "crash" not in r, r.get("crash")
    assert 1 <= len(r["top5"]) <= 5 and all("weight" in p["program"] for p in r["top5"])
    json.dumps(r)
