"""SIGKILL checks from campaign.resume/run_series docstrings and C3.2/C4.5's no-free-retry rule."""

import json
import random
from pathlib import Path

import pytest

from gate import campaign
from gate.agent import campaigns
from ingest.tests.crash_helpers import acknowledge, checkpoint, kill_during, recover

MODULE = __name__
IDS = [f"crash-swarm-N2-{i}" for i in range(5)]


def result(cid):
    return {"id": cid, "counts_as_promotion": False, "proof": "é🦉" * 200_000}


def worker(root, interactive):
    root = Path(root)
    mode = (root / "mode").read_text()

    def swarm(cid, inputs):
        with (root / "invocations.jsonl").open("a") as stream:
            stream.write(json.dumps(cid) + "\n")
        checkpoint(f"campaign:{cid}", interactive)
        acknowledge(cid)
        return result(cid)

    if mode == "resume":
        checkpoint("start", interactive)
        with campaign.resume(IDS, root / "series.jsonl", root) as todo:
            for cid in todo:
                (root / cid).mkdir()
                row = swarm(cid, {})
                with (root / "series.jsonl").open("a") as stream:
                    stream.write(json.dumps(row) + "\n")
    else:
        campaigns.OUT = root
        campaigns.COHORTS["swarm"] = ("crash-swarm", len(IDS))
        campaigns.SERIES["swarm"] = swarm
        campaigns.series_inputs = lambda: {"mm": "synthetic-kernel"}
        campaigns.ready = lambda log: ("synthetic-account", {})
        campaigns.check_frozen = lambda mm: None
        campaigns.windows = lambda token=None: {}
        campaigns.usage = lambda work: {}
        checkpoint("start", interactive)
        campaigns.run_series("swarm")
    checkpoint("finished", interactive)


@pytest.mark.parametrize("mode", ["resume", "series"])
@pytest.mark.parametrize("cut", ["start", "campaign"])
@pytest.mark.parametrize("seed", [7, 29, 101, 307])
def test_random_sigkill_keeps_every_started_campaign_once_and_releases_the_lock(tmp_path, mode, cut, seed):
    (tmp_path / "mode").write_text(mode)
    target = random.Random(seed).choice(IDS[1:-1])
    kill_during(MODULE, tmp_path, "start" if cut == "start" else f"campaign:{target}", seed)
    log = tmp_path / ("series.jsonl" if mode == "resume" else "crash-swarm.jsonl")
    original = log.read_bytes() if log.exists() else b""
    before = campaign.records(log) if log.exists() else []
    started = {cid for cid in IDS if (tmp_path / cid).exists()}
    unrecorded = started - {row["id"] for row in before}
    calls = tmp_path / "invocations.jsonl"
    invoked = [json.loads(line) for line in calls.read_text().splitlines()] if calls.exists() else []
    expected_calls = invoked + [cid for cid in IDS if cid not in started]
    recover(MODULE, tmp_path)
    rows = campaign.records(log)
    assert log.read_bytes().startswith(original)
    assert rows[:len(before)] == before
    assert [row["id"] for row in rows] == IDS
    for row in rows:
        if row["id"] in unrecorded:
            assert row["counts_as_promotion"] and "interrupted" in row["crash"]
        else:
            assert not row["counts_as_promotion"] and row["proof"] == result(row["id"])["proof"]
    invocations = [json.loads(line) for line in calls.read_text().splitlines()]
    assert invocations == expected_calls
    assert len(invocations) == len(set(invocations))
    complete = log.read_bytes()
    recover(MODULE, tmp_path)
    assert log.read_bytes() == complete
    assert [json.loads(line) for line in calls.read_text().splitlines()] == expected_calls
