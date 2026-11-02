import copy

import pytest

from criteria import test_stages3to5 as stages
from gate.agent import campaigns


@pytest.mark.parametrize("defect", ["mismatch", "outside", "missing_agent", "missing_campaign", "no_audit",
                                  "agent_over_budget", "missing_budget", "missing_budget_campaign", "no_budgets"])
def test_swarm_evidence_rejects_failed_or_missing_audits_and_budgets(monkeypatch, defect):
    ids = campaigns.cohort("swarm")[0]
    good = {"match": True, "outside_permitted": []}
    summary = {"n": 10, "counted_promotions": 0, "statement": campaigns.SMOKE["swarm"],
               "cross_agent_history": [True] * 10, "evaluations": [400] * 10,
               "agent_evaluations": [{f"A{i + 1}": 100 for i in range(4)} for _ in ids],
               "audits": {cid: {f"A{i + 1}": copy.deepcopy(good) for i in range(4)} for cid in ids}}
    monkeypatch.setattr(stages, "load", lambda _: summary)
    stages.test_c45_swarm_smoke()
    audits = summary["audits"][ids[-1]]
    if defect == "mismatch":
        audits["A4"]["match"] = False
    elif defect == "outside":
        audits["A4"]["outside_permitted"] = ["WebFetch"]
    elif defect == "missing_agent":
        del audits["A4"]
    elif defect == "missing_campaign":
        del summary["audits"][ids[-1]]
    elif defect == "no_audit":
        audits["A4"] = None
    elif defect == "agent_over_budget":
        summary["agent_evaluations"][-1]["A4"] = 101
    elif defect == "missing_budget":
        del summary["agent_evaluations"][-1]["A4"]
    elif defect == "missing_budget_campaign":
        summary["agent_evaluations"].pop()
    else:
        summary["agent_evaluations"][-1] = None
    with pytest.raises(AssertionError):
        stages.test_c45_swarm_smoke()
