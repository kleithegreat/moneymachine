"""C10.3: hand-derived position fixtures, written before the position code (PROGRESS.md, Stage 10).

Times are in hours (H). A thesis enters at the first 1h open at or after t_r + 120 s; exits come at
the first 1h open at or after their actionable time; funding, then exits, then entries at an hour.
Unless a case sets them, fees and costs are 0 and equity starts at $10,000, so b = $100.
"""

import pytest

from thesis import positions

H = 3_600_000
DELTA = 120_000
MIN = 60_000
ZERO_COSTS = {"buy": {"1000": 0.0, "10000": 0.0}, "sell": {"1000": 0.0, "10000": 0.0}}


def flat(price, start=0, end=200, **bars):
    """{openTime: (open, close)} with every hour at `price`, except bars given as h<hour>=(open, close)."""
    out = {h * H: (price, price) for h in range(start, end)}
    for k, v in bars.items():
        h = int(k[1:])
        if v is None:
            del out[h * H]
        else:
            out[h * H] = v
    return out


def thesis(i, t_r, legs, L=0.1, T=96, p=0.6):
    return {"id": i, "t_r": t_r, "legs": legs, "T": T * H, "L": L, "p": p}


def run(theses, bars, exits=(), funding=None, fee=0.0, costs=None, now=200 * H):
    account = {"initial": 10_000.0, "fee": fee, "costs": {m: costs or ZERO_COSTS for m in bars}}
    return positions.run(account, theses, list(exits), {"bars": bars, "funding": funding or {}}, now)


def reconciles(out):
    assert all(abs(e - r) <= 1e-9 for _, e, r in out["equity"])


def test_entry_bar_sizing_and_horizon_exit():
    # t_r = 10:30; 10:32 is after the 10h bar's open, so entry is the 11h open (101), never 100.
    # b = 0.01 * 10,000 = 100, N = b / L = 1000, q = 1000/101. Exit at the 96h open (110).
    bars = {"X": flat(101, h10=(100, 101), **{f"h{h}": (110, 110) for h in range(96, 200)})}
    out = run([thesis("a", 10 * H + 30 * MIN, [["X", 1]])], bars)
    a = out["theses"]["a"]
    assert a["N"] == 1000 and a["size"] == 1000
    assert a["entry"]["t"] == 11 * H and a["entry"]["legs"][0]["ref"] == 101
    assert a["entry"]["legs"][0]["q"] == pytest.approx(1000 / 101, abs=1e-12)
    assert a["exit"]["t"] == 96 * H and a["exit"]["reason"] == "horizon"
    assert a["outcome"]["R_net"] == pytest.approx(9 / 101, abs=1e-12) and a["outcome"]["o"] == 1
    assert a["managed_return"] == pytest.approx(9 / 101, abs=1e-12)
    reconciles(out)


def test_invalidation_waits_for_the_next_open_and_can_gap_through():
    # L = 0.05: N = 2000, q = 20 at 100. The 11h bar closes at 96 (R = -0.04): no trigger.
    # The 12h bar closes (at 13h) at 94.9: R = -0.051 <= -0.05. Actionable at 13h + 120 s, so the 13h
    # open (94.9, simultaneous with the close) is never used: exit at the 14h open, 93.
    # Managed: 20 * (93 - 100) = -140, -0.07 per N: the loss exceeds L.
    # As registered, held to the 96h open (105): R_net = 20 * 5 / 2000 = 0.05, o = 1.
    bars = {"X": flat(93, h11=(100, 96), h12=(96, 94.9), h13=(94.9, 93.5), **{f"h{h}": (105, 105) for h in range(96, 200)})}
    out = run([thesis("a", 10 * H + 30 * MIN, [["X", 1]], L=0.05)], bars)
    a = out["theses"]["a"]
    assert a["entry"]["t"] == 11 * H and a["N"] == 2000
    assert a["exit"]["t"] == 14 * H and a["exit"]["reason"] == "invalidation"
    assert a["managed_return"] == pytest.approx(-0.07, abs=1e-12)
    assert a["outcome"]["R_net"] == pytest.approx(0.05, abs=1e-12) and a["outcome"]["o"] == 1
    reconciles(out)


def test_cap_counts_pending_entries_follows_commit_order_and_frees_on_exit():
    # Six theses at 10:12 .. 10:42, all before the 11h entry: each reserves b = 100 while pending.
    # Five fill the cap (500 = 0.05 * 10,000); the sixth gets size 0, with the same t_r as the fifth
    # (commit order decides). Thesis 1 exits at its discretion at 15:10 (filled at the 16h open), so
    # thesis 7 at 20h finds 400 reserved and is admitted with N = 1000 (prices flat, equity 10,000).
    # Size zero is still scored: hypothetical N = 1000, 100 -> 102 at 96h, R_net = 0.02, o = 1.
    bars = {"X": flat(100, **{f"h{h}": (102, 102) for h in range(96, 200)})}
    ts = [thesis(str(i), 10 * H + (12 + 6 * min(i, 4)) * MIN, [["X", 1]]) for i in range(6)]
    ts.append(thesis("6", 20 * H, [["X", 1]]))
    out = run(ts, bars, exits=[{"id": "0", "t_x": 15 * H + 10 * MIN}])
    sizes = [out["theses"][str(i)]["size"] for i in range(7)]
    assert sizes == [1000] * 5 + [0, 1000]
    z = out["theses"]["5"]
    assert z["entry"] is None and z["outcome"]["R_net"] == pytest.approx(0.02, abs=1e-12) and z["outcome"]["o"] == 1
    assert out["theses"]["0"]["exit"] == {"t": 16 * H, "reason": "discretionary", "legs": [{"ref": 100, "fill": 100}]}
    reconciles(out)


def test_risk_budget_follows_falling_equity():
    # A: L = 0.5, N = 200, q = 2 at 100; the price falls to 90 by the 11h close and stays.
    # At B's t_r (20:30) equity = 10,000 + 2 * (90 - 100) = 9,980, so b = 99.8 and N = 998.
    bars = {"X": flat(90, h11=(100, 90))}
    out = run([thesis("A", 10 * H + 30 * MIN, [["X", 1]], L=0.5), thesis("B", 20 * H + 30 * MIN, [["X", 1]])], bars)
    assert out["theses"]["A"]["N"] == 200
    assert out["theses"]["B"]["N"] == pytest.approx(998, abs=1e-9)
    reconciles(out)


def test_discretionary_exit_is_scored_as_managed_only():
    # q = 10 at 100. Exit committed at 20:10 fills at the 21h open (104): managed 10 * 4 / 1000 = 0.04.
    # As registered, the 96h open is 98: R_net = -0.02, o = 0.
    bars = {"X": flat(100, h21=(104, 104), **{f"h{h}": (98, 98) for h in range(96, 200)})}
    out = run([thesis("a", 10 * H + 30 * MIN, [["X", 1]])], bars, exits=[{"id": "a", "t_x": 20 * H + 10 * MIN}])
    a = out["theses"]["a"]
    assert a["exit"]["t"] == 21 * H and a["managed_return"] == pytest.approx(0.04, abs=1e-12)
    assert a["outcome"]["R_net"] == pytest.approx(-0.02, abs=1e-12) and a["outcome"]["o"] == 0


def test_funding_coincident_with_entry_and_exit():
    # q = 10 from the 11h open. Funding at 11h (0.001) comes before the entry: not paid.
    # 12h: rate 1e-4 on q = 10 at the 12h open (100): the long pays 0.1.
    # 21h: rate -2e-5, before the 21h discretionary exit: the long receives 10 * 2e-5 * 100 = 0.02.
    # Flat prices: managed = (-0.1 + 0.02) / 1000 = -8e-5. Held to 96h with no other rows: the same, o = 0.
    funding = {"X": {11 * H: 0.001, 12 * H: 1e-4, 21 * H: -2e-5}}
    out = run([thesis("a", 10 * H + 30 * MIN, [["X", 1]])], {"X": flat(100)},
              exits=[{"id": "a", "t_x": 20 * H + 10 * MIN}], funding=funding)
    a = out["theses"]["a"]
    assert a["managed_return"] == pytest.approx(-8e-5, abs=1e-15)
    assert a["outcome"]["R_net"] == pytest.approx(-8e-5, abs=1e-15) and a["outcome"]["o"] == 0
    reconciles(out)


def test_costs_and_fees_on_entry_and_exit():
    # The cell follows each fill's traded notional |q| * ref; fee 0.1%. q = N / ref = 10.
    # Buy: 10 * 100 = $1,000, the "1000" cell (10 bps): 100 * 1.001 = 100.1, fee 10 * 100.1 * 0.001 = 1.001.
    # Sell: 10 * 110 = $1,100, the "10000" cell (20 bps): 110 * 0.998 = 109.78, fee 1.0978.
    # R_net = (10 * (109.78 - 100.1) - 1.001 - 1.0978) / 1000 = 0.0947012.
    costs = {"buy": {"1000": 10.0, "10000": 20.0}, "sell": {"1000": 10.0, "10000": 20.0}}
    bars = {"X": flat(100, **{f"h{h}": (110, 110) for h in range(96, 200)})}
    out = run([thesis("a", 10 * H + 30 * MIN, [["X", 1]])], bars, fee=0.001, costs=costs)
    a = out["theses"]["a"]
    assert a["entry"]["legs"][0]["fill"] == pytest.approx(100.1, abs=1e-12)
    assert a["outcome"]["R_net"] == pytest.approx(0.0947012, abs=1e-12)
    reconciles(out)


def test_short_and_spread():
    # Short C: q = -10 at 100, 90 at 96h: R_net = 0.1, o = 1.
    # Spread long A short B, N = 1000 per leg: q_A = 10 at 100 -> 110, q_B = -20 at 50 -> 55.
    # R_net = (100 - 100) / 1000 = 0 exactly, so o = 0.
    late = lambda p: {f"h{h}": (p, p) for h in range(96, 200)}
    bars = {"A": flat(100, **late(110)), "B": flat(50, **late(55)), "C": flat(100, **late(90))}
    out = run([thesis("s", 10 * H + 30 * MIN, [["C", -1]]), thesis("p", 10 * H + 31 * MIN, [["A", 1], ["B", -1]])], bars)
    assert out["theses"]["s"]["outcome"] == {"R_net": pytest.approx(0.1, abs=1e-12), "o": 1}
    p = out["theses"]["p"]
    assert [leg["q"] for leg in p["entry"]["legs"]] == [pytest.approx(10), pytest.approx(-20)]
    assert p["outcome"]["R_net"] == 0 and p["outcome"]["o"] == 0
    reconciles(out)


def test_horizon_on_a_missing_bar_uses_the_next_open_and_unresolved_until_data():
    # The 96h bar is missing: the exit is the 97h open (120). q = 10 at 100: R_net = 0.2.
    bars = {"X": flat(100, h96=None, **{f"h{h}": (120, 120) for h in range(97, 200)})}
    out = run([thesis("a", 10 * H + 30 * MIN, [["X", 1]])], bars)
    assert out["theses"]["a"]["exit"]["t"] == 97 * H and out["theses"]["a"]["outcome"]["R_net"] == pytest.approx(0.2)
    early = run([thesis("a", 10 * H + 30 * MIN, [["X", 1]])], {"X": flat(100, end=96)}, now=96 * H + 30 * MIN)
    assert early["theses"]["a"]["outcome"] is None and early["theses"]["a"]["exit"] is None
