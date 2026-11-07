"""The resolver of kernel/RULES.md §6 (B3 revision) over the store's Parquet layout (kernel/SOURCES.md §2): every
`.parquet` file of a source's directory holds its stored revisions. `resolve` returns each key's timeline, one entry per
delivered revision at its own effective knownAt. `mm` implements the same rules in Rust (`kernel/mm/src/resolve.rs`).

A source is a declaration reduced to what resolution reads (RULES.md §7): `name` (its directory), `rule`, `times`,
`values`, `entity`, `event`, `slot`, `roles`, `evidence` and `deps`.

Before a holdout check passes, a search reads file footers and the event-time column alone; nothing else is decoded,
and no statistic of another column is used."""

import base64
import math
from collections import defaultdict
from pathlib import Path

import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.parquet as pq

from ingest import knownat

LO, HI = knownat.LO, knownat.HI
CELL_LO, CELL_HI = -(2**63), 2**63 - 1
METADATA = ("fetchedAt", "tombstone", "source", "hash", "upstream", "knownAt")
UNCHECKABLE = "the holdout check cannot be made: an event time is not a non-null Int64 in range"


class Refusal(ValueError):
    """An outcome with no timelines, by RULES.md §7's code: E_DECL, E_RULE or INVALID."""

    def __init__(self, code, detail=""):
        super().__init__(f"{code}: {detail}" if detail else code)
        self.code = code


class Entry:
    __slots__ = ("fetched", "known", "retraction", "slot", "cells", "role", "where")

    def __init__(self, fetched, known, retraction, slot, cells, role, where):
        self.fetched, self.known, self.retraction, self.slot = fetched, known, retraction, slot
        self.cells, self.role, self.where = cells, role, where


class Key:
    __slots__ = ("source", "entity", "event", "coin", "entries")

    def __init__(self, source, entity, event, coin):
        self.source, self.entity, self.event, self.coin, self.entries = source, entity, event, coin, []

    def sees(self, t):
        """The entry a query at t sees, or None."""
        seen = None
        for e in self.entries:
            if e.known <= t:
                seen = e
        return None if seen is None or seen.retraction else seen


def ident(cell):
    """A cell's identity: an integer is never a non-integer, a boolean never an integer, the two zeros one value."""
    return ("f", cell + 0.0) if type(cell) is float else (type(cell).__name__, cell)


def role_columns(s):
    return next(iter(s["roles"].values())) if s["roles"] else []


def declared(s):
    return sorted(set(s["values"] + s["times"] + s["entity"] + [s["event"]] + ([s["slot"]] if s["slot"] else [])
                      + role_columns(s)))


def check_declarations(sources):
    """The checked rule of each source, or Refusal: E_DECL if a declared column is one the store writes, else E_RULE
    if a rule fails checking, both whatever the rows hold."""
    if any(set(METADATA) & set(declared(s)) for s in sources):
        raise Refusal("E_DECL")
    try:
        return [knownat.check(s["rule"], [*s["times"], "fetchedAt"], [d["name"] for d in s["deps"]]) for s in sources]
    except knownat.RuleError as e:
        raise Refusal("E_RULE", str(e)) from None


class Footer:
    def __init__(self, path):
        self.path = path
        try:
            file = pq.ParquetFile(path)
            self.rows = file.metadata.num_rows
            self.schema = file.schema_arrow
            names = file.schema.to_arrow_schema().names
            blob = (file.metadata.metadata or {}).get(b"ARROW:schema")
            embedded = pa.ipc.read_schema(pa.py_buffer(base64.b64decode(blob))).names if blob else names
        except (pa.ArrowException, OSError, ValueError) as e:
            raise Refusal("INVALID", f"{path}: {e}") from None
        if len(set(names)) != len(names) or embedded != names:
            raise Refusal("INVALID", f"{path}: top-level names repeat or differ between the schemas")
        self.names = names
        types = dict(zip(self.schema.names, self.schema.types))
        if types.get("fetchedAt") != pa.int64() or types.get("tombstone", pa.bool_()) != pa.bool_():
            raise Refusal("INVALID", f"{path}: fetchedAt is not Int64 or tombstone is not Boolean")
        self.types = types


def read_footers(root, sources):
    """Each source's footers, its files' in name order; Refusal if a file fails SOURCES.md §2's footer schema checks."""
    return [[Footer(f) for f in sorted((Path(root) / s["name"]).glob("*.parquet"))] for s in sources]


def columns_read(footer, s):
    """The columns of a file the resolver decodes for source s, in file order: those it declares and the metadata it
    reads."""
    wanted = {"fetchedAt", "tombstone", *declared(s), *(["upstream"] if s["deps"] else [])}
    return [c for c in footer.names if c in wanted]


def holdout_check(footers, event, boundary):
    """SOURCES.md §2's holdout check on the event-time column of every row of `footers`, which projects that column
    alone: ValueError, with the prescribed message, or None. Any uncheckable event time takes precedence."""
    least = None
    for f in footers:
        if f.rows == 0:
            continue
        col = pq.read_table(f.path, columns=[event]).column(0) if event in f.names else None
        if col is None or col.type != pa.int64() or col.null_count:
            raise ValueError(UNCHECKABLE)
        extremes = pc.min_max(col)
        if extremes["min"].as_py() < LO or extremes["max"].as_py() > HI:
            raise ValueError(UNCHECKABLE)
        crossing = pc.min(pc.filter(col, pc.greater_equal(col, boundary))).as_py()
        if crossing is not None and (least is None or crossing < least):
            least = crossing
    if least is not None:
        raise ValueError(f"holdout crossing: event time {least} at or after {boundary}")


def cell(v):
    """A parsed JSON value as (whether it is a cell, the cell)."""
    if v is None or type(v) in (bool, str):
        return True, v
    if type(v) is int:
        return CELL_LO <= v <= CELL_HI, v
    if type(v) is knownat.Real:
        return math.isfinite(v.value), v.value
    return False, None


def lineage_keys(text, names, entity_columns):
    """A lineage text's members, each dependency name to its keys (source, entity, event), or Refusal."""
    try:
        doc = knownat.parse(text)
    except knownat.Malformed:
        raise Refusal("INVALID", "lineage") from None
    if type(doc) is not dict:
        raise Refusal("INVALID", "lineage is not an object")
    out = {}
    for name, keys in doc.items():
        if type(keys) is not list:
            raise Refusal("INVALID", "lineage member")
        out[name] = []
        for k in keys:
            if not (type(k) is list and len(k) == 3 and type(k[0]) is str and k[0] in names and type(k[1]) is list
                    and len(k[1]) == entity_columns[names[k[0]]] and type(k[2]) is int and LO <= k[2] <= HI):
                raise Refusal("INVALID", "lineage key")
            cells = [cell(c) for c in k[1]]
            if not all(ok for ok, _ in cells):
                raise Refusal("INVALID", "lineage key")
            out[name].append((names[k[0]], tuple(ident(c) for _, c in cells), k[2]))
    return out


class Rev:
    __slots__ = ("fetched", "tombstone", "cells", "lineage", "where")

    def __init__(self, fetched, tombstone, cells, lineage, where):
        self.fetched, self.tombstone, self.cells, self.lineage, self.where = fetched, tombstone, cells, lineage, where


def read_revisions(footers, tables, s, version, names, entity_columns):
    """Source s's eligible revisions (fetchedAt <= version) by key, each decoded, or Refusal. `tables` receives each
    file's table, indexed as `where` says."""
    cols, event = declared(s), s["event"]
    derived = bool(s["deps"])
    by_key = defaultdict(list)
    for f in footers:
        if f.rows == 0:
            continue
        whole = pq.read_table(f.path, columns=columns_read(f, s))
        fetched = whole.column("fetchedAt")
        if fetched.null_count:
            raise Refusal("INVALID", f"{f.path}: a null fetchedAt")
        eligible = pc.indices_nonzero(pc.less_equal(fetched, version)).to_pylist()
        if not eligible:
            continue
        present = [c for c in columns_read(f, s) if c in cols]
        table = whole.take(eligible)
        for c in present:
            t = f.types[c]
            if not (t in (pa.int64(), pa.float64(), pa.string(), pa.large_string(), pa.bool_())):
                raise Refusal("INVALID", f"{f.path}: column {c} of type {t} is not a cell")
        tables.append(table)
        where = len(tables) - 1
        data = {c: table.column(c).to_pylist() for c in table.column_names}
        for j in range(table.num_rows):
            cells = {c: data[c][j] for c in present}
            if any(type(v) is float and not math.isfinite(v) for v in cells.values()):
                raise Refusal("INVALID", f"{f.path}: a non-finite Double")
            at = data["fetchedAt"][j]
            ev = cells.get(event)
            if not (LO <= at <= HI and type(ev) is int and LO <= ev <= HI):
                raise Refusal("INVALID", f"{f.path}: fetchedAt or event time outside the range")
            tombstone = bool(data["tombstone"][j]) if "tombstone" in data else False
            lineage = None
            if derived and not tombstone:
                text = data["upstream"][j] if "upstream" in data and f.types["upstream"] in (pa.string(), pa.large_string()) else None
                if text is None:
                    raise Refusal("INVALID", f"{f.path}: no lineage")
                lineage = lineage_keys(text, names, entity_columns)
            entity = tuple(ident(cells.get(c)) for c in s["entity"])
            by_key[entity, ev].append(Rev(at, tombstone, cells, lineage, (where, j)))
    return by_key


def resolve(sources, footers, universe, version, holdout=None):
    """The timelines of every key with an eligible revision, {(source index, entity identity, event): Key}, for the
    registry `sources` with their `footers` (`read_footers`), and each source's list of decoded tables, which
    `Entry.where` indexes
    (table, row). Refusal for E_DECL, E_RULE and INVALID; ValueError for a holdout refusal when `holdout` is a
    boundary."""
    exprs = check_declarations(sources)
    names = {s["name"]: i for i, s in enumerate(sources)}
    if holdout is not None:
        for s, fs in zip(sources, footers):
            holdout_check(fs, s["event"], holdout)
    tables = [[] for _ in sources]
    entity_columns = {i: len(s["entity"]) for i, s in enumerate(sources)}
    revisions = [read_revisions(fs, tables[i], s, version, names, entity_columns)
                 for i, (s, fs) in enumerate(zip(sources, footers))]
    keys = {}

    def build(i):
        s = sources[i]
        if s["name"] in done:
            return
        done.add(s["name"])
        for d in s["deps"]:
            for u in d["sources"]:
                build(names[u])
        for (entity, event), revs in revisions[i].items():
            revs.sort(key=lambda r: r.fetched)
            if any(a.fetched == b.fetched for a, b in zip(revs, revs[1:])):
                raise Refusal("INVALID", f"{s['name']}: two revisions of a key share a fetchedAt")
            first = revs[0].cells
            key = Key(s["name"], tuple(first.get(c) for c in s["entity"]), event, None)
            if not s["evidence"] and "coin" in s["entity"]:
                coin = first.get("coin")
                key.coin = universe.index(coin) if type(coin) is str and coin in universe else None
            timeline(i, key, revs, exprs[i])
            keys[i, entity, event] = key

    def upstream_time(r, d):
        times = []
        for u, entity, event in r.lineage.get(d["name"], []):
            if sources[u]["name"] not in d["sources"] or (u, entity, event) not in keys:
                return None
            seen = [e.known for e in keys[u, entity, event].entries if e.fetched <= r.fetched]
            if not seen:
                return None
            times.append(max(seen))
        return max(times) if times else None

    def timeline(i, key, revs, expr):
        s, entries, last = sources[i], key.entries, None
        columns = declared(s)
        for r in revs:
            if last is not None and last.tombstone == r.tombstone and all(
                    ident(last.cells.get(c)) == ident(r.cells.get(c)) for c in columns):
                last = r
                continue
            known = None if r.tombstone else candidate(s, expr, r, last, entries)
            payload = None if known is None else decode(s, r)
            if known is None or payload is None:
                if entries:
                    entries.append(Entry(r.fetched, max(r.fetched, entries[-1].known), True, entries[-1].slot,
                                         None, None, r.where))
            else:
                entries.append(Entry(r.fetched, known, False, payload[0], r.cells, payload[1], r.where))
            last = r

    def candidate(s, expr, r, last, entries):
        deps = {}
        for d in s["deps"]:
            deps[d["name"]] = upstream_time(r, d)
            if deps[d["name"]] is None:
                return None
        row = {t: r.cells.get(t) for t in s["times"]} | {"fetchedAt": r.fetched}
        try:
            known = knownat.evaluate(expr, row, deps)
        except knownat.Rejected:
            return None
        raises = [r.fetched] if last is not None else []
        raises += [entries[-1].known] if entries else []
        raises += [deps[d["name"]] + d["lag"] for d in s["deps"]]
        if any(not LO <= x <= HI for x in raises):
            return None
        known = max([known, *raises])
        return known

    def decode(s, r):
        slot = None
        if s["slot"]:
            slot = r.cells.get(s["slot"])
            if type(slot) is not int:
                return None
        if not s["roles"]:
            return slot, None
        role = [r.cells.get(c) for c in role_columns(s)]
        numbers = role if "settlement" in s["roles"] else role[:-1]
        if not all(type(x) in (int, float) for x in numbers) or ("bars" in s["roles"] and type(role[-1]) is not int):
            return None
        return slot, role

    done = set()
    for i in range(len(sources)):
        build(i)
    return keys, tables
