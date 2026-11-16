"""A frozen arm must not silently change its markets' execution costs."""

import json
from pathlib import Path

import pytest

from gate import kernel, markets, sweep
from gate.agent import campaigns
from gate.control import manifest


def test_verify_rejects_execution_costs_changed_between_arms(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    root = tmp_path / "repo"
    for source in manifest.judged_path(manifest.REPO):
        destination = root / source.relative_to(manifest.REPO)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source.read_bytes())

    binary = root / "kernel" / "fake-mm"
    binary.parent.mkdir(parents=True, exist_ok=True)
    binary.write_bytes(b"synthetic kernel identity")
    funding = root / "data" / "agent" / "inputs" / "synthetic-funding"
    funding.parent.mkdir(parents=True)
    funding.write_bytes(b"synthetic funding identity")
    nulls = root / "gate" / "nulls.json"
    nulls.write_text(json.dumps({"N2": {"funding": {"sha256": funding.name}}}))
    calibration = root / "audit" / "control-1" / "calibration.json"
    calibration.parent.mkdir(parents=True)
    calibration.write_text(json.dumps({"strength": 0.004, "walls": {str(k): {"status": "pass"} for k in range(2, 6)}}))
    execution = root / "venue" / "hyperliquid" / "execution.json"
    execution.parent.mkdir(parents=True)

    def write_costs(bps: float) -> None:
        cells = {side: {"1000": bps, "10000": bps} for side in ("buy", "sell")}
        execution.write_text(json.dumps({"cost_bps_ex_fee": {"S0": cells}}))

    monkeypatch.setattr(kernel, "MM", binary)
    monkeypatch.setattr(campaigns, "OUT", root / "data" / "agent")
    monkeypatch.setattr(markets, "NULLS", nulls)
    monkeypatch.setattr(manifest, "harness_hash", lambda: "synthetic-harness")
    monkeypatch.chdir(root)
    write_costs(2.0)
    path = root / "manifest.json"
    manifest.write(manifest.build("control-1", calibration, manifest.files(root)), path)
    manifest.verify(path, manifest.files(root))
    searcher_costs = sweep.cost_cells()

    write_costs(200.0)
    assert sweep.cost_cells() != searcher_costs
    with pytest.raises(ValueError, match="execution"):
        manifest.verify(path, manifest.files(root))
