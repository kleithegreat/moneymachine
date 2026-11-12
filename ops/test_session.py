"""ops/session.sh starts a named, logged Claude session for a role, defers a builder while another runs, and detaches an
architect."""

import os
import shutil
import subprocess
import time
from pathlib import Path


def start(tmp_path: Path, busy: bool, *argv: str) -> subprocess.CompletedProcess[str]:
    (tmp_path / "ops").mkdir()
    shutil.copy(Path(__file__).with_name("session.sh"), tmp_path / "ops")
    stubs = tmp_path / "stubs"
    stubs.mkdir()
    for name, code in (("claude", 0), ("pgrep", 0 if busy else 1)):
        (stubs / name).write_text(
            f'#!/bin/sh\necho "$@" >> {tmp_path}/{name}.args\n'
            f'echo "$TMPDIR $CLAUDE_CODE_TMPDIR $(test -d "$TMPDIR" && echo exists)" > {tmp_path}/{name}.env\n'
            f"exit {code}\n"
        )
        (stubs / name).chmod(0o755)
    (stubs / "systemd-run").write_text(f"""#!/bin/sh
echo "$@" >> {tmp_path}/systemd-run.args
case " $* " in *" --scope "*) while [ "$1" != env ]; do shift; done; exec "$@";; esac
""")
    (stubs / "systemd-run").chmod(0o755)
    (stubs / "nix").write_text(f'#!/bin/sh\necho "$@" >> {tmp_path}/nix.args\nshift 2\nexec "$@"\n')
    (stubs / "nix").chmod(0o755)
    env = dict(os.environ, PATH=f"{stubs}:{os.environ['PATH']}")
    return subprocess.run(
        [tmp_path / "ops/session.sh", "run", *argv], cwd=tmp_path, env=env, check=True, capture_output=True, text=True
    )


def log(tmp_path: Path, lines: int) -> list[list[str]]:
    path = tmp_path / "data/builder/log.tsv"
    deadline = time.time() + 10
    while time.time() < deadline and (not path.exists() or len(path.read_text().splitlines()) < lines):
        time.sleep(0.05)
    return [line.split("\t") for line in path.read_text().splitlines()]


def test_run_starts_a_named_session_and_logs_its_id(tmp_path: Path) -> None:
    start(tmp_path, False, "builder", "stage 3 check", "sonnet")
    (started, exited), args = log(tmp_path, 2), (tmp_path / "claude.args").read_text()
    assert [started[1], exited[1]] == ["start", "exit 0"]
    assert started[2] == exited[2] and started[3:] == ["sonnet", "builder: stage 3 check"]
    assert f"-p --name builder: stage 3 check --model sonnet --permission-mode auto --session-id {started[2]} " in args
    assert (tmp_path / "nix.args").read_text().startswith(f"develop -c {tmp_path}/stubs/claude -p ")
    assert (tmp_path / f"data/builder/{started[2]}.out").exists()
    scope = (tmp_path / "systemd-run.args").read_text()
    assert f"--unit=mm-builder-{started[2]} " in scope and "-p OOMPolicy=continue " in scope and "MemoryMax=" in scope
    assert "RuntimeMaxSec" not in scope


def test_a_session_has_its_own_temporary_directory_removed_when_it_exits(tmp_path: Path) -> None:
    start(tmp_path, False, "builder", "stage 3 check", "sonnet")
    started = log(tmp_path, 2)[0]
    tmp = f"/tmp/b{started[2][:4]}"
    assert (tmp_path / "claude.env").read_text().split() == [tmp, tmp, "exists"]
    assert not Path(tmp).exists()


def test_a_stop_time_bounds_the_scope(tmp_path: Path) -> None:
    start(tmp_path, False, "builder", "stage 3 check", "sonnet", "+1 hour")
    limit = (tmp_path / "systemd-run.args").read_text().split("RuntimeMaxSec=")[1].split()[0]
    assert 3590 <= int(limit) <= 3600


def test_a_builder_defers_while_another_builder_runs(tmp_path: Path) -> None:
    start(tmp_path, True, "builder", "stage 3 check", "sonnet")
    busy, scheduled = log(tmp_path, 2)
    assert [busy[1], scheduled[1]] == ["busy", "scheduled"] and not (tmp_path / "claude.args").exists()
    assert (
        (tmp_path / "systemd-run.args").read_text().rstrip().endswith("ops/session.sh run builder stage 3 check sonnet")
    )


def test_an_architect_detaches_with_the_explicit_fable_model_and_logs_it(tmp_path: Path) -> None:
    (tmp_path / "data/builder").mkdir(parents=True)
    (tmp_path / "data/builder/architect-header.txt").write_text("HEADER\n")
    brief = tmp_path / "brief.txt"
    brief.write_text("BRIEF\n")
    done = start(tmp_path, False, "architect", "design", "--brief", str(brief), "--dir", str(tmp_path))
    started, exited = log(tmp_path, 2)
    assert done.stdout.strip() == started[2] == exited[2]
    assert [started[1], exited[1]] == ["start", "exit 0"]
    assert started[3:] == ["claude-fable-5-2[1m]", "architect: design"]
    args = (tmp_path / "claude.args").read_text()
    assert "--model claude-fable-5-2[1m] --effort xhigh --permission-mode auto --session-id" in args
    assert args.endswith("HEADER BRIEF\n") or "HEADER\nBRIEF" in args
    assert not Path(f"/tmp/a{started[2][:4]}").exists()
