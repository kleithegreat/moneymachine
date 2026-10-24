"""Agent sessions in a bubblewrap sandbox, shared by the research agents (gate/agent) and the thesis agents
(thesis/). A track supplies its files, its tool's command spec, its daemon and its limits.

A session's directory holds `work` (the workspace, /work), `tool` (read-only at /tool: the client, the egress relay
and both sockets; a link to a short temporary path, since a socket's path is limited to 107 bytes) and `home` (/home/agent, holding only a copy of the CLI credentials). Inside the sandbox: those,
the Nix store paths the CLI, Python and coreutils need, read-only, and a minimal /etc. No repo, no data/, no ledger,
no real HOME, no host environment, and no network but `egress.py`'s relay to the hosts in HOSTS. The agent's tools
are Read and Write in the workspace and Bash for `./<client>` only, a read-only mount whose Python ignores the
workspace's modules; no MCP servers, no setting sources, no web tools.
"""

import functools
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

from sandbox.egress import Proxy

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
FILES = (HERE / "session.py", HERE / "server.py", HERE / "client.py", HERE / "egress.py")
PROMPT = "Read brief.md in this directory and do exactly what it says."
PERMITTED = {"Read", "Write", "Bash"}
HOSTS = ("api.anthropic.com",)
ETC = {"passwd": "agent:x:1000:100::/home/agent:/bin/sh\n", "group": "users:x:100:\n",
       "nsswitch.conf": "passwd: files\ngroup: files\nhosts: files\n"}


def tools(client):
    return ["--tools", "Read,Write,Bash",
            "--allowedTools", f"Bash(./{client}:*)", "Read(//work/**)", "Write(//work/**)",
            "--disallowedTools", "WebFetch", "WebSearch", "Edit", "Glob", "Grep", "Task", "NotebookEdit",
            "--permission-mode", "dontAsk", "--strict-mcp-config", "--setting-sources", "", "--no-session-persistence"]


def claude_binary():
    return str(Path(shutil.which("claude")).resolve())


def socket_path(workdir, client):
    """The daemon's socket for a session in `workdir`."""
    return (Path(workdir) / "tool").resolve() / f"{client}.sock"


def workspace(workdir, files, client, spec):
    """`workdir`/work holding `files` ({name in the workspace: text}), `workdir`/tool holding the client configured by
    `spec` and the egress relay, and `workdir`/home holding a copy of the CLI credentials."""
    workdir = Path(workdir)
    work, tool, home = workdir / "work", Path(tempfile.mkdtemp(prefix="mm-tool-")), workdir / "home"
    for d in (work, home / ".claude", workdir / "etc"):
        d.mkdir(parents=True)
    (workdir / "tool").symlink_to(tool)
    for name, text in files.items():
        (work / name).write_text(text)
    (tool / client).write_text(f"#!{sys.executable} -I\nSPEC = {json.dumps(spec | {'socket': f'/tool/{client}.sock'})}\n"
                               + (HERE / "client.py").read_text())
    os.chmod(tool / client, 0o755)
    shutil.copy(HERE / "egress.py", tool / "egress.py")
    for name, text in ETC.items():
        (workdir / "etc" / name).write_text(text)
    creds = home / ".claude" / ".credentials.json"
    shutil.copy(Path.home() / ".claude" / ".credentials.json", creds)
    os.chmod(creds, 0o600)


@functools.cache
def store_paths():
    """The closure of the CLI, Python, coreutils and /bin/sh in the Nix store."""
    roots = [claude_binary(), sys.executable, shutil.which("ls"), "/bin/sh", "/usr/bin/env"]
    out = subprocess.run(["nix-store", "-qR", *{os.path.realpath(r) for r in roots}], check=True, capture_output=True,
                         text=True).stdout
    return sorted(set(out.split()))


def sandbox_path():
    """Python and coreutils from the Nix store; which commands run is decided by the tool permissions."""
    coreutils = os.path.dirname(os.path.realpath(shutil.which("ls")))
    return ":".join([os.path.dirname(sys.executable), coreutils, "/bin", "/usr/bin"])


def sandbox_command(workdir, client, argv):
    workdir = Path(workdir)
    tool = (workdir / "tool").resolve()
    binds = [a for p in store_paths() for a in ("--ro-bind", p, p)]
    binds += [a for name in ETC for a in ("--ro-bind", str(workdir / "etc" / name), f"/etc/{name}")]
    return ["bwrap", "--unshare-all", "--die-with-parent", "--new-session", "--clearenv", *binds,
            "--ro-bind", "/bin", "/bin", "--ro-bind", "/usr", "/usr", "--proc", "/proc", "--dev", "/dev", "--tmpfs", "/tmp",
            "--bind", str(workdir / "home"), "/home/agent", "--bind", str(workdir / "work"), "/work",
            "--ro-bind", str(tool), "/tool", "--ro-bind", str(tool / client), f"/work/{client}",
            "--setenv", "HOME", "/home/agent", "--setenv", "PATH", sandbox_path(),
            "--setenv", "SHELL", str(Path(os.path.realpath("/bin/sh")).parent / "bash"),
            "--setenv", "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC", "1",
            "--chdir", "/work", sys.executable, "-I", "/tool/egress.py", "/tool/egress.sock", *argv]


def run(workdir, client, model, max_turns, wall_seconds, prompt=PROMPT):
    """The agent's session, stopped at `max_turns` assistant turns or `wall_seconds`, whether or not it is printing;
    the private HOME and the tool directory are removed."""
    workdir = Path(workdir)
    argv = [claude_binary(), "-p", prompt, "--model", model, "--output-format", "stream-json", "--verbose", *tools(client)]
    transcript = workdir / "transcript.jsonl"
    proxy = Proxy((workdir / "tool").resolve() / "egress.sock", HOSTS, workdir / "egress.log")
    turns, started, stopped = 0, time.time(), "finished"
    with open(transcript, "w") as out:
        proc = subprocess.Popen(sandbox_command(workdir, client, argv), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
        expired = threading.Event()
        timer = threading.Timer(wall_seconds, lambda: (expired.set(), proc.kill()))
        timer.start()
        for line in proc.stdout:
            out.write(line)
            try:
                turns += json.loads(line).get("type") == "assistant"
            except json.JSONDecodeError:
                pass
            if turns > max_turns:
                stopped = "turn limit"
                proc.kill()
                break
        proc.wait()
        timer.cancel()
    proxy.close()
    stopped = "wall time" if expired.is_set() else stopped
    shutil.rmtree(workdir / "home")
    shutil.rmtree((workdir / "tool").resolve())
    return {"turns": turns, "stopped": stopped, "exit": proc.returncode, "seconds": round(time.time() - started),
            "transcript_sha256": hashlib.sha256(transcript.read_bytes()).hexdigest()}


def tool_use(transcript, client):
    """The tools a transcript used, its calls of `./<client>`, those outside PERMITTED, and its permission denials."""
    tools_, calls, denied = [], 0, []
    for line in open(transcript):
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if d.get("type") == "assistant":
            for c in d["message"]["content"]:
                if c.get("type") == "tool_use":
                    tools_.append(c["name"])
                    calls += c["name"] == "Bash" and f"./{client}" in c.get("input", {}).get("command", "")
        if d.get("type") == "result":
            denied = d.get("permission_denials", [])
    return {"tools": sorted(set(tools_)), "client_calls": calls, "outside_permitted": sorted(set(tools_) - PERMITTED),
            "denials": len(denied)}


def identity(files, extra):
    """sha256 of `files` (paths; this package's are always included) and the JSON of `extra`."""
    h = hashlib.sha256()
    for f in [*files, *FILES]:
        h.update(str(Path(f).resolve().relative_to(REPO)).encode() + b"\0" + Path(f).read_bytes())
    h.update(json.dumps(extra).encode())
    return h.hexdigest()
