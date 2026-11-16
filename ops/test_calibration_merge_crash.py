"""Completed share trials must survive interrupted publication into the merged log."""

import json
import multiprocessing
import os
import signal
from pathlib import Path

import pytest

from gate.control import calibrate
from ops import jobs


def trial_line(market: str, earns: bool) -> bytes:
    return (json.dumps({"strength": calibrate.HI, "market": market, "result": {"earns": earns}}) + "\n").encode()


@pytest.mark.xfail(strict=True, reason="hunt finding 7: calibration merges are not crash-safe")
def test_kill_after_share_rename_does_not_lose_its_completed_trial(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    market = calibrate.cal_a_ids()[0]
    merged = tmp_path / "calibration.jsonl"
    merged.write_bytes(b"")
    share = tmp_path / "share-0.jsonl"
    share.write_bytes(trial_line(market, True))
    rename = Path.rename

    def rename_then_die(path: Path, target: str | Path) -> Path:
        renamed = rename(path, target)
        if path == share:
            os.kill(os.getpid(), signal.SIGKILL)
        return renamed

    monkeypatch.setattr(Path, "rename", rename_then_die)
    process = multiprocessing.get_context("fork").Process(target=jobs.merge_shares, args=(tmp_path, "r0"))
    process.start()
    try:
        process.join(10)
        assert process.exitcode == -signal.SIGKILL
    finally:
        if process.is_alive():
            process.kill()
            process.join(10)
    monkeypatch.setattr(Path, "rename", rename)
    assert (tmp_path / "share-0.r0.jsonl").read_bytes() == trial_line(market, True)

    jobs.merge_shares(tmp_path, "r1")
    assert (calibrate.HI, market) in calibrate.parse([merged])


@pytest.mark.xfail(strict=True, reason="hunt finding 7: calibration merges are not crash-safe")
def test_retry_after_torn_merged_append_does_not_hide_all_new_trials(tmp_path: Path) -> None:
    first, second = calibrate.cal_a_ids()[:2]
    merged = tmp_path / "calibration.jsonl"
    merged.write_bytes(trial_line(first, False) + b'{"strength": 0.01, "market": "cut')
    (tmp_path / "share-0.jsonl").write_bytes(trial_line(second, True))

    jobs.merge_shares(tmp_path, "r1")
    known = calibrate.parse([merged])
    assert set(known) == {(calibrate.HI, first), (calibrate.HI, second)}
