"""Read-only Hyperliquid info API client with weighted admission at its configured allocation."""

import contextlib
import threading
import time
from collections.abc import Callable, Iterator
from typing import Any

import httpx

from ingest.policy import DAY, HOUR

URL = "https://api.hyperliquid.xyz/info"
DOCUMENTED_WEIGHT_PER_MIN = 1200
BUDGET_PER_MIN = DOCUMENTED_WEIGHT_PER_MIN // 2
RECORDER_WEIGHT_PER_MIN = 480

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
        self.foreground: list[object] = []
        self.holds = 0
        self.local = threading.local()

    def delay(self, priority: bool) -> float:
        return 0

    @contextlib.contextmanager
    def hold(self, cancel: Callable[[], bool] | None = None) -> Iterator[None]:
        """Hold background work, optionally cancelling this thread's admissions while held."""
        previous = getattr(self.local, "cancel", None)
        self.local.cancel = (lambda: bool(cancel() or previous and previous())) if cancel else previous
        with self.lock:
            self.holds += 1
        try:
            yield
        finally:
            self.local.cancel = previous
            with self.lock:
                self.holds -= 1

    def charge(self, weight: int, priority: bool = False, background: bool = False) -> None:
        """Admit foreground callers FIFO, priority sampling ahead of them, and background only outside holds and the queue."""
        if not 0 <= weight <= self.budget:
            raise ValueError(f"weight {weight} exceeds per-minute budget {self.budget}")
        ticket = object() if not background and not priority else None
        if ticket is not None:
            with self.lock:
                self.foreground.append(ticket)
        try:
            while True:
                cancel = getattr(self.local, "cancel", None)
                if cancel and cancel():
                    raise TimeoutError("admission cancelled")
                with self.lock:
                    now = time.monotonic()
                    self.spent = [(t, w) for t, w in self.spent if now - t < 60]
                    queued = ticket is not None and self.foreground[0] is not ticket
                    delay = self.delay(priority) or (0.25 if queued or background and (self.foreground or self.holds) else 0)
                    if not delay and sum(w for _, w in self.spent) + weight <= self.budget:
                        self.spent.append((now, weight))
                        return
                    wait = delay or max(0.001, self.spent[0][0] + 60 - now)
                    if cancel:
                        wait = min(wait, 0.25)
                time.sleep(wait)
        finally:
            if ticket is not None:
                with self.lock:
                    self.foreground.remove(ticket)


class Info:
    def __init__(self, budget_per_min: int = BUDGET_PER_MIN, *, limiter: WeightLimit | None = None) -> None:
        self.limiter = limiter if limiter is not None else WeightLimit(budget_per_min)
        self.http = httpx.Client(timeout=TIMEOUT)

    def _charge(self, weight: int, background: bool = False) -> None:
        self.limiter.charge(weight, background=background)

    def post(self, body: dict[str, Any], weight: int = 20, per_items: int | None = None, *, attempts: int = 6,
             background: bool = False) -> Any:
        """One request, retried after a 429, a 5xx or a transport error (a timeout, a dropped connection) with
        backoff; every attempt is charged its weight."""
        for attempt in range(attempts):
            if attempt:
                time.sleep(2 ** (attempt - 1))
            self._charge(weight, background)
            try:
                r = self._send(body)
            except httpx.TransportError:
                if attempt == attempts - 1:
                    raise
                continue
            if (r.status_code == 429 or r.status_code >= 500) and attempt < attempts - 1:
                continue
            r.raise_for_status()
            out = self._decode(body, r)
            if per_items and isinstance(out, list):
                self._charge(len(out) // per_items, background)
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

    def funding_page(self, coin: str, start: int, end: int | None = None, *, background: bool = False) -> list[Any]:
        """One page (at most 500) of the settled funding rows with start <= time < end."""
        body: dict[str, Any] = {"type": "fundingHistory", "coin": coin, "startTime": start}
        if end is not None:
            body["endTime"] = end - 1
        page: list[Any] = self.post(body, per_items=20, background=background)
        return page

    def funding(self, coin: str, start: int, end: int | None = None) -> list[Any]:
        """All settled funding rows with start <= time < end, paginated by 500."""
        rows: list[Any] = []
        while True:
            page = self.funding_page(coin, start, end)
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
