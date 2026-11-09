import copy
from typing import Any

import pytest

from criteria import test_stages3to5 as stages
from gate.agent import campaigns


@pytest.mark.parametrize(
    "defect",
    [
        "mismatch",
        "outside",
        "missing_agent",
        "missing_campaign",
        "no_audit",
        "agent_over_budget",
        "missing_budget",
        "evidence_fails",
        "crashed_after_data",
        "missing_evidence",
        "two_unresolved_called_pass",
        "all_not_established_called_pass",
        "unknown_class",
        "no_trials",
        "one_active_agent",
        "no_history",
        "one_campaign_short",
        "hidden_unresolved",
    ],
)
def test_swarm_evidence_rejects_a_summary_v3_does_not_support(monkeypatch: pytest.MonkeyPatch, defect: str) -> None:
    ids = campaigns.cohort("swarm")[0]
    good = {"match": True, "outside_permitted": []}
    names = [f"A{i + 1}" for i in range(4)]
    summary: dict[str, Any] = {
        "n": 10,
        "ids": ids,
        "classes": dict.fromkeys(ids, "established"),
        "verdict": "pass",
        "statement": campaigns.SMOKE["swarm"],
        "trials": dict.fromkeys(ids, 3),
        "history": dict.fromkeys(ids, True),
        "evidence": {c: {a: {"holds": True, "received": True, "crashed": False} for a in names} for c in ids},
        "evaluations_by_agent": {c: dict.fromkeys(names, 100) for c in ids},
        "audits": {c: {a: copy.deepcopy(good) for a in names} for c in ids},
    }
    monkeypatch.setattr(stages, "load", lambda _: summary)
    stages.test_c45_swarm_smoke()
    last = ids[-1]
    audits, evidence, evaluations = (
        summary["audits"][last],
        summary["evidence"][last],
        summary["evaluations_by_agent"][last],
    )
    if defect == "mismatch":
        audits["A4"]["match"] = False
    elif defect == "outside":
        audits["A4"]["outside_permitted"] = ["WebFetch"]
    elif defect == "missing_agent":
        del audits["A4"]
    elif defect == "missing_campaign":
        del summary["audits"][last]
    elif defect == "no_audit":
        audits["A4"] = None
    elif defect == "agent_over_budget":
        evaluations["A4"] = 101
    elif defect == "missing_budget":
        del evaluations["A4"]
    elif defect == "evidence_fails":
        evidence["A4"]["holds"] = False
    elif defect == "crashed_after_data":
        evidence["A4"]["crashed"] = True
    elif defect == "missing_evidence":
        del evidence["A4"]
    elif defect == "two_unresolved_called_pass":
        summary["classes"][ids[0]] = summary["classes"][ids[1]] = "unresolved"
    elif defect == "all_not_established_called_pass":
        summary["classes"] = dict.fromkeys(ids, "not established")
    elif defect == "unknown_class":
        summary["classes"] = dict.fromkeys(ids, "fine")
    elif defect == "no_trials":
        summary["trials"][last] = 0
    elif defect == "one_active_agent":
        summary["evaluations_by_agent"][last] = {"A1": 5, "A2": 0, "A3": 0, "A4": 0}
    elif defect == "hidden_unresolved":
        summary["classes"][last] = "not established"
        evidence["A4"]["holds"] = False
    elif defect == "no_history":
        summary["history"][last] = False
    else:
        del summary["classes"][last]
    with pytest.raises(AssertionError):
        stages.test_c45_swarm_smoke()
