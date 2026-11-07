import os
import subprocess
from pathlib import Path

import pytest

from ops import shards


@pytest.fixture
def worktree(tmp_path):
    repo = tmp_path / "work tree"
    repo.mkdir()
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    for name in ("flake.nix", "modified.py", "deleted.py"):
        (repo / name).write_text("original\n")
    (repo / ".gitignore").write_text("data/\n.keys.env\nforced.py\n")
    subprocess.run(["git", "add", "."], cwd=repo, check=True)
    subprocess.run(["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "initial"],
                   cwd=repo, check=True)
    return repo


def test_arguments(worktree):
    assert shards.arguments([str(worktree)]) == (worktree, ["local", "prodesk5", "gmktec"], [])
    assert shards.arguments([str(worktree), "-k", "one or two", "ops", "--machines", "local,gmktec"]) == (
        worktree, ["local", "gmktec"], ["-k", "one or two", "ops"])


@pytest.mark.parametrize("machines", ["local,prodesk7", "prodesk5", "local,192.168.8.222", "local,local", "local;touch /tmp/no"])
def test_refuses_unapproved_machines_before_any_subprocess(monkeypatch, machines, capsys):
    def unexpected(*args, **kwargs):
        pytest.fail("refusal must precede even local subprocesses")

    monkeypatch.setattr(shards.subprocess, "run", unexpected)
    with pytest.raises(SystemExit) as e:
        shards.arguments(["/nonexistent", "--machines", machines])
    assert e.value.code == 2
    assert "prodesk7" in capsys.readouterr().err


@pytest.mark.parametrize("args", [[], ["/nonexistent"], [".", "--basetemp=/tmp/outside"], [".", "-n", "3"], [".", "-p", "x"]])
def test_bad_arguments(args):
    with pytest.raises(SystemExit) as e:
        shards.arguments(args)
    assert e.value.code == 2


def test_rejects_nonroot_and_nonflake_worktrees(worktree):
    child = worktree / "child"
    child.mkdir()
    with pytest.raises(SystemExit):
        shards.arguments([str(child)])
    (worktree / "flake.nix").unlink()
    with pytest.raises(SystemExit):
        shards.arguments([str(worktree)])


def test_manifest_is_current_tree_without_ignored_data_and_names_deletions(worktree):
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


def test_assignment_places_every_test_once_balanced_by_duration_and_speed():
    local_only = shards.LOCAL_ONLY[0] + "[x]"
    ids = [f"t.py::a{i}" for i in range(40)] + ["t.py::big", local_only]
    durations = {"t.py::big": 100.0, local_only: 5.0} | {f"t.py::a{i}": 1.0 for i in range(40)}
    cores = {"local": 12, "prodesk5": 6, "gmktec": 8}
    parts = shards.assign(ids, durations, cores)
    assert sorted(i for p in parts.values() for i in p) == sorted(ids)
    assert local_only in parts["local"] and "t.py::big" in parts["local"]
    finish = {m: sum(durations[i] for i in p) / cores[m] for m, p in parts.items()}
    assert max(finish.values()) - min(finish.values()) <= 100.0 / 12 + 1.0
    assert sum(len(p) for p in parts.values()) == len(ids)
    assert shards.assign(ids, {}, cores) == shards.assign(ids, {}, cores)


def shim(root, code):
    (root / "bin").mkdir(parents=True)
    tool = root / "bin" / "nix"
    tool.write_text(f'#!/bin/sh\nprintf \'%s\\n\' "$HOME" "$TMPDIR" "$@" > "$HOME/../nix-args"\ncd "$PWD"; '
                    f'cat "$HOME/../w/modified.py" "$HOME/../w/new file.py" > "$HOME/../seen"; ls "$HOME/../w" >> "$HOME/../seen"; exit {code}\n')
    tool.chmod(0o755)


def remote(root, tar, env_path):
    with tar.open("rb") as stdin:
        return subprocess.run(["bash", "-c", shards.REMOTE, "bash", str(root), str(root.parent / "tmp")], stdin=stdin, capture_output=True, text=True,
                              env=os.environ | {"PATH": f"{env_path}:{os.environ['PATH']}"})


@pytest.mark.parametrize("code", [0, 1, 5])
def test_remote_script_checks_out_the_dirty_tree_keeps_builds_and_returns_the_status(worktree, tmp_path, code):
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
        assert f"@{root}/in/ids" in args and "--basetemp" in args and f"{root}/report.json" in args
        assert not (root / "in").exists() and not (root.parent / "tmp").exists()
        (root / "w/build-output").write_text("kept\n")
        assert subprocess.run(["git", "-C", str(root / "w"), "ls-files", "new file.py"], capture_output=True, text=True).stdout
    assert (root / "w/build-output").read_text() == "kept\n"
    assert Path(root / "lock").exists()
