"""Point-in-time revision store.

Every row is a revision of a (coin, eventTime) key, holding only what was observed: the values,
fetchedAt and source, with a hash of the content. A write appends only rows whose content
differs from the key's latest live revision, into a new read-only file. A key that a complete
fetch no longer lists gets a tombstone revision (`tombstone` true, values null), and a later
listing restores it. knownAt is never stored: `known_at` computes it from a revision's fields by
the rule of the store's policy (`policy.json` in the search store, which also governs its holdout
store). A revision whose observed values differ from its key's first revision is a correction: it is
known no earlier than it was fetched, so before then the key is hidden, never shown with a value
nobody had at that time. A dataset version is a fetchedAt cutoff; `as_of(t, version)` is the
version's data known by t, and `as_of(t, t)` is the content live at t.
"""

import hashlib
import json
import os
from collections.abc import Iterable
from pathlib import Path
from typing import Any

import polars as pl

from ingest.policy import HOLDOUT_START, HOUR, POLICY, EpochMs, Policy

KEY = ["coin", "eventTime"]
META = ["fetchedAt", "source", "hash"]


def ruled(dataset: str) -> bool:
    """Whether a dataset's knownAt follows the policy's rule; any other is known when fetched."""
    return dataset in ("funding", "bars_4h") or dataset.startswith("events_")


def known_at(dataset: str, policy: Policy | None) -> pl.Expr:
    """A first revision's knownAt from its observed fields by `policy`'s rule (C0.3; C0.4 as amended). `mm` applies
    the same rule."""
    if policy is None or not ruled(dataset):
        return pl.col("fetchedAt")
    if dataset == "funding":
        r = pl.col("reportedTime")
        return pl.max_horizontal(r // HOUR * HOUR + policy["delta_ms"], r + policy["settlement_latency_ms"])
    return pl.col("eventTime") + policy["delta_ms"]


def live(df: pl.DataFrame) -> pl.Expr:
    return pl.col("tombstone").is_null() if "tombstone" in df.columns else pl.lit(True)


def _hash(row: dict[str, Any]) -> str:
    return hashlib.sha256(json.dumps(row, sort_keys=True).encode()).hexdigest()


class Store:
    def __init__(
        self,
        root: Path,
        event_before: EpochMs | None = None,
        key: Iterable[str] = KEY,
        policy_root: Path | None = None,
    ) -> None:
        self.root = Path(root)
        self.event_before = event_before
        self.key = list(key)
        self.policy_root = Path(policy_root or root)
        self._cache: dict[str, tuple[list[Path], pl.DataFrame | None]] = {}

    def policy(self) -> Policy:
        policy: Policy = json.loads((self.policy_root / "policy.json").read_text())
        return policy

    def _files(self, dataset: str) -> list[Path]:
        d = self.root / dataset
        return sorted(d.glob("*.parquet")) if d.exists() else []

    def revisions(self, dataset: str) -> pl.DataFrame | None:
        files = self._files(dataset)
        cached = self._cache.get(dataset)
        if cached is None or cached[0] != files:
            df = (
                pl.concat([pl.read_parquet(f).drop("knownAt", strict=False) for f in files], how="diagonal_relaxed")
                if files
                else None
            )
            self._cache[dataset] = cached = (files, df)
        return cached[1]

    def write(
        self, dataset: str, df: pl.DataFrame, fetched_at: EpochMs, source: str, complete: pl.Expr | None = None
    ) -> int:
        """Append the changed rows of df (KEY + observed values); return how many. `complete`, an expression
        over stored rows, selects the keys df lists in full: those it omits are tombstoned."""
        if "knownAt" in df.columns:
            raise ValueError("knownAt is computed by known_at, never stored")
        if self.event_before is not None and df.height and df["eventTime"].max() >= self.event_before:
            raise ValueError(f"{self.root} refuses rows with eventTime >= {self.event_before}")
        cols = list(dict.fromkeys(self.key + ["eventTime"] + [c for c in df.columns if c not in META]))

        def hashed(d: pl.DataFrame) -> pl.Series:
            return pl.Series("hash", [_hash(r) for r in d.select(cols).iter_rows(named=True)], pl.Utf8)

        df = df.with_columns(
            hashed(df), pl.lit(fetched_at, pl.Int64).alias("fetchedAt"), pl.lit(source).alias("source")
        )
        old = self.revisions(dataset)
        if old is not None:
            latest = old.sort("fetchedAt").group_by(self.key).last()
            listed = df.select(self.key)
            current = latest.filter(live(latest))
            if set(cols) <= set(current.columns):
                df = df.join(current.select(self.key).with_columns(hashed(current)), on=self.key + ["hash"], how="anti")
            if complete is not None:
                gone = (
                    latest.filter(complete & live(latest))
                    .join(listed, on=self.key, how="anti")
                    .select(list(dict.fromkeys(self.key + ["eventTime"])))
                    .with_columns(pl.lit(True).alias("tombstone"))
                )
                gone = gone.with_columns(
                    pl.Series("hash", [_hash(r) for r in gone.iter_rows(named=True)], pl.Utf8),
                    pl.lit(fetched_at, pl.Int64).alias("fetchedAt"),
                    pl.lit(source).alias("source"),
                )
                df = pl.concat([df, gone], how="diagonal_relaxed")
        if df.height == 0:
            return 0
        path = self.root / dataset / f"{fetched_at}.parquet"
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            raise FileExistsError(path)
        df.write_parquet(path)
        os.chmod(path, 0o444)
        height: int = df.height
        return height

    def as_of(self, dataset: str, t: EpochMs, version: EpochMs) -> pl.DataFrame:
        """Per key, the latest revision fetched by `version`, unless a tombstone, if its knownAt is <= t: the rule's
        time, or for a correction the later of that and its fetchedAt."""
        df = self.revisions(dataset)
        if df is None:
            raise FileNotFoundError(f"{self.root / dataset}: no revisions")
        df = df.filter(pl.col("fetchedAt") <= version).sort("fetchedAt")
        values = [c for c in df.columns if c not in self.key + META + ["tombstone"]]
        first = (
            df.group_by(self.key, maintain_order=True)
            .first()
            .select(self.key + [pl.col(c).alias(f"{c}#first") for c in values])
        )
        same = pl.all_horizontal([pl.col(c).eq_missing(pl.col(f"{c}#first")) for c in values])
        rule = known_at(dataset, self.policy() if ruled(dataset) else None)
        return (
            df.group_by(self.key, maintain_order=True)
            .last()
            .filter(live(df))
            .join(first, on=self.key, how="left", maintain_order="left")
            .with_columns(
                pl.when(same).then(rule).otherwise(pl.max_horizontal(rule, pl.col("fetchedAt"))).alias("knownAt")
            )
            .drop([f"{c}#first" for c in values])
            .filter(pl.col("knownAt") <= t)
        )


def stores(data_root: Path | str) -> tuple[Store, Store]:
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


def write_split(
    search: Store,
    holdout: Store,
    dataset: str,
    df: pl.DataFrame,
    fetched_at: EpochMs,
    source: str,
    holdout_start: EpochMs = HOLDOUT_START,
) -> tuple[int, int]:
    split = pl.col("eventTime") < holdout_start
    return (
        search.write(dataset, df.filter(split), fetched_at, source),
        holdout.write(dataset, df.filter(~split), fetched_at, source),
    )
