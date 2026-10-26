"""Databento historical pulls (`venue/sources.toml`, `databento`; kernel-only, so nothing here prints or inspects
records beyond integrity). Each request of a declared pull (`venue/sources/databento.json`) is priced with the free
`metadata.get_cost` call first, and is made only while the running total stays under the plan's `spend_cap_usd`, below
the USD 125 sign-up credit. The response, zstd-compressed DBN as served, is stored under `<out>/raw/<sha256>.dbn.zst`
beside a manifest line {"pull", "request", "cost_usd", "bytes", "sha256", "fetched"}; a request already in the
manifest is skipped, so a pull resumes."""

import datetime as dt
import hashlib
import json
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import httpx

from ingest.datalayer import secrets
from ingest.live import now_ms

REPO = Path(__file__).resolve().parents[1]
PLAN = REPO / "venue/sources/databento.json"
API = "https://hist.databento.com/v0/"
DBNCONV = REPO / "ingest/dbnconv"


def months(start, end):
    """`start`, then the first day of every later month through `end`."""
    d = dt.date.fromisoformat(start)
    while d <= end:
        yield d
        d = (d.replace(day=28) + dt.timedelta(days=4)).replace(day=1)


def requests(plan, pull, today, outrights=None):
    """The pull's requests, one per month from the plan's start: a definition pull takes one day's snapshot of every
    contract under the roots, on the month's first day or, when that is a Saturday (no session, so no definitions), on
    the Sunday; a pull by raw symbol takes the whole month for the outright futures in that month's snapshot
    (`outrights`, by month)."""
    days = list(months(plan["start"], today))
    for d, end in zip(days, days[1:] + [today]):
        q = {"dataset": plan["dataset"], "stype_in": pull["stype_in"], "schema": pull["schema"]}
        if pull["stype_in"] == "parent":
            d += dt.timedelta(days=d.weekday() == 5)
            yield q | {"symbols": ",".join(f"{r}.FUT" for r in plan["roots"]), "start": d.isoformat(),
                       "end": (d + dt.timedelta(days=1)).isoformat()}
        elif end > d:
            yield q | {"symbols": ",".join(outrights[d.isoformat()[:7]]), "start": d.isoformat(), "end": end.isoformat()}


def outrights(out_dir):
    """Per month of the monthly definitions in `out_dir`, the raw symbols of the outright futures its snapshots list,
    decoded by `ingest/dbnconv` without printing a record."""
    out = Path(out_dir)
    defs = [r for r in map(json.loads, open(out / "manifest.jsonl")) if r["pull"] == "definition-monthly"]
    subprocess.run(["cargo", "build", "-q", "--release"], cwd=DBNCONV, check=True)
    files = {str(out / "raw" / f"{r['sha256']}.dbn.zst"): r["request"]["start"][:7] for r in defs}
    subprocess.run([DBNCONV / "target/release/dbnconv", "outrights", out / "outrights.jsonl", *files], check=True)
    by_month = {}
    for x in map(json.loads, open(out / "outrights.jsonl")):
        by_month.setdefault(files[x["file"]], set()).update(x["outrights"])
    return {m: sorted(v) for m, v in by_month.items()}


def plan_requests(plan, name, out_dir, today):
    spec = next(p for p in plan["pulls"] if p["name"] == name)
    return list(requests(plan, spec, today, outrights(out_dir) if spec["stype_in"] == "raw_symbol" else None))


def send(http, path, q, tries=4):
    """One POST, retried after a 5xx or a transport error, 30 s apart and more each time."""
    for attempt in range(tries):
        time.sleep(30 * attempt)
        try:
            r = http.post(path, data=q)
        except httpx.TransportError:
            if attempt == tries - 1:
                raise
            continue
        if r.status_code < 500 or attempt == tries - 1:
            return r.raise_for_status()


def client():
    return httpx.Client(base_url=API, auth=(secrets()["DATABENTO_API_KEY"].strip('"'), ""), timeout=600)


def price(name, out_dir, out=None, workers=10):
    """The pull's total cost from `metadata.get_cost`, request by request (free), `workers` calls at a time, with
    progress printed every 20 requests."""
    qs = plan_requests(json.loads(PLAN.read_text()), name, out_dir, dt.date.today())
    with client() as http, ThreadPoolExecutor(workers) as pool:
        costs = []
        for k, c in enumerate(pool.map(lambda q: float(send(http, "metadata.get_cost", q).json()), qs), 1):
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
    qs = plan_requests(plan, name, out_dir, today or dt.date.today())
    out = Path(out_dir)
    (out / "raw").mkdir(parents=True, exist_ok=True)
    manifest = out / "manifest.jsonl"
    done = [json.loads(l) for l in open(manifest)] if manifest.exists() else []
    spent, seen = sum(r["cost_usd"] for r in done), {json.dumps(r["request"], sort_keys=True) for r in done}
    with http or client() as http:
        for q in qs:
            if json.dumps(q, sort_keys=True) in seen:
                continue
            cost = float(send(http, "metadata.get_cost", q).json())
            if spent + cost > plan["spend_cap_usd"]:
                sys.exit(f"stopped: {q['start']} would bring spending to {spent + cost:.2f} USD, over the cap")
            body = send(http, "timeseries.get_range", q | {"encoding": "dbn", "compression": "zstd"}).content
            digest = hashlib.sha256(body).hexdigest()
            (out / "raw" / f"{digest}.dbn.zst").write_bytes(body)
            with open(manifest, "a") as f:
                f.write(json.dumps({"pull": name, "request": q, "cost_usd": cost, "bytes": len(body), "sha256": digest,
                                    "fetched": now_ms()}) + "\n")
            spent += cost
    print(json.dumps({"pull": name, "spent_usd": round(spent, 4)}))
