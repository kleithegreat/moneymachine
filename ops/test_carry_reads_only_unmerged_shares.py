"""A run carried from another reads that run's merged log and its unmerged shares, never a share already merged.

Found by the advisor while checking the hunt's finding 7 (2026-11-16): `cal-3`'s log holds 1,600 identical copies of
`cal-2`'s strength-0.01 lines, because the carry's glob `share-*.jsonl` also matched `share-0.r0.jsonl`, a share
`merge_shares` had already appended and renamed. `parse` keys by (strength, market), so no rate changed."""

import json
from pathlib import Path

import pytest

from gate.control import calibrate
from ops import jobs


def line(market: str) -> str:
    return json.dumps({"strength": calibrate.HI, "market": market, "result": {"earns": False}}) + "\n"


@pytest.mark.local
def test_carry_skips_shares_already_merged(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    merged_id, unmerged_id = calibrate.cal_a_ids()[:2]
    results = tmp_path / "results"
    source = results / "old"
    source.mkdir(parents=True)
    (source / "record.json").write_text(json.dumps({"mm": "k"}))
    (source / "calibration.jsonl").write_text(line(merged_id))
    (source / "share-0.r0.jsonl").write_text(line(merged_id))
    (source / "share-1.jsonl").write_text(line(unmerged_id))
    inputs = tmp_path / "inputs"
    inputs.mkdir()
    (inputs / "k").write_bytes(b"kernel")
    monkeypatch.setattr(jobs, "RESULTS", results)
    monkeypatch.setattr(jobs, "INPUTS", inputs)
    monkeypatch.setattr(jobs, "cal_kernel", lambda: inputs / "k")
    monkeypatch.setattr(jobs, "stage", lambda data: "k")
    monkeypatch.setattr(jobs, "cal_step", lambda *args: False)

    with pytest.raises(SystemExit):
        jobs.calibrate("new", "sha256:image", "old")

    carried = (results / "new" / "calibration.jsonl").read_text().splitlines()
    assert sorted(carried) == sorted([line(merged_id).strip(), line(unmerged_id).strip()])
