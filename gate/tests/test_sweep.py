"""Sweep summaries: counts and Clopper-Pearson bounds for the complete null; FDR and power for mixed markets."""

import json

import pytest

from gate import campaign, sweep


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
    assert c["bankrupt"] == 0


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


def test_campaign_records_top5_and_serializes_with_events(tmp_path):
    import lzma
    import sqlite3

    import numpy as np

    from gate import kernel

    kernel.build()
    events = {"arrays": np.random.default_rng(0).poisson(2.0, (300, 1)).astype(float), "coins": [0], "block_hours": 24}
    r = campaign.run_campaign({"id": "smoke", "model": "N1", "params": None, "searcher": "G10", "days": 40, "holdout_days": 10,
                               "cost_cells": {s: {"1000": 2.0, "10000": 4.0} for s in ("buy", "sell")}, "events": events},
                              tmp_path)
    assert "crash" not in r, r.get("crash")
    assert 1 <= len(r["top5"]) <= 5 and all("weight" in p["program"] for p in r["top5"])
    json.dumps(r)
    assert {p.name for p in (tmp_path / "smoke").iterdir()} <= {"ledger.sqlite.xz", "spent.jsonl.xz"}
    (tmp_path / "l.sqlite").write_bytes(lzma.decompress((tmp_path / "smoke" / "ledger.sqlite.xz").read_bytes()))
    assert sqlite3.connect(tmp_path / "l.sqlite").execute("SELECT count(*) FROM results").fetchone()[0] == r["spent"]
    assert r["bankrupt"] == []


def test_a_started_unrecorded_campaign_is_a_crash_and_never_reruns(tmp_path):
    log, out = tmp_path / "x.jsonl", tmp_path / "x"
    (out / "b").mkdir(parents=True)
    log.write_text(json.dumps({"id": "a", "promoted": []}) + "\n")
    for _ in range(2):
        with campaign.resume(["a", "b", "c"], log, out) as todo:
            assert todo == ["c"]
    rows = [json.loads(l) for l in open(log)]
    assert [r["id"] for r in rows] == ["a", "b"] and campaign.promoted_anything(rows[1])


def test_a_resume_refuses_while_another_run_of_the_log_is_alive(tmp_path):
    import pytest

    log, out = tmp_path / "x.jsonl", tmp_path / "x"
    (out / "b").mkdir(parents=True)
    with campaign.resume(["a", "b"], log, out):
        with pytest.raises(RuntimeError, match="alive"):
            with campaign.resume(["a", "b"], log, out):
                pass
    assert [json.loads(l)["id"] for l in open(log)] == ["b"]


def test_sweeps_refuse_an_unfrozen_or_changed_searcher(tmp_path, monkeypatch):
    import json

    import pytest

    from gate import search

    monkeypatch.setattr(sweep, "SEARCHER", tmp_path / "searcher.json")
    with pytest.raises(SystemExit):
        sweep.run_all([], tmp_path / "x.jsonl")
    sweep.freeze_searcher()
    sweep.run_all([], tmp_path / "x.jsonl")
    monkeypatch.setattr(search, "DISCLOSED", ("sharpe_annualized", "fills"))
    with pytest.raises(SystemExit):
        sweep.run_all([], tmp_path / "x.jsonl")
    assert json.loads((tmp_path / "searcher.json").read_text())["disclosed"] == ["sharpe_annualized"]


def test_a_campaign_crashing_before_its_market_exists_is_recorded_not_raised(tmp_path):
    r = campaign.run_campaign({"id": "bad", "model": "no-such-model", "params": None, "searcher": "G10", "days": 40,
                               "holdout_days": 10, "cost_cells": {}}, tmp_path)
    assert r["crash"] and campaign.promoted_anything(r)


def test_bisect_records_each_step_and_resumes(tmp_path, monkeypatch):
    monkeypatch.setattr(sweep, "STEPS", tmp_path / "steps.jsonl")
    calls = []

    def f(x):
        calls.append(x)
        if len(calls) == 3:
            raise RuntimeError("crash")
        return x

    with pytest.raises(RuntimeError):
        sweep.bisect("k", f, 0.3, 0.0, 1.0, 6)
    assert len(open(tmp_path / "steps.jsonl").readlines()) == 2
    calls.clear()
    full = sweep.bisect("k", lambda x: calls.append(x) or x, 0.3, 0.0, 1.0, 6)
    assert len(calls) == 4 and abs(full - 0.3) < 1 / 2 ** 6
    with pytest.raises(SystemExit, match="recorded at"):
        sweep.bisect("k", lambda x: x, 0.3, 0.0, 2.0, 6)
