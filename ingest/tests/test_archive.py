"""The archive reducer costs each snapshot by C0.7's own function and censors an order the 20 levels cannot fill."""

import json
import math

from ingest import archive


def line(bids, asks, t=1):
    lv = lambda xs: [{"px": str(p), "sz": str(s), "n": 1} for p, s in xs]
    return json.dumps({"time": "x", "ver_num": 1, "raw": {"channel": "l2Book", "data": {"coin": "X", "time": t,
                                                                                         "levels": [lv(bids), lv(asks)]}}})


def test_costs_and_censoring():
    # $5,050 of asks at 101 and $9,900 of bids at 99 around a mid of 100: $1,000 costs 100 bps either way, and
    # neither side can fill $10,000.
    (t, mid, costs), = archive.reduce([line([(99, 100)], [(101, 50)])])
    assert (t, mid) == (1, 100.0)
    assert math.isclose(costs["buy:1000"], 100.0) and math.isclose(costs["sell:1000"], 100.0)
    assert math.isinf(costs["buy:10000"]) and math.isinf(costs["sell:10000"])
    assert archive.reduce([line([], [(101, 5)])]) == []


def book(t, bid_sz=100, ask_sz=50):
    lv = lambda xs: [{"px": str(p), "sz": str(s), "n": 1} for p, s in xs]
    return {"coin": "X", "time": t, "levels": [lv([(99, bid_sz)]), lv([(101, ask_sz)])]}


def write_archive(root, day, hour, coin, books):
    import gzip

    rows = archive.reduce([json.dumps({"time": "x", "ver_num": 1, "raw": {"channel": "l2Book", "data": b}}) for b in books])
    path = root / day / str(hour) / f"{coin}.json.gz"
    path.parent.mkdir(parents=True)
    path.write_bytes(gzip.compress(json.dumps(rows).encode()))


def test_equivalence_matches_by_book_time_and_requires_every_cell(tmp_path):
    t0 = 1792368000000  # 2026-10-20 00:00 UTC
    write_archive(tmp_path / "a", "20261020", 0, "X", [book(t0 + k * 5000) for k in range(10)])
    live_dir = tmp_path / "live"
    live_dir.mkdir()
    polls = [{"kind": "l2", "coin": "X", "sent": 0, "recv": 0, "data": book(t0 + k * 5000 + 300)} for k in range(10)]
    polls.append({"kind": "l2", "coin": "X", "sent": 0, "recv": 0, "data": book(t0 + 2 * 3_600_000)})
    (live_dir / "polls-20261020.jsonl").write_text("".join(json.dumps(p) + "\n" for p in polls))
    out = archive.equivalence(tmp_path / "a", [live_dir], ["X"])
    x = out["coins"]["X"]
    assert (x["live"], x["matched"]) == (10, 10) and out["pass"]
    assert x["cells"]["buy:10000"]["censoring_agree"] == 1.0 and x["cells"]["buy:1000"]["cost_agree"] == 1.0
    polls = [dict(p, data=book(p["data"]["time"], ask_sz=5)) for p in polls]
    (live_dir / "polls-20261020.jsonl").write_text("".join(json.dumps(p) + "\n" for p in polls))
    assert not archive.equivalence(tmp_path / "a", [live_dir], ["X"])["pass"]


def test_table_keeps_c07_for_a_cell_censored_anywhere(tmp_path):
    t0 = 1780272000000  # 2026-06-01 00:00 UTC
    books = [book(t0 + k * 30_000, ask_sz=50 if k else 500) for k in range(40)]
    write_archive(tmp_path / "a", "20260601", 0, "X", books)
    c07 = tmp_path / "execution.json"
    c07.write_text(json.dumps({"cost_bps_ex_fee": {"X": {s: {"1000": 7.0, "10000": 9.0} for s in ("buy", "sell")}}}))
    t = archive.table(tmp_path / "a", ["X"], c07)
    assert sorted(t["kept_from_c07"]) == ["X:buy:10000", "X:sell:10000"]
    assert t["cost_bps_ex_fee"]["X"]["buy"]["10000"] == 9.0 and math.isclose(t["cost_bps_ex_fee"]["X"]["buy"]["1000"], 100.0)
