"""Point-in-time revision store.

Every row is a revision of a (coin, eventTime) key. A write appends only rows whose
content differs from the key's latest revision, into a new read-only file. A dataset
version is a fetchedAt cutoff; `as_of(t, version)` is what was knowable at t according
to the data fetched by that cutoff.
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


def _hash(row):
    return hashlib.sha256(json.dumps(row, sort_keys=True).encode()).hexdigest()


class Store:
    def __init__(self, root, event_before=None):
        self.root = Path(root)
        self.event_before = event_before
        self._cache = {}

    def _files(self, dataset):
        d = self.root / dataset
        return sorted(d.glob("*.parquet")) if d.exists() else []

    def revisions(self, dataset):
        files = self._files(dataset)
        cached = self._cache.get(dataset)
        if cached is None or cached[0] != files:
            df = pl.concat([pl.read_parquet(f) for f in files]) if files else None
            self._cache[dataset] = cached = (files, df)
        return cached[1]

    def write(self, dataset, df, fetched_at, source):
        """Append the changed rows of df (KEY + knownAt + values); return how many."""
        if self.event_before is not None and df.height and df["eventTime"].max() >= self.event_before:
            raise ValueError(f"{self.root} refuses rows with eventTime >= {self.event_before}")
        values = [c for c in df.columns if c not in KEY + META]
        df = df.with_columns(
            pl.Series("hash", [_hash(r) for r in df.select(KEY + ["knownAt"] + values).iter_rows(named=True)]),
            pl.lit(fetched_at, pl.Int64).alias("fetchedAt"),
            pl.lit(source).alias("source"),
        )
        old = self.revisions(dataset)
        if old is not None:
            latest = old.sort("fetchedAt").group_by(KEY).last().select(KEY + ["hash"])
            df = df.join(latest, on=KEY + ["hash"], how="anti")
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
        """Per key, the latest revision with fetchedAt <= version and knownAt <= t."""
        df = self.revisions(dataset)
        if df is None:
            return df
        return (df.filter((pl.col("fetchedAt") <= version) & (pl.col("knownAt") <= t))
                .sort("fetchedAt").group_by(KEY, maintain_order=True).last())


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
