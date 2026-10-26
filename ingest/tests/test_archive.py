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
