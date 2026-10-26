"""The frozen C7.6 suite meets its own requirements: at least 1,000 distinct generated pairs, at least 100 in each
structural class, every code among the hand cases, and the committed files equal to what the generator gives."""

import json
from collections import Counter
from pathlib import Path

from kernel.tests.rules import suite

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
