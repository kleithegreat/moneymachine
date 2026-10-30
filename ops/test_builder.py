"""ops/builder.sh starts a named builder session with a logged id, or defers it while another builder runs."""

import os
import shutil
import subprocess
from pathlib import Path


def launcher(tmp_path, busy):
    (tmp_path / "ops").mkdir()
    shutil.copy(Path(__file__).with_name("builder.sh"), tmp_path / "ops")
    stubs = tmp_path / "stubs"
    stubs.mkdir()
    for name, code in (("claude", 0), ("systemd-run", 0), ("pgrep", 0 if busy else 1)):
        (stubs / name).write_text(f'#!/bin/sh\necho "$@" >> {tmp_path}/{name}.args\nexit {code}\n')
        (stubs / name).chmod(0o755)
    (stubs / "nix").write_text(f'#!/bin/sh\necho "$@" >> {tmp_path}/nix.args\nshift 2\nexec "$@"\n')
    (stubs / "nix").chmod(0o755)
    env = dict(os.environ, PATH=f"{stubs}:{os.environ['PATH']}")
    subprocess.run([tmp_path / "ops/builder.sh", "run", "stage 3 check", "sonnet"], env=env, check=True)
    return [line.split("\t") for line in (tmp_path / "data/builder/log.tsv").read_text().splitlines()]


def test_run_starts_a_named_session_and_logs_its_id(tmp_path):
    (start, exit_), args = launcher(tmp_path, busy=False), (tmp_path / "claude.args").read_text()
    assert [start[1], exit_[1]] == ["start", "exit 0"] and start[2] == exit_[2] and start[3:] == ["sonnet", "stage 3 check"]
    assert f"-p --name builder: stage 3 check --model sonnet --permission-mode auto --session-id {start[2]} " in args
    assert (tmp_path / "nix.args").read_text().startswith(f"develop -c {tmp_path}/stubs/claude -p ")
    assert (tmp_path / f"data/builder/{start[2]}.out").exists()


def test_run_defers_while_another_builder_runs(tmp_path):
    busy, scheduled = launcher(tmp_path, busy=True)
    assert [busy[1], scheduled[1]] == ["busy", "scheduled"] and not (tmp_path / "claude.args").exists()
    assert (tmp_path / "systemd-run.args").read_text().rstrip().endswith("ops/builder.sh run stage 3 check sonnet")
