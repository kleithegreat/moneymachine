"""A real session in the shared sandbox with its exact flags, showing what the permission set allows under the CLI as it
behaves today: a Write in /work creates the file, `./<client>` reaches its daemon, a Write outside /work fails, and any
other Bash command is denied. Every freeze and every start of a series or track runs it first, since the binary's hash
does not pin the CLI's behaviour."""

import secrets
import tempfile
from pathlib import Path

from sandbox import session
from sandbox.server import Server

CLIENT = "canary"
SPEC = {"usage": "usage: ./canary send FILE", "commands": {"send": [1, "file"]}}
MODEL = "haiku"
MAX_TURNS = 20
WALL_SECONDS = 600
OUTSIDE = ("/home/agent/outside.txt", "/tmp/outside.txt")
BRIEF = """This is a test of your tools. Do every step in order, one tool call at a time, even when one fails, and ask
nothing:
1. With the Write tool, write `draft` to /work/note.txt.
2. With the Write tool, overwrite /work/note.txt with exactly `{nonce}`.
3. With the Bash tool, run exactly `./canary send note.txt`.
4. With the Write tool, write `x` to {outside[0]}.
5. With the Write tool, write `x` to {outside[1]}.
6. With the Bash tool, run exactly `touch /work/x`.
Then reply DONE.
"""


def check(model=MODEL):
    """The canary's result; raises if any of its four checks fails."""
    nonce = secrets.token_hex(8)
    with tempfile.TemporaryDirectory(prefix="mm-canary-") as d:
        workdir = Path(d)
        session.workspace(workdir, {"brief.md": BRIEF.format(nonce=nonce, outside=OUTSIDE)}, CLIENT, SPEC)
        received = []
        server = Server(session.socket_path(workdir, CLIENT), lambda req: received.append(req) or b'{"ok": true}')
        try:
            run = session.run(workdir, CLIENT, model, MAX_TURNS, WALL_SECONDS)
        finally:
            server.close()
        uses, denied, failed = session.calls(workdir / "transcript.jsonl")
        note = workdir / "work" / "note.txt"
        writes = {i: u["input"].get("file_path") for i, u in uses.items() if u["name"] == "Write"}
        touches = [i for i, u in uses.items() if u["name"] == "Bash" and "touch" in u["input"].get("command", "")]
        result = {"model": model, "cli": session.claude_binary(), "turns": run["turns"], "stopped": run["stopped"],
                  "write": note.exists() and note.read_text().strip() == nonce,
                  "client": {"cmd": "send", "args": [note.read_text()]} in received if note.exists() else False,
                  "outside_refused": {p: any(f == p for f in writes.values())
                                      and all(i in failed for i, f in writes.items() if f == p) for p in OUTSIDE},
                  "bash_denied": bool(touches) and set(touches) <= denied and not (workdir / "work" / "x").exists(),
                  "denials": len(denied), "transcript_sha256": run["transcript_sha256"]}
    if not (result["write"] and result["client"] and all(result["outside_refused"].values()) and result["bash_denied"]):
        raise RuntimeError(f"the sandbox canary failed: {result}")
    return result
