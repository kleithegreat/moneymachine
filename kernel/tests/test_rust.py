"""The kernel's cargo tests and its mutants, run by the sharded suite wherever Rust is installed."""

import fcntl
import shutil
import subprocess
import time
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

import pytest

from gate import compute
from kernel.mutants import mutants

REPO = Path(__file__).resolve().parents[2]
needs_rust = pytest.mark.skipif(shutil.which("cargo") is None, reason="no Rust toolchain on this machine")


@contextmanager
def slot() -> Iterator[int]:
    """One of as many mutant slots as free memory fits at `SLOT_BYTES`, across every worker of the run: a slot keeps
    its own cargo target, reused by the mutants that follow."""
    mutants.LOGS.mkdir(parents=True, exist_ok=True)
    while True:
        for i in range(compute.workers(mutants.SLOT_BYTES)):
            with open(mutants.LOGS / f"slot-{i}.lock", "w") as lock:
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    continue
                yield i
                return
        time.sleep(1)


@needs_rust
@pytest.mark.timeout(3600)
def test_the_kernels_cargo_tests_pass() -> None:
    done = subprocess.run(["cargo", "test", "-q", "--release"], cwd=REPO / "kernel", capture_output=True, text=True)
    assert done.returncode == 0, done.stdout[-3000:] + done.stderr[-3000:]


@needs_rust
@pytest.mark.timeout(3600)
@pytest.mark.parametrize("name", mutants.MUTANTS)
def test_the_mutant_is_caught_by_its_test(name: str) -> None:
    with slot() as i:
        result = mutants.check(name, i)
    assert result == f"caught {name}"
