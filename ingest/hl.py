"""Read-only Hyperliquid info API client, held under half the documented rate limit."""

import threading
import time

import httpx

from ingest.policy import DAY, HOUR

URL = "https://api.hyperliquid.xyz/info"
DOCUMENTED_WEIGHT_PER_MIN = 1200
BUDGET_PER_MIN = DOCUMENTED_WEIGHT_PER_MIN // 2

INTERVAL_MS = {"1h": HOUR, "4h": 4 * HOUR, "1d": DAY}
TIMEOUT = 10  # s: one hung request plus the recorder's 5 s back-off stays under C0.3's 60 s gap limit


class Info:
    def __init__(self, budget_per_min=BUDGET_PER_MIN):
        self.budget = budget_per_min
        self.spent = []
        self.lock = threading.Lock()
        self.http = httpx.Client(timeout=TIMEOUT)

    def _charge(self, weight):
        with self.lock:
            while True:
                now = time.monotonic()
                self.spent = [(t, w) for t, w in self.spent if now - t < 60]
                if sum(w for _, w in self.spent) + weight <= self.budget:
                    self.spent.append((now, weight))
                    return
                time.sleep(0.25)

    def post(self, body, weight=20, per_items=None):
        """One request, retried after a 429 or 5xx with backoff; every attempt is charged its weight."""
        for attempt in range(6):
            self._charge(weight)
            r = self.http.post(URL, json=body)
            if r.status_code == 429 or r.status_code >= 500:
                time.sleep(2**attempt)
                continue
            r.raise_for_status()
            out = r.json()
            if per_items and isinstance(out, list):
                self._charge(len(out) // per_items)
            return out
        r.raise_for_status()

    def meta(self):
        return self.post({"type": "meta"})

    def l2_book(self, coin, sig_figs=None):
        body = {"type": "l2Book", "coin": coin}
        if sig_figs:
            body["nSigFigs"] = sig_figs
        return self.post(body, weight=2)

    def funding(self, coin, start, end=None):
        """All settled funding rows with start <= time < end, paginated by 500."""
        rows = []
        while True:
            body = {"type": "fundingHistory", "coin": coin, "startTime": start}
            if end is not None:
                body["endTime"] = end - 1
            page = self.post(body, per_items=20)
            rows += page
            if len(page) < 500:
                return rows
            start = page[-1]["time"] + 1

    def candles(self, coin, interval, start, end):
        """All candles with start <= t < end, including any unclosed last one."""
        rows = []
        while start < end:
            body = {"type": "candleSnapshot",
                    "req": {"coin": coin, "interval": interval, "startTime": start, "endTime": end - 1}}
            page = self.post(body, per_items=60)
            page = [c for c in page if start <= c["t"] < end]
            if not page:
                return rows
            rows += page
            start = page[-1]["t"] + INTERVAL_MS[interval]
        return rows
