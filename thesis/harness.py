"""Thesis agent sessions in the shared sandbox (`sandbox/`; audit/criteria.md, stage 10). The workspace holds only
the session's brief, its task file (for an ablation) and `./thesis-agent`."""

import functools
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

from ingest import terms
from sandbox import session
from thesis.daemon import SPEC

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
MODEL = "claude-opus-5-5"
MAX_TURNS = 100
WALL_SECONDS = 3600
CLIENT = "thesis-agent"
BRIEFS = {"main": "brief.md", "noread": "brief-noread.md", "ablation": "brief-ablation.md"}
BRIEF_TEXT = {kind: (HERE / name).read_text() for kind, name in BRIEFS.items()}
DATA = ("policy.json", "venue/hyperliquid/rules.json", "venue/hyperliquid/execution.json",
        "thesis/SCORING.md", "flake.lock", "kernel/Cargo.lock")


@functools.cache
def manifest_files(kernel):
    """Every repo module the runner and the report load (in a fresh interpreter, so the caller's imports do not
    matter), the track's pinned kernel binary `kernel` (it writes the ledger), the briefs and the data files the track
    reads."""
    loaded = subprocess.run([sys.executable, "-c", "import sys, thesis.runner, thesis.report; print(*sorted({m.__file__ "
                             "for m in list(sys.modules.values()) if getattr(m, '__file__', None)}), sep='\\n')"],
                            cwd=REPO, capture_output=True, text=True, check=True).stdout.splitlines()
    code = sorted(p.resolve() for p in map(Path, loaded) if p.resolve().is_relative_to(REPO))
    return code + [Path(kernel)] + [HERE / n for n in BRIEFS.values()] + [REPO / f for f in DATA]


@functools.cache
def manifest_hash(kernel):
    """The track version's identity: its files, the `claude` build (its store path), model, limits and flags, and the
    retrieval allowlist it reads from the source registry (not the registry's other records), hashed once per process,
    as the track reads them once."""
    return session.identity(manifest_files(kernel), [MODEL, MAX_TURNS, WALL_SECONDS, session.PROMPT, session.tools(CLIENT), BRIEFS,
                                                    sorted(terms.allowlist(retrieval=True)), session.claude_binary()])


def workspace(workdir, kind, task=None):
    files = {"brief.md": BRIEF_TEXT[kind]}
    if task is not None:
        files["task.json"] = json.dumps(task, indent=1)
    session.workspace(workdir, files, CLIENT, SPEC)


def run_session(workdir, kind, start_daemon, task=None):
    """Run one session; `start_daemon(socket_path)` returns the session's serving daemon, closed however the session ends."""
    workspace(workdir, kind, task)
    daemon = start_daemon(session.socket_path(workdir, CLIENT))
    try:
        s = session.run(workdir, CLIENT, MODEL, MAX_TURNS, WALL_SECONDS)
    finally:
        daemon.close()
    return {"kind": kind, **s}


def invocations(command):
    """The `./thesis-agent` calls in a Bash command: each one's arguments, up to the next shell operator."""
    lexer = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        tokens = command.split()
    calls = []
    for i, token in enumerate(tokens):
        if token == f"./{CLIENT}":
            end = next((j for j in range(i + 1, len(tokens)) if set(tokens[j]) <= set(";&|<>()")), len(tokens))
            args = tokens[i + 1:end]
            if end < len(tokens) and tokens[end][0] in "<>" and args and args[-1].isdigit():
                args.pop()
            calls.append(args)
    return calls


def results(transcript):
    """{tool call id: (the text of its result, whether it is an error)} in a transcript."""
    out = {}
    for line in open(transcript):
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        content = d.get("message", {}).get("content") if d.get("type") == "user" else None
        for c in content if isinstance(content, list) else []:
            if c.get("type") == "tool_result":
                body = c.get("content")
                out[c["tool_use_id"]] = (body if isinstance(body, str) else "".join(b.get("text", "") for b in body or []),
                                         bool(c.get("is_error")))
    return out


def client_refusal(output, is_error):
    """Whether a Bash result is exactly the client's own refusal, which no daemon reply resembles (a call that reached the
    daemon exits 0): Claude Code records a nonzero exit as "Exit code N\n<output>" with is_error, and the output is the
    usage line (an unknown command or a wrong number of arguments) or one {"ok": false, "error": text} (an unreadable FILE)."""
    m = re.fullmatch(r"Exit code ([1-9]\d*)\n(.*)", output, re.S)
    if not is_error or m is None:
        return False
    body = m[2].strip()
    try:
        reply = json.loads(body)
    except json.JSONDecodeError:
        return body == SPEC["usage"]
    return isinstance(reply, dict) and reply.keys() == {"ok", "error"} and reply["ok"] is False and isinstance(reply["error"], str)


def audit(transcript, calls):
    """C10.2's per-session mapping: every client call in the transcript that reached the daemon to its own daemon call record,
    by command and arguments (a FILE argument by its count; an argument with a shell expansion matches any), and each record
    to a call. A call is refused locally, and not sent, only when it is the sole client call of its Bash command and the result
    is `client_refusal`; every other call is sent, so one the transcript cannot attribute (a loop, a script, a refusal beside
    other calls) reads as unmatched. The tools outside the permitted set are listed."""
    uses, denied, _ = session.calls(transcript)
    outputs = results(transcript)
    sent, refused = [], 0
    for i, u in uses.items():
        if u["name"] == "Bash" and i not in denied:
            argvs = invocations(u["input"].get("command", ""))
            if len(argvs) == 1 and client_refusal(*outputs.get(i, ("", False))):
                refused += 1
            else:
                sent += argvs
    records = [(c["request"].get("cmd"), c["request"].get("args", [])) for c in calls]

    def fits(argv, record):
        (cmd, args), spec = record, SPEC["commands"].get(argv[0], [])
        return argv[0] == cmd and (len(argv) == len(args) + 1 if "file" in spec else
                                   all(a == b or any(ch in a for ch in "$`") for a, b in zip(argv[1:], args)))

    free = list(records)
    unmatched = []
    for argv in sorted(sent, key=lambda a: any(ch in "".join(a) for ch in "$`")):
        hit = next((r for r in free if fits(argv, r)), None)
        free.remove(hit) if hit is not None else unmatched.append(argv)
    return {"client_calls": len(sent) + refused, "refused_locally": refused, "daemon_calls": len(calls),
            "unmatched_client_calls": len(unmatched), "unmatched_daemon_calls": len(free),
            "match": not unmatched and not free, "outside_permitted": session.tool_use(transcript, CLIENT)["outside_permitted"]}
