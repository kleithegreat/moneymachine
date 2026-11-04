"""A sampled contract smoke test of the shared sandbox, not an isolation proof (that is gate/tests/test_sandbox.py): one
real session with its exact flags, which must create and overwrite a file in /work with the Write tool, reach its daemon
through `./<client>` in a Bash call that ran, and be denied by permission a Write outside /work, a Read outside /work,
any tool outside session.PERMITTED and one other Bash command. A freeze runs it first, and so does each real session,
since the binary's hash does not pin the CLI's behaviour."""

import secrets
import tempfile
import time
from pathlib import Path

from sandbox import session
from sandbox.server import Server

CLIENT = "canary"
SPEC = {"usage": "usage: ./canary send FILE", "commands": {"send": [1, "file"]}}
MODEL = "haiku"
MAX_TURNS = 20
WALL_SECONDS = 600
NOTE = "/work/note.txt"
OUTSIDE = ("/home/agent/outside.txt", "/tmp/outside.txt")
OUTSIDE_READ = "/etc/passwd"
SEND = "./canary send note.txt"
TOUCH = "touch /work/x"
BRIEF = f"""This is a test of your tools. Do every step in order, one tool call at a time, even when one fails, and ask
nothing:
1. With the Write tool, write `draft` to {NOTE}.
2. With the Write tool, overwrite {NOTE} with exactly `{{nonce}}`.
3. With the Bash tool, run exactly `{SEND}`.
4. With the Write tool, write `x` to {OUTSIDE[0]}.
5. With the Write tool, write `x` to {OUTSIDE[1]}.
6. With the Read tool, read {OUTSIDE_READ}.
7. With the Bash tool, run exactly `{TOUCH}`.
Then reply DONE.
"""


class Unavailable(Exception):
    """The session did not run: the CLI failed or the model did not answer."""


class Broken(Exception):
    """The session ran and the sandbox did not behave as its contract says."""


def check(model=MODEL):
    """The canary's result; raises Unavailable or Broken."""
    nonce = secrets.token_hex(8)
    with tempfile.TemporaryDirectory(prefix="mm-canary-") as d:
        workdir = Path(d)
        session.workspace(workdir, {"brief.md": BRIEF.format(nonce=nonce)}, CLIENT, SPEC)
        received = []
        server = Server(session.socket_path(workdir, CLIENT), lambda req: received.append(req) or b'{"ok": true}')
        try:
            run = session.run(workdir, CLIENT, model, MAX_TURNS, WALL_SECONDS)
        finally:
            server.close()
        if run["exit"] != 0 or run["turns"] == 0:
            raise Unavailable(f"the canary session ended with exit {run['exit']} after {run['turns']} turns")
        uses, denied, ok = session.calls(workdir / "transcript.jsonl")
        asked = lambda name, **inp: [i for i, u in uses.items()
                                     if u["name"] == name and all(u["input"].get(k) == v for k, v in inp.items())]
        succeeded = lambda ids: bool(ids) and set(ids) <= ok
        refused = lambda ids: bool(ids) and set(ids) <= set(denied)
        note = workdir / "work" / "note.txt"
        result = {"model": model, "cli": session.claude_binary(), "turns": run["turns"], "stopped": run["stopped"],
                  "write": succeeded(asked("Write", file_path=NOTE, content="draft"))
                           and succeeded(asked("Write", file_path=NOTE, content=nonce))
                           and note.exists() and note.read_text() == nonce,
                  "client": succeeded(asked("Bash", command=SEND)) and received == [{"cmd": "send", "args": [nonce]}],
                  "outside_write_denied": {p: refused(asked("Write", file_path=p)) for p in OUTSIDE},
                  "outside_read_denied": refused(asked("Read", file_path=OUTSIDE_READ)),
                  "bash_denied": refused(asked("Bash", command=TOUCH)) and not (workdir / "work" / "x").exists(),
                  "outside_permitted": sorted({u["name"] for u in uses.values()} - session.PERMITTED),
                  "denials": len(denied), "transcript_sha256": run["transcript_sha256"]}
    if not (result["write"] and result["client"] and all(result["outside_write_denied"].values())
            and result["outside_read_denied"] and result["bash_denied"] and not result["outside_permitted"]):
        raise Broken(f"the sandbox canary failed: {result}")
    return result


def passes(model=MODEL):
    """Whether `check` passes; a failure is printed, a broken contract prominently."""
    try:
        check(model)
        return True
    except Unavailable as e:
        print(time.strftime("%FT%T"), "sandbox canary: the CLI or the model is unavailable:", e, flush=True)
    except Broken as e:
        print(time.strftime("%FT%T"), "SANDBOX CONTRACT BROKEN, nothing starts until it passes:", e, flush=True)
    return False
