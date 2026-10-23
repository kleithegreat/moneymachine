"""The thesis track's runner (PROGRESS.md, Stage 10): for one frozen track version (named by the
manifest hash), the daily main session at 00:10 UTC with an ablation per accepted thesis and then the
full no-reading session; the Monday benchmark; hourly resolutions; and the report.

The state is the ledger: a session is started once per UTC date, recorded when it starts, so a crash
consumes the date; a resolution or a missing-data status is recorded once per thesis.
"""

import json
import threading
import time
from pathlib import Path

from gate.agent.campaigns import RETRY, available
from ingest.execution import fill_missing
from ingest.live import now_ms
from ingest.policy import DAY, HOUR
from thesis import harness, positions, registry, scoring
from thesis.daemon import Daemon
from thesis.market import MARK_OFFSET, Exchange, Market
from thesis.retrieval import Fetcher

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "data" / "thesis"
FROZEN = REPO / "audit" / "stage10" / "manifest.json"
SESSION_OFFSET = 10 * 60_000
ACCOUNTS = ("main", "noread", "benchmark")
BENCHMARK = ("BTC", "ETH", "xyz:XYZ100", "xyz:GOLD", "flx:OIL")
INITIAL = 10_000.0
RESOLUTION_GRACE = 2 * HOUR
MAIN_COMMANDS = ("markets", "prices", "fetch", "register", "positions", "exit")
NOREAD_COMMANDS = ("markets", "prices", "register", "positions", "exit")


class Track:
    def __init__(self, root=ROOT):
        self.root = Path(root)
        self.version = f"thesis-{harness.manifest_hash()[:12]}"
        self.ledger = registry.Ledger(self.root / "ledger.sqlite", self.version)
        self.market = Market(self.root / "market", Exchange(self.root / "exchange"))
        self.fetcher = Fetcher()

    def config(self, markets):
        """Fee from the venue rules; each market's C0.7 cost cells, or the maximum over U (an unvalidated fallback)."""
        rules = json.loads((REPO / "venue/hyperliquid/rules.json").read_text())
        cells = json.loads((REPO / "venue/hyperliquid/execution.json").read_text())["cost_bps_ex_fee"]
        costs, fallback = fill_missing(cells, sorted(markets))
        return {"initial": INITIAL, "fee": rules["rules"]["taker_fee"]["value"], "costs": costs, "fallback": fallback}

    def data(self, markets, now):
        return {"bars": {m: scoring.bars(self.market.bars(m, "1h", now)) for m in markets},
                "funding": {m: dict(self.market.funding(m, now)) for m in markets},
                "lag": {m: self.market.lag(m) for m in markets}}

    def markets_of(self, account):
        return sorted({m for th in self.ledger.theses(account) for m, _ in th["legs"]})

    def replay(self, account, now, extra=()):
        markets = sorted(set(self.markets_of(account)) | set(extra))
        return positions.run(self.config(markets), self.ledger.theses(account), self.ledger.exits(account), self.data(markets, now), now)

    def snapshot(self, now):
        listings = self.market.listings()
        markets, daily = {}, {}
        for m, delisted in sorted(listings.items()):
            if delisted:
                continue
            d = [r for r in self.market.bars(m, "1d", now) if r[0] + DAY <= now]
            if len(d) < registry.MIN_DAILY_BARS:
                continue
            h = [r for r in self.market.bars(m, "1h", now) if r[2] is not None]
            if h:
                markets[m] = {"last_close": h[-1][2], "t": h[-1][0] + HOUR}
                daily[m] = d
        snap = {"taken": now, "listings": listings, "markets": markets, "daily": daily}
        path = self.root / "snapshots" / f"{now}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(snap))
        return snap

    def daemon(self, socket_path, session, account, snapshot, commands, ablation_of=None):
        inputs = lambda acct, markets, t_r: (self.config(set(self.markets_of(acct)) | set(markets)),
                                             self.data(set(self.markets_of(acct)) | set(markets), t_r))
        replay = lambda acct, now: {"theses": self.replay(acct, now)["theses"]}
        return Daemon(socket_path, session, account, self.ledger, snapshot, self.fetcher, self.root / "responses", replay,
                      inputs, commands, ablation_of=ablation_of).serve()

    def session(self, kind, account, date, snapshot, commands, task=None, ablation_of=None):
        name = f"{kind}-{date}" if ablation_of is None else f"ablation-{ablation_of}"
        self.ledger.disclose("session", account, {"session": name, "kind": kind, "started": now_ms(),
                                                  "manifest": harness.manifest_hash()})
        run = harness.run_session(self.root / "sessions" / name, kind,
                                  lambda sock: self.daemon(sock, name, account, snapshot, commands, ablation_of), task)
        calls = [c for _, _, c in self.ledger.records("call", account) if c["session"] == name]
        run["audit"] = harness.audit(self.root / "sessions" / name / "transcript.jsonl", calls)
        self.ledger.disclose("session_end", account, {"session": name, **run})
        return name

    def started(self, kind, date):
        return any(c["session"] == f"{kind}-{date}" for _, _, c in self.ledger.records("session"))

    def ablation_task(self, th, snapshot):
        cutoff = {m: [r for r in snapshot["daily"].get(m, []) if r[0] + DAY <= th["t_r"]] for m, _ in th["legs"]}
        task = {"exposure": [{"market": m, "direction": "long" if w == 1 else "short"} for m, w in th["legs"]],
                "forecast_time_ms": th["t_r"], "entry": "the first hourly open at or after the forecast time plus 120 s",
                "horizon_ms": th["T"], "exit": "the first hourly open at or after the horizon",
                "outcome": "the fixed-quantity position's net return (price change, fees, trading costs and hourly "
                           "funding payments) from entry to exit is strictly positive"}
        snap = {"taken": th["t_r"], "listings": snapshot["listings"], "daily": cutoff,
                "markets": {m: {"last_close": d[-1][2], "t": d[-1][0] + DAY} for m, d in cutoff.items() if d}}
        return task, snap

    def day(self, date):
        """The main session, an ablation per accepted main thesis, then the full no-reading session."""
        while not available():
            if now_ms() >= date + DAY:
                self.ledger.disclose("session_missed", "main", {"date": date, "reason": "the model was unavailable all day"})
                return
            time.sleep(RETRY)
        snapshot = self.snapshot(now_ms())
        name = self.session("main", "main", date, snapshot, MAIN_COMMANDS)
        for th in [t for t in self.ledger.theses("main") if t["session"] == name]:
            task, snap = self.ablation_task(th, snapshot)
            self.session("ablation", "ablation", date, snap, ("prices", "forecast"), task, ablation_of=th["id"])
        self.session("noread", "noread", date, snapshot, NOREAD_COMMANDS)

    def benchmark(self, monday):
        """The frozen benchmark's registrations for one Monday 00:00 UTC, in BENCHMARK order."""
        snapshot = self.snapshot(monday)
        for m in BENCHMARK:
            closes = {r[0]: r[2] for r in snapshot["daily"].get(m, [])}
            last, before = monday - DAY, monday - 21 * DAY
            if m not in snapshot["markets"] or last not in closes or before not in closes:
                self.ledger.disclose("skip", "benchmark", {"date": monday, "market": m, "reason": "missing daily close"})
                continue
            w = 1 if closes[last] > closes[before] else -1
            equity = self.replay("benchmark", monday)["equity"]
            n = 0.01 * (equity[-1][1] if equity else INITIAL) / 0.1
            probe = {"legs": [[m, w]], "t_r": now_ms(), "T": monday + 21 * DAY, "N": n}
            daily = {m: scoring.bars(snapshot["daily"][m])}
            funding = {m: dict(self.market.funding(m, monday))}
            p_ref, _, _ = scoring.base_rate(probe, self.config([m]), daily, funding)
            if p_ref is None:
                self.ledger.disclose("skip", "benchmark", {"date": monday, "market": m, "reason": "no base rate"})
                continue
            request = {"request_id": f"benchmark-{monday}-{m}", "legs": [[m, w]], "T": monday + 21 * DAY, "p": p_ref,
                       "L": 0.1, "catalyst": "frozen benchmark: the sign of the 20-day return", "catalyst_id": "benchmark",
                       "sources": []}
            t_r = now_ms()
            config_markets = set(self.markets_of("benchmark")) | {m}
            _, errors = registry.register(self.ledger, "benchmark", f"benchmark-{monday}", request, t_r, snapshot["listings"],
                                          lambda x: [r[0] for r in snapshot["daily"].get(x, [])], set(),
                                          self.config(config_markets), self.data(config_markets, t_r))
            if errors:
                self.ledger.disclose("skip", "benchmark", {"date": monday, "market": m, "reason": "; ".join(errors)})

    def resolve(self, now):
        """Record each due thesis's outcome once, or its missing-data status once."""
        done = {(c["id"], c["status"]) for _, _, c in self.ledger.records("resolution")}
        for account in ACCOUNTS:
            theses = [th for th in self.ledger.theses(account) if th["T"] <= now]
            if not theses:
                continue
            markets = self.markets_of(account)
            config, data = self.config(markets), self.data(markets, now)
            managed = positions.run(config, self.ledger.theses(account), self.ledger.exits(account), data, now)["theses"]
            for th in theses:
                if (th["id"], "resolved") in done:
                    continue
                out = positions.outcome(th, th["N"], config, data, now)
                if out is not None:
                    self.ledger.disclose("resolution", account, {"id": th["id"], "status": "resolved", "outcome": out,
                                                                 "managed_return": managed[th["id"]]["managed_return"],
                                                                 "at": now, "fallback_costs": sorted(set(config["fallback"]) & {m for m, _ in th["legs"]})})
                elif now >= th["T"] + RESOLUTION_GRACE and (th["id"], "missing data") not in done:
                    self.ledger.disclose("resolution", account, {"id": th["id"], "status": "missing data", "at": now})

    def benchmarked(self, monday):
        return any(c["date"] == monday for _, _, c in self.ledger.records("skip", "benchmark")) or \
            any(th["session"] == f"benchmark-{monday}" for th in self.ledger.theses("benchmark"))

    def marker(self):
        """Builder markets' mark samples at H + MARK_OFFSET every hour (stage 10 revision of 2026-10-23)."""
        while True:
            now = now_ms()
            time.sleep((now // HOUR * HOUR + HOUR + MARK_OFFSET - now) / 1000)
            try:
                self.market.record_marks()
            except Exception as e:
                print(time.strftime("%FT%T"), "marks", repr(e), flush=True)

    def resolver(self):
        while True:
            self.resolve(now_ms())
            time.sleep(300)

    def run(self):
        """Forever: resolutions on their own thread; the Monday benchmark and the daily sessions here."""
        frozen = json.loads(FROZEN.read_text()) if FROZEN.exists() else {}
        if frozen.get("manifest") != harness.manifest_hash():
            raise SystemExit(f"the manifest differs from {FROZEN}: freeze it (a new track version) before running")
        threading.Thread(target=self.resolver, daemon=True).start()
        threading.Thread(target=self.marker, daemon=True).start()
        while True:
            now = now_ms()
            date = now // DAY * DAY
            monday = date - ((date // DAY + 3) % 7) * DAY
            if monday > frozen["frozen"] - DAY and not self.benchmarked(monday):
                if now - monday < DAY:
                    self.benchmark(monday)
                else:
                    self.ledger.disclose("skip", "benchmark", {"date": monday, "market": None, "reason": "run missed"})
            if now >= date + SESSION_OFFSET and not self.started("main", date) and not self.missed(date):
                self.day(date)
            time.sleep(60)

    def missed(self, date):
        return any(c["date"] == date for _, _, c in self.ledger.records("session_missed"))


def freeze():
    """Record the manifest: the start of a track version and of C10.5's observation window."""
    FROZEN.parent.mkdir(parents=True, exist_ok=True)
    old = json.loads(FROZEN.read_text()) if FROZEN.exists() else None
    if old and old["manifest"] == harness.manifest_hash():
        raise SystemExit("this manifest is already frozen")
    FROZEN.write_text(json.dumps({"manifest": harness.manifest_hash(), "version": f"thesis-{harness.manifest_hash()[:12]}",
                                  "frozen": now_ms(), "previous": old}, indent=1) + "\n")


def run():
    Track().run()


def report(out):
    from thesis import report as r

    r.write(Track(), now_ms(), out)
