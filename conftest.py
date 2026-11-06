import fcntl
import os
import sys
import threading
from functools import partial
from pathlib import Path
from time import sleep

import pytest

PAGE = os.sysconf("SC_PAGE_SIZE")


def watch(limit, capture):
    """Ends this process when its resident memory passes `limit`. Under xdist the run reports the worker's crash and its test."""
    while int(Path("/proc/self/statm").read_text().split()[1]) * PAGE <= limit:
        sleep(0.1)
    capture.suspend_global_capture(in_=True)
    print(f"worker_memory_gb exceeded: resident memory over {limit} bytes", file=sys.stderr, flush=True)
    os._exit(1)


def pytest_addoption(parser):
    parser.addini("worker_memory_gb", "Resident memory at which a pytest process ends, in GiB (children are not counted)", default="2")


def pytest_configure(config):
    if config.getoption("numprocesses", default=None) or hasattr(config, "workerinput"):
        for name in ("POLARS_MAX_THREADS", "OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS"):
            os.environ.setdefault(name, "1")
    limit = int(float(config.getini("worker_memory_gb")) * 2**30)
    threading.Thread(target=watch, args=(limit, config.pluginmanager.getplugin("capturemanager")), daemon=True).start()


def build_once(directory, name, build):
    """Share successful builds across this session's workers, never across later runs."""
    with (directory / f"{name}.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        done = directory / f"{name}.built"
        if not done.exists():
            build()
            done.touch()


@pytest.fixture(scope="session")
def session_build(tmp_path_factory, request):
    directory = tmp_path_factory.getbasetemp()
    if hasattr(request.config, "workerinput"):
        directory = directory.parent
    return partial(build_once, directory)


@pytest.fixture(scope="session")
def built_kernel(session_build):
    from gate import kernel

    session_build("kernel", kernel.build)
    return kernel.MM
