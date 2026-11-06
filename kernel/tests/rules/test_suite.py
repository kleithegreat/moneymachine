"""C7.6's frozen rule and resolver suites meet their size, coverage, file and Lean comparison requirements.
The production resolver participants join in slice 5; Lean alone is not a pass of C7.6."""

import json
import subprocess
from collections import Counter
from itertools import islice
from pathlib import Path

import pytest

from kernel.tests.rules import lean_check, resolver_suite, suite

HERE = Path(__file__).resolve().parent


def test_the_generated_cases_cover_each_class():
    gen = suite.generate()
    assert len({json.dumps(c, sort_keys=True) for c in gen}) == len(gen) >= 1000
    counts = Counter(k for c in gen for k in suite.classes(c))
    assert all(counts[k] >= 100 for k in ("floors", "maxima", "offsets", "composition")), counts


def test_the_hand_cases_cover_every_code():
    codes = {c["expect"] for c in suite.HAND if isinstance(c["expect"], str)}
    assert codes == {"E_RULE", "R_ROW", "R_FIELD_ABSENT", "R_FIELD_TYPE", "R_OVERFLOW"}


def test_the_frozen_files_match_the_generator():
    lines = lambda name: [json.loads(l) for l in (HERE / name).read_text().splitlines()]
    assert lines("hand.jsonl") == suite.HAND and lines("generated.jsonl") == suite.generate()


def resolver_cases(name):
    return [json.loads(line) for line in (HERE / f"resolver_{name}.jsonl").read_text().splitlines()]


def test_the_resolver_files_match_hand_and_the_generated_prefix():
    gen = resolver_cases("generated")
    assert lean_check.same(resolver_cases("hand"), resolver_suite.HAND)
    assert lean_check.same(gen, list(islice(resolver_suite.stream(), len(gen))))
    counts = Counter(t for c in gen for t in resolver_suite.classes(c))
    assert all(counts[t] >= resolver_suite.FLOOR for t in resolver_suite.CLASSES), counts


@pytest.fixture(scope="module")
def resolver_results(session_build):
    session_build("lean", lambda: subprocess.run(["lake", "build"], cwd=lean_check.REFMM.parents[3],
                                                capture_output=True, check=True))
    return {"lean": lean_check.lean(resolver_suite.HAND + resolver_cases("generated"), lean_check.REFMM)}


def test_each_resolver_participant_meets_the_frozen_size(resolver_results):
    gen = resolver_cases("generated")
    for name, results in resolver_results.items():
        assert len(results) == len(resolver_suite.HAND) + len(gen), name
        generated = results[len(resolver_suite.HAND):]
        sizes = [resolver_suite.delivered(c, r["result"]) for c, r in zip(gen, generated, strict=True)]
        assert sum(sizes) >= resolver_suite.SIZE, (name, sum(sizes))
        assert sum(sizes[:-1]) < resolver_suite.SIZE, (name, "not the shortest prefix")


def test_lean_matches_every_hand_expectation_and_reaches_every_tag(resolver_results):
    results = resolver_results["lean"]
    hand, generated = results[:len(resolver_suite.HAND)], results[len(resolver_suite.HAND):]
    for c, r in zip(resolver_suite.HAND, hand, strict=True):
        assert lean_check.same(c["expect"], r["result"]), (c, r)
    counts = Counter(t for c, r in zip(resolver_cases("generated"), generated, strict=True)
                     for t in resolver_suite.reached(c, r["result"]))
    assert all(counts[t] >= resolver_suite.FLOOR for t in resolver_suite.REACHED), counts


def test_resolve_all_observations_equal_the_timelines_delivery(resolver_results):
    for c, r in zip(resolver_suite.HAND + resolver_cases("generated"), resolver_results["lean"], strict=True):
        expected = c.get("expect", r["result"])
        if isinstance(expected, dict):
            assert lean_check.same(lean_check.deliveries(c, expected), r["observations"]), (c, r)


def test_result_comparison_keeps_nested_cell_kinds():
    assert not lean_check.same({"cells": [True]}, {"cells": [1]})
    assert not lean_check.same({"cells": [1]}, {"cells": [1.0]})
    assert lean_check.same({"cells": [1.0, None]}, {"cells": [1.0, None]})
