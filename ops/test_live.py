"""The live workloads' manifests keep CLUSTER.md's boundaries: only live volumes, the token only in runners, the
datalayer keys only in its recorder, restricted pods with read-only roots, user namespaces and the bubblewrap profiles
only where sessions run."""

import gzip
import hashlib
import json
import multiprocessing
import sqlite3
import time
from pathlib import Path
from types import SimpleNamespace
from typing import Never

import live
import pytest


def killed_at(action, install) -> None:
    parent, child = multiprocessing.get_context("fork").Pipe()

    def worker() -> None:
        def stop() -> None:
            child.send("paused")
            child.recv()

        install(stop)
        action()
        child.send("finished")

    process = multiprocessing.get_context("fork").Process(target=worker)
    process.start()
    try:
        assert parent.poll(10), "child did not reach interruption point"
        assert parent.recv() == "paused"
        process.kill()
    finally:
        process.join(10)
        if process.is_alive():
            process.kill()
            process.join()
    assert process.exitcode == -9


@pytest.mark.parametrize("dest", ["../../hl/record.jsonl", "absolute", "safe/../record", "SHA256.json"])
def test_seed_validates_all_destinations_before_copy(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, dest) -> None:
    if dest == "absolute":
        dest = str(tmp_path / "outside/record.jsonl")
    monkeypatch.setattr(live, "MIRROR", tmp_path)
    source = tmp_path / "source"
    source.write_bytes(b"new")
    copied = []
    copy = live.shutil.copy2

    def tracked(*a):
        copied.append(a)
        return copy(*a)

    monkeypatch.setattr(live.shutil, "copy2", tracked)
    monkeypatch.setattr(live, "run_pod", lambda *a: ("", True))
    with pytest.raises((SystemExit, ValueError)):
        live.seed("sha256:A", "agent", f"{source}:valid", f"{source}:{dest}")
    assert copied == []


def local_seed_runner(name, spec):
    path = live.Path

    def mapped(p):
        p = path(p)
        return live.MIRROR / p.relative_to("/mirror") if p.is_relative_to("/mirror") else p

    live.Path = mapped
    try:
        live.seed_run(*spec["containers"][0]["command"][3:])
        return "", True
    finally:
        live.Path = path


@pytest.mark.parametrize("success", [False, True])
def test_seed_removes_only_its_own_successful_stage(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, success) -> None:
    monkeypatch.setattr(live, "APP", tmp_path / "app")
    monkeypatch.setattr(live, "MIRROR", tmp_path / "mirror")
    leftover = live.MIRROR / "seed/earlier-stage"
    leftover.mkdir(parents=True)
    (leftover / "diagnostic").write_text("keep")
    source = tmp_path / "source"
    source.write_bytes(b"complete")
    stages = []

    def runner(name, spec):
        stages.extend(p.parent for p in live.MIRROR.rglob("SHA256.json"))
        assert len(stages) == 1
        return local_seed_runner(name, spec) if success else ("diagnostic failure", False)

    monkeypatch.setattr(live, "run_pod", runner)
    if success:
        live.seed("sha256:A", "agent", f"{source}:input")
        assert (live.APP / "data/agent/input").read_bytes() == b"complete"
        assert not stages[0].exists()
    else:
        with pytest.raises(SystemExit):
            live.seed("sha256:A", "agent", f"{source}:input")
        assert (stages[0] / "input").read_bytes() == b"complete"
        assert json.loads((stages[0] / "SHA256.json").read_text())["input"] == live.sha256(source)
    assert (leftover / "diagnostic").read_text() == "keep"


def test_reseed_never_replaces_concurrently_appended_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(live, "APP", tmp_path / "app")
    monkeypatch.setattr(live, "MIRROR", tmp_path / "mirror")
    source = tmp_path / "source"
    source.write_bytes(b"A")
    target = tmp_path / "app/data/agent/day.jsonl"
    target.parent.mkdir(parents=True)
    target.write_bytes(b"A")
    digest = live.sha256
    checked = []

    def append_after_check(path, *a):
        result = digest(path, *a)
        if Path(path) == target and not checked:
            checked.append(True)
            with target.open("ab") as f:
                f.write(b"B")
        return result

    monkeypatch.setattr(live, "sha256", append_after_check)
    monkeypatch.setattr(live, "run_pod", local_seed_runner)
    live.seed("sha256:A", "agent", f"{source}:day.jsonl")
    assert target.read_bytes() == b"AB"


def test_seed_interruption_does_not_publish_partial_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(live, "APP", tmp_path / "app")
    monkeypatch.setattr(live, "MIRROR", tmp_path / "mirror")
    source = tmp_path / "source"
    source.write_bytes(b"complete")
    target = tmp_path / "app/data/agent/input"

    def install(stop) -> None:
        copy = live.shutil.copyfileobj
        copy2 = live.shutil.copy2

        def interrupted(a, b, *args):
            if not Path(b.name).is_relative_to(tmp_path / "app"):
                return copy(a, b, *args)
            b.write(a.read(1))
            b.flush()
            stop()

        live.shutil.copyfileobj = interrupted

        def copy_file(a, b):
            if not Path(b).is_relative_to(tmp_path / "app"):
                return copy2(a, b)
            with open(a, "rb") as src, open(b, "wb") as dst:
                interrupted(src, dst)

        live.shutil.copy2 = copy_file
        live.run_pod = local_seed_runner

    killed_at(lambda: live.seed("sha256:A", "agent", f"{source}:input"), install)
    assert not target.exists()


def test_seed_refuses_conflicts_and_symlinks_before_installing_any_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(live, "APP", tmp_path / "app")
    target = tmp_path / "app/data/agent"
    target.mkdir(parents=True)
    stage = tmp_path / "stage"
    stage.mkdir()
    (stage / "first").write_bytes(b"new")
    (stage / "second").write_bytes(b"new")
    digest = live.sha256(stage / "first")
    (stage / "SHA256.json").write_text(json.dumps({"first": digest, "second": digest}))
    (target / "second").write_bytes(b"recording")
    with pytest.raises(SystemExit, match="other content"):
        live.seed_run("agent", stage)
    assert not (target / "first").exists()
    assert (target / "second").read_bytes() == b"recording"
    (stage / "SHA256.json").write_text(json.dumps({"first": digest, "link/second": digest}))
    (target / "link").symlink_to(tmp_path, target_is_directory=True)
    with pytest.raises(SystemExit, match="symlink"):
        live.seed_run("agent", stage)
    assert not (target / "first").exists()
    (stage / "SHA256.json").write_text(json.dumps({"first": digest, "second/child": digest}))
    with pytest.raises(SystemExit, match="not a directory"):
        live.seed_run("agent", stage)
    assert not (target / "first").exists()


def test_concurrent_seed_destination_creation_is_not_overwritten(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(live, "APP", tmp_path / "app")
    stage = tmp_path / "stage"
    stage.mkdir()
    (stage / "input").write_bytes(b"new")
    (stage / "SHA256.json").write_text(json.dumps({"input": live.sha256(stage / "input")}))
    target = tmp_path / "app/data/agent/input"
    link = live.os.link

    def concurrent(src, dst):
        target.write_bytes(b"recording")
        return link(src, dst)

    monkeypatch.setattr(live.os, "link", concurrent)
    with pytest.raises(FileExistsError):
        live.seed_run("agent", stage)
    assert target.read_bytes() == b"recording"


def test_helper_after_killed_client_cannot_reuse_completed_pod(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    store = tmp_path / "pods.json"
    store.write_text("{}")

    def fake(*args, stdin=None):
        pods = json.loads(store.read_text())
        if args[0] in ("apply", "create"):
            pod = json.loads(stdin)
            name = pod["metadata"].get("name") or pod["metadata"]["generateName"] + str(len(pods))
            if args[0] == "create" and name in pods:
                raise RuntimeError("already exists")
            pods[name] = "Succeeded"
            store.write_text(json.dumps(pods))
            return json.dumps({"metadata": {"name": name}})
        if args[0] == "get":
            return pods[args[2]]
        if args[0] == "logs":
            return args[1]
        if args[0] == "delete":
            pods.pop(args[2])
            store.write_text(json.dumps(pods))
            return ""
        raise AssertionError(args)

    monkeypatch.setattr(live, "kubectl", fake)

    def install(stop) -> None:
        def interrupted(*args, **kw):
            if args[0] == "delete":
                stop()
            return fake(*args, **kw)

        live.kubectl = interrupted

    killed_at(lambda: live.run_pod("seed-agent", {}), install)
    leftover = set(json.loads(store.read_text()))
    log, ok = live.run_pod("seed-agent", {})
    assert ok and log not in leftover


@pytest.fixture
def passing_gate(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    from gate.agent import campaigns, harness
    from sandbox import session

    frozen = tmp_path / "audit/stage3/harness.json"
    frozen.parent.mkdir(parents=True)
    frozen.write_text(json.dumps({"harness": "frozen"}))
    monkeypatch.setattr(live, "REPO", tmp_path)
    monkeypatch.setattr(harness, "harness_hash", lambda: "frozen")
    monkeypatch.setattr(live.subprocess, "run", lambda *a, **kw: SimpleNamespace(returncode=0, stdout="passed"))
    monkeypatch.setattr(live, "view", lambda: ["view"])
    monkeypatch.setattr(campaigns, "windows", lambda: {"five_hour": 0.1})
    monkeypatch.setattr(live, "reach", lambda h, p: h == "api.anthropic.com")
    monkeypatch.setattr(live, "retrieval_reach", lambda: {"certified": 200})
    monkeypatch.setattr(session, "workspace", lambda *a: None)

    def run(work, *a):
        (work / "transcript.jsonl").write_text(json.dumps({"type": "result", "is_error": False, "result": "READY"}))
        return {"stopped": "finished", "exit": 0}

    monkeypatch.setattr(session, "run", run)
    return harness, campaigns, session


@pytest.mark.parametrize("failure", ["tests", "harness", "session", "windows", "network", "retrieval", "view"])
def test_gate_exits_nonzero_with_named_failure(
    passing_gate, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], failure
) -> None:
    harness, campaigns, session = passing_gate
    if failure == "tests":
        monkeypatch.setattr(live.subprocess, "run", lambda *a, **kw: SimpleNamespace(returncode=1, stdout="failed"))
    elif failure == "harness":
        monkeypatch.setattr(harness, "harness_hash", lambda: "different")
    elif failure == "session":
        monkeypatch.setattr(session, "run", lambda *a: {"stopped": "turn limit", "exit": 1})
    elif failure == "windows":

        def broken() -> Never:
            raise RuntimeError("unavailable")

        monkeypatch.setattr(campaigns, "windows", broken)
    elif failure == "network":
        monkeypatch.setattr(live, "reach", lambda *a: True)
    elif failure == "retrieval":
        monkeypatch.setattr(live, "retrieval_reach", lambda: {"certified": 403})
    else:
        monkeypatch.setattr(live, "view", lambda: [])
    with pytest.raises(SystemExit) as error:
        live.gate_run(json.dumps(live.TARGETS))
    assert error.value.code
    assert failure in str(error.value) + capsys.readouterr().out


@pytest.mark.parametrize(
    "result", [{"is_error": True, "result": "READY"}, {"is_error": False, "result": "NOT READY"}, {}]
)
def test_gate_refuses_unsuccessful_session_results(passing_gate, monkeypatch: pytest.MonkeyPatch, result) -> None:
    _, _, session = passing_gate

    def run(work, *a):
        (work / "transcript.jsonl").write_text(json.dumps({"type": "result"} | result))
        return {"stopped": "finished", "exit": 0}

    monkeypatch.setattr(session, "run", run)
    with pytest.raises(SystemExit, match="session"):
        live.gate_run(json.dumps(live.TARGETS))


def test_gate_requires_model_api_reachable(passing_gate, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(live, "reach", lambda *a: False)
    with pytest.raises(SystemExit, match="network"):
        live.gate_run(json.dumps(live.TARGETS))


def test_gate_accepts_all_passing_checks(passing_gate) -> None:
    live.gate_run(json.dumps(live.TARGETS))


def test_gate_propagates_failed_helper(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(live, "REPO", tmp_path)
    (tmp_path / "audit/cluster").mkdir(parents=True)
    monkeypatch.setattr(live, "run_pod", lambda *a: ("tests failed", False))
    with pytest.raises(SystemExit, match="gate"):
        live.gate("sha256:A")


def changing_mirror(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(live, "VOLUMES", {"thesis": "data/thesis"})
    app, out = tmp_path / "app", tmp_path / "mirror"
    source = app / "data/thesis"
    source.mkdir(parents=True)
    with sqlite3.connect(source / "ledger.sqlite") as db:
        db.execute("create table t (x)")
        db.execute("insert into t values (1)")
    (source / "other").write_text("original")
    (source / "day.jsonl").write_text("old\n")
    live.mirror(app, out)
    with sqlite3.connect(source / "ledger.sqlite") as db:
        db.execute("insert into t values (2)")
    (source / "other").write_text("replacement")
    with (source / "day.jsonl").open("a") as f:
        f.write("new\n")
    return app, out


@pytest.fixture
def verify_clock(monkeypatch: pytest.MonkeyPatch):
    clock = SimpleNamespace(elapsed=0, sleeps=[], on_sleep=lambda: None)

    def sleep(seconds) -> None:
        assert 0 < seconds <= 5
        clock.sleeps.append(seconds)
        clock.elapsed += seconds
        assert clock.elapsed <= live.MIRROR_VERIFY_WAIT
        clock.on_sleep()

    monkeypatch.setattr(live, "time", SimpleNamespace(monotonic=lambda: clock.elapsed, sleep=sleep, time=time.time))
    return clock


def test_mirror_publishes_only_flat_files_and_manifest(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    live.mirror(app, out)
    volume = out / "thesis"
    assert {p.name for p in out.iterdir()} == {"thesis"}
    assert not volume.is_symlink()
    assert {p.name for p in volume.iterdir()} == {"ledger.sqlite", "other", "day.jsonl", "MANIFEST.json"}
    assert all(p.is_file() and not p.is_symlink() for p in volume.iterdir())
    manifest = json.loads((volume / "MANIFEST.json").read_text())
    assert set(manifest) == {"taken", "files", "capacity"}
    assert set(manifest["files"]) == {"ledger.sqlite", "other", "day.jsonl"}
    live.verify(app, out)


@pytest.mark.parametrize("initial", [False, True])
def test_killed_whole_file_copy_never_publishes_partial_target(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, initial
) -> None:
    monkeypatch.setattr(live, "VOLUMES", {"thesis": "data/thesis"})
    app, out = tmp_path / "app", tmp_path / "mirror"
    source = app / "data/thesis/input"
    source.parent.mkdir(parents=True)
    source.write_bytes(b"original")
    target = out / "thesis/input"
    if not initial:
        live.mirror(app, out)
    source.write_bytes(b"complete replacement")
    (source.parent / "unrelated.tmp").write_bytes(b"partial writer output")

    def install(stop) -> None:
        copy = live.shutil.copy2

        def interrupted(src, dst, *args, **kwargs):
            if Path(src) != source:
                return copy(src, dst, *args, **kwargs)
            assert Path(dst) != target and Path(dst).suffix == ".tmp"
            with open(src, "rb") as reader, open(dst, "wb") as writer:
                writer.write(reader.read(1))
                writer.flush()
                stop()

        live.shutil.copy2 = interrupted

    killed_at(lambda: live.mirror(app, out), install)
    if initial:
        assert not target.exists()
    else:
        assert target.read_bytes() == b"original"
    (target.parent / "unrelated.tmp").write_bytes(b"leftover")
    live.mirror(app, out)
    assert target.read_bytes() == b"complete replacement"
    assert set(json.loads((target.parent / "MANIFEST.json").read_text())["files"]) == {"input"}
    live.verify(app, out)


def test_killed_sqlite_backup_preserves_complete_snapshot(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    source = app / "data/thesis/ledger.sqlite"
    target = out / "thesis/ledger.sqlite"
    before = target.read_bytes()
    with sqlite3.connect(source) as db:
        db.execute("create table body (payload)")
        db.execute("insert into body values (zeroblob(65536))")

    def install(stop) -> None:
        connect = live.sqlite3.connect

        class InterruptedConnection(sqlite3.Connection):
            def backup(self, destination, *args, **kwargs):
                path = Path(destination.execute("pragma database_list").fetchone()[2])
                assert path != target and path.suffix == ".tmp"

                def progress(status, remaining, total) -> None:
                    assert remaining > 0
                    stop()

                return super().backup(destination, pages=1, progress=progress)

        live.sqlite3.connect = lambda *a, **kw: connect(*a, **kw, factory=InterruptedConnection)

    killed_at(lambda: live.mirror(app, out), install)
    assert target.read_bytes() == before
    with sqlite3.connect(target) as db:
        assert db.execute("pragma integrity_check").fetchone() == ("ok",)
        assert db.execute("select x from t").fetchall() == [(1,)]
    live.mirror(app, out)
    with sqlite3.connect(target) as db:
        assert db.execute("pragma integrity_check").fetchone() == ("ok",)
        assert db.execute("select x from t").fetchall() == [(1,), (2,)]
    live.verify(app, out)


def test_verify_overlaps_flat_file_publication(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    manifest = out / "thesis/MANIFEST.json"
    parent, child = multiprocessing.get_context("fork").Pipe()

    def verifier() -> None:
        read = Path.read_text
        elapsed = [0]
        first = [True]

        def pause_after_old_manifest(path, *args, **kwargs):
            text = read(path, *args, **kwargs)
            if path == manifest and first[0]:
                first[0] = False
                child.send("read old manifest")
                child.recv()
            return text

        def sleep(seconds) -> None:
            child.send("waiting for publication")
            child.recv()
            elapsed[0] += seconds

        Path.read_text = pause_after_old_manifest
        live.time = SimpleNamespace(monotonic=lambda: elapsed[0], sleep=sleep, time=time.time)
        live.verify(app, out)
        child.send("verified")

    process = multiprocessing.get_context("fork").Process(target=verifier)
    process.start()
    try:
        assert parent.poll(10) and parent.recv() == "read old manifest"
        write = Path.write_text
        paused = []

        def before_manifest(path, *args, **kwargs):
            if path.name.startswith("MANIFEST.json") and not paused:
                paused.append(True)
                assert (out / "thesis/other").read_text() == "replacement"
                with sqlite3.connect(out / "thesis/ledger.sqlite") as db:
                    assert db.execute("select x from t").fetchall() == [(1,), (2,)]
                parent.send("files replaced")
                assert parent.poll(10) and parent.recv() == "waiting for publication"
            return write(path, *args, **kwargs)

        with monkeypatch.context() as patcher:
            patcher.setattr(Path, "write_text", before_manifest)
            live.mirror(app, out)
        assert paused
        parent.send("manifest published")
        assert parent.poll(10) and parent.recv() == "verified"
        process.join(10)
        assert process.exitcode == 0
    finally:
        if process.is_alive():
            process.kill()
            process.join()
    live.verify(app, out)


@pytest.mark.parametrize("published", [False, True])
def test_killed_manifest_publication_is_detected_and_recoverable(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock, published
) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    before = (out / "thesis/MANIFEST.json").read_bytes()

    def install(stop) -> None:
        write = Path.write_text
        replace = Path.replace

        def interrupted(path, *a, **kw):
            if not published and path.name.startswith("MANIFEST.json"):
                stop()
            return write(path, *a, **kw)

        def after_publication(path, *a, **kw):
            result = replace(path, *a, **kw)
            if published and path.name == "MANIFEST.json.tmp":
                stop()
            return result

        Path.write_text = interrupted
        Path.replace = after_publication

    killed_at(lambda: live.mirror(app, out), install)
    assert ((out / "thesis/MANIFEST.json").read_bytes() != before) == published
    if published:
        live.verify(app, out)
        assert verify_clock.sleeps == []
    else:
        with pytest.raises(SystemExit, match="ledger.sqlite|other"):
            live.verify(app, out)
        assert verify_clock.elapsed == live.MIRROR_VERIFY_WAIT
    live.mirror(app, out)
    live.verify(app, out)


def test_verify_source_prefix_mismatch_fails_without_waiting(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock
) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    (app / "data/thesis/day.jsonl").write_text("bad\nnew\n")
    with pytest.raises(SystemExit, match="day.jsonl"):
        live.verify(app, out)
    assert verify_clock.sleeps == []


def test_verify_waits_for_a_healthy_next_manifest(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock
) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    (out / "thesis/other").write_text("replacement")
    manifest = out / "thesis/MANIFEST.json"
    before = manifest.read_bytes()
    verify_clock.on_sleep = lambda: live.mirror(app, out)
    live.verify(app, out)
    assert manifest.read_bytes() != before
    assert 0 < verify_clock.elapsed <= 5


def test_verify_rereads_an_already_changed_manifest_without_waiting(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock
) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    manifest = out / "thesis/MANIFEST.json"
    read = Path.read_text
    captured = []

    def publish_after_read(path, *args, **kwargs):
        text = read(path, *args, **kwargs)
        if path == manifest and not captured:
            captured.append(text)
            live.mirror(app, out)
        return text

    monkeypatch.setattr(Path, "read_text", publish_after_read)
    live.verify(app, out)
    assert captured and manifest.read_text() != captured[0]
    assert verify_clock.sleeps == []


@pytest.mark.parametrize("name", ["other", "day.jsonl"])
def test_verify_refuses_corruption_preserved_across_later_manifest(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock, name
) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    live.mirror(app, out)
    manifest = out / "thesis/MANIFEST.json"
    before = manifest.read_bytes()
    record = json.loads(before)["files"][name]
    target = out / "thesis" / name
    corruption = b"x" * target.stat().st_size
    target.write_bytes(corruption)

    def publish_unrelated_change() -> None:
        (app / "data/thesis/unrelated").write_text("new file")
        live.mirror(app, out)
        assert manifest.read_bytes() != before
        assert target.read_bytes() == corruption
        assert json.loads(manifest.read_text())["files"][name] == record

    verify_clock.on_sleep = publish_unrelated_change
    with pytest.raises(SystemExit, match=name):
        live.verify(app, out)
    assert 0 < verify_clock.elapsed <= 5


@pytest.mark.parametrize("damage", ["missing", "corrupt"])
def test_verify_bounds_wait_without_a_new_manifest(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock, damage
) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    target = out / "thesis/other"
    if damage == "missing":
        target.unlink()
    else:
        target.write_bytes(b"wrong")
    with pytest.raises(SystemExit, match="other"):
        live.verify(app, out)
    assert verify_clock.elapsed == live.MIRROR_VERIFY_WAIT


@pytest.mark.parametrize("damage", ["missing", "shorter"])
def test_mirror_still_refuses_lost_published_bytes(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, damage) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    target = out / "thesis/day.jsonl"
    if damage == "missing":
        target.unlink()
    else:
        target.write_bytes(b"o")
    with pytest.raises(SystemExit, match="lost bytes"):
        live.mirror(app, out)


def test_mirror_documentation_states_snapshot_order_and_missing_manifest_refusal() -> None:
    section = (Path(__file__).resolve().parents[1] / "CLUSTER.md").read_text().split("## 5.")[1].split("## 6.")[0]
    assert "day-file sizes before listing" in section
    assert "copies only those prefixes" in section
    assert "refuses a missing manifest" in section


def test_manifests_keep_the_boundaries() -> None:
    for name in live.WORKLOADS:
        m = live.manifest(name, "sha256:0")
        spec = m["spec"].get("template", m["spec"].get("jobTemplate", {}).get("spec", {}).get("template"))["spec"]
        c, runner = spec["containers"][0], live.WORKLOADS[name][3]
        claims = {v["persistentVolumeClaim"]["claimName"] for v in spec["volumes"] if "persistentVolumeClaim" in v}
        assert claims <= set(live.VOLUMES) | {"mirror"} and not claims & {"inputs", "results"}
        assert [e["valueFrom"]["secretKeyRef"]["key"] for e in c["env"] if e["name"] == "CLAUDE_CODE_OAUTH_TOKEN"] == (
            [runner] if runner else []
        )
        assert (spec.get("hostUsers") is False) == bool(runner)
        assert ("keys" in {v["name"] for v in spec["volumes"]}) == (name == "datalayer")
        assert spec["securityContext"]["seccompProfile"]["type"] == ("Localhost" if runner else "RuntimeDefault")
        assert c["securityContext"]["readOnlyRootFilesystem"] and c["securityContext"]["capabilities"] == {
            "drop": ["ALL"]
        }
        assert not spec["automountServiceAccountToken"] and spec["priorityClassName"] == live.NAMESPACE
        assert c["image"].startswith(live.jobs.REGISTRY + "@sha256:")
    assert {n for n, w in live.WORKLOADS.items() if w[3]} == {"thesis", "agent-series", "agent-real"}
    assert live.manifest("thesis", "sha256:0")["spec"]["updateStrategy"] == {"type": "OnDelete"}
    json.dumps([live.manifest(n, "sha256:0") for n in live.WORKLOADS])


def test_mirror_verify_wait_fits_job_deadline_and_mounts_mirror_read_only() -> None:
    assert live.MIRROR_VERIFY_WAIT == 2 * 10 * 60
    job = live.manifest("mirror-verify", "sha256:0")["spec"]["jobTemplate"]["spec"]
    pod = job["template"]["spec"]
    assert pod["terminationGracePeriodSeconds"] == 600
    for spec in (job, pod):
        if "activeDeadlineSeconds" in spec:
            assert spec["activeDeadlineSeconds"] >= live.MIRROR_VERIFY_WAIT
    mirror = [mount for mount in pod["containers"][0]["volumeMounts"] if mount["name"] == "mirror"]
    assert len(mirror) == 1 and mirror[0]["readOnly"] is True


def test_the_real_campaign_is_one_attempt_on_the_series_volume_and_pool() -> None:
    real, series = (live.manifest(n, "sha256:0")["spec"] for n in ("agent-real", "agent-series"))
    spec = real["template"]["spec"]
    assert real["backoffLimit"] == 0 and spec["restartPolicy"] == "Never"
    assert series["backoffLimit"] == 20 and series["template"]["spec"]["restartPolicy"] == "OnFailure"
    env = spec["containers"][0]["env"]
    assert env == series["template"]["spec"]["containers"][0]["env"] and {e["name"] for e in env} >= {
        "CLAUDE_CODE_OAUTH_TOKEN_TAMU",
        "CLAUDE_CODE_OAUTH_TOKEN_CORNELL",
        "CARGO_TARGET_DIR",
    }
    assert [v["name"] for v in spec["volumes"] if "persistentVolumeClaim" in v] == ["agent"]
    command = spec["containers"][0]["command"]
    assert command[-3:] == ["agent-real", "data/agent/real", "1792613363942"]


def test_the_mirror_appends_refuses_rewritten_history_and_snapshots_ledgers(tmp_path: Path, verify_clock) -> None:
    app, out = tmp_path / "app", tmp_path / "mirror"
    live_dir, thesis = app / "data/live", app / "data/thesis"
    for path in live.VOLUMES.values():
        (app / path).mkdir(parents=True)
    (live_dir / "polls-1.jsonl").write_text('{"a":1}\n')
    with sqlite3.connect(thesis / "ledger.sqlite") as db:
        db.execute("create table t (x)"), db.execute("insert into t values (1)")
    live.mirror(app, out)
    with open(live_dir / "polls-1.jsonl", "a") as f:
        f.write('{"a":2}\n')
    live.mirror(app, out)
    assert (out / "hl/polls-1.jsonl").read_text() == '{"a":1}\n{"a":2}\n'
    manifest = json.loads((out / "hl/MANIFEST.json").read_text())["files"]
    assert manifest["polls-1.jsonl"]["size"] == 16
    with sqlite3.connect(out / "thesis/ledger.sqlite") as db:
        assert db.execute("select x from t").fetchall() == [(1,)]
    (live_dir / "polls-1.jsonl").write_text('{"a":9}\n{"a":2}\n{"a":3}\n')
    with pytest.raises(SystemExit):
        live.mirror(app, out)
    (live_dir / "polls-1.jsonl").write_text('{"a":1}\n{"a":2}\n')
    live.mirror(app, out)
    live.verify(app, out)
    (out / "hl/polls-1.jsonl").write_text('{"a":1}\n{"a":3}\n')
    with pytest.raises(SystemExit):
        live.verify(app, out)
    (live_dir / "polls-1.jsonl").unlink()
    with pytest.raises(SystemExit):
        live.mirror(app, out)


@pytest.mark.parametrize("missing", [None, *live.VOLUMES])
def test_verify_refuses_missing_volume_manifests(tmp_path: Path, missing) -> None:
    app, out = tmp_path / "app", tmp_path / "mirror"
    for path in live.VOLUMES.values():
        (app / path).mkdir(parents=True)
    if missing is not None:
        live.mirror(app, out)
        live.verify(app, out)
        (out / missing / "MANIFEST.json").unlink()
    with pytest.raises(SystemExit, match="manifest"):
        live.verify(app, out)


@pytest.mark.parametrize("initial", [False, True])
def test_mirror_copies_only_the_log_prefix_before_body_enumeration(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, initial
) -> None:
    monkeypatch.setattr(live, "VOLUMES", {"datalayer": "data/datalayer"})
    app, out = tmp_path / "app", tmp_path / "mirror"
    source = app / "data/datalayer"
    (source / "raw").mkdir(parents=True)
    old_digest = hashlib.sha256(b"old").hexdigest()
    new_digest = hashlib.sha256(b"new").hexdigest()
    (source / "raw" / f"{old_digest}.gz").write_bytes(gzip.compress(b"old"))
    log = source / "datalayer-20261020.jsonl"
    row = json.dumps({"sha256": old_digest}) + "\n"
    log.write_text(row)
    if not initial:
        live.mirror(app, out)
    manifest = out / "datalayer/MANIFEST.json"
    log.write_text(row * 2)
    rglob = Path.rglob

    def publish_after_listing(path, pattern):
        listed = list(rglob(path, pattern))
        if path == source and pattern == "*":
            (source / "raw" / f"{new_digest}.gz").write_bytes(gzip.compress(b"new"))
            with log.open("a") as fh:
                fh.write(json.dumps({"sha256": new_digest}) + "\n")
        return iter(listed)

    with monkeypatch.context() as patcher:
        patcher.setattr(Path, "rglob", publish_after_listing)
        live.mirror(app, out)
    assert (out / "datalayer" / log.name).read_text() == row * 2
    assert f"raw/{new_digest}.gz" not in json.loads(manifest.read_text())["files"]
    live.verify(app, out)
    live.mirror(app, out)
    live.verify(app, out)
    files = json.loads(manifest.read_text())["files"]
    assert f"raw/{new_digest}.gz" in files
    assert gzip.decompress((out / "datalayer/raw" / f"{new_digest}.gz").read_bytes()) == b"new"


def test_malformed_datalayer_lines_do_not_block_later_volumes(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(live, "VOLUMES", {"datalayer": "data/datalayer", "agent": "data/agent"})
    app, out = tmp_path / "app", tmp_path / "mirror"
    for path in live.VOLUMES.values():
        (app / path).mkdir(parents=True)
    raw = b'{"sha256":\n\xff\n'
    (app / "data/datalayer/day.jsonl").write_bytes(raw)
    live.mirror(app, out)
    assert (out / "datalayer/day.jsonl").read_bytes() == raw
    assert (out / "agent/MANIFEST.json").exists()
    live.verify(app, out)


def test_the_mirror_skips_a_writer_s_transient_tmp_file(tmp_path: Path) -> None:
    """Claude's round 2 review, R7: an atomic write's `.tmp` can vanish between the listing and the copy."""
    app, out = tmp_path / "app", tmp_path / "mirror"
    for path in live.VOLUMES.values():
        (app / path).mkdir(parents=True)
    (app / live.VOLUMES["datalayer"] / "raw").mkdir()
    (app / live.VOLUMES["datalayer"] / "raw" / "ab.tmp").write_bytes(b"partial")
    live.mirror(app, out)
    assert json.loads((out / "datalayer/MANIFEST.json").read_text())["files"] == {}


@pytest.mark.parametrize("note", ["notes.jsonl", "notes.sqlite"])
def test_a_note_an_agent_rewrites_in_its_workspace_never_stops_the_mirror(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, note
) -> None:
    """The thesis brief invites notes in the workspace, which is data/thesis/sessions/<version>/<session>/work, and the
    Write tool replaces a file whole."""
    monkeypatch.setattr(live, "VOLUMES", {"thesis": "data/thesis", "agent": "data/agent"})
    app, out = tmp_path / "app", tmp_path / "mirror"
    for path in live.VOLUMES.values():
        (app / path).mkdir(parents=True)
    work = app / "data/thesis/sessions/thesis-0/main-0/work"
    work.mkdir(parents=True)
    (work / note).write_text('{"idea": "gold"}\n')
    live.mirror(app, out)
    (work / note).write_text('{"idea": "oil"}\n')
    (app / "data/agent/swarm-null-3.jsonl").write_text('{"campaign": 1}\n')
    live.mirror(app, out)
    assert (out / "agent/swarm-null-3.jsonl").read_text() == '{"campaign": 1}\n'


@pytest.mark.parametrize("workspace", ["sessions/thesis-0/main-0/work", "campaign/run/work", "campaign/swarm/A1/work"])
@pytest.mark.parametrize("note", ["notes.jsonl", "notes.sqlite"])
def test_workspace_notes_are_whole_files_not_source_history(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, workspace, note
) -> None:
    monkeypatch.setattr(live, "VOLUMES", {"thesis": "data/thesis"})
    app, out = tmp_path / "app", tmp_path / "mirror"
    rel = Path(workspace) / "nested" / note
    source, target = app / "data/thesis" / rel, out / "thesis" / rel
    source.parent.mkdir(parents=True)
    source.write_bytes(b"a long original note\n")
    live.mirror(app, out)
    source.write_bytes(b"new\n")
    live.verify(app, out)
    live.mirror(app, out)
    assert target.read_bytes() == b"new\n"
    source.unlink()
    live.verify(app, out)
    live.mirror(app, out)
    assert str(rel) not in json.loads((out / "thesis/MANIFEST.json").read_text())["files"]
    live.verify(app, out)
