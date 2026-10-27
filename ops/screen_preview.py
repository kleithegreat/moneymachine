"""Development preview of the revised DSR screen on the first round's ledgers (human decision of 2026-10-27; a
labelled diagnostic, never evidence: stage 2 is judged only on the fresh-id rerun).

    python ops/screen_preview.py run <out.jsonl> [null,mixed] [k,.../n]   resumable, one line per campaign; shards k of n
    python ops/screen_preview.py summary <out.jsonl> <summary.json>

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
from multiprocessing import Pool
from pathlib import Path

import numpy as np
import pandas as pd

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))

from gate import campaign, gate, markets, sweep  # noqa: E402

ROUND1 = sweep.OUT / "round1"
FAMILIES = ("frozen", "best", "clusters")
# Peak memory of a null campaign's preview: its ledger (about 0.8 GB measured) and, with finalists, its two-year market.
NULL_BYTES = 1_500_000_000


def specs():
    """The first round's specs: the current sweeps' specs under their round-one ids (no round tag)."""
    betas = json.loads((sweep.OUT / "betas.json").read_text())
    return [s | {"id": s["id"].replace(sweep.ROUND, "", 1), "sweep": name}
            for name, ss in (("null", sweep.null_specs()), ("mixed", sweep.mixed_specs(betas))) for s in ss]


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
    done = campaign.recorded(path)
    mine = [s for i, s in enumerate(specs()) if i % n in ks]
    for name, per_task in (("null", NULL_BYTES), ("mixed", sweep.CAMPAIGN_BYTES)):
        if name not in names:
            continue
        todo = [s | {"recorded": recorded[s["id"]]} for s in mine if s["sweep"] == name and s["id"] not in done]
        with Pool(sweep.workers(per_task)) as pool, open(path, "a") as fh:
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


if __name__ == "__main__":
    {"run": run, "summary": summary}[sys.argv[1]](*sys.argv[2:])
