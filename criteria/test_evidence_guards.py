import copy

import pytest

from criteria import test_stages3to5 as stages
from gate.agent import campaigns


@pytest.mark.parametrize("defect", ["mismatch", "outside", "missing_agent", "missing_campaign", "no_audit"])
def test_swarm_evidence_rejects_failed_or_missing_audits(monkeypatch, defect):
    ids = campaigns.cohort("swarm")[0]
    good = {"match": True, "outside_permitted": []}
    summary = {"n": 10, "counted_promotions": 0, "statement": campaigns.SMOKE["swarm"],
               "cross_agent_history": [True] * 10, "evaluations": [300] * 10,
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
    else:
        audits["A4"] = None
    with pytest.raises(AssertionError):
        stages.test_c45_swarm_smoke()
