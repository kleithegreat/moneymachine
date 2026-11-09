import json
import subprocess
from pathlib import Path
from types import SimpleNamespace
from typing import Never

import jobs
import pytest
from test_live import killed_at


@pytest.fixture
def batch(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ("INPUTS", "RESULTS", "REPO"):
        path = tmp_path / name
        path.mkdir()
        monkeypatch.setattr(jobs, name, path)
    (jobs.REPO / "kernel/target/release").mkdir(parents=True)
    (jobs.REPO / "kernel/target/release/mm").write_bytes(b"kernel A")
    (jobs.REPO / "data/campaigns").mkdir(parents=True)
    (jobs.REPO / "data/campaigns/betas.json").write_bytes(b"calibration A")
    monkeypatch.setattr(jobs, "campaign_specs", lambda sweep: [{"id": "one"}, {"id": "two"}])
    monkeypatch.setattr(jobs, "stage_funding", lambda: None)
    monkeypatch.setattr(jobs, "manifest", lambda *a: {})
    monkeypatch.setattr(jobs, "kubectl", lambda *a, **kw: "created")
    monkeypatch.setattr(jobs, "job", lambda run: {"conditions": [{"type": "Complete", "status": "True"}]})
    monkeypatch.setattr(jobs.subprocess, "run", lambda *a, **kw: SimpleNamespace(stdout="commit"))


def test_retry_uses_recorded_inputs_without_local_files(batch) -> None:
    jobs.submit("original", "mixed", "sha256:A")
    original, _, _ = jobs.state("original")
    (jobs.RESULTS / "original/one.tar").touch()
    (jobs.REPO / "kernel/target/release/mm").unlink()
    (jobs.REPO / "data/campaigns/betas.json").write_bytes(b"calibration B")
    jobs.resubmit("original")
    retry, ids, _ = jobs.state("original-r1")
    assert ids == ["two"]
    assert {k: retry[k] for k in ("mm", "betas", "image", "commit")} == {
        k: original[k] for k in ("mm", "betas", "image", "commit")
    }


@pytest.mark.parametrize("field", ["mm", "betas", "ids"])
def test_retry_refuses_changed_recorded_input(batch, field) -> None:
    jobs.submit("original", "mixed", "sha256:A")
    record, _, _ = jobs.state("original")
    (jobs.INPUTS / record[field]).write_text("[]" if field == "ids" else "corrupt")
    with pytest.raises(SystemExit, match=field):
        jobs.resubmit("original")
    assert not (jobs.RESULTS / "original-r1").exists()


@pytest.mark.parametrize("field", ["betas", "image"])
def test_collect_refuses_mixed_provenance(batch, field) -> None:
    jobs.submit("original", "mixed", "sha256:A")
    record, _, _ = jobs.state("original")
    other = jobs.RESULTS / "other"
    other.mkdir()
    (other / "record.json").write_text(json.dumps(record | {field: "different"}))
    with pytest.raises(SystemExit, match="calibration or image"):
        jobs.collect("original", "other")


def test_run_name_is_single_use_even_when_apply_fails(batch, monkeypatch: pytest.MonkeyPatch) -> None:
    def refuse(*a, **kw) -> Never:
        raise subprocess.CalledProcessError(1, "fake apply")

    monkeypatch.setattr(jobs, "kubectl", refuse)
    with pytest.raises(subprocess.CalledProcessError):
        jobs.submit("used", "mixed", "sha256:A")
    before = (jobs.RESULTS / "used/record.json").read_bytes()
    with pytest.raises((FileExistsError, SystemExit)):
        jobs.submit("used", "mixed", "sha256:B")
    assert (jobs.RESULTS / "used/record.json").read_bytes() == before


def test_killed_submission_still_consumes_run_name(batch, monkeypatch: pytest.MonkeyPatch) -> None:
    def install(stop) -> None:
        jobs.kubectl = lambda *a, **kw: stop()

    killed_at(lambda: jobs.submit("used", "mixed", "sha256:A"), install)
    before = (jobs.RESULTS / "used/record.json").read_bytes()
    with pytest.raises(FileExistsError):
        jobs.submit("used", "mixed", "sha256:B")
    assert (jobs.RESULTS / "used/record.json").read_bytes() == before


def test_push_digest_belongs_to_copy_not_mutable_tag(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    calls = []

    def run(args, **kw):
        calls.append(args)
        if args[:2] == ["nix", "build"]:
            return SimpleNamespace(stdout="/fake/image")
        if args[0] == "git":
            return SimpleNamespace(stdout="commit")
        if args[:2] == ["skopeo", "copy"]:
            if "--digestfile" in args:
                Path(args[args.index("--digestfile") + 1]).write_text("sha256:A")
            return SimpleNamespace(stdout="")
        return SimpleNamespace(stdout=json.dumps({"Digest": "sha256:B"}))

    monkeypatch.setattr(jobs.subprocess, "run", run)
    assert jobs.push() == "sha256:A"
    assert not any(a[:2] == ["skopeo", "inspect"] for a in calls)
    assert json.loads(capsys.readouterr().out)["digest"] == "sha256:A"
