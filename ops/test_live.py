"""The live workloads' manifests keep CLUSTER.md's boundaries: only live volumes, the datalayer keys only in its
recorder, restricted pods with read-only roots."""

import gzip
import hashlib
import json
import multiprocessing
import shutil
import sqlite3
import time
from collections.abc import Callable, Iterator
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import live
import pytest
from jobs import REGISTRY


def killed_at(action: Callable[[], object], install: Callable[[Callable[[], None]], None]) -> None:
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


def changing_mirror(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> tuple[Path, Path]:
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
def verify_clock(monkeypatch: pytest.MonkeyPatch) -> SimpleNamespace:
    clock = SimpleNamespace(elapsed=0, sleeps=[], on_sleep=lambda: None)

    def sleep(seconds: float) -> None:
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


@pytest.mark.local
@pytest.mark.parametrize("initial", [False, True])
def test_killed_whole_file_copy_never_publishes_partial_target(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, initial: bool
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

    def install(stop: Callable[[], None]) -> None:
        copy = shutil.copy2

        def interrupted(src: Any, dst: Any, *args: Any, **kwargs: Any) -> Any:
            if Path(src) != source:
                return copy(src, dst, *args, **kwargs)
            assert Path(dst) != target and Path(dst).suffix == ".tmp"
            with open(src, "rb") as reader, open(dst, "wb") as writer:
                writer.write(reader.read(1))
                writer.flush()
                stop()

        monkeypatch.setattr(shutil, "copy2", interrupted)

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


@pytest.mark.local
def test_killed_sqlite_backup_preserves_complete_snapshot(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    source = app / "data/thesis/ledger.sqlite"
    target = out / "thesis/ledger.sqlite"
    before = target.read_bytes()
    with sqlite3.connect(source) as db:
        db.execute("create table body (payload)")
        db.execute("insert into body values (zeroblob(65536))")

    def install(stop: Callable[[], None]) -> None:
        connect = sqlite3.connect
        published = target

        class InterruptedConnection(sqlite3.Connection):
            def backup(self, target: sqlite3.Connection, **kwargs: Any) -> None:
                path = Path(target.execute("pragma database_list").fetchone()[2])
                assert path != published and path.suffix == ".tmp"

                def progress(status: int, remaining: int, total: int) -> None:
                    assert remaining > 0
                    stop()

                super().backup(target, pages=1, progress=progress)

        monkeypatch.setattr(sqlite3, "connect", lambda *a, **kw: connect(*a, **kw, factory=InterruptedConnection))

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
        elapsed = [0.0]
        first = [True]

        def pause_after_old_manifest(path: Path, *args: Any, **kwargs: Any) -> str:
            text = read(path, *args, **kwargs)
            if path == manifest and first[0]:
                first[0] = False
                child.send("read old manifest")
                child.recv()
            return text

        def sleep(seconds: float) -> None:
            child.send("waiting for publication")
            child.recv()
            elapsed[0] += seconds

        monkeypatch.setattr(Path, "read_text", pause_after_old_manifest)
        monkeypatch.setattr(live, "time", SimpleNamespace(monotonic=lambda: elapsed[0], sleep=sleep, time=time.time))
        live.verify(app, out)
        child.send("verified")

    process = multiprocessing.get_context("fork").Process(target=verifier)
    process.start()
    try:
        assert parent.poll(10) and parent.recv() == "read old manifest"
        write = Path.write_text
        paused: list[bool] = []

        def before_manifest(path: Path, *args: Any, **kwargs: Any) -> int:
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


@pytest.mark.local
@pytest.mark.parametrize("published", [False, True])
def test_killed_manifest_publication_is_detected_and_recoverable(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock: SimpleNamespace, published: bool
) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    before = (out / "thesis/MANIFEST.json").read_bytes()

    def install(stop: Callable[[], None]) -> None:
        write = Path.write_text
        replace = Path.replace

        def interrupted(path: Path, *a: Any, **kw: Any) -> int:
            if not published and path.name.startswith("MANIFEST.json"):
                stop()
            return write(path, *a, **kw)

        def after_publication(path: Path, *a: Any, **kw: Any) -> Path:
            result = replace(path, *a, **kw)
            if published and path.name == "MANIFEST.json.tmp":
                stop()
            return result

        monkeypatch.setattr(Path, "write_text", interrupted)
        monkeypatch.setattr(Path, "replace", after_publication)

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
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock: SimpleNamespace
) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    (app / "data/thesis/day.jsonl").write_text("bad\nnew\n")
    with pytest.raises(SystemExit, match="day.jsonl"):
        live.verify(app, out)
    assert verify_clock.sleeps == []


def test_verify_waits_for_a_healthy_next_manifest(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock: SimpleNamespace
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
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock: SimpleNamespace
) -> None:
    app, out = changing_mirror(tmp_path, monkeypatch)
    manifest = out / "thesis/MANIFEST.json"
    read = Path.read_text
    captured: list[str] = []

    def publish_after_read(path: Path, *args: Any, **kwargs: Any) -> str:
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
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock: SimpleNamespace, name: str
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
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, verify_clock: SimpleNamespace, damage: str
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
def test_mirror_still_refuses_lost_published_bytes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, damage: str
) -> None:
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
        c = spec["containers"][0]
        claims = {v["persistentVolumeClaim"]["claimName"] for v in spec["volumes"] if "persistentVolumeClaim" in v}
        assert claims <= set(live.CLAIMS) | {"mirror"} and not claims & {"inputs", "results"}
        assert "env" not in c and "hostUsers" not in spec
        assert ("keys" in {v["name"] for v in spec["volumes"]}) == (name == "datalayer")
        assert spec["securityContext"]["seccompProfile"]["type"] == "RuntimeDefault"
        assert c["securityContext"]["readOnlyRootFilesystem"] and c["securityContext"]["capabilities"] == {
            "drop": ["ALL"]
        }
        assert not spec["automountServiceAccountToken"] and spec["priorityClassName"] == live.NAMESPACE
        assert c["image"].startswith(REGISTRY + "@sha256:")
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


def test_the_mirror_appends_refuses_rewritten_history_and_snapshots_ledgers(
    tmp_path: Path, verify_clock: SimpleNamespace
) -> None:
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
def test_verify_refuses_missing_volume_manifests(tmp_path: Path, missing: str | None) -> None:
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
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, initial: bool
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

    def publish_after_listing(path: Path, pattern: str) -> Iterator[Path]:
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
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, note: str
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
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, workspace: str, note: str
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
