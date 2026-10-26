"""Databento historical pulls (`venue/sources.toml`, `databento`; kernel-only, so nothing here prints or inspects
records beyond integrity). Each request of a declared pull (`venue/sources/databento.json`) is priced with the free
`metadata.get_cost` call first, and is made only while the running total stays under the plan's `spend_cap_usd`, below
the USD 125 sign-up credit. The response, zstd-compressed DBN as served, is stored under `<out>/raw/<sha256>.dbn.zst`
beside a manifest line {"pull", "request", "cost_usd", "bytes", "sha256", "fetched"}; a request already in the
manifest is skipped, so a pull resumes."""

import datetime as dt
import hashlib
import json
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import httpx

from ingest.datalayer import secrets
from ingest.live import now_ms

REPO = Path(__file__).resolve().parents[1]
PLAN = REPO / "venue/sources/databento.json"
API = "https://hist.databento.com/v0/"


def months(start, end):
    """`start`, then the first day of every later month through `end`."""
    d = dt.date.fromisoformat(start)
    while d <= end:
        yield d
        d = (d.replace(day=28) + dt.timedelta(days=4)).replace(day=1)


def requests(plan, pull, today):
    """The pull's requests: for monthly definitions, one day's snapshot of every contract defined then, on the plan's
    start and the first day of each later month."""
    symbols = ",".join(f"{r}.FUT" for r in plan["roots"])
    for d in months(plan["start"], today):
        yield {"dataset": plan["dataset"], "symbols": symbols, "stype_in": pull["stype_in"], "schema": pull["schema"],
               "start": d.isoformat(), "end": (d + dt.timedelta(days=1)).isoformat()}


def client():
    return httpx.Client(base_url=API, auth=(secrets()["DATABENTO_API_KEY"].strip('"'), ""), timeout=600)


def price(name, out=None, workers=10):
    """The pull's total cost from `metadata.get_cost`, request by request (free), `workers` calls at a time, with
    progress printed every 20 requests."""
    plan = json.loads(PLAN.read_text())
    pull = next(p for p in plan["pulls"] if p["name"] == name)
    qs = list(requests(plan, pull, dt.date.today()))
    with client() as http, ThreadPoolExecutor(workers) as pool:
        costs = []
        for k, c in enumerate(pool.map(lambda q: float(http.get("metadata.get_cost", params=q).raise_for_status().json()), qs), 1):
            costs.append(c)
            if k % 20 == 0 or k == len(qs):
                print(f"{k}/{len(qs)} priced, {sum(costs):.2f} USD so far", flush=True)
    total = {"pull": name, "requests": len(costs), "cost_usd": float(sum(costs)), "max_request_usd": float(max(costs))}
    print(json.dumps(total))
    if out:
        Path(out).write_text(json.dumps(total, indent=1) + "\n")
    return total


def pull(name, out_dir, http=None, plan_path=PLAN, today=None):
    """Fetch the pull's requests not yet in the manifest, each priced first, within the spend cap."""
    plan = json.loads(Path(plan_path).read_text())
    spec = next(p for p in plan["pulls"] if p["name"] == name)
    out = Path(out_dir)
    (out / "raw").mkdir(parents=True, exist_ok=True)
    manifest = out / "manifest.jsonl"
    done = [json.loads(l) for l in open(manifest)] if manifest.exists() else []
    spent, seen = sum(r["cost_usd"] for r in done), {json.dumps(r["request"], sort_keys=True) for r in done}
    with http or client() as http:
        for q in requests(plan, spec, today or dt.date.today()):
            if json.dumps(q, sort_keys=True) in seen:
                continue
            cost = float(http.get("metadata.get_cost", params=q).raise_for_status().json())
            if spent + cost > plan["spend_cap_usd"]:
                sys.exit(f"stopped: {q['start']} would bring spending to {spent + cost:.2f} USD, over the cap")
            body = http.post("timeseries.get_range", data=q | {"encoding": "dbn", "compression": "zstd"}).raise_for_status().content
            digest = hashlib.sha256(body).hexdigest()
            (out / "raw" / f"{digest}.dbn.zst").write_bytes(body)
            with open(manifest, "a") as f:
                f.write(json.dumps({"pull": name, "request": q, "cost_usd": cost, "bytes": len(body), "sha256": digest,
                                    "fetched": now_ms()}) + "\n")
            spent += cost
    print(json.dumps({"pull": name, "spent_usd": round(spent, 4)}))
