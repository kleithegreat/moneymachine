"""The searcher draws the forum-activity feature only where the market carries event counts, and the
kernel runs it there."""

import json
import random
import subprocess
from pathlib import Path

import numpy as np

from gate import kernel, markets, search
from gate.kernel import MM

REPO = Path(__file__).resolve().parents[2]


def test_event_feature_runs_where_events_exist(tmp_path):
    kernel.build()
    events = {"arrays": np.random.default_rng(0).poisson(2.0, (500, 2)).tolist(), "coins": [0, 3], "block_hours": 24}
    plain = markets.write_market(tmp_path / "plain", days=30)
    with_events = markets.write(tmp_path / "ev", markets.generate("N1", None, "ev", 30, events=events), 0,
                                {s: {"1000": 2.0, "10000": 4.0} for s in ("buy", "sell")})
    assert search.features(plain) == 6 and search.features(with_events) == 7
    g = {"sig": ["feat", 6, "close", 24], "size": 0.05, "squash": "sign"}
    p = tmp_path / "p.json"
    p.write_text(json.dumps(search.compile_genome(g)))
    outs = {}
    for name, m in (("plain", plain), ("ev", with_events)):
        r = subprocess.run([str(MM), "eval", str(p), "--campaign", name, "--agent", "t", "--store", str(m / "store"),
                            "--venue", str(m / "venue"), "--ledger", str(tmp_path / "l.sqlite")], capture_output=True, text=True)
        outs[name] = json.loads((r.stdout or r.stderr).strip().splitlines()[-1])
    assert outs["plain"]["code"] == "R_INPUT_UNAVAILABLE"
    assert outs["ev"]["disclosure"]["result"]["fills"] > 0
    rng = random.Random(1)
    assert any(n[1] == 6 for n in (search.random_node(rng, 0, 7) for _ in range(200)))
