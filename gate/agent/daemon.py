"""The mm-agent daemon: outside the sandbox, the only path from the research agent to the kernel.

It fixes the store, ledger, campaign and agent; enforces the evaluation budget; discloses only
FIELDS per evaluation (or a rejection code); and logs every call with its payload hash.
"""

import hashlib
import json
import socketserver
import subprocess
import tempfile
import threading
import time
from pathlib import Path

FIELDS = ("sharpe_annualized", "fills", "total_return", "max_drawdown")
MAX_REQUEST = 1 << 20
HISTORY_LIMIT = 20


class Swarm:
    """The swarm's shared, sequence-numbered record of every evaluation (stage 4)."""

    def __init__(self):
        self.lock = threading.Lock()
        self.records = []

    def add(self, record):
        with self.lock:
            self.records.append({"seq": len(self.records) + 1, **record})

    def snapshot(self):
        with self.lock:
            return list(self.records)


class Daemon:
    def __init__(self, socket_path, mm, market, ledger, campaign, agent, budget, log_path, swarm=None):
        self.socket_path, self.mm, self.market, self.ledger = Path(socket_path), str(mm), Path(market), Path(ledger)
        self.campaign, self.agent, self.budget, self.log_path = campaign, agent, budget, Path(log_path)
        self.spent = 0
        self.swarm, self.history_calls = swarm, 0
        self.lock = threading.Lock()
        self.evaluated = {}
        m = self.market
        self.common = ["--store", str(m / "store"), "--venue", str(m / "venue"), "--policy", str(m / "policy.json"),
                       "--ledger", str(self.ledger)]
        self.proc = subprocess.Popen([self.mm, "eval", "-", "--campaign", campaign, "--agent", agent, *self.common],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)

    def log(self, cmd, payload, response):
        with open(self.log_path, "a") as fh:
            fh.write(json.dumps({"t": time.time(), "cmd": cmd, "sha256": hashlib.sha256(payload.encode()).hexdigest(),
                                 "response": response}) + "\n")

    def eval(self, text):
        if self.spent >= self.budget:
            return {"ok": False, "code": "BUDGET", "message": f"all {self.budget} evaluations used"}
        self.spent += 1
        self.proc.stdin.write(text.replace("\r", " ").replace("\n", " ") + "\n")
        self.proc.stdin.flush()
        line = self.proc.stdout.readline()
        if not line:
            return {"ok": False, "code": "KERNEL", "message": "kernel stopped"}
        d = json.loads(line)
        if "disclosure" not in d:
            out = {"ok": False, "code": d.get("code"), "message": d.get("message", "")[:500]}
            if self.swarm:
                self.swarm.add({"agent": self.agent, "program": text, "code": out["code"]})
            return out
        self.evaluated[hashlib.sha256(text.encode()).hexdigest()] = d["disclosure"]["strategy"]
        r = d["disclosure"]["result"]
        fields = {k: r[k] for k in FIELDS}
        if self.swarm:
            self.swarm.add({"agent": self.agent, "equivalence": d["disclosure"]["equivalence"], "program": text, **fields})
        return {"ok": True, **fields, "remaining": self.budget - self.spent}

    def history(self):
        if self.swarm is None:
            return {"ok": False, "message": "no shared history in this campaign"}
        if self.history_calls >= HISTORY_LIMIT:
            return {"ok": False, "code": "HISTORY_LIMIT", "message": f"at most {HISTORY_LIMIT} history calls"}
        self.history_calls += 1
        records = self.swarm.snapshot()
        payload = {"ok": True, "through": records[-1]["seq"] if records else 0, "evaluations": records}
        with tempfile.NamedTemporaryFile("w", suffix=".json") as fh:
            fh.write(json.dumps(payload))
            fh.flush()
            subprocess.run([self.mm, "disclose", fh.name, "--campaign", self.campaign, "--agent", self.agent,
                            "--kind", "history", "--ledger", str(self.ledger)], check=True, capture_output=True)
        return payload

    def check(self, text):
        with tempfile.NamedTemporaryFile("w", suffix=".json") as fh:
            fh.write(text)
            fh.flush()
            out = subprocess.run([self.mm, "check", fh.name, "--campaign", self.campaign, "--agent", self.agent,
                                  "--ledger", str(self.ledger)], capture_output=True, text=True)
        line = (out.stdout or out.stderr).strip().splitlines()
        return json.loads(line[-1]) if line else {"ok": False, "code": "KERNEL"}

    def select(self, texts):
        hashes = [self.evaluated.get(hashlib.sha256(t.encode()).hexdigest()) for t in texts]
        if len(texts) > 10 or None in hashes:
            return {"ok": False, "message": "select at most 10 strategies, each already evaluated (same file content)"}
        for h in hashes:
            subprocess.run([self.mm, "select", h, "--campaign", self.campaign, "--agent", self.agent,
                            "--note", "agent selection", "--ledger", str(self.ledger)], check=True, capture_output=True)
        return {"ok": True, "selected": len(hashes)}

    def handle(self, req):
        cmd, texts = req.get("cmd"), req.get("programs", [])
        with self.lock:
            if cmd == "eval" and len(texts) == 1:
                out = self.eval(texts[0])
            elif cmd == "check" and len(texts) == 1:
                out = self.check(texts[0])
            elif cmd == "select":
                out = self.select(texts)
            elif cmd == "history":
                out = self.history()
            elif cmd == "budget":
                out = {"remaining": self.budget - self.spent}
            else:
                out = {"ok": False, "message": "bad request"}
            self.log(cmd, json.dumps(texts), out)
        return out

    def serve(self):
        daemon = self

        class Handler(socketserver.StreamRequestHandler):
            def handle(self):
                raw = self.rfile.readline(MAX_REQUEST)
                try:
                    out = daemon.handle(json.loads(raw))
                except (json.JSONDecodeError, AttributeError):
                    out = {"ok": False, "message": "bad request"}
                self.wfile.write(json.dumps(out).encode() + b"\n")

        self.socket_path.unlink(missing_ok=True)
        self.server = socketserver.ThreadingUnixStreamServer(str(self.socket_path), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        return self

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.proc.stdin.close()
        self.proc.wait()
        self.socket_path.unlink(missing_ok=True)
