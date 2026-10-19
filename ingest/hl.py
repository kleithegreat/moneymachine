"""Read-only Hyperliquid info API client, held under half the documented rate limit."""

import threading
import time

import httpx

URL = "https://api.hyperliquid.xyz/info"
DOCUMENTED_WEIGHT_PER_MIN = 1200
BUDGET_PER_MIN = DOCUMENTED_WEIGHT_PER_MIN // 2

HOUR = 3_600_000
DAY = 24 * HOUR
INTERVAL_MS = {"1h": HOUR, "4h": 4 * HOUR, "1d": DAY}


class Info:
    def __init__(self, budget_per_min=BUDGET_PER_MIN):
        self.budget = budget_per_min
        self.spent = []
        self.lock = threading.Lock()
        self.http = httpx.Client(timeout=30)

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
        self._charge(weight)
        for attempt in range(6):
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

    def l2_book(self, coin):
        return self.post({"type": "l2Book", "coin": coin}, weight=2)

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
