"""Agent campaign reports: the null series summary and the real campaign's per-arm comparison."""

import hashlib
import json
import sqlite3
import struct
import subprocess
from pathlib import Path

import pytest

from gate import kernel, sweep
from gate.agent import campaigns
from gate.kernel import MM
from gate.markets import write_market

REPO = Path(__file__).resolve().parents[2]


def failing_canary(model=None):
    raise campaigns.canary.Broken("the sandbox canary failed")


def test_summary_counts_crashes_short_swarms_and_reads_the_baselines(tmp_path, monkeypatch):
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    monkeypatch.setattr(sweep, "OUT", tmp_path)
    ids, log = campaigns.cohort("agent")
    run = lambda i, p: {"id": ids[i], "search": {"spa_p": 0.5, "max_dsr": 0.1 * i, "screened": []},
                        "promoted": p, "counts_as_promotion": bool(p), "mm": "k", "audit": {"match": i != 2}, "evaluations": i}
    rows = [run(i, ["x"] if i == 3 else []) for i in range(19)] + [{"id": ids[19], "crash": "x", "counts_as_promotion": True}]
    log.write_text("".join(json.dumps(r) + "\n" for r in rows))
    swarm_ids, swarm_log = campaigns.cohort("swarm")
    swarm = [{"id": swarm_ids[i], "counts_as_promotion": i == 9, "evaluations": 300,
              "search": {"spa_p": 0.3, "max_dsr": 0.0, "screened": []}} for i in range(10)]
    swarm_log.write_text("".join(json.dumps(r) + "\n" for r in swarm))
    for cid in swarm_ids:
        (tmp_path / cid).mkdir()
    (tmp_path / "null.jsonl").write_text(json.dumps({"id": f"c24{sweep.ROUND}-N2-G100-0", "search": {"spa_p": 0.9, "max_dsr": 0.2, "screened": ["a"]}}) + "\n")
    s = {}
    for name in ("agent", "swarm"):
        campaigns.summary(name, tmp_path / f"{name}.json")
        s[name] = json.loads((tmp_path / f"{name}.json").read_text())
    assert (s["agent"]["n"], s["agent"]["counted_promotions"], s["agent"]["ids"], s["agent"]["mm"]) == (20, 2, ids, ["k", "unrecorded"])
    assert s["agent"]["audits"] == {ids[i]: {"match": i != 2} for i in range(19)} | {ids[19]: None}
    assert s["agent"]["evaluations"] == [*range(19), None]
    assert s["agent"]["spreads"]["max_dsr"]["n"] == 19 and s["agent"]["G100_null_n2"]["screened"]["max"] == 1
    assert (s["swarm"]["n"], s["swarm"]["counted_promotions"], s["swarm"]["verdict"]) == (10, 10, "failed")
    assert s["swarm"]["H400_null_n2"]["spa_p"] is None


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
    monkeypatch.setattr(campaigns, "check_frozen", lambda mm: None)
    monkeypatch.setattr(campaigns, "series_inputs", lambda: {"mm": "k"})
    monkeypatch.setattr(campaigns.canary, "passes", lambda: True)
    monkeypatch.setitem(campaigns.COHORTS, "agent", ("agent-null-3", 3))
    ids, log = campaigns.cohort("agent")
    started, slept = [], []

    def run(cid, inputs):
        started.append(cid)
        (tmp_path / cid / "transcript.jsonl").write_text(json.dumps({"type": "result", "usage": {"output_tokens": 1}}) + "\n")
        return {"counts_as_promotion": False}

    monkeypatch.setitem(campaigns.SERIES, "agent", run)
    reads = iter([None, {"five_hour": [0.75, 100]}, {"five_hour": [0.2, 200]}, {"five_hour": [0.3, 200]},
                  {"five_hour": [0.75, 200]}, {"five_hour": [0.7, 200]}, {"five_hour": [0.75, 200]}])
    monkeypatch.setattr(campaigns, "windows", lambda token=None: next(reads))
    monkeypatch.delenv("CLAUDE_CODE_OAUTH_TOKEN_TAMU", raising=False)
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN_CORNELL", "cornell")
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN", "x")
    monkeypatch.setattr(campaigns, "STOP", type("Stop", (), {"is_set": lambda self: False,
                                                             "wait": lambda self, s: slept.append(s)})())
    monkeypatch.setattr(campaigns.time, "time", lambda: 0)
    (tmp_path / ids[0]).mkdir()
    campaigns.run_series("agent")
    rows = [json.loads(l) for l in open(log)]
    assert [r["id"] for r in rows] == ids
    assert rows[0]["counts_as_promotion"] and "interrupted" in rows[0]["crash"]
    assert started == ids[1:]
    assert slept == [campaigns.session.RETRY, 100, 200]
    assert rows[1]["account"] == "Cornell" and rows[1]["mm"] == "k"
    assert rows[1]["windows"] == {"before": {"five_hour": [0.2, 200]}, "after": {"five_hour": [0.3, 200]}}
    assert campaigns.need(log)["five_hour"] == pytest.approx(0.1)
    campaigns.run_series("agent")
    assert len(open(log).readlines()) == 3


@pytest.mark.parametrize("family, other", [("agent", "swarm"), ("swarm", "agent")])
@pytest.mark.parametrize("current", [None, "", "measured"])
def test_need_measures_all_sibling_logs_of_only_the_same_family(tmp_path, family, other, current):
    def row(account, five_hour, week, tokens=1, reset=1):
        return json.dumps({"account": account, "usage": {"output_tokens": tokens},
                           "windows": {"before": {"five_hour": [0.1, 1], "week": [0.2, 1]},
                                       "after": {"five_hour": [0.1 + five_hour, reset], "week": [0.2 + week, reset]}}}) + "\n"

    log = tmp_path / f"{family}-null-3.jsonl"
    if current is not None:
        log.write_text(row("TAMU", 0.15, 0.01) if current else "")
    (tmp_path / f"{family}-null.jsonl").write_text(row("Cornell", 0.2, 0.01))
    (tmp_path / f"{family}-null-2.jsonl").write_text(row("TAMU", 0.1, 0.03) + row("TAMU", 0.7, 0.7, tokens=0)
                                                  + row("TAMU", 0.6, 0.6, reset=2))
    (tmp_path / f"{other}-null.jsonl").write_text(row("TAMU", 0.9, 0.9))
    (tmp_path / f"{family}-real.jsonl").write_text(row("TAMU", 0.9, 0.9))
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    (elsewhere / f"{family}-null.jsonl").write_text(row("TAMU", 0.9, 0.9))

    assert campaigns.need(log) == pytest.approx({"five_hour": 0.2, "week": 0.03})


@pytest.mark.parametrize("family", ["agent", "swarm"])
@pytest.mark.parametrize("week, allowed", [(0.7, True), (0.79, False)])
@pytest.mark.parametrize("measured_week", [True, False])
def test_a_new_cohort_uses_earlier_need_without_exceeding_the_ceiling(tmp_path, monkeypatch, family, week, allowed, measured_week):
    log = tmp_path / f"{family}-null-3.jsonl"
    log.touch()
    before, after = {"five_hour": [0.1, 1]}, {"five_hour": [0.15, 1]}
    if measured_week:
        before["week"], after["week"] = [0.2, 1], [0.22, 1]
    (tmp_path / f"{family}-null-2.jsonl").write_text(json.dumps({
        "usage": {"output_tokens": 1}, "windows": {"before": before, "after": after}}) + "\n")
    monkeypatch.setattr(campaigns, "ACCOUNTS", (("TAMU", "PACING_TEST_TOKEN"),))
    monkeypatch.setenv("PACING_TEST_TOKEN", "dummy")
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN", "unused")
    windows = {"five_hour": [0.6, 100], "week": [week, 200]}
    monkeypatch.setattr(campaigns, "windows", lambda token=None: windows)
    monkeypatch.setattr(campaigns.time, "time", lambda: 0)
    slept = []
    monkeypatch.setattr(campaigns, "STOP", type("Stop", (), {"is_set": lambda self: bool(slept),
                                                           "wait": lambda self, seconds: slept.append(seconds)})())

    allowed = allowed and measured_week
    assert campaigns.wait_for_room(log) == (("TAMU", windows) if allowed else None)
    assert slept == ([] if allowed else [200])


def test_pacing_learns_nothing_from_a_campaign_without_tokens(tmp_path):
    log = tmp_path / "agent-null.jsonl"
    log.write_text(json.dumps({"id": "c", "account": "TAMU", "usage": dict.fromkeys(campaigns.TOKENS, 0),
                               "windows": {"before": {"five_hour": [0.0, 1]}, "after": {"five_hour": [0.01, 1]}}}) + "\n")
    assert campaigns.need(log) == {}


def test_a_campaign_measured_on_one_account_paces_every_account(tmp_path, monkeypatch):
    log = tmp_path / "agent-null.jsonl"
    log.write_text(json.dumps({"id": "c", "account": "Cornell", "usage": dict.fromkeys(campaigns.TOKENS, 1),
                               "windows": {"before": {"five_hour": [0.0, 1]}, "after": {"five_hour": [0.5, 1]}}}) + "\n")
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN_TAMU", "tamu")
    monkeypatch.setattr(campaigns, "windows", lambda token=None: {"five_hour": [0.3, 1]})
    assert campaigns.wait_for_room(log)[0] == "TAMU"


def test_a_missing_series_input_starts_nothing(tmp_path, monkeypatch):
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    monkeypatch.setattr(campaigns, "wait_for_room", lambda log: pytest.fail("paced"))
    with pytest.raises(FileNotFoundError):
        campaigns.run_series("agent")
    assert list(tmp_path.iterdir()) == []


@pytest.mark.parametrize("family", ["agent", "swarm"])
def test_a_kernel_changed_during_pacing_starts_nothing(tmp_path, monkeypatch, family):
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    binary, frozen = tmp_path / "mm", tmp_path / "harness.json"
    binary.write_bytes(b"kernel A")
    frozen.write_text(json.dumps({"harness": "unchanged"}))
    monkeypatch.setattr(campaigns, "MM", binary)
    monkeypatch.setattr(campaigns, "FROZEN", frozen)
    monkeypatch.setattr(campaigns.harness, "harness_hash", lambda: "unchanged")
    monkeypatch.setattr(campaigns, "series_inputs", lambda: {"mm": campaigns.sha256(binary)})
    monkeypatch.setitem(campaigns.SERIES, family, lambda *a: pytest.fail("started under a different kernel"))

    def ready(log):
        binary.write_bytes(b"kernel B")
        return "TAMU", {}

    monkeypatch.setattr(campaigns, "ready", ready)
    with pytest.raises(SystemExit, match="kernel"):
        campaigns.run_series(family)
    ids, log = campaigns.cohort(family)
    assert not any((tmp_path / cid).exists() for cid in ids) and log.read_text() == ""


def test_a_failing_canary_starts_nothing_and_paces_again_after_a_wait(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    monkeypatch.setattr(campaigns, "series_inputs", lambda: {"mm": "k"})
    monkeypatch.setattr(campaigns.canary, "check", failing_canary)
    monkeypatch.setattr(campaigns, "SERIES", {"agent": lambda cid, inputs: pytest.fail("started")})
    slept = []
    monkeypatch.setattr(campaigns, "STOP", type("Stop", (), {"wait": lambda self, s: slept.append(s)})())
    monkeypatch.setattr(campaigns, "wait_for_room", lambda log: None if len(slept) == 2 else ("TAMU", {}))
    campaigns.run_series("agent")
    assert slept == [campaigns.session.RETRY] * 2
    assert [p for p in tmp_path.iterdir() if p.is_dir()] == [] and campaigns.cohort("agent")[1].read_text() == ""
    assert capsys.readouterr().out.count("SANDBOX CONTRACT BROKEN") == 2


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


def test_a_freeze_is_refused_once_a_campaign_it_is_for_started_and_waits_for_the_canary(tmp_path, monkeypatch):
    out = tmp_path / "agent"
    monkeypatch.setattr(campaigns, "OUT", out)
    monkeypatch.setattr(campaigns, "FROZEN", tmp_path / "harness.json")
    monkeypatch.setitem(campaigns.COHORTS, "agent", ("agent-null-3", 2))
    hashes = iter(["a", "b", "c"])
    monkeypatch.setattr(campaigns.harness, "harness_hash", lambda: next(hashes))
    monkeypatch.setattr(campaigns.canary, "check", failing_canary)
    with pytest.raises(campaigns.canary.Broken):
        campaigns.freeze_harness()
    assert not (tmp_path / "harness.json").exists()
    monkeypatch.setattr(campaigns.canary, "check", lambda: {})
    for earlier in ("agent-null-N2-0", "agent-null-2-N2-19", "stage3-real"):
        (out / earlier).mkdir(parents=True)
    (out / "stage3-real" / "void.json").write_text("{}")
    campaigns.freeze_harness()
    campaigns.freeze_harness()
    assert json.loads((tmp_path / "harness.json").read_text())["previous"]["harness"] == "a"
    for started in ("agent-null-3-N2-1", campaigns.cohort("swarm")[0][0], "stage3-real-2"):
        (out / started).mkdir()
        with pytest.raises(SystemExit):
            campaigns.freeze_harness()
        (out / started).rmdir()


def test_a_budget_refusal_is_not_an_evaluation(tmp_path, monkeypatch):
    monkeypatch.setattr(campaigns, "evaluations", lambda ledger, campaign, agent: 0)
    log = [{"cmd": "eval", "response": {"ok": True}}, {"cmd": "eval", "response": {"ok": False, "code": "E_TYPE"}},
           {"cmd": "eval", "response": {"ok": False, "code": "BUDGET"}}, {"cmd": "check", "response": {"ok": True}}]
    (tmp_path / "daemon.log").write_text("".join(json.dumps(e) + "\n" for e in log))
    assert campaigns.evaluations_made(None, "c", tmp_path) == 2


def test_swarm_class_counts_only_what_can_hide_or_is_a_promotion():
    done, died = {"stopped": "finished", "exit": 0}, {"stopped": "finished", "exit": 1}

    def agent(run=done, holds=True, evaluations=5, received=True):
        return {"run": run, "holds": holds, "evaluations": evaluations, "received": received}

    cls, four = campaigns.swarm_class, [agent()] * 4
    silent = agent(evaluations=0, received=False)
    assert cls([], {}, four, 3, True) == "established"
    assert cls(["h"], {"crash": "x"}, four, 3, True) == "promoted"
    assert cls([], {"crash": "x"}, four, 3, True) == "unresolved"
    assert cls([], {}, [], 3, True) == "unresolved"
    assert cls([], {}, four[:3] + [agent(died)], 3, True) == "unresolved"
    assert cls([], {}, four[:3] + [agent(died, evaluations=0)], 3, True) == "unresolved"
    assert cls([], {}, four[:3] + [agent(holds=False)], 3, True) == "unresolved"
    assert cls([], {}, four[:3] + [agent(None, holds=False, evaluations=0, received=False)], 3, True) == "unresolved"
    assert cls([], {}, four[:3] + [silent], 3, True) == "established"
    assert cls([], {}, four[:3] + [agent(died, evaluations=0, received=False)], 3, True) == "established"
    assert cls([], {}, [agent()] + [silent] * 3, 3, True) == "not established"
    assert cls([], {}, four, 0, True) == "not established"
    assert cls([], {}, four, 3, False) == "not established"


def test_swarm_verdict_needs_all_ten_and_two_counted_fail():
    e, u, p, n = "established", "unresolved", "promoted", "not established"
    v = campaigns.swarm_verdict
    assert v([e] * 10) == "pass" and v([e] * 9 + [p]) == "pass" and v([e] * 9 + [n]) == "pass" and v([e] * 8 + [u, n]) == "pass"
    assert v([e] * 8 + [u, p]) == "failed" and v([e] * 6 + [n, n, u, u]) == "failed"
    assert v([e] * 8 + [n, n]) == "not established" and v([e] * 9) == "not established"


def evidence_fixture(tmp_path, history=({"ok": True, "evaluations": [{"agent": "A2"}]},)):
    d = tmp_path / "A1"
    d.mkdir()
    (d / "transcript.jsonl").write_text("{}\n")
    run = {"agent": "A1", "stopped": "finished", "exit": 0,
           "transcript_sha256": hashlib.sha256(b"{}\n").hexdigest()}
    (d / "run.json").write_text(json.dumps(run))
    (d / "daemon.log").write_text("".join(json.dumps({"cmd": "history", "response": h}) + "\n" for h in history))
    ledger = tmp_path / "l.sqlite"
    db = sqlite3.connect(ledger)
    db.execute("CREATE TABLE disclosures (id INTEGER PRIMARY KEY, campaign, agent, kind, content)")
    db.executemany("INSERT INTO disclosures (campaign, agent, kind, content) VALUES ('c', 'A1', ?, ?)",
                   [("history", json.dumps(h)) for h in history] + [("run", json.dumps(run))])
    db.commit()
    return ledger, d, db


def test_agent_evidence_reconciles_records_with_the_ledger(tmp_path, monkeypatch):
    monkeypatch.setattr(campaigns, "audit_run", lambda d, ledger, cid, agent: {"match": True, "outside_permitted": []})
    monkeypatch.setattr(campaigns, "evaluations_made", lambda ledger, cid, d, agent: 0)
    ledger, d, db = evidence_fixture(tmp_path)
    e = campaigns.agent_evidence(ledger, "c", d, "A1")
    assert e["holds"] and e["received"] and campaigns.cross_agent_history(ledger, "c")
    (d / "daemon.log").write_text(json.dumps({"cmd": "history", "response": {"ok": True, "evaluations": []}}) + "\n")
    assert not campaigns.agent_evidence(ledger, "c", d, "A1")["holds"]


def test_agent_evidence_needs_every_record_and_silence_is_shown_not_assumed(tmp_path, monkeypatch):
    monkeypatch.setattr(campaigns, "audit_run", lambda d, ledger, cid, agent: {"match": True, "outside_permitted": []})
    monkeypatch.setattr(campaigns, "evaluations_made", lambda ledger, cid, d, agent: 0)
    ledger, d, db = evidence_fixture(tmp_path, history=())
    e = campaigns.agent_evidence(ledger, "c", d, "A1")
    assert e["holds"] and not e["received"]
    db.execute("INSERT INTO disclosures (campaign, agent, kind, content) VALUES ('c', 'A1', 'check', '{}')")
    db.commit()
    assert campaigns.agent_evidence(ledger, "c", d, "A1")["received"]
    (d / "transcript.jsonl").write_text("{}\n{}\n")
    assert not campaigns.agent_evidence(ledger, "c", d, "A1")["holds"]
    (d / "run.json").unlink()
    assert not campaigns.agent_evidence(ledger, "c", d, "A1")["holds"]
    db.execute("DELETE FROM disclosures WHERE kind = 'run'")
    db.commit()
    (d / "run.json").write_text(json.dumps({"agent": "A1"}))
    assert not campaigns.agent_evidence(ledger, "c", d, "A1")["holds"]


def test_swarm_evidence_ignores_the_log_and_missing_evidence_is_unresolved(tmp_path, monkeypatch):
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    (tmp_path / "gone").mkdir()
    assert campaigns.swarm_evidence("gone", "k")["class"] == "unresolved"
    c = tmp_path / "c"
    c.mkdir()
    db = sqlite3.connect(c / "ledger.sqlite")
    db.execute("CREATE TABLE experiments (campaign, kernel)")
    db.execute("INSERT INTO experiments VALUES ('c', 'k')")
    db.commit()
    evidence = {"run": {"stopped": "finished", "exit": 0}, "audit": {}, "evaluations": 5, "holds": True, "received": True, "denials": {}}
    monkeypatch.setattr(campaigns, "agent_evidence", lambda *a: evidence)
    monkeypatch.setattr(campaigns, "cross_agent_history", lambda *a: True)
    monkeypatch.setattr(campaigns.gate, "trials", lambda *a: {"t": 1})
    assert campaigns.swarm_evidence("c", "k")["class"] == "unresolved"
    (c / "decision.json").write_text("{torn")
    e = campaigns.swarm_evidence("c", "k")
    assert e["class"] == "unresolved" and not e["complete"]
    (c / "decision.json").write_text(json.dumps({"promoted": []}))
    assert campaigns.swarm_evidence("c", "k")["class"] == "established"
    monkeypatch.setattr(campaigns.gate, "trials", lambda *a: {})
    assert campaigns.swarm_evidence("c", "k")["class"] == "not established"
    (c / "decision.json").write_text(json.dumps({"promoted": ["h"]}))
    assert campaigns.swarm_evidence("c", "k")["class"] == "promoted"
    (c / "decision.json").write_text(json.dumps({"promoted": []}))
    monkeypatch.setattr(campaigns, "agent_evidence", lambda *a: 1 / 0)
    assert campaigns.swarm_evidence("c", "k")["class"] == "unresolved"


@pytest.mark.parametrize("mode", ["search", "holdout"])
@pytest.mark.parametrize("recorded_kernel", ["series-kernel", "other-kernel", None])
def test_swarm_establishment_requires_every_ledger_kernel_to_match_the_series(tmp_path, monkeypatch, mode, recorded_kernel):
    """C4.5 v3: unchanged kernel; mismatched ledger is unresolved, but promotions always count."""
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    cid = campaigns.cohort("swarm")[0][0]
    work = tmp_path / cid
    work.mkdir()
    db = sqlite3.connect(work / "ledger.sqlite")
    db.execute("CREATE TABLE disclosures (id INTEGER PRIMARY KEY, campaign, agent, kind, content)")
    db.execute("CREATE TABLE experiments (id, campaign, agent, mode, kernel, trial, program)")
    db.execute("CREATE TABLE results (experiment_id, returns, summary)")
    db.executemany("INSERT INTO experiments VALUES (?, ?, 'A1', ?, ?, 'trial', '{}')",
                   [(1, cid, "search", "series-kernel"), (2, cid, mode, recorded_kernel), (3, "elsewhere", mode, "unrelated")])
    db.execute("INSERT INTO results VALUES (1, ?, ?)", (b"", json.dumps({"fills": 1})))
    for agent in ("A1", "A2", "A3", "A4"):
        d = work / "swarm" / agent
        d.mkdir(parents=True)
        (d / "transcript.jsonl").write_text("{}\n")
        run = {"agent": agent, "stopped": "finished", "exit": 0, "transcript_sha256": campaigns.sha256(d / "transcript.jsonl")}
        (d / "run.json").write_text(json.dumps(run))
        calls = [{"cmd": "eval", "response": {"ok": True, "fills": 1}},
                 {"cmd": "history", "response": {"ok": True, "evaluations": [{"agent": "A2" if agent == "A1" else "A1"}]}}]
        (d / "daemon.log").write_text("".join(json.dumps(c) + "\n" for c in calls))
        db.executemany("INSERT INTO disclosures (campaign, agent, kind, content) VALUES (?, ?, ?, ?)",
                       [(cid, agent, "eval", json.dumps({"result": {"fills": 1}})),
                        (cid, agent, "history", json.dumps(calls[1]["response"])), (cid, agent, "run", json.dumps(run))])
    db.commit()
    (work / "decision.json").write_text(json.dumps({"promoted": []}))
    rows = [{"id": cid, "mm": "series-kernel", "class": "established"}]
    report = campaigns.swarm_report(rows)
    expected = "established" if recorded_kernel == "series-kernel" else "unresolved"
    assert report["classes"][cid] == expected
    assert all(e["holds"] for e in report["evidence"][cid].values())
    if expected == "unresolved":
        assert "kernel" in report["reasons"][cid] and "series-kernel" in report["reasons"][cid]
    assert campaigns.swarm_report([{"id": cid}])["classes"][cid] == "unresolved"
    (work / "decision.json").write_text(json.dumps({"promoted": ["winner"]}))
    assert campaigns.swarm_report(rows)["classes"][cid] == "promoted"


def test_a_failed_agent_costs_the_swarm_nothing_but_its_count(tmp_path, monkeypatch):
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    monkeypatch.setattr(campaigns, "null_market", lambda cid, inputs: "market")

    def fails(market, ledger, cid, work, agents):
        run = Path(work) / "A1" / "run.json"
        run.parent.mkdir(parents=True)
        run.write_text(json.dumps({"agent": "A1", "stopped": "finished", "exit": 0}))
        db = sqlite3.connect(ledger)
        db.execute("CREATE TABLE disclosures (campaign, agent, kind, content)")
        db.execute("CREATE TABLE experiments (id, campaign, mode)")
        db.execute("CREATE TABLE results (experiment_id, summary)")
        db.commit()
        raise RuntimeError("disclose")

    monkeypatch.setattr(campaigns.harness, "run_swarm", fails)
    (tmp_path / "c").mkdir()
    monkeypatch.setattr(campaigns, "screened", lambda market, ledger, cid: ({"n": 1}, {}, []))
    monkeypatch.setattr(campaigns.gate, "freeze", lambda *a: None)
    monkeypatch.setattr(campaigns.gate, "holdout_decision", lambda *a: ([], {"diagnostics": {}}))
    monkeypatch.setattr(campaigns.gate, "bankrupt", lambda ledger: [])
    monkeypatch.setattr(campaigns.gate, "trials", lambda *a: {"t": 1})
    monkeypatch.setattr(campaigns, "agent_evidence", lambda ledger, cid, d, agent: {
        "run": None, "audit": None, "evaluations": 3, "holds": True, "received": True, "denials": {}})
    row = campaigns.swarm_null("c", {"mm": "k"})
    assert "disclose" in row["crash"] and row["counts_as_promotion"] and row["class"] == "unresolved" and row["search"] == {"n": 1}
    assert row["evaluations"] == 12 and list(row["agent_evaluations"]) == ["A1", "A2", "A3", "A4"]
    assert [r["agent"] for r in row["runs"]] == ["A1"]
    assert "disclose" in json.loads((tmp_path / "c" / "decision.json").read_text())["crash"]


def test_a_null_campaign_counts_if_it_promotes_crashes_or_an_agent_made_no_evaluation():
    done = {"stopped": "finished", "exit": 0}
    assert not campaigns.counts([], [done] * 4, [5, 9, 12, 7])
    assert campaigns.counts(["h"], [done] * 4, [5, 9, 12, 7])
    assert campaigns.counts([], [done, {"stopped": "finished", "exit": 1}], [5, 9])
    assert campaigns.counts([], [done] * 4, [5, 0, 12, 7])


def qualification_campaign(tmp_path, monkeypatch, promoted=()):
    """Committed outputs only, following C4.5's 2026-11-04 qualification; no kernel evaluation."""
    monkeypatch.setattr(campaigns, "OUT", tmp_path)
    cid = campaigns.cohort("swarm")[0][0]
    work = tmp_path / cid
    work.mkdir()
    db = sqlite3.connect(work / "ledger.sqlite")
    db.execute("CREATE TABLE experiments (id INTEGER PRIMARY KEY, campaign, agent, mode, kernel, trial, program)")
    db.execute("CREATE TABLE results (experiment_id, returns, summary)")
    db.execute("CREATE TABLE disclosures (id INTEGER PRIMARY KEY, campaign, agent, kind, content)")
    db.execute("CREATE TABLE selections (campaign, agent, strategy_hash)")
    db.execute("INSERT INTO selections VALUES (?, 'gate', 'h')", (cid,))
    for agent in ("A1", "A2", "A3", "A4"):
        d = work / "swarm" / agent
        d.mkdir(parents=True)
        (d / "transcript.jsonl").write_text("{}\n")
        run = {"agent": agent, "stopped": "finished", "exit": 0,
               "transcript_sha256": campaigns.sha256(d / "transcript.jsonl")}
        (d / "run.json").write_text(json.dumps(run))
        history = {"ok": True, "through": 1, "evaluations": [{"seq": 1, "agent": "A2" if agent == "A1" else "A1"}]}
        calls = [{"cmd": "eval", "response": {"ok": True, "fills": 1}}, {"cmd": "history", "response": history}]
        (d / "daemon.log").write_text("".join(json.dumps(c) + "\n" for c in calls))
        db.executemany("INSERT INTO disclosures (campaign, agent, kind, content) VALUES (?, ?, ?, ?)",
                       [(cid, agent, "eval", json.dumps({"result": {"fills": 1}})),
                        (cid, agent, "history", json.dumps(history)), (cid, agent, "run", json.dumps(run))])
    (work / "decision.json").write_text(json.dumps({"promoted": list(promoted)}))
    db.commit()
    row = {"id": cid, "mm": "k", "kept": ["h"], "search": {"finalists": ["h", "mechanism-rejected"]}}
    return cid, work, db, row


def committed_result(db, cid, experiment, trial="h", mode="search", fills=1, turnover=3.0, returns=(-0.2, 0.1)):
    db.execute("INSERT INTO experiments VALUES (?, ?, 'A1', ?, 'k', ?, '{}')", (experiment, cid, mode, trial))
    db.execute("INSERT INTO results VALUES (?, ?, ?)",
               (experiment, struct.pack("<" + "d" * len(returns), *returns), json.dumps({"fills": fills, "turnover": turnover})))
    db.commit()


def test_v3_reports_each_finalists_committed_search_and_completed_holdout_separately(tmp_path, monkeypatch):
    cid, work, db, row = qualification_campaign(tmp_path, monkeypatch)
    committed_result(db, cid, 1, fills=0, turnover=111, returns=(-0.9,))
    committed_result(db, cid, 2, turnover=7.25, returns=(0.1, -1.0, 0.0))
    committed_result(db, cid, 3, turnover=222, returns=(-0.8,))
    committed_result(db, cid, 4, mode="holdout", turnover=2.5, returns=(0.0, 0.0))
    committed_result(db, cid, 5, trial="mechanism-rejected", turnover=0.75, returns=(-0.03, 0.02))
    committed_result(db, "other-campaign", 6, mode="holdout", turnover=333, returns=(-0.7,))
    before = (work / "ledger.sqlite").read_bytes()

    def forbidden(*args, **kwargs):
        pytest.fail("reporting must not evaluate, read a market, or recompute a decision")

    monkeypatch.setattr(campaigns.subprocess, "run", forbidden)
    monkeypatch.setattr(campaigns.markets, "generate", forbidden)
    monkeypatch.setattr(campaigns.gate, "search_decision", forbidden)
    monkeypatch.setattr(campaigns.gate, "promote", forbidden)
    monkeypatch.setattr(campaigns.gate, "release", forbidden)
    report = campaigns.swarm_report([row])
    diagnostics = report["finalist_diagnostics"][cid]
    assert set(diagnostics) == {"h", "mechanism-rejected"}
    assert diagnostics["h"]["search"] == {"experiment": 2, "turnover": 7.25, "min_net_step_return": -1.0, "unavailable": []}
    assert diagnostics["h"]["holdout"] == {"experiment": 4, "turnover": 2.5, "min_net_step_return": 0.0, "unavailable": []}
    assert diagnostics["mechanism-rejected"]["search"]["min_net_step_return"] == -0.03
    assert "holdout" in " ".join(diagnostics["mechanism-rejected"]["holdout"]["unavailable"])
    note = report["finalist_diagnostics_note"].lower()
    assert "not maximum held gross exposure" in note and "after shortfall absorption" in note
    assert "do not measure" in note and "size" in note
    assert report["classes"][cid] == "established"
    assert (work / "ledger.sqlite").read_bytes() == before


@pytest.mark.parametrize("missing", ["search", "holdout", "incomplete holdout", "empty returns", "turnover", "ledger"])
def test_v3_names_unavailable_finalist_results_without_substituting_or_reclassifying(tmp_path, monkeypatch, missing):
    cid, work, db, row = qualification_campaign(tmp_path, monkeypatch, promoted=["h"])
    if missing != "search":
        committed_result(db, cid, 1, returns=() if missing == "empty returns" else (-0.2,))
    if missing not in ("holdout", "incomplete holdout"):
        committed_result(db, cid, 2, mode="holdout")
    if missing == "incomplete holdout":
        db.execute("INSERT INTO experiments VALUES (2, ?, 'gate', 'holdout', 'k', 'h', '{}')", (cid,))
        db.commit()
    if missing == "turnover":
        db.execute("UPDATE results SET summary = ? WHERE experiment_id = 1", (json.dumps({"fills": 1}),))
        db.commit()
    if missing == "ledger":
        db.close()
        (work / "ledger.sqlite").unlink()
    report = campaigns.swarm_report([row])
    diagnostic = report["finalist_diagnostics"][cid]["h"]
    mode = "holdout" if missing in ("holdout", "incomplete holdout") else "search"
    field = "turnover" if missing == "turnover" else "min_net_step_return"
    assert diagnostic[mode][field] is None and diagnostic[mode]["unavailable"]
    assert report["classes"][cid] == ("unresolved" if missing == "ledger" else "promoted")
    if missing == "empty returns":
        assert diagnostic["search"]["turnover"] == 3.0


@pytest.mark.parametrize("failure", [None, "no filled trial", "one evaluating agent", "no cross-agent history",
                                      "transcript mismatch", "history mismatch", "kernel mismatch", "disclosed crash", "gate crash"])
def test_v3_promotions_report_every_establishment_requirement_without_changing_the_verdict(tmp_path, monkeypatch, failure):
    cid, work, db, row = qualification_campaign(tmp_path, monkeypatch, promoted=["h"])
    committed_result(db, cid, 1, fills=0 if failure == "no filled trial" else 1)
    committed_result(db, cid, 2)
    if failure == "no filled trial":
        db.execute("UPDATE results SET summary = ?", (json.dumps({"fills": 0, "turnover": 0}),))
    if failure == "kernel mismatch":
        db.execute("UPDATE experiments SET kernel = 'wrong'")
    if failure == "gate crash":
        (work / "decision.json").write_text(json.dumps({"promoted": ["h"], "crash": "harness failed"}))
    for agent in ("A1", "A2", "A3", "A4"):
        d = work / "swarm" / agent
        calls = [json.loads(l) for l in (d / "daemon.log").read_text().splitlines()]
        if failure == "one evaluating agent" and agent != "A1":
            calls = calls[1:]
            db.execute("DELETE FROM disclosures WHERE agent = ? AND kind = 'eval'", (agent,))
        if failure == "no cross-agent history":
            calls[-1]["response"]["evaluations"] = [{"agent": agent}]
            db.execute("UPDATE disclosures SET content = ? WHERE agent = ? AND kind = 'history'",
                       (json.dumps(calls[-1]["response"]), agent))
        if failure == "history mismatch" and agent == "A1":
            calls[-1]["response"]["evaluations"] = []
        (d / "daemon.log").write_text("".join(json.dumps(c) + "\n" for c in calls))
    if failure == "transcript mismatch":
        (work / "swarm/A1/transcript.jsonl").write_text("{}\n{}\n")
    if failure == "disclosed crash":
        d = work / "swarm/A1/run.json"
        run = json.loads(d.read_text()) | {"exit": 1}
        d.write_text(json.dumps(run))
        db.execute("UPDATE disclosures SET content = ? WHERE agent = 'A1' AND kind = 'run'", (json.dumps(run),))
    db.commit()
    report = campaigns.swarm_report([row])
    establishment = report["promotion_establishment"][cid]
    assert establishment["holds"] == (failure is None)
    assert establishment["promotion_masks_non_establishment"] == (failure is not None)
    assert establishment["distinct_filled_trials"] == (0 if failure == "no filled trial" else 1)
    assert establishment["agents_with_evaluations"] == (["A1"] if failure == "one evaluating agent" else ["A1", "A2", "A3", "A4"])
    assert establishment["audit_complete"] == (failure not in ("transcript mismatch", "history mismatch"))
    assert bool(establishment["history_receipts"]) == (failure != "no cross-agent history")
    if failure is None:
        receipt = establishment["history_receipts"][0]
        assert receipt["recipient"] == "A1" and receipt["evaluations"] == [{"agent": "A2", "seq": 1}]
        assert receipt["disclosure"] == 2 and receipt["through"] == 1
    else:
        assert establishment["missing_or_mismatched"]
    assert report["classes"][cid] == "promoted" and report["verdict"] == "not established"


def test_v3_exposes_the_masking_false_pass_channel_but_does_not_repair_it(tmp_path, monkeypatch):
    cid, work, db, row = qualification_campaign(tmp_path, monkeypatch, promoted=["h"])
    committed_result(db, cid, 1, fills=0)
    ids = campaigns.cohort("swarm")[0]
    original = campaigns.swarm_evidence
    established = original(cid, "k")
    for other in ids[1:]:
        (tmp_path / other).mkdir()

    def evidence(other, mm):
        if other == cid:
            return original(other, mm)
        return established | {"class": "not established" if other == ids[1] else "established", "promoted": []}
    monkeypatch.setattr(campaigns, "swarm_evidence", evidence)
    report = campaigns.swarm_report([row])
    assert report["verdict"] == "pass" and report["not_established"] == 1
    assert report["promotion_establishment"][cid]["promotion_masks_non_establishment"]


def test_v3_recovers_frozen_finalist_identities_but_names_a_missing_search_report(tmp_path, monkeypatch):
    cid, work, db, row = qualification_campaign(tmp_path, monkeypatch)
    committed_result(db, cid, 1)
    committed_result(db, cid, 2, mode="holdout")
    report = campaigns.swarm_report([{"id": cid, "mm": "k", "crash": "interrupted after holdout commit"}])
    assert report["finalist_diagnostics"][cid]["h"]["holdout"]["experiment"] == 2
    assert "search finalist" in " ".join(report["finalist_evidence_unavailable"][cid])
    assert report["classes"][cid] == "established"


@pytest.mark.parametrize("missing", ["run", "transcript", "history JSON", "disclosures table"])
def test_v3_names_missing_or_unreadable_promotion_evidence(tmp_path, monkeypatch, missing):
    cid, work, db, row = qualification_campaign(tmp_path, monkeypatch, promoted=["h"])
    committed_result(db, cid, 1)
    if missing in ("run", "transcript"):
        (work / "swarm/A1" / ("run.json" if missing == "run" else "transcript.jsonl")).unlink()
    elif missing == "history JSON":
        db.execute("UPDATE disclosures SET content = 'null' WHERE kind = 'history'")
    else:
        db.execute("DROP TABLE disclosures")
    db.commit()
    report = campaigns.swarm_report([row])
    evidence = report["promotion_establishment"][cid]
    assert report["classes"][cid] == "promoted"
    assert evidence["promotion_masks_non_establishment"] and not evidence["audit_complete"]
    assert evidence["missing_or_mismatched"]


def test_v3_unreadable_search_summary_does_not_hide_a_completed_holdout(tmp_path, monkeypatch):
    cid, work, db, row = qualification_campaign(tmp_path, monkeypatch, promoted=["h"])
    committed_result(db, cid, 1)
    committed_result(db, cid, 2, mode="holdout", turnover=4.5, returns=(-0.1,))
    db.execute("UPDATE results SET summary = 'null' WHERE experiment_id = 1")
    db.commit()
    report = campaigns.swarm_report([row])
    diagnostic = report["finalist_diagnostics"][cid]["h"]
    assert diagnostic["search"]["unavailable"] and diagnostic["search"]["turnover"] is None
    assert diagnostic["holdout"] == {"experiment": 2, "turnover": 4.5, "min_net_step_return": -0.1, "unavailable": []}
    assert report["classes"][cid] == "promoted"
