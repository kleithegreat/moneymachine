from kernel.mutants.mutants import failed_by_assertion


def test_only_a_test_failing_by_assertion_counts():
    rust = "thread 't' panicked at mm/tests/fixtures.rs:386:5:\nassertion failed\ntest result: FAILED. 0 passed; 1 failed"
    py = "E   AssertionError\nFAILED kernel/tests/cli/test_cli.py::test_x - AssertionError: assert 1"
    assert failed_by_assertion(rust) and failed_by_assertion(py)
    for log in ["error[E0425]: cannot find value\nerror: could not compile `mm`", "FAILED a.py::t - Failed: Timeout >600.0s",
                "ERROR collecting ingest/tests/test_store.py", "worker_memory_gb exceeded: resident memory over 1 bytes",
                "FAILED a.py::t - KeyError: 'x'"]:
        assert not failed_by_assertion(log)
