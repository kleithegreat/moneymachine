import json
import os
import signal
import subprocess
import time
from pathlib import Path
from types import SimpleNamespace

import pytest

from ops import shards


@pytest.fixture
def worktree(tmp_path: Path):
    repo = tmp_path / "work tree"
    repo.mkdir()
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    for name in ("flake.nix", "modified.py", "deleted.py"):
        (repo / name).write_text("original\n")
    (repo / ".gitignore").write_text("data/\n.keys.env\nforced.py\n")
    subprocess.run(["git", "add", "."], cwd=repo, check=True)
    subprocess.run(
        ["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "initial"],
        cwd=repo,
        check=True,
    )
    return repo


def test_arguments(worktree) -> None:
    assert shards.arguments([str(worktree)]) == (worktree, ["local", "prodesk5", "gmktec", "prodesk7"], [])
    assert shards.arguments([str(worktree), "-k", "one or two", "ops", "--machines", "local,gmktec"]) == (
        worktree,
        ["local", "gmktec"],
        ["-k", "one or two", "ops"],
    )


@pytest.mark.parametrize(
    "machines", ["prodesk7", "prodesk5", "local,192.168.8.222", "local,local", "local;touch /tmp/no"]
)
def test_refuses_unapproved_machines_before_any_subprocess(
    monkeypatch: pytest.MonkeyPatch, machines, capsys: pytest.CaptureFixture[str]
) -> None:
    def unexpected(*args, **kwargs) -> None:
        pytest.fail("refusal must precede even local subprocesses")

    monkeypatch.setattr(shards.subprocess, "run", unexpected)
    with pytest.raises(SystemExit) as e:
        shards.arguments(["/nonexistent", "--machines", machines])
    assert e.value.code == 2
    assert "refused" in capsys.readouterr().err


@pytest.mark.parametrize(
    "args", [[], ["/nonexistent"], [".", "--basetemp=/tmp/outside"], [".", "-n", "3"], [".", "-p", "x"]]
)
def test_bad_arguments(args) -> None:
    with pytest.raises(SystemExit) as e:
        shards.arguments(args)
    assert e.value.code == 2


def test_rejects_nonroot_and_nonflake_worktrees(worktree) -> None:
    child = worktree / "child"
    child.mkdir()
    with pytest.raises(SystemExit):
        shards.arguments([str(child)])
    (worktree / "flake.nix").unlink()
    with pytest.raises(SystemExit):
        shards.arguments([str(worktree)])


def test_manifest_is_current_tree_without_ignored_data_and_names_deletions(worktree) -> None:
    (worktree / "modified.py").write_text("dirty\n")
    (worktree / "deleted.py").unlink()
    (worktree / "new file.py").write_text("new\n")
    (worktree / ".keys.env").write_text("secret\n")
    (worktree / "data").mkdir()
    (worktree / "data/store").write_text("not shipped\n")
    kept, gone = shards.files(worktree)
    assert set(kept.split(b"\0")) == {b"", b".gitignore", b"flake.nix", b"modified.py", b"new file.py"}
    assert gone == b"deleted.py\0"
    (worktree / "escape").symlink_to(worktree.parent)
    with pytest.raises(ValueError, match="escapes"):
        shards.files(worktree)


def test_assignment_places_every_test_once_balanced_by_duration_and_speed() -> None:
    local_only = shards.LOCAL_ONLY[0] + "[x]"
    ids = [f"t.py::a{i}" for i in range(40)] + ["t.py::big", local_only]
    durations = {"t.py::big": 100.0, local_only: 5.0} | {f"t.py::a{i}": 1.0 for i in range(40)}
    cores = {"local": 12, "prodesk5": 6, "gmktec": 8}
    parts = shards.assign(ids, durations, cores, {})
    assert sorted(i for p in parts.values() for i in p) == sorted(ids)
    assert local_only in parts["local"] and "t.py::big" in parts["local"]
    finish = {m: sum(durations[i] for i in p) / cores[m] for m, p in parts.items()}
    assert max(finish.values()) - min(finish.values()) <= 100.0 / 12 + 1.0
    assert sum(len(p) for p in parts.values()) == len(ids)
    assert shards.assign(ids, {}, cores, {}) == shards.assign(ids, {}, cores, {})


def test_a_machine_with_overhead_gets_fewer_tests_and_overhead_is_learned_from_the_wall() -> None:
    ids = [f"t.py::a{i}" for i in range(60)]
    durations = {i: 1.0 for i in ids}
    cores = {"local": 10, "gmktec": 10}
    parts = shards.assign(ids, durations, cores, {"gmktec": 3.0})
    assert len(parts["gmktec"]) == 30 - 15 and len(parts["local"]) == 45
    rows = {"a": {"seconds": 40.0}, "b": {"seconds": 20.0}}
    learned = shards.learn_overhead(
        {"gmktec": 10.0},
        {"gmktec": 50.0, "local": 5.0},
        {"a": "gmktec", "b": "gmktec"},
        rows,
        {"gmktec": 4, "local": 12},
    )
    assert learned == {"gmktec": pytest.approx((10.0 + 50.0 - 60.0 / 4) / 2)}


def shim(root, code) -> None:
    (root / "bin").mkdir(parents=True)
    tool = root / "bin" / "nix"
    tool.write_text(
        f'#!/bin/sh\nprintf \'%s\\n\' "$HOME" "$TMPDIR" "$@" > "$HOME/../nix-args"\ncd "$PWD"; '
        f'cat "$HOME/../w/modified.py" "$HOME/../w/new file.py" > "$HOME/../seen"; ls "$HOME/../w" >> "$HOME/../seen"; exit {code}\n'
    )
    tool.chmod(0o755)


def remote(root, tar, env_path):
    with tar.open("rb") as stdin:
        return subprocess.run(
            [
                "bash",
                "-c",
                shards.REMOTE,
                "bash",
                str(root),
                str(root.parent / "tmp"),
                f"{root}/report.run1.json",
                "auto",
            ],
            stdin=stdin,
            capture_output=True,
            text=True,
            env=os.environ | {"PATH": f"{env_path}:{os.environ['PATH']}"},
        )


@pytest.mark.parametrize("code", [0, 1, 5])
def test_remote_script_checks_out_the_dirty_tree_keeps_builds_and_returns_the_status(
    worktree, tmp_path: Path, code
) -> None:
    root = tmp_path / "runner"
    shim(root, code)
    ids = ["ops/test_x.py::test[one two]", "ops/test_y.py::test_z"]
    for round_ in range(2):
        (worktree / "modified.py").write_text(f"dirty {round_}\n")
        (worktree / "deleted.py").unlink(missing_ok=True)
        (worktree / "new file.py").write_text("untracked\n")
        (worktree / ".keys.env").write_text("secret\n")
        tar = tmp_path / "in.tar.gz"
        shards.package(worktree, ids, tar)
        done = remote(root, tar, root / "bin")
        assert done.returncode == code, done.stderr
        seen = (root / "seen").read_text().split("\n")
        assert seen[0] == f"dirty {round_}" and seen[1] == "untracked"
        assert "deleted.py" not in seen and ".keys.env" not in seen and list((root / "w/data").iterdir()) == []
        args = (root / "nix-args").read_text().splitlines()
        assert args[:2] == [str(root / "h"), str(root.parent / "tmp")]
        assert f"@{root}/in/ids" in args and "--basetemp" in args and f"{root}/report.run1.json" in args
        assert not (root / "in").exists() and not (root.parent / "tmp").exists()
        (root / "w/build-output").write_text("kept\n")
        assert subprocess.run(
            ["git", "-C", str(root / "w"), "ls-files", "new file.py"], capture_output=True, text=True
        ).stdout
    assert (root / "w/build-output").read_text() == "kept\n"
    assert Path(root / "lock").exists()


def test_a_waiting_run_leaves_the_previous_runs_report_for_its_controller(worktree, tmp_path: Path) -> None:
    root = tmp_path / "runner"
    shim(root, 0)
    (root / "report.previous.json").write_text("{}")
    tar = tmp_path / "in.tar.gz"
    shards.package(worktree, ["ops/test_x.py::t"], tar)
    assert remote(root, tar, root / "bin").returncode == 0
    assert (root / "report.previous.json").read_text() == "{}"


def test_ssh_notices_a_dead_node() -> None:
    assert "ServerAliveInterval=15" in shards.SSH and "ServerAliveCountMax=4" in shards.SSH


def test_each_node_run_fetches_only_its_own_report(worktree, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    calls = []

    def fake(argv, **kwargs):
        calls.append(argv[-1])
        if "cat" in argv[-1]:
            return SimpleNamespace(returncode=0, stdout=b"{}")
        kwargs["stdin"].read()
        return SimpleNamespace(returncode=255)

    monkeypatch.setattr(shards.subprocess, "run", fake)
    monkeypatch.setattr(shards, "package", lambda worktree, ids, path: Path(path).write_bytes(b"x"))
    for _ in range(2):
        shards.run_node(worktree, "kevin@h", ["a.py::t"], open(os.devnull, "w"), tmp_path / "r.json")
    first, second = [c for c in calls if "cat" in c][0], [c for c in calls if "cat" in c][1]
    assert first != second and "report.json" not in first
    assert all(shards.ROOT + "/report." in c for c in (first, second))
    runs = [c for c in calls if "cat" not in c]
    assert (
        first.split("report.")[1].split(".json")[0] in runs[0]
        and second.split("report.")[1].split(".json")[0] in runs[1]
    )


def test_a_remote_run_dies_with_its_session_and_frees_the_lock(tmp_path: Path) -> None:
    root = tmp_path / "runner"
    shim(root, 0)
    (root / "bin" / "nix").write_text('#!/bin/sh\necho $$ > "$HOME/../nix-pid"\nexec sleep 300\n')
    tar = tmp_path / "in.tar.gz"
    repo = tmp_path / "wt"
    repo.mkdir()
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    (repo / "flake.nix").write_text("x\n")
    subprocess.run(
        ["git", "-c", "user.name=T", "-c", "user.email=t@x.invalid", "commit", "-q", "--allow-empty", "-m", "i"],
        cwd=repo,
        check=True,
    )
    shards.package(repo, ["a.py::t"], tar)
    launcher = subprocess.Popen(
        [
            "sh",
            "-c",
            'setsid bash -c "$1" bash "$2" "$3" "$2/report.run1.json" auto < "$4" & wait',
            "sh",
            shards.REMOTE,
            str(root),
            str(tmp_path / "tmp"),
            str(tar),
        ],
        env=os.environ | {"PATH": f"{root}/bin:{os.environ['PATH']}"},
    )
    pidfile = root / "nix-pid"
    for _ in range(100):
        if pidfile.exists():
            break
        time.sleep(0.1)
    pid = int(pidfile.read_text())
    os.kill(launcher.pid, signal.SIGKILL)
    for _ in range(100):
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            break
        time.sleep(0.2)
    else:
        os.kill(pid, signal.SIGKILL)
        pytest.fail("the remote run outlived its session")
    assert subprocess.run(["flock", "-n", str(root / "lock"), "true"]).returncode == 0


def test_a_test_skipped_on_a_node_is_rerun_here() -> None:
    shard = {"local": ["a"], "prodesk5": ["b", "c", "d"]}
    rows = {"a": {"outcome": "skipped"}, "b": {"outcome": "skipped"}, "c": {"outcome": "passed"}}
    assert shards.rerun(shard, rows) == ["b", "d"]


def test_slowness_comes_from_test_seconds_and_stale_ids_are_pruned(tmp_path: Path) -> None:
    durations = {"a": 10.0, "b": 10.0, "gone": 5.0, "tiny": 0.1}
    rows = {"a": {"seconds": 40.0}, "b": {"seconds": 20.0}, "new": {"seconds": 3.0}, "tiny": {"seconds": 9.0}}
    ran = {"a": "gmktec", "b": "gmktec", "new": "gmktec", "tiny": "gmktec"}
    updated, slowness = shards.update(durations, {"gmktec": 1.0}, ran, rows, ["a", "b", "new", "tiny"], full=True)
    assert slowness["gmktec"] == pytest.approx((1.0 + 3.0) / 2) and "gone" not in updated
    assert updated["a"] == pytest.approx((10.0 + 40.0 / 2.0) / 2) and updated["new"] == pytest.approx(3.0 / 2.0)
    partial, _ = shards.update(durations, {}, {}, {}, ["a"], full=False)
    assert "gone" in partial


def test_durations_are_written_atomically(tmp_path: Path) -> None:
    path = tmp_path / "d" / "durations.json"
    shards.write_durations(path, {"a": 1.0}, {"local": 1.5}, {"local": 2.0})
    assert json.loads(path.read_text()) == {"a": 1.0, shards.SLOWNESS: {"local": 1.5}, shards.OVERHEAD: {"local": 2.0}}
    assert [p.name for p in path.parent.iterdir()] == ["durations.json"]


def test_the_unit_run_holds_its_lifeline_open_until_the_unit_ends_and_cleans_its_stage(
    worktree, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    seen, order = [], []

    class Start:
        def __init__(self, argv, **kwargs) -> None:
            seen.append(argv[-1])
            self.stdin = SimpleNamespace(close=lambda: order.append("closed"))
            assert kwargs["stdin"] == subprocess.PIPE

        def __enter__(self):
            return self

        def __exit__(self, *exc):
            return False

        def wait(self, timeout) -> int:
            order.append("waited")
            return 0

    def fake(argv, **kwargs):
        seen.append(argv[-1])
        if "report.json" in argv[-1]:
            return SimpleNamespace(returncode=0, stdout=b'{"t": {"outcome": "passed"}}')
        if "out.log" in argv[-1]:
            return SimpleNamespace(returncode=0, stdout=b"log\n")
        if kwargs.get("stdin"):
            kwargs["stdin"].read()
        return SimpleNamespace(returncode=0, stdout=b"log\n")

    monkeypatch.setattr(shards.subprocess, "run", fake)
    monkeypatch.setattr(shards.subprocess, "Popen", Start)
    monkeypatch.setattr(shards, "package", lambda worktree, ids, path: Path(path).write_bytes(b"x"))
    report = tmp_path / "r.json"
    with open(os.devnull, "w") as log:
        assert shards.run_unit(worktree, "prodesk7", ["a.py::t"], log, report, 3) == 0
    assert json.loads(report.read_text()) == {"t": {"outcome": "passed"}}
    assert order == ["waited", "closed"]
    stage = [c for c in seen if "rm -rf" in c or c.startswith("rm ")]
    assert stage and shards.UNIT_STAGE in stage[-1]
    assert "mkdir -m 750" in seen[0] and seen[1].startswith("sudo mm-tests start ")


@pytest.mark.parametrize("size, kept", [(shards.REPORT_CAP, True), (shards.REPORT_CAP + 1, False)])
def test_an_oversize_unit_report_is_no_report_and_an_oversize_log_is_truncated(
    worktree, monkeypatch: pytest.MonkeyPatch, tmp_path: Path, size, kept
) -> None:
    def fake(argv, **kwargs):
        if "head" in argv[-1]:
            cap = int(argv[-1].split("-c ")[1].split()[0])
            return SimpleNamespace(
                returncode=0, stdout=(b"x" * (size if "report.json" in argv[-1] else shards.LOG_CAP * 2))[:cap]
            )
        if kwargs.get("stdin"):
            kwargs["stdin"].read()
        return SimpleNamespace(returncode=0, stdout=b"")

    class Start:
        stdin = SimpleNamespace(close=lambda: None)

        def __init__(self, *a, **k) -> None:
            pass

        def __enter__(self):
            return self

        def __exit__(self, *e):
            return False

        def wait(self, timeout) -> int:
            return 0

    monkeypatch.setattr(shards.subprocess, "run", fake)
    monkeypatch.setattr(shards.subprocess, "Popen", Start)
    monkeypatch.setattr(shards, "package", lambda worktree, ids, path: Path(path).write_bytes(b"x"))
    report, log = tmp_path / "r.json", tmp_path / "log"
    with log.open("w") as handle:
        shards.run_unit(worktree, "prodesk7", ["a.py::t"], handle, report, 3)
    assert report.exists() is kept
    text = log.read_text()
    assert len(text) < shards.LOG_CAP + 100 and "[log truncated" in text


@pytest.mark.parametrize(("available", "cpus", "expected"), [(64 << 30, 12, 12), (4 << 30, 12, 6), (1, 12, 1)])
def test_the_local_shard_sizes_its_workers_from_free_memory(
    monkeypatch: pytest.MonkeyPatch, available: int, cpus: int, expected: int
) -> None:
    from gate import compute

    monkeypatch.setattr(compute, "available", lambda: available)
    monkeypatch.setattr(os, "cpu_count", lambda: cpus)
    seen: list[list[str]] = []
    monkeypatch.setattr(subprocess, "run", lambda command, **_: seen.append(command) or SimpleNamespace(returncode=0))
    shards.run_local(Path("."), ["a.py::t"], open(os.devnull, "w"), Path("report.json"))
    command = seen[0]
    assert command[command.index("-n") + 1] == str(expected)
