"""Point-in-time revision store.

Every row is a revision of a (coin, eventTime) key. A write appends only rows whose
content differs from the key's latest revision, into a new read-only file. A key that a complete
fetch no longer lists gets a tombstone revision (`tombstone` true, values null), and a later
listing restores it. A dataset version is a fetchedAt cutoff; `as_of(t, version)` is what was
knowable at t according to the data fetched by that cutoff.
"""

import hashlib
import json
import os
from pathlib import Path

import polars as pl

_POLICY = json.loads((Path(__file__).parent.parent / "policy.json").read_text())
DELTA = _POLICY["delta_ms"]
W_START = _POLICY["w_start"]
HOLDOUT_START = _POLICY["holdout_start"]
W_END = _POLICY["w_end"]

KEY = ["coin", "eventTime"]
META = ["knownAt", "fetchedAt", "source", "hash"]


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
            df = pl.concat([pl.read_parquet(f) for f in files], how="diagonal_relaxed") if files else None
            self._cache[dataset] = cached = (files, df)
        return cached[1]

    def write(self, dataset, df, fetched_at, source, complete=None):
        """Append the changed rows of df (KEY + knownAt + values); return how many. Rows without
        knownAt are known when fetched. `complete`, an expression over stored rows, selects the keys df
        lists in full: those it omits are tombstoned."""
        if self.event_before is not None and df.height and df["eventTime"].max() >= self.event_before:
            raise ValueError(f"{self.root} refuses rows with eventTime >= {self.event_before}")
        values = [c for c in df.columns if c not in self.key + ["eventTime"] + META]
        cols = list(dict.fromkeys(self.key + ["eventTime"] + ["knownAt"] * ("knownAt" in df.columns) + values))
        df = df.with_columns(
            pl.Series("hash", [_hash(r) for r in df.select(cols).iter_rows(named=True)]),
            pl.lit(fetched_at, pl.Int64).alias("fetchedAt"),
            pl.lit(source).alias("source"),
        )
        if "knownAt" not in df.columns:
            df = df.with_columns(pl.lit(fetched_at, pl.Int64).alias("knownAt"))
        old = self.revisions(dataset)
        if old is not None:
            latest = old.sort("fetchedAt").group_by(self.key).last()
            listed = df.select(self.key)
            df = df.join(latest.select(self.key + ["hash"]), on=self.key + ["hash"], how="anti")
            if complete is not None:
                gone = (latest.filter(complete & live(latest)).join(listed, on=self.key, how="anti")
                        .select(list(dict.fromkeys(self.key + ["eventTime"])))
                        .with_columns(pl.lit(fetched_at, pl.Int64).alias("knownAt"), pl.lit(True).alias("tombstone")))
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
        """Per key, the latest revision with fetchedAt <= version and knownAt <= t, unless a tombstone."""
        df = self.revisions(dataset)
        if df is None:
            return df
        return (df.filter((pl.col("fetchedAt") <= version) & (pl.col("knownAt") <= t))
                .sort("fetchedAt").group_by(self.key, maintain_order=True).last().filter(live(df)))


def stores(data_root):
    """The search store (refuses holdout rows) and the holdout store. The search store carries the
    policy the kernel enforces, so a caller cannot choose a different holdout boundary."""
    root = Path(data_root)
    bound = root / "store" / "policy.json"
    bound.parent.mkdir(parents=True, exist_ok=True)
    if not bound.exists():
        bound.write_text(json.dumps(_POLICY, indent=1) + "\n")
    if json.loads(bound.read_text()) != _POLICY:
        raise ValueError(f"{bound} differs from the repository policy")
    return Store(root / "store", event_before=HOLDOUT_START), Store(root / "holdout")


def write_split(search, holdout, dataset, df, fetched_at, source, holdout_start=HOLDOUT_START):
    split = pl.col("eventTime") < holdout_start
    return (search.write(dataset, df.filter(split), fetched_at, source),
            holdout.write(dataset, df.filter(~split), fetched_at, source))
