"""Fakes and a reference for study 1's steps 7 to 9 (audit/program/briefs/1-positive-control.md at ce7ff38), written
from the plan before the code. Nothing here runs an agent session, the kernel or an account check.

The interfaces these fakes stand in for are stated in `test_runner.py`, `test_manifest.py` and `test_report.py`. In
short, the runner takes six injected effects, each defaulting to the real one:
- `verify() -> manifest`: `manifest.verify`, which raises before the runner does anything else;
- `room() -> object | None`: pacing on the TAMU and Cornell accounts (`wait_for_room`); None ends the runner;
- `market(root, market_id, strength) -> Path`: `pairs.write_market`;
- `session(market, ledger, campaign, workdir) -> run record`: `harness.run_agent`, which streams the transcript to
  `workdir/transcript.jsonl` and, at a designed end or a crash, writes the run record to `workdir/run.json` before it
  returns;
- `spent(ledger, campaign, workdir) -> int`: `campaigns.evaluations_made`, the session's evaluations;
- `judge(market_id, strength, ledger) -> judgement`: the pick (step 3) of agent "A" in campaign `market_id`,
  classified on the market's fresh pairs (steps 1, 2): {"pick", "reads", "pairs_won", "reference_median",
  "pick_median", "earns"}.

A fake session writes its transcript and a ledger that is a JSON file naming the session, its scripted kind and its
evaluations, before it can be killed; only the fake `spent` and `judge` read the ledger. A session of a kind with a
late commit also starts a stand-in for the daemon's kernel process (`mm eval -`): a separate process whose command
line names the ledger, which writes the session's last evaluation into it after a delay and exits, whether or not
the runner that started it is still alive. A session that is not killed waits for it, as `Daemon.close` does.

Every fake call appends one line to `ctl/calls.log` with the size and hash of `results.jsonl` at that moment. A kill
point `(kind, n)` makes the n-th call of that kind (counted over every restart) SIGKILL the process that runs the
code under test, and itself.

The kinds of session follow the pilot's record (`audit/decisions.md`, 2026-11-12 15:23 UTC): of 169 sessions, 109
were answered by `claude-opus-4-8` with one `model_refusal_fallback` line written after the responses it explains,
3 of those after one `claude-opus-5-5` response, and the rest by `claude-opus-5-5` throughout."""

import copy
import hashlib
import json
import multiprocessing
import os
import signal
import subprocess
import time
import traceback
from collections.abc import Callable, Collection, Iterable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from gate.agent.campaigns import crashed
from gate.control.constants import MAX_MARKETS
from gate.control.sequential import decide, outcome

Record = dict[str, Any]

ASKED = "claude-opus-5-5"
FALLBACK = "claude-opus-4-8"
SERVED = (ASKED, FALLBACK)
NOTICE = "<synthetic>"
FOREIGN = "claude-other-9-9"
STRENGTH = 0.004
SEED = "control-1-test-seed"
IDS = [f"control-1-m{i:03d}" for i in range(MAX_MARKETS)]
ENDING_DECISIONS = ("claim", "futility", "undecided")
ENDING_STATES = ("ended early",)
STOPPED = 4
MARKET_KEYS = (
    "id",
    "run",
    "models",
    "is_agent",
    "evaluations",
    "ended",
    "pick",
    "agent_earns",
    "searcher_earns",
    "outcome",
    "running_wins",
    "running_losses",
    "decision",
)
PICK_KEYS = ("reads", "pairs_won", "reference_median", "pick_median")


@dataclass(frozen=True)
class Kind:
    stopped: str
    exit: int
    evaluations: int
    earns: bool
    answers: tuple[str, ...]
    event_at: int | None
    late: float = 0.0


KINDS = {
    "earn": Kind("finished", 0, 6, True, (ASKED,) * 3, None),
    "miss": Kind("finished", 0, 6, False, (ASKED,) * 3, None),
    "nopick": Kind("finished", 0, 0, False, (ASKED,) * 2, None),
    "turns": Kind("turn limit", -9, 9, True, (ASKED,) * 4, None),
    "wall": Kind("wall time", -9, 9, False, (ASKED,) * 4, None),
    "crash": Kind("finished", 1, 4, True, (ASKED,) * 2, None),
    "signal": Kind("finished", -15, 4, False, (ASKED,) * 2, None),
    "empty": Kind("finished", 1, 0, False, (ASKED,), None),
    "fallback": Kind("finished", 0, 6, True, (FALLBACK,) * 3, 2),
    "mixed": Kind("finished", 0, 6, True, (ASKED,) + (FALLBACK,) * 3, 3),
    "notice": Kind("finished", 0, 6, True, (ASKED, ASKED, NOTICE, ASKED), None),
    "foreign": Kind("finished", 0, 6, True, (ASKED, FOREIGN, FOREIGN), None),
    "foreign-crash": Kind("finished", 1, 0, False, (FOREIGN,), None),
    "late": Kind("finished", 0, 1, True, (ASKED,) * 2, None, 0.05),
    "slow": Kind("finished", 0, 1, True, (ASKED,) * 2, None, 1.5),
}
DEFAULT = "miss"


def kind_of(script: Sequence[str], session: int) -> str:
    return script[session] if session < len(script) else DEFAULT


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def evaluations(session: int, kind: str) -> int:
    k = KINDS[kind]
    if not k.evaluations or k.late:
        return k.evaluations
    return k.evaluations + session % 5


def judgement(session: int, kind: str, count: int) -> Record:
    """The judgement of a ledger that holds `count` of the session's evaluations."""
    k = KINDS[kind]
    if not count:
        return {"pick": None, "reads": [], "pairs_won": 0, "reference_median": 0.5, "pick_median": None, "earns": False}
    return {
        "pick": f"pick-{session}",
        "reads": ["funding"] if k.earns else ["prices"],
        "pairs_won": 45 if k.earns else 20,
        "reference_median": 0.5,
        "pick_median": 0.4 if k.earns else 0.1,
        "earns": k.earns,
    }


def ids_of(answers: Sequence[str], notice: str | None = NOTICE) -> list[list[Any]]:
    """The model ids the plan defines: each assistant id but `notice`, with its count, in order of first appearance."""
    counts: dict[str, int] = {}
    for answer in answers:
        if answer != notice:
            counts[answer] = counts.get(answer, 0) + 1
    return [[model, count] for model, count in counts.items()]


def event_line() -> Record:
    return {
        "type": "system",
        "subtype": "model_refusal_fallback",
        "trigger": "refusal",
        "scope": "session",
        "original_model": ASKED,
        "fallback_model": FALLBACK,
        "api_refusal_category": "cyber",
    }


def transcript(answers: Sequence[str], event_at: int | None = None) -> str:
    """A stream-json transcript: the init line naming the model asked for, then each answer as an assistant line with a
    tool result after it, the fallback event after the first `event_at` answers (none when None), and a result line
    whose usage names the model asked for too."""
    lines: list[Record] = [{"type": "system", "subtype": "init", "model": ASKED, "tools": ["Bash", "Read", "Write"]}]
    for index, answer in enumerate(answers):
        if event_at == index:
            lines.append(event_line())
        lines.append({"type": "assistant", "message": {"model": answer, "content": [{"type": "text", "text": "x"}]}})
        lines.append({"type": "user", "message": {"content": [{"type": "tool_result", "content": "ok"}]}})
    if event_at is not None and event_at >= len(answers):
        lines.append(event_line())
    usage = {model: {"outputTokens": 1} for model in dict.fromkeys((ASKED, *answers))}
    lines.append({"type": "result", "subtype": "success", "modelUsage": usage})
    return "".join(json.dumps(line) + "\n" for line in lines)


def run_record(session: int, kind: str, campaign: str, transcript_sha: str | None) -> Record:
    k = KINDS[kind]
    return {
        "campaign": campaign,
        "agent": "A",
        "spent": evaluations(session, kind),
        "history_calls": 0,
        "turns": len(k.answers),
        "stopped": k.stopped,
        "exit": k.exit,
        "seconds": 0,
        "transcript_sha256": transcript_sha,
        "harness": "fake",
    }


def earlier(market_id: str, earns: bool) -> list[Record]:
    return [
        {"evaluation": 1, "pick": f"g100-{market_id}-1", "pairs_won": 10, "earns": False},
        {"evaluation": 7, "pick": f"g100-{market_id}-7", "pairs_won": 41, "earns": True},
        {"evaluation": 40, "pick": f"g100-{market_id}", "pairs_won": 45 if earns else 10, "earns": earns},
    ]


def searcher_line(market_id: str, earns: bool) -> Record:
    return {
        "id": market_id,
        "seed": int.from_bytes(hashlib.sha256(f"{SEED}:{market_id}:G100".encode()).digest()[:8], "big"),
        "evaluations": 100,
        "pick": f"g100-{market_id}",
        "reads": ["prices"],
        "pairs_won": 45 if earns else 10,
        "reference_median": 0.5,
        "earns": earns,
        "earlier": earlier(market_id, earns),
    }


def manifest(served: Sequence[str] = SERVED, notice: str | None = NOTICE) -> Record:
    return {
        "seed": SEED,
        "markets": list(IDS),
        "strength": STRENGTH,
        "model": ASKED,
        "constants": {"SERVED": list(served), "NOTICE": notice},
    }


def jsonl(path: Path) -> list[Record]:
    """Every line of a JSON-lines file; a line that does not parse fails the test."""
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_bytes().splitlines()]


def is_market_line(line: Mapping[str, Any]) -> bool:
    return "outcome" in line


def ends_study(line: Mapping[str, Any]) -> bool:
    if is_market_line(line):
        return line["decision"] in ENDING_DECISIONS
    return line.get("state") in ENDING_STATES


def stops_for_a_person(line: Mapping[str, Any]) -> bool:
    """A line after which the runner exits for a person: its study goes on, and its session crashed or is not the
    agent's."""
    return line["decision"] == "continue" and (line["ended"] == "crashed" or not line["is_agent"])


def simulate(
    g100: Sequence[bool], script: Sequence[str], killed: Collection[int] = ()
) -> tuple[list[Record], list[str]]:
    """The plan's step 8, applied to a script of sessions, one a market, with a start after every exit for a person:
    the results lines, and the markets after whose line the runner exited for a person. `killed` holds the sessions
    killed while running: they left their transcript and ledger, and no run record."""
    lines: list[Record] = []
    stops: list[str] = []
    wins = losses = 0
    for index, market_id in enumerate(IDS):
        kind = kind_of(script, index)
        models = ids_of(KINDS[kind].answers)
        is_agent = all(model in SERVED for model, _ in models)
        record = None if index in killed else run_record(index, kind, market_id, None)
        count = evaluations(index, kind)
        if record is None:
            ended = "killed"
        elif crashed(record):
            ended = "crashed"
        else:
            ended = record["stopped"]
        judged = judgement(index, kind, count) if is_agent else judgement(index, kind, 0)
        result = outcome(judged["earns"], g100[index])
        wins += result == "win"
        losses += result == "loss"
        decision = decide(wins, losses, index + 1)
        line = {
            "id": market_id,
            "run": record,
            "models": models,
            "is_agent": is_agent,
            "evaluations": count,
            "ended": ended,
            "pick": judged["pick"],
            "reads": judged["reads"],
            "pairs_won": judged["pairs_won"],
            "reference_median": judged["reference_median"],
            "pick_median": judged["pick_median"],
            "agent_earns": judged["earns"],
            "searcher_earns": g100[index],
            "outcome": result,
            "running_wins": wins,
            "running_losses": losses,
            "decision": decision,
        }
        lines.append(line)
        if decision != "continue":
            break
        if stops_for_a_person(line):
            stops.append(market_id)
    return lines, stops


def project(line: Mapping[str, Any]) -> Record:
    """What a results line must say: a market line's plan fields (a judged pick's details only where there is one),
    without the run record's transcript hash, which a fake writes and `simulate` cannot know; or a state line's state
    and count."""
    if not is_market_line(line):
        return {key: line[key] for key in ("state", "markets") if key in line}
    projected = {key: line[key] for key in MARKET_KEYS}
    if line["pick"] is not None:
        projected.update({key: line[key] for key in PICK_KEYS})
    if projected["run"] is not None:
        projected["run"] = {k: v for k, v in projected["run"].items() if k != "transcript_sha256"}
    return projected


def append(path: Path, entry: Mapping[str, Any]) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT)
    try:
        os.write(fd, (json.dumps(entry) + "\n").encode())
    finally:
        os.close(fd)


def die(ctl: Path) -> None:
    """SIGKILL the process running the code under test, then this one (a pool worker, or the same process)."""
    main = int((ctl / "pid").read_text())
    os.kill(main, signal.SIGKILL)
    os.kill(os.getpid(), signal.SIGKILL)


def kernel_standin(ledger: Path, final: str, delay: float) -> subprocess.Popen[bytes]:
    """A stand-in for the daemon's `mm eval -`: its command line names the ledger, and after `delay` seconds it commits
    `final` to it and exits. It is its own process, so a SIGKILL of the runner leaves it running."""
    pending = ledger.with_name(ledger.name + ".pending")
    pending.write_text(final)
    script = 'sleep "$3"; cat "$2" > "$1.tmp"; mv "$1.tmp" "$1"; rm "$2"'
    return subprocess.Popen(["sh", "-c", script, "mm-eval-standin", str(ledger), str(pending), str(delay)])


def world(
    root: Path,
    g100: Sequence[bool],
    script: Sequence[str],
    kills: Iterable[tuple[str, int]] = (),
    room_limit: int | None = None,
    pause_seconds: float = 0.0,
    event_at: int | None = -1,
) -> None:
    """A study directory: `out` (audit/control-1's stand-in, holding searcher.jsonl), `work` (G100's arm under
    `work/searcher`), and `ctl` (the fakes' script, kill points and call log). `event_at`, when not -1, puts every
    session's fallback event after that many answers (None: no event)."""
    out, work, ctl = root / "out", root / "work", root / "ctl"
    out.mkdir(parents=True)
    ctl.mkdir()
    g100_dir = work / "searcher" / IDS[0]
    g100_dir.mkdir(parents=True)
    (g100_dir / "ledger.sqlite").write_text("G100's ledger")
    (out / "searcher.jsonl").write_text("".join(json.dumps(searcher_line(i, e)) + "\n" for i, e in zip(IDS, g100)))
    (out / "calibration.json").write_text(json.dumps({"strength": STRENGTH, "walls": {}}))
    settings = {
        "manifest": manifest(),
        "script": list(script),
        "kills": [list(k) for k in kills],
        "room_limit": room_limit,
        "pause_seconds": pause_seconds,
        "event_at": event_at,
    }
    (ctl / "settings.json").write_text(json.dumps(settings))


class Fakes:
    """The runner's six effects, for the study directory at `root`."""

    def __init__(self, root: Path) -> None:
        self.out, self.work, self.ctl = root / "out", root / "work", root / "ctl"
        settings = json.loads((self.ctl / "settings.json").read_text())
        self.manifest: Record = settings["manifest"]
        self.script: list[str] = settings["script"]
        self.kills = {(kind, n) for kind, n in settings["kills"]}
        self.room_limit: int | None = settings["room_limit"]
        self.pause_seconds: float = settings["pause_seconds"]
        self.event_at: int | None = settings["event_at"]

    def log(self, kind: str, **extra: Any) -> int:
        n = len([call for call in calls(self.ctl) if call["kind"] == kind])
        results = self.out / "results.jsonl"
        content = results.read_bytes() if results.exists() else b""
        append(self.ctl / "calls.log", {"kind": kind, "n": n, "results": [len(content), sha256(content)], **extra})
        return n

    def kill_point(self, kind: str, n: int) -> None:
        if (kind, n) in self.kills:
            die(self.ctl)

    def violation(self, text: str) -> None:
        self.log("violation", text=text)

    def verify(self) -> Record:
        self.log("verify")
        return copy.deepcopy(self.manifest)

    def room(self) -> object | None:
        n = self.log("room")
        self.kill_point("room", n)
        if self.room_limit is not None and n >= self.room_limit:
            return None
        return ("TAMU", {})

    def market(self, root: Path, market_id: str, strength: float) -> Path:
        n = self.log("market", id=market_id)
        self.kill_point("market", n)
        if strength != self.manifest["strength"]:
            self.violation(f"market {market_id} written at {strength}")
        path = Path(root) / f"fake-market-{n}"
        path.mkdir(parents=True)
        (path / "id").write_text(market_id)
        return path

    def check_isolation(self, market: Path, ledger: Path, campaign: str, workdir: Path) -> None:
        own = self.work / "agent" / campaign
        if (market / "id").read_text() != campaign:
            self.violation(f"session on market {(market / 'id').read_text()} with campaign {campaign}")
        if workdir.exists() and any(workdir.iterdir()):
            self.violation(f"workdir {workdir} holds {sorted(p.name for p in workdir.iterdir())} at the start")
        if ledger.exists():
            self.violation(f"ledger {ledger} exists at the start")
        for path in (market, ledger, workdir):
            if not path.is_relative_to(own):
                self.violation(f"{path} is outside {own}")
        for other in (self.out, self.work / "searcher"):
            if workdir.is_relative_to(other) or other.is_relative_to(workdir):
                self.violation(f"workdir {workdir} overlaps {other}")

    def session(self, market: Path, ledger: Path, campaign: str, workdir: Path) -> Record:
        market, ledger, workdir = Path(market), Path(ledger), Path(workdir)
        n = self.log("session", id=campaign, workdir=str(workdir), ledger=str(ledger))
        self.check_isolation(market, ledger, campaign, workdir)
        kind = kind_of(self.script, n)
        k = KINDS[kind]
        workdir.mkdir(parents=True, exist_ok=True)
        (workdir / "token").write_text(f"session-{n}")
        event_at = k.event_at if self.event_at == -1 else self.event_at
        text = transcript(k.answers, event_at)
        (workdir / "transcript.jsonl").write_text(text)
        ledger.parent.mkdir(parents=True, exist_ok=True)
        final = json.dumps({"session": n, "kind": kind, "evaluations": evaluations(n, kind)})
        standin = None
        if k.late:
            ledger.write_text(json.dumps({"session": n, "kind": kind, "evaluations": 0}))
            standin = kernel_standin(ledger, final, k.late)
        else:
            ledger.write_text(final)
        time.sleep(self.pause_seconds)
        self.kill_point("session", n)
        if standin is not None:
            standin.wait()
        record = run_record(n, kind, campaign, sha256(text.encode()))
        (workdir / "run.json").write_text(json.dumps(record))
        return record

    def spent(self, ledger: Path, campaign: str, workdir: Path) -> int:
        n = self.log("spent", ledger=str(ledger))
        self.kill_point("spent", n)
        ledger = Path(ledger)
        if not ledger.exists():
            return 0
        return int(json.loads(ledger.read_text())["evaluations"])

    def judge(self, market_id: str, strength: float, ledger: Path) -> Record:
        ledger = Path(ledger)
        content = json.loads(ledger.read_text()) if ledger.exists() else None
        n = self.log(
            "judge",
            id=market_id,
            ledger=str(ledger),
            session=content and content["session"],
            evaluations=content and content["evaluations"],
        )
        self.kill_point("judge", n)
        if strength != self.manifest["strength"]:
            self.violation(f"judged {market_id} at {strength}")
        if content is None:
            return judgement(-1, "nopick", 0)
        return judgement(content["session"], content["kind"], content["evaluations"])


def calls(ctl: Path) -> list[Record]:
    return jsonl(ctl / "calls.log")


@dataclass
class Drive:
    lines: list[Record]
    calls: list[Record]
    snapshots: list[bytes]
    exits: list[int]
    stops: list[str]


def child(root: Path, run: Callable[..., object]) -> None:
    """Run the runner once. An exit for a person, a RuntimeError or a SystemExit, is recorded with its message and
    ends this process with STOPPED; any other exception fails the test."""
    ctl = root / "ctl"
    (ctl / "pid").write_text(str(os.getpid()))
    fakes = Fakes(root)
    try:
        run(
            root / "out",
            root / "work",
            verify=fakes.verify,
            room=fakes.room,
            market=fakes.market,
            session=fakes.session,
            spent=fakes.spent,
            judge=fakes.judge,
        )
    except (RuntimeError, SystemExit) as stop:
        append(ctl / "stops.log", {"message": str(stop)})
        os._exit(STOPPED)
    except BaseException:
        (ctl / "error").write_text(traceback.format_exc())
        os._exit(3)
    os._exit(0)


def drive(
    root: Path, run: Callable[..., object], restarts: int = 60, kill_after: Callable[[], float] | None = None
) -> Drive:
    """Run `run` in a forked process until it returns, starting it again after a kill or an exit for a person, at most
    `restarts` times. With `kill_after`, each process is also killed after that many seconds unless it has returned."""
    context = multiprocessing.get_context("fork")
    exits: list[int] = []
    snapshots: list[bytes] = []
    results = root / "out" / "results.jsonl"
    for _ in range(restarts):
        process = context.Process(target=child, args=(root, run))
        process.start()
        if kill_after is not None:
            process.join(kill_after())
            if process.is_alive() and process.pid is not None:
                os.kill(process.pid, signal.SIGKILL)
        process.join(120)
        if process.is_alive():
            process.kill()
            raise AssertionError("the runner did not return within 120 s")
        code = process.exitcode
        assert code is not None
        error = root / "ctl" / "error"
        if error.exists():
            raise AssertionError(f"the runner raised:\n{error.read_text()}")
        assert code in (0, STOPPED, -signal.SIGKILL), code
        exits.append(code)
        snapshots.append(results.read_bytes() if results.exists() else b"")
        if code == 0:
            break
    stops = [str(entry["message"]) for entry in jsonl(root / "ctl" / "stops.log")]
    return Drive(jsonl(results), calls(root / "ctl"), snapshots, exits, stops)
