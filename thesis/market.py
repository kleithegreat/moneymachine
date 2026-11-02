"""Market data for the thesis track through a fixed-host adapter (audit/criteria.md, stage 10).

The adapter is the venue's public info endpoint with only the frozen read request types; there is no
signing, account or order operation anywhere. Every response is archived with its retrieval time.
Completed bars and funding rows are cached per market, each file rewritten atomically under a lock: extended
incrementally, every hole the venue left retried each `repair_every` for as long as it stays one, and a cached row is
never rewritten. A candle's open is known at its open plus δ and its close at its close plus δ (C0.3's rule), whenever it
was first read, so a read as of a cutoff does not depend on what the cache holds. A builder (HIP-3) market's
hourly bars are its recorded mark prices (stage 10 revision of 2026-10-23): `record_marks` samples every builder
dex's `metaAndAssetCtxs` once an hour, and `mark_bars` builds the bars from those samples as known at `now`.
"""

import hashlib
import json
import math
import os
import threading
from collections.abc import Callable, Iterable
from pathlib import Path
from typing import Any

from ingest.hl import Info
from ingest.live import append, now_ms, read
from ingest.policy import DAY, DELTA, HOUR

ALLOWED = frozenset({"meta", "perpDexs", "candleSnapshot", "fundingHistory", "metaAndAssetCtxs"})
BUDGET_PER_MIN = 120
HISTORY = {"1h": 200 * DAY, "1d": 3 * 365 * DAY + 30 * DAY, "funding": 3 * 365 * DAY + 30 * DAY}
MARK_OFFSET = 5_000
MARK_WINDOW = 5 * 60_000
STEP = {"1h": HOUR, "1d": DAY, "funding": HOUR}
REPAIR_EVERY = HOUR  # leaves C10.5's two hours from a late row's availability to its score
PAGE = 500  # holes closer than a page of rows share a request
EDGES = {"1h", "funding"}  # a market's daily history starts where the venue's does; no result needs a day before it


def builder(market: str) -> bool:
    return ":" in market


def dex_of(market: str) -> str | None:
    return market.split(":")[0] if builder(market) else None


def holes(rows: list[list[Any]], step: int, start: int | None) -> list[tuple[int, int]]:
    """[(from, to)) of the rows missing between `rows`, and before the first from `start` if given."""
    times: list[int] = [r[0] for r in rows]
    gaps = [(a + step, b) for a, b in zip(times, times[1:]) if b - a > step]
    if start is not None and times[0] - step >= start:
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
    """ingest.hl.Info restricted to ALLOWED request types, archiving each response."""

    def __init__(self, archive_dir: str | Path, budget: int = BUDGET_PER_MIN) -> None:
        super().__init__(budget)
        self.archive = Path(archive_dir)
        self.archive.mkdir(parents=True, exist_ok=True)

    def post(self, body: dict[str, Any], weight: int = 20, per_items: int | None = None) -> Any:
        if body.get("type") not in ALLOWED:
            raise PermissionError(f"request type {body.get('type')!r} is not an approved public read")
        out = super().post(body, weight, per_items)
        text = json.dumps(out, separators=(",", ":"))
        t = now_ms()
        append(self.archive, "info", t, {"t": t, "request": body, "sha256": hashlib.sha256(text.encode()).hexdigest(), "response": out})
        return out


class Market:
    """Listings, completed 1h and 1d bars, and hourly funding, cached under `root`."""

    def __init__(self, root: str | Path, exchange: Any, repair_every: int = REPAIR_EVERY) -> None:
        self.root, self.x, self.repair_every = Path(root), exchange, repair_every
        (self.root / "marks").mkdir(parents=True, exist_ok=True)
        self.lock = threading.Lock()
        self.repaired: dict[Path, int] = {}

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
        """{market: delisted} now, of `markets` the venue lists, reading only their dexes."""
        universes = {dex: self.universe(dex) for dex in set(map(dex_of, markets))}
        return {m: universes[dex_of(m)][m] for m in markets if m in universes[dex_of(m)]}

    def _cached(self, market: str, kind: str, fetch: Callable[[int, int], list[list[Any]]], now: int) -> list[list[Any]]:
        path = self.root / market.replace(":", "_") / f"{kind}.json"
        with self.lock:
            rows = json.loads(path.read_text()) if path.exists() else []
            first = now - HISTORY[kind]
            last = self.repaired.get(path)
            repair = last is None or now_ms() - last >= self.repair_every
            spans = holes(rows, STEP[kind], first if kind in EDGES else None) if rows and repair else []
            spans.append((rows[-1][0] + 1, now) if rows else (first, now))
            known = {r[0] for r in rows}
            fresh = {r[0]: r for a, b in spans if a < b for r in fetch(a, b) if r[0] not in known}
            if repair:
                self.repaired[path] = now_ms()
            if fresh:
                path.parent.mkdir(parents=True, exist_ok=True)
                rows = sorted(rows + list(fresh.values()))
                tmp = path.with_suffix(".tmp")
                tmp.write_text(json.dumps(rows, separators=(",", ":")))
                os.replace(tmp, path)
            return rows

    def record_marks(self) -> None:
        """One sample of every builder dex's mark prices, archived with its send and receive times."""
        for dex in self.x.post({"type": "perpDexs"}):
            if dex:
                sent = now_ms()
                meta, ctxs = self.x.post({"type": "metaAndAssetCtxs", "dex": dex["name"]})
                marks = {a["name"]: float(c["markPx"]) if c.get("markPx") is not None else None for a, c in zip(meta["universe"], ctxs)}
                append(self.root / "marks", "marks", sent, {"sent": sent, "recv": now_ms(), "dex": dex["name"], "marks": marks})

    def marks(self, market: str) -> list[tuple[int, int, float | None]]:
        """(sent, recv, markPx or None) of every sample of the market's dex, in archive order."""
        dex = dex_of(market)
        return [(s["sent"], s["recv"], s["marks"].get(market)) for s in read(self.root / "marks", "marks") if s["dex"] == dex]

    def lag(self, market: str) -> int:
        return MARK_WINDOW if builder(market) else DELTA

    def bars(self, market: str, interval: str, now: int | None = None) -> list[list[Any]]:
        """[[openTime, open, close]] of bars known by `now`. A builder market's 1h bars are its marks; a core 1h candle shows
        its open from δ with a null close until its own close is known, and is cached only once complete."""
        now = now or now_ms()
        if interval == "1h" and builder(market):
            return mark_bars(self.marks(market), now)
        step = STEP[interval]
        shown = DELTA if interval == "1h" else step + DELTA
        progress: list[list[Any]] = []

        def fetch(start: int, end: int) -> list[list[Any]]:
            candles = [[c["t"], float(c["o"]), float(c["c"])] for c in self.x.candles(market, interval, start, end)]
            progress.extend(r for r in candles if r[0] + step + DELTA > now)
            return [r for r in candles if r[0] + step + DELTA <= now]
        cached = self._cached(market, interval, fetch, now)
        rows = {r[0]: r for r in progress + cached}
        return [[t, o, c if t + step + DELTA <= now else None] for t, (_, o, c) in sorted(rows.items()) if t + shown <= now]

    def funding(self, market: str, now: int | None = None) -> list[list[Any]]:
        """[[hour, rate]] of settled funding up to `now`."""
        now = now or now_ms()

        def fetch(start: int, end: int) -> list[list[Any]]:
            return [[r["time"] // HOUR * HOUR, float(r["fundingRate"])] for r in self.x.funding(market, start, end + 1)]
        return [r for r in self._cached(market, "funding", fetch, now) if r[0] <= now]
