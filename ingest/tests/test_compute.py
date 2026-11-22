"""Fresh workers must not inherit thread locks, mutable settings or campaign randomness."""

import multiprocessing
import threading

from ingest import compute

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
