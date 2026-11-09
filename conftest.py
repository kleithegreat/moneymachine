import fcntl
import json
import os
import sys
import threading
from functools import partial
from pathlib import Path
from time import sleep

import pytest

PAGE = os.sysconf("SC_PAGE_SIZE")


def watch(limit, capture) -> None:
    """Ends this process when its resident memory passes `limit`. Under xdist the run reports the worker's crash and its test."""
    while int(Path("/proc/self/statm").read_text().split()[1]) * PAGE <= limit:
        sleep(0.1)
    capture.suspend_global_capture(in_=True)
    print(f"worker_memory_gb exceeded: resident memory over {limit} bytes", file=sys.stderr, flush=True)
    os._exit(1)


def pytest_addoption(parser) -> None:
    parser.addoption(
        "--shard-report", default=None, help="write each test's outcome and seconds here as JSON (ops/shards.py)"
    )
    parser.addini(
        "worker_memory_gb",
        "Resident memory at which a pytest process ends, in GiB (children are not counted)",
        default="2",
    )


def pytest_configure(config) -> None:
    if config.getoption("numprocesses", default=None) or hasattr(config, "workerinput"):
        for name in ("POLARS_MAX_THREADS", "OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS"):
            os.environ.setdefault(name, "1")
    limit = int(float(config.getini("worker_memory_gb")) * 2**30)
    threading.Thread(target=watch, args=(limit, config.pluginmanager.getplugin("capturemanager")), daemon=True).start()


ROWS = {}


def pytest_runtest_logreport(report) -> None:
    """With --shard-report (ops/shards.py), the controller keeps each test's outcome, seconds and failure text."""
    row = ROWS.setdefault(report.nodeid, {"outcome": "passed", "seconds": 0.0})
    row["seconds"] += report.duration
    if report.failed:
        row["outcome"] = "failed" if report.when == "call" else "error"
        row["text"] = report.longreprtext[-800:]
    elif report.skipped and row["outcome"] == "passed":
        row["outcome"] = "xfailed" if hasattr(report, "wasxfail") else "skipped"


def pytest_sessionfinish(session) -> None:
    path = session.config.getoption("shard_report")
    if path and not hasattr(session.config, "workerinput"):
        Path(path).write_text(json.dumps(ROWS))


def build_once(directory, name, build) -> None:
    """Share successful builds across this session's workers, never across later runs."""
    with (directory / f"{name}.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        done = directory / f"{name}.built"
        if not done.exists():
            build()
            done.touch()


@pytest.fixture(scope="session")
def session_build(tmp_path_factory: pytest.TempPathFactory, request: pytest.FixtureRequest):
    directory = tmp_path_factory.getbasetemp()
    if hasattr(request.config, "workerinput"):
        directory = directory.parent
    return partial(build_once, directory)


@pytest.fixture(scope="session")
def built_kernel(session_build):
    from gate import kernel

    session_build("kernel", kernel.build)
    return kernel.MM
