"""C7.6's frozen rule and resolver suites meet their size, coverage, file and Lean comparison requirements, and the
production loaders (`store.as_of`'s resolver, `ingest/resolve.py`, and `mm`'s, `kernel/mm/src/resolve.rs`) give Lean's
result and observations on every case with a Parquet image, and GPT's independent resolver (`gpt_resolver.py`) on every
case. A development run is not a pass of C7.6."""

import json
import subprocess
from collections import Counter
from itertools import islice
from pathlib import Path

import pytest

from kernel.tests.rules import gpt_resolver, lean_check, loaders, resolver_suite, suite

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


def cases():
    return resolver_suite.HAND + resolver_cases("generated")


@pytest.fixture(scope="module")
def resolver_results(session_build, built_kernel, tmp_path_factory):
    session_build("lean", lambda: subprocess.run(["lake", "build"], cwd=lean_check.REFMM.parents[3],
                                                capture_output=True, check=True))
    results = {"lean": lean_check.lean(cases(), lean_check.REFMM)}
    for name, run in (("python", loaders.python), ("mm", lambda c, root: loaders.rust(c, root, built_kernel))):
        out = []
        for i, c in enumerate(cases()):
            if resolver_suite.image(c):
                root = tmp_path_factory.mktemp(f"{name}{i}")
                loaders.write_image(c, root)
                out.append(run(c, root))
            else:
                out.append({"result": None, "observations": None})
        results[name] = out
    results["gpt"] = [{"result": gpt_resolver.resolve(json.loads(json.dumps(c))),
                       "observations": gpt_resolver.observations(json.loads(json.dumps(c)))} for c in cases()]
    return results


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


@pytest.mark.parametrize("loader", ["python", "mm"])
def test_each_production_loader_gives_leans_result_and_observations(resolver_results, loader):
    """Named test 1 (observations) and the timelines, on every case with a Parquet image: result and observations equal
    Lean's, delivery by delivery."""
    imaged = [(c, lean, got) for c, lean, got in zip(cases(), resolver_results["lean"], resolver_results[loader], strict=True)
              if resolver_suite.image(c)]
    assert len(imaged) >= 500
    for c, lean, got in imaged:
        assert lean_check.same(got["result"], lean["result"]), (loader, c, got["result"], lean["result"])
        assert lean_check.same(got["observations"], lean["observations"]), (loader, c)


def test_gpts_independent_resolver_gives_leans_result_and_observations(resolver_results):
    """C7.6's spec-only participant, on every case: result and observations equal Lean's."""
    for c, lean, got in zip(cases(), resolver_results["lean"], resolver_results["gpt"], strict=True):
        assert lean_check.same(got["result"], lean["result"]), (c, got["result"], lean["result"])
        if isinstance(lean["result"], dict):
            assert lean_check.same(got["observations"], lean["observations"]), c
