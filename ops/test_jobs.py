import json
import subprocess
from collections.abc import Callable
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Never

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
    monkeypatch.setattr(subprocess, "run", lambda *a, **kw: SimpleNamespace(stdout="commit"))


def test_retry_uses_recorded_inputs_without_local_files(batch: None) -> None:
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
def test_retry_refuses_changed_recorded_input(batch: None, field: str) -> None:
    jobs.submit("original", "mixed", "sha256:A")
    record, _, _ = jobs.state("original")
    (jobs.INPUTS / record[field]).write_text("[]" if field == "ids" else "corrupt")
    with pytest.raises(SystemExit, match=field):
        jobs.resubmit("original")
    assert not (jobs.RESULTS / "original-r1").exists()


@pytest.mark.parametrize("field", ["betas", "image"])
def test_collect_refuses_mixed_provenance(batch: None, field: str) -> None:
    jobs.submit("original", "mixed", "sha256:A")
    record, _, _ = jobs.state("original")
    other = jobs.RESULTS / "other"
    other.mkdir()
    (other / "record.json").write_text(json.dumps(record | {field: "different"}))
    with pytest.raises(SystemExit, match="calibration or image"):
        jobs.collect("original", "other")


def test_run_name_is_single_use_even_when_apply_fails(batch: None, monkeypatch: pytest.MonkeyPatch) -> None:
    def refuse(*a: Any, **kw: Any) -> Never:
        raise subprocess.CalledProcessError(1, "fake apply")

    monkeypatch.setattr(jobs, "kubectl", refuse)
    with pytest.raises(subprocess.CalledProcessError):
        jobs.submit("used", "mixed", "sha256:A")
    before = (jobs.RESULTS / "used/record.json").read_bytes()
    with pytest.raises((FileExistsError, SystemExit)):
        jobs.submit("used", "mixed", "sha256:B")
    assert (jobs.RESULTS / "used/record.json").read_bytes() == before


def test_killed_submission_still_consumes_run_name(batch: None, monkeypatch: pytest.MonkeyPatch) -> None:
    def install(stop: Callable[[], None]) -> None:
        jobs.kubectl = lambda *a, **kw: stop()  # type: ignore[assignment]

    killed_at(lambda: jobs.submit("used", "mixed", "sha256:A"), install)
    before = (jobs.RESULTS / "used/record.json").read_bytes()
    with pytest.raises(FileExistsError):
        jobs.submit("used", "mixed", "sha256:B")
    assert (jobs.RESULTS / "used/record.json").read_bytes() == before


def test_push_digest_belongs_to_copy_not_mutable_tag(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    calls: list[list[str]] = []

    def run(args: list[str], **kw: Any) -> SimpleNamespace:
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

    monkeypatch.setattr(subprocess, "run", run)
    assert jobs.push() == "sha256:A"
    assert not any(a[:2] == ["skopeo", "inspect"] for a in calls)
    assert json.loads(capsys.readouterr().out)["digest"] == "sha256:A"


def test_merge_shares_appends_complete_lines_and_keeps_each_share_under_its_step(tmp_path: Path) -> None:
    (tmp_path / "calibration.jsonl").write_text('{"a": 1}\n')
    (tmp_path / "share-0.jsonl").write_text('{"b": 2}\n{"c": 3}\n')
    (tmp_path / "share-1.jsonl").write_text('{"d": 4}\n{"e": ')
    assert jobs.merge_shares(tmp_path, "r0") == 3
    assert (tmp_path / "calibration.jsonl").read_text() == '{"a": 1}\n{"b": 2}\n{"c": 3}\n{"d": 4}\n'
    assert sorted(f.name for f in tmp_path.glob("share-*")) == ["share-0.r0.jsonl", "share-1.r0.jsonl"]


def test_merge_shares_takes_only_this_rounds_numbered_files_over_two_rounds(tmp_path: Path) -> None:
    (tmp_path / "calibration.jsonl").write_bytes(b'{"merged": 0}\n')
    first = b'{"round": 0}\n'
    second = b'{"round": 1}\n'
    (tmp_path / "share-0.jsonl").write_bytes(first)
    assert jobs.merge_shares(tmp_path, "r0") == 1
    assert (tmp_path / "share-0.r0.jsonl").read_bytes() == first
    assert (tmp_path / "calibration.jsonl").read_bytes() == b'{"merged": 0}\n' + first
    ignored = {
        "share-host.jsonl": b'{"not": "digits"}\n',
        "share-1.jsonl.bak": b'{"not": "a jsonl file"}\n',
        "share-2-extra.jsonl": b'{"not": "just digits"}\n',
    }
    for name, contents in ignored.items():
        (tmp_path / name).write_bytes(contents)
    (tmp_path / "share-0.jsonl").write_bytes(second)
    assert jobs.merge_shares(tmp_path, "r1") == 1
    assert (tmp_path / "calibration.jsonl").read_bytes() == b'{"merged": 0}\n' + first + second
    assert (tmp_path / "share-0.r0.jsonl").read_bytes() == first
    assert (tmp_path / "share-0.r1.jsonl").read_bytes() == second
    assert sorted(path.name for path in tmp_path.iterdir()) == sorted(
        ["calibration.jsonl", "share-0.r0.jsonl", "share-0.r1.jsonl", *ignored]
    )
    for name, contents in ignored.items():
        assert (tmp_path / name).read_bytes() == contents
    assert jobs.merge_shares(tmp_path, "r2") == 0
    assert (tmp_path / "calibration.jsonl").read_bytes() == b'{"merged": 0}\n' + first + second
    assert (tmp_path / "share-0.r0.jsonl").read_bytes() == first
    assert (tmp_path / "share-0.r1.jsonl").read_bytes() == second


class CalibrationClusterStoppedError(Exception):
    pass


def stop_calibration_cluster(*args: Any, **kwargs: Any) -> Never:
    raise CalibrationClusterStoppedError


def source_files(source: Path) -> dict[str, bytes]:
    return {str(path.relative_to(source)): path.read_bytes() for path in source.rglob("*") if path.is_file()}


@pytest.fixture
def calibration_source(batch: None) -> Path:
    jobs.submit("source", "mixed", "sha256:A")
    source = jobs.RESULTS / "source"
    contents = {
        "calibration.jsonl": b'{"market": "merged"}\n{"cut": ',
        "share-0.r0.jsonl": b'{"market": "kept"}\n{"market": "merged"}\n',
        "share-1.jsonl": b'{"market": "current"}\n{"cut": ',
        "share-arbitrary-name.jsonl": b'{"market": "named"}\n',
        "share-2.r0.r1.jsonl": b'{"market": "old-renamed"}\n',
        "share-3.jsonl": b'{"cut": ',
        "probe-0.json": b'{"seconds": 1, "results": []}\n',
        "unrelated.jsonl": b'{"not": "a trial"}\n',
        "calibration.json": b'{"strength": 0.004}\n',
    }
    for name, data in contents.items():
        (source / name).write_bytes(data)
    return source


def test_calibrate_carries_the_merged_log_and_the_unmerged_shares_once_and_leaves_the_source_unchanged(
    calibration_source: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    def cal_kernel() -> Path:
        return jobs.REPO / "kernel/target/release/mm"

    monkeypatch.setattr(jobs, "cal_kernel", cal_kernel)
    monkeypatch.setattr(jobs, "cal_step", stop_calibration_cluster)
    before = source_files(calibration_source)
    with pytest.raises(CalibrationClusterStoppedError):
        jobs.calibrate("carried", "sha256:B", "source")
    out = jobs.RESULTS / "carried"
    expected = [b'{"market": "merged"}\n', b'{"market": "current"}\n']
    assert sorted((out / "calibration.jsonl").read_bytes().splitlines(keepends=True)) == sorted(expected)
    record: dict[str, Any] = json.loads((out / "record.json").read_text())
    original: dict[str, Any] = json.loads(before["record.json"])
    assert record["from"] == "source"
    assert record["mm"] == original["mm"]
    assert record["image"] == "sha256:B"
    assert not (out / "calibration.json").exists()
    assert source_files(calibration_source) == before


def test_calibrate_refuses_to_carry_another_kernel_without_changing_the_source(
    calibration_source: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    def cal_kernel() -> Path:
        return jobs.REPO / "kernel/target/release/mm"

    monkeypatch.setattr(jobs, "cal_kernel", cal_kernel)
    monkeypatch.setattr(jobs, "cal_step", stop_calibration_cluster)
    before = source_files(calibration_source)
    (jobs.REPO / "kernel/target/release/mm").write_bytes(b"kernel B")
    with pytest.raises((SystemExit, RuntimeError, ValueError)) as stopped:
        jobs.calibrate("refused", "sha256:B", "source")
    if isinstance(stopped.value, SystemExit):
        assert stopped.value.code not in (None, 0)
    log = jobs.RESULTS / "refused/calibration.jsonl"
    assert not log.exists() or log.read_bytes() == b""
    assert not (jobs.RESULTS / "refused/calibration.json").exists()
    assert source_files(calibration_source) == before


def test_calibrate_carries_source_lines_only_when_the_new_run_is_made(
    calibration_source: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    def cal_kernel() -> Path:
        return jobs.REPO / "kernel/target/release/mm"

    monkeypatch.setattr(jobs, "cal_kernel", cal_kernel)
    monkeypatch.setattr(jobs, "cal_step", stop_calibration_cluster)
    with pytest.raises(CalibrationClusterStoppedError):
        jobs.calibrate("carried", "sha256:B", "source")
    out = jobs.RESULTS / "carried"
    log = (out / "calibration.jsonl").read_bytes()
    (calibration_source / "share-4.jsonl").write_bytes(b'{"market": "later"}\n')
    before = source_files(calibration_source)
    with pytest.raises(CalibrationClusterStoppedError):
        jobs.calibrate("carried", "sha256:B")
    assert (out / "calibration.jsonl").read_bytes() == log
    assert json.loads((out / "record.json").read_text())["from"] == "source"
    assert source_files(calibration_source) == before
