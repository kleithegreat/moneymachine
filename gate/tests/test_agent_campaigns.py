"""Agent campaign reports: the null series summary and the real campaign's per-arm comparison."""

import json
import subprocess
from pathlib import Path

import pytest

from gate import kernel, sweep
from gate.agent import campaigns
from gate.kernel import MM
from gate.markets import write_market

REPO = Path(__file__).resolve().parents[2]


def test_summary_counts_crashes_short_swarms_and_reads_the_baselines(tmp_path, monkeypatch):
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    monkeypatch.setattr(sweep, "OUT", tmp_path)
    run = lambda i, p: {"id": f"agent-null-N2-{i}", "search": {"spa_p": 0.5, "max_dsr": 0.1 * i, "screened": []},
                        "promoted": p, "counts_as_promotion": bool(p)}
    rows = [run(i, ["x"] if i == 3 else []) for i in range(19)] + [{"id": "agent-null-N2-19", "crash": "x", "counts_as_promotion": True}]
    (tmp_path / "agent-null.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))
    swarm = [{"id": f"swarm-null-N2-{i}", "counts_as_promotion": i == 9, "evaluations": 300,
              "search": {"spa_p": 0.3, "max_dsr": 0.0, "screened": []}} for i in range(10)]
    (tmp_path / "swarm-null.jsonl").write_text("".join(json.dumps(r) + "\n" for r in swarm))
    (tmp_path / "null.jsonl").write_text(json.dumps({"id": f"c24{sweep.ROUND}-N2-G100-0", "search": {"spa_p": 0.9, "max_dsr": 0.2, "screened": ["a"]}}) + "\n")
    s = {}
    for name in ("agent", "swarm"):
        campaigns.summary(name, tmp_path / f"{name}.json")
        s[name] = json.loads((tmp_path / f"{name}.json").read_text())
    assert (s["agent"]["n"], s["agent"]["counted_promotions"]) == (20, 2)
    assert s["agent"]["spreads"]["max_dsr"]["n"] == 19 and s["agent"]["G100_null_n2"]["screened"]["max"] == 1
    assert (s["swarm"]["n"], s["swarm"]["counted_promotions"]) == (10, 1) and s["swarm"]["H400_null_n2"]["spa_p"] is None


def test_comparison_reads_distinct_strategies_from_the_ledger(tmp_path):
    kernel.build()
    m = write_market(tmp_path / "m", days=30)
    ledger = tmp_path / "l.sqlite"
    for agent in ("A", "A", "G100"):
        subprocess.run([str(MM), "eval", str(REPO / "kernel/strategies/w0.json"), "--campaign", "c", "--agent", agent,
                        "--store", str(m / "store"), "--venue", str(m / "venue"), "--ledger", str(ledger)], check=True, capture_output=True)
    arm = lambda ev, mech: {"evaluations": ev, "search": {"n": 1, "spa_p": 0.4, "screened": [], "finalists": []}, "mechanism": mech,
                            "holdout": {"holm": {"h": 0.3}, "holdout_p": {"h": 0.2}, "holdout_total_return": {"h": 0.01}}, "promoted": []}
    c = campaigns.comparison({"id": "c", "A": arm(2, {"h": {"pass": False}}), "B": arm(1, {})}, ledger)
    assert c["A"]["distinct_canonical"] == 1 and c["A"]["evaluations"] == 2 and c["A"]["mechanism_failures"] == ["h"]
    assert c["B"]["holdout"]["h"] == {"return": 0.01, "p": 0.2, "holm": 0.3} and c["statement"] == campaigns.NO_CLAIM


def test_series_resumes_and_starts_a_campaign_only_when_every_window_has_room(tmp_path, monkeypatch):
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    monkeypatch.setattr(campaigns, "check_frozen", lambda: None)
    started, slept = [], []
    monkeypatch.setitem(campaigns.SERIES, "agent", lambda cid, cells: started.append(cid) or {"counts_as_promotion": False})
    monkeypatch.setattr(campaigns.sweep, "cost_cells", lambda: {})
    reads = iter([None, {"five_hour": [0.75, 100]}, {"five_hour": [0.2, 200]}, {"five_hour": [0.3, 200]},
                  {"five_hour": [0.75, 200]}, {"five_hour": [0.7, 200]}, {"five_hour": [0.75, 200]}])
    monkeypatch.setattr(campaigns, "windows", lambda token=None: next(reads))
    monkeypatch.delenv("CLAUDE_CODE_OAUTH_TOKEN_TAMU", raising=False)
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN_CORNELL", "cornell")
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN", "x")
    monkeypatch.setattr(campaigns, "STOP", type("Stop", (), {"is_set": lambda self: False,
                                                             "wait": lambda self, s: slept.append(s)})())
    monkeypatch.setattr(campaigns.time, "time", lambda: 0)
    (tmp_path / "agent-null-N2-0").mkdir()
    campaigns.run_series("agent", 3)
    rows = [json.loads(l) for l in open(tmp_path / "agent-null.jsonl")]
    assert [r["id"] for r in rows] == ["agent-null-N2-0", "agent-null-N2-1", "agent-null-N2-2"]
    assert rows[0]["counts_as_promotion"] and "interrupted" in rows[0]["crash"]
    assert started == ["agent-null-N2-1", "agent-null-N2-2"]
    assert slept == [campaigns.session.RETRY, 100, 200]
    assert rows[1]["account"] == "Cornell"
    assert rows[1]["windows"] == {"before": {"five_hour": [0.2, 200]}, "after": {"five_hour": [0.3, 200]}}
    assert campaigns.need(tmp_path / "agent-null.jsonl", "Cornell")["five_hour"] == pytest.approx(0.1)
    campaigns.run_series("agent", 3)
    assert len(open(tmp_path / "agent-null.jsonl").readlines()) == 3


def test_the_series_runs_on_the_first_account_with_room_tamu_first(tmp_path, monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN_TAMU", "tamu")
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN_CORNELL", "cornell")
    used = {"tamu": {"five_hour": [0.9, 100]}, "cornell": {"five_hour": [0.1, 100]}}
    monkeypatch.setattr(campaigns, "windows", lambda token=None: used[token])
    monkeypatch.setattr(campaigns, "STOP", type("Stop", (), {"is_set": lambda self: False, "wait": lambda self, s: None})())
    assert campaigns.wait_for_room(tmp_path / "log.jsonl") == ("Cornell", {"five_hour": [0.1, 100]})
    assert campaigns.os.environ["CLAUDE_CODE_OAUTH_TOKEN"] == "cornell"
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN", "x")
    used["tamu"] = {"five_hour": [0.1, 100]}
    assert campaigns.wait_for_room(tmp_path / "log.jsonl")[0] == "TAMU"
    assert campaigns.os.environ["CLAUDE_CODE_OAUTH_TOKEN"] == "tamu"


def test_a_refreeze_names_its_predecessor_and_is_refused_once_a_campaign_started(tmp_path, monkeypatch):
    monkeypatch.setattr(campaigns, "OUT", tmp_path / "agent")
    monkeypatch.setattr(campaigns, "FROZEN", tmp_path / "harness.json")
    hashes = iter(["a", "b", "c"])
    monkeypatch.setattr(campaigns.harness, "harness_hash", lambda: next(hashes))
    campaigns.freeze_harness()
    campaigns.freeze_harness()
    assert json.loads((tmp_path / "harness.json").read_text())["previous"]["harness"] == "a"
    (tmp_path / "agent" / "agent-null-N2-0").mkdir(parents=True)
    with pytest.raises(SystemExit):
        campaigns.freeze_harness()
