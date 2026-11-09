"""The thesis ledger and registration (audit/criteria.md, stage 10).

Records are canonical JSON (sorted keys, no whitespace) written with `mm disclose` to an append-only
ledger, one campaign per track version and one agent name per paper account. Kinds: `thesis`, `exit`,
`resolution`, and `call` (every daemon call, before its response is released).
"""

import hashlib
import json
import math
import sqlite3
import subprocess
import tempfile
import threading
from collections.abc import Callable, Collection
from contextlib import closing
from pathlib import Path
from typing import Any

from gate.kernel import MM, command
from ingest.policy import DAY, HOUR
from thesis import positions, scoring
from thesis.positions import Json

FIELDS = {"request_id", "legs", "T", "p", "L", "catalyst", "catalyst_id", "sources", "outcome_market"}
MIN_DAILY_BARS = 90
AMOUNTS = ("N", "size", "b", "E_r", "reserved")  # recorded as exact rationals' text


def canonical(obj: Any) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def sha256(text: str | bytes) -> str:
    return hashlib.sha256(text.encode() if isinstance(text, str) else text).hexdigest()


class Ledger:
    def __init__(self, path: str | Path, track: str, binary: str | Path = MM) -> None:
        self.path, self.track, self.binary = Path(path), track, binary
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock = threading.Lock()

    def disclose(self, kind: str, account: str, content: Json) -> tuple[Any, str]:
        text = canonical(content)
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh:
            fh.write(text)
        try:
            r = subprocess.run(command("disclose", fh.name, self.track, account, self.path, None, "--kind", kind,
                                       binary=self.binary),
                               capture_output=True, text=True)
        finally:
            Path(fh.name).unlink()
        if r.returncode != 0:
            raise RuntimeError(f"ledger write failed: {r.stderr.strip()}")
        return json.loads(r.stdout)["disclosure"], sha256(text)

    def records(self, kind: str, account: str | None = None) -> list[tuple[int, str, Any]]:
        """[(ledger id, created, content)] in commit order; no committed schema means no records."""
        if not self.path.exists():
            return []
        with closing(sqlite3.connect(self.path)) as db:
            if not db.execute("SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = 'disclosures'").fetchone():
                return []
            rows = db.execute("SELECT id, created, content FROM disclosures WHERE campaign = ? AND kind = ? AND (? IS NULL OR agent = ?) "
                              "ORDER BY id", (self.track, kind, account, account)).fetchall()
        return [(i, c, json.loads(t)) for i, c, t in rows]

    def theses(self, account: str) -> list[Json]:
        return [c for _, _, c in self.records("thesis", account)]

    def exits(self, account: str) -> list[Json]:
        return [c for _, _, c in self.records("exit", account)]


def number(x: Any, lo: float, hi: float) -> bool:
    return type(x) in (int, float) and math.isfinite(x) and lo <= x <= hi


def validate(request: Any, disclosed: Collection[str]) -> list[str]:
    """Errors of a registration request's form (empty if valid); `disclosed` is the retrieval ids already disclosed to the
    session. Time, snapshot and venue checks live in `prerequisites` and `eligible`."""
    if not isinstance(request, dict) or set(request) != FIELDS:
        return [f"fields must be exactly {sorted(FIELDS)}"]
    errors = []
    rid, legs = request["request_id"], request["legs"]
    if not (isinstance(rid, str) and 1 <= len(rid) <= 64):
        errors.append("request_id: 1 to 64 characters")
    if not (isinstance(legs, list) and len(legs) in (1, 2) and all(
            isinstance(l, list) and len(l) == 2 and isinstance(l[0], str) and type(l[1]) is int and l[1] in (1, -1) for l in legs)):
        errors.append("legs: one [market, 1 | -1], or two distinct markets with weights 1 and -1")
    elif len(legs) == 2 and (legs[0][0] == legs[1][0] or sorted(l[1] for l in legs) != [-1, 1]):
        errors.append("legs: a spread is two distinct markets with weights 1 and -1")
    if not number(request["p"], 0.01, 0.99):
        errors.append("p: a finite number in [0.01, 0.99]")
    if not number(request["L"], 0.01, 0.5):
        errors.append("L: a finite number in [0.01, 0.5]")
    if not (type(request["T"]) is int and request["T"] % DAY == 0):
        errors.append("T: a UTC midnight")
    if not (isinstance(request["catalyst"], str) and 1 <= len(request["catalyst"]) <= 4000):
        errors.append("catalyst: 1 to 4000 characters")
    if not (isinstance(request["catalyst_id"], str) and 1 <= len(request["catalyst_id"]) <= 64):
        errors.append("catalyst_id: 1 to 64 characters")
    market = request["outcome_market"]
    if not (market is None or (isinstance(market, str) and market.isdigit() and len(market) <= 20)):
        errors.append("outcome_market: null, or the id of a Polymarket market (digits)")
    sources = request["sources"]
    if not (isinstance(sources, list) and all(isinstance(s, str) for s in sources)):
        errors.append("sources: a list of retrieval ids")
    elif not set(sources) <= set(disclosed):
        errors.append("sources: every id must be a retrieval already disclosed in this session")
    return errors


def prerequisites(request: Json, now: int, daily: Json) -> list[str]:
    """Snapshot/time refusals no later input fetch can cure; safe both before fetching and at commit."""
    errors = []
    for market, _ in request["legs"]:
        if len([t for t in daily.get(market, ()) if t + DAY <= now]) < MIN_DAILY_BARS:
            errors.append(f"legs: {market} has fewer than {MIN_DAILY_BARS} completed daily bars in the session snapshot")
    if request["T"] - now < 72 * HOUR:
        errors.append("T: 72 to 1440 hours after registration")
    return errors


def eligible(request: Json, t_r: int, listings: dict[str, bool], daily: Json) -> list[str]:
    """Errors at commit: fresh listings, snapshot prerequisites, and the upper horizon at the actual t_r."""
    errors = []
    for market, _ in request["legs"]:
        if market not in listings or listings[market]:
            errors.append(f"legs: {market} is not listed")
    errors.extend(prerequisites(request, t_r, daily))
    if request["T"] - t_r > 1440 * HOUR:
        errors.append("T: 72 to 1440 hours after registration")
    return errors


def markets_of(request: Any) -> list[str]:
    """The market names a registration request's legs give, however malformed the rest of it is."""
    legs = request.get("legs") if isinstance(request, dict) else None
    return [l[0] for l in legs if isinstance(l, list) and l and isinstance(l[0], str)] if isinstance(legs, list) else []


def committed(ledger: Ledger, account: str, request: Any, p_is_base_rate: bool = False) -> tuple[Json, None] | tuple[None, list[str]] | None:
    """A retry of a committed request id: (its thesis, None), or (None, errors) if the content differs; None for a new id."""
    if isinstance(request, dict) and isinstance(request.get("request_id"), str):
        for th in ledger.theses(account):
            if th["request_id"] == request["request_id"]:
                same = canonical({k: th[k] for k in FIELDS} | ({"p": None} if p_is_base_rate else {})) == canonical(request)
                return (th, None) if same else (None, ["request_id: already used with different content"])
    return None


def register(ledger: Ledger, account: str, session: str, request: Any, clock: Callable[[], int], disclosed: Collection[str], config: Json,
             data: Json, p_is_base_rate: bool = False, *, forecast_at: int | None = None,
             listings_at: int | None = None) -> tuple[Json, None] | tuple[None, list[str]]:
    """Validate, size and commit one thesis. Under the ledger's lock a retry returns what it `committed`; a well-formed new
    request has its markets' listings read (`data["listed"]`), t_r read from `clock` as that read returns, then is checked
    against them, sized (`positions.admit`), given its base rate and committed, so commit order is t_r order, slow inputs
    never backdate it, and a market delisted while they were prepared is refused. `data` (bars, funding, lag and the
    session's daily bars, read as of `data["cutoff"]`) is fetched before the call, so it holds nothing later than t_r. What
    is fixed here is recorded with the thesis: the listing read and its times, the data's cutoff, what sized it (each
    amount an exact rational's text), the fee and cost cells, the cost fallbacks, and p_ref with its window counts. With
    `p_is_base_rate` the request's p is null and p is that p_ref, or the thesis is refused for lacking one. Returns
    (thesis, None) or (None, errors). The deterministic benchmark alone supplies its approved fixed `forecast_at`;
    its actual receipt remains `registered_at`, distinct from the effective forecast/holding time `t_r`, and its listings
    are an archived observation, whose time `listings_at` is recorded as `listings_read`."""
    with ledger.lock:
        if (retry := committed(ledger, account, request, p_is_base_rate)) is not None:
            return retry
        if errors := validate({**request, "p": 0.5} if p_is_base_rate else request, disclosed):
            return None, errors
        read_from = clock()
        listings = data["listed"](markets_of(request))
        read_to = registered_at = clock()
        t_r = registered_at if forecast_at is None else forecast_at
        if errors := eligible(request, t_r, listings, data["daily"]):
            return None, errors
        existing = ledger.theses(account)
        markets = [m for m, _ in request["legs"]]
        th = {**request, "id": f"{account}-{len(existing) + 1}", "account": account, "session": session, "t_r": t_r,
              "registered_at": registered_at, "listings": listings, "listings_read": [read_from, read_to] if listings_at is None else [listings_at, listings_at], "cutoff": data["cutoff"],
              "fee": config["fee"], "costs": {m: config["costs"][m] for m in markets},
              "fallback_costs": sorted(set(config["fallback"]) & set(markets))}
        sizing = positions.admit(config["initial"], existing, ledger.exits(account), data, t_r, request["L"])
        th.update({k: str(v) if k in AMOUNTS else v for k, v in sizing.items()})
        p_ref, m, x = scoring.base_rate(th, data["daily"], data["funding"])
        th.update(p_ref=p_ref, base_windows=m, base_positive=x)
        if p_is_base_rate:
            if p_ref is None:
                return None, ["no base rate"]
            th["p"] = p_ref
        ledger.disclose("thesis", account, th)
    return th, None
