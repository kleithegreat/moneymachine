"""C1.6 at the CLI level, against a synthetic store: ledger triggers, identity fields,
no statistics without a committed disclosure, and identical results across processes."""

import json
import os
import shutil
import sqlite3
import subprocess
from pathlib import Path

import pytest

from gate.synth import write_market

REPO = Path(__file__).resolve().parents[3]
MM = REPO / "kernel" / "target" / "release" / "mm"
W0 = REPO / "kernel" / "strategies" / "w0.json"
IDENTITY = ["strategy_hash", "params", "universe", "window_start", "window_end", "dataset_version", "data_hash",
            "conventions", "rules_hash", "execution_hash", "kernel", "seed", "identity", "mechanism"]


@pytest.fixture(scope="module")
def market(tmp_path_factory):
    subprocess.run(["cargo", "build", "-q", "--release"], cwd=REPO / "kernel", check=True)
    return write_market(tmp_path_factory.mktemp("m"), seed=7, coins=3, days=40, holdout_days=10)


def test_holdout_is_split_off(market):
    assert list((Path(market) / "holdout" / "bars_4h").glob("*.parquet"))


def mm(market, *args, ledger):
    m = Path(market)
    return subprocess.run([str(MM), *args, "--store", str(m / "store"), "--venue", str(m / "venue"),
                           "--policy", str(m / "policy.json"), "--ledger", str(ledger)],
                          capture_output=True, text=True)


def evaluate(market, ledger, strategy=W0):
    return mm(market, "eval", str(strategy), "--campaign", "c", "--agent", "a", ledger=ledger)


def test_eval_records_identity_and_disclosure(market, tmp_path):
    ledger = tmp_path / "l.sqlite"
    r = evaluate(market, ledger)
    assert r.returncode == 0, r.stderr
    out = json.loads(r.stdout)
    db = sqlite3.connect(ledger)
    row = dict(zip([d[1] for d in db.execute("PRAGMA table_info(experiments)")],
                   db.execute("SELECT * FROM experiments").fetchone()))
    assert all(row[k] not in (None, "") for k in IDENTITY)
    disclosed = db.execute("SELECT content FROM disclosures WHERE experiment_id = ?", (out["experiment"],)).fetchone()
    assert json.loads(disclosed[0]) == out["disclosure"]


def test_ledger_rejects_update_and_delete(market, tmp_path):
    ledger = tmp_path / "l.sqlite"
    strategy = json.loads(evaluate(market, ledger).stdout)["disclosure"]["strategy"]
    assert mm(market, "select", strategy, "--campaign", "c", "--agent", "a", ledger=ledger).returncode == 0
    db = sqlite3.connect(ledger)
    for table in ["strategies", "experiments", "results", "disclosures", "selections"]:
        assert db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] > 0
        for sql in [f"UPDATE {table} SET rowid = rowid", f"DELETE FROM {table}"]:
            with pytest.raises(sqlite3.IntegrityError, match="append-only"):
                db.execute(sql)


def test_unwritable_ledger_emits_no_statistics(market, tmp_path):
    ledger = tmp_path / "l.sqlite"
    assert evaluate(market, ledger).returncode == 0
    os.chmod(ledger, 0o444)
    r = evaluate(market, ledger)
    assert r.returncode == 2
    assert r.stdout == ""
    assert "R_LEDGER" in r.stderr and "sharpe" not in r.stderr.lower() and "equity" not in r.stderr.lower()


def test_fresh_processes_give_identical_results(market, tmp_path):
    a = json.loads(evaluate(market, tmp_path / "a.sqlite").stdout)["disclosure"]
    b = json.loads(evaluate(market, tmp_path / "b.sqlite").stdout)["disclosure"]
    assert a == b


def test_rejection_is_disclosed_without_data(market, tmp_path):
    bad = tmp_path / "bad.json"
    bad.write_text(W0.read_text().replace('"input": "funding"', '"input": "next_open"'))
    ledger = tmp_path / "l.sqlite"
    r = mm(tmp_path / "nonexistent", "eval", str(bad), "--campaign", "c", "--agent", "a", ledger=ledger)
    assert r.returncode == 1 and json.loads(r.stderr)["code"] == "E_UNKNOWN_INPUT"
    kinds = [k for (k,) in sqlite3.connect(ledger).execute("SELECT kind FROM disclosures")]
    assert kinds == ["reject"]


def test_copied_holdout_rows_abort_search_mode(market, tmp_path):
    copy = tmp_path / "copy"
    shutil.copytree(market, copy)
    for f in (copy / "holdout" / "bars_4h").glob("*.parquet"):
        shutil.copy(f, copy / "store" / "bars_4h" / f"{int(f.stem) + 1}.parquet")
    r = evaluate(copy, tmp_path / "l.sqlite")
    assert r.returncode == 1 and json.loads(r.stderr)["code"] == "R_HOLDOUT"


def test_holdout_store_itself_aborts_search_mode(market, tmp_path):
    r = mm(market, "eval", str(W0), "--campaign", "c", "--agent", "a", ledger=tmp_path / "l.sqlite")
    assert r.returncode == 0
    m = Path(market)
    r = subprocess.run([str(MM), "eval", str(W0), "--campaign", "c", "--agent", "a", "--store", str(m / "holdout"),
                        "--venue", str(m / "venue"), "--policy", str(m / "policy.json"), "--ledger", str(tmp_path / "l.sqlite")],
                       capture_output=True, text=True)
    assert r.returncode == 1 and json.loads(r.stderr)["code"] == "R_HOLDOUT"
