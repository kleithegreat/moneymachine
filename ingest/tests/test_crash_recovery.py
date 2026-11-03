"""SIGKILL recovery contracts from live.append/read and the recorder/data-layer public docstrings.

An in-flight append may be torn, not an acknowledged one. Recovery keeps the byte history and every
complete record, skips a torn record, and appends the remaining synthetic observations exactly once.
"""

import gzip
import hashlib
import random
from pathlib import Path

import httpx
import pytest

from ingest import datalayer, live, record
from ingest.tests.crash_helpers import acknowledge, checkpoint, kill_during, recover

COUNT = 7
MODULE = __name__
SEEDS = (7, 29, 101, 307)


def observation(i):
    return {"seq": i, "sent": 0, "recv": 0, "data": "é🦉" * 200_000}


def body(i):
    return random.Random(i).randbytes(300_000)


def poll(root, i):
    with httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=body(i)))) as http:
        return datalayer.poll(http, {"name": f"feed-{i}", "url": f"https://example.invalid/{i}"}, root, {})


def worker(root, interactive):
    root = Path(root)
    mode = (root / "mode").read_text()
    if mode in ("live", "record"):
        prefix = "observations" if mode == "live" else "polls"
        done = {row["seq"] for row in live.read(root, prefix)}
        record.Info = lambda budget: None
        recorder = record.Recorder(480, [], root) if mode == "record" else None
        for i in range(COUNT):
            if i in done:
                continue
            checkpoint(f"append:{i}", interactive)
            if recorder is None:
                live.append(root, prefix, 0, observation(i))
            else:
                recorder.log(observation(i))
            acknowledge(i)
    else:
        done = {row["feed"] for row in live.read(root, "datalayer")}
        for i in range(COUNT):
            if f"feed-{i}" in done:
                continue
            checkpoint(f"append:{i}", interactive)
            poll(root, i)
            acknowledge(i)
    checkpoint("finished", interactive)


@pytest.mark.parametrize("mode", ["live", "record", "datalayer", "repair"])
@pytest.mark.parametrize("seed", SEEDS)
def test_random_sigkill_preserves_completed_appends_and_recovers(tmp_path, mode, seed):
    (tmp_path / "mode").write_text(mode)
    if mode == "repair":
        (tmp_path / "raw").mkdir()
        for i in range(COUNT):
            digest = hashlib.sha256(body(i)).hexdigest()
            (tmp_path / "raw" / f"{digest}.gz").write_bytes(gzip.compress(body(i))[:31])
    target = random.Random(seed).randrange(1, COUNT - 1)
    acks = kill_during(MODULE, tmp_path, f"append:{target}", seed)
    history = {path: path.read_bytes() for path in tmp_path.glob("*.jsonl")}
    prefix = {"live": "observations", "record": "polls"}.get(mode, "datalayer")
    before = list(live.read(tmp_path, prefix))
    indices = [row["seq"] if prefix != "datalayer" else int(row["feed"].split("-")[1]) for row in before]
    assert indices == list(range(len(indices)))
    assert set(acks) <= set(indices)
    recover(MODULE, tmp_path)
    rows = list(live.read(tmp_path, prefix))
    assert rows[:len(before)] == before
    assert all(path.read_bytes().startswith(raw) for path, raw in history.items())
    if prefix != "datalayer":
        assert rows == [observation(i) for i in range(COUNT)]
    else:
        assert [row["feed"] for row in rows] == [f"feed-{i}" for i in range(COUNT)]
        for i, row in enumerate(rows):
            assert row["sha256"] == hashlib.sha256(body(i)).hexdigest()
            assert row["bytes"] == len(body(i)) and row["status"] == 200
            assert row["sent"] <= row["recv"]
            assert datalayer.body(tmp_path, row["sha256"]) == body(i)
        if mode == "repair":
            repairs = list(live.read(tmp_path, "repairs"))
            assert {row["sha256"] for row in repairs} == {row["sha256"] for row in rows}
            for repair in repairs:
                kept = tmp_path / "raw" / repair["kept"]
                assert hashlib.sha256(kept.read_bytes()).hexdigest() == repair["damaged_sha256"]
    complete = {path: path.read_bytes() for path in tmp_path.glob("*.jsonl")}
    recover(MODULE, tmp_path)
    assert {path: path.read_bytes() for path in tmp_path.glob("*.jsonl")} == complete
