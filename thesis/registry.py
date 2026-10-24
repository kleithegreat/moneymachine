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
from pathlib import Path

from gate.kernel import command
from ingest.policy import DAY, HOUR
from thesis import positions

FIELDS = {"request_id", "legs", "T", "p", "L", "catalyst", "catalyst_id", "sources", "outcome_market"}
MIN_DAILY_BARS = 90


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def sha256(text):
    return hashlib.sha256(text.encode() if isinstance(text, str) else text).hexdigest()


class Ledger:
    def __init__(self, path, track):
        self.path, self.track = Path(path), track
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def disclose(self, kind, account, content):
        text = canonical(content)
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh:
            fh.write(text)
        try:
            r = subprocess.run(command("disclose", fh.name, self.track, account, self.path, None, "--kind", kind),
                               capture_output=True, text=True)
        finally:
            Path(fh.name).unlink()
        if r.returncode != 0:
            raise RuntimeError(f"ledger write failed: {r.stderr.strip()}")
        return json.loads(r.stdout)["disclosure"], sha256(text)

    def records(self, kind, account=None):
        """[(ledger id, created, content)] in commit order."""
        if not self.path.exists():
            return []
        db = sqlite3.connect(self.path)
        rows = db.execute("SELECT id, created, content FROM disclosures WHERE campaign = ? AND kind = ? AND (? IS NULL OR agent = ?) "
                          "ORDER BY id", (self.track, kind, account, account)).fetchall()
        return [(i, c, json.loads(t)) for i, c, t in rows]

    def theses(self, account):
        return [c for _, _, c in self.records("thesis", account)]

    def exits(self, account):
        return [c for _, _, c in self.records("exit", account)]


def number(x, lo, hi):
    return type(x) in (int, float) and math.isfinite(x) and lo <= x <= hi


def validate(request, t_r, listings, daily_bars, disclosed):
    """Errors for a registration request at t_r (empty if valid). `listings` is {market: delisted};
    `daily_bars(market)` the completed daily openTimes known at t_r; `disclosed` the retrieval ids
    already disclosed to the session."""
    if not isinstance(request, dict) or set(request) != FIELDS:
        return [f"fields must be exactly {sorted(FIELDS)}"]
    errors = []
    rid, legs = request["request_id"], request["legs"]
    if not (isinstance(rid, str) and 1 <= len(rid) <= 64):
        errors.append("request_id: 1 to 64 characters")
    shape_ok = isinstance(legs, list) and len(legs) in (1, 2) and all(
        isinstance(l, list) and len(l) == 2 and isinstance(l[0], str) and type(l[1]) is int and l[1] in (1, -1) for l in legs)
    if not shape_ok:
        errors.append("legs: one [market, 1 | -1], or two distinct markets with weights 1 and -1")
    elif len(legs) == 2 and (legs[0][0] == legs[1][0] or sorted(l[1] for l in legs) != [-1, 1]):
        errors.append("legs: a spread is two distinct markets with weights 1 and -1")
    else:
        for market, _ in legs:
            if market not in listings or listings[market]:
                errors.append(f"legs: {market} is not listed")
            elif len([t for t in daily_bars(market) if t + DAY <= t_r]) < MIN_DAILY_BARS:
                errors.append(f"legs: {market} has fewer than {MIN_DAILY_BARS} completed daily bars")
    T = request["T"]
    if not (type(T) is int and T % DAY == 0 and 72 * HOUR <= T - t_r <= 1440 * HOUR):
        errors.append("T: a UTC midnight, 72 to 1440 hours after registration")
    if not number(request["p"], 0.01, 0.99):
        errors.append("p: a finite number in [0.01, 0.99]")
    if not number(request["L"], 0.01, 0.5):
        errors.append("L: a finite number in [0.01, 0.5]")
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


def register(ledger, account, session, request, t_r, listings, daily_bars, disclosed, account_config, data):
    """Validate, size and commit one thesis; the caller serializes calls and supplies t_r from its clock.
    Returns (thesis, None) or (None, errors). A retry of a request id returns the original thesis."""
    existing = ledger.theses(account)
    if isinstance(request, dict) and isinstance(request.get("request_id"), str):
        for th in existing:
            if th["request_id"] == request["request_id"]:
                same = canonical({k: th[k] for k in FIELDS}) == canonical(request)
                return (th, None) if same else (None, ["request_id: already used with different content"])
    errors = validate(request, t_r, listings, daily_bars, disclosed)
    if errors:
        return None, errors
    th = {**request, "id": f"{account}-{len(existing) + 1}", "account": account, "session": session, "t_r": t_r}
    out = positions.run(account_config, existing + [th], ledger.exits(account), data, t_r)["theses"][th["id"]]
    th.update(N=out["N"], size=out["size"])
    ledger.disclose("thesis", account, th)
    return th, None
