"""Live recorder for the availability check (C0.3) and execution calibration (C0.7).

Appends raw polls as JSONL. From each hour boundary H, every coin's funding is polled
every 30 s until the row settled at H appears; at 4h boundaries the same is done for the
bar closing at H. Each is polled once more at H + 10 min as the reference final value.
L2 books are polled every 30 s per coin, at full precision and aggregated to 4 significant figures
(deeper, with conservative bucket prices), logging the server time for clock offset. L2 runs on its
own thread and rate budget, so boundary polls never delay it.
"""

import json
import sys
import threading
import time
from pathlib import Path

from ingest.hl import HOUR, Info

POLL = 30_000
VERIFY_AFTER = 600_000
BAR = 4 * HOUR
L2_BUDGET = 120


def now_ms():
    return int(time.time() * 1000)


class Recorder:
    def __init__(self, budget, coins, out_dir):
        self.info, self.l2_info = Info(budget - L2_BUDGET), Info(L2_BUDGET)
        self.coins, self.out = coins, Path(out_dir)
        self.write = threading.Lock()
        self.out.mkdir(parents=True, exist_ok=True)
        self.hour = now_ms() // HOUR * HOUR
        self.pending = {}
        self.verify = [(self.hour + VERIFY_AFTER, self.kinds(self.hour))] if now_ms() < self.hour + VERIFY_AFTER else []
        self.last_l2 = {c: 0 for c in coins}

    def log(self, rec):
        day = time.strftime("%Y%m%d", time.gmtime(rec["sent"] / 1000))
        with self.write, open(self.out / f"polls-{day}.jsonl", "a") as f:
            f.write(json.dumps(rec) + "\n")

    def poll(self, kind, coin, boundary, purpose):
        sent = now_ms()
        if kind == "funding":
            data = self.info.post({"type": "fundingHistory", "coin": coin, "startTime": boundary - 1}, per_items=20)
            found = any(r["time"] // HOUR * HOUR == boundary for r in data)
        else:
            data = self.info.candles(coin, "4h", boundary - BAR, boundary + BAR)
            found = any(c["t"] == boundary - BAR for c in data) and any(c["t"] == boundary for c in data)
        self.log({"kind": kind, "coin": coin, "boundary": boundary, "purpose": purpose,
                  "sent": sent, "recv": now_ms(), "found": found, "data": data})
        return found

    def poll_l2(self, coin):
        sent = now_ms()
        book = self.l2_info.l2_book(coin)
        agg = self.l2_info.l2_book(coin, sig_figs=4)
        self.log({"kind": "l2", "coin": coin, "sent": sent, "recv": now_ms(), "data": book, "agg": agg})

    @staticmethod
    def kinds(h):
        return ["funding"] + (["bar"] if h % BAR == 0 else [])

    def step(self):
        t = now_ms()
        h = t // HOUR * HOUR
        if h > self.hour:
            self.hour = h
            kinds = self.kinds(h)
            for kind in kinds:
                for c in self.coins:
                    self.pending[(kind, c)] = (h, 0)
                self.verify.append((h + VERIFY_AFTER, kinds))
        for (kind, c), (b, last) in list(self.pending.items()):
            if now_ms() - last >= POLL:
                if self.poll(kind, c, b, "first"):
                    del self.pending[(kind, c)]
                else:
                    self.pending[(kind, c)] = (b, now_ms())
        while self.verify and self.verify[0][0] <= now_ms():
            at, kinds = self.verify.pop(0)
            for kind in kinds:
                for c in self.coins:
                    self.poll(kind, c, at - VERIFY_AFTER, "verify")

    def step_l2(self):
        for c in self.coins:
            if now_ms() - self.last_l2[c] >= POLL:
                self.last_l2[c] = now_ms()
                self.poll_l2(c)


def forever(step):
    while True:
        try:
            step()
        except Exception as e:
            print(time.strftime("%FT%T"), "error", repr(e), file=sys.stderr, flush=True)
            time.sleep(5)
        time.sleep(0.5)


def main(universe_path, out_dir, budget):
    coins = json.loads(Path(universe_path).read_text())["universe"]
    rec = Recorder(int(budget), coins, out_dir)
    threading.Thread(target=forever, args=(rec.step_l2,), daemon=True).start()
    forever(rec.step)


if __name__ == "__main__":
    main(*sys.argv[1:])
