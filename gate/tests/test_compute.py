"""Fresh workers must not inherit thread locks, mutable settings or campaign randomness."""

import multiprocessing
import os
import threading
from pathlib import Path

import pytest

from gate import campaign, compute

LOCK = threading.Lock()


def acquire_lock() -> str:
    with LOCK:
        return multiprocessing.get_start_method()


def test_pool_does_not_copy_a_live_threads_lock() -> None:
    ready, release = threading.Event(), threading.Event()

    def hold() -> None:
        with LOCK:
            ready.set()
            release.wait()

    thread = threading.Thread(target=hold)
    thread.start()
    try:
        assert ready.wait(10)
        with compute.Pool(1) as pool:
            assert pool.apply_async(acquire_lock).get(timeout=10) == "forkserver"
    finally:
        release.set()
        thread.join()


def test_pool_keeps_the_campaign_lock_after_its_parent_releases_it(tmp_path: Path) -> None:
    log = tmp_path / "series.jsonl"
    with campaign.exclusive(log) as fh:
        pool = compute.Pool(2, initializer=campaign.KeepLock(fh))
    try:
        assert pool.apply_async(os.getpid).get(timeout=10) != os.getpid()
        with pytest.raises(RuntimeError, match="another run"), campaign.exclusive(log):
            pytest.fail("pool lost the lock")
    finally:
        pool.terminate()
        pool.join()
    with campaign.exclusive(log):
        pass
