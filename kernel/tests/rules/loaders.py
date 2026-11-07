"""The production loaders as C7.6 participants: a resolver case written into the store's Parquet layout, then resolved
by `ingest/resolve.py` (the path `store.as_of` reads) and by `mm resolve` (the Rust loader's resolver), each giving
RULES.md §7's whole result and its observations.

The image (audit/criteria.md, C7.6's B3 revision): row i of a case is the file `<i>.parquet` under its source's
directory, holding the row's fetchedAt, a `tombstone` column only for a tombstone, `upstream` as LargeUtf8 for a derived
source, and its declared members by SOURCES.md §2's mapping (a string as LargeUtf8, a null as a Double null, a member
that is no cell as a List column holding its JSON text); absent declared members and undeclared ones are left out."""

import json
import subprocess
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq

from gate import kernel
from ingest import resolve
from kernel.tests.rules import lean_check
from kernel.tests.rules import resolver_suite as suite


def member(text, value):
    """One declared member as a one-row column."""
    ok, v = resolve.cell(json_cell(value))
    if not ok:
        return pa.array([[text]], pa.list_(pa.string()))
    if v is None:
        return pa.array([None], pa.float64())
    if type(v) is bool:
        return pa.array([v], pa.bool_())
    return pa.array([v], {int: pa.int64(), float: pa.float64(), str: pa.large_string()}[type(v)])


def json_cell(value):
    """A decoded Python JSON value as the resolver's parsed form: a float is a Real."""
    if type(value) is float:
        return resolve.knownat.Real(value)
    return value


def write_image(case, root):
    by = {s["name"]: s for s in case["sources"]}
    for i, r in enumerate(case["rows"]):
        s = by[r["source"]]
        cells = json.loads(r["cells"])
        columns = {"fetchedAt": pa.array([r["fetchedAt"]], pa.int64())}
        if r["tombstone"]:
            columns["tombstone"] = pa.array([True])
        if s["deps"]:
            columns["upstream"] = pa.array([r["upstream"]], pa.large_string())
        for name in suite.declared(s):
            if name in cells:
                columns[name] = member(json.dumps(cells[name]), cells[name])
        directory = Path(root) / s["name"]
        directory.mkdir(parents=True, exist_ok=True)
        pq.write_table(pa.table(columns), directory / f"{i}.parquet")


def listing(case, keys):
    """RULES.md §7's keys from the resolver's: sorted, with each entry as the array the result gives."""
    by = {s["name"]: s for s in case["sources"]}
    out = []
    for k in sorted(keys.values(), key=lambda k: (k.source, suite.order(list(k.entity)), k.event)):
        s = by[k.source]
        out.append({"source": k.source, "entity": list(k.entity), "event": k.event, "coin": k.coin,
                    "timeline": [[e.fetched, e.known, e.retraction, e.slot,
                                  None if e.retraction else {c: e.cells.get(c) for c in suite.declared(s)}, e.role]
                                 for e in k.entries],
                    "visible": [None if (e := k.sees(q)) is None else e.fetched for q in case["queries"]]})
    return out


def observations(case, listed):
    return sorted(([k["source"], k["coin"], k["event"], *delivery(case, k, i, e)]
                   for k in listed if k["coin"] is not None and not suite_source(case, k)["evidence"]
                   for i, e in enumerate(k["timeline"])), key=lambda o: (o[0], o[1], o[2], o[3]))


def suite_source(case, k):
    return next(s for s in case["sources"] if s["name"] == k["source"])


def delivery(case, k, i, e):
    s = suite_source(case, k)
    fetched, known, retraction, slot, cells, role = e
    values = [None if retraction else lean_check.bits(cells[v]) for v in s["values"]]
    payload = None if role is None else (
        [lean_check.bits(x) for x in role[:-1]] + [role[-1]] if "bars" in s["roles"] else [lean_check.bits(role[0])])
    return [fetched, known, retraction, slot, values, payload, i + 1 == len(k["timeline"])]


def python(case, root):
    """`ingest/resolve.py`'s result and observations on the case's image under `root`."""
    try:
        keys, tables = resolve.resolve(case["sources"], resolve.read_footers(root, case["sources"]), case["universe"],
                                       case["version"])
    except resolve.Refusal as r:
        return {"result": r.code, "observations": None}
    listed = listing(case, keys)
    return {"result": {"keys": listed}, "observations": observations(case, listed)}


def rust(case, root, mm=kernel.MM):
    """`mm resolve`'s on the same image."""
    given = {k: case[k] for k in ("universe", "sources", "version", "queries")}
    out = subprocess.run([str(mm), "resolve", str(root)], input=json.dumps(given), capture_output=True, text=True,
                         check=True).stdout
    return json.loads(out)
