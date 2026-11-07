"""Read-only Hyperliquid info API client, held under half the documented rate limit."""

import threading
import time
from typing import Any

import httpx

from ingest.policy import DAY, HOUR

URL = "https://api.hyperliquid.xyz/info"
DOCUMENTED_WEIGHT_PER_MIN = 1200
BUDGET_PER_MIN = DOCUMENTED_WEIGHT_PER_MIN // 2

INTERVAL_MS = {"1h": HOUR, "4h": 4 * HOUR, "1d": DAY}
TIMEOUT = 10  # s: one hung request plus the recorder's 5 s back-off stays under C0.3's 60 s gap limit


class WeightLimit:
    """One rolling-minute admission ledger, shared by every client using a quota."""

    def __init__(self, budget: int) -> None:
        if budget <= 0:
            raise ValueError("budget must be positive")
        self.budget = budget
        self.spent: list[tuple[float, int]] = []
        self.lock = threading.Lock()

    def delay(self, priority: bool) -> float:
        return 0

    def charge(self, weight: int, priority: bool = False) -> None:
        if not 0 <= weight <= self.budget:
            raise ValueError(f"weight {weight} exceeds per-minute budget {self.budget}")
        while True:
            with self.lock:
                now = time.monotonic()
                self.spent = [(t, w) for t, w in self.spent if now - t < 60]
                delay = self.delay(priority)
                if not delay and sum(w for _, w in self.spent) + weight <= self.budget:
                    self.spent.append((now, weight))
                    return
                wait = delay or max(0.001, self.spent[0][0] + 60 - now)
            time.sleep(wait)


class Info:
    def __init__(self, budget_per_min: int = BUDGET_PER_MIN, *, limiter: WeightLimit | None = None) -> None:
        self.limiter = limiter if limiter is not None else WeightLimit(budget_per_min)
        self.http = httpx.Client(timeout=TIMEOUT)

    def _charge(self, weight: int) -> None:
        self.limiter.charge(weight)

    def post(self, body: dict[str, Any], weight: int = 20, per_items: int | None = None, *, attempts: int = 6) -> Any:
        """One request, retried after a 429, a 5xx or a transport error (a timeout, a dropped connection) with
        backoff; every attempt is charged its weight."""
        for attempt in range(attempts):
            if attempt:
                time.sleep(2 ** (attempt - 1))
            self._charge(weight)
            try:
                r = self._send(body)
            except httpx.TransportError:
                if attempt == attempts - 1:
                    raise
                continue
            if (r.status_code == 429 or r.status_code >= 500) and attempt < attempts - 1:
                continue
            r.raise_for_status()
            try:
                out = self._decode(body, r)
            except ValueError:
                if attempt == attempts - 1:
                    raise
                continue
            if per_items and isinstance(out, list):
                self._charge(len(out) // per_items)
            return out

    def _send(self, body: dict[str, Any]) -> httpx.Response:
        """Send one already-charged attempt."""
        return self.http.post(URL, json=body)

    def _decode(self, body: dict[str, Any], response: httpx.Response) -> Any:
        return response.json()

    def meta(self) -> Any:
        return self.post({"type": "meta"})

    def l2_book(self, coin: str, sig_figs: int | None = None) -> Any:
        body: dict[str, Any] = {"type": "l2Book", "coin": coin}
        if sig_figs:
            body["nSigFigs"] = sig_figs
        return self.post(body, weight=2)

    def funding(self, coin: str, start: int, end: int | None = None) -> list[Any]:
        """All settled funding rows with start <= time < end, paginated by 500."""
        rows: list[Any] = []
        while True:
            body: dict[str, Any] = {"type": "fundingHistory", "coin": coin, "startTime": start}
            if end is not None:
                body["endTime"] = end - 1
            page = self.post(body, per_items=20)
            rows += page
            if len(page) < 500:
                return rows
            start = page[-1]["time"] + 1

    def candles(self, coin: str, interval: str, start: int, end: int) -> list[Any]:
        """All candles with start <= t < end, including any unclosed last one."""
        rows: list[Any] = []
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
