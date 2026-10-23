"""C5.5 synthetic event streams, dense in boundary cases (FORMAT.md)."""

import random

from ingest.policy import DELTA, HOUR as H

MARGIN = 60_000
GAP = 600_000


def edge(rng, t):
    """t moved onto, or one millisecond around, a nearby hour boundary, tick or availability edge."""
    b = (t // H + rng.choice([0, 1])) * H + rng.choice([0, DELTA])
    return rng.choice([t, b, b - 1, b + 1, b - MARGIN, b - MARGIN + 1, b - MARGIN - 1])


def window_edge(rng, t, margin):
    """t moved onto, or one millisecond around, a nearby hour's coverage-window edge, less up to a gap."""
    b = (t // H + rng.choice([0, 1])) * H + DELTA - margin - rng.choice([0, H])
    return b - rng.choice([0, GAP, GAP - 1, GAP + 1]) + rng.choice([0, 1, -1])


def case(rng):
    base = rng.randint(400_000, 500_000) * H + rng.choice([0, 0, 1, H - 1, rng.randrange(H)])
    keys = [f"k{i}" for i in range(rng.randint(1, 4))]
    coin_of = {k: f"C{i}" for i, k in enumerate(keys) if rng.random() < 0.8}
    margin = rng.choice([0, MARGIN])
    polls, obs = {}, []
    for k in keys:
        s = edge(rng, base + rng.randrange(3 * H))
        if rng.random() < 0.85:
            t, ts = s, [s]
            for _ in range(rng.randint(0, 4)):
                for _ in range(rng.randint(0, 80)):
                    t += rng.choices([GAP // 2, 1, MARGIN, GAP - 1, GAP, GAP + 1], [70, 5, 5, 7, 7, 6])[0]
                    r = rng.random()
                    ts.append(edge(rng, t) if r < 0.1 else window_edge(rng, t, margin) if r < 0.2 else t)
                t += rng.choice([GAP + 1, H, rng.randrange(1, 3 * H)])
                ts.append(t)
            rng.shuffle(ts)
            polls[k] = ts
        span = max(polls.get(k, [s])) - s + 2 * H
        for item in range(rng.randint(0, 15)):
            created = edge(rng, s + rng.randint(-2 * H, span))
            if rng.random() < 0.2:
                created = rng.choice([s, s - 1, s + 1])
            at = edge(rng, created + rng.choice([0, 1, MARGIN, rng.randrange(2 * H)]))
            obs.append([k, item, created, at])
            for _ in range(rng.choice([0, 0, 1, 2])):
                again = at if rng.random() < 0.3 else edge(rng, at + rng.randrange(-H, 3 * H))
                obs.append([k, item, created + rng.choice([0, 0, -1, 5, -MARGIN]), again])
    times = [o[3] for o in obs] + [p for ps in polls.values() for p in ps]
    version = max(times, default=base) + rng.choice([0, 1, H, rng.randrange(3 * H)])
    if rng.random() < 0.3 and times:
        version = edge(rng, rng.choice(times))
        obs = [o for o in obs if o[3] <= version]
        polls = {k: [p for p in ps if p <= version] for k, ps in polls.items()}
        polls = {k: ps for k, ps in polls.items() if ps}
    rng.shuffle(obs)
    return {"observations": obs, "polls": polls, "coin_of": coin_of, "margin": margin, "version": version}


def generate(n, seed):
    rng = random.Random(seed)
    return [case(rng) for _ in range(n)]
