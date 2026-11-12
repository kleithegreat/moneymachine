"""Fakes and a reference for study 1's steps 7 to 9 (audit/program/briefs/1-positive-control.md), written from the plan
before the code. Nothing here runs an agent session, the kernel or an account check.

The interfaces these fakes stand in for are stated in `test_runner.py`, `test_manifest.py` and `test_report.py`. In
short, the runner takes six injected effects, each defaulting to the real one:
- `verify() -> manifest`: `manifest.verify`, which raises before the runner does anything else;
- `room() -> object | None`: pacing on the TAMU and Cornell accounts (`wait_for_room`); None ends the runner;
- `market(root, market_id, strength) -> Path`: `pairs.write_market`;
- `session(market, ledger, campaign, workdir) -> run record`: `harness.run_agent`, which writes the record to
  `workdir/run.json` and the transcript to `workdir/transcript.jsonl` before it returns;
- `spent(ledger, campaign, workdir) -> int`: `campaigns.evaluations_made`;
- `judge(market_id, strength, ledger) -> judgement`: the pick (step 3) of agent "A" in campaign `market_id`,
  classified on the market's fresh pairs (steps 1, 2).

A fake session writes a ledger that is a JSON file naming the session and its scripted behaviour; only the fake
`spent` and `judge` read it. Every fake call appends one line to `ctl/calls.log` with the size and hash of
`results.jsonl` at that moment, so a test can check what the runner had written whenever it acted. A kill point
`(kind, n)` makes the n-th call of that kind (counted over every restart) SIGKILL the process that runs the code
under test, and itself."""

import hashlib
import json
import multiprocessing
import os
import signal
import time
import traceback
from collections.abc import Callable, Collection, Iterable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from gate.agent.campaigns import crashed
from gate.control.constants import MAX_MARKETS, MAX_VOIDS
from gate.control.sequential import decide, outcome

Record = dict[str, Any]

PINNED = "claude-opus-5-5"
FOREIGN = "claude-opus-4-8"
STRENGTH = 0.004
SEED = "control-1-test-seed"
IDS = [f"control-1-m{i:03d}" for i in range(MAX_MARKETS)]
ENDING_DECISIONS = ("claim", "futility", "undecided")
ENDING_STATES = ("model changed", "ended early")
MARKET_KEYS = (
    "id",
    "models",
    "evaluations",
    "stopped",
    "pick",
    "pairs_won",
    "reference_median",
    "pick_median",
    "agent_earns",
    "searcher_earns",
    "outcome",
    "running_wins",
    "running_losses",
    "decision",
)


@dataclass(frozen=True)
class Behaviour:
    stopped: str
    exit: int
    has_pick: bool
    earns: bool
    foreign: bool


BEHAVIOURS = {
    "earn": Behaviour("finished", 0, True, True, False),
    "miss": Behaviour("finished", 0, True, False, False),
    "nopick": Behaviour("finished", 0, False, False, False),
    "turns": Behaviour("turn limit", -9, True, True, False),
    "wall": Behaviour("wall time", -9, True, False, False),
    "crash": Behaviour("finished", 1, True, True, False),
    "crash-miss": Behaviour("finished", 1, True, False, False),
    "signal": Behaviour("finished", -15, True, True, False),
    "foreign": Behaviour("finished", 0, True, True, True),
}
DEFAULT = "miss"


def behaviour_of(script: Sequence[str], session: int) -> str:
    return script[session] if session < len(script) else DEFAULT


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def evaluations(session: int) -> int:
    return 1 + (7 * session) % 23


def judgement(session: int, behaviour: str) -> Record:
    b = BEHAVIOURS[behaviour]
    if not b.has_pick:
        return {"pick": None, "pairs_won": 0, "reference_median": 0.5, "pick_median": None, "earns": False}
    return {
        "pick": f"pick-{session}",
        "pairs_won": 45 if b.earns else 20,
        "reference_median": 0.5,
        "pick_median": 0.4 if b.earns else 0.1,
        "earns": b.earns,
    }


def transcript(pinned: str, foreign: bool) -> str:
    answered = FOREIGN if foreign else pinned
    lines: list[Record] = [{"type": "system", "subtype": "init", "model": pinned, "tools": ["Bash", "Read", "Write"]}]
    if foreign:
        lines.append(
            {
                "type": "system",
                "subtype": "model_refusal_fallback",
                "original_model": pinned,
                "fallback_model": FOREIGN,
            }
        )
    for text in ("reading the brief", "done"):
        lines.append({"type": "assistant", "message": {"model": answered, "content": [{"type": "text", "text": text}]}})
    usage = {pinned: {"outputTokens": 1}, FOREIGN: {"outputTokens": 9}} if foreign else {pinned: {"outputTokens": 9}}
    lines.append({"type": "result", "subtype": "success", "modelUsage": usage})
    return "".join(json.dumps(line) + "\n" for line in lines)


def run_record(session: int, behaviour: str, campaign: str, transcript_sha: str | None) -> Record:
    b = BEHAVIOURS[behaviour]
    return {
        "campaign": campaign,
        "agent": "A",
        "spent": evaluations(session),
        "history_calls": 0,
        "turns": 3 + session % 5,
        "stopped": b.stopped,
        "exit": b.exit,
        "seconds": 0,
        "transcript_sha256": transcript_sha,
        "harness": "fake",
    }


def searcher_line(market_id: str, earns: bool) -> Record:
    return {
        "id": market_id,
        "seed": int.from_bytes(hashlib.sha256(f"{SEED}:{market_id}:G100".encode()).digest()[:8], "big"),
        "evaluations": 100,
        "pick": f"g100-{market_id}",
        "pairs_won": 45 if earns else 10,
        "reference_median": 0.5,
        "earns": earns,
    }


def manifest(model: str = PINNED) -> Record:
    return {"seed": SEED, "markets": list(IDS), "strength": STRENGTH, "model": model}


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


def simulate(
    g100: Sequence[bool], script: Sequence[str], killed: Collection[int] = (), model: str = PINNED
) -> tuple[list[Record], list[Record], int]:
    """The plan's step 8, applied to a script of sessions with a restart after every pause: the results lines, the
    void lines (with the session that each void was) and the number of sessions launched. `killed` holds the
    sessions killed while running, which are voids whatever their script says."""
    lines: list[Record] = []
    voids: list[Record] = []
    launched = 0
    wins = losses = 0
    since_pause = 0
    index = 0
    while index < len(IDS):
        market_id = IDS[index]
        if since_pause >= MAX_VOIDS:
            lines.append({"state": "paused", "id": market_id})
            since_pause = 0
            continue
        session = launched
        launched += 1
        behaviour = behaviour_of(script, session)
        record = run_record(session, behaviour, market_id, None)
        if session in killed or crashed(record):
            voids.append({"id": market_id, "session": session, "evaluations": evaluations(session), "run": record})
            since_pause += 1
            continue
        if BEHAVIOURS[behaviour].foreign:
            lines.append({"state": "model changed", "id": market_id})
            break
        judged = judgement(session, behaviour)
        result = outcome(judged["earns"], g100[index])
        wins += result == "win"
        losses += result == "loss"
        decision = decide(wins, losses, index + 1)
        lines.append(
            {
                "id": market_id,
                "run": record,
                "models": [model],
                "evaluations": evaluations(session),
                "stopped": record["stopped"],
                "pick": judged["pick"],
                "pairs_won": judged["pairs_won"],
                "reference_median": judged["reference_median"],
                "pick_median": judged["pick_median"],
                "agent_earns": judged["earns"],
                "searcher_earns": g100[index],
                "outcome": result,
                "running_wins": wins,
                "running_losses": losses,
                "decision": decision,
                "session": session,
            }
        )
        if decision != "continue":
            break
        index += 1
        since_pause = 0
    return lines, voids, launched


def project(line: Mapping[str, Any]) -> Record:
    """What a results line must say: a market line's plan fields, or a state line's state and market."""
    if is_market_line(line):
        return {key: line[key] for key in MARKET_KEYS}
    return {key: line[key] for key in ("state", "id", "markets") if key in line}


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


def world(
    root: Path,
    g100: Sequence[bool],
    script: Sequence[str],
    kills: Iterable[tuple[str, int]] = (),
    model: str = PINNED,
    room_limit: int | None = None,
    pause_seconds: float = 0.0,
) -> None:
    """A study directory: `out` (audit/control-1's stand-in, holding searcher.jsonl), `work` (G100's arm under
    `work/searcher`), and `ctl` (the fakes' script, kill points and call log)."""
    out, work, ctl = root / "out", root / "work", root / "ctl"
    out.mkdir(parents=True)
    ctl.mkdir()
    g100_dir = work / "searcher" / IDS[0]
    g100_dir.mkdir(parents=True)
    (g100_dir / "ledger.sqlite").write_text("G100's ledger")
    (out / "searcher.jsonl").write_text("".join(json.dumps(searcher_line(i, e)) + "\n" for i, e in zip(IDS, g100)))
    (out / "calibration.json").write_text(json.dumps({"strength": STRENGTH, "walls": {}}))
    settings = {
        "manifest": manifest(model),
        "script": list(script),
        "kills": [list(k) for k in kills],
        "room_limit": room_limit,
        "pause_seconds": pause_seconds,
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
        return dict(self.manifest)

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
        behaviour = behaviour_of(self.script, n)
        workdir.mkdir(parents=True, exist_ok=True)
        (workdir / "token").write_text(f"session-{n}")
        ledger.parent.mkdir(parents=True, exist_ok=True)
        ledger.write_text(json.dumps({"session": n, "behaviour": behaviour}))
        time.sleep(self.pause_seconds)
        self.kill_point("session", n)
        text = transcript(self.manifest["model"], BEHAVIOURS[behaviour].foreign)
        (workdir / "transcript.jsonl").write_text(text)
        record = run_record(n, behaviour, campaign, sha256(text.encode()))
        (workdir / "run.json").write_text(json.dumps(record))
        return record

    def spent(self, ledger: Path, campaign: str, workdir: Path) -> int:
        n = self.log("spent", ledger=str(ledger))
        self.kill_point("spent", n)
        ledger = Path(ledger)
        if not ledger.exists():
            return 0
        return evaluations(json.loads(ledger.read_text())["session"])

    def judge(self, market_id: str, strength: float, ledger: Path) -> Record:
        ledger = Path(ledger)
        content = json.loads(ledger.read_text()) if ledger.exists() else None
        n = self.log("judge", id=market_id, ledger=str(ledger), session=content and content["session"])
        self.kill_point("judge", n)
        if strength != self.manifest["strength"]:
            self.violation(f"judged {market_id} at {strength}")
        if content is None:
            return judgement(-1, "nopick")
        return judgement(content["session"], content["behaviour"])


def calls(ctl: Path) -> list[Record]:
    return jsonl(ctl / "calls.log")


@dataclass
class Drive:
    lines: list[Record]
    voids: list[Record]
    calls: list[Record]
    snapshots: list[bytes]
    exits: list[int]


def child(root: Path, run: Callable[..., object]) -> None:
    (root / "ctl" / "pid").write_text(str(os.getpid()))
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
    except BaseException:
        (root / "ctl" / "error").write_text(traceback.format_exc())
        os._exit(3)
    os._exit(0)


def drive(
    root: Path, run: Callable[..., object], restarts: int = 60, kill_after: Callable[[], float] | None = None
) -> Drive:
    """Run `run` in a forked process until it returns other than paused, restarting it after a kill or a pause, at
    most `restarts` times. With `kill_after`, each process is also killed after that many seconds unless it has returned."""
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
        assert code in (0, -signal.SIGKILL), code
        exits.append(code)
        snapshots.append(results.read_bytes() if results.exists() else b"")
        lines = jsonl(results)
        if code == 0 and not (lines and lines[-1].get("state") == "paused"):
            break
    return Drive(jsonl(results), jsonl(root / "out" / "voids.jsonl"), calls(root / "ctl"), snapshots, exits)
