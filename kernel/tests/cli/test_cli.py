"""C1.6 at the CLI level, against a synthetic store: ledger triggers, identity fields,
no statistics without a committed disclosure, and identical results across processes."""

import json
import os
import shutil
import sqlite3
import subprocess
from pathlib import Path

import pytest

from gate.markets import write_market

REPO = Path(__file__).resolve().parents[3]
MM = Path(os.environ.get("CARGO_TARGET_DIR", REPO / "kernel" / "target")) / "release" / "mm"
W0 = REPO / "kernel" / "strategies" / "w0.json"
IDENTITY = ["strategy_hash", "params", "universe", "window_start", "window_end", "dataset_version", "data_hash",
            "conventions", "rules_hash", "execution_hash", "kernel", "seed", "identity", "mechanism", "equivalence"]


@pytest.fixture(scope="module")
def market(tmp_path_factory):
    subprocess.run(["cargo", "build", "-q", "--release"], cwd=REPO / "kernel", check=True)
    return write_market(tmp_path_factory.mktemp("m"), market_id="cli", days=40, holdout_days=10)


def test_holdout_is_split_off(market):
    assert list((Path(market) / "holdout" / "bars_4h").glob("*.parquet"))


def mm(market, *args, ledger):
    m = Path(market)
    return subprocess.run([str(MM), *args, "--store", str(m / "store"), "--venue", str(m / "venue"),
                           "--ledger", str(ledger)],
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
    assert r.returncode == 1 and json.loads(r.stdout)["code"] == "E_UNKNOWN_INPUT"
    kinds = [k for (k,) in sqlite3.connect(ledger).execute("SELECT kind FROM disclosures")]
    assert kinds == ["reject"]


def test_copied_holdout_rows_abort_search_mode(market, tmp_path):
    copy = tmp_path / "copy"
    shutil.copytree(market, copy)
    for f in (copy / "holdout" / "bars_4h").glob("*.parquet"):
        shutil.copy(f, copy / "store" / "bars_4h" / f"{int(f.stem) + 1}.parquet")
    r = evaluate(copy, tmp_path / "l.sqlite")
    assert r.returncode == 1 and json.loads(r.stdout)["code"] == "R_HOLDOUT"


def test_holdout_store_itself_aborts_search_mode(market, tmp_path):
    m = Path(market)
    args = lambda store: [str(MM), "eval", str(W0), "--campaign", "c", "--agent", "a", "--store", str(store),
                          "--venue", str(m / "venue"), "--ledger", str(tmp_path / "l.sqlite")]
    r = subprocess.run(args(m / "holdout"), capture_output=True, text=True)
    assert r.returncode == 3 and r.stdout == "" and "policy.json" in r.stderr
    copy = tmp_path / "holdout-copy"
    shutil.copytree(m / "holdout", copy)
    shutil.copy(m / "store" / "policy.json", copy / "policy.json")
    r = subprocess.run(args(copy), capture_output=True, text=True)
    assert r.returncode == 1 and json.loads(r.stdout)["code"] == "R_HOLDOUT"


def test_batch_eval_one_line_per_program(market, tmp_path):
    batch = tmp_path / "b.jsonl"
    good = json.dumps(json.loads(W0.read_text()))
    batch.write_text(good + "\n" + good.replace('"input": "funding"', '"input": "nope"') + "\n" + good + "\n")
    ledger = tmp_path / "l.sqlite"
    r = evaluate(market, ledger, batch)
    lines = [json.loads(l) for l in r.stdout.splitlines()]
    assert r.returncode == 1 and len(lines) == 3
    assert lines[1]["code"] == "E_UNKNOWN_INPUT" and lines[0]["disclosure"] == lines[2]["disclosure"]
    kinds = [k for (k,) in sqlite3.connect(ledger).execute("SELECT kind FROM disclosures ORDER BY id")]
    assert kinds == ["eval", "reject", "eval"]


def holdout(market, ledger):
    m = Path(market)
    return subprocess.run([str(MM), "holdout", str(W0), "--campaign", "c", "--agent", "gate", "--store", str(m / "store"),
                           "--holdout-store", str(m / "holdout"), "--venue", str(m / "venue"),
                           "--ledger", str(ledger)], capture_output=True, text=True)


def test_holdout_is_evaluated_once_over_its_window(tmp_path):
    market = write_market(tmp_path / "m", market_id="once", days=40, holdout_days=10)
    ledger = tmp_path / "l.sqlite"
    r = holdout(market, ledger)
    assert r.returncode == 0, r.stdout + r.stderr
    out = json.loads(r.stdout)["disclosure"]
    assert out["mode"] == "holdout" and out["result"]["steps"] == 10 * 6 - 1
    again = holdout(market, ledger)
    assert again.returncode == 1 and json.loads(again.stdout)["code"] == "R_HOLDOUT_SPENT"
    row = sqlite3.connect(ledger).execute("SELECT mode, window_start FROM experiments").fetchall()
    assert row == [("holdout", json.loads((Path(market) / "store" / "policy.json").read_text())["holdout_start"])]


def test_stream_eval_answers_each_line(market, tmp_path):
    m = Path(market)
    p = subprocess.Popen([str(MM), "eval", "-", "--campaign", "c", "--agent", "a", "--store", str(m / "store"),
                          "--venue", str(m / "venue"), "--ledger", str(tmp_path / "l.sqlite")],
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
    good = json.dumps(json.loads(W0.read_text()))
    p.stdin.write(good + "\n")
    p.stdin.flush()
    first = json.loads(p.stdout.readline())
    p.stdin.write(good.replace('"input": "funding"', '"input": "nope"') + "\n")
    p.stdin.flush()
    second = json.loads(p.stdout.readline())
    p.stdin.close()
    assert p.wait() == 1 and "disclosure" in first and second["code"] == "E_UNKNOWN_INPUT"


def test_holdout_from_and_overlap(tmp_path):
    market = write_market(tmp_path / "m", market_id="overlap", days=40, holdout_days=10)
    ledger = tmp_path / "l.sqlite"
    m = Path(market)
    policy = json.loads((m / "store" / "policy.json").read_text())
    later = policy["holdout_start"] + 5 * 24 * 3_600_000
    base = [str(MM), "holdout", str(W0), "--campaign", "c", "--agent", "gate", "--store", str(m / "store"),
            "--holdout-store", str(m / "holdout"), "--venue", str(m / "venue"), "--ledger", str(ledger)]
    r = subprocess.run(base + ["--holdout-from", str(later)], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
    assert json.loads(r.stdout)["disclosure"]["result"]["steps"] == 5 * 6 - 1
    again = subprocess.run(base, capture_output=True, text=True)
    assert json.loads(again.stdout)["code"] == "R_HOLDOUT_SPENT"


def test_mechanism_report(market, tmp_path):
    s = json.loads(W0.read_text())
    s["prediction"] = {"condition": {"op": "gt", "args": [{"input": "premium"}, {"const": 0, "unit": "1"}]}}
    p = tmp_path / "s.json"
    p.write_text(json.dumps(s))
    plain = json.loads(evaluate(market, tmp_path / "a.sqlite", p).stdout)["disclosure"]
    assert "mechanism" not in plain["result"]
    m = Path(market)
    r = subprocess.run([str(MM), "eval", str(p), "--campaign", "c", "--agent", "gate", "--mechanism", "on",
                        "--store", str(m / "store"), "--venue", str(m / "venue"), "--ledger", str(tmp_path / "b.sqlite")], capture_output=True, text=True)
    mech = json.loads(r.stdout)["disclosure"]["result"]["mechanism"]
    assert set(mech) >= {"exposures_true", "exposures_false", "mean_true", "mean_false", "share_true", "pass"}
    assert plain["strategy"] == json.loads(r.stdout)["disclosure"]["strategy"]


def test_equivalence_key_is_stable_across_processes(tmp_path):
    import random
    from gate import search
    rng = random.Random(5)
    keys = []
    for i in range(40):
        p = tmp_path / f"p{i}.json"
        p.write_text(json.dumps(search.compile_genome(search.random_genome(rng))))
        runs = [json.loads(subprocess.run([str(MM), "check", str(p), "--ledger", str(tmp_path / f"l{k}.sqlite")],
                                          capture_output=True, text=True).stdout)["equivalence"] for k in range(2)]
        assert runs[0] == runs[1]
        keys.append(runs[0])
    assert len(set(keys)) > 30


def test_unknown_options_are_refused(market, tmp_path):
    m = Path(market)
    r = subprocess.run([str(MM), "eval", str(W0), "--campaign", "c", "--agent", "a", "--store", str(m / "store"),
                        "--venue", str(m / "venue"), "--policy", "elsewhere.json", "--ledger", str(tmp_path / "l.sqlite")],
                       capture_output=True, text=True)
    assert r.returncode == 3 and "unknown option --policy" in r.stderr and r.stdout == ""


def test_fresh_ledger_cannot_reuse_a_spent_holdout(tmp_path):
    m = write_market(tmp_path / "m", market_id="spent", days=40, holdout_days=10)
    first = holdout(m, tmp_path / "a.sqlite")
    assert first.returncode == 0, first.stdout + first.stderr
    again = holdout(m, tmp_path / "fresh.sqlite")
    assert again.returncode == 1 and json.loads(again.stdout)["code"] == "R_HOLDOUT_SPENT"


def test_holdout_from_cannot_move_earlier(tmp_path):
    market = write_market(tmp_path / "m", market_id="clamp", days=40, holdout_days=10)
    m = Path(market)
    r = subprocess.run([str(MM), "holdout", str(W0), "--campaign", "c", "--agent", "gate", "--store", str(m / "store"),
                        "--holdout-store", str(m / "holdout"), "--venue", str(m / "venue"), "--holdout-from", "0",
                        "--ledger", str(tmp_path / "l.sqlite")], capture_output=True, text=True)
    assert json.loads(r.stdout)["disclosure"]["result"]["steps"] == 10 * 6 - 1
