import os
import shlex
import subprocess
from pathlib import Path
from types import SimpleNamespace

import pytest

from ops import remote_test as rt


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


@pytest.mark.parametrize("tail, expected", [
    ([], []), (["-q"], ["-q"]), (["prodesk5", "ops/test_progress.py"], ["ops/test_progress.py"]),
    (["192.168.8.229", "-k", "one or two"], ["-k", "one or two"]),
    (["--", "ops/test_progress.py", "-q"], ["ops/test_progress.py", "-q"]),
])
def test_arguments(worktree, tail, expected):
    assert rt.arguments([str(worktree), *tail]) == (worktree, "kevin@192.168.8.229", expected)


@pytest.mark.parametrize("node", ["prodesk7", "PRODESK7", "prodesk7.home.lab", "kevin@prodesk7", "192.168.8.222",
                                "other", "prodesk5; touch /tmp/no", "kevin@192.168.8.229"])
def test_refuses_unapproved_destinations_before_any_subprocess(monkeypatch, node, capsys):
    def unexpected(*args, **kwargs):
        pytest.fail("refusal must precede even local subprocesses")

    monkeypatch.setattr(rt.subprocess, "run", unexpected)
    with pytest.raises(SystemExit) as e:
        rt.main(["/nonexistent", node])
    assert e.value.code == 2
    assert "prodesk7" in capsys.readouterr().err


@pytest.mark.parametrize("args", [[], ["/nonexistent"], [".", "--basetemp=/tmp/outside"], [".", "--", "--"]])
def test_bad_arguments(args):
    with pytest.raises(SystemExit) as e:
        rt.arguments(args)
    assert e.value.code == 2


def test_rejects_nonroot_and_nonflake_worktrees(worktree):
    child = worktree / "child"
    child.mkdir()
    with pytest.raises(SystemExit):
        rt.arguments([str(child)])
    (worktree / "flake.nix").unlink()
    with pytest.raises(SystemExit):
        rt.arguments([str(worktree)])


def test_manifest_is_current_tree_without_ignored_data(worktree):
    (worktree / "modified.py").write_text("dirty\n")
    (worktree / "deleted.py").unlink()
    (worktree / "new file.py").write_text("new\n")
    (worktree / ".keys.env").write_text("secret\n")
    (worktree / "data").mkdir()
    (worktree / "data/store").write_text("not shipped\n")
    assert set(rt.files(worktree).split(b"\0")) == {b"", b".gitignore", b"flake.nix", b"modified.py", b"new file.py"}
    (worktree / "escape").symlink_to(worktree.parent)
    with pytest.raises(ValueError, match="escapes"):
        rt.files(worktree)


def test_bundle_and_rsync_reproduce_dirty_worktree_without_network(worktree, monkeypatch):
    original = subprocess.run
    (worktree / "modified.py").write_text("staged\n")
    original(["git", "add", "modified.py"], cwd=worktree, check=True)
    (worktree / "modified.py").write_text("unstaged\n")
    (worktree / "deleted.py").unlink()
    (worktree / "new file.py").write_text("untracked\n")
    (worktree / "forced.py").write_text("staged despite ignore\n")
    original(["git", "add", "-f", "forced.py"], cwd=worktree, check=True)
    index = original(["git", "diff", "--cached"], cwd=worktree, capture_output=True, check=True).stdout
    head = original(["git", "rev-parse", "HEAD"], cwd=worktree, capture_output=True, check=True).stdout

    def command(argv, **kwargs):
        assert argv[0] != "ssh", "this test must never use the network"
        if argv[0] == "rsync":
            argv = [*argv[:-1], argv[-1].split(":", 1)[1]]
        return original(argv, **kwargs)

    def local_ssh(host, *argv, **kwargs):
        if argv[0] != "bash":
            return original(list(argv), **kwargs)
        repo = Path(argv[4]) / "w"
        assert (repo / "modified.py").read_text() == "unstaged\n"
        assert (repo / "new file.py").read_text() == "untracked\n"
        assert (repo / "forced.py").read_text() == "staged despite ignore\n"
        assert not (repo / "deleted.py").exists()
        assert original(["git", "rev-parse", "HEAD"], cwd=repo, capture_output=True, check=True).stdout == head
        original(["git", "add", "-f", "-A"], cwd=repo, check=True)
        assert b"new file.py" in original(["git", "ls-files"], cwd=repo, capture_output=True, check=True).stdout
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(rt.subprocess, "run", command)
    monkeypatch.setattr(rt, "ssh", local_ssh)
    assert rt.main([str(worktree)]) == 0
    assert original(["git", "diff", "--cached"], cwd=worktree, capture_output=True, check=True).stdout == index


@pytest.mark.parametrize("failure, code", [(None, 0), (None, 1), ("rsync", 23)])
def test_transport_status_quoting_and_cleanup(worktree, monkeypatch, capsys, failure, code):
    original = subprocess.run
    calls = []

    def command(argv, **kwargs):
        if argv[0] == "git":
            return original(argv, **kwargs)
        calls.append((argv, kwargs))
        if argv[0] == failure:
            raise subprocess.CalledProcessError(code, argv)
        return SimpleNamespace(returncode=code if argv[0] == "ssh" and "pytest" in argv[-1] else 0)

    monkeypatch.setattr(rt.subprocess, "run", command)
    expression = "one or two; echo NOT_A_COMMAND"
    assert rt.main([str(worktree), "prodesk5", "-k", expression]) == code
    remote = [shlex.split(c[-1]) for c, _ in calls if c[0] == "ssh"]
    assert remote[-1][:3] == ["rm", "-rf", "--"]
    assert remote[-1][-1].startswith("/tmp/rt.")
    if failure is None:
        invocation = next(c for c in remote if c[0] == "bash")
        assert expression in invocation and all(f"--deselect={t}" in invocation for t in rt.EXCLUDED)
        assert "--basetemp" in invocation and "no:cacheprovider" in invocation
        assert f"exit status: {code}" in capsys.readouterr().out
    transfers = [(c, kw) for c, kw in calls if c[0] == "rsync" and "input" in kw]
    if transfers:
        assert b"modified.py\0" in transfers[0][1]["input"]


@pytest.mark.parametrize("code", [0, 1, 5])
def test_remote_shell_scopes_temp_home_and_cleans_on_failure(tmp_path, code):
    root = tmp_path / "runner"
    for name in ("h", "t", "w", "bin"):
        (root / name).mkdir(parents=True)
    for name, body in (("git", '[ "$*" = "add -f -A" ]'), ("nix", f'''printf '%s\\n' "$HOME" "$XDG_CACHE_HOME" "$TMPDIR" "$@"
exit {code}''')):
        tool = root / "bin" / name
        tool.write_text("#!/bin/sh\n" + body + "\n")
        tool.chmod(0o755)
    result = subprocess.run(["bash", "-c", rt.REMOTE, "bash", str(root), "-q"],
                            env=os.environ | {"PATH": f"{root}/bin:{os.environ['PATH']}"}, capture_output=True, text=True)
    assert result.returncode == code
    assert result.stdout.splitlines()[:3] == [str(root / "h"), str(root / "h/cache"), str(root / "t")]
    assert ["--extra-experimental-features", "nix-command flakes", "develop", "-c", "env",
            f"TMPDIR={root}/t", "pytest", "-q"] == result.stdout.splitlines()[3:]
    assert not root.exists()
