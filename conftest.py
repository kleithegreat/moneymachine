import re
import resource
from pathlib import Path


def data_size():
    return int(re.search(r"VmData:\s+(\d+) kB", Path("/proc/self/status").read_text()).group(1)) * 1024


def pytest_addoption(parser):
    parser.addini("worker_memory_gb", "What each pytest process and its children may allocate beyond their imports, in GiB", default="4")


def pytest_configure(config):
    """RLIMIT_DATA over the reservations of numpy's and scipy's OpenBLAS, which scale with the host's cores (3.2 GiB on 12)."""
    import numpy  # noqa: F401
    import polars  # noqa: F401
    import scipy.linalg  # noqa: F401

    limit = data_size() + int(float(config.getini("worker_memory_gb")) * 2**30)
    resource.setrlimit(resource.RLIMIT_DATA, (limit, resource.getrlimit(resource.RLIMIT_DATA)[1]))
