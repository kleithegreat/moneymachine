"""The thesis track's runner (audit/criteria.md, stage 10): for one frozen track version (named by the
manifest hash), the daily main session at 00:10 UTC with an ablation per accepted thesis and then the
full no-reading session; the Monday benchmark; hourly resolutions; and the report.

The state is the ledger: each session runs once, recorded when it starts, so a crash consumes that session and ends it
on the record, and a restart runs the rest of its date; a resolution or a missing-data status is recorded once per thesis.
"""

import fcntl
import functools
import json
import os
import shutil
import signal
import threading
import time
from pathlib import Path

import httpx

from gate import kernel
from ingest.fallback import fill_missing
from ingest.live import now_ms
from ingest.policy import DAY, DELTA, HOUR
from sandbox import canary, session
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
RESOLUTION_GRACE = 90 * 60_000  # a status by C10.5's two hours, with room for resolve passes; candles come at T + 1 h + δ
MAIN_COMMANDS = ("markets", "prices", "fetch", "register", "positions", "exit")
NOREAD_COMMANDS = ("markets", "prices", "register", "positions", "exit")


def unbenchmarkable(snapshot, m, days):
    """Why `snapshot` holds no daily close of `m` on each of `days`, by cause; None if it holds them."""
    if m not in snapshot["listings"]:
        return "not listed"
    if snapshot["listings"][m]:
        return "delisted"
    if m not in snapshot["markets"]:
        return f"fewer than {registry.MIN_DAILY_BARS} daily bars or no hourly close"
    have = {r[0] for r in snapshot["daily"][m]}
    if missing := [d for d in days if d not in have]:
        return f"no daily close at {missing}"


class Track:
    def __init__(self, root=ROOT):
        self.root = Path(root)
        self.stop = threading.Event()
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
        """A registration's (config, data): the new thesis's markets' listings now, the account's and its markets as of
        `now`, and the session snapshot's daily bars."""
        listings = self.market.listed(markets)
        markets = set(self.markets_of(account)) | set(markets)
        return self.config(markets), {**self.data(markets, now), "listings": listings,
                                      "daily": {m: scoring.bars(snapshot["daily"].get(m, [])) for m in markets}}

    def markets_of(self, account):
        return sorted({m for th in self.ledger.theses(account) for m, _ in th["legs"]})

    def replay(self, account, now):
        return positions.run(INITIAL, self.ledger.theses(account), self.ledger.exits(account),
                             self.data(self.markets_of(account), now), now)

    def snapshot(self, now):
        """The market snapshot taken at `now`: the one already saved under that time, else a new one saved."""
        path = self.root / "snapshots" / f"{now}.json"
        if path.exists():
            return json.loads(path.read_text())
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
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(snap))
        os.replace(tmp, path)
        return snap

    def daemon(self, socket_path, session, account, snapshot, commands, ablation_of=None):
        inputs = lambda acct, markets, now: self.inputs(acct, markets, now, snapshot)
        replay = lambda acct, now: {"theses": self.replay(acct, now)["theses"]}
        return Daemon(socket_path, session, account, self.ledger, snapshot, self.fetcher, self.root / "responses", replay,
                      inputs, commands, ablation_of=ablation_of).serve()

    def session(self, kind, date, snapshot, commands, task=None, ablation_of=None):
        """One session on the paper account named as its kind, its start on the record first, naming its snapshot."""
        name = f"{kind}-{date}" if ablation_of is None else f"ablation-{ablation_of}"
        self.ledger.disclose("session", kind, {"session": name, "kind": kind, "started": now_ms(), "taken": snapshot["taken"],
                                               "manifest": self.manifest})
        work = self.root / "sessions" / self.version / name
        try:
            run = harness.run_session(work, kind, lambda sock: self.daemon(sock, name, kind, snapshot, commands, ablation_of), task)
        except Exception as e:
            run = {"kind": kind, "error": repr(e)}
        else:
            calls = [c for _, _, c in self.ledger.records("call", kind) if c["session"] == name]
            run["audit"] = harness.audit(work / "transcript.jsonl", calls)
        self.ledger.disclose("session_end", kind, {"session": name, **run})

    def settled(self):
        """Every session on the record as started or missed: none of them runs again."""
        return {c["session"] for kind in ("session", "session_missed") for _, _, c in self.ledger.records(kind)}

    def close_interrupted(self):
        """End on the record every session with no end: only a dead runner leaves one, and it consumed the session."""
        ended = {c["session"] for _, _, c in self.ledger.records("session_end")}
        for _, _, c in self.ledger.records("session"):
            if c["session"] not in ended:
                self.ledger.disclose("session_end", c["kind"], {"session": c["session"], "kind": c["kind"],
                                                                "error": "the runner died during the session"})

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

    def ready(self, date):
        """Whether a session of `date` may start now: the model answers and the sandbox canary passes, retried every
        session.RETRY, with no SIGTERM and the day not over when they do."""
        while not self.stop.is_set() and now_ms() < date + DAY:
            if session.available(harness.MODEL) and canary.passes():
                return not self.stop.is_set() and now_ms() < date + DAY
            self.stop.wait(session.RETRY)
        return False

    def miss(self, date, account, name):
        self.ledger.disclose("session_missed", account, {"date": date, "session": name,
                                                         "reason": "the day ended before the session could start"})

    def day(self, date):
        """The sessions of `date` not yet settled, each once `ready`, in order: main, an ablation per thesis main accepted,
        and the full no-reading session on main's snapshot. A session that the day's end finds unstarted is disclosed as
        missed, and a SIGTERM leaves the rest of the date to the next start."""
        main = f"main-{date}"
        if main not in self.settled():
            snapshot = self.snapshot(now_ms()) if self.ready(date) else None
            if self.stop.is_set():
                return
            if snapshot is None or now_ms() >= date + DAY:
                self.miss(date, "main", main)
            else:
                self.session("main", date, snapshot, MAIN_COMMANDS)
        taken = [c["taken"] for _, _, c in self.ledger.records("session") if c["session"] == main]
        snapshot = self.snapshot(taken[0]) if taken else None
        theses = [t for t in self.ledger.theses("main") if t["session"] == main]
        for kind, name, th in [("ablation", f"ablation-{t['id']}", t) for t in theses] + [("noread", f"noread-{date}", None)]:
            if name in self.settled():
                continue
            if snapshot is not None and self.ready(date):
                if th is None:
                    self.session(kind, date, snapshot, NOREAD_COMMANDS)
                else:
                    task, snap = self.ablation_task(th, snapshot)
                    self.session(kind, date, snap, ("prices", "forecast"), task, ablation_of=th["id"])
            elif self.stop.is_set():
                return
            else:
                self.miss(date, kind, name)

    def benchmark(self, monday):
        """The frozen benchmark's registrations for one Monday 00:00 UTC, in BENCHMARK order, of the markets not yet on the
        record: each market's last daily close known at that instant (a bar is known DELTA after it closes) against the
        close 20 days before it."""
        snapshot = self.snapshot(monday)
        last = (monday - DELTA) // DAY * DAY - DAY
        before = last - 20 * DAY
        for m in self.unbenchmarked(monday):
            if reason := unbenchmarkable(snapshot, m, (before, last)):
                self.ledger.disclose("skip", "benchmark", {"date": monday, "market": m, "reason": reason})
                continue
            closes = {r[0]: r[2] for r in snapshot["daily"][m]}
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
            _, errors = registry.register(self.ledger, "benchmark", f"benchmark-{monday}", request, now_ms, set(), config, data)
            if errors:
                self.ledger.disclose("skip", "benchmark", {"date": monday, "market": m, "reason": "; ".join(errors)})

    def resolve(self, now):
        """Record each due thesis's outcome once, or its missing-data status once."""
        done = {(c["id"], c["status"]) for _, _, c in self.ledger.records("resolution")}
        for account in ACCOUNTS:
            theses = [th for th in self.ledger.theses(account) if th["T"] <= now and (th["id"], "resolved") not in done]
            if not theses:
                continue
            try:
                data = self.data(self.markets_of(account), now)
            except httpx.HTTPError as e:
                print(time.strftime("%FT%T"), "resolve", account, repr(e), flush=True)
                data = None
            managed = None if data is None else positions.run(INITIAL, self.ledger.theses(account), self.ledger.exits(account),
                                                              data, now)["theses"]
            for th in theses:
                out = None if data is None else positions.outcome(th, data, now)
                if out is not None:
                    self.ledger.disclose("resolution", account, {"id": th["id"], "status": "resolved", "outcome": out,
                                                                 "managed_return": managed[th["id"]]["managed_return"],
                                                                 "at": now})
                elif now >= th["T"] + RESOLUTION_GRACE and (th["id"], "missing data") not in done:
                    self.ledger.disclose("resolution", account, {"id": th["id"], "status": "missing data", "at": now})

    def unbenchmarked(self, monday):
        """The markets of a Monday's batch neither registered nor skipped on the record, in order."""
        done = {c["market"] for _, _, c in self.ledger.records("skip", "benchmark") if c["date"] == monday} | \
            {th["legs"][0][0] for th in self.ledger.theses("benchmark") if th["session"] == f"benchmark-{monday}"}
        return [m for m in BENCHMARK if m not in done]

    def run(self):
        """Until SIGTERM: resolutions every 5 min, builder marks at H + MARK_OFFSET and the Monday benchmark (`benchmarks`) each
        minute on their own threads; the daily sessions each minute (`schedule`). On SIGTERM each loop finishes its current
        step and the runner exits, leaving a day's remaining sessions to the next start. One runner per root."""
        frozen = json.loads(FROZEN.read_text()) if FROZEN.exists() else {}
        if frozen.get("manifest") != self.manifest:
            raise SystemExit(f"the manifest differs from {FROZEN}: freeze it (a new track version) before running")
        self.root.mkdir(parents=True, exist_ok=True)
        lock = open(self.root / "run.lock", "w")
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        self.venue
        stop = self.stop
        signal.signal(signal.SIGTERM, lambda *_: stop.set())
        loops = [threading.Thread(target=forever, args=("resolve", lambda: self.resolve(now_ms()), lambda now: 300_000, stop)),
                 threading.Thread(target=forever, args=("marks", self.market.record_marks,
                                                        lambda now: now // HOUR * HOUR + HOUR + MARK_OFFSET - now, stop)),
                 threading.Thread(target=forever, args=("benchmarks", lambda: self.benchmarks(now_ms(), frozen["frozen"]),
                                                        lambda now: 60_000, stop))]
        for t in loops:
            t.start()
        forever("schedule", lambda: self.schedule(now_ms(), frozen["frozen"]), lambda now: 60_000, stop)
        for t in loops:
            t.join()

    def benchmarks(self, now, frozen):
        """Every Monday since the freeze of a version frozen at `frozen`: a batch runs within its day; what its day left
        unprocessed is logged as missed, market by market, never backdated. Its failure leaves the batch to the next pass."""
        for monday in range(frozen // DAY * DAY, now + 1, DAY):
            if (monday // DAY + 3) % 7 == 0 and self.unbenchmarked(monday):
                if now - monday < DAY:
                    self.benchmark(monday)
                else:
                    for m in self.unbenchmarked(monday):
                        self.ledger.disclose("skip", "benchmark", {"date": monday, "market": m, "reason": "run missed"})

    def schedule(self, now, frozen):
        """Every date since the freeze of a version frozen at `frozen` whose sessions are due at `now` and not all settled,
        oldest first, so a date an outage spanned is disclosed as missed, and a session a crash cut off ends on the record."""
        self.close_interrupted()
        for date in range(frozen // DAY * DAY, now + 1 - SESSION_OFFSET, DAY):
            if f"noread-{date}" not in self.settled():
                self.day(date)


def forever(name, step, wait, stop):
    """Run `step` after each `wait(now)` ms until `stop` is set; a failure is logged and the loop goes on."""
    while not stop.wait(wait(now_ms()) / 1000):
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
    """Record the manifest, with the kernel binary pinned, once the sandbox canary passes: the start of a track version
    and of C10.5's observation window."""
    canary.check()
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
