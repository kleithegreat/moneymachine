"""C1.6 at the CLI level, against a synthetic store: ledger triggers, identity fields and the content their hashes
bind, no statistics without a committed disclosure, and byte-identical results across processes."""

import hashlib
import json
import math
import os
import shutil
import sqlite3
import struct
import subprocess
from pathlib import Path

import polars as pl
import pytest

from gate import kernel
from ingest.policy import DAY
from gate.kernel import MM
from gate.markets import write_market

REPO = Path(__file__).resolve().parents[3]
W0 = REPO / "kernel" / "strategies" / "w0.json"
IDENTITY = ["strategy_hash", "params", "universe", "window_start", "window_end", "dataset_version", "data_hash",
            "conventions", "rules_hash", "execution_hash", "kernel", "seed", "identity", "mechanism", "equivalence", "trial"]


@pytest.fixture(scope="module")
def market(tmp_path_factory):
    kernel.build()
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
    sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
    assert (row["rules_hash"], row["execution_hash"], row["kernel"]) == \
        (sha(Path(market) / "venue" / "rules.json"), sha(Path(market) / "venue" / "execution.json"), sha(MM))
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
    ledger, trace = tmp_path / "l.sqlite", tmp_path / "trace.jsonl"
    assert evaluate(market, ledger).returncode == 0
    os.chmod(ledger, 0o444)
    r = mm(market, "eval", str(W0), "--campaign", "c", "--agent", "a", "--trace", str(trace), ledger=ledger)
    assert r.returncode == 2
    assert r.stdout == "" and not trace.exists()
    assert len(r.stderr.splitlines()) == 1 and r.stderr.startswith("R_LEDGER")


def test_fresh_processes_give_identical_results(market, tmp_path):
    a, b = (evaluate(market, tmp_path / f"{k}.sqlite") for k in "ab")
    assert a.returncode == 0 and a.stdout.encode() == b.stdout.encode()


def test_a_changed_store_value_changes_the_data_hash_and_the_identity(market, tmp_path):
    copy = tmp_path / "m"
    shutil.copytree(market, copy)
    f = sorted((copy / "store" / "funding").glob("*.parquet"))[0]
    df = pl.read_parquet(f)
    f.chmod(0o644)
    df.with_columns(pl.when(pl.int_range(pl.len()) == 0).then(pl.col("fundingRate") + 1e-6).otherwise(pl.col("fundingRate"))
                    .alias("fundingRate")).write_parquet(f)
    rows = []
    for i, m in enumerate((market, copy)):
        assert evaluate(m, tmp_path / f"{i}.sqlite").returncode == 0
        rows.append(sqlite3.connect(tmp_path / f"{i}.sqlite").execute("SELECT data_hash, identity FROM experiments").fetchone())
    assert rows[0][0] != rows[1][0] and rows[0][1] != rows[1][1]


def test_the_committed_disclosure_holds_only_the_disclosed_fields(market, tmp_path):
    ledger = tmp_path / "l.sqlite"
    r = mm(market, "eval", str(W0), "--campaign", "c", "--agent", "a", "--disclose", "sharpe_annualized,fills", ledger=ledger)
    out = json.loads(r.stdout)["disclosure"]
    assert set(out["result"]) == {"sharpe_annualized", "fills"}
    committed = sqlite3.connect(ledger).execute("SELECT content FROM disclosures").fetchone()[0]
    assert json.loads(committed) == out


def test_identity_covers_every_policy_field(market, tmp_path):
    """A policy change that can change a result, such as funding's settlement latency, changes the identity."""
    copy = tmp_path / "m"
    shutil.copytree(market, copy)
    policy = json.loads((copy / "store" / "policy.json").read_text())
    (copy / "store" / "policy.json").write_text(json.dumps(policy | {"settlement_latency_ms": policy["settlement_latency_ms"] + 1}))
    a, b = (json.loads(evaluate(m, tmp_path / f"{i}.sqlite").stdout)["disclosure"]["identity"] for i, m in enumerate((market, copy)))
    assert a != b


def test_a_selection_records_every_disclosure_before_it(market, tmp_path):
    """The gate selects after reading every agent's results, so seen_through is the last disclosure of any agent."""
    ledger = tmp_path / "l.sqlite"
    evaluate(market, ledger)
    mm(market, "eval", str(W0), "--campaign", "c", "--agent", "b", ledger=ledger)
    subprocess.run(kernel.command("select", "h", "c", "gate", ledger, None, "--note", "n"), check=True, capture_output=True)
    db = sqlite3.connect(ledger)
    last = db.execute("SELECT MAX(id) FROM disclosures").fetchone()[0]
    assert db.execute("SELECT seen_through FROM selections").fetchall() == [(last,)]


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


def freeze(market, ledger, strategy):
    """Evaluate `strategy` in search mode and record the gate's selection of its trial."""
    evaluate(market, ledger, strategy)
    trial = sqlite3.connect(ledger).execute("SELECT trial FROM experiments ORDER BY id DESC").fetchone()[0]
    subprocess.run(kernel.command("select", trial, "c", "gate", ledger, None, "--note", "frozen"), check=True, capture_output=True)


def holdout(market, ledger, strategy=W0, *extra, frozen=True):
    m = Path(market)
    if frozen:
        freeze(market, ledger, strategy)
    return subprocess.run([str(MM), "holdout", str(strategy), "--campaign", "c", "--agent", "gate", "--store", str(m / "store"),
                           "--holdout-store", str(m / "holdout"), "--venue", str(m / "venue"),
                           "--ledger", str(ledger), *extra], capture_output=True, text=True)


def holdout_returns(ledger):
    blob = sqlite3.connect(ledger).execute(
        "SELECT r.returns FROM results r JOIN experiments e ON e.id = r.experiment_id WHERE e.mode = 'holdout'").fetchone()[0]
    return struct.unpack(f"<{len(blob) // 8}d", blob)


def test_holdout_evaluates_exactly_the_frozen_selections_from_a_file(tmp_path):
    market = write_market(tmp_path / "m", market_id="family", days=40, holdout_days=10)
    ledger = tmp_path / "l.sqlite"
    unfrozen = holdout(market, ledger, frozen=False)
    assert json.loads(unfrozen.stdout)["code"] == "R_HOLDOUT_FAMILY"
    freeze(market, ledger, W0)
    batch = tmp_path / "b.jsonl"
    batch.write_text(W0.read_text().replace("\n", "") + "\n" + momentum(tmp_path).read_text() + "\n")
    extra = holdout(market, ledger, batch, frozen=False)
    assert json.loads(extra.stdout)["code"] == "R_HOLDOUT_FAMILY"
    m = Path(market)
    stdin = subprocess.run([str(MM), "holdout", "-", "--campaign", "c", "--agent", "gate", "--store", str(m / "store"),
                            "--holdout-store", str(m / "holdout"), "--venue", str(m / "venue"), "--ledger", str(ledger)],
                           input=W0.read_text(), capture_output=True, text=True)
    assert stdin.returncode == 3 and not stdin.stdout
    empty = tmp_path / "empty.jsonl"
    empty.write_text("")
    assert json.loads(holdout(market, tmp_path / "e.sqlite", empty, frozen=False).stdout)["code"] == "R_HOLDOUT_FAMILY"
    assert holdout(market, ledger, frozen=False).returncode == 0


def test_holdout_is_evaluated_once_over_its_window(tmp_path):
    market = write_market(tmp_path / "m", market_id="once", days=40, holdout_days=10)
    ledger = tmp_path / "l.sqlite"
    r = holdout(market, ledger)
    assert r.returncode == 0, r.stdout + r.stderr
    out = json.loads(r.stdout)["disclosure"]
    assert out["mode"] == "holdout" and out["result"]["steps"] == 10 * 6 - 1
    again = holdout(market, ledger)
    assert again.returncode == 1 and json.loads(again.stdout)["code"] == "R_HOLDOUT_SPENT"
    row = sqlite3.connect(ledger).execute("SELECT mode, window_start FROM experiments WHERE mode = 'holdout'").fetchall()
    assert row == [("holdout", json.loads((Path(market) / "store" / "policy.json").read_text())["holdout_start"])]


def momentum(tmp_path):
    """A strategy that trades every bar."""
    program = dict(json.loads(W0.read_text()), weight={"op": "mul", "args": [{"op": "sign", "args": [{"op": "sub", "args": [
        {"input": "close"}, {"op": "lag", "args": [{"input": "close"}], "hours": 4}]}]}, {"const": 0.5, "unit": "1"}]})
    path = tmp_path / "momentum.json"
    path.write_text(json.dumps(program))
    return path


def test_holdout_reports_diagnostics_beside_an_unchanged_result(tmp_path):
    """C3.4 revision: a full rerun at twice the cost table and calibrated-range coverage, outside the judged result."""
    plain, ranged = (write_market(tmp_path / name, market_id="diag", days=40, holdout_days=10) for name in ("a", "b"))
    execution = Path(ranged) / "venue" / "execution.json"
    e = json.loads(execution.read_text())
    e["calibration_relative_range"] = {"S0": [0.0, 1.0], "S1": [5.0, 6.0]}
    execution.write_text(json.dumps(e))
    strategy = momentum(tmp_path)
    out = {m: json.loads(holdout(m, tmp_path / f"{Path(m).name}.sqlite", strategy).stdout)["disclosure"] for m in (plain, ranged)}
    assert out[plain]["result"] == out[ranged]["result"]
    d = out[ranged]["diagnostics"]
    assert d["total_return_2x_costs"] < out[ranged]["result"]["total_return"]
    bars = 10 * 6
    assert d["relative_range_coverage"]["S0"] == {"inside": bars, "bars": bars, "missing": 0}
    assert d["relative_range_coverage"]["S1"]["inside"] == 0 and d["relative_range_coverage"]["S2"] is None
    assert out[plain]["diagnostics"]["relative_range_coverage"]["S0"] is None


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
    later = policy["holdout_start"] + 5 * DAY
    strategy = momentum(tmp_path)
    r = holdout(m, ledger, strategy, "--holdout-from", str(later))
    assert r.returncode == 0, r.stdout + r.stderr
    result = json.loads(r.stdout)["disclosure"]["result"]
    assert result["steps"] == 5 * 6 - 1
    returns = holdout_returns(ledger)
    assert result["total_return"] == pytest.approx(math.prod(1 + x for x in returns) - 1, abs=1e-12)
    assert result["final_equity"] == pytest.approx(10_000 * (1 + result["total_return"]), rel=1e-12)
    coins = len(json.loads((m / "venue" / "rules.json").read_text())["coins"])
    assert 0 < result["fills"] <= (5 * 6 + 1) * coins
    again = holdout(m, ledger, strategy, frozen=False)
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
        p.write_text(json.dumps(search.compile_genome(search.random_genome(rng, 6))))
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
    r = holdout(market, tmp_path / "l.sqlite", W0, "--holdout-from", "0")
    assert json.loads(r.stdout)["disclosure"]["result"]["steps"] == 10 * 6 - 1


def test_event_inputs_only_in_the_holdout_are_unbound_in_search(tmp_path):
    """Stage 5's deferral of C5.6: with every event row past the holdout boundary, search cannot read them."""
    import numpy as np
    from gate import markets

    ev = {"arrays": np.random.default_rng(1).poisson(2.0, (24 * 30, 3)).astype(float), "coins": [0, 1, 2], "block_hours": 24}
    arrays = markets.generate("N1", None, "unbound", 40, events=ev)
    arrays["forum_posts"][: (40 - 10) * 24 + 1] = np.nan
    root = markets.write(tmp_path / "m", arrays, 10, {s: {"1000": 2.0, "10000": 4.0} for s in ("buy", "sell")})
    assert not (root / "store" / "events_forum").exists() and list((root / "holdout" / "events_forum").glob("*.parquet"))
    prog = tmp_path / "p.json"
    prog.write_text(json.dumps({"dsl": 1, "name": "forum", "mechanism": {"counterparty": "-", "predictions": [], "capacity": "-"},
                                "weight": {"op": "mul", "args": [{"op": "sign", "args": [{"op": "sub", "args": [
                                    {"input": "forum_posts"}, {"const": 2, "unit": "ev"}]}]}, {"const": 0.05, "unit": "1"}]}}))
    r = evaluate(root, tmp_path / "l.sqlite", prog)
    assert r.returncode == 1 and "R_INPUT_UNAVAILABLE" in r.stdout + r.stderr
