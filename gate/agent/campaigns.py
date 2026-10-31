"""Agent campaigns: the sandboxed research agent (arm A) and the swarm on null markets as smoke tests, and the one
real campaign (arm A against the G100 searcher, one holdout batch); null series are paced, and both resume."""

import hashlib
import json
import os
import signal
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

from gate import campaign, gate, markets, search, sweep
from gate.agent import harness
from gate.kernel import MM, command
from ingest.live import now_ms
from ingest.policy import DAY
from sandbox import session

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "data" / "agent"
FROZEN = REPO / "audit/stage3/harness.json"
NULL_SUMMARY = REPO / "audit/stage3/null-summary.json"
HOLDOUT_RECORD = REPO / "audit/holdout.json"
VENUE = REPO / "venue/hyperliquid"
REPORT_FROM_DAY = {"agent": 670, "swarm": 640}
REAL_REPORT_FROM = 1785542400000  # 2026-08-01, a month after the agent model's knowledge cutoff
LABEL = "pipeline validation run, not a test for edge; every promotion: historical holdout, costs fitted after it"
MIN_SWARM_EVALUATIONS = 200
CEILING = 0.8  # the most of any subscription window a campaign may bring it to; the rest stays with the human
FIRST_NEED = 0.5  # a campaign's assumed share of each window until one has been measured
ACCOUNTS = (("TAMU", "CLAUDE_CODE_OAUTH_TOKEN_TAMU"), ("Cornell", "CLAUDE_CODE_OAUTH_TOKEN_CORNELL"))  # in preference order: the thesis track also draws on Cornell
TOKENS = ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens", "output_tokens")
STOP = threading.Event()  # set by SIGTERM: the series ends between campaigns
NO_CLAIM = "One campaign per arm supports no claim that either generator is better."
SMOKE = {"agent": "20 runs bound the promotion rate only to about 0.28; this is a smoke test.",
         "swarm": "With 10 runs the 95% bound is about 0.39; this is a smoke test only."}


def freeze_harness():
    """Record the harness hash. A refreeze names the freeze it supersedes, and only while no campaign was ever started."""
    previous = json.loads(FROZEN.read_text()) if FROZEN.exists() else None
    started = OUT.exists() and any(p.is_dir() or p.read_text().strip() for p in OUT.iterdir())
    if previous and started:
        sys.exit(f"{FROZEN}: a campaign has started under it, so a changed harness needs fresh campaign ids")
    FROZEN.parent.mkdir(parents=True, exist_ok=True)
    FROZEN.write_text(json.dumps({"harness": harness.harness_hash(), "frozen": now_ms(), "previous": previous}, indent=1) + "\n")


def check_frozen():
    if not FROZEN.exists() or json.loads(FROZEN.read_text())["harness"] != harness.harness_hash():
        sys.exit(f"the harness differs from {FROZEN}: null campaigns must be rerun with fresh ids after a change")


def row_kind(entry):
    """The disclosure kind a daemon call commits, by the kernel's own rule; None if it commits none."""
    cmd, r = entry["cmd"], entry["response"]
    if cmd == "eval" and r.get("code") != "BUDGET":
        return "eval" if r.get("ok") else "reject" if str(r.get("code")).startswith("E_") else "abort"
    if cmd == "check":
        return "check" if r.get("ok") else "reject"
    return "history" if cmd == "history" and r.get("ok") else None


def daemon_log(run_dir):
    """The daemon's calls; it writes its log at the first call, so a session that made none has no file."""
    path = Path(run_dir) / "daemon.log"
    return [json.loads(l) for l in open(path)] if path.exists() else []


def audit_run(run_dir, ledger, campaign, agent="A"):
    """One agent run: the daemon's calls against the ledger's rows, kind by kind and in order, and no tool call outside
    the permitted set."""
    calls = [k for k in map(row_kind, daemon_log(run_dir)) if k]
    rows = [k for (k,) in sqlite3.connect(ledger).execute(
        "SELECT kind FROM disclosures WHERE campaign = ? AND agent = ? AND kind IN ('eval', 'check', 'reject', 'abort', 'history') "
        "ORDER BY id", (campaign, agent))]
    use = session.tool_use(Path(run_dir) / "transcript.jsonl", harness.CLIENT)
    return {"daemon_calls": len(calls), "ledger_rows": len(rows), "match": calls == rows,
            **{k: use[k] for k in ("tools", "outside_permitted", "denials")}}


def cross_agent_history(run_dirs):
    """Whether any agent received history containing another agent's evaluations."""
    for d in run_dirs:
        for line in open(d / "daemon.log"):
            e = json.loads(line)
            if e["cmd"] == "history" and any(r.get("agent") != d.name for r in e["response"].get("evaluations", [])):
                return True
    return False


def screened(market, ledger, campaign, agent=None):
    """The search decision, then the mechanism check: (report, mechanism results, kept finalists)."""
    finalists, report = gate.search_decision(ledger, campaign, agent)
    programs = gate.programs(ledger, campaign, finalists, agent)
    mech = gate.mechanism_check(market, ledger, campaign, programs)
    return report, mech, {h: p for h, p in programs.items() if mech[h]["pass"]}


def null_market(cid, cost_cells):
    return markets.write(OUT / cid / "m", markets.generate("N2", markets.null_params()["N2"], cid, sweep.DAYS), sweep.HOLDOUT_DAYS, cost_cells)


def agent_null(cid, cost_cells):
    """Arm A on a null market. A session that made no daemon call counts as a promotion, as a crash does (C3.2)."""
    market = null_market(cid, cost_cells)
    ledger = OUT / cid / "ledger.sqlite"
    run = harness.run_agent(market, ledger, cid, OUT / cid / "run")
    report, mech, kept = screened(market, ledger, cid, "A")
    gate.freeze(ledger, cid, kept, "frozen finalist A")
    promoted, holdout = gate.holdout_decision(market, ledger, cid, kept, REPORT_FROM_DAY["agent"] * DAY)
    return {"agent_run": run, "search": report, "mechanism": mech, "kept": list(kept), "holdout": holdout,
            "bankrupt": gate.bankrupt(ledger),
            "promoted": promoted, "audit": audit_run(OUT / cid / "run", ledger, cid),
            "counts_as_promotion": bool(promoted) or not (OUT / cid / "run" / "daemon.log").exists()}


def swarm_null(cid, cost_cells):
    market = null_market(cid, cost_cells)
    ledger = OUT / cid / "ledger.sqlite"
    swarm = harness.run_swarm(market, ledger, cid, OUT / cid / "swarm")
    report, mech, kept = screened(market, ledger, cid)
    gate.freeze(ledger, cid, kept, "frozen finalist swarm")
    promoted, holdout = gate.holdout_decision(market, ledger, cid, kept, REPORT_FROM_DAY["swarm"] * DAY)
    run_dirs = [OUT / cid / "swarm" / r["agent"] for r in swarm["runs"]]
    return {"runs": swarm["runs"], "evaluations": swarm["evaluations"], "search": report, "mechanism": mech,
            "kept": list(kept), "holdout": holdout, "promoted": promoted, "cross_agent_history": cross_agent_history(run_dirs),
            "bankrupt": gate.bankrupt(ledger),
            "audits": {d.name: audit_run(d, ledger, cid, d.name) for d in run_dirs},
            "counts_as_promotion": bool(promoted) or swarm["evaluations"] < MIN_SWARM_EVALUATIONS}


SERIES = {"agent": agent_null, "swarm": swarm_null}
STAGE = {"agent": 3, "swarm": 4}


def windows(token=None):
    """The usage windows of the subscription behind `token` (default: the environment's), {name: [utilization,
    resets_at]}, from one tiny model call; None if it fails."""
    env = os.environ | ({"CLAUDE_CODE_OAUTH_TOKEN": token} if token else {})
    try:
        out = subprocess.run([session.claude_binary(), "-p", "Reply with OK.", "--model", harness.MODEL, "--output-format",
                              "stream-json", "--verbose"], capture_output=True, text=True, timeout=300, env=env).stdout
    except subprocess.TimeoutExpired:
        return None
    for line in out.splitlines():
        if '"rate_limit_event"' in line:
            found = json.loads(line)["rate_limit_info"].get("unifiedWindows")
            return found and {k: [w["utilization"], w["resetsAt"]] for k, w in found.items()}
    return None


def need(log, account):
    """Per window, the most any campaign `account` ran in `log` used of it within one reset period. It counts the
    account's other use meanwhile, so it overstates."""
    used = {}
    for row in map(json.loads, open(log)) if log.exists() else []:
        if row.get("account", "Cornell") != account:
            continue
        w = row.get("windows", {})
        for k, (u, reset) in (w.get("after") or {}).items():
            before = (w.get("before") or {}).get(k)
            if before and before[1] == reset:
                used[k] = max(used.get(k, 0.0), u - before[0])
    return used


def wait_for_room(log):
    """Wait until some account, TAMU first, has every window's utilization plus its `need` (FIRST_NEED where unmeasured)
    within CEILING, so no campaign exhausts a subscription mid-run. Set `CLAUDE_CODE_OAUTH_TOKEN`, the one sessions use, to that account's
    token and return (account, windows last read); None once STOP is set."""
    while not STOP.is_set():
        resets = []
        for account, var in ACCOUNTS:
            if var not in os.environ:
                continue
            w = windows(os.environ[var])
            if w is None:
                resets.append(time.time() + session.RETRY)
                continue
            used = need(log, account)
            full = [reset for k, (u, reset) in w.items() if u + used.get(k, FIRST_NEED) > CEILING]
            if not full:
                os.environ["CLAUDE_CODE_OAUTH_TOKEN"] = os.environ[var]
                return account, w
            resets.append(min(full))
        STOP.wait(max(60, min(resets, default=time.time() + session.RETRY) - time.time()))
    return None


def usage(work):
    """Tokens and cost summed over the result lines of every transcript under `work`."""
    total = dict.fromkeys(TOKENS, 0) | {"cost_usd": 0.0}
    for t in sorted(Path(work).rglob("transcript.jsonl")):
        for line in open(t):
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            if d.get("type") == "result":
                total = {k: total[k] + d.get("usage", {}).get(k, 0) for k in TOKENS} | {"cost_usd": total["cost_usd"] + d.get("total_cost_usd", 0.0)}
    return total


def run_series(name, n):
    """Campaigns `{name}-null-N2-0` .. n - 1, resumable (a started, unrecorded id is recorded as a crash), each started
    when the subscription has room for it (`wait_for_room`) and the harness is still the frozen one, and recorded with
    its account, usage and the windows around it. SIGTERM ends the series between campaigns."""
    signal.signal(signal.SIGTERM, lambda *_: STOP.set())
    OUT.mkdir(parents=True, exist_ok=True)
    log = OUT / f"{name}-null.jsonl"
    with campaign.resume([f"{name}-null-N2-{i}" for i in range(n)], log, OUT) as todo:
        for cid in todo:
            room = wait_for_room(log)
            if room is None:
                break
            account, before = room
            check_frozen()
            started = time.time()
            try:
                result = SERIES[name](cid, sweep.cost_cells())
            except Exception as e:
                result = {"crash": repr(e), "counts_as_promotion": True}
            result |= {"seconds": round(time.time() - started), "usage": usage(OUT / cid), "account": account,
                       "windows": {"before": before, "after": windows()}}
            with open(log, "a") as fh:
                fh.write(json.dumps({"id": cid, **result}) + "\n")


def write_json(path, value):
    """`path` holds the whole of `value` or is untouched, whenever the process dies."""
    tmp = path.with_name(path.name + ".tmp")
    with open(tmp, "w") as fh:
        json.dump(value, fh, indent=1)
        fh.write("\n")
        fh.flush()
        os.fsync(fh.fileno())
    tmp.replace(path)


def sha256(path):
    with open(path, "rb") as fh:
        return hashlib.file_digest(fh, "sha256").hexdigest()


def claims(holdout):
    path = Path(holdout) / "spent.jsonl"
    return [json.loads(l) for l in open(path)] if path.exists() else []


def inputs(root):
    """sha256 of every input of the campaign: the store, the holdout's data, the venue and the kernel. Hashes bytes only."""
    trees = {"store": root / "store", "holdout": root / "holdout", "venue": VENUE}
    found = {f"{name}/{p.relative_to(tree)}": sha256(p) for name, tree in trees.items() for p in sorted(tree.rglob("*"))
             if p.is_file() and p.name != "spent.jsonl"}
    return found | {"mm": sha256(MM)}


def check_ready(work, data_root, report_from):
    """Everything that would make the release invalid and can be known without it: C3.2 recorded and passed, the frozen
    harness and searcher, the writable paths, no overlapping claim, the holdout as C0.9 recorded it, and the inputs as
    this campaign first recorded them. Any failure stops here, with the holdout unspent."""
    check_frozen()
    sweep.require_frozen_searcher()
    null = json.loads(NULL_SUMMARY.read_text()) if NULL_SUMMARY.exists() else {}
    if null.get("n") != 20 or null.get("counted_promotions", 3) > 2:
        sys.exit(f"{NULL_SUMMARY}: C3.2 is not recorded as passed")
    root = Path(data_root)
    work.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=work), open(root / "holdout" / "spent.jsonl", "a"):
        pass
    end = json.loads((root / "store" / "policy.json").read_text())["w_end"]
    if taken := [c for c in claims(root / "holdout") if c["campaign"] != work.name and c["start"] < end and c["end"] > report_from]:
        sys.exit(f"the holdout window is already claimed: {taken}")
    found = inputs(root)
    if wrong := [e["path"] for e in json.loads(HOLDOUT_RECORD.read_text()) if found.get(e["path"]) != e["sha256"]]:
        sys.exit(f"the holdout differs from {HOLDOUT_RECORD}: {wrong}")
    recorded = work / "inputs.json"
    if not recorded.exists():
        write_json(recorded, found)
    elif json.loads(recorded.read_text()) != found:
        sys.exit(f"the inputs differ from {recorded}")


def evaluations(ledger, campaign, agent):
    """The `mm eval` lines committed for `agent`. A free check's rejection names a path, an evaluation's does not."""
    return sqlite3.connect(ledger).execute(
        "SELECT COUNT(*) FROM disclosures WHERE campaign = ? AND agent = ? AND (kind IN ('eval', 'abort') "
        "OR (kind = 'reject' AND json_extract(content, '$.path') IS NULL))", (campaign, agent)).fetchone()[0]


def run_record(run_dir, ledger, campaign):
    """Arm A's run record; a session that died before writing it gets one here, also in the ledger (C3.3)."""
    path = run_dir / "run.json"
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    transcript = run_dir / "transcript.jsonl"
    run = {"campaign": campaign, "agent": "A", "crashed": True, "harness": harness.harness_hash(),
           "transcript_sha256": sha256(transcript) if transcript.exists() else None}
    write_json(path, run)
    subprocess.run(command("disclose", path, campaign, "A", ledger, None, "--kind", "run"), check=True, capture_output=True)
    return run


def both_arms(work, data_root, version, report_from, voids):
    """Everything before the release, ending in the frozen finalists and `pre-release.json`. An arm runs only if it never
    started: one that started and has no record ended there (One attempt), and every later step can simply run again."""
    cid = work.name
    check_ready(work, data_root, report_from)
    market, ledger, run_dir = work / "m", work / "ledger.sqlite", work / "run"
    market.mkdir(exist_ok=True)
    for name, target in [("store", Path(data_root) / "store"), ("holdout", Path(data_root) / "holdout"), ("venue", VENUE)]:
        if not (market / name).is_symlink():
            (market / name).symlink_to(Path(target).resolve())
    (market / "version").write_text(f"{int(version)}\n")
    if not run_dir.exists():
        account, before = wait_for_room(OUT / "agent-null.jsonl")
        check_ready(work, data_root, report_from)
        write_json(work / "account.json", {"account": account, "windows": before})
        harness.run_agent(market, ledger, cid, run_dir)
    run = run_record(run_dir, ledger, cid)
    spent_a = max(evaluations(ledger, cid, "A"), sum(e["cmd"] == "eval" for e in daemon_log(run_dir)))
    if spent_a == 0:
        write_json(work / "void.json", {"id": cid, "agent_run": run})
        sys.exit(f"{cid}: void, arm A made no evaluation (audit/criteria.md, One attempt); nothing claimed, a new attempt takes a fresh id")
    audit = audit_run(run_dir, ledger, cid)
    if not audit["match"] or audit["outside_permitted"]:
        sys.exit(f"{cid}: arm A fails C3.1's audit, the holdout stays unspent and the case goes to the human: {audit}")
    report_a, mech, kept_a = screened(market, ledger, cid, "A")
    if not (work / "b-started").exists():
        (work / "b-started").touch()
        search.run("G100", market, ledger, cid, markets.seed(cid))
    finalists_b, report_b = gate.search_decision(ledger, cid, "G100")
    kept_b = gate.programs(ledger, cid, finalists_b, "G100")
    gate.freeze(ledger, cid, kept_a, "frozen finalist A")
    gate.freeze(ledger, cid, kept_b, "frozen finalist B")
    write_json(work / "pre-release.json", {
        "id": cid, "version": int(version), "label": LABEL, "qualifications": "PROGRESS.md, Qualifications, stage 3",
        "report_from": report_from, "void_attempts": voids, **json.loads((work / "account.json").read_text()),
        "agent_run": run, "audit": audit, "usage": usage(work), "inputs": json.loads((work / "inputs.json").read_text()),
        "A": {"evaluations": spent_a, "search": report_a, "mechanism": mech, "kept": kept_a},
        "B": {"evaluations": evaluations(ledger, cid, "G100"), "search": report_b, "kept": kept_b}})


def commit_promotions(ledger, campaign, decisions):
    """The promotion decisions as one ledger disclosure, once; a later report must reach the same ones."""
    row = sqlite3.connect(ledger).execute("SELECT content FROM disclosures WHERE campaign = ? AND kind = 'promotion'",
                                          (campaign,)).fetchone()
    if row is None:
        with tempfile.NamedTemporaryFile("w", suffix=".json") as fh:
            json.dump(decisions, fh)
            fh.flush()
            subprocess.run(command("disclose", fh.name, campaign, "gate", ledger, None, "--kind", "promotion"),
                           check=True, capture_output=True)
    elif json.loads(row[0]) != decisions:
        sys.exit(f"{campaign}: the committed promotions differ from the ledger's results")


def report(work):
    """`work/real.json` from `pre-release.json` and the ledger alone, on the normal and the recovery path alike: promotions
    by finalist identity (a finalist without a result counts as `gate.ABSENT`), committed, and only then the diagnostics."""
    pre = json.loads((work / "pre-release.json").read_text())
    cid, ledger = pre["id"], work / "ledger.sqlite"
    results = gate.committed_holdout(ledger, cid)
    decisions = {}
    for arm in ("A", "B"):
        promoted, stats = gate.promote({h: results.get(h, gate.ABSENT) for h in pre[arm]["kept"]})
        decisions[arm] = {"promoted": promoted, **stats}
    commit_promotions(ledger, cid, decisions)
    diagnostics = gate.committed_diagnostics(ledger, cid)
    finalists = {h for arm in ("A", "B") for h in pre[arm]["kept"]}
    aborts = sqlite3.connect(ledger).execute("SELECT content FROM disclosures WHERE campaign = ? AND agent = 'gate' AND kind = 'abort'",
                                             (cid,)).fetchall()
    result = pre | {"released": bool(finalists), "batch": {"missing": sorted(finalists - set(results)), "aborts": [a for (a,) in aborts]},
                    "bankrupt": gate.bankrupt(ledger),
                    "holdout_mechanism": "the reporting step after this report (audit/criteria.md, Mechanism check)" if pre["A"]["kept"] else None}
    for arm in ("A", "B"):
        promoted, stats = decisions[arm]["promoted"], {k: v for k, v in decisions[arm].items() if k != "promoted"}
        kept = list(pre[arm]["kept"])
        result[arm] = pre[arm] | {"kept": kept, "promoted": promoted,
                                  "holdout": stats | {"diagnostics": {h: diagnostics.get(h) for h in kept}}}
    result["comparison"] = comparison(result, ledger)
    write_json(work / "real.json", result)
    return result


def real(data_root, version, report_from=REAL_REPORT_FROM):
    """The one real campaign: both arms, one holdout batch with Holm within each arm, its report. Running it again resumes
    the same attempt and never repeats an arm or the release; only a void attempt moves on to a fresh id."""
    OUT.mkdir(parents=True, exist_ok=True)
    with campaign.exclusive(OUT / "agent-null.jsonl"):
        voids, n = [], 1
        while (OUT / (cid := "stage3-real" if n == 1 else f"stage3-real-{n}") / "void.json").exists():
            voids.append(cid)
            n += 1
        work = OUT / cid
        if not (work / "pre-release.json").exists():
            both_arms(work, data_root, version, report_from, voids)
        pre = json.loads((work / "pre-release.json").read_text())
        programs = {**pre["A"]["kept"], **pre["B"]["kept"]}
        holdout = work / "m" / "holdout"
        if programs and not any(c["campaign"] == cid for c in claims(holdout)):
            check_ready(work, data_root, report_from)
            out = gate.release(work / "m", work / "ledger.sqlite", cid, programs, report_from)
            if not any(c["campaign"] == cid for c in claims(holdout)):
                sys.exit(f"{cid}: the batch stopped before its claim, the holdout is unspent: {out.stdout}{out.stderr}")
        if missing := report(work)["batch"]["missing"]:
            sys.exit(f"{cid}: the batch is incomplete, {len(missing)} finalists have no result; see real.json")


def comparison(result, ledger):
    """Per arm: evaluations, distinct canonical strategies, N, SPA p-value, screened count, finalists,
    mechanism failures, each finalist's holdout return, bootstrap and Holm p-values, and promotions."""
    db = sqlite3.connect(ledger)
    out = {}
    for arm, agent in (("A", "A"), ("B", "G100")):
        r = result[arm]
        distinct = db.execute("SELECT COUNT(DISTINCT equivalence) FROM experiments WHERE campaign = ? AND agent = ?",
                              (result["id"], agent)).fetchone()[0]
        h = r["holdout"]
        out[arm] = {"evaluations": r["evaluations"], "distinct_canonical": distinct, "N": r["search"]["n"],
                    "spa_p": r["search"]["spa_p"], "screened": len(r["search"]["screened"]), "finalists": r["search"]["finalists"],
                    "mechanism_failures": [k for k, m in r.get("mechanism", {}).items() if not m["pass"]],
                    "holdout": {k: {"return": h["holdout_total_return"][k], "p": h["holdout_p"][k], "holm": h["holm"][k]}
                                for k in h.get("holm", {})},
                    "promotions": r["promoted"]}
    out["statement"] = NO_CLAIM
    return out


def spread(xs):
    xs = sorted(x for x in xs if x is not None)
    return {"n": len(xs), "min": xs[0], "median": xs[len(xs) // 2], "max": xs[-1]} if xs else None


def spreads(rows):
    s = [r["search"] for r in rows if "search" in r]
    return {"spa_p": spread([x["spa_p"] for x in s]), "max_dsr": spread([x.get("max_dsr") for x in s]),
            "screened": spread([len(x["screened"]) for x in s])}


BASELINE = {"agent": "G100", "swarm": "H400"}


def summary(name, out):
    """A null series (`agent` or `swarm`): campaigns, counted promotions, evaluations and history use,
    and the spreads of SPA p-values, maximum DSR and screened counts beside its baseline searcher's
    complete-null N2 runs."""
    searcher = BASELINE[name]
    log = OUT / f"{name}-null.jsonl"
    rows = [json.loads(l) for l in open(log)] if log.exists() else []
    baseline = [r for r in sweep.results("null") if r["id"].startswith(f"c24{sweep.ROUND}-N2-{searcher}-")]
    report = {"n": len(rows), "counted_promotions": sum(r["counts_as_promotion"] for r in rows),
              "evaluations": [r.get("evaluations", r.get("agent_run", {}).get("spent")) for r in rows],
              "cross_agent_history": [r.get("cross_agent_history") for r in rows],
              "spreads": spreads(rows), f"{searcher}_null_n2": spreads(baseline), "statement": SMOKE[name],
              "qualifications": f"PROGRESS.md, Qualifications, stage {STAGE[name]}"} | ({"label": LABEL} if name == "agent" else {})
    Path(out).write_text(json.dumps(report, indent=1) + "\n")
