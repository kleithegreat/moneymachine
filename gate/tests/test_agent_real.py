"""The one real campaign with the model call stubbed and everything else real (kernel, daemon, ledger, claim): each way it
can end, and recovery after a crash at each step (audit/criteria.md, stage 3, revisions of 2026-10-31); and the null
series as its pod runs it."""

import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import pytest

from gate import kernel, markets
from gate.agent import campaigns
from gate.agent.daemon import Daemon
from gate.kernel import MM, command
from gate.markets import HOLDOUT_START, HOUR, W_START, write_market

REPO = Path(__file__).resolve().parents[2]
BAD = '{"dsl": 1}'


class Crash(Exception):
    pass


def program(hours):
    close = {"input": "close"}
    momentum = {"op": "sub", "args": [{"op": "div", "args": [close, {"op": "lag", "args": [close], "hours": hours}]}, {"const": 1, "unit": "1"}]}
    return json.dumps({"dsl": 1, "name": "momentum", "mechanism": {"counterparty": "-", "predictions": [], "capacity": "-"},
                       "weight": {"op": "mul", "args": [{"op": "sign", "args": [momentum]}, {"const": 0.05, "unit": "1"}]}})


def daemon_session(market, ledger, cid, workdir, evals):
    """A model session's calls, made through the real daemon: a rejected free check, then `evals`."""
    workdir.mkdir(parents=True)
    (workdir / "transcript.jsonl").write_text("")
    d = Daemon(workdir / "sock", market, ledger, cid, "A", 100, workdir / "daemon.log")
    d.handle({"cmd": "check", "args": [BAD]})
    for text in evals:
        d.handle({"cmd": "eval", "args": [text]})
    d.proc.stdin.close()
    d.proc.wait()
    return d


class Campaign:
    """The stubs around `real`: the model session runs `evals` through the real daemon, the searcher commits one
    evaluation, and the search gate passes every filled trial when `finalists` is set."""

    def __init__(self, tmp_path, monkeypatch):
        self.root = write_market(tmp_path / "real", days=60, holdout_days=20)
        policy = json.loads((self.root / "store/policy.json").read_text())
        self.from_ = policy["holdout_start"]
        self.out, self.monkeypatch = tmp_path / "agent", monkeypatch
        self.evals, self.finalists, self.sessions, self.searches, self.releases = [program(8), program(12)], True, 0, 0, 0
        self.end = {"stopped": "finished", "exit": 0}
        record, null = tmp_path / "holdout.json", tmp_path / "null.json"
        record.write_text(json.dumps([{"path": str(p.relative_to(self.root)), "sha256": campaigns.sha256(p)}
                                      for p in sorted((self.root / "holdout").rglob("*.parquet"))]))
        ids = campaigns.cohort("agent")[0]
        audit = {"match": True, "outside_permitted": []}
        null.write_text(json.dumps({"ids": ids, "mm": [campaigns.sha256(MM)], "counted_promotions": 0, "audits": dict.fromkeys(ids, audit)}))
        for name, value in [("OUT", self.out), ("VENUE", self.root / "venue"), ("HOLDOUT_RECORD", record), ("NULL_SUMMARY", null),
                            ("check_frozen", lambda: None), ("wait_for_room", lambda log: ("TAMU", {"five_hour": [0.1, 100]}))]:
            monkeypatch.setattr(campaigns, name, value)
        monkeypatch.setattr(campaigns.sweep, "require_frozen_searcher", lambda: None)
        monkeypatch.setattr(campaigns.harness, "run_agent", self.session)
        monkeypatch.setattr(campaigns.search, "run", self.searcher)
        monkeypatch.setattr(campaigns.gate, "search_decision", self.decision)
        monkeypatch.setattr(campaigns.gate, "mechanism_check", lambda m, l, c, programs: {h: {"pass": True} for h in programs})
        real_release = campaigns.gate.release

        def release(*args):
            self.releases += 1
            return real_release(*args)

        monkeypatch.setattr(campaigns.gate, "release", release)

    def session(self, market, ledger, cid, workdir, die=False, undisclosed=False):
        self.sessions += 1
        d = daemon_session(market, ledger, cid, workdir, self.evals)
        if die:
            raise Crash
        run = {"campaign": cid, "agent": "A", "spent": d.spent, **self.end}
        (workdir / "run.json").write_text(json.dumps(run))
        if undisclosed:
            raise Crash
        subprocess.run(command("disclose", workdir / "run.json", cid, "A", ledger, None, "--kind", "run"), check=True, capture_output=True)
        return run

    def searcher(self, name, market, ledger, cid, seed, die=False):
        self.searches += 1
        file = market.parent / "g.json"
        file.write_text(program(24))
        subprocess.run(command("eval", file, cid, name, ledger, market), check=True, capture_output=True)
        if die:
            raise Crash

    def decision(self, ledger, cid, agent=None):
        finalists = list(campaigns.gate.candidates(ledger, cid, agent)) if self.finalists else []
        return finalists, {"n": len(finalists), "spa_p": 0.01, "screened": [], "finalists": finalists}

    def run(self, version=1):
        campaigns.real(self.root, version, self.from_)

    def claims(self):
        return campaigns.claims(self.root / "holdout")

    def report(self, cid="stage3-real"):
        return json.loads((self.out / cid / "real.json").read_text())

    def disclosures(self, kind, cid="stage3-real"):
        return sqlite3.connect(self.out / cid / "ledger.sqlite").execute(
            "SELECT content FROM disclosures WHERE kind = ?", (kind,)).fetchall()


@pytest.fixture
def c(tmp_path, monkeypatch):
    if os.access(REPO, os.W_OK):
        kernel.build()
    return Campaign(tmp_path, monkeypatch)


def test_a_complete_campaign_commits_promotions_before_reading_diagnostics(c, monkeypatch):
    read = campaigns.gate.committed_diagnostics

    def diagnostics(ledger, cid):
        assert c.disclosures("promotion")
        return read(ledger, cid)

    monkeypatch.setattr(campaigns.gate, "committed_diagnostics", diagnostics)
    c.run()
    r = c.report()
    assert r["released"] and r["batch"]["missing"] == [] and len(c.claims()) == 1 and c.claims()[0]["start"] == c.from_
    assert r["A"]["evaluations"] == 2 and r["B"]["evaluations"] == 1 and len(r["A"]["kept"]) == 2 and len(r["B"]["kept"]) == 1
    assert all(r["A"]["holdout"]["diagnostics"].values()) and r["comparison"]["statement"] == campaigns.NO_CLAIM
    assert r["audit"]["match"] and r["audit"]["ledger_rows"] == 3
    assert r["account"] == "TAMU" and r["windows"] == {"five_hour": [0.1, 100]} and "token" not in json.dumps(r).lower().replace("_tokens", "")


def test_a_dead_session_with_evaluations_stands(c, monkeypatch):
    session = c.session
    monkeypatch.setattr(campaigns.harness, "run_agent", lambda *a: session(*a, die=True))
    with pytest.raises(Crash):
        c.run()
    monkeypatch.setattr(campaigns.harness, "run_agent", lambda *a: pytest.fail("a second attempt"))
    c.run()
    r = c.report()
    assert r["agent_run"]["crashed"] and r["A"]["evaluations"] == 2 and r["released"] and c.searches == 1
    assert any("crashed" in row for (row,) in c.disclosures("run"))


@pytest.mark.parametrize("stopped, exit", [("finished", 0), ("turn limit", -9), ("wall time", -9)])
def test_zero_evaluations_are_void_and_the_next_attempt_takes_a_fresh_id(c, stopped, exit):
    c.evals, c.end = [], {"stopped": stopped, "exit": exit}
    with pytest.raises(SystemExit, match="void"):
        c.run()
    assert (c.out / "stage3-real/void.json").exists() and c.searches == 0 and c.claims() == []
    c.evals = [program(8)]
    c.run()
    assert c.sessions == 2 and c.report("stage3-real-2")["void_attempts"] == ["stage3-real"]
    assert [x["campaign"] for x in c.claims()] == ["stage3-real-2"]


def test_an_attempt_stopped_from_outside_before_any_evaluation_is_not_void(c):
    c.evals = []
    (c.out / "stage3-real/run").mkdir(parents=True)
    with pytest.raises(SystemExit, match="goes to the human"):
        c.run()
    assert not (c.out / "stage3-real/void.json").exists() and c.sessions == 0 and c.searches == 0 and c.claims() == []
    with pytest.raises(SystemExit, match="goes to the human"):
        c.run()
    assert not (c.out / "stage3-real-2").exists()


@pytest.mark.parametrize("exit", [1, -9, -15, 137])
def test_a_session_without_a_designed_end_and_no_evaluation_goes_to_the_human(c, exit):
    """A child killed from outside while its runner survives leaves a normal run record with a signal or nonzero exit."""
    c.evals, c.end = [], {"stopped": "finished", "exit": exit}
    for _ in range(2):
        with pytest.raises(SystemExit, match="goes to the human"):
            c.run()
    assert not (c.out / "stage3-real/void.json").exists() and c.sessions == 1 and c.searches == 0 and c.claims() == []
    assert not (c.out / "stage3-real-2").exists()


def test_a_resume_with_another_dataset_version_is_refused(c, monkeypatch):
    crash_once(monkeypatch, campaigns.gate, "mechanism_check")
    with pytest.raises(Crash):
        c.run()
    with pytest.raises(SystemExit, match="inputs differ"):
        c.run(version=2)
    assert (c.out / "stage3-real/m/version").read_text() == "1\n" and c.searches == 0 and c.claims() == []
    c.run()
    assert c.report()["version"] == 1 and len(c.claims()) == 1


def test_a_run_record_never_disclosed_is_disclosed_on_resume(c, monkeypatch):
    session = c.session
    monkeypatch.setattr(campaigns.harness, "run_agent", lambda *a: session(*a, undisclosed=True))
    with pytest.raises(Crash):
        c.run()
    assert c.disclosures("run") == []
    c.run()
    (row,) = c.disclosures("run")
    assert json.loads(row[0]) == json.loads((c.out / "stage3-real/run/run.json").read_text()) == c.report()["agent_run"]
    assert c.sessions == 1 and len(c.claims()) == 1


def test_a_run_record_that_differs_from_its_disclosure_stops_before_arm_b(c, monkeypatch):
    crash_once(monkeypatch, campaigns.gate, "mechanism_check")
    with pytest.raises(Crash):
        c.run()
    run_json = c.out / "stage3-real/run/run.json"
    run_json.write_text(json.dumps(json.loads(run_json.read_text()) | {"exit": 0, "stopped": "turn limit"}))
    with pytest.raises(SystemExit, match="differs from the ledger"):
        c.run()
    assert c.searches == 0 and c.claims() == []


def test_zero_finalists_make_no_claim_and_say_so(c):
    c.finalists = False
    c.run()
    r = c.report()
    assert r["released"] is False and c.claims() == [] and c.releases == 0 and r["A"]["promoted"] == []


def partial_release(c, survivors):
    """A batch that stopped after its claim: the kernel's real claim, and real results only for `survivors`' programs."""

    def release(market, ledger, cid, programs, holdout_from):
        c.releases += 1
        batch = market.parent / "batch.jsonl"
        batch.write_text("".join(json.dumps(programs[h]) + "\n" for h in list(programs)[:survivors]))
        for h in list(programs)[:survivors]:
            subprocess.run(command("select", h, cid, "partial", ledger, None, "--note", "x"), check=True, capture_output=True)
        subprocess.run(command("holdout", batch, cid, "partial", ledger, market, "--holdout-store", str(market / "holdout"),
                               "--holdout-from", str(holdout_from)), check=True, capture_output=True)
        file = market.parent / "abort.json"
        file.write_text('{"ok": false, "code": "R_BOUND"}')
        subprocess.run(command("disclose", file, cid, "gate", ledger, None, "--kind", "abort"), check=True, capture_output=True)

    c.monkeypatch.setattr(campaigns.gate, "release", release)


def test_an_aborted_finalist_counts_as_p_one_in_its_family_and_recovery_never_evaluates_again(c):
    partial_release(c, 1)
    with pytest.raises(SystemExit, match="incomplete"):
        c.run()
    r = c.report()
    first, second = r["A"]["kept"]
    assert r["batch"]["missing"] == sorted([second, r["B"]["kept"][0]]) and len(r["batch"]["aborts"]) == 1
    h = r["A"]["holdout"]
    assert h["holdout_p"][second] == 1.0 and h["holm"][second] == 1.0 and h["holdout_total_return"][second] == 0.0
    assert h["holm"][first] == pytest.approx(min(1.0, 2 * h["holdout_p"][first])) and second not in r["A"]["promoted"]
    assert h["diagnostics"][second] is None and r["B"]["holdout"]["holdout_p"][r["B"]["kept"][0]] == 1.0
    assert c.releases == 1
    with pytest.raises(SystemExit, match="incomplete"):
        c.run()
    assert c.releases == 1 and len(c.claims()) == 1 and len(c.disclosures("promotion")) == 1


def test_a_batch_killed_right_after_its_claim_is_reported_as_lost(c):
    def release(market, ledger, cid, programs, holdout_from):
        with open(market / "holdout" / "spent.jsonl", "a") as fh:
            fh.write(json.dumps({"start": holdout_from, "end": 2**62, "campaign": cid}) + "\n")
        raise Crash

    c.monkeypatch.setattr(campaigns.gate, "release", release)
    with pytest.raises(Crash):
        c.run()
    with pytest.raises(SystemExit, match="incomplete"):
        c.run()
    r = c.report()
    assert r["released"] and len(r["batch"]["missing"]) == 3 and r["A"]["promoted"] == r["B"]["promoted"] == []
    assert set(r["A"]["holdout"]["holdout_p"].values()) == {1.0}


def crash_once(monkeypatch, owner, name):
    real = getattr(owner, name)
    state = {"armed": True}

    def wrapped(*args, **kwargs):
        if state["armed"]:
            state["armed"] = False
            raise Crash
        return real(*args, **kwargs)

    monkeypatch.setattr(owner, name, wrapped)


def crash_on_write(monkeypatch, filename):
    real = campaigns.write_json
    state = {"armed": True}

    def wrapped(path, value):
        if state["armed"] and path.name == filename:
            state["armed"] = False
            raise Crash
        return real(path, value)

    monkeypatch.setattr(campaigns, "write_json", wrapped)


STEPS = {"screening": lambda m: crash_once(m, campaigns.gate, "mechanism_check"),
         "freeze": lambda m: crash_once(m, campaigns.gate, "freeze"),
         "pre-release": lambda m: crash_on_write(m, "pre-release.json"),
         "before the claim": lambda m: crash_once(m, campaigns.gate, "release"),
         "promotions": lambda m: crash_once(m, campaigns, "commit_promotions"),
         "diagnostics": lambda m: crash_once(m, campaigns.gate, "committed_diagnostics"),
         "report": lambda m: crash_on_write(m, "real.json")}


@pytest.mark.parametrize("step", STEPS)
def test_recovery_after_a_crash_at_each_step(c, monkeypatch, step):
    STEPS[step](monkeypatch)
    with pytest.raises(Crash):
        c.run()
    assert c.sessions == 1
    c.run()
    r = c.report()
    assert c.sessions == 1 and c.searches == 1 and len(c.claims()) == 1 and r["batch"]["missing"] == []
    assert len(c.disclosures("promotion")) == 1 and all(r["A"]["holdout"]["diagnostics"].values())


def test_a_searcher_that_died_ended_its_arm(c, monkeypatch):
    searcher = c.searcher
    monkeypatch.setattr(campaigns.search, "run", lambda *a: searcher(*a, die=True))
    with pytest.raises(Crash):
        c.run()
    c.run()
    assert c.searches == 1 and c.report()["B"]["evaluations"] == 1


@pytest.mark.parametrize("spoil", ["searcher", "harness", "c32", "c32 v1", "kernel", "failed audit", "no audit", "holdout", "claim"])
def test_nothing_starts_unless_it_is_ready(c, monkeypatch, spoil):
    def refuse():
        raise SystemExit("pin")

    if spoil == "searcher":
        monkeypatch.setattr(campaigns.sweep, "require_frozen_searcher", refuse)
    elif spoil == "harness":
        monkeypatch.setattr(campaigns, "check_frozen", refuse)
    elif spoil.startswith("c32") or spoil in ("kernel", "failed audit", "no audit"):
        null = json.loads(campaigns.NULL_SUMMARY.read_text())
        last = campaigns.cohort("agent")[0][-1]
        null |= {"c32": {"counted_promotions": 3}, "c32 v1": {"ids": [f"agent-null-N2-{i}" for i in range(20)]},
                 "kernel": {"mm": ["other"]},
                 "failed audit": {"audits": null["audits"] | {last: {"match": True, "outside_permitted": ["WebFetch"]}}},
                 "no audit": {"audits": null["audits"] | {last: None}}}[spoil]
        campaigns.NULL_SUMMARY.write_text(json.dumps(null))
    elif spoil == "holdout":
        file = next((c.root / "holdout").rglob("*.parquet"))
        file.chmod(0o644)
        file.write_bytes(b"other")
    else:
        (c.root / "holdout/spent.jsonl").write_text(json.dumps({"start": c.from_, "end": 2**62, "campaign": "other"}) + "\n")
    with pytest.raises(SystemExit):
        c.run()
    assert c.sessions == 0 and not (c.out / "stage3-real/run").exists()


def test_the_harness_is_checked_again_after_pacing(c, monkeypatch):
    calls = []

    def wait(log):
        monkeypatch.setattr(campaigns, "check_frozen", lambda: calls.append("frozen") or sys.exit("changed"))
        return "TAMU", {}

    monkeypatch.setattr(campaigns, "wait_for_room", wait)
    with pytest.raises(SystemExit):
        c.run()
    assert calls == ["frozen"] and c.sessions == 0


def test_an_input_changed_during_the_arms_stops_the_release(c, monkeypatch):
    run_agent = c.session

    def session(market, ledger, cid, workdir):
        run = run_agent(market, ledger, cid, workdir)
        (c.root / "store/funding/extra.parquet").write_bytes(b"x")
        return run

    monkeypatch.setattr(campaigns.harness, "run_agent", session)
    with pytest.raises(SystemExit, match="inputs differ"):
        c.run()
    assert c.claims() == [] and c.releases == 0


def test_a_failed_audit_stops_before_arm_b(c, monkeypatch):
    session = c.session

    def forged(market, ledger, cid, workdir):
        run = session(market, ledger, cid, workdir)
        (workdir / "daemon.log").unlink()
        return run

    monkeypatch.setattr(campaigns.harness, "run_agent", forged)
    with pytest.raises(SystemExit, match="audit"):
        c.run()
    assert c.searches == 0 and c.claims() == []


def test_audit_matches_per_kind_in_order_and_tolerates_a_session_without_calls(tmp_path, c):
    market, ledger, run = c.root, tmp_path / "l.sqlite", tmp_path / "run"
    c.session(market, ledger, "x", run)
    a = campaigns.audit_run(run, ledger, "x")
    assert a["match"] and a["daemon_calls"] == 3
    lines = (run / "daemon.log").read_text().splitlines()
    (run / "daemon.log").write_text("\n".join(lines[1:] + lines[:1]) + "\n")
    assert not campaigns.audit_run(run, ledger, "x")["match"]
    empty = tmp_path / "empty"
    empty.mkdir()
    (empty / "transcript.jsonl").write_text("")
    subprocess.run(command("disclose", run / "run.json", "y", "A", ledger, None, "--kind", "run"), check=True, capture_output=True)
    assert campaigns.audit_run(empty, ledger, "y")["match"]


def test_a_null_session_that_made_no_call_still_counts_as_a_promotion(c, monkeypatch):
    c.evals = []
    ledger = c.out / "null-0/ledger.sqlite"

    def silent(market, led, cid, workdir):
        workdir.mkdir(parents=True)
        (workdir / "transcript.jsonl").write_text("")
        subprocess.run(command("disclose", REPO / "kernel/strategies/w0.json", cid, "A", led, None, "--kind", "run"), check=True, capture_output=True)
        return {"spent": 0}

    (c.out / "null-0").mkdir(parents=True)
    monkeypatch.setattr(campaigns, "null_market", lambda cid, cells: c.root)
    monkeypatch.setattr(campaigns.harness, "run_agent", silent)
    r = campaigns.agent_null("null-0", {})
    assert r["counts_as_promotion"] and r["promoted"] == [] and ledger.exists()


@pytest.mark.parametrize("stopped, exit, counts", [("finished", 1, True), ("finished", -9, True), ("wall time", -9, False),
                                                   ("turn limit", -9, False), ("finished", 0, False)])
def test_a_null_session_that_crashed_counts_as_a_promotion(c, monkeypatch, stopped, exit, counts):
    c.evals = []

    def called(market, led, cid, workdir):
        workdir.mkdir(parents=True)
        (workdir / "transcript.jsonl").write_text("")
        (workdir / "daemon.log").write_text("")
        subprocess.run(command("disclose", REPO / "kernel/strategies/w0.json", cid, "A", led, None, "--kind", "run"), check=True, capture_output=True)
        return {"spent": 1, "stopped": stopped, "exit": exit}

    (c.out / "null-0").mkdir(parents=True)
    monkeypatch.setattr(campaigns, "null_market", lambda cid, cells: c.root)
    monkeypatch.setattr(campaigns.harness, "run_agent", called)
    r = campaigns.agent_null("null-0", {})
    assert r["promoted"] == [] and r["counts_as_promotion"] == counts


def test_no_returns_mean_p_one():
    assert campaigns.gate.holdout_pvalue(np.zeros(0)) == 1.0


def series_in_the_pods_view():
    """One campaign of the agent series, run by `test_the_series_in_its_pods_view` inside the pod's view: everything
    real but the model session (through the real daemon), pacing and the funding blob, synthetic and seeded here."""
    spec = markets.null_params()["N2"]
    t, k = len(range(W_START, HOLDOUT_START, HOUR)), len(set(spec["funding"]["coins"]) - set(spec["funding"]["short"]))
    blob = np.random.default_rng(0).normal(1.25e-5, 1e-5, (2 * t, k)).tobytes()
    spec["funding"]["sha256"] = hashlib.sha256(blob).hexdigest()
    (campaigns.OUT / "inputs").mkdir()
    (campaigns.OUT / "inputs" / spec["funding"]["sha256"]).write_bytes(blob)
    markets.NULLS = Path(tempfile.mkdtemp()) / "nulls.json"
    markets.NULLS.write_text(json.dumps({"N2": spec}))
    rooms = iter([("TAMU", {})])
    campaigns.wait_for_room = lambda log: next(rooms, None)
    campaigns.windows = lambda token=None: None
    campaigns.harness.run_agent = lambda market, ledger, cid, workdir: {"spent": daemon_session(market, ledger, cid, workdir, [program(8)]).spent}
    campaigns.run_series("agent")
    rows = [json.loads(l) for l in open(campaigns.cohort("agent")[1])]
    assert len(rows) == 1 and "crash" not in rows[0] and rows[0]["audit"]["match"] and rows[0]["mm"] == campaigns.sha256(MM), rows


def test_the_series_in_its_pods_view(tmp_path):
    """The series pod's view: a read-only root, `data/` hidden but for the `agent` volume holding the seeded kernel."""
    kernel.build()
    (REPO / "data").mkdir(exist_ok=True)
    volume = tmp_path / "agent"
    (volume / "kernel/release").mkdir(parents=True)
    shutil.copy2(MM, volume / "kernel/release/mm")
    out = subprocess.run(["bwrap", "--ro-bind", "/", "/", "--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp",
                          "--tmpfs", REPO / "data", "--bind", volume, REPO / "data/agent", sys.executable, "-c",
                          "from gate.tests.test_agent_real import series_in_the_pods_view; series_in_the_pods_view()"],
                         capture_output=True, text=True, cwd=REPO,
                         env=os.environ | {"PYTHONDONTWRITEBYTECODE": "1", "CARGO_TARGET_DIR": str(REPO / "data/agent/kernel")})
    assert out.returncode == 0, out.stdout + out.stderr


def test_under_a_read_only_root(tmp_path):
    kernel.build()
    target = f"{Path(__file__)}::test_a_complete_campaign_commits_promotions_before_reading_diagnostics"
    out = subprocess.run(["bwrap", "--ro-bind", "/", "/", "--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp", sys.executable, "-m", "pytest",
                          "-q", "-p", "no:cacheprovider", target], capture_output=True, text=True, cwd=REPO,
                         env=os.environ | {"PYTHONDONTWRITEBYTECODE": "1"})
    assert out.returncode == 0, out.stdout + out.stderr
