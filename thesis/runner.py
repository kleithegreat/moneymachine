"""The thesis track's runner (audit/criteria.md, stage 10): for one frozen track version (named by the
manifest hash), the daily snapshot acquired from 00:05 UTC, the main session at 05:00 UTC with an ablation per accepted
thesis and then the full no-reading session; the Monday benchmark on that snapshot; hourly resolutions; and the report.

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
from collections.abc import Callable, Iterable
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import httpx

from gate import kernel
from ingest.fallback import fill_missing
from ingest.live import now_ms
from ingest.policy import DAY, DELTA, HOUR
from sandbox import canary, session
from thesis import harness, positions, registry, scoring
from thesis.daemon import Daemon
from thesis.market import FRESH, MARK_OFFSET, MARK_PREP, Exchange, Market
from thesis.positions import Json
from thesis.retrieval import Fetcher

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO / "data" / "thesis"
FROZEN = REPO / "audit" / "stage10" / "manifest.json"
SNAPSHOT_OFFSET = 5 * 60_000
SESSION_OFFSET = 5 * HOUR
ACCOUNTS = ("main", "noread", "benchmark")
BENCHMARK = ("BTC", "ETH", "xyz:XYZ100", "xyz:GOLD", "flx:OIL")
INITIAL = 10_000.0
PREWARM_EVERY = 15 * 60_000  # between passes of the background funding fill
RESOLUTION_GRACE = 90 * 60_000  # well before C10.5's two hours; `deadlines` reads only the ledger, each minute
MAIN_COMMANDS = ("markets", "prices", "fetch", "register", "positions", "exit")
NOREAD_COMMANDS = ("markets", "prices", "register", "positions", "exit")


def unbenchmarkable(snapshot: Json, m: str, days: Iterable[int]) -> str | None:
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
    return None


class Track:
    def __init__(self, root: str | Path = ROOT) -> None:
        self.root = Path(root)
        self.stop = threading.Event()
        self.attestation = threading.Lock()
        kernel = pinned_kernel(self.root)
        self.manifest = harness.manifest_hash(kernel)
        self.version = f"thesis-{self.manifest[:12]}"
        self.ledger = registry.Ledger(self.root / "ledger.sqlite", self.version, kernel)
        self.market = Market(self.root / "market", Exchange(self.root / "exchange"))
        self.fetcher = Fetcher()

    @functools.cached_property
    def venue(self) -> tuple[float, Json]:
        """The taker fee and the C0.7 cost cells, read once."""
        rules = json.loads((REPO / "venue/hyperliquid/rules.json").read_text())
        cells = json.loads((REPO / "venue/hyperliquid/execution.json").read_text())["cost_bps_ex_fee"]
        return rules["rules"]["taker_fee"]["value"], cells

    def config(self, markets: Iterable[str]) -> Json:
        """The fee, and each market's cost cells or the maximum over U (an unvalidated fallback)."""
        fee, cells = self.venue
        costs, fallback = fill_missing(cells, sorted(markets))
        return {"initial": INITIAL, "fee": fee, "costs": costs, "fallback": fallback}

    def read(self, market: str, now: int, start: int | None = None) -> Json:
        """A market's hourly bars, funding and lag as of `now`: every cached funding row, the venue asked only about
        [start, now), the whole scope by default (a read in a session passes where its own dependency begins; the background
        fill makes the rest ready)."""
        return {"bars": scoring.bars(self.market.bars(market, "1h", now)),
                "funding": dict(self.market.funding(market, now, start)), "lag": self.market.lag(market)}

    def data(self, markets: Iterable[str], now: int, starts: Json | None = None) -> Json:
        return joined({m: self.read(m, now, (starts or {}).get(m)) for m in markets}, now)

    def starts(self, theses: Iterable[Json]) -> Json:
        """{market: the earliest registration of `theses` in it}: where its funding dependency begins."""
        out: Json = {}
        for th in theses:
            for m, _ in th["legs"]:
                out[m] = min(out.get(m, th["t_r"]), th["t_r"])
        return out

    def inputs(self, account: str, markets: Iterable[str], now: int, snapshot: Json) -> tuple[Json, Json]:
        """Day-fixed admission, shared daily bars, and account inputs at the registration's own cutoff."""
        markets = set(markets)
        cold = sorted(m for m in markets if not snapshot["ready"].get(m, False))
        if cold:
            raise httpx.TransportError(f"funding history is not ready for {cold}")
        markets |= set(self.markets_of(account))
        starts = dict.fromkeys(markets, now - FRESH) | self.starts(self.ledger.theses(account))
        return self.config(markets), {**self.data(markets, now, starts), "listed": self.market.listed,
                                      "daily": {m: scoring.bars(snapshot["daily"].get(m, [])) for m in markets}}

    def markets_of(self, account: str) -> list[str]:
        return sorted({m for th in self.ledger.theses(account) for m, _ in th["legs"]})

    def replay(self, account: str, now: int) -> Json:
        return positions.run(INITIAL, self.ledger.theses(account), self.ledger.exits(account),
                             self.data(self.markets_of(account), now, self.starts(self.ledger.theses(account))), now)

    def snapshot(self, now: int) -> Json:
        """Reuse only attested bytes; otherwise acquire afresh until the date's deadline or stop."""
        path = self.root / "snapshots" / f"{now}.json"
        date = now // DAY * DAY
        if any(c["taken"] == now for _, _, c in self.ledger.records("snapshot_ready", "main")):
            saved = self.attested(date, last_acquisition(date))
            if saved is None:
                raise ValueError("attested snapshot bytes are missing or changed")
            return saved
        cancelled = lambda: self.stop.is_set() or now_ms() >= last_acquisition(date)

        def check() -> None:
            if cancelled():
                raise TimeoutError("snapshot acquisition ended")

        markets, daily, before = {}, {}, self.market.sent()
        with self.market.hold(cancel=cancelled):
            check()
            listed_at = now_ms()
            listings = self.market.listings()
            benchmark_listings = self.market.listings_at(date) if is_monday(date) else {}
            scope = listings.keys() | benchmark_listings.keys()
            for m in sorted(scope):
                check()
                if listings.get(m, True) and benchmark_listings.get(m, True):
                    continue
                d = self.market.bars(m, "1d", now)
                if len(d) < registry.MIN_DAILY_BARS:
                    continue
                check()
                h = [r for r in self.market.bars(m, "1h", now) if r[2] is not None]
                if h:
                    markets[m] = {"last_close": h[-1][2], "t": h[-1][0] + HOUR}
                    daily[m] = d
            readiness_at = now_ms()
            ready = {m: self.market.ready(m, readiness_at) for m in scope}
        check()
        snap = {"taken": now, "listed_at": listed_at, "requests": self.market.sent() - before, "listings": listings,
                "markets": {m: v for m, v in markets.items() if not listings.get(m, True)}, "daily": daily,
                "readiness_at": readiness_at, "ready": ready}
        if is_monday(date):
            snap.update(benchmark_listings=benchmark_listings,
                        benchmark_markets={m: v for m, v in markets.items() if not benchmark_listings.get(m, True)})
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(snap))
        check()
        os.replace(tmp, path)
        return snap

    def attested(self, date: int, by: int | None = None) -> Json | None:
        """The day's snapshot if the ledger attests its exact bytes as published before `by` (the session deadline by default):
        there is no other."""
        cutoff, by = date + SNAPSHOT_OFFSET, by or date + SESSION_OFFSET
        path = self.root / "snapshots" / f"{cutoff}.json"
        saved = [c for _, _, c in self.ledger.records("snapshot_ready", "main") if c["taken"] == cutoff and c["acquired"] < by]
        if not saved or not path.exists() or registry.sha256(path.read_bytes()) != saved[0]["sha256"]:
            return None
        snap: Json = json.loads(path.read_text())
        return snap

    def attested_at(self, date: int) -> int:
        """When the day's snapshot was attested, as milliseconds after the date's start."""
        return int(min(c["acquired"] for _, _, c in self.ledger.records("snapshot_ready", "main")
                       if c["taken"] == date + SNAPSHOT_OFFSET) - date)

    def acquire(self, date: int) -> None:
        """Take the day's snapshot and attest it, unless it is attested or its last moment has passed or SIGTERM came: the
        session deadline, or the date's end on a Monday, whose benchmark waits for it."""
        cutoff, end = date + SNAPSHOT_OFFSET, last_acquisition(date)
        if any(c["taken"] == cutoff for _, _, c in self.ledger.records("snapshot_ready", "main")) or now_ms() >= end:
            return
        try:
            snap = self.snapshot(cutoff)
        except TimeoutError:
            return
        if self.stop.is_set():
            return
        digest = registry.sha256((self.root / "snapshots" / f"{cutoff}.json").read_bytes())
        with self.attestation:
            if (acquired := now_ms()) < end:
                self.ledger.disclose("snapshot_ready", "main", {"taken": cutoff, "acquired": acquired, "sha256": digest,
                                                                "listed_at": snap["listed_at"], "requests": snap["requests"],
                                                                "readiness_at": snap["readiness_at"]})

    def daemon(self, socket_path: str | Path, session: str, account: str, snapshot: Json, commands: Iterable[str],
               ablation_of: str | None = None) -> Daemon:
        inputs = lambda acct, markets, now: self.inputs(acct, markets, now, snapshot)
        replay = lambda acct, now: {"theses": self.replay(acct, now)["theses"]}
        return Daemon(socket_path, session, account, self.ledger, snapshot, self.fetcher, self.root / "responses", replay,
                      inputs, commands, ablation_of=ablation_of).serve()

    def session(self, kind: str, date: int, snapshot: Json, commands: Iterable[str], task: Json | None = None,
                ablation_of: str | None = None) -> None:
        """One session on the paper account named as its kind, its start on the record first, naming its snapshot."""
        name = f"{kind}-{date}" if ablation_of is None else f"ablation-{ablation_of}"
        self.ledger.disclose("session", kind, {"session": name, "kind": kind, "started": now_ms(), "taken": snapshot["taken"],
                                               "manifest": self.manifest})
        work = self.root / "sessions" / self.version / name
        try:
            with self.market.hold():
                run = harness.run_session(work, kind, lambda sock: self.daemon(sock, name, kind, snapshot, commands, ablation_of), task)
        except Exception as e:
            run = {"kind": kind, "error": repr(e)}
        else:
            calls = [c for _, _, c in self.ledger.records("call", kind) if c["session"] == name]
            run["audit"] = harness.audit(work / "transcript.jsonl", calls)
        self.ledger.disclose("session_end", kind, {"session": name, **run})

    def warm_order(self) -> list[str]:
        """The listed markets the background fill keeps ready, the benchmark's first, then the accounts', then the rest: a
        market not yet eligible is filled too, so it is ready when it becomes one."""
        live = [m for m, delisted in sorted(self.market.listings(background=True).items()) if not delisted]
        first = [*BENCHMARK, *(m for account in ACCOUNTS for m in self.markets_of(account))]
        return [m for m in dict.fromkeys([*first, *live]) if m in live]

    def prewarm(self) -> None:
        fill(self.market, self.warm_order(), self.stop, HOUR)

    def settled(self) -> set[str]:
        """Every session on the record as started or missed: none of them runs again."""
        return {c["session"] for kind in ("session", "session_missed") for _, _, c in self.ledger.records(kind)}

    def close_interrupted(self) -> None:
        """End on the record every session with no end: only a dead runner leaves one, and it consumed the session."""
        ended = {c["session"] for _, _, c in self.ledger.records("session_end")}
        for _, _, c in self.ledger.records("session"):
            if c["session"] not in ended:
                self.ledger.disclose("session_end", c["kind"], {"session": c["session"], "kind": c["kind"],
                                                                "error": "the runner died during the session"})

    def ablation_task(self, th: Json, snapshot: Json) -> tuple[Json, Json]:
        cutoff = {m: [r for r in snapshot["daily"].get(m, []) if r[0] + DAY <= th["t_r"]] for m, _ in th["legs"]}
        task = {"exposure": [{"market": m, "direction": "long" if w == 1 else "short"} for m, w in th["legs"]],
                "forecast_time_ms": th["t_r"], "entry": "the first hourly open at or after the forecast time plus 120 s",
                "horizon_ms": th["T"], "exit": "the first hourly open at or after the horizon",
                "outcome": "the fixed-quantity position's net return (price change, fees, trading costs and hourly "
                           "funding payments) from entry to exit is strictly positive"}
        snap = {**snapshot, "taken": th["t_r"], "daily": cutoff,
                "markets": {m: {"last_close": d[-1][2], "t": d[-1][0] + DAY} for m, d in cutoff.items() if d}}
        return task, snap

    def ready(self, date: int) -> bool:
        """Whether a session of `date` may start now: the model answers and the sandbox canary passes, retried every
        session.RETRY, with no SIGTERM and the day not over when they do."""
        while not self.stop.is_set() and now_ms() < date + DAY:
            if session.available(harness.MODEL) and canary.passes():
                return not self.stop.is_set() and now_ms() < date + DAY
            self.stop.wait(session.RETRY)
        return False

    def miss(self, date: int, account: str, name: str, reason: str = "snapshot or readiness unavailable before the start deadline") -> None:
        self.ledger.disclose("session_missed", account, {"date": date, "session": name,
                                                          "reason": reason})

    def day(self, date: int, snapshot: Json | None) -> None:
        """The sessions on the prepared snapshot (None if unavailable), each once `ready`: main, its accepted theses' ablations,
        and the full no-reading session on main's snapshot. A session that the day's end finds unstarted is disclosed as
        missed, and a SIGTERM leaves the rest of the date to the next start."""
        main = f"main-{date}"
        if main not in self.settled():
            if snapshot is not None and not self.ready(date):
                snapshot = None
            if self.stop.is_set():
                return
            if snapshot is None or now_ms() >= date + DAY:
                self.miss(date, "main", main)
            else:
                self.session("main", date, snapshot, MAIN_COMMANDS)
        if not any(c["session"] == main for _, _, c in self.ledger.records("session")):
            snapshot = None
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

    def benchmark(self, monday: int) -> None:
        """Register the deterministic Monday-midnight reference, retaining its actual receipt time separately."""
        if (attested := self.attested(monday, monday + DAY)) is None:
            return
        snapshot = known_at(attested, monday)
        last = (monday - DELTA) // DAY * DAY - DAY
        before = last - 20 * DAY
        for m in self.unbenchmarked(monday):
            if reason := unbenchmarkable(snapshot, m, (before, last)):
                self.ledger.disclose("skip", "benchmark", {"date": monday, "market": m, "reason": reason})
                continue
            closes = {r[0]: r[2] for r in snapshot["daily"][m]}
            w = 1 if closes[last] > closes[before] else -1
            config, data = self.inputs("benchmark", [m], monday, snapshot)
            data["listed"] = lambda markets: {m: snapshot["listings"][m] for m in markets if m in snapshot["listings"]}
            request = {"request_id": f"benchmark-{monday}-{m}", "legs": [[m, w]], "T": monday + 21 * DAY, "p": None,
                       "L": 0.1, "catalyst": "frozen benchmark: the sign of the 20-day return", "catalyst_id": "benchmark",
                       "sources": [], "outcome_market": None}
            _, errors = registry.register(self.ledger, "benchmark", f"benchmark-{monday}", request, now_ms, set(), config, data,
                                          p_is_base_rate=True, forecast_at=monday)
            if errors:
                self.ledger.disclose("skip", "benchmark", {"date": monday, "market": m, "reason": "; ".join(errors)})

    def resolve(self, now: int) -> None:
        """Record each due thesis's outcome once, from its own markets alone. Each market a due thesis needs is read once a
        pass, all at once, and a thesis is scored as soon as its own markets have been, so a failure or a delay in one market
        holds up only the theses that need it. A record's `at` is when it was written and its `cutoff` the data's."""
        done = {c["id"] for _, _, c in self.ledger.records("resolution") if c["status"] == "resolved"}
        due = [(account, th) for account in ACCOUNTS for th in self.ledger.theses(account) if th["T"] <= now and th["id"] not in done]
        starts = self.starts(th for _, th in due)
        with ThreadPoolExecutor(max(len(due), 1)) as pool:
            reads = {m: pool.submit(self.read, m, now, starts[m]) for m in starts}
            for _ in as_completed(reads.values()):
                ready = {th["id"] for _, th in due if all(reads[m].done() for m, _ in th["legs"])}
                for account, th in [(a, th) for a, th in due if th["id"] in ready]:
                    try:
                        self.score(account, th, joined({m: reads[m].result() for m, _ in th["legs"]}, now), now)
                    except Exception as e:
                        print(time.strftime("%FT%T"), "resolve", th["id"], repr(e), flush=True)
                due = [(a, th) for a, th in due if th["id"] not in ready]

    def score(self, account: str, th: Json, data: Json, now: int) -> None:
        """A position's managed return depends on no other thesis, so it is replayed alone; its failure leaves the outcome
        scored, with the failure on the record."""
        out = positions.outcome(th, data, now)
        if out is None:
            return
        managed: Json = {"managed_return": None}
        try:
            exits = [e for e in self.ledger.exits(account) if e["id"] == th["id"]]
            managed["managed_return"] = positions.run(INITIAL, [th], exits, data, now)["theses"][th["id"]]["managed_return"]
        except Exception as e:
            managed["managed_failure"] = repr(e)
        self.ledger.disclose("resolution", account, {"id": th["id"], "status": "resolved", "outcome": out, **managed,
                                                     "at": now_ms(), "cutoff": now})

    def deadlines(self, now: int) -> None:
        """Record once a missing-data status for each thesis RESOLUTION_GRACE past its horizon with no record: from the ledger
        alone, so no market can delay it. A score can still follow."""
        recorded = {c["id"] for _, _, c in self.ledger.records("resolution")}
        for account in ACCOUNTS:
            for th in self.ledger.theses(account):
                if th["T"] + RESOLUTION_GRACE <= now and th["id"] not in recorded:
                    self.ledger.disclose("resolution", account, {"id": th["id"], "status": "missing data", "at": now_ms()})

    def unbenchmarked(self, monday: int) -> list[str]:
        """The markets of a Monday's batch neither registered nor skipped on the record, in order."""
        done = {c["market"] for _, _, c in self.ledger.records("skip", "benchmark") if c["date"] == monday} | \
            {th["legs"][0][0] for th in self.ledger.theses("benchmark") if th["session"] == f"benchmark-{monday}"}
        return [m for m in BENCHMARK if m not in done]

    def run(self) -> None:
        """Until SIGTERM: resolutions every 5 min, missing-data statuses each minute, builder marks at H + MARK_OFFSET and the
        Monday benchmark (`benchmarks`) and the daily snapshots (`acquisitions`) each minute on their own threads; the daily sessions
        each minute (`schedule`). On SIGTERM
        each loop finishes its current step and the runner exits, leaving a day's remaining sessions to the next start. One
        runner per root."""
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
                 threading.Thread(target=forever, args=("deadlines", lambda: self.deadlines(now_ms()), lambda now: 60_000, stop)),
                 threading.Thread(target=hourly_marks, args=(self.market.record_marks, stop)),
                 threading.Thread(target=forever, args=("prewarm", self.prewarm, lambda now: PREWARM_EVERY, stop)),
                 threading.Thread(target=forever, args=("acquire", lambda: self.acquisitions(now_ms(), frozen["frozen"]),
                                                        lambda now: 60_000, stop)),
                 threading.Thread(target=forever, args=("benchmarks", lambda: self.benchmarks(now_ms(), frozen["frozen"]),
                                                        lambda now: 60_000, stop))]
        for t in loops:
            t.start()
        forever("schedule", lambda: self.schedule(now_ms(), frozen["frozen"]), lambda now: 60_000, stop)
        for t in loops:
            t.join()

    def benchmarks(self, now: int, frozen: int) -> None:
        """Run each Monday batch after attestation and the session deadline, rounded up to an hour except in the last hour.
        A date without an attested snapshot is logged as missed; transient failures leave the batch to the next pass."""
        for monday in range(frozen // DAY * DAY, now + 1, DAY):
            if is_monday(monday) and self.unbenchmarked(monday):
                elapsed, snap = now - monday, self.attested(monday, monday + DAY)
                due = max(SESSION_OFFSET, self.attested_at(monday)) if snap is not None else 0
                if snap is not None and elapsed < DAY:
                    if due < 23 * HOUR:
                        due = -(-due // HOUR) * HOUR
                    if elapsed >= due:
                        self.benchmark(monday)
                elif reason := "run missed" if snap is not None else "no attested snapshot" if elapsed >= DAY else None:
                    for m in self.unbenchmarked(monday):
                        self.ledger.disclose("skip", "benchmark", {"date": monday, "market": m, "reason": reason})

    def acquisitions(self, now: int, frozen: int) -> None:
        """Every date since the freeze of a version frozen at `frozen` whose snapshot is due and whose last acquisition moment
        is not past, acquired and attested whatever the sessions or the model are doing."""
        for date in range(frozen // DAY * DAY, now + 1 - SNAPSHOT_OFFSET, DAY):
            if now < last_acquisition(date) and not self.stop.is_set():
                self.acquire(date)

    def schedule(self, now: int, frozen: int) -> None:
        """Every date since the freeze of a version frozen at `frozen` whose sessions are due at `now` and not all settled,
        oldest first, so a date an outage spanned is disclosed as missed, and a session a crash cut off ends on the record.
        A date without an attested snapshot misses main and no-reading."""
        self.close_interrupted()
        for date in range(frozen // DAY * DAY, now + 1 - SESSION_OFFSET, DAY):
            if f"noread-{date}" in self.settled():
                continue
            with self.attestation:
                snapshot = self.attested(date)
                if snapshot is None and f"main-{date}" not in self.settled():
                    for kind in ("main", "noread"):
                        self.miss(date, kind, f"{kind}-{date}", "no attested snapshot before the completion deadline")
                    continue
            self.day(date, snapshot)
            if self.stop.is_set():
                return


def is_monday(date: int) -> bool:
    return bool((date // DAY + 3) % 7 == 0)


def last_acquisition(date: int) -> int:
    """The last moment a date's snapshot may be attested: its sessions' deadline, or on a Monday the end of the date."""
    return int(date + (DAY if is_monday(date) else SESSION_OFFSET))


def known_at(snapshot: Json, at: int) -> Json:
    """The Monday view: historical listings and daily bars closed DELTA before midnight."""
    daily = {m: [r for r in d if r[0] + DAY + DELTA <= at] for m, d in snapshot["daily"].items()}
    kept = {m for m, d in daily.items() if len(d) >= registry.MIN_DAILY_BARS}
    return {**snapshot, "taken": at, "listings": snapshot["benchmark_listings"],
            "markets": {m: v for m, v in snapshot["benchmark_markets"].items() if m in kept},
            "daily": {m: daily[m] for m in kept}}


def fill(market: Market, order: Iterable[str], stop: threading.Event, limit: int | None = None) -> None:
    """One background pass over `order`, stopping between markets after `limit` ms or SIGTERM; a failed market keeps the
    pages it committed and the pass goes on."""
    began = now_ms()
    for m in order:
        if stop.is_set() or (limit is not None and now_ms() - began >= limit):
            return
        try:
            market.prewarm(m, now_ms(), stop)
        except (httpx.HTTPError, ValueError) as e:
            print(time.strftime("%FT%T"), "prewarm", m, repr(e), flush=True)


def joined(reads: dict[str, Json], now: int) -> Json:
    """The data of several markets' reads (`Track.read`) as of `now`."""
    return {k: {m: r[k] for m, r in reads.items()} for k in ("bars", "funding", "lag")} | {"cutoff": now}


def hourly_marks(sample: Callable[[int], None], stop: threading.Event) -> None:
    """Choose the hourly deadline once before waiting, so a clock step cannot change the batch's identity."""
    while not stop.is_set():
        now = now_ms()
        due = (now - MARK_OFFSET + MARK_PREP) // HOUR * HOUR + HOUR + MARK_OFFSET
        if stop.wait((due - MARK_PREP - now) / 1000):
            return
        try:
            sample(due)
        except Exception as e:
            print(time.strftime("%FT%T"), "marks", repr(e), flush=True)


def forever(name: str, step: Callable[[], None], wait: Callable[[int], float], stop: threading.Event) -> None:
    """Run `step` after each `wait(now)` ms until `stop` is set; a failure is logged and the loop goes on."""
    while not stop.wait(wait(now_ms()) / 1000):
        try:
            step()
        except Exception as e:
            print(time.strftime("%FT%T"), name, repr(e), flush=True)


def pinned_kernel(root: str | Path, fresh: bool = False) -> Path:
    """The track's own copy of the `mm` binary, which writes its ledger: copied from the current build when absent, or
    afresh at a freeze, so later kernel builds never change a running track version."""
    path = Path(root) / "bin" / "mm"
    if fresh or not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(kernel.build(), path)
    return path


def freeze() -> None:
    """Record the manifest, with the kernel binary pinned, once the sandbox canary passes: the start of a track version
    and of C10.5's observation window."""
    canary.check()
    market = Market(ROOT / "market", Exchange(ROOT / "exchange"))
    cold = [m for m, delisted in sorted(market.listings().items()) if not delisted and not market.ready(m, now_ms())]
    if cold:
        raise SystemExit(f"funding history is not ready for {len(cold)} listed markets, such as {cold[:5]}: let the background "
                         "fill finish before the freeze")
    manifest = harness.manifest_hash(pinned_kernel(ROOT, fresh=True))
    FROZEN.parent.mkdir(parents=True, exist_ok=True)
    old = json.loads(FROZEN.read_text()) if FROZEN.exists() else None
    if old and old["manifest"] == manifest:
        raise SystemExit("this manifest is already frozen")
    FROZEN.write_text(json.dumps({"manifest": manifest, "version": f"thesis-{manifest[:12]}",
                                  "frozen": now_ms(), "previous": old}, indent=1) + "\n")


def run() -> None:
    Track().run()


def prewarm() -> None:
    """One resumable acquisition pass, without starting or freezing a track. Run only with the runner stopped."""
    ROOT.mkdir(parents=True, exist_ok=True)
    with (ROOT / "run.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        stop = threading.Event()
        signal.signal(signal.SIGTERM, lambda *_: stop.set())
        market = Market(ROOT / "market", Exchange(ROOT / "exchange"))
        fill(market, [m for m, delisted in sorted(market.listings(background=True).items()) if not delisted], stop)


def report(out: str | Path) -> None:
    from thesis import report as r

    r.write(Track(), now_ms(), out)
