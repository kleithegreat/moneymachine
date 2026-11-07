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


def python(case, root):
    """`ingest/resolve.py`'s result and observations on the case's image under `root`."""
    try:
        keys, tables = resolve.resolve(case["sources"], resolve.read_footers(root, case["sources"]), case["universe"],
                                       case["version"])
    except resolve.Refusal as r:
        return {"result": r.code, "observations": None}
    return {"result": resolve.listing(case["sources"], keys, case["queries"]),
            "observations": resolve.observations(case["sources"], keys)}


def rust(case, root, mm=kernel.MM):
    """`mm resolve`'s on the same image."""
    given = {k: case[k] for k in ("universe", "sources", "version", "queries")}
    out = subprocess.run([str(mm), "resolve", str(root)], input=json.dumps(given), capture_output=True, text=True,
                         check=True).stdout
    return json.loads(out)
