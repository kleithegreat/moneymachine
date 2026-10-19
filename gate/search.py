"""Baseline searchers over the DSL (stage 2 calibration; the stage 3 baseline).

G<budget>: random-plus-genetic search. H<budget>: a hill-climber on in-sample Sharpe. Each sees
only DISCLOSED from each evaluation, and every evaluation goes through `mm eval` and the ledger.
Features draw on the inputs the market carries: the forum-activity feature exists only where the
store has `events_forum`.
"""

import copy
import json
import random
import subprocess
from pathlib import Path

DISCLOSED = ("sharpe_annualized",)
WINDOWS = (4, 8, 12, 24, 48, 96, 168, 336)
SIZES = (0.02, 0.05, 0.1)


def const(x, unit="1"):
    return {"const": x, "unit": unit}


def op(name, *args, **extra):
    return {"op": name, "args": list(args), **extra}


PRICES = ("open", "high", "low", "close")


def compile_feature(kind, price, h):
    if kind == 0:
        x = {"input": price}
        return op("sub", op("div", x, op("lag", x, hours=h)), const(1))
    if kind == 1:
        return op("div", {"input": "funding"}, const(1e-4, "1/h"))
    if kind == 2:
        f = {"input": "funding"}
        return op("div", op("sub", f, op("mean", f, hours=h)), op("std", f, hours=max(h, 8)))
    if kind == 3:
        return op("mul", {"input": "premium"}, const(1e3))
    if kind == 4:
        v = {"input": "volume"}
        return op("sub", op("div", v, op("mean", v, hours=h)), const(1))
    if kind == 5:
        return op("div", op("sub", {"input": "high"}, {"input": "low"}), {"input": "close"})
    e, mean = {"input": "forum_posts"}, op("mean", {"input": "forum_posts"}, hours=h)
    return op("div", op("sub", e, mean), op("add", mean, const(1.0, "ev")))


def features(market):
    """How many feature kinds the market's inputs support."""
    return 7 if (Path(market) / "store" / "events_forum").exists() else 6


def compile_node(n):
    """Genome node (a JSON list) -> dimensionless DSL expression."""
    tag = n[0]
    if tag == "feat":
        return compile_feature(*n[1:])
    if tag == "neg":
        return op("neg", compile_node(n[1]))
    if tag in ("sub", "mul"):
        return op(tag, compile_node(n[1]), compile_node(n[2]))
    if tag == "smooth":
        return op(n[1], compile_node(n[3]), hours=n[2])
    if tag == "xsdemean":
        return op("xs_demean", compile_node(n[1]))
    if tag == "xsrank":
        return op("sub", op("xs_rank", compile_node(n[1])), const(0.5))
    return op("if", op("gt", compile_node(n[1]), const(0.0)), compile_node(n[2]), op("neg", compile_node(n[3])))


def compile_genome(g):
    sig = compile_node(g["sig"])
    w = op("sign", sig) if g["squash"] == "sign" else op("clip", sig, const(-1.0), const(1.0))
    return {"dsl": 1, "name": "search", "mechanism": {"counterparty": "unstated", "predictions": [], "capacity": "-"},
            "weight": op("mul", w, const(g["size"]))}


def random_node(rng, depth, nf):
    if depth == 0 or rng.random() < 0.3:
        return ["feat", rng.randrange(nf), rng.choice(PRICES), rng.choice(WINDOWS)]
    k = rng.randrange(7)
    a = random_node(rng, depth - 1, nf)
    if k == 0:
        return ["neg", a]
    if k in (1, 2):
        return [("sub", "mul")[k - 1], a, random_node(rng, depth - 1, nf)]
    if k == 3:
        return ["smooth", rng.choice(["mean", "ema"]), rng.choice(WINDOWS), a]
    if k == 4:
        return ["xsdemean", a]
    if k == 5:
        return ["xsrank", a]
    return ["cond", a, random_node(rng, depth - 1, nf), random_node(rng, depth - 1, nf)]


def random_genome(rng, nf):
    return {"sig": random_node(rng, rng.randint(0, 3), nf), "size": rng.choice(SIZES), "squash": rng.choice(["sign", "clip"])}


def children(n):
    """Indices of a node's child nodes."""
    return {"feat": [], "neg": [1], "sub": [1, 2], "mul": [1, 2], "smooth": [3], "xsdemean": [1], "xsrank": [1],
            "cond": [1, 2, 3]}[n[0]]


def paths(n, p=()):
    yield p
    for i in children(n):
        yield from paths(n[i], p + (i,))


def get(n, p):
    for i in p:
        n = n[i]
    return n


def put(n, p, new):
    if not p:
        return new
    n = copy.deepcopy(n)
    get(n, p[:-1])[p[-1]] = new
    return n


def mutate(rng, g, nf):
    g = copy.deepcopy(g)
    r = rng.random()
    p = rng.choice(list(paths(g["sig"])))
    node = get(g["sig"], p)
    if r < 0.35:
        g["sig"] = put(g["sig"], p, random_node(rng, rng.randint(0, 2), nf))
    elif r < 0.7 and node[0] in ("feat", "smooth"):
        node[2 if node[0] == "smooth" else 3] = rng.choice(WINDOWS)
    elif r < 0.85:
        g["squash"] = rng.choice(["sign", "clip"])
    else:
        g["size"] = rng.choice(SIZES)
    return g


def crossover(rng, a, b):
    donor = get(b["sig"], rng.choice(list(paths(b["sig"]))))
    child = copy.deepcopy(a)
    child["sig"] = put(a["sig"], rng.choice(list(paths(a["sig"]))), copy.deepcopy(donor))
    return child


class Evaluator:
    """Streams programs through one `mm eval -` process and returns only the disclosed statistics."""

    def __init__(self, mm, market, ledger, campaign, agent):
        m = Path(market)
        self.proc = subprocess.Popen(
            [str(mm), "eval", "-", "--campaign", campaign, "--agent", agent, "--store", str(m / "store"),
             "--venue", str(m / "venue"), "--ledger", str(ledger)],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self.seen = {}

    def __call__(self, genomes):
        out = []
        for g in genomes:
            text = json.dumps(compile_genome(g), sort_keys=True)
            if text not in self.seen:
                self.proc.stdin.write(text + "\n")
                self.proc.stdin.flush()
                line = self.proc.stdout.readline()
                if not line:
                    raise RuntimeError(f"mm eval exited with {self.proc.wait()}")
                d = json.loads(line)
                stats = d["disclosure"]["result"] if "disclosure" in d else {}
                self.seen[text] = {k: stats.get(k, float("-inf")) for k in DISCLOSED}
            out.append(self.seen[text])
        return out

    def close(self):
        self.proc.stdin.close()
        self.proc.wait()

    @property
    def spent(self):
        return len(self.seen)


def genetic(evaluate, budget, rng, nf, population=20):
    pop = [random_genome(rng, nf) for _ in range(population)]
    scored = list(zip(pop, evaluate(pop)))
    for _ in range(100 * budget):
        if evaluate.spent >= budget:
            break
        scored.sort(key=lambda x: -x[1]["sharpe_annualized"])
        parents = [s for s, _ in scored[: population // 2]]
        children = []
        while len(children) < min(population, budget - evaluate.spent):
            r = rng.random()
            child = (crossover(rng, rng.choice(parents), rng.choice(parents)) if r < 0.3
                     else mutate(rng, rng.choice(parents), nf) if r < 0.8 else random_genome(rng, nf))
            children.append(child)
        scored = scored[: population // 2] + list(zip(children, evaluate(children)))


def hill_climb(evaluate, budget, rng, nf):
    best = random_genome(rng, nf)
    best_score = evaluate([best])[0]["sharpe_annualized"]
    stall = 0
    while evaluate.spent < budget and stall < 4 * budget:
        cand = mutate(rng, best, nf)
        score = evaluate([cand])[0]["sharpe_annualized"]
        stall += 1
        if score > best_score:
            best, best_score, stall = cand, score, 0


def run(searcher, mm, market, ledger, campaign, seed):
    """Run searcher 'G100', 'G400' or 'H400' on a market; every evaluation lands in the ledger."""
    kind, budget = searcher[0], int(searcher[1:])
    evaluate = Evaluator(mm, market, ledger, campaign, searcher)
    rng = random.Random(seed)
    try:
        (genetic if kind == "G" else hill_climb)(evaluate, budget, rng, features(market))
    finally:
        evaluate.close()
    return evaluate.spent
