"""Stage 3 reports: C3.2's count and spreads, and C3.4's per-arm comparison from a real ledger."""

import json
import subprocess
from pathlib import Path

from gate import kernel, stage3, sweep
from gate.markets import write_market

REPO = Path(__file__).resolve().parents[2]


def test_c32_report_counts_crashes(tmp_path, monkeypatch):
    monkeypatch.setattr(stage3, "OUT", tmp_path)
    monkeypatch.setattr(sweep, "OUT", tmp_path)
    run = lambda i, p: {"id": f"c32-N2-{i}", "search": {"spa_p": 0.5, "max_dsr": 0.1 * i, "screened": []}, "promoted": p}
    (tmp_path / "c32.jsonl").write_text("".join(json.dumps(r) + "\n" for r in
                                                [run(i, ["x"] if i == 3 else []) for i in range(19)] + [{"id": "c32-N2-19", "crash": "x"}]))
    (tmp_path / "c24.jsonl").write_text(json.dumps({"id": "c24-N2-G100-0", "search": {"spa_p": 0.9, "max_dsr": 0.2, "screened": ["a"]}}) + "\n")
    r = stage3.report_c32()
    assert (r["n"], r["promoted"], r["pass"]) == (20, 2, True)
    assert r["arm_a"]["max_dsr"]["n"] == 19 and r["g100_c24_n2"]["screened"]["max"] == 1


def test_comparison_reads_distinct_strategies_from_the_ledger(tmp_path):
    kernel.build()
    m = write_market(tmp_path / "m", days=30)
    ledger = tmp_path / "l.sqlite"
    for agent in ("A", "A", "G100"):
        subprocess.run([str(stage3.MM), "eval", str(REPO / "kernel/strategies/w0.json"), "--campaign", "c", "--agent", agent,
                        "--store", str(m / "store"), "--venue", str(m / "venue"), "--ledger", str(ledger)], check=True, capture_output=True)
    arm = lambda ev, mech: {"evaluations": ev, "search": {"n": 1, "spa_p": 0.4, "screened": [], "finalists": []}, "mechanism": mech,
                            "holdout": {"holm": {"h": 0.3}, "holdout_p": {"h": 0.2}, "holdout_total_return": {"h": 0.01}}, "promoted": []}
    c = stage3.comparison({"id": "c", "A": arm(2, {"h": {"pass": False}}), "B": arm(1, {})}, ledger)
    assert c["A"]["distinct_canonical"] == 1 and c["A"]["evaluations"] == 2 and c["A"]["mechanism_failures"] == ["h"]
    assert c["B"]["holdout"]["h"] == {"return": 0.01, "p": 0.2, "holm": 0.3} and c["statement"] == stage3.NO_CLAIM


def test_c45_report_counts_short_and_crashed_campaigns(tmp_path, monkeypatch):
    from gate import stage4

    monkeypatch.setattr(stage4, "OUT", tmp_path)
    monkeypatch.setattr(sweep, "OUT", tmp_path)
    rows = [{"id": f"c45-N2-{i}", "counts_as_promotion": i == 9, "evaluations": 300, "search": {"spa_p": 0.3, "max_dsr": 0.0, "screened": []}}
            for i in range(10)]
    (tmp_path / "c45.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))
    (tmp_path / "c24.jsonl").write_text("")
    r = stage4.report_c45()
    assert (r["n"], r["counted_promotions"], r["pass"]) == (10, 1, True) and r["h400_c24_n2"]["spa_p"] is None
