"""C10.4 test sets for thesis/SCORING.md, dense in boundary cases: a net return of exactly 0, a horizon
on a missing bar, clusters chaining through overlaps, touching intervals, fewer than 10 base-rate
windows, size-zero (hypothetical N) theses, and B_ref = 0 (flat prices without costs give o = 0, and the one paired ablation says 0).
Since the stage 10 revision of 2026-10-23 also: hourly rows with a null close (a builder market's missing next mark),
and no opening reference between entry and the horizon (e >= x). Since the C10.4 revision of 2026-10-24, funding is
hourly over the last 150 days (zero rates on flat markets), and missing funding hours inside a holding period."""

import json
import random
from pathlib import Path

HOUR, DAY, DELTA = 3_600_000, 86_400_000, 120_000
KINDS = ("zero_return", "missing_horizon_bar", "chain", "touching", "short_history", "size_zero", "b_ref_zero", "random",
         "null_close", "no_opening_to_horizon", "missing_funding")
SEED = 1010
STATES = Path(__file__).with_name("scoring_gen_states.json")
COSTS = {"buy": {"1000": 2.0, "10000": 5.0}, "sell": {"1000": 3.0, "10000": 6.0}}


def series(rng, start, end, step, flat=False, drop=0.0):
    rows, price = [], rng.uniform(20, 200)
    for t in range(start, end, step):
        o = price
        price = o if flat else max(0.01, o * (1 + rng.gauss(0, 0.01 if step == HOUR else 0.04)))
        if rng.random() >= drop:
            rows.append([t, round(o, 6), round(price, 6)])
    return rows


def generate_set(rng, kind):
    now = (900 + rng.randrange(60)) * DAY + rng.randrange(24) * HOUR
    markets = [f"M{i}" for i in range(rng.choice((1, 2, 3)))]
    flat = kind in ("zero_return", "b_ref_zero")
    history = 40 * DAY if kind == "short_history" else 1200 * DAY
    hourly_start = now - 120 * DAY
    test = {"account": {"fee": 0.0 if flat else 0.00045, "costs": {m: ({"buy": {"1000": 0.0, "10000": 0.0}, "sell": {"1000": 0.0, "10000": 0.0}} if flat else COSTS) for m in markets}},
            "hourly": {m: series(rng, hourly_start, now - HOUR + 1, HOUR, flat, 0.0 if flat else 0.002) for m in markets},
            "daily": {m: series(rng, (now - history) // DAY * DAY, now // DAY * DAY - DAY + 1, DAY, flat, 0.03) for m in markets},
            "funding": {m: [(h, 0.0 if flat else round(rng.gauss(0, 1e-4), 8)) for h in range(now - 150 * DAY, now + 1, HOUR)]
                        for m in markets},
            "now": now, "theses": []}
    sessions, catalysts = [f"s{i}" for i in range(4)], [f"c{i}" for i in range(4)]
    for i in range(rng.randint(2, 7)):
        t_r = hourly_start + rng.randrange(0, 100 * DAY)
        T = (t_r + rng.randrange(3 * DAY, 60 * DAY + 1)) // DAY * DAY + DAY
        legs = [[rng.choice(markets), rng.choice((1, -1))]]
        if len(markets) > 1 and rng.random() < 0.3:
            other = rng.choice([m for m in markets if m != legs[0][0]])
            legs = [[legs[0][0], 1], [other, -1]]
        th = {"id": f"t{i}", "session": rng.choice(sessions), "catalyst_id": rng.choice(catalysts), "legs": legs,
              "t_r": t_r, "T": T, "N": round(rng.uniform(100, 3000), 2), "p": round(rng.uniform(0.01, 0.99), 3),
              "p_ablation": None if rng.random() < 0.2 else round(rng.uniform(0.01, 0.99), 3)}
        if kind in ("chain", "touching"):
            th["session"], th["catalyst_id"] = f"u{i}", f"k{i}"
        test["theses"].append(th)
    ts = test["theses"]
    if kind == "chain":
        for a, b in zip(ts, ts[1:]):
            b["legs"] = [[a["legs"][-1][0], 1]]
            b["t_r"] = a["T"] - DAY
            b["T"] = (b["t_r"] + 10 * DAY) // DAY * DAY
    if kind == "touching":
        ts[1]["legs"] = [[ts[0]["legs"][0][0], -1]]
        ts[1]["t_r"] = ts[0]["T"]
        ts[1]["T"] = ts[1]["t_r"] + 5 * DAY
    if kind == "missing_horizon_bar":
        m = ts[0]["legs"][0][0]
        test["hourly"][m] = [r for r in test["hourly"][m] if r[0] != ts[0]["T"]]
    if kind == "null_close":
        for m in markets:
            test["hourly"][m] = [[t, o, None if rng.random() < 0.05 else c] for t, o, c in test["hourly"][m]]
    if kind == "no_opening_to_horizon":
        th = ts[0]
        for m, _ in th["legs"]:
            test["hourly"][m] = [r for r in test["hourly"][m] if not th["t_r"] + DELTA <= r[0] < th["T"]]
    if kind == "missing_funding":
        th = ts[0]
        m = th["legs"][0][0]
        gap = set(rng.sample(range(th["t_r"] // HOUR + 2, min(th["T"], now) // HOUR), 3))
        test["funding"][m] = [r for r in test["funding"][m] if r[0] // HOUR not in gap]
    if kind == "size_zero":
        ts[0]["N"] = round(0.01 * 10_000 / 0.5, 2)
    if kind == "b_ref_zero":
        for th in ts:
            th["p_ablation"] = None
        ts[0]["p_ablation"] = 0.0
    return test


def boundaries(n=1000, chunks=16):
    return [n * k // chunks for k in range(chunks + 1)]


def walk(rng, start, stop):
    """Sets start .. stop - 1 of the one stream, from the state `rng` holds after set start - 1."""
    return (generate_set(rng, KINDS[i % len(KINDS)]) for i in range(start, stop))


def write_states():
    """The stream's state at each boundary, so that its parts can be generated apart. `python -m thesis.tests.scoring_gen`,
    after any change to the generator; the test checks that each part ends where the next begins."""
    rng, states = random.Random(SEED), []
    ends = boundaries()
    for start, stop in zip(ends, ends[1:]):
        states.append(rng.getstate())
        for _ in walk(rng, start, stop):
            pass
    STATES.write_text(json.dumps(states + [rng.getstate()]))


def read_states():
    return [(v, tuple(s), g) for v, s, g in json.loads(STATES.read_text())]


if __name__ == "__main__":
    write_states()
