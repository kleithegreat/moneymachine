"""Thread-safe process pools, using every core as memory allows (CLAUDE.md, Performance)."""

import os
from multiprocessing import get_context
from pathlib import Path

Pool = get_context("forkserver").Pool


def available() -> int:
    """Bytes free to this process: the host's available memory, and its cgroup's MemoryMax less what the cgroup uses."""
    meminfo = dict(line.split(":", 1) for line in Path("/proc/meminfo").read_text().splitlines())
    free = int(meminfo["MemAvailable"].split()[0]) * 1024
    cgroup = Path("/sys/fs/cgroup", Path("/proc/self/cgroup").read_text().split("::", 1)[1].strip().lstrip("/"))
    cap = cgroup / "memory.max"
    if cap.exists() and cap.read_text().strip() != "max":
        free = min(free, int(cap.read_text()) - int((cgroup / "memory.current").read_text()))
    return free


def workers(per_task: int) -> int:
    """As many workers as cores, but only as many as fit in `available()` at `per_task` bytes each, a task's measured
    peak. Results never depend on it: every task is seeded by its id or computed alone."""
    return max(1, min(os.cpu_count() or 1, available() // per_task))
