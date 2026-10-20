"""The thesis daemon: outside the sandbox, the only path from a thesis agent to markets, the web and the
ledger (PROGRESS.md, Stage 10).

Every call, rejected and failed ones included, is written to the ledger as a `call` record with the
sha256 of the exact response bytes, which are stored under `responses/`, before the bytes are
released. The daemon's clock sets every time; requests carry none.
"""

import json
import socketserver
import threading
from pathlib import Path

from ingest.live import now_ms
from thesis import registry

MAX_REQUEST = 1 << 20
MAX_REGISTRATIONS = 2


class Daemon:
    """One session's daemon. `snapshot` is the pre-session market snapshot: {"taken", "markets":
    {market: {"last_close", "t"}}, "daily": {market: [[t, open, close]]}, "listings"}. `positions(account, now)`
    replays an account; `register_inputs(account, markets, t_r)` gives (config, data) for admission."""

    def __init__(self, socket_path, session, account, ledger, snapshot, fetcher, responses, positions, register_inputs,
                 commands, clock=now_ms, ablation_of=None):
        self.socket_path, self.session, self.account, self.ledger = Path(socket_path), session, account, ledger
        self.snapshot, self.fetcher, self.responses = snapshot, fetcher, Path(responses)
        self.positions, self.register_inputs, self.commands, self.clock = positions, register_inputs, set(commands), clock
        self.responses.mkdir(parents=True, exist_ok=True)
        self.lock = threading.Lock()
        self.seq = 0
        self.retrievals = set()
        self.registered = 0
        self.ablation_of, self.forecasted = ablation_of, False

    def markets(self, args):
        return {"ok": True, "taken": self.snapshot["taken"], "markets": self.snapshot["markets"]}

    def prices(self, args):
        if len(args) != 1 or args[0] not in self.snapshot["markets"]:
            return {"ok": False, "message": "prices MARKET, for a market listed by `markets`"}
        return {"ok": True, "market": args[0], "daily": self.snapshot["daily"][args[0]]}

    def fetch(self, args):
        if len(args) != 1:
            return {"ok": False, "message": "fetch URL"}
        r = self.fetcher.fetch(args[0])
        if "refused" in r:
            return {"ok": False, "message": r["refused"], "record": {k: r[k] for k in ("url", "final_url", "redirects", "started", "ended")}}
        rid = f"{self.session}-f{len(self.retrievals) + 1}"
        self.retrievals.add(rid)
        record = {k: r[k] for k in ("url", "final_url", "redirects", "status", "content_type", "truncated", "started", "ended")}
        record["body_sha256"] = registry.sha256(r["body"])
        return {"ok": True, "retrieval_id": rid, **record, "text": r["body"].decode("utf-8", "replace"), "record": record}

    def register(self, args):
        if len(args) != 1:
            return {"ok": False, "message": "register FILE"}
        if self.registered >= MAX_REGISTRATIONS:
            return {"ok": False, "message": f"at most {MAX_REGISTRATIONS} registrations per session"}
        try:
            request = json.loads(args[0])
        except json.JSONDecodeError as e:
            return {"ok": False, "message": f"not JSON: {e}"}
        t_r = self.clock()
        markets = [l[0] for l in request.get("legs", []) if isinstance(l, list) and l and isinstance(l[0], str)] \
            if isinstance(request, dict) and isinstance(request.get("legs"), list) else []
        config, data = self.register_inputs(self.account, markets, t_r)
        daily = lambda m: [row[0] for row in self.snapshot["daily"].get(m, [])]
        th, errors = registry.register(self.ledger, self.account, self.session, request, t_r, self.snapshot["listings"],
                                       daily, self.retrievals, config, data)
        if errors:
            return {"ok": False, "errors": errors}
        if th["t_r"] == t_r:
            self.registered += 1
        return {"ok": True, "thesis": th}

    def open_positions(self, args):
        return {"ok": True, **self.positions(self.account, self.clock())}

    def exit(self, args):
        if len(args) != 2:
            return {"ok": False, "message": "exit ID REASON"}
        state = self.positions(self.account, self.clock())["theses"].get(args[0])
        if state is None or state["size"] == 0 or state["exit"] is not None:
            return {"ok": False, "message": f"{args[0]} is not an open position of this account"}
        t_x = self.clock()
        self.ledger.disclose("exit", self.account, {"id": args[0], "t_x": t_x, "reason": args[1], "session": self.session})
        return {"ok": True, "id": args[0], "t_x": t_x}

    def forecast(self, args):
        try:
            p = float(args[0]) if len(args) == 1 else None
        except ValueError:
            p = None
        if self.ablation_of is None or self.forecasted or not registry.number(p, 0.01, 0.99):
            return {"ok": False, "message": "forecast P, once, with P in [0.01, 0.99]"}
        self.forecasted = True
        self.ledger.disclose("ablation", self.account, {"thesis": self.ablation_of, "p": p, "session": self.session})
        return {"ok": True, "thesis": self.ablation_of, "p": p}

    COMMANDS = {"markets": markets, "prices": prices, "fetch": fetch, "register": register, "positions": open_positions,
                "exit": exit, "forecast": forecast}

    def handle(self, req):
        with self.lock:
            self.seq += 1
            t = self.clock()
            cmd = req.get("cmd") if isinstance(req, dict) else None
            args = req.get("args", []) if isinstance(req, dict) else []
            if cmd not in self.commands or not isinstance(args, list) or not all(isinstance(a, str) for a in args):
                out = {"ok": False, "message": f"commands: {', '.join(sorted(self.commands))}"}
            else:
                try:
                    out = self.COMMANDS[cmd](self, args)
                except Exception as e:
                    out = {"ok": False, "message": f"daemon error: {type(e).__name__}"}
            record = out.pop("record", None)
            body = registry.canonical(out).encode()
            digest = registry.sha256(body)
            (self.responses / f"{digest}.json").write_bytes(body)
            self.ledger.disclose("call", self.account, {"session": self.session, "seq": self.seq, "t": t,
                                                        "request": req if isinstance(req, dict) else str(req),
                                                        "ok": out.get("ok", False), "response_sha256": digest,
                                                        **({"fetch": record} if record else {})})
            return body

    def serve(self):
        daemon = self

        class Handler(socketserver.StreamRequestHandler):
            def handle(self):
                raw = self.rfile.readline(MAX_REQUEST)
                try:
                    req = json.loads(raw)
                except json.JSONDecodeError:
                    req = {"cmd": None, "raw": raw[:200].decode("utf-8", "replace")}
                self.wfile.write(daemon.handle(req) + b"\n")

        self.socket_path.unlink(missing_ok=True)
        self.server = socketserver.ThreadingUnixStreamServer(str(self.socket_path), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        return self

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.socket_path.unlink(missing_ok=True)
