"""Agent sessions in a bubblewrap sandbox, shared by the research agents (gate/agent) and the thesis agents
(thesis/). A track supplies its files, its tool's command spec, its daemon and its limits.

Inside the sandbox: the Nix store, a minimal /etc, /bin and /usr read-only, the workspace (/work) and a private
HOME (/home/agent, holding only a copy of the CLI credentials). No repo, no data/, no ledger, no real HOME. The
agent's tools are Read and Write in the workspace and Bash for its one client only, with no MCP servers, no
setting sources and no web tools.
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
FILES = (HERE / "session.py", HERE / "server.py", HERE / "client.py")
PROMPT = "Read brief.md in this directory and do exactly what it says."
PERMITTED = {"Read", "Write", "Bash"}
ETC = ("resolv.conf", "hosts", "passwd", "group", "localtime", "ssl", "static")


def tools(client):
    return ["--tools", "Read,Write,Bash",
            "--allowedTools", f"Bash(./{client}:*)", "Read(//work/**)", "Write(//work/**)",
            "--disallowedTools", "WebFetch", "WebSearch", "Edit", "Glob", "Grep", "Task", "NotebookEdit",
            "--permission-mode", "dontAsk", "--strict-mcp-config", "--setting-sources", "", "--no-session-persistence"]


def claude_binary():
    return str(Path(shutil.which("claude")).resolve())


def workspace(workdir, files, client, spec):
    """`workdir`/work holding `files` ({name in the workspace: text}) and `./<client>` configured by `spec`, and
    `workdir`/home holding a copy of the CLI credentials."""
    work, home = Path(workdir) / "work", Path(workdir) / "home"
    (home / ".claude").mkdir(parents=True)
    work.mkdir(parents=True)
    for name, text in files.items():
        (work / name).write_text(text)
    (work / client).write_text(f"#!{sys.executable}\nSPEC = {json.dumps(spec | {'socket': f'{client}.sock'})}\n"
                               + (HERE / "client.py").read_text())
    os.chmod(work / client, 0o755)
    creds = home / ".claude" / ".credentials.json"
    shutil.copy(Path.home() / ".claude" / ".credentials.json", creds)
    os.chmod(creds, 0o600)
    return work, home


def sandbox_path():
    """Python and coreutils from the Nix store; which commands run is decided by the tool permissions."""
    coreutils = os.path.dirname(os.path.realpath(shutil.which("ls")))
    return ":".join([os.path.dirname(sys.executable), coreutils, "/bin", "/usr/bin"])


def sandbox_command(work, home, argv):
    """A fresh /etc holding only what the CLI needs. The host's nsswitch resolves through
    systemd-resolved's socket under /run, which is not mounted, so the sandbox gets plain DNS (the
    resolver stub is reachable on the shared network)."""
    nss = Path(home).parent / "nsswitch.conf"
    nss.write_text("passwd: files\ngroup: files\nhosts: files dns\n")
    etc = []
    for name in ETC:
        if os.path.exists(f"/etc/{name}"):
            etc += ["--ro-bind", os.path.realpath(f"/etc/{name}"), f"/etc/{name}"]
    return ["bwrap", "--unshare-all", "--share-net", "--die-with-parent", "--new-session",
            "--ro-bind", "/nix", "/nix", "--tmpfs", "/etc", *etc, "--ro-bind", str(nss), "/etc/nsswitch.conf",
            "--ro-bind", "/bin", "/bin", "--ro-bind", "/usr", "/usr", "--proc", "/proc", "--dev", "/dev", "--tmpfs", "/tmp",
            "--bind", str(home), "/home/agent", "--bind", str(work), "/work",
            "--setenv", "HOME", "/home/agent", "--setenv", "PATH", sandbox_path(),
            "--chdir", "/work", *argv]


def run(workdir, work, home, client, model, max_turns, wall_seconds, prompt=PROMPT):
    """The agent's session, stopped at `max_turns` assistant turns or `wall_seconds`; the private HOME is removed."""
    argv = [claude_binary(), "-p", prompt, "--model", model, "--output-format", "stream-json", "--verbose", *tools(client)]
    transcript = Path(workdir) / "transcript.jsonl"
    turns, started, stopped = 0, time.time(), "finished"
    with open(transcript, "w") as out:
        proc = subprocess.Popen(sandbox_command(work, home, argv), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
        for line in proc.stdout:
            out.write(line)
            try:
                turns += json.loads(line).get("type") == "assistant"
            except json.JSONDecodeError:
                pass
            if turns > max_turns or time.time() - started > wall_seconds:
                stopped = "turn limit" if turns > max_turns else "wall time"
                proc.kill()
                break
        proc.wait()
    shutil.rmtree(home)
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
