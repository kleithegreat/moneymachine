"""Session builds are shared across workers only after success, never across sessions."""

import subprocess
import sys

import pytest

from conftest import build_once


def test_builds_are_shared_across_processes_but_not_sessions(tmp_path):
    script = """
from pathlib import Path
import sys
from conftest import build_once
root = Path(sys.argv[1])
def build():
    with (root / 'calls').open('a') as f:
        f.write('built\\n')
build_once(root, 'shared', build)
"""
    for name in ("first", "next"):
        directory = tmp_path / name
        directory.mkdir()
        processes = [subprocess.Popen([sys.executable, "-c", script, str(directory)]) for _ in range(4)]
        try:
            assert [p.wait(timeout=30) for p in processes] == [0] * 4
            assert (directory / "calls").read_text() == "built\n"
        finally:
            for p in processes:
                if p.poll() is None:
                    p.kill()
                p.wait()


def test_a_failed_build_is_retried(tmp_path):
    calls = []

    def build():
        calls.append(1)
        if len(calls) == 1:
            raise RuntimeError("compiler failed")

    with pytest.raises(RuntimeError, match="compiler failed"):
        build_once(tmp_path, "kernel", build)
    assert not (tmp_path / "kernel.built").exists()
    build_once(tmp_path, "kernel", build)
    build_once(tmp_path, "kernel", build)
    assert len(calls) == 2
