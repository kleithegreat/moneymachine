"""Point-in-time revision store.

Every row is a revision of a (coin, eventTime) key, holding only what was observed: the values,
fetchedAt and source, with a hash of the content. A write appends only rows whose content
differs from the key's latest live revision, into a new read-only file. A key that a complete
fetch no longer lists gets a tombstone revision (`tombstone` true, values null), and a later
listing restores it. knownAt is never stored: `ingest/resolve.py` computes it from a revision's fields by the rule
of the store's policy (`policy.json` in the search store, which also governs its holdout store), resolving the
revisions bitemporally (kernel/RULES.md §6): each is delivered at its own knownAt, a correction no earlier than it was
fetched, and a tombstone retracts the key from its fetchedAt, with no fallback to an older value. A dataset version is a
fetchedAt cutoff; `as_of(t, version)` is what a query at t sees of the version, and `as_of(t, t)` is the content live
at t. A search store refuses to read a dataset with an event time at or after its boundary (SOURCES.md §2).
"""

import hashlib
import json
import os
from pathlib import Path

import polars as pl
import pyarrow as pa

from ingest import knownat, resolve
from ingest.policy import HOLDOUT_START, HOUR, POLICY


KEY = ["coin", "eventTime"]
META = ["fetchedAt", "source", "hash"]


def ruled(dataset):
    """Whether a dataset's knownAt follows the policy's rule; any other is known when fetched."""
    return dataset in ("funding", "bars_4h") or dataset.startswith("events_")


def rule_expr(dataset, policy):
    """The dataset's availability rule (kernel/RULES.md §3): a first revision's knownAt from its observed fields (C0.3;
    C0.4 as amended). `mm` applies the same rule."""
    if dataset == "funding":
        r = {"field": "reportedTime"}
        return {"max": [{"add": [{"floor": [r, {"ms": HOUR}]}, {"ms": policy["delta_ms"]}]},
                        {"add": [r, {"ms": policy["settlement_latency_ms"]}]}]}
    if ruled(dataset):
        return {"add": [{"field": "eventTime"}, {"ms": policy["delta_ms"]}]}
    return {"field": "fetchedAt"}


def known_at(dataset, policy, row):
    """A first revision's knownAt from its time fields `row`: the dataset's rule, evaluated as the resolver does."""
    expr = knownat.check(json.dumps({"rule": 1, "expr": rule_expr(dataset, policy)}), ["eventTime", "reportedTime", "fetchedAt"], [])
    return knownat.evaluate(expr, row, {})


def live(df):
    return pl.col("tombstone").is_null() if "tombstone" in df.columns else pl.lit(True)


def _hash(row):
    return hashlib.sha256(json.dumps(row, sort_keys=True).encode()).hexdigest()


class Store:
    def __init__(self, root, event_before=None, key=KEY, policy_root=None):
        self.root = Path(root)
        self.event_before = event_before
        self.key = list(key)
        self.policy_root = Path(policy_root or root)
        self._cache = {}

    def policy(self):
        return json.loads((self.policy_root / "policy.json").read_text())

    def _files(self, dataset):
        d = self.root / dataset
        return sorted(d.glob("*.parquet")) if d.exists() else []

    def _pinned(self, dataset):
        """The dataset's pinned files, with their footers read, SOURCES.md §2's footer schema checks made and, in a
        store with a boundary, the holdout check passed on their event times alone; nothing else is decoded before it
        passes. What is kept is bound to the files' identity: a changed file set is a new dataset."""
        files = self._files(dataset)
        identity = tuple((f, (st := f.stat()).st_size, st.st_mtime_ns) for f in files)
        kept = self._cache.get(dataset)
        if kept is None or kept["identity"] != identity:
            self._cache[dataset] = kept = {"identity": identity, "footers": [resolve.Footer(f) for f in files],
                                           "checked": False, "revisions": None, "resolved": {}}
        if self.event_before is not None and not kept["checked"]:
            resolve.holdout_check([(kept["footers"], "eventTime")], self.event_before)
        kept["checked"] = True
        return kept

    def revisions(self, dataset):
        kept = self._pinned(dataset)
        if kept["revisions"] is None and kept["footers"]:
            kept["revisions"] = pl.concat([pl.read_parquet(f.data.to_pybytes()).drop("knownAt", strict=False) for f in kept["footers"]],
                                          how="diagonal_relaxed")
        return kept["revisions"]

    def write(self, dataset, df, fetched_at, source, complete=None):
        """Append the changed rows of df (KEY + observed values); return how many. `complete`, an expression
        over stored rows, selects the keys df lists in full: those it omits are tombstoned."""
        if "knownAt" in df.columns:
            raise ValueError("knownAt is computed by known_at, never stored")
        if self.event_before is not None and df.height and df["eventTime"].max() >= self.event_before:
            raise ValueError(f"{self.root} refuses rows with eventTime >= {self.event_before}")
        cols = list(dict.fromkeys(self.key + ["eventTime"] + [c for c in df.columns if c not in META]))
        hashed = lambda d: pl.Series("hash", [_hash(r) for r in d.select(cols).iter_rows(named=True)], pl.Utf8)
        df = df.with_columns(hashed(df), pl.lit(fetched_at, pl.Int64).alias("fetchedAt"), pl.lit(source).alias("source"))
        old = self.revisions(dataset)
        if old is not None:
            latest = old.sort("fetchedAt").group_by(self.key).last()
            listed = df.select(self.key)
            current = latest.filter(live(latest))
            if set(cols) <= set(current.columns):
                df = df.join(current.select(self.key).with_columns(hashed(current)), on=self.key + ["hash"], how="anti")
            if complete is not None:
                gone = (latest.filter(complete & live(latest)).join(listed, on=self.key, how="anti")
                        .select(list(dict.fromkeys(self.key + ["eventTime"])))
                        .with_columns(pl.lit(True).alias("tombstone")))
                gone = gone.with_columns(
                    pl.Series("hash", [_hash(r) for r in gone.iter_rows(named=True)], pl.Utf8),
                    pl.lit(fetched_at, pl.Int64).alias("fetchedAt"), pl.lit(source).alias("source"))
                df = pl.concat([df, gone], how="diagonal_relaxed")
        if df.height == 0:
            return 0
        df = df.with_columns(pl.col(c).cast(pl.Float64) for c, t in df.schema.items() if t == pl.Null)
        path = self.root / dataset / f"{fetched_at}.parquet"
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            raise FileExistsError(path)
        df.write_parquet(path)
        os.chmod(path, 0o444)
        return df.height

    def source(self, dataset, footers):
        """The dataset as a source for the resolver (kernel/RULES.md §7): its key without the event time is its
        entity, its other columns are values, and its rule is the policy's."""
        policy = self.policy() if ruled(dataset) else None
        entity = [c for c in self.key if c != "eventTime"]
        times = ["eventTime", "reportedTime"] if dataset == "funding" else ["eventTime"]
        columns = {c for f in footers for c in f.names} - set(resolve.METADATA)
        return {"name": dataset, "rule": json.dumps({"rule": 1, "expr": rule_expr(dataset, policy)}), "times": times,
                "values": sorted(columns - set(entity) - set(times)), "entity": entity, "event": "eventTime",
                "slot": None, "roles": None, "evidence": False, "deps": []}

    def _resolved(self, dataset, version):
        kept = self._pinned(dataset)
        if not kept["footers"]:
            raise FileNotFoundError(f"{self.root / dataset}: no revisions")
        if version not in kept["resolved"]:
            source = self.source(dataset, kept["footers"])
            keys, tables = resolve.resolve([source], [kept["footers"]], [], version)
            kept["resolved"][version] = source, kept["footers"], list(keys.values()), tables[0]
        return kept["resolved"][version]

    def _frame(self, dataset, version, chosen, **extra):
        """The stored rows of the `chosen` entries, in order, as polars, then the `extra` columns. Only files with a
        row fetched by `version` give columns and types, as the empty tables of those files do; with none, the footers."""
        source, footers, _, tables = self._resolved(dataset, version)
        by_table = {}
        for position, (_, e) in enumerate(chosen):
            by_table.setdefault(e.where[0], []).append((position, e.where[1]))
        if tables:
            parts = [pl.from_arrow(t.slice(0, 0)).with_columns(pl.lit(None, pl.Int64).alias("#")) for t in tables]
        else:
            types = {}
            for f in footers:
                for c in resolve.columns_read(f, source):
                    types.setdefault(c, f.types[c])
            parts = [pl.from_arrow(pa.table({c: pa.array([], t) for c, t in types.items()})).with_columns(pl.lit(None, pl.Int64).alias("#"))]
        for t, rows in by_table.items():
            parts.append(pl.from_arrow(tables[t].take([r for _, r in rows])).with_columns(pl.Series("#", [p for p, _ in rows], pl.Int64)))
        frame = pl.concat(parts, how="diagonal_relaxed").sort("#", nulls_last=True).drop("#")
        return frame.with_columns(*(pl.Series(k, v, pl.Int64 if k == "knownAt" else pl.Boolean) for k, v in extra.items()))

    def entries(self, dataset, version):
        """Every delivered revision of the dataset at `version` (kernel/RULES.md §6): the stored columns, `knownAt` and
        `retraction`, key by key in the order the keys first appear, each key's by knownAt. A retraction delivers no
        value: its values are null."""
        source = self._resolved(dataset, version)[0]
        chosen = [(k, e) for k in self._resolved(dataset, version)[2] for e in k.entries]
        frame = self._frame(dataset, version, chosen, knownAt=[e.known for _, e in chosen],
                            retraction=[e.retraction for _, e in chosen])
        return frame.with_columns(*(pl.when(~pl.col("retraction")).then(pl.col(c)).alias(c) for c in source["values"] if c in frame.columns))

    def as_of(self, dataset, t, version):
        """Per key, the latest revision of `version` known by t, unless it retracts the key."""
        seen = [(k, e) for k in self._resolved(dataset, version)[2] if (e := k.sees(t)) is not None]
        return self._frame(dataset, version, seen, knownAt=[e.known for _, e in seen])


def stores(data_root):
    """The search store (refuses holdout rows) and the holdout store. The search store carries the
    policy the kernel enforces, so a caller cannot choose a different holdout boundary."""
    root = Path(data_root)
    bound = root / "store" / "policy.json"
    bound.parent.mkdir(parents=True, exist_ok=True)
    if not bound.exists():
        bound.write_text(json.dumps(POLICY, indent=1) + "\n")
    if json.loads(bound.read_text()) != POLICY:
        raise ValueError(f"{bound} differs from the repository policy")
    return Store(root / "store", event_before=HOLDOUT_START), Store(root / "holdout", policy_root=root / "store")


def write_split(search, holdout, dataset, df, fetched_at, source, holdout_start=HOLDOUT_START):
    split = pl.col("eventTime") < holdout_start
    return (search.write(dataset, df.filter(split), fetched_at, source),
            holdout.write(dataset, df.filter(~split), fetched_at, source))
