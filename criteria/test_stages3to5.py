"""Stage 3 to 5 criteria (audit/criteria.md) on the committed evidence. C3.1, C4.1 to C4.3 and C5.2 and C5.5
are tests of the code (gate/tests, kernel/mm/tests, ingest/tests); the agent audits are per campaign."""

import json
from pathlib import Path

import pytest

from criteria.evidence import REPO, load
from criteria.test_stage2 import P_MIN, Z_MAX
from gate.agent import campaigns


def test_c32_smoke_calibration() -> None:
    """C3.2 v3, judged on its declared campaigns alone."""
    s = load("stage3/null-summary.json")
    assert sorted(s["ids"]) == sorted(campaigns.cohort("agent")[0])
    assert s["counted_promotions"] <= 2 and s["statement"] == campaigns.SMOKE["agent"]


def test_c31_every_null_run_passes_its_audit() -> None:
    s = load("stage3/null-summary.json")
    assert sorted(s["audits"]) == sorted(campaigns.cohort("agent")[0]) and all(
        map(campaigns.audit_holds, s["audits"].values())
    )


@pytest.mark.xfail(
    strict=True,
    raises=AssertionError,
    reason="C3.2 v1 failed: its 20 campaigns crashed before any model call, each a promotion "
    "(audit/stage3/null-v1.jsonl, null-summary-v1.json)",
)
def test_c32_v1_smoke_calibration() -> None:
    s = load("stage3/null-summary-v1.json")
    assert s["n"] == 20 and s["counted_promotions"] <= 2


def test_c34_report_states_no_claim() -> None:
    r = load("stage3/real.json")
    assert r["comparison"]["statement"] == campaigns.NO_CLAIM
    assert campaigns.audit_holds(r["audit"])


def test_c45_swarm_smoke() -> None:
    s = load("stage4/null-summary.json")
    ids, classes = campaigns.cohort("swarm")[0], s["classes"]
    assert s["n"] == 10 and s["ids"] == ids and list(classes) == ids
    assert (
        s["verdict"] == campaigns.swarm_verdict(list(classes.values())) == "pass"
        and s["statement"] == campaigns.SMOKE["swarm"]
    )
    agents = {f"A{i + 1}" for i in range(campaigns.SWARM_AGENTS)}
    for cid in ids:
        if classes[cid] in ("established", "not established"):
            evidence, audits, evaluations = (
                s["evidence"][cid],
                s["audits"].get(cid) or {},
                s["evaluations_by_agent"][cid],
            )
            assert set(evidence) == set(audits) == set(evaluations) == agents
            assert all(e["holds"] and not (e["crashed"] and e["received"]) for e in evidence.values())
            assert all(a is not None and campaigns.audit_holds(a) for a in audits.values())
            assert sum(evaluations.values()) <= 400 and max(evaluations.values()) <= 100
        if classes[cid] == "established":
            assert (
                s["history"][cid]
                and s["trials"][cid] >= 1
                and sum(map(bool, s["evaluations_by_agent"][cid].values())) >= 2
            )


@pytest.mark.xfail(
    strict=True,
    raises=AssertionError,
    reason="C4.5 v1 failed: its first 2 campaigns made 33 and 36 evaluations, under 200, each a promotion; "
    "the series stopped with 8 unstarted (audit/stage4/null-v1.jsonl, null-summary-v1.json)",
)
def test_c45_v1_swarm_smoke() -> None:
    s = load("stage4/null-summary-v1.json")
    assert s["counted_promotions"] <= 1


@pytest.mark.xfail(
    strict=True,
    raises=AssertionError,
    reason="C4.5 v2 failed: 2 of 10 counted, nothing promoted where recorded, each counted campaign an agent "
    "that ran /work/mm-agent, was refused, and made no evaluation (audit/stage4/null-v2.jsonl, "
    "null-summary-v2.json)",
)
def test_c45_v2_swarm_smoke() -> None:
    s = load("stage4/null-summary-v2.json")
    assert s["counted_promotions"] <= 1


def test_c51_mapped_forums_meet_the_precision_rule() -> None:
    labels = load("stage5/c51-discourse.json")
    mapped = {r["forum"] for r in json.loads((REPO / "venue/sources/discourse_map.json").read_text())["rows"]}
    assert len(labels["labels"]) >= 50
    for forum in mapped:
        assert labels["per_key"][forum]["precision"] >= 0.8, forum


def test_c53_prospective_sources_reported() -> None:
    """Under the stage 5 amendment: each prospective source's figures are reported over at least 72 h."""
    for source in ("discourse", "snapshot"):
        files = sorted((REPO / "audit/stage5").glob(f"availability-{source}-*.json"))
        assert files and json.loads(files[-1].read_text())["hours_recorded"] >= 72, source
    assert sorted((REPO / "audit/stage5").glob("reconcile-*.json"))


def search_event_datasets(store: Path) -> list[str]:
    return sorted(p.name for p in store.iterdir() if p.name.startswith("events_"))


def test_the_c56_guard_sees_any_search_event_dataset(tmp_path: Path) -> None:
    assert search_event_datasets(tmp_path) == []
    for ds in ("events_forum", "events_governance"):
        (tmp_path / ds).mkdir()
    assert search_event_datasets(tmp_path) == ["events_forum", "events_governance"]
    with pytest.raises(FileNotFoundError):
        search_event_datasets(tmp_path / "missing")


@pytest.mark.local
def test_c56_or_no_search_event_inputs() -> None:
    """C5.6 is deferred while the search store carries no event dataset (clarification of 2026-10-22): once
    one exists, C5.6's evidence is required, and this fails without it."""
    store = REPO / "data/store"
    if not store.is_dir():
        pytest.skip("no data/store here: the search store is checked where it exists")
    if not search_event_datasets(store):
        return
    assert (REPO / "audit/stage5/c56-probes.json").exists() and (REPO / "audit/stage2/sweeps.json").exists(), (
        "an event dataset is in the search store without C5.6's evidence"
    )
    r = load("stage5/c56-probes.json")
    for model in ("N1", "N2", "N3"):
        assert min(r[model]["regression_p"]) > P_MIN and max(abs(z) for z in r[model]["z"].values()) < Z_MAX, model
    c = load("stage2/sweeps.json")["events"]["N2-G400"]
    assert c["n"] == 300 and c["promoted_upper"] <= 0.05
