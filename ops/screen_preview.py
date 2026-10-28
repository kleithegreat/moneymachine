"""Development preview of the revised DSR screen on the first round's ledgers (human decision of 2026-10-27; a
labelled diagnostic, never evidence: stage 2 is judged only on the fresh-id rerun).

    python ops/screen_preview.py run <out.jsonl> [null,mixed] [k,.../n]   resumable, one line per campaign; shards k of n
    python ops/screen_preview.py summary <out.jsonl> <summary.json>
    python ops/screen_preview.py holdouts <out.jsonl> <dir> [null,mixed] [k,.../n] | truths <dir> | bounds <dir> <bounds.json>

`holdouts`, `truths` and `bounds` price the holdout's loss bound B for the human's decision: each mixed campaign's
finalists' holdout returns (and every third null campaign's in-sample best), tested with the bet cap 1/(2B) on returns
floored at -B, the floor standing in for a kernel stop or an isolated margin; and the cluster representatives at SCALE
times their size with B = 1. Truths use the unscaled or scaled program, not the floored one.

For each first-round campaign it reruns `gate.search_decision` (the revised screen; SPA, seeded by the campaign id,
must reproduce the recorded p-value) on the kept ledger. Where finalists exist, it regenerates the market from the
id, freezes them and runs the holdout step once. From those holdout results it also prices two other finalist-family
rules for Holm, options for the human, not the gate: the best finalist by search-period Sharpe, and the best of each
|rho| >= 0.5 cluster. Each mixed promotion under any rule gets the truth check of C2.5."""

import json
import lzma
import shutil
import sys
import tempfile
from functools import partial
from multiprocessing import Pool
from pathlib import Path

import subprocess
import sqlite3

import numpy as np
import pandas as pd

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))

from gate import campaign, compute, gate, markets, sweep  # noqa: E402

ROUND1 = sweep.OUT / "round1"
FAMILIES = ("frozen", "best", "clusters")
BOUNDS, SCALE = (1.0, 0.2, 0.1, 0.05, 0.02), 10.0
# Peak memory per task with mm 3a732069: a mixed campaign's holdout batch, 778 MiB measured for c25-N2-long-1, plus
# margin; a null campaign's is smaller.
NULL_BYTES, MIXED_BYTES = 1_000_000_000, 1_000_000_000


def specs():
    """The first round's specs (no round tag in their ids)."""
    betas = json.loads((sweep.OUT / "betas.json").read_text())
    return [s | {"sweep": name}
            for name, ss in (("null", sweep.null_specs(rnd="")), ("mixed", sweep.mixed_specs(betas, rnd=""))) for s in ss]


def promoted(family, holdout):
    adj = gate.holm(np.array([holdout["holdout_p"][h] for h in family]))
    return [h for h, a in zip(family, adj) if holdout["holdout_total_return"][h] > 0 and a <= gate.ALPHA]


def families(r, finalists):
    sharpe = r[finalists].mean() / r[finalists].std(ddof=1)
    best = {}
    for h, k in gate.cluster_labels(r[finalists], 0.5).items():
        if k not in best or sharpe[h] > sharpe[best[k]]:
            best[k] = h
    return {"frozen": finalists, "best": [sharpe.idxmax()], "clusters": list(best.values())}


def preview(spec):
    recorded = spec["recorded"]
    out = {"id": spec["id"]}
    if recorded.get("crash"):
        return out | {"crash": True}
    programs = {}
    with tempfile.TemporaryDirectory(dir=sweep.OUT) as tmp:
        root = Path(tmp) / "m"
        root.mkdir()
        ledger = root / "ledger.sqlite"
        ledger.write_bytes(lzma.decompress((ROUND1 / spec["sweep"] / spec["id"] / "ledger.sqlite.xz").read_bytes()))
        finalists, report = gate.search_decision(ledger, spec["id"])
        out |= {"n": report["n"], "spa_p": report["spa_p"], "spa_p_recorded": recorded["search"]["spa_p"],
                "screened": len(report["screened"]), "finalists": len(finalists), "max_dsr": report["max_dsr"],
                "promoted": {f: [] for f in FAMILIES}}
        if finalists:
            fams = families(pd.DataFrame(gate.candidates(ledger, spec["id"])), finalists)
            ledger.rename(Path(tmp) / "ledger.sqlite")
            shutil.rmtree(root)
            markets.write(root, markets.generate(spec["model"], spec["params"], spec["id"], spec["days"],
                                                 spec.get("planted", ()), spec.get("beta", 0.0), spec.get("events")),
                          spec["holdout_days"], spec["cost_cells"])
            (Path(tmp) / "ledger.sqlite").rename(ledger)
            gate.freeze(ledger, spec["id"], finalists, "finalist")
            programs = gate.programs(ledger, spec["id"], finalists)
            frozen, holdout = gate.holdout_decision(root, ledger, spec["id"], programs)
            out["promoted"] = {f: promoted(fam, holdout) for f, fam in fams.items()}
            assert out["promoted"]["frozen"] == frozen
            out |= {"family_sizes": {f: len(fam) for f, fam in fams.items()},
                    "holdout_p_min": min(holdout["holdout_p"].values())}
    if spec["sweep"] == "mixed":
        _, model, _, _ = spec["id"].split("-")
        out["true"] = {h: sweep.is_true(programs[h], model, spec["beta"], sweep.truth_id(spec["id"], h))
                       for h in sorted(set().union(*out["promoted"].values()))}
    return out


def run(path, names="null,mixed", shard="0/1"):
    ks, n = shard.split("/")
    ks, n = set(map(int, ks.split(","))), int(n)
    names = names.split(",")
    recorded = {r["id"]: r for name in names for r in map(json.loads, open(ROUND1 / f"{name}.jsonl"))}
    mine = [s for i, s in enumerate(specs()) if i % n in ks]
    with campaign.exclusive(path) as fh:
        done = campaign.recorded(path)
        for name, per_task in (("null", NULL_BYTES), ("mixed", MIXED_BYTES)):
            if name not in names:
                continue
            todo = [s | {"recorded": recorded[s["id"]]} for s in mine if s["sweep"] == name and s["id"] not in done]
            with Pool(compute.workers(per_task)) as pool:
                for r in pool.imap_unordered(preview, todo):
                    fh.write(json.dumps(r) + "\n")
                    fh.flush()


def summary(path, out):
    """Per cell: SPA rejections, campaigns with finalists (C2.4's second bullet) and the SPA reproduction check; per
    family rule, promoting campaigns (C2.4's first bullet) and, in mixed cells, FDR and power as `sweep` computes them."""
    cells = {}
    for r in map(json.loads, open(path)):
        _, model, cell, _ = r["id"].split("-")
        c = cells.setdefault(f"{model}-{cell}", {"n": 0, "crashes": 0, "spa": 0, "spa_mismatch": 0, "screened_any": 0,
                                                 "spa_and_finalists": 0, "family": {f: {"promoting": 0, "fdp": [], "with_true": 0}
                                                                                    for f in FAMILIES}})
        c["n"] += 1
        if r.get("crash"):
            c["crashes"] += 1
            c["spa_and_finalists"] += 1
            for f in c["family"].values():
                f["promoting"] += 1
                f["fdp"].append(1.0)
            continue
        c["spa"] += r["spa_p"] <= gate.ALPHA
        c["spa_mismatch"] += r["spa_p"] != r["spa_p_recorded"]
        c["screened_any"] += r["screened"] > 0
        c["spa_and_finalists"] += r["finalists"] > 0
        for name, f in c["family"].items():
            ts = [r.get("true", {}).get(h, False) for h in r["promoted"][name]]
            f["promoting"] += bool(ts)
            f["fdp"].append(ts.count(False) / max(len(ts), 1))
            f["with_true"] += any(ts)
    mixed = lambda name: name.split("-")[1].startswith(("s", "long"))
    for name, c in cells.items():
        c["spa_upper"] = sweep.cp_upper(c["spa_and_finalists"], c["n"])
        for f in c["family"].values():
            fdp = f.pop("fdp")
            f["promoting_upper"] = sweep.cp_upper(f["promoting"], c["n"])
            if mixed(name):
                f |= {"fdr": sum(fdp) / c["n"], "power": f["with_true"] / c["n"],
                      "power_ci": sweep.cp_interval(f["with_true"], c["n"])}
            else:
                del f["with_true"]
    Path(out).write_text(json.dumps({"label": "development diagnostic on the first round's ledgers; not evidence",
                                     "cells": dict(sorted(cells.items()))}, indent=1) + "\n")


def holdout_one(spec, out_dir):
    from gate.kernel import command

    target = Path(out_dir) / f"{spec['id']}.npz"
    if target.exists():
        return
    with tempfile.TemporaryDirectory(dir=sweep.OUT) as tmp:
        root = Path(tmp) / "m"
        markets.write(root, markets.generate(spec["model"], spec["params"], spec["id"], spec["days"],
                                             spec.get("planted", ()), spec.get("beta", 0.0)), spec["holdout_days"], spec["cost_cells"])
        ledger = root / "ledger.sqlite"
        ledger.write_bytes(lzma.decompress((ROUND1 / spec["sweep"] / spec["id"] / "ledger.sqlite.xz").read_bytes()))
        if spec["sweep"] == "mixed":
            base, _ = gate.search_decision(ledger, spec["id"])
            fams = families(pd.DataFrame(gate.candidates(ledger, spec["id"])), base)
        else:
            base = spec["recorded"]["search"]["top5"][:1]
            fams = {f: base for f in FAMILIES}
        programs = gate.programs(ledger, spec["id"], base)
        for h in fams["clusters"]:
            scaled = programs[h] | {"weight": {"op": "mul", "args": [programs[h]["weight"], {"const": SCALE, "unit": "1"}]}}
            f = Path(tmp) / f"{h}.json"
            f.write_text(json.dumps(scaled))
            out = subprocess.run(command("eval", f, spec["id"], "scale", ledger, root), capture_output=True, text=True, check=True)
            key = sqlite3.connect(ledger).execute("SELECT trial FROM experiments WHERE id = ?",
                                                  (json.loads(out.stdout)["experiment"],)).fetchone()[0]
            programs[f"x{h}"] = scaled | {"_key": key}
        keys = {h: p.pop("_key", h) for h, p in programs.items()}
        gate.freeze(ledger, spec["id"], list(keys.values()), "bound preview")
        results = gate.holdout_run(root, ledger, spec["id"], {keys[h]: programs[h] for h in programs})
    names = list(programs)
    np.savez(target, names=names, returns=np.array([results[keys[h]][0] for h in names]),
             programs=[json.dumps(programs[h]) for h in names], **{f: np.array(fams[f]) for f in FAMILIES})


def holdouts(path, out_dir, names="null,mixed", shard="0/1"):
    ks, n = shard.split("/")
    ks, n = set(map(int, ks.split(","))), int(n)
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    rows = {r["id"]: r for r in map(json.loads, open(path))}
    recorded = {r["id"]: r for name in ("null", "mixed") for r in map(json.loads, open(ROUND1 / f"{name}.jsonl"))}
    todo = [s | {"recorded": recorded[s["id"]]} for i, s in enumerate(specs()) if i % n in ks and s["sweep"] in names.split(",")
            and not rows[s["id"]].get("crash")
            and (rows[s["id"]].get("finalists") if s["sweep"] == "mixed" else i % 3 == 0)]
    with Pool(compute.workers(MIXED_BYTES)) as pool:
        list(pool.imap_unordered(partial(holdout_one, out_dir=out_dir), todo))


def campaigns(out_dir):
    for f in sorted(Path(out_dir).glob("*.npz")):
        d = np.load(f)
        yield f.stem, {k: d[k] for k in d.files}


def decide(cid, d, bound, scaled):
    """The promoted names of each family rule under one option."""
    names, r = list(d["names"]), d["returns"]
    out = {}
    for fam in FAMILIES:
        members = [f"x{h}" if scaled else h for h in d[fam]] if not (scaled and fam == "frozen") else [f"x{h}" for h in d["clusters"]]
        rows = np.array([np.maximum(r[names.index(m)], -bound) for m in members])
        p, total = gate.holdout_pvalues(rows, bound), np.prod(1 + rows, axis=-1) - 1
        adj = gate.holm(p)
        out[fam] = [m for m, a, t in zip(members, adj, total) if t > 0 and a <= gate.ALPHA]
    return out


def truths(out_dir):
    """C2.5's truth for every name any option promotes in a mixed campaign, cached in `out_dir`/truth.jsonl."""
    cache = Path(out_dir) / "truth.jsonl"
    done = campaign.recorded(cache)
    betas = json.loads((sweep.OUT / "betas.json").read_text())
    todo = {}
    for cid, d in campaigns(out_dir):
        if cid.startswith("c25"):
            for bound, scaled in [(b, False) for b in BOUNDS] + [(1.0, True)]:
                for names in decide(cid, d, bound, scaled).values():
                    for m in names:
                        if f"{cid}/{m}" not in done:
                            _, model, cell, _ = cid.split("-")
                            todo[f"{cid}/{m}"] = (json.loads(str(d["programs"][list(d["names"]).index(m)])), model, betas[f"{model}-{cell}"])
    with Pool(compute.workers(sweep.CALIBRATION_BYTES)) as pool, open(cache, "a") as fh:
        for key, true in pool.imap_unordered(truth_one, todo.items()):
            fh.write(json.dumps({"id": key, "true": true}) + "\n")
            fh.flush()


def truth_one(item):
    key, (program, model, beta) = item
    return key, sweep.is_true(program, model, beta, "bound-" + key.replace("/", "-"))


def bounds(out_dir, out):
    """Per option and cell: promoting campaigns, FDR and power per family rule; per option, the null in-sample best's
    rejection rate; and how often the floor binds."""
    truth = {r["id"]: r["true"] for r in map(json.loads, open(Path(out_dir) / "truth.jsonl"))} if (Path(out_dir) / "truth.jsonl").exists() else {}
    options = {f"B={b}": (b, False) for b in BOUNDS} | {f"B=1,x{SCALE:g}": (1.0, True)}
    table = {o: {} for o in options}
    for cid, d in campaigns(out_dir):
        cell = "-".join(cid.split("-")[1:3]) if cid.startswith("c25") else "null"
        for o, (bound, scaled) in options.items():
            c = table[o].setdefault(cell, {"n": 0, "binding_steps": 0, "steps": 0} | {f: {"promoting": 0, "fdp": [], "with_true": 0, "unknown": 0} for f in FAMILIES})
            c["n"] += 1
            rows = d["returns"][[i for i, m in enumerate(d["names"]) if m.startswith("x") == scaled]]
            c["binding_steps"] += int((rows < -bound).sum())
            c["steps"] += rows.size
            for f, names in decide(cid, d, bound, scaled).items():
                ts = [truth.get(f"{cid}/{m}") for m in names]
                c[f]["unknown"] += ts.count(None)
                ts = [t is True for t in ts]
                c[f]["promoting"] += bool(names)
                c[f]["fdp"].append(ts.count(False) / max(len(ts), 1))
                c[f]["with_true"] += any(ts)
    for o in table.values():
        for cell, c in o.items():
            for f in FAMILIES:
                fdp = c[f].pop("fdp")
                c[f] |= {"rate": c[f]["promoting"] / c["n"]} if cell == "null" else {"fdr": sum(fdp) / c["n"], "power": c[f]["with_true"] / c["n"]}
    Path(out).write_text(json.dumps({"label": "development diagnostic on the first round's campaigns; not evidence",
                                     "floor": "returns floored at -B stand in for a kernel stop or an isolated margin",
                                     "options": table}, indent=1) + "\n")


if __name__ == "__main__":
    {"run": run, "summary": summary, "holdouts": holdouts, "truths": truths, "bounds": bounds}[sys.argv[1]](*sys.argv[2:])
