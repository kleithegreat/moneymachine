"""C7.6: the availability rule language's three implementations (`ingest/knownat.py`, `mm rules`, and GPT's independent
`gpt_rules.py`) give every hand case its expected result and agree exactly on every generated case.
The B3 resolver suite's production participants join in slice 5."""

import json
import subprocess
import sys
from pathlib import Path

from gate import kernel
from ingest import knownat
from kernel.tests.rules.lean_check import same

HERE = Path(__file__).resolve().parent


def outputs(command, cases):
    out = subprocess.run(command, input="".join(json.dumps(c) + "\n" for c in cases), capture_output=True, text=True,
                         check=True, timeout=600)
    return [json.loads(l) for l in out.stdout.splitlines()]


def compare(python, mm_command, gpt):
    kernel.build()
    for name in ("hand", "generated"):
        cases = [json.loads(l) for l in (HERE / f"{name}.jsonl").read_text().splitlines()]
        results = {"python": [python(c) for c in cases],
                   "rust": outputs([str(kernel.MM), mm_command, "-"], cases),
                   "gpt": outputs([sys.executable, str(HERE / gpt)], cases)}
        assert all(len(r) == len(cases) for r in results.values())
        for i, c in enumerate(cases):
            got = [results[k][i] for k in ("python", "rust", "gpt")]
            assert all(same(g, got[0]) for g in got), (name, i, c, got)
            if name == "hand":
                assert same(got[0], c["expect"]), (i, c, got[0])


def test_three_rule_implementations_agree_on_the_frozen_suite():
    compare(knownat.result, "rules", "gpt_rules.py")
