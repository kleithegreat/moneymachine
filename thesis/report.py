"""The thesis track's report (audit/criteria.md, stage 10, C10.6): what ran, what was registered and resolved,
forecast scores against every baseline with cluster-bootstrap intervals, and position performance,
for one track version. Forecast scoring and position performance are reported separately, and stage
completion is not skill evidence."""

import json
from pathlib import Path

from ingest.datalayer import body
from ingest.live import read
from ingest.policy import HOUR
from thesis import scoring

DATALAYER = Path(__file__).resolve().parents[1] / "data" / "datalayer"

NO_CLAIM = ("No skill claim is made: a claim needs at least 200 resolved main-agent clusters within one track version, "
            "and then a separately frozen inferential protocol. These scores are descriptive.")
MARKET_IMPLIED = ("Outcome-market prices (Polymarket) appear beside a thesis's probability only where the thesis names a market. "
                  "They are descriptive: a market's question rarely states the thesis's exact outcome, so no score uses them.")


def outcome_markets(theses, root=DATALAYER):
    """For each thesis naming a Polymarket market (stage 10 revision of 2026-10-23): the market's latest recorded
    prices at or before t_r and, once it has closed, its resolution, from the data layer's recordings."""
    named = {th["id"]: th["outcome_market"] for th in theses if th.get("outcome_market")}
    seen = {}
    if named:
        for poll in read(root, "datalayer"):
            if poll["feed"] in ("polymarket-active", "polymarket-resolved") and poll["status"] == 200:
                for m in json.loads(body(root, poll["sha256"])):
                    if m.get("id") in named.values():
                        seen.setdefault(m["id"], []).append((poll["recv"], m["question"], json.loads(m["outcomes"]),
                                                             json.loads(m["outcomePrices"]), bool(m.get("closed"))))
    out = {}
    for th in theses:
        if th["id"] in named:
            rows = sorted(seen.get(named[th["id"]], []))
            before, closed = [r for r in rows if r[0] <= th["t_r"]], [r for r in rows if r[4]]
            out[th["id"]] = {"market": named[th["id"]], "p": th["p"], "question": rows[-1][1] if rows else None,
                             "prices_at_t_r": dict(zip(before[-1][2], before[-1][3])) if before else None,
                             "resolution": dict(zip(closed[0][2], closed[0][3])) if closed else None}
    return out


def scoring_input(track, account, now):
    """thesis/SCORING.md input for one account, from the ledger and the market cache, as of `now`."""
    theses = track.ledger.theses(account)
    ablation = {c["thesis"]: c["p"] for _, _, c in track.ledger.records("ablation")}
    markets = sorted({m for th in theses for m, _ in th["legs"]})
    config = track.config(markets)
    return {"account": {"fee": config["fee"], "costs": config["costs"]},
            "hourly": {m: track.market.bars(m, "1h", now) for m in markets},
            "daily": {m: track.market.bars(m, "1d", now) for m in markets},
            "funding": {m: track.market.funding(m, now) for m in markets}, "now": now,
            "theses": [{"id": th["id"], "session": th["session"], "catalyst_id": th["catalyst_id"], "legs": th["legs"],
                        "t_r": th["t_r"], "T": th["T"], "N": th["N"], "p": th["p"], "p_ablation": ablation.get(th["id"])}
                       for th in theses]}, config


def account_report(track, account, now):
    test, config = scoring_input(track, account, now)
    if not test["theses"]:
        return {"theses": 0}
    result = scoring.score(test)
    replay = track.replay(account, now)
    resolved = [t for t, r in result["theses"].items() if r["outcome"] is not None]
    managed = [replay["theses"][t]["managed_return"] for t in replay["theses"] if replay["theses"][t]["managed_return"] is not None]
    sizes = [len(c["members"]) for c in result["clusters"]]
    return {
        "theses": len(test["theses"]), "size_zero": sum(th["size"] == 0 for th in track.ledger.theses(account)),
        "resolved": len(resolved), "unresolved": len(test["theses"]) - len(resolved),
        "base_rate_unavailable": sum(r["p_ref"] is None for r in result["theses"].values()),
        "ablation_missing": sum(th["p_ablation"] is None for th in test["theses"]) if account == "main" else None,
        "clusters": len(sizes), "resolved_clusters": sum(c["resolved"] for c in result["clusters"]),
        "largest_cluster_share": max(sizes) / len(test["theses"]),
        "forecast": result["scores"], "intervals": scoring.bootstrap(test, result),
        "positions": {"as_registered_mean": (sum(result["theses"][t]["outcome"]["R_net"] for t in resolved) / len(resolved)) if resolved else None,
                      "as_managed_mean": sum(managed) / len(managed) if managed else None,
                      "equity": replay["equity"][-1][1] if replay["equity"] else None},
        "cost_fallback_markets": config["fallback"],
    }


def write(track, now, out):
    calls = [c for _, _, c in track.ledger.records("call")]
    report = {
        "version": track.version, "as_of": now, "qualifications": "PROGRESS.md, Qualifications, stage 10",
        "sessions": [c for _, _, c in track.ledger.records("session_end")],
        "sessions_missed": [c for _, _, c in track.ledger.records("session_missed")],
        "registration_attempts": sum(c["request"].get("cmd") == "register" for c in calls if isinstance(c["request"], dict)),
        "rejected_registrations": sum(c["request"].get("cmd") == "register" and not c["ok"] for c in calls if isinstance(c["request"], dict)),
        "benchmark_skips": [c for _, _, c in track.ledger.records("skip", "benchmark")],
        "missing_data": [c for _, _, c in track.ledger.records("resolution") if c["status"] == "missing data"],
        "overdue": [th["id"] for a in ("main", "noread", "benchmark") for th in track.ledger.theses(a)
                    if th["T"] + 2 * HOUR <= now and not any(c["id"] == th["id"] for _, _, c in track.ledger.records("resolution"))],
        "accounts": {a: account_report(track, a, now) for a in ("main", "noread", "benchmark")},
        "outcome_markets": outcome_markets(track.ledger.theses("main")),
        "statements": [NO_CLAIM, MARKET_IMPLIED,
                       "The benchmark's Brier score is descriptive: its exposures and horizons differ from the agent's.",
                       "The conditional ablation measures probability assessment on the main agent's chosen tasks, not the value "
                       "of reading for choosing them; the full no-reading agent is scored separately."],
    }
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    Path(out).write_text(json.dumps(report, indent=1) + "\n")
