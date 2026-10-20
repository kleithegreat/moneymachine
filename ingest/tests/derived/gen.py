"""C5.5 synthetic event streams, dense in boundary cases (FORMAT.md)."""

import random

from ingest.policy import HOUR as H

LAG = 600_000


def edge(rng, t):
    """t moved onto, or one millisecond around, a nearby hour boundary or availability edge."""
    b = (t // H + rng.choice([0, 1])) * H
    return rng.choice([t, b, b - 1, b + 1, b - LAG, b - LAG + 1, b - LAG - 1])


def case(rng):
    base = rng.randint(400_000, 500_000) * H + rng.choice([0, 0, 1, H - 1, rng.randrange(H)])
    keys = [f"k{i}" for i in range(rng.randint(1, 4))]
    coin_of = {k: f"C{i}" for i, k in enumerate(keys) if rng.random() < 0.8}
    polls, obs = {}, []
    for k in keys:
        s = edge(rng, base + rng.randrange(3 * H))
        if rng.random() < 0.85:
            t, ts = s, [s]
            for _ in range(rng.randint(0, 25)):
                t += rng.choice([1, LAG // 2, H, rng.randrange(1, 3 * H)])
                ts.append(edge(rng, t) if rng.random() < 0.3 else t)
            rng.shuffle(ts)
            polls[k] = ts
        span = max(polls.get(k, [s])) - s + 2 * H
        for item in range(rng.randint(0, 15)):
            created = edge(rng, s + rng.randint(-2 * H, span))
            if rng.random() < 0.2:
                created = rng.choice([s, s - 1, s + 1])
            at = edge(rng, created + rng.choice([0, 1, LAG, rng.randrange(2 * H)]))
            obs.append([k, item, created, at])
            for _ in range(rng.choice([0, 0, 1, 2])):
                again = at if rng.random() < 0.3 else edge(rng, at + rng.randrange(-H, 3 * H))
                obs.append([k, item, created + rng.choice([0, 0, -1, 5, -LAG]), again])
    rng.shuffle(obs)
    start = edge(rng, base - rng.randint(0, 5) * H - rng.choice([0, rng.randrange(H)]))
    return {"observations": obs, "polls": polls, "coin_of": coin_of, "admitted": rng.random() < 0.5, "start": start}


def generate(n, seed):
    rng = random.Random(seed)
    return [case(rng) for _ in range(n)]
