"""The frozen C7.6 suite meets its own requirements: at least 1,000 distinct generated pairs, at least 100 in each
structural class, every code among the hand cases, and the committed files equal to what the generator gives."""

import json
from collections import Counter
from pathlib import Path

from kernel.tests.rules import resolver_suite, suite

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


def test_the_resolver_suite_is_frozen_and_large_enough():
    lines = lambda name: [json.loads(l) for l in (HERE / name).read_text().splitlines()]
    gen = resolver_suite.generate()
    assert sum(len(c["queries"]) for c in gen) + sum(len(c["queries"]) for c in resolver_suite.HAND) >= 1000
    assert lines("resolver_hand.jsonl") == resolver_suite.HAND and lines("resolver_generated.jsonl") == gen
