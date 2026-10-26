"""The thesis track's runner (audit/criteria.md, stage 10): for one frozen track version (named by the
manifest hash), the daily main session at 00:10 UTC with an ablation per accepted thesis and then the
full no-reading session; the Monday benchmark; hourly resolutions; and the report.

The state is the ledger: a session is started once per UTC date, recorded when it starts, so a crash
consumes the date; a resolution or a missing-data status is recorded once per thesis.
"""

import fcntl
import functools
import json
import shutil
import threading
import time
from pathlib import Path

from gate import kernel
from ingest.fallback import fill_missing
from ingest.live import now_ms
from ingest.policy import DAY, HOUR
from sandbox import session
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
        kernel = pinned_kernel(self.root)
        self.manifest = harness.manifest_hash(kernel)
        self.version = f"thesis-{self.manifest[:12]}"
        self.ledger = registry.Ledger(self.root / "ledger.sqlite", self.version, kernel)
        self.market = Market(self.root / "market", Exchange(self.root / "exchange"))
        self.fetcher = Fetcher()

    @functools.cached_property
    def venue(self):
        """The taker fee and the C0.7 cost cells, read once."""
        rules = json.loads((REPO / "venue/hyperliquid/rules.json").read_text())
        cells = json.loads((REPO / "venue/hyperliquid/execution.json").read_text())["cost_bps_ex_fee"]
        return rules["rules"]["taker_fee"]["value"], cells

    def config(self, markets):
        """The fee, and each market's cost cells or the maximum over U (an unvalidated fallback)."""
        fee, cells = self.venue
        costs, fallback = fill_missing(cells, sorted(markets))
        return {"initial": INITIAL, "fee": fee, "costs": costs, "fallback": fallback}

    def data(self, markets, now):
        return {"bars": {m: scoring.bars(self.market.bars(m, "1h", now)) for m in markets},
                "funding": {m: dict(self.market.funding(m, now)) for m in markets},
                "lag": {m: self.market.lag(m) for m in markets}}

    def inputs(self, account, markets, now, snapshot):
        """A registration's (config, data): the account's and the new thesis's markets as of `now`, and the
        session snapshot's daily bars."""
        markets = set(self.markets_of(account)) | set(markets)
        return self.config(markets), {**self.data(markets, now),
                                      "daily": {m: scoring.bars(snapshot["daily"].get(m, [])) for m in markets}}

    def markets_of(self, account):
        return sorted({m for th in self.ledger.theses(account) for m, _ in th["legs"]})

    def replay(self, account, now):
        return positions.run(INITIAL, self.ledger.theses(account), self.ledger.exits(account),
                             self.data(self.markets_of(account), now), now)

    def snapshot(self, now):
        listings = self.market.listings()
        markets, daily = {}, {}
        for m, delisted in sorted(listings.items()):
            if delisted:
                continue
            d = self.market.bars(m, "1d", now)
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
        inputs = lambda acct, markets, now: self.inputs(acct, markets, now, snapshot)
        replay = lambda acct, now: {"theses": self.replay(acct, now)["theses"]}
        return Daemon(socket_path, session, account, self.ledger, snapshot, self.fetcher, self.root / "responses", replay,
                      inputs, commands, ablation_of=ablation_of).serve()

    def session(self, kind, account, date, snapshot, commands, task=None, ablation_of=None):
        name = f"{kind}-{date}" if ablation_of is None else f"ablation-{ablation_of}"
        self.ledger.disclose("session", account, {"session": name, "kind": kind, "started": now_ms(),
                                                  "manifest": self.manifest})
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
        while not session.available(harness.MODEL):
            if now_ms() >= date + DAY:
                self.ledger.disclose("session_missed", "main", {"date": date, "reason": "the model was unavailable all day"})
                return
            time.sleep(session.RETRY)
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
            config, data = self.inputs("benchmark", [m], now_ms(), snapshot)
            equity = self.replay("benchmark", monday)["equity"]
            probe = {"legs": [[m, w]], "t_r": now_ms(), "T": monday + 21 * DAY, "N": 0.01 * (equity[-1][1] if equity else INITIAL) / 0.1,
                     "costs": config["costs"], "fee": config["fee"]}
            p_ref, _, _ = scoring.base_rate(probe, data["daily"], data["funding"])
            if p_ref is None:
                self.ledger.disclose("skip", "benchmark", {"date": monday, "market": m, "reason": "no base rate"})
                continue
            request = {"request_id": f"benchmark-{monday}-{m}", "legs": [[m, w]], "T": monday + 21 * DAY, "p": p_ref,
                       "L": 0.1, "catalyst": "frozen benchmark: the sign of the 20-day return", "catalyst_id": "benchmark",
                       "sources": [], "outcome_market": None}
            _, errors = registry.register(self.ledger, "benchmark", f"benchmark-{monday}", request, now_ms,
                                          snapshot["listings"], set(), config, data)
            if errors:
                self.ledger.disclose("skip", "benchmark", {"date": monday, "market": m, "reason": "; ".join(errors)})

    def resolve(self, now):
        """Record each due thesis's outcome once, or its missing-data status once."""
        done = {(c["id"], c["status"]) for _, _, c in self.ledger.records("resolution")}
        for account in ACCOUNTS:
            theses = [th for th in self.ledger.theses(account) if th["T"] <= now]
            if not theses:
                continue
            data = self.data(self.markets_of(account), now)
            managed = positions.run(INITIAL, self.ledger.theses(account), self.ledger.exits(account), data, now)["theses"]
            for th in theses:
                if (th["id"], "resolved") in done:
                    continue
                out = positions.outcome(th, data, now)
                if out is not None:
                    self.ledger.disclose("resolution", account, {"id": th["id"], "status": "resolved", "outcome": out,
                                                                 "managed_return": managed[th["id"]]["managed_return"],
                                                                 "at": now})
                elif now >= th["T"] + RESOLUTION_GRACE and (th["id"], "missing data") not in done:
                    self.ledger.disclose("resolution", account, {"id": th["id"], "status": "missing data", "at": now})

    def benchmarked(self, monday):
        return any(c["date"] == monday for _, _, c in self.ledger.records("skip", "benchmark")) or \
            any(th["session"] == f"benchmark-{monday}" for th in self.ledger.theses("benchmark"))

    def run(self):
        """Forever: resolutions every 5 min and builder marks at H + MARK_OFFSET (stage 10 revision of 2026-10-23) on
        their own threads; the Monday benchmark and the daily sessions each minute (`schedule`). One runner per root."""
        frozen = json.loads(FROZEN.read_text()) if FROZEN.exists() else {}
        if frozen.get("manifest") != self.manifest:
            raise SystemExit(f"the manifest differs from {FROZEN}: freeze it (a new track version) before running")
        self.root.mkdir(parents=True, exist_ok=True)
        lock = open(self.root / "run.lock", "w")
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        self.venue
        threading.Thread(target=forever, args=("resolve", lambda: self.resolve(now_ms()), lambda now: 300_000), daemon=True).start()
        threading.Thread(target=forever, args=("marks", self.market.record_marks,
                                               lambda now: now // HOUR * HOUR + HOUR + MARK_OFFSET - now), daemon=True).start()
        forever("schedule", lambda: self.schedule(now_ms(), frozen["frozen"]), lambda now: 60_000)

    def schedule(self, now, frozen):
        """The Monday benchmark and the daily sessions due at `now`, for a track version frozen at `frozen`."""
        date = now // DAY * DAY
        monday = date - ((date // DAY + 3) % 7) * DAY
        if monday > frozen - DAY and not self.benchmarked(monday):
            if now - monday < DAY:
                self.benchmark(monday)
            else:
                self.ledger.disclose("skip", "benchmark", {"date": monday, "market": None, "reason": "run missed"})
        if now >= date + SESSION_OFFSET and not self.started("main", date) and not self.missed(date):
            self.day(date)

    def missed(self, date):
        return any(c["date"] == date for _, _, c in self.ledger.records("session_missed"))


def forever(name, step, wait):
    """Run `step` after each `wait(now)` ms, forever; a failure is logged and the loop goes on."""
    while True:
        time.sleep(wait(now_ms()) / 1000)
        try:
            step()
        except Exception as e:
            print(time.strftime("%FT%T"), name, repr(e), flush=True)


def pinned_kernel(root, fresh=False):
    """The track's own copy of the `mm` binary, which writes its ledger: copied from the current build when absent, or
    afresh at a freeze, so later kernel builds never change a running track version."""
    path = Path(root) / "bin" / "mm"
    if fresh or not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(kernel.build(), path)
    return path


def freeze():
    """Record the manifest, with the kernel binary pinned: the start of a track version and of C10.5's observation
    window."""
    manifest = harness.manifest_hash(pinned_kernel(ROOT, fresh=True))
    FROZEN.parent.mkdir(parents=True, exist_ok=True)
    old = json.loads(FROZEN.read_text()) if FROZEN.exists() else None
    if old and old["manifest"] == manifest:
        raise SystemExit("this manifest is already frozen")
    FROZEN.write_text(json.dumps({"manifest": manifest, "version": f"thesis-{manifest[:12]}",
                                  "frozen": now_ms(), "previous": old}, indent=1) + "\n")


def run():
    Track().run()


def report(out):
    from thesis import report as r

    r.write(Track(), now_ms(), out)
