"""Fresh workers must not inherit thread locks, mutable settings or campaign randomness."""

import json
import multiprocessing
import os
import subprocess
import sys
import threading

import numpy as np
import pytest

from gate import campaign, compute, kernel
from ops.crossmachine import rows

LOCK = threading.Lock()


def acquire_lock():
    with LOCK:
        return multiprocessing.get_start_method()


def test_pool_does_not_copy_a_live_threads_lock():
    ready, release = threading.Event(), threading.Event()

    def hold():
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


def test_pool_keeps_the_campaign_lock_after_its_parent_releases_it(tmp_path):
    log = tmp_path / "series.jsonl"
    with campaign.exclusive(log) as fh:
        pool = compute.Pool(2, initializer=campaign.KeepLock(fh))
    try:
        assert pool.apply_async(os.getpid).get(timeout=10) != os.getpid()
        with pytest.raises(RuntimeError, match="another run"):
            with campaign.exclusive(log):
                pytest.fail("pool lost the lock")
    finally:
        pool.terminate()
        pool.join()
    with campaign.exclusive(log):
        pass


@pytest.mark.parametrize("model", ["N1", "N2", "N3"])
def test_campaign_results_and_ledgers_agree_across_start_methods(tmp_path, model, built_kernel):
    script = """
import json, multiprocessing, sys
from pathlib import Path
from gate import campaign
if __name__ == '__main__':
    spec = json.loads(Path(sys.argv[1]).read_text())
    with multiprocessing.get_context(sys.argv[2]).Pool(1) as pool:
        result = pool.apply(campaign.run_campaign, (spec, Path(sys.argv[3])))
    Path(sys.argv[3], 'result.json').write_text(json.dumps(result))
"""
    from gate import markets

    params = markets.null_params().get(model)
    if params:
        funding = np.arange(48 * 12).reshape(48, 12)
        params["funding"] = {"arrays": [(funding / 1e7).tolist(), (funding / 1e5).tolist()],
                             "coins": [f"S{i}" for i in range(12)], "block_hours": 24}
    spec = {"id": f"start-method-{model}", "model": model, "params": params, "searcher": "G10", "days": 40,
            "holdout_days": 10, "planted": [0, 1], "beta": 0.01, "cost_cells": markets.FLAT_COST,
            "events": {"arrays": np.arange(300).reshape(-1, 1).tolist(), "coins": [0], "block_hours": 24}}
    source, program = tmp_path / "spec.json", tmp_path / "compare.py"
    source.write_text(json.dumps(spec))
    program.write_text(script)
    results, ledgers = [], []
    for method in ("fork", "forkserver"):
        out = tmp_path / method
        subprocess.run([sys.executable, str(program), str(source), method, str(out)], check=True, timeout=60,
                       env={**os.environ, "PYTHONPATH": str(kernel.REPO)})
        result = json.loads((out / "result.json").read_text())
        assert "crash" not in result, result.get("crash")
        results.append({k: v for k, v in result.items() if k != "seconds"})
        ledgers.append(rows(out / spec["id"] / "ledger.sqlite.xz"))
    assert results[0] == results[1]
    assert ledgers[0] == ledgers[1]
