"""Source-blind preservation regressions: CLUSTER §5, paper O2, decision 2026-11-04."""

import errno
import json
import multiprocessing
import sqlite3
from pathlib import Path

import pytest

import live


PLAIN = Path("swarm-null-3-N2-3/swarm/A4/home/.claude/.last-cleanup")


@pytest.fixture
def volume(tmp_path, monkeypatch):
    monkeypatch.setattr(live, "VOLUMES", {"agent": "data/agent"})
    monkeypatch.setattr(live, "MIRROR_VERIFY_WAIT", 0)
    app, out = tmp_path / "app", tmp_path / "mirror"
    root = app / "data/agent"
    root.mkdir(parents=True)
    (root / "survivor").write_bytes(b"complete")
    return app, out, root


def put(root, rel, content=b"original"):
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    return path


def manifest(out):
    return out / "agent/MANIFEST.json"


@pytest.mark.parametrize("published", [False, True])
@pytest.mark.parametrize("phase", ["stat", "copy", "comparison"])
@pytest.mark.parametrize("rel", [PLAIN, Path("campaign/swarm/A4/work/nested/notes.jsonl"),
                                Path("campaign/swarm/A4/work/nested/notes.sqlite")])
def test_plain_source_disappearing_during_mirror_is_omitted(volume, monkeypatch, published, phase, rel):
    app, out, root = volume
    source = put(root, rel)
    if published:
        live.mirror(app, out)
    source.write_bytes(b"a longer replacement")
    stat, rglob, copy, digest = Path.stat, Path.rglob, live.shutil.copy2, live.sha256
    enumerated, copied, vanished = [], [], []

    def listing(path, pattern, *args, **kwargs):
        paths = list(rglob(path, pattern, *args, **kwargs))
        if path == root and source in paths:
            enumerated.append(True)
        return iter(paths)

    def source_stat(path, *args, **kwargs):
        result = stat(path, *args, **kwargs)
        if phase == "stat" and path == source and enumerated and not vanished:
            vanished.append(True)
            source.unlink()
        return result

    def source_copy(src, dst, *args, **kwargs):
        if Path(src) == source:
            if phase == "copy" and not vanished:
                vanished.append(True)
                source.unlink()
            result = copy(src, dst, *args, **kwargs)
            copied.append(True)
            return result
        return copy(src, dst, *args, **kwargs)

    def source_hash(path, *args, **kwargs):
        if phase == "comparison" and Path(path) == source and copied and not vanished:
            vanished.append(True)
            source.unlink()
        return digest(path, *args, **kwargs)

    with monkeypatch.context() as patcher:
        patcher.setattr(Path, "rglob", listing)
        patcher.setattr(Path, "stat", source_stat)
        patcher.setattr(live.shutil, "copy2", source_copy)
        patcher.setattr(live, "sha256", source_hash)
        live.mirror(app, out)
    assert vanished, f"{phase} hook was not exercised"
    files = json.loads(manifest(out).read_text())["files"]
    assert str(rel) not in files
    assert "survivor" in files
    assert (out / "agent/survivor").read_bytes() == b"complete"
    target = out / "agent" / rel
    if published:
        assert target.read_bytes() == b"original"
    else:
        assert not target.exists()
    live.verify(app, out)


@pytest.mark.parametrize("phase", ["enumeration", "copy"])
def test_plain_directory_disappearing_is_allowed(volume, monkeypatch, phase):
    app, out, root = volume
    rel = Path("scratch/nested/note")
    source = put(root, rel)
    live.mirror(app, out)
    source.write_bytes(b"a longer replacement")
    rglob, copy = Path.rglob, live.shutil.copy2
    vanished = []

    def disappear():
        vanished.append(True)
        source.unlink()
        source.parent.rmdir()
        source.parent.parent.rmdir()

    def listing(path, pattern, *args, **kwargs):
        paths = list(rglob(path, pattern, *args, **kwargs))
        if phase == "enumeration" and path == root and source in paths and not vanished:
            disappear()
        return iter(paths)

    def source_copy(src, dst, *args, **kwargs):
        if phase == "copy" and Path(src) == source and not vanished:
            disappear()
        return copy(src, dst, *args, **kwargs)

    with monkeypatch.context() as patcher:
        patcher.setattr(Path, "rglob", listing)
        patcher.setattr(live.shutil, "copy2", source_copy)
        live.mirror(app, out)
    assert vanished
    assert str(rel) not in json.loads(manifest(out).read_text())["files"]
    assert (out / "agent" / rel).read_bytes() == b"original"
    live.verify(app, out)


@pytest.mark.parametrize("name", ["day.jsonl", "ledger.sqlite"])
@pytest.mark.parametrize("phase", ["observed", "previously_manifested"])
def test_recording_disappearance_alarms_without_replacing_manifest(volume, monkeypatch, name, phase):
    app, out, root = volume
    live.mirror(app, out)
    source = root / name
    if name.endswith(".sqlite"):
        with sqlite3.connect(source) as db:
            db.execute("create table recording (id integer)")
            db.execute("insert into recording values (1)")
    else:
        source.write_bytes(b"recorded bytes\n")
    if phase == "previously_manifested":
        live.mirror(app, out)
    before = manifest(out).read_bytes()
    vanished = []
    stat = Path.stat

    def after_observation(path, *args, **kwargs):
        result = stat(path, *args, **kwargs)
        if path == source and not vanished:
            vanished.append(True)
            source.unlink()
        return result

    with monkeypatch.context() as patcher:
        if phase == "observed":
            patcher.setattr(Path, "stat", after_observation)
        else:
            source.unlink()
        with pytest.raises((OSError, SystemExit)) as error:
            live.mirror(app, out)
    if isinstance(error.value, SystemExit):
        assert error.value.code
    if phase == "observed":
        assert vanished
    assert manifest(out).read_bytes() == before


def test_day_disappearing_between_prefix_snapshot_and_general_listing_alarms(volume, monkeypatch):
    app, out, root = volume
    live.mirror(app, out)
    before = manifest(out).read_bytes()
    source = put(root, "day.jsonl", b"recorded bytes\n")
    stat, rglob = Path.stat, Path.rglob
    observed, vanished = [], []

    def observation(path, *args, **kwargs):
        result = stat(path, *args, **kwargs)
        if path == source:
            observed.append(True)
        return result

    def listing(path, pattern, *args, **kwargs):
        if path == root and pattern == "*" and observed and not vanished:
            vanished.append(True)
            source.unlink()
        return rglob(path, pattern, *args, **kwargs)

    with monkeypatch.context() as patcher:
        patcher.setattr(Path, "stat", observation)
        patcher.setattr(Path, "rglob", listing)
        with pytest.raises((OSError, SystemExit)) as error:
            live.mirror(app, out)
    assert vanished
    if isinstance(error.value, SystemExit):
        assert error.value.code
    assert manifest(out).read_bytes() == before


@pytest.mark.parametrize("rel", [PLAIN, Path("day.jsonl")])
@pytest.mark.parametrize("missing", ["source", "mirror", "both", "source_at_hash"])
def test_verify_distinguishes_source_churn_from_missing_mirror(volume, monkeypatch, rel, missing):
    app, out, root = volume
    source = put(root, rel, b"recorded bytes\n")
    live.mirror(app, out)
    before = manifest(out).read_bytes()
    if missing in {"source", "both"}:
        source.unlink()
    if missing in {"mirror", "both"}:
        (out / "agent" / rel).unlink()
    digest, vanished = live.sha256, []

    def source_hash(path, *args, **kwargs):
        if missing == "source_at_hash" and Path(path) == source and not vanished:
            vanished.append(True)
            source.unlink()
        return digest(path, *args, **kwargs)

    monkeypatch.setattr(live, "sha256", source_hash)
    if rel == PLAIN and missing in {"source", "source_at_hash"}:
        live.verify(app, out)
    else:
        with pytest.raises((OSError, SystemExit)) as error:
            live.verify(app, out)
        if isinstance(error.value, SystemExit):
            assert error.value.code
    if missing == "source_at_hash":
        assert bool(vanished) == (rel != PLAIN)
    assert manifest(out).read_bytes() == before


@pytest.mark.parametrize("published", [False, True])
@pytest.mark.parametrize("phase", ["copy", "comparison"])
def test_missing_plain_destination_is_not_source_churn(volume, monkeypatch, published, phase):
    app, out, root = volume
    source = put(root, PLAIN)
    if not published:
        source.unlink()
    live.mirror(app, out)
    before = manifest(out).read_bytes()
    put(root, PLAIN, b"a longer replacement")
    target = out / "agent" / PLAIN
    copy, digest = live.shutil.copy2, live.sha256
    copied, missing = [], []

    def source_copy(src, dst, *args, **kwargs):
        if Path(src) == source:
            if phase == "copy":
                assert not Path(dst).exists()
                missing.append(Path(dst))
                raise FileNotFoundError(errno.ENOENT, "missing copy destination", str(dst))
            result = copy(src, dst, *args, **kwargs)
            copied.append(Path(dst))
            return result
        return copy(src, dst, *args, **kwargs)

    def destination_hash(path, *args, **kwargs):
        if phase == "comparison" and copied and Path(path) in {*copied, target} and not missing:
            missing.append(Path(path))
            Path(path).unlink()
        return digest(path, *args, **kwargs)

    with monkeypatch.context() as patcher:
        patcher.setattr(live.shutil, "copy2", source_copy)
        patcher.setattr(live, "sha256", destination_hash)
        with pytest.raises((OSError, SystemExit)) as error:
            live.mirror(app, out)
    assert missing and not missing[0].exists()
    assert missing[0].is_relative_to(out / "agent")
    if isinstance(error.value, OSError):
        assert error.value.filename == str(missing[0])
    else:
        assert error.value.code
    assert source.read_bytes() == b"a longer replacement"
    assert manifest(out).read_bytes() == before
    if published:
        assert target.read_bytes() == b"original"
    else:
        assert not target.exists()


@pytest.mark.parametrize("error_number", [errno.EACCES, errno.EIO])
@pytest.mark.parametrize("phase", ["stat", "copy", "comparison", "verify"])
def test_io_errors_are_not_treated_as_source_churn(volume, monkeypatch, error_number, phase):
    app, out, root = volume
    source = put(root, PLAIN)
    live.mirror(app, out)
    before = manifest(out).read_bytes()
    source.write_bytes(b"a longer replacement")
    fired, copied = [], []
    stat, copy, digest = Path.stat, live.shutil.copy2, live.sha256

    def fail():
        fired.append(True)
        raise OSError(error_number, "injected storage failure", str(source))

    def source_stat(path, *args, **kwargs):
        if phase == "stat" and path == source:
            fail()
        return stat(path, *args, **kwargs)

    def source_copy(src, dst, *args, **kwargs):
        if Path(src) == source:
            if phase == "copy":
                fail()
            result = copy(src, dst, *args, **kwargs)
            copied.append(True)
            return result
        return copy(src, dst, *args, **kwargs)

    def source_hash(path, *args, **kwargs):
        if phase == "comparison" and Path(path) == source and copied:
            fail()
        if phase == "verify" and Path(path) == out / "agent" / PLAIN:
            fail()
        return digest(path, *args, **kwargs)

    with monkeypatch.context() as patcher:
        patcher.setattr(Path, "stat", source_stat)
        patcher.setattr(live.shutil, "copy2", source_copy)
        patcher.setattr(live, "sha256", source_hash)
        with pytest.raises((OSError, SystemExit)) as error:
            (live.verify if phase == "verify" else live.mirror)(app, out)
    assert fired
    if isinstance(error.value, SystemExit):
        assert error.value.code
    assert manifest(out).read_bytes() == before


def test_sigkill_during_plain_copy_preserves_manifest_and_published_bytes(volume):
    app, out, root = volume
    source = put(root, PLAIN)
    live.mirror(app, out)
    before = manifest(out).read_bytes()
    source.write_bytes(b"a longer replacement")
    context = multiprocessing.get_context("fork")
    parent, child = context.Pipe()

    def worker():
        copy = live.shutil.copy2

        def interrupted(src, dst, *args, **kwargs):
            if Path(src) != source:
                return copy(src, dst, *args, **kwargs)
            with open(dst, "wb") as writer:
                writer.write(b"a")
                writer.flush()
                child.send(str(dst))
                child.recv()

        live.shutil.copy2 = interrupted
        live.mirror(app, out)

    process = context.Process(target=worker)
    process.start()
    try:
        assert parent.poll(10), "copy did not reach the synchronized interruption"
        temporary = Path(parent.recv())
        process.kill()
        process.join(10)
        assert process.exitcode == -9
    finally:
        if process.is_alive():
            process.kill()
            process.join(10)
        parent.close()
        child.close()
    assert temporary != out / "agent" / PLAIN
    assert manifest(out).read_bytes() == before
    assert (out / "agent" / PLAIN).read_bytes() == b"original"
    assert str(temporary.relative_to(out / "agent")) not in json.loads(before)["files"]
    live.verify(app, out)
    live.mirror(app, out)
    assert (out / "agent" / PLAIN).read_bytes() == b"a longer replacement"
    live.verify(app, out)
