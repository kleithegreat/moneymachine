"""Capacity alarms and mirror reports, tested from the public specification."""

import builtins
import importlib
import io
import json
import multiprocessing
import os
import re
import signal
import subprocess
import time
from pathlib import Path
from types import SimpleNamespace
from typing import Never

import pytest

VOLUMES = ("hl", "sources", "datalayer", "thesis", "agent")
RESOURCES = ("bytes", "inodes")
NOW = 1_800_000_000.0


def sample(free: int = 80, total: int = 100):
    return {resource: {"free": free, "total": total} for resource in RESOURCES}


def statvfs_result(measurement):
    return SimpleNamespace(
        f_bavail=measurement["bytes"]["free"],
        f_blocks=measurement["bytes"]["total"],
        f_frsize=1,
        f_bsize=4096,
        f_bfree=999,
        f_favail=measurement["inodes"]["free"],
        f_files=measurement["inodes"]["total"],
        f_ffree=999,
    )


def write_report(mirror, volume, *, capacity=None, taken=NOW * 1000):
    path = mirror / volume / "MANIFEST.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            {
                "taken": int(taken),
                "capacity": sample() if capacity is None else capacity,
                "files": {},
            }
        )
    )
    return path


def named(alarms, scope, resource=None):
    matches = [alarm for alarm in alarms if re.search(rf"\b{re.escape(scope)}\b", alarm)]
    if resource is not None:
        matches = [alarm for alarm in matches if resource in alarm]
    assert matches, (scope, resource, alarms)
    return matches


@pytest.fixture
def diskguard():
    return importlib.import_module("ops.diskguard")


@pytest.fixture
def site(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    data, mirror = tmp_path / "data", tmp_path / "mirror"
    data.mkdir()
    for volume in VOLUMES:
        write_report(mirror, volume)
    measurements = {data: sample(), mirror: sample()}
    measured = []

    def measure(path: Path):
        path = Path(path)
        measured.append(path)
        result = measurements[path]
        if isinstance(result, Exception):
            raise result
        return statvfs_result(result)

    monkeypatch.setattr(os, "statvfs", measure)
    monkeypatch.setattr(time, "time", lambda: NOW)
    return SimpleNamespace(data=data, mirror=mirror, measurements=measurements, measured=measured)


def test_capacity_uses_available_blocks_fragment_size_and_available_inodes(
    diskguard, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    calls = []

    def measure(path: Path):
        calls.append(path)
        return SimpleNamespace(
            f_bavail=11, f_bfree=99, f_blocks=100, f_frsize=4096, f_bsize=8192, f_favail=13, f_ffree=88, f_files=200
        )

    monkeypatch.setattr(os, "statvfs", measure)
    assert diskguard.capacity(tmp_path) == {
        "bytes": {"free": 11 * 4096, "total": 100 * 4096},
        "inodes": {"free": 13, "total": 200},
    }
    assert calls == [tmp_path]


@pytest.mark.parametrize("resource", RESOURCES)
@pytest.mark.parametrize("free", [0, 10, 20])
def test_problems_names_low_resource_and_free_fraction(diskguard, resource, free) -> None:
    measurement = sample()
    measurement[resource]["free"] = free
    alarms = diskguard.problems(measurement)
    assert isinstance(alarms, list) and len(alarms) == 1
    alarm = named(alarms, resource)[0]
    fraction = free / 100
    assert (
        re.search(rf"(?<![\d.]){free}(?:\.0+)?\s*%", alarm)
        or re.search(rf"(?<![\d.]){re.escape(str(fraction))}(?:0*)(?!\d)", alarm)
        or re.search(rf"\b{free}\s*/\s*100\b", alarm)
    ), alarm


@pytest.mark.parametrize("free,total", [(21, 100), (1, 4), (100, 100), (2**60 + 1, 5 * 2**60)])
def test_problems_accepts_above_twenty_percent_without_float_rounding(diskguard, free, total) -> None:
    assert diskguard.problems(sample(free, total)) == []


def test_problems_reports_both_exhausted_resources(diskguard) -> None:
    alarms = diskguard.problems(sample(0))
    assert len(alarms) == 2
    for resource in RESOURCES:
        named(alarms, resource)


@pytest.mark.parametrize("invalid", [None, [], "capacity", {}, {"bytes": {}}, {"bytes": {"free": 80, "total": 100}}])
def test_problems_rejects_invalid_schema(diskguard, invalid) -> None:
    with pytest.raises(ValueError):
        diskguard.problems(invalid)


@pytest.mark.parametrize("resource", RESOURCES)
@pytest.mark.parametrize(
    "field,value",
    [
        ("free", -1),
        ("free", 101),
        ("free", 1.0),
        ("free", "80"),
        ("free", None),
        ("free", True),
        ("free", float("nan")),
        ("total", 0),
        ("total", -1),
        ("total", 100.0),
        ("total", "100"),
        ("total", None),
        ("total", True),
        ("total", float("inf")),
    ],
)
def test_problems_rejects_invalid_counters(diskguard, resource, field, value) -> None:
    measurement = sample()
    measurement[resource][field] = value
    with pytest.raises(ValueError):
        diskguard.problems(measurement)


@pytest.mark.parametrize("resource", RESOURCES)
@pytest.mark.parametrize("missing", ["resource", "free", "total"])
def test_problems_rejects_missing_counters(diskguard, resource, missing) -> None:
    measurement = sample()
    if missing == "resource":
        del measurement[resource]
    else:
        del measurement[resource][missing]
    with pytest.raises(ValueError):
        diskguard.problems(measurement)


def test_check_measures_both_local_paths_and_accepts_all_reports(diskguard, site) -> None:
    assert diskguard.check(site.data, site.mirror, now=NOW) == []
    assert set(site.measured) == {site.data, site.mirror}


@pytest.mark.parametrize("location", ["data", "mirror", *VOLUMES])
@pytest.mark.parametrize("resource", RESOURCES)
@pytest.mark.parametrize("free", [19, 20, 21])
def test_check_each_resource_on_each_volume_at_threshold(diskguard, site, location, resource, free) -> None:
    measurement = sample()
    measurement[resource]["free"] = free
    if location in ("data", "mirror"):
        site.measurements[getattr(site, location)] = measurement
    else:
        write_report(site.mirror, location, capacity=measurement)
    alarms = diskguard.check(site.data, site.mirror, now=NOW)
    if free > 20:
        assert alarms == []
    else:
        assert len(alarms) == 1
        named(alarms, location, resource)


@pytest.mark.parametrize("age", [0, 1799.999, 1800])
def test_check_accepts_report_age_inclusive_boundaries(diskguard, site, age) -> None:
    for volume in VOLUMES:
        write_report(site.mirror, volume, taken=(NOW - age) * 1000)
    assert diskguard.check(site.data, site.mirror, now=NOW) == []


@pytest.mark.parametrize("volume", VOLUMES)
@pytest.mark.parametrize("failure", ["missing", "corrupt", "stale", "future", "directory"])
def test_check_reports_each_unavailable_or_expired_source(diskguard, site, volume, failure) -> None:
    path = site.mirror / volume / "MANIFEST.json"
    if failure == "missing":
        path.unlink()
    elif failure == "corrupt":
        path.write_text("{not JSON")
    elif failure == "directory":
        path.unlink()
        path.mkdir()
    else:
        taken = (NOW - 1800.001 if failure == "stale" else NOW + 0.001) * 1000
        write_report(site.mirror, volume, taken=taken)
    alarms = diskguard.check(site.data, site.mirror, now=NOW)
    assert len(alarms) == 1
    named(alarms, volume)


@pytest.mark.parametrize(
    "invalid",
    [
        None,
        [],
        {},
        {"taken": NOW * 1000},
        {"capacity": sample()},
        {"taken": NOW * 1000, "capacity": []},
        *(
            {"taken": taken, "capacity": sample()}
            for taken in [None, True, "1800000000000", float("nan"), float("inf")]
        ),
    ],
)
def test_check_rejects_malformed_report_metadata(diskguard, site, invalid) -> None:
    (site.mirror / "hl/MANIFEST.json").write_text(json.dumps(invalid))
    alarms = diskguard.check(site.data, site.mirror, now=NOW)
    assert len(alarms) == 1
    named(alarms, "hl")


@pytest.mark.parametrize("volume", VOLUMES)
@pytest.mark.parametrize("resource", RESOURCES)
def test_check_invalid_source_counters_do_not_hide_other_source_alarms(diskguard, site, volume, resource) -> None:
    measurement = sample()
    measurement[resource]["free"] = -1
    write_report(site.mirror, volume, capacity=measurement)
    other = next(name for name in VOLUMES if name != volume)
    write_report(site.mirror, other, capacity=sample(0))
    alarms = diskguard.check(site.data, site.mirror, now=NOW)
    named(alarms, volume)
    for kind in RESOURCES:
        named(alarms, other, kind)


@pytest.mark.parametrize("location", ["data", "mirror"])
@pytest.mark.parametrize("failure", ["measurement", "counter"])
def test_check_continues_after_individual_local_failures(diskguard, site, location, failure) -> None:
    path = getattr(site, location)
    site.measurements[path] = PermissionError("measurement unavailable") if failure == "measurement" else sample(-1)
    other = site.mirror if location == "data" else site.data
    site.measurements[other] = sample(0)
    for volume in VOLUMES:
        write_report(site.mirror, volume, capacity=sample(0))
    alarms = diskguard.check(site.data, site.mirror, now=NOW)
    named(alarms, location)
    for scope in [other.name, *VOLUMES]:
        for resource in RESOURCES:
            named(alarms, scope, resource)
    assert set(site.measured) == {site.data, site.mirror}


def test_check_accumulates_all_missing_reports_and_both_local_errors(diskguard, site) -> None:
    for path in site.measurements:
        site.measurements[path] = OSError("offline")
    for volume in VOLUMES:
        (site.mirror / volume / "MANIFEST.json").unlink()
    alarms = diskguard.check(site.data, site.mirror, now=NOW)
    assert len(alarms) == 7
    for scope in ["data", "mirror", *VOLUMES]:
        named(alarms, scope)


def test_check_reads_only_manifest_metadata(diskguard, site, monkeypatch: pytest.MonkeyPatch) -> None:
    for volume in VOLUMES:
        (site.mirror / volume / "recording.jsonl").write_text("synthetic content, not a report")
    allowed = {site.mirror / volume / "MANIFEST.json" for volume in VOLUMES}
    opened = []

    def guarded(original):
        def open_file(path: Path, mode: str = "r", *args, **kwargs):
            assert Path(path) in allowed, path
            assert "w" not in mode and "a" not in mode and "+" not in mode
            opened.append(Path(path))
            return original(path, mode, *args, **kwargs)

        return open_file

    with monkeypatch.context() as patch:
        patch.setattr(builtins, "open", guarded(builtins.open))
        patch.setattr(io, "open", guarded(io.open))
        alarms = diskguard.check(site.data, site.mirror, now=NOW)
    assert alarms == []
    assert set(opened) == allowed


def test_main_healthy_does_not_notify(
    diskguard, site, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    calls = []
    monkeypatch.setattr(subprocess, "run", lambda *args, **kwargs: calls.append((args, kwargs)))
    assert diskguard.main(site.data, site.mirror) == 0
    assert calls == []
    assert capsys.readouterr().err == ""


def test_main_uses_specified_default_paths(diskguard, monkeypatch: pytest.MonkeyPatch) -> None:
    calls = []

    def check(data, mirror, now=None):
        calls.append((data, mirror))
        return []

    def unexpected_notification(*args, **kwargs) -> None:
        pytest.fail("healthy main must not launch a notification")

    monkeypatch.setattr(diskguard, "check", check)
    monkeypatch.setattr(subprocess, "run", unexpected_notification)
    assert diskguard.main() == 0
    assert calls == [(Path("data"), Path("/srv/moneymachine/mirror"))]


def test_main_repeats_critical_persistent_notification_with_all_alarms(
    diskguard, site, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    site.measurements[site.data] = sample(0)
    for volume in VOLUMES:
        write_report(site.mirror, volume, capacity=sample(0))
    expected = diskguard.check(site.data, site.mirror, now=NOW)
    assert len(expected) == 12
    calls = []

    def notify(command, **kwargs):
        calls.append((command, kwargs))
        return subprocess.CompletedProcess(command, 0)

    monkeypatch.setattr(subprocess, "run", notify)
    for _ in range(2):
        assert diskguard.main(site.data, site.mirror) == 1
        stderr = capsys.readouterr().err
        assert all(alarm in stderr for alarm in expected)
    assert len(calls) == 2
    for command, kwargs in calls:
        assert command[:4] == [
            "notify-send",
            "--urgency=critical",
            "--expire-time=0",
            "moneymachine: recording capacity alarm",
        ]
        assert len(command) == 5
        assert all(alarm in command[4] for alarm in expected)
        assert kwargs == {"check": True, "timeout": 10}


@pytest.mark.parametrize(
    "failure",
    [
        FileNotFoundError("notify-send"),
        subprocess.CalledProcessError(1, ["notify-send"]),
        subprocess.TimeoutExpired(["notify-send"], 10),
    ],
)
def test_main_notification_failure_cannot_return_success(
    diskguard, site, monkeypatch: pytest.MonkeyPatch, failure
) -> None:
    write_report(site.mirror, "agent", capacity=sample(0))
    calls = []

    def fail(*args, **kwargs) -> Never:
        calls.append((args, kwargs))
        raise failure

    monkeypatch.setattr(subprocess, "run", fail)
    try:
        result = diskguard.main(site.data, site.mirror)
    except (OSError, subprocess.SubprocessError):
        pass
    else:
        assert result != 0
    assert len(calls) == 1


@pytest.fixture
def mirror_site(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    live = importlib.import_module("ops.live")
    assert set(live.VOLUMES) == set(VOLUMES)
    app, out = tmp_path / "app", tmp_path / "mirror"
    measurements = {}
    measured = []
    for index, volume in enumerate(VOLUMES):
        source = app / live.VOLUMES[volume]
        source.mkdir(parents=True)
        (source / "synthetic.txt").write_text(f"synthetic {volume}")
        measurements[source] = {
            "bytes": {"free": 40 + index, "total": 100 + index},
            "inodes": {"free": 60 + index, "total": 200 + index},
        }

    def measure(path: Path):
        path = Path(path)
        measured.append(path)
        return statvfs_result(measurements.get(path, sample()))

    monkeypatch.setattr(os, "statvfs", measure)
    return SimpleNamespace(live=live, app=app, mirror=out, measurements=measurements, measured=measured)


def test_mirror_reports_each_source_volume_capacity_and_publishes_manifest_last(
    mirror_site, monkeypatch: pytest.MonkeyPatch
) -> None:
    site = mirror_site
    published = []
    replace = Path.replace

    def publish(path: Path, target):
        target = Path(target)
        if target.name == "MANIFEST.json":
            volume = target.parent.name
            assert (target.parent / "synthetic.txt").read_text() == f"synthetic {volume}"
            published.append(volume)
        return replace(path, target)

    monkeypatch.setattr(Path, "replace", publish)
    before = time.time() * 1000
    site.live.mirror(site.app, site.mirror)
    after = time.time() * 1000
    assert set(published) == set(VOLUMES)
    for volume in VOLUMES:
        source = site.app / site.live.VOLUMES[volume]
        report = json.loads((site.mirror / volume / "MANIFEST.json").read_text())
        assert set(report) == {"taken", "files", "capacity"}
        assert report["capacity"] == site.measurements[source]
        assert before - 1 <= report["taken"] <= after + 1
        assert set(report["files"]) == {"synthetic.txt"}
        assert source in site.measured


def test_killed_mirror_cannot_refresh_report_before_final_publication(diskguard, mirror_site) -> None:
    site = mirror_site
    site.live.mirror(site.app, site.mirror)
    target = site.mirror / "hl/MANIFEST.json"
    old_report = target.read_bytes()
    now = json.loads(old_report)["taken"] / 1000 + 1801
    for volume in VOLUMES:
        source = site.app / site.live.VOLUMES[volume]
        (source / "synthetic.txt").write_text(f"updated synthetic {volume}")
        if volume != "hl":
            write_report(site.mirror, volume, taken=now * 1000)
    context = multiprocessing.get_context("fork")
    parent, child = context.Pipe()

    def worker() -> None:
        replace = Path.replace

        def interrupted(path: Path, destination):
            if Path(destination) == target:
                child.send("paused before manifest publication")
                child.recv()
            return replace(path, destination)

        Path.replace = interrupted
        time.time = lambda: now
        try:
            site.live.mirror(site.app, site.mirror)
            child.send("finished without interruption")
        except BaseException as error:
            child.send(f"{type(error).__name__}: {error}")

    process = context.Process(target=worker)
    process.start()
    try:
        assert parent.poll(15), "mirror did not reach final manifest replacement"
        assert parent.recv() == "paused before manifest publication"
        process.kill()
        process.join(10)
        assert process.exitcode == -signal.SIGKILL
    finally:
        if process.is_alive():
            process.kill()
        process.join(10)
        parent.close()
        child.close()
    assert target.read_bytes() == old_report
    alarms = diskguard.check(site.app / "data", site.mirror, now=now)
    assert len(alarms) == 1
    alarm = named(alarms, "hl")[0]
    assert "stale" in alarm.lower() or "age" in alarm.lower() or "old" in alarm.lower()
