"""Market data for the thesis track through a fixed-host adapter (audit/criteria.md, stage 10).

The adapter is the venue's public info endpoint with only the frozen read request types; there is no
signing, account or order operation anywhere. Every response is archived with its retrieval time.
Final bars and funding rows are cached per market, each file rewritten atomically under its own lock: extended
incrementally, every hole the venue left, before the first row too, retried each `repair_every` for as long as it stays
one, and a cached row is never rewritten. A candle's open is known at its open plus δ and its close at its close plus δ
(C0.3's rule), whenever it was first read, so a read as of a cutoff does not depend on what the cache holds; one shown
but not final is held in memory, so a read holding the newest row it can show asks the venue for nothing. A builder (HIP-3)
market's hourly bars are its recorded mark prices (stage 10 revision of 2026-10-23): `record_marks` samples every builder
dex's `metaAndAssetCtxs` once an hour, and `mark_bars` builds the bars from those samples as known at `now`.
"""

import functools
import hashlib
import json
import math
import os
import sys
import threading
from collections.abc import Callable, Iterable
from pathlib import Path
from typing import Any

import httpx

from ingest.hl import Info
from ingest.live import append, now_ms, read
from ingest.policy import DAY, DELTA, HOUR

ALLOWED = frozenset({"meta", "perpDexs", "candleSnapshot", "fundingHistory", "metaAndAssetCtxs"})
BUDGET_PER_MIN = 120
MARK_BUDGET = BUDGET_PER_MIN // 2  # reserve half for hourly sampling; history cannot spend it
HISTORY = {"1h": 200 * DAY, "1d": 3 * 365 * DAY + 30 * DAY, "funding": 3 * 365 * DAY + 30 * DAY}
MARK_OFFSET = 5_000
MARK_WINDOW = 5 * 60_000
STEP = {"1h": HOUR, "1d": DAY, "funding": HOUR}
SHOWN = {"1h": DELTA, "1d": DAY + DELTA, "funding": 0}  # after its time, when a row first shows
FINAL = {"1h": HOUR + DELTA, "1d": DAY + DELTA, "funding": 0}  # after its time, when a row is final and cached
REPAIR_EVERY = HOUR  # leaves C10.5's two hours from a late row's availability to its score
PAGE = 500  # holes closer than a page of rows share a request


def builder(market: str) -> bool:
    return ":" in market


def dex_of(market: str) -> str | None:
    return market.split(":")[0] if builder(market) else None


def holes(rows: list[list[Any]], step: int, start: int, end: int) -> list[tuple[int, int]]:
    """[(from, to)) of the rows missing from `rows` in [start, end): before the first, between two and after the last."""
    times: list[int] = [r[0] for r in rows]
    if not times:
        return [(start, end)]
    gaps = [(a + step, b) for a, b in zip(times, times[1:]) if b - a > step] + [(times[-1] + 1, end)]
    if times[0] - step >= start:
        gaps.insert(0, (start, times[0]))
    spans: list[tuple[int, int]] = []
    for a, b in gaps:
        if spans and a - spans[-1][1] < PAGE * step:
            spans[-1] = (spans[-1][0], b)
        else:
            spans.append((a, b))
    return spans


def seal(samples: Iterable[tuple[int, int, float | None]]) -> dict[int, float]:
    """{H: markPx} sealed at H + MARK_WINDOW from (sent, recv, markPx) samples in archive order: the earliest
    sample sent in [H, H + MARK_WINDOW) and received by then, ties in archive order; a missing or invalid mark
    in it leaves H missing (stage 10 revision of 2026-10-23)."""
    out: dict[int, float | None] = {}
    for sent, recv, px in sorted(samples, key=lambda s: s[0]):
        h = sent // HOUR * HOUR
        if h not in out and recv <= h + MARK_WINDOW:
            out[h] = px
    return {h: px for h, px in out.items() if px is not None and math.isfinite(px) and px > 0}


def mark_bars(samples: Iterable[tuple[int, int, float | None]], now: int) -> list[list[Any]]:
    """[[H, M(H), M(H + 1 h) or None]] for every reference sealed by `now` (M(H + 1 h) only once it is sealed too)."""
    m = {h: px for h, px in seal(samples).items() if h + MARK_WINDOW <= now}
    return [[h, px, m.get(h + HOUR)] for h, px in sorted(m.items())]


class Exchange(Info):
    """ingest.hl.Info restricted to ALLOWED request types, archiving each actual HTTP attempt."""

    prefix = "info"

    def __init__(self, archive_dir: str | Path, budget: int = BUDGET_PER_MIN - MARK_BUDGET) -> None:
        super().__init__(budget)
        self.archive = Path(archive_dir)
        self.archive.mkdir(parents=True, exist_ok=True)

    def post(self, body: dict[str, Any], weight: int = 20, per_items: int | None = None) -> Any:
        if body.get("type") not in ALLOWED:
            raise PermissionError(f"request type {body.get('type')!r} is not an approved public read")
        return super().post(body, weight, per_items)

    def _send(self, body: dict[str, Any]) -> Any:
        sample = {"sent": now_ms(), "request": body}
        try:
            response = super()._send(body)
        except Exception as e:
            sample.update(recv=None, failed=now_ms(), error=repr(e))
            self._archive(sample)
            raise
        sample.update(recv=now_ms(), status=response.status_code)
        try:
            sample["response"] = response.json()
        except ValueError:
            sample["response"] = response.text
        self._archive(sample)
        return response

    def _archive(self, sample: dict[str, Any]) -> None:
        if "response" in sample:
            text = json.dumps(sample["response"], separators=(",", ":"))
            sample["sha256"] = hashlib.sha256(text.encode()).hexdigest()
        append(self.archive, self.prefix, sample["sent"], sample)


def snapshot_marks(payload: Any) -> dict[str, float | None]:
    """Validate a complete dex snapshot; an invalid individual price stays missing, never substituted."""
    if not isinstance(payload, list) or len(payload) != 2:
        raise ValueError("expected [meta, contexts]")
    meta, ctxs = payload
    assets = meta.get("universe") if isinstance(meta, dict) else None
    if not isinstance(assets, list) or not isinstance(ctxs, list) or len(assets) != len(ctxs):
        raise ValueError("expected matching universe and contexts")
    marks = {}
    for a, c in zip(assets, ctxs):
        if not isinstance(a, dict) or not isinstance(a.get("name"), str) or not isinstance(c, dict):
            raise ValueError("expected named assets and context objects")
        try:
            marks[a["name"]] = float(c["markPx"])
        except (KeyError, TypeError, ValueError):
            marks[a["name"]] = None
    return marks


class Sampler(Exchange):
    """The hourly archive holds the raw attempt and its marks together, including failed or invalid samples."""

    prefix = "marks"

    def _decode(self, body: dict[str, Any], response: httpx.Response) -> Any:
        payload = super()._decode(body, response)
        if body["type"] == "metaAndAssetCtxs":
            snapshot_marks(payload)
        return payload

    def _archive(self, sample: dict[str, Any]) -> None:
        marks = {}
        valid = False
        if sample["request"]["type"] == "metaAndAssetCtxs" and sample.get("status") == 200:
            try:
                marks = snapshot_marks(sample["response"])
                valid = True
            except ValueError:
                pass
        super()._archive(sample | {"dex": sample["request"].get("dex"), "marks": marks, "valid": valid})


class Market:
    """Listings, completed 1h and 1d bars, and hourly funding, cached under `root`."""

    def __init__(self, root: str | Path, exchange: Any, repair_every: int = REPAIR_EVERY) -> None:
        self.root, self.x, self.repair_every = Path(root), exchange, repair_every
        (self.root / "marks").mkdir(parents=True, exist_ok=True)
        self.locks: dict[Path, threading.Lock] = {}
        self.repaired: dict[Path, int] = {}
        self.pending: dict[Path, dict[int, list[Any]]] = {}

    @functools.cached_property
    def sampler(self) -> Sampler:
        """Hourly requests own a rate budget and connection, independent of every history read."""
        return Sampler(self.root / "marks", MARK_BUDGET)

    def universe(self, dex: str | None = None) -> dict[str, bool]:
        """{market: delisted} of a builder dex, or of the core venue."""
        meta = self.x.post({"type": "meta", "dex": dex}) if dex else self.x.meta()
        return {a["name"]: bool(a.get("isDelisted")) for a in meta["universe"]}

    def listings(self) -> dict[str, bool]:
        """{market: delisted} over the core venue and every builder dex."""
        out = self.universe()
        for dex in self.x.post({"type": "perpDexs"}):
            if dex:
                out.update(self.universe(dex["name"]))
        return out

    def listed(self, markets: Iterable[str]) -> dict[str, bool]:
        """{market: delisted} now, of `markets` the venue lists, reading only their dexes: a dex it doesn't list lists none."""
        dexes = set(map(dex_of, markets))
        if dexes - {None}:
            dexes &= {None} | {d["name"] for d in self.x.post({"type": "perpDexs"}) if d}
        universes = {dex: self.universe(dex) for dex in dexes}
        return {m: universes[dex_of(m)][m] for m in markets if m in universes.get(dex_of(m), {})}

    def _cached(self, market: str, kind: str, fetch: Callable[[int, int], list[list[Any]]], now: int) -> list[list[Any]]:
        """The rows of `kind` shown by `now`: the cache's final ones and those read in this process not yet final."""
        path, step = self.root / market.replace(":", "_") / f"{kind}.json", STEP[kind]
        with self.locks.setdefault(path, threading.Lock()):
            rows = json.loads(path.read_text()) if path.exists() else []
            pending = self.pending.setdefault(path, {})
            expired = [t for t in pending if t + FINAL[kind] <= now]
            for t in expired:
                del pending[t]
            known = {r[0] for r in rows}
            last = self.repaired.get(path)
            repair = last is None or now_ms() - last >= self.repair_every
            if repair or not rows or expired:
                spans = holes(rows, step, now - HISTORY[kind], now)
            else:
                spans = [] if (now - SHOWN[kind]) // step * step in known | set(pending) else [(rows[-1][0] + 1, now)]
            fresh = {r[0]: r for a, b in spans if a < b for r in fetch(a, b) if r[0] not in known and r[0] + SHOWN[kind] <= now}
            if repair:
                self.repaired[path] = now_ms()
            final = [r for t, r in fresh.items() if t + FINAL[kind] <= now]
            pending.update((t, r) for t, r in fresh.items() if t + FINAL[kind] > now)
            if final:
                path.parent.mkdir(parents=True, exist_ok=True)
                rows = sorted(rows + final)
                tmp = path.with_suffix(".tmp")
                tmp.write_text(json.dumps(rows, separators=(",", ":")))
                os.replace(tmp, path)
            return sorted(r for r in rows + list(pending.values()) if r[0] + SHOWN[kind] <= now)

    def record_marks(self) -> None:
        """One sample per builder dex; archive failures as missing marks without abandoning later dexes."""
        for dex in self.sampler.post({"type": "perpDexs"}):
            if dex:
                try:
                    self.sampler.post({"type": "metaAndAssetCtxs", "dex": dex["name"]})
                except (httpx.HTTPError, ValueError) as e:
                    print(f"mark sample failed for {dex['name']}: {e!r}", file=sys.stderr)

    def marks(self, market: str) -> list[tuple[int, int, float | None]]:
        """(sent, recv, markPx or None) of successful dex snapshots, in archive order; attempts stay in the archive."""
        dex = dex_of(market)
        return [(s["sent"], s["recv"], s["marks"].get(market)) for s in read(self.root / "marks", "marks")
                if s["dex"] == dex and s["recv"] is not None and s.get("status", 200) == 200 and s.get("valid", True)]

    def lag(self, market: str) -> int:
        return MARK_WINDOW if builder(market) else DELTA

    def bars(self, market: str, interval: str, now: int | None = None) -> list[list[Any]]:
        """[[openTime, open, close]] of bars known by `now`. A builder market's 1h bars are its marks; a core 1h candle shows
        its open from δ with a null close until its own close is known, and is cached only once complete."""
        now = now or now_ms()
        if interval == "1h" and builder(market):
            return mark_bars(self.marks(market), now)
        step = STEP[interval]

        def fetch(start: int, end: int) -> list[list[Any]]:
            return [[c["t"], float(c["o"]), float(c["c"])] for c in self.x.candles(market, interval, start, end)]
        return [[t, o, c if t + step + DELTA <= now else None] for t, o, c in self._cached(market, interval, fetch, now)]

    def funding(self, market: str, now: int | None = None) -> list[list[Any]]:
        """[[hour, rate]] of settled funding up to `now`."""
        now = now or now_ms()

        def fetch(start: int, end: int) -> list[list[Any]]:
            return [[r["time"] // HOUR * HOUR, float(r["fundingRate"])] for r in self.x.funding(market, start, end + 1)]
        return self._cached(market, "funding", fetch, now)
