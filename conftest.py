import os
import sys
import threading
from pathlib import Path
from time import sleep

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
    limit = int(float(config.getini("worker_memory_gb")) * 2**30)
    threading.Thread(target=watch, args=(limit, config.pluginmanager.getplugin("capturemanager")), daemon=True).start()
