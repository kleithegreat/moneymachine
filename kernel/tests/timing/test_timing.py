"""C1.5: the kernel's fill checker and GPT's independent one both match generated labels."""

import importlib.util
import json
import os
import subprocess
from pathlib import Path

import pytest

HERE = Path(__file__).parent
REPO = HERE.parents[2]
spec = importlib.util.spec_from_file_location("timing_gen", HERE / "gen.py")
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


@pytest.fixture(scope="module")
def cases(tmp_path_factory):
    subprocess.run(["cargo", "build", "-q", "--release"], cwd=REPO / "kernel", check=True)
    path = tmp_path_factory.mktemp("t") / "cases.jsonl"
    cs = gen.generate(2000, 11)
    path.write_text("".join(json.dumps(c) + "\n" for c in cs))
    return path, cs


def mismatches(cases, verdicts):
    return [(c["id"], c["kind"], c["label"], v) for c, v in zip(cases, verdicts) if c["label"] != v]


def test_labels_cover_every_violation(cases):
    _, cs = cases
    assert sum(c["label"] != "ok" for c in cs) >= len(cs) / 2 - 100
    assert {c["kind"] for c in cs} >= {"later_bar", "bar_before_submission", "zero_trades", "known_after_decision",
                                       "submitted_before_decision", "filled_before_submission", "notional_cap",
                                       "rolled_to_later_bar", "closeout_stale_bar", "closeout_wrong_reference", "zero_qty"}


def test_kernel_checker_matches_labels(cases):
    path, cs = cases
    mm = Path(os.environ.get("CARGO_TARGET_DIR", REPO / "kernel" / "target")) / "release" / "mm"
    out = subprocess.run([str(mm), "check-fills", str(path)],
                         capture_output=True, text=True, check=True).stdout
    assert mismatches(cs, [json.loads(l)["verdict"] for l in out.splitlines()]) == []


def test_independent_checker_matches_labels(cases):
    _, cs = cases
    spec = importlib.util.spec_from_file_location("independent_checker", HERE / "independent_checker.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    assert mismatches(cs, [mod.check(json.loads(json.dumps(c))) for c in cs]) == []
