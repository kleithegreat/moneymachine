"""Market data for the thesis track through a fixed-host adapter (PROGRESS.md, Stage 10).

The adapter is the venue's public info endpoint with only the frozen read request types; there is no
signing, account or order operation anywhere. Every response is archived with its retrieval time.
Completed bars and funding rows are cached per market and extended incrementally.
"""

import hashlib
import json
import time
from pathlib import Path

from ingest.hl import Info
from ingest.live import now_ms
from ingest.policy import DAY, HOUR

ALLOWED = frozenset({"meta", "perpDexs", "candleSnapshot", "fundingHistory"})
BUDGET_PER_MIN = 120
HISTORY = {"1h": 200 * DAY, "1d": 3 * 365 * DAY + 30 * DAY, "funding": 3 * 365 * DAY + 30 * DAY}


class Exchange(Info):
    """ingest.hl.Info restricted to ALLOWED request types, archiving each response."""

    def __init__(self, archive_dir, budget=BUDGET_PER_MIN):
        super().__init__(budget)
        self.archive = Path(archive_dir)
        self.archive.mkdir(parents=True, exist_ok=True)

    def post(self, body, weight=20, per_items=None):
        if body.get("type") not in ALLOWED:
            raise PermissionError(f"request type {body.get('type')!r} is not an approved public read")
        out = super().post(body, weight, per_items)
        text = json.dumps(out, separators=(",", ":"))
        with open(self.archive / f"info-{time.strftime('%Y%m%d', time.gmtime())}.jsonl", "a") as fh:
            fh.write(json.dumps({"t": now_ms(), "request": body, "sha256": hashlib.sha256(text.encode()).hexdigest(),
                                 "response": out}, separators=(",", ":")) + "\n")
        return out


class Market:
    """Listings, completed 1h and 1d bars, and hourly funding, cached under `root`."""

    def __init__(self, root, exchange):
        self.root, self.x = Path(root), exchange
        self.root.mkdir(parents=True, exist_ok=True)

    def listings(self):
        """{market: delisted} over the core venue and every builder dex."""
        out = {a["name"]: bool(a.get("isDelisted")) for a in self.x.meta()["universe"]}
        for dex in self.x.post({"type": "perpDexs"}):
            if dex:
                out.update({a["name"]: bool(a.get("isDelisted")) for a in self.x.post({"type": "meta", "dex": dex["name"]})["universe"]})
        return out

    def _cached(self, market, kind, fetch, now):
        path = self.root / market.replace(":", "_") / f"{kind}.json"
        rows = json.loads(path.read_text()) if path.exists() else []
        start = rows[-1][0] + 1 if rows else now - HISTORY[kind]
        fresh = [r for r in fetch(start, now) if not rows or r[0] > rows[-1][0]]
        if fresh:
            path.parent.mkdir(parents=True, exist_ok=True)
            rows += fresh
            path.write_text(json.dumps(rows, separators=(",", ":")))
        return rows

    def bars(self, market, interval, now=None):
        """[[openTime, open, close]] of completed bars up to `now`."""
        now = now or now_ms()
        step = {"1h": HOUR, "1d": DAY}[interval]

        def fetch(start, end):
            return [[c["t"], float(c["o"]), float(c["c"])] for c in self.x.candles(market, interval, start, end)
                    if c["t"] + step <= end]
        return [r for r in self._cached(market, interval, fetch, now) if r[0] + step <= now]

    def funding(self, market, now=None):
        """[[hour, rate]] of settled funding up to `now`."""
        now = now or now_ms()

        def fetch(start, end):
            return [[r["time"] // HOUR * HOUR, float(r["fundingRate"])] for r in self.x.funding(market, start, end)]
        return [r for r in self._cached(market, "funding", fetch, now) if r[0] <= now]
