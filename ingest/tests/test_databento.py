"""Databento pulls: monthly windows from the plan's start, each request priced before it is made, the spend cap, and
resuming from the manifest."""

import datetime as dt
import json

import httpx
import pytest

from ingest import databento

PLAN = {"dataset": "GLBX.MDP3", "roots": ["CL", "GC"], "start": "2010-06-06", "spend_cap_usd": 1.0,
        "pulls": [{"name": "d", "schema": "definition", "stype_in": "parent", "window": "monthly"}]}


def test_windows_start_at_the_plan_start_then_each_month():
    assert [d.isoformat() for d in databento.months("2010-06-06", dt.date(2010, 9, 1))] == \
        ["2010-06-06", "2010-07-01", "2010-08-01", "2010-09-01"]
    qs = list(databento.requests(PLAN, PLAN["pulls"][0], dt.date(2011, 1, 15)))
    assert (qs[0]["symbols"], qs[0]["start"], qs[0]["end"]) == ("CL.FUT,GC.FUT", "2010-06-06", "2010-06-07")
    assert (qs[-1]["start"], qs[-1]["end"]) == ("2011-01-02", "2011-01-03"), "a Saturday's snapshot moves to the Sunday"


def test_a_pull_by_raw_symbol_takes_each_whole_month_for_its_snapshot_outrights():
    pull = {"name": "s", "schema": "statistics", "stype_in": "raw_symbol"}
    qs = list(databento.requests(PLAN, pull, dt.date(2010, 8, 1), {"2010-06": ["CLN0", "GCQ0"], "2010-07": ["CLQ0"]}))
    assert [(q["symbols"], q["start"], q["end"]) for q in qs] == \
        [("CLN0,GCQ0", "2010-06-06", "2010-07-01"), ("CLQ0", "2010-07-01", "2010-08-01")]


def server(cost, calls):
    def handle(req):
        calls.append(req.url.path)
        if req.url.path.endswith("metadata.get_cost"):
            return httpx.Response(200, json=cost)
        return httpx.Response(200, content=b"dbn" + req.content[-8:])
    return httpx.Client(transport=httpx.MockTransport(handle), base_url=databento.API)


def test_each_request_is_priced_first_and_the_cap_stops_the_pull(tmp_path):
    plan = tmp_path / "plan.json"
    plan.write_text(json.dumps(PLAN))
    calls = []
    with pytest.raises(SystemExit, match="over the cap"):
        databento.pull("d", tmp_path / "out", server(0.4, calls), plan, dt.date(2010, 9, 15))
    assert calls == ["/v0/metadata.get_cost", "/v0/timeseries.get_range"] * 2 + ["/v0/metadata.get_cost"]
    rows = [json.loads(l) for l in open(tmp_path / "out" / "manifest.jsonl")]
    assert [r["request"]["start"] for r in rows] == ["2010-06-06", "2010-07-01"] and sum(r["cost_usd"] for r in rows) == 0.8
    assert all((tmp_path / "out" / "raw" / f"{r['sha256']}.dbn.zst").exists() for r in rows)


def test_a_pull_resumes_from_its_manifest(tmp_path):
    plan = tmp_path / "plan.json"
    plan.write_text(json.dumps(PLAN | {"spend_cap_usd": 10.0}))
    databento.pull("d", tmp_path / "out", server(0.1, []), plan, dt.date(2010, 7, 15))
    calls = []
    databento.pull("d", tmp_path / "out", server(0.1, calls), plan, dt.date(2010, 8, 15))
    assert calls == ["/v0/metadata.get_cost", "/v0/timeseries.get_range"]
    assert len(open(tmp_path / "out" / "manifest.jsonl").readlines()) == 3


def test_a_server_error_is_retried(monkeypatch):
    monkeypatch.setattr(databento.time, "sleep", lambda s: None)
    replies = iter([httpx.Response(504), httpx.Response(200, json=0.5)])
    http = httpx.Client(transport=httpx.MockTransport(lambda req: next(replies)), base_url=databento.API)
    assert databento.send(http, "metadata.get_cost", {}).json() == 0.5
