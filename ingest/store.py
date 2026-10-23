"""Point-in-time revision store.

Every row is a revision of a (coin, eventTime) key, holding only what was observed: the values,
fetchedAt and source, with a hash of the content. A write appends only rows whose content
differs from the key's latest live revision, into a new read-only file. A key that a complete
fetch no longer lists gets a tombstone revision (`tombstone` true, values null), and a later
listing restores it. knownAt is never stored: `known_at` computes it from a revision's fields by
the policy's rule. A dataset version is a fetchedAt cutoff; `as_of(t, version)` is the version's
data known by t, and `as_of(t, t)` is the content live at t.
"""

import hashlib
import json
import os
from pathlib import Path

import polars as pl

from ingest.policy import DELTA, HOLDOUT_START, HOUR, POLICY, SETTLEMENT_LATENCY


KEY = ["coin", "eventTime"]
META = ["fetchedAt", "source", "hash"]


def known_at(dataset):
    """A revision's knownAt from its observed fields (C0.3; C0.4 as amended). `mm` applies the same rule."""
    if dataset == "funding":
        r = pl.col("reportedTime")
        return pl.max_horizontal(r // HOUR * HOUR + DELTA, r + SETTLEMENT_LATENCY)
    if dataset == "bars_4h" or dataset.startswith("events_"):
        return pl.col("eventTime") + DELTA
    return pl.col("fetchedAt")


def live(df):
    return pl.col("tombstone").is_null() if "tombstone" in df.columns else pl.lit(True)


def _hash(row):
    return hashlib.sha256(json.dumps(row, sort_keys=True).encode()).hexdigest()


class Store:
    def __init__(self, root, event_before=None, key=KEY):
        self.root = Path(root)
        self.event_before = event_before
        self.key = list(key)
        self._cache = {}

    def _files(self, dataset):
        d = self.root / dataset
        return sorted(d.glob("*.parquet")) if d.exists() else []

    def revisions(self, dataset):
        files = self._files(dataset)
        cached = self._cache.get(dataset)
        if cached is None or cached[0] != files:
            df = pl.concat([pl.read_parquet(f).drop("knownAt", strict=False) for f in files], how="diagonal_relaxed") if files else None
            self._cache[dataset] = cached = (files, df)
        return cached[1]

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
        path = self.root / dataset / f"{fetched_at}.parquet"
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            raise FileExistsError(path)
        df.write_parquet(path)
        os.chmod(path, 0o444)
        return df.height

    def as_of(self, dataset, t, version):
        """Per key, the latest revision fetched by `version`, unless a tombstone, if its knownAt is <= t."""
        df = self.revisions(dataset)
        if df is None:
            return df
        return (df.filter(pl.col("fetchedAt") <= version).sort("fetchedAt").group_by(self.key, maintain_order=True).last()
                .filter(live(df)).with_columns(known_at(dataset).alias("knownAt")).filter(pl.col("knownAt") <= t))


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
    return Store(root / "store", event_before=HOLDOUT_START), Store(root / "holdout")


def write_split(search, holdout, dataset, df, fetched_at, source, holdout_start=HOLDOUT_START):
    split = pl.col("eventTime") < holdout_start
    return (search.write(dataset, df.filter(split), fetched_at, source),
            holdout.write(dataset, df.filter(~split), fetched_at, source))
