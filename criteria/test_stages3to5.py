"""Stage 3 to 5 criteria on the committed evidence (PROGRESS.md). C3.1, C4.1 to C4.3 and C5.2 and C5.5
are tests of the code (gate/tests, kernel/mm/tests, ingest/tests); the agent audits are per campaign."""

import json

from criteria.evidence import REPO, load
from criteria.test_stage2 import P_MIN, Z_MAX
from gate.agent import campaigns


def test_c32_smoke_calibration():
    s = load("stage3/null-summary.json")
    assert s["n"] == 20 and s["counted_promotions"] <= 2 and s["statement"] == campaigns.SMOKE["agent"]


def test_c34_report_states_no_claim():
    r = load("stage3/real.json")
    assert r["comparison"]["statement"] == campaigns.NO_CLAIM
    assert r["audit"]["match"] and r["audit"]["outside_permitted"] == []


def test_c45_swarm_smoke():
    s = load("stage4/null-summary.json")
    assert s["n"] == 10 and s["counted_promotions"] <= 1 and s["statement"] == campaigns.SMOKE["swarm"]
    assert all(s["cross_agent_history"]) and all(e is not None and e <= 400 for e in s["evaluations"])


def test_c51_mapped_forums_meet_the_precision_rule():
    labels = load("stage5/c51-discourse.json")
    mapped = {r["forum"] for r in json.loads((REPO / "venue/sources/discourse_map.json").read_text())["rows"]}
    assert len(labels["labels"]) >= 50
    for forum in mapped:
        assert labels["per_key"][forum]["precision"] >= 0.8, forum


def test_c53_sources_availability():
    a = load("stage5/sources-availability.json")
    assert a["new_items"] >= 30 and a["item_failures"] == [] and a["edit_failures"] == []
    assert a["clock_offset_ms"]["max_abs"] < 1000


def test_c56_probes_with_events():
    r = load("stage5/c56-probes.json")
    for model in ("N1", "N2", "N3"):
        assert min(r[model]["regression_p"]) > P_MIN and max(abs(z) for z in r[model]["z"].values()) < Z_MAX, model


def test_c56_complete_null_with_events():
    c = load("stage2/sweeps.json")["events"]["N2-G400"]
    assert c["n"] == 300 and c["promoted_upper"] <= 0.05
