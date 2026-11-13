"""Study 1, step 7: the manifest and the searcher's arm (gate/control/manifest.py, gate/control/searcher.py), their
behaviours and laws L7.1 to L7.4, from audit/program/briefs/1-positive-control.md at ce7ff38. Written from the plan
before the code, by another model than the builder's. No kernel run happens here: G100's trial is a fake, and L7.4
runs step 3's `pick` on ledgers that hold only the two tables it reads.

The plan fixes behaviour, not names, so these tests fix the interface they use:
- `manifest.files(root=REPO) -> dict[str, Path]`: every hashed file by a name of its own: the kernel binary
  (`gate.kernel.MM`), the funding blob (`data/agent/inputs/<N2's funding sha256>`), the null models' parameters
  (`gate/markets.py`'s `NULLS`), `audit/control-1/calibration.json`, `flake.lock`, and the judged path under `root`:
  every file of the repository that `gate/control/runner.py` or `gate/control/searcher.py` imports, directly or through
  other modules, whatever its directory, the two arms themselves, and every file of `gate/control/programs/`.
  Packages' `__init__.py` files may be among them; nothing under a `tests/` directory is. One entry a file, so a
  failure names the file.
- `manifest.build(seed, calibration, files) -> dict`, `calibration` the path of step 5's `calibration.json`, and a
  ValueError when it has no strength or any wall's status is "stop". The manifest holds "seed"; "markets",
  `control-1-m000` to `control-1-m099` in order; "strength", the calibration's; "constants", every constant of
  `constants.py` by name (PLANTED, SERVED and NOTICE among them); "harness", `harness_hash()`; "model", the id the
  harness asks for; "hashes", {name: sha256 hex of the file's bytes} for each entry of `files`, in its order.
- `manifest.write(content, path) -> None`: FileExistsError where a manifest exists, leaving it unchanged.
- `manifest.verify(path, files=None) -> dict`: the manifest, after recomputing the hash of every entry it names
  (resolved through `files`, default `files()`) and the harness hash; ValueError naming the first that differs, in
  the manifest's order, or that is missing. Files that the manifest does not name are not its concern.
- `searcher.bests(ledger, campaign, agent) -> list[int]`: G100's earlier bests, as the numbers (from 1, in the order
  of the agent's evaluations in that campaign, with or without a statistic) of the evaluations after which the pick
  of the ledger cut there changed.
- `searcher.run(out, work, *, verify, trial, workers=1) -> None` (`python -m gate.control.searcher`): `verify()`
  first; refuses with RuntimeError, before any trial, when any study market has an agent directory `work/agent/<id>`
  (the runner's layout, `test_runner.py`); calls `trial(market_id, strength, seed, scratch) -> {"evaluations",
  "pick", "reads", "pairs_won", "reference_median", "earns", "earlier"}` for each market, `seed` being G100's seed on
  it and `scratch` a directory of that market's own under `work/searcher`; and writes `out/searcher.jsonl`, one line
  a market in the manifest's order: "id", "seed" and the trial's fields. "earlier" is a list of {"evaluation",
  "pick", "pairs_won", "earns"}, one for each of `bests`. A trial may run in another process, so the fakes here are
  picklable."""

import ast
import hashlib
import importlib
import json
import math
import multiprocessing
import os
import shutil
import signal
import sqlite3
import tempfile
import time
import traceback
from collections.abc import Mapping
from contextlib import closing
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from gate import kernel, markets
from gate.agent import campaigns
from gate.agent.harness import MODEL, harness_hash
from gate.control import constants
from gate.control.pick import pick
from gate.control.tests.fakes import IDS, SEED, STRENGTH, append, die, jsonl

CONTROL = Path(constants.__file__).resolve().parent
REPO = CONTROL.parents[1]
ARMS = ("runner", "searcher")
NAMES = (
    "PAIRS",
    "MAJORITY",
    "SHARE",
    "THETA1",
    "ALPHA",
    "BETA_ERROR",
    "MAX_MARKETS",
    "TARGET",
    "TOLERANCE",
    "MAX_STEPS",
    "SEARCH_MARKETS",
    "CHECK_MARKETS",
    "BAND",
    "BLIND_MARKETS",
    "EVEN_ALLOWED",
    "CONSTANT_ALLOWED",
    "PLANTED",
    "SERVED",
    "NOTICE",
)


def manifest() -> ModuleType:
    return importlib.import_module("gate.control.manifest")


def searcher() -> ModuleType:
    return importlib.import_module("gate.control.searcher")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


# The judged path, found here from the modules' imports

SKIPPED = {".git", "data", "__pycache__", ".hypothesis", ".pytest_cache", "result"}


def module_file(root: Path, parts: list[str]) -> Path | None:
    """The repository file of a dotted module, as a module or as a package; None when it is not in the repository."""
    base = root.joinpath(*parts)
    for candidate in (base.with_suffix(".py"), base / "__init__.py"):
        if parts and candidate.is_file():
            return candidate
    return None


def imported(module: Path, root: Path) -> set[Path]:
    """The repository files that `module` imports, absolutely or relatively, anywhere in its body: each named module,
    each package on its way, and each name of a `from` import that is itself a module."""
    package = list(module.relative_to(root).parent.parts)
    found: set[Path | None] = set()
    for node in ast.walk(ast.parse(module.read_text())):
        if isinstance(node, ast.Import):
            for alias in node.names:
                parts = alias.name.split(".")
                found.update(module_file(root, parts[:k]) for k in range(1, len(parts) + 1))
        elif isinstance(node, ast.ImportFrom):
            stem = node.module.split(".") if node.module else []
            parts = package[: len(package) - node.level + 1] + stem if node.level else stem
            found.update(module_file(root, parts[:k]) for k in range(1, len(parts) + 1))
            found.update(module_file(root, [*parts, alias.name]) for alias in node.names)
    return {path for path in found if path is not None}


def judged_path(root: Path) -> set[Path]:
    """Every repository file that runner.py or searcher.py imports, through any chain, with the arms themselves, the
    programs and `flake.lock`. Packages' `__init__.py` files are left out here and allowed in the hashed set."""
    control = root / "gate" / "control"
    todo = [control / f"{arm}.py" for arm in ARMS]
    seen: set[Path] = set()
    while todo:
        module = todo.pop()
        if module in seen:
            continue
        seen.add(module)
        todo.extend(imported(module, root))
    programs = {p for p in (control / "programs").rglob("*") if p.is_file()}
    modules = {p for p in seen if p.name != "__init__.py"}
    return {p.resolve() for p in modules | programs | {root / "flake.lock"}}


def hashed_under(files: Mapping[str, Path], root: Path) -> set[Path]:
    """The hashed files of the repository at `root` that are Python modules, programs or `flake.lock`."""
    programs = (root / "gate" / "control" / "programs").resolve()
    found = set()
    for path in (Path(p).resolve() for p in files.values()):
        if not path.is_relative_to(root.resolve()):
            continue
        if path.suffix == ".py" or path.is_relative_to(programs) or path.name == "flake.lock":
            found.add(path)
    return found


def check_judged(files: Mapping[str, Path], root: Path) -> None:
    want = judged_path(root)
    got = hashed_under(files, root)
    extra = {p for p in got - want if p.name != "__init__.py"}
    missing = want - got
    assert not extra and not missing, (sorted(map(str, extra)), sorted(map(str, missing)))
    assert not any("tests" in p.relative_to(root.resolve()).parts for p in got)


def test_files_name_the_inputs_and_exactly_the_judged_path() -> None:
    files = manifest().files()
    paths = {Path(p).resolve() for p in files.values()}
    funding = campaigns.OUT / "inputs" / markets.null_params()["N2"]["funding"]["sha256"]
    required = (
        kernel.MM,
        funding,
        markets.NULLS,
        REPO / "audit" / "control-1" / "calibration.json",
        REPO / "flake.lock",
    )
    for path in required:
        assert Path(path).resolve() in paths, path
    check_judged(files, REPO)
    for named in ("gate/search.py", "gate/markets.py", "gate/sweep.py", "gate/agent/campaigns.py"):
        assert (REPO / named).resolve() in paths, named


def copy_repository(root: Path) -> None:
    """The repository's Python modules, programs and `flake.lock`, in a tree of their own."""
    for directory, names, filenames in os.walk(REPO):
        names[:] = [name for name in names if name not in SKIPPED and not name.startswith("result")]
        for filename in filenames:
            source = Path(directory) / filename
            relative = source.relative_to(REPO)
            if source.suffix == ".py" or relative.parts[:3] == ("gate", "control", "programs"):
                (root / relative).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, root / relative)
    shutil.copy2(REPO / "flake.lock", root / "flake.lock")


def test_l7_3_a_new_module_an_arm_imports_is_hashed_anywhere_in_the_repository_and_a_new_test_is_not(
    tmp_path: Path,
) -> None:
    root = tmp_path / "repo"
    copy_repository(root)
    control = root / "gate" / "control"
    (root / "ingest" / "deeper_extra.py").write_text("DEPTH = 2\n")
    (root / "ingest" / "unjudged_extra.py").write_text("NOTE = 3\n")
    (control / "unjudged_extra.py").write_text("NOTE = 4\n")
    (control / "judged_extra.py").write_text("from ingest import deeper_extra\n\nWEIGHT = deeper_extra.DEPTH\n")
    runner = control / "runner.py"
    runner.write_text(runner.read_text() + "\nfrom gate.control import judged_extra  # noqa: E402,F401\n")
    (control / "tests" / "test_new_law.py").write_text("def test_nothing() -> None: ...\n")
    (root / "gate" / "tests").mkdir(exist_ok=True)
    (root / "gate" / "tests" / "test_another_law.py").write_text("def test_nothing() -> None: ...\n")
    files = manifest().files(root)
    check_judged(files, root)
    got = hashed_under(files, root)
    assert (control / "judged_extra.py").resolve() in got
    assert (root / "ingest" / "deeper_extra.py").resolve() in got
    assert (root / "ingest" / "unjudged_extra.py").resolve() not in got
    assert (control / "unjudged_extra.py").resolve() not in got
    assert (root / "flake.lock").resolve() in got
    if (control / "report.py").exists():
        assert (control / "report.py").resolve() not in got


# The manifest


def tree(root: Path) -> dict[str, Path]:
    """A stand-in for the hashed files: a binary, JSON, Python sources in a nested directory."""
    contents = {
        "kernel": bytes(range(256)) * 8,
        "funding": os.urandom(512),
        "gate/nulls.json": b'{"N2": {"funding": {}}}',
        "audit/control-1/calibration.json": json.dumps(calibration({"2": "pass", "3": "pass"})).encode(),
        "gate/control/measure.py": b"def classify() -> None: ...\n",
        "gate/control/programs/reference.json": b'{"dsl": 1}',
        "gate/control/programs/long.json": b'{"dsl": 1, "weight": 1}',
    }
    files: dict[str, Path] = {}
    for name, data in contents.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        files[name] = path
    return files


def calibration(walls: dict[str, str], strength: float | None = STRENGTH) -> dict[str, Any]:
    return {
        "strength": strength,
        "walls": {k: {"count": 0, "denominator": 1, "status": v} for k, v in walls.items()},
        "mirror_rates": {},
        "pick_histogram": [0] * (constants.PAIRS + 1),
    }


def built(files: Mapping[str, Path], seed: str = SEED) -> dict[str, Any]:
    content: dict[str, Any] = manifest().build(seed, files["audit/control-1/calibration.json"], files)
    return content


def written(root: Path, files: Mapping[str, Path]) -> Path:
    path = root / "manifest.json"
    manifest().write(built(files), path)
    return path


def test_build_holds_every_entry_the_plan_lists(tmp_path: Path) -> None:
    files = tree(tmp_path)
    content = built(files)
    assert content["seed"] == SEED
    assert content["markets"] == [f"control-1-m{i:03d}" for i in range(constants.MAX_MARKETS)]
    assert content["strength"] == STRENGTH
    expected = {name: json.loads(json.dumps(getattr(constants, name))) for name in NAMES}
    assert {name: content["constants"][name] for name in NAMES} == expected
    assert content["constants"]["PLANTED"] == [0, 1, 2, 3, 4, 5]
    assert content["constants"]["SERVED"] == ["claude-opus-5-5", "claude-opus-4-8"]
    assert content["constants"]["NOTICE"] == "<synthetic>"
    assert content["harness"] == harness_hash()
    assert content["model"] == MODEL == "claude-opus-5-5"
    assert list(content["hashes"]) == list(files)
    assert content["hashes"] == {name: digest(path) for name, path in files.items()}
    json.dumps(content)


@pytest.mark.parametrize(
    "bad",
    [
        calibration({"2": "pass", "3": "stop", "4": "pass", "5": "pass"}),
        calibration({"2": "pass", "3": "pass", "4": "pass", "5": "stop"}),
        calibration({"2": "stop", "3": "pass", "4": "pass", "5": "pass"}),
        calibration({"2": "pass", "3": "pass", "4": "stop", "5": "pass"}, None),
    ],
)
def test_no_manifest_is_built_from_a_calibration_with_no_strength_or_a_stopped_wall(
    tmp_path: Path, bad: dict[str, Any]
) -> None:
    files = tree(tmp_path)
    files["audit/control-1/calibration.json"].write_text(json.dumps(bad))
    with pytest.raises(ValueError):
        built(files)


def test_writing_a_manifest_where_one_exists_is_an_error(tmp_path: Path) -> None:
    files = tree(tmp_path / "t")
    path = written(tmp_path, files)
    before = path.read_bytes()
    with pytest.raises(FileExistsError):
        manifest().write(built(files, "another seed"), path)
    assert path.read_bytes() == before


def test_verify_passes_on_an_untouched_tree_and_returns_the_manifest(tmp_path: Path) -> None:
    files = tree(tmp_path / "t")
    path = written(tmp_path, files)
    assert manifest().verify(path, files) == json.loads(path.read_text())


def test_verify_names_the_first_entry_that_differs(tmp_path: Path) -> None:
    files = tree(tmp_path / "t")
    path = written(tmp_path, files)
    names = list(files)
    for name in (names[4], names[2]):
        files[name].write_bytes(files[name].read_bytes() + b"\n")
    with pytest.raises(ValueError, match=names[2]):
        manifest().verify(path, files)


def test_verify_fails_naming_a_missing_file(tmp_path: Path) -> None:
    files = tree(tmp_path / "t")
    path = written(tmp_path, files)
    files["gate/control/programs/long.json"].unlink()
    with pytest.raises(ValueError, match="long.json"):
        manifest().verify(path, files)


def test_verify_fails_on_another_harness(tmp_path: Path) -> None:
    files = tree(tmp_path / "t")
    content = built(files)
    content["harness"] = "0" * 64
    path = tmp_path / "manifest.json"
    manifest().write(content, path)
    with pytest.raises(ValueError, match="harness"):
        manifest().verify(path, files)


def test_verify_ignores_files_the_manifest_does_not_name(tmp_path: Path) -> None:
    files = tree(tmp_path / "t")
    path = written(tmp_path, files)
    extra = tmp_path / "t" / "gate" / "control" / "report.py"
    extra.write_text("written after the manifest\n")
    pycache = tmp_path / "t" / "gate" / "control" / "__pycache__" / "measure.cpython-313.pyc"
    pycache.parent.mkdir()
    pycache.write_bytes(b"\x00")
    manifest().verify(path, {**files, "gate/control/report.py": extra})


@settings(max_examples=40, deadline=None)
@given(st.data())
def test_l7_1_one_changed_byte_in_any_hashed_file_fails_verify_naming_that_file(data: st.DataObject) -> None:
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        files = tree(root / "t")
        path = written(root, files)
        manifest().verify(path, files)
        name = data.draw(st.sampled_from(sorted(files)))
        target = files[name]
        content = bytearray(target.read_bytes())
        offset = data.draw(st.integers(0, len(content) - 1))
        content[offset] ^= data.draw(st.integers(1, 255))
        target.write_bytes(bytes(content))
        with pytest.raises(ValueError) as failure:
            manifest().verify(path, files)
        assert name in str(failure.value)
        assert not any(other in str(failure.value) for other in files if other != name)


# L7.4: G100's earlier bests, against step 3's pick


def ledger_of(root: Path, scores: list[float | None], name: str) -> Path:
    """A ledger holding the two tables `pick` reads, with one G100 evaluation for each score."""
    path = root / f"{name}.sqlite"
    with closing(sqlite3.connect(path)) as db:
        db.execute("CREATE TABLE experiments (id INTEGER PRIMARY KEY, program TEXT)")
        db.execute(
            "CREATE TABLE disclosures (id INTEGER PRIMARY KEY, experiment_id INTEGER, campaign TEXT, agent TEXT, "
            "kind TEXT, content TEXT)"
        )
        db.execute("INSERT INTO experiments (id, program) VALUES (0, ?)", (json.dumps({"other": True}),))
        db.execute(
            "INSERT INTO disclosures (experiment_id, campaign, agent, kind, content) VALUES (0, 'c', 'A', 'eval', ?)",
            (json.dumps({"result": {"sharpe_annualized": 99.0}}),),
        )
        for number, score in enumerate(scores, start=1):
            db.execute("INSERT INTO experiments (id, program) VALUES (?, ?)", (number, json.dumps({"number": number})))
            result = {} if score is None else {"sharpe_annualized": score}
            db.execute(
                "INSERT INTO disclosures (experiment_id, campaign, agent, kind, content) VALUES (?, 'c', 'G100', "
                "'eval', ?)",
                (number, json.dumps({"result": result})),
            )
        db.commit()
    return path


scores_lists = st.lists(
    st.one_of(st.none(), st.sampled_from([math.nan, math.inf, -math.inf]), st.integers(-4, 4).map(float)),
    max_size=30,
)


@settings(max_examples=100, deadline=None)
@given(scores_lists)
def test_l7_4_each_earlier_best_is_the_pick_of_the_ledger_cut_there_and_the_last_is_the_pick(
    scores: list[float | None],
) -> None:
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        bests = searcher().bests(ledger_of(root, scores, "whole"), "c", "G100")
        assert bests == sorted(set(bests))
        whole = pick(ledger_of(root, scores, "again"), "c", "G100")
        assert (bests[-1] if bests else None) == (whole["number"] if whole else None)
        for k in range(len(scores) + 1):
            cut = pick(ledger_of(root, scores[:k], f"cut-{k}"), "c", "G100")
            at_or_before = [b for b in bests if b <= k]
            assert (at_or_before[-1] if at_or_before else None) == (cut["number"] if cut else None), k


# The searcher's arm


def result(market_id: str) -> dict[str, Any]:
    """A trial's result, a function of the market alone."""
    h = int.from_bytes(hashlib.sha256(market_id.encode()).digest()[:8], "big")
    won = h % (constants.PAIRS + 1)
    earns = won >= constants.MAJORITY
    return {
        "evaluations": 100,
        "pick": f"g100-{market_id}",
        "reads": ["prices"] if h % 2 else ["funding", "prices"],
        "pairs_won": won,
        "reference_median": (h % 1000) / 1000,
        "earns": earns,
        "earlier": [
            {"evaluation": 1, "pick": f"g100-{market_id}-1", "pairs_won": 3, "earns": False},
            {"evaluation": 1 + h % 99, "pick": f"g100-{market_id}", "pairs_won": won, "earns": earns},
        ],
    }


class Trial:
    """G100 on one market, faked: logs each call to `ctl/trials.log`, sleeps up to 20 ms when `jitter` (a salt for
    the order in which markets finish), and kills the searcher's process at its `kill_at`-th call."""

    def __init__(self, ctl: Path, jitter: int | None = None, kill_at: int | None = None) -> None:
        self.ctl, self.jitter, self.kill_at = ctl, jitter, kill_at

    def __call__(self, market_id: str, strength: float, seed: int, scratch: Path) -> dict[str, Any]:
        log = self.ctl / "trials.log"
        done = len(jsonl(log))
        append(log, {"id": market_id, "strength": strength, "seed": seed, "scratch": str(scratch)})
        if self.kill_at is not None and done == self.kill_at:
            die(self.ctl)
        if self.jitter is not None:
            h = hashlib.sha256(f"{self.jitter}:{market_id}".encode()).digest()[0]
            time.sleep(h / 255 * 0.02)
        Path(scratch).mkdir(parents=True, exist_ok=True)
        (Path(scratch) / "ledger.sqlite").write_text(f"G100 on {market_id}")
        return result(market_id)


def fake_manifest(markets: list[str] | None = None) -> dict[str, Any]:
    return {"seed": SEED, "markets": markets or list(IDS), "strength": STRENGTH, "model": MODEL}


def g100_seed(market_id: str) -> int:
    return int.from_bytes(hashlib.sha256(f"{SEED}:{market_id}:G100".encode()).digest()[:8], "big")


def run_searcher(root: Path, trial: Trial, workers: int = 1, markets: list[str] | None = None) -> bytes:
    (root / "out").mkdir(parents=True, exist_ok=True)
    (root / "ctl").mkdir(exist_ok=True)
    searcher().run(root / "out", root / "work", verify=lambda: fake_manifest(markets), trial=trial, workers=workers)
    return (root / "out" / "searcher.jsonl").read_bytes()


def test_the_searcher_writes_one_line_a_market_in_the_manifests_order(tmp_path: Path) -> None:
    content = run_searcher(tmp_path, Trial(tmp_path / "ctl"))
    lines = [json.loads(line) for line in content.splitlines()]
    assert [line["id"] for line in lines] == IDS
    keys = ("evaluations", "pick", "reads", "pairs_won", "reference_median", "earns", "earlier")
    for line in lines:
        assert line["seed"] == g100_seed(line["id"])
        assert {k: line[k] for k in keys} == result(line["id"])
    trials = jsonl(tmp_path / "ctl" / "trials.log")
    assert sorted(t["id"] for t in trials) == sorted(IDS)
    assert all(t["strength"] == STRENGTH and t["seed"] == g100_seed(t["id"]) for t in trials)
    scratches = [Path(t["scratch"]) for t in trials]
    assert len(set(scratches)) == len(IDS)
    assert all(s.is_relative_to(tmp_path / "work" / "searcher") for s in scratches)


def test_verify_failing_stops_the_searcher_before_any_trial(tmp_path: Path) -> None:
    (tmp_path / "ctl").mkdir()

    def broken() -> dict[str, Any]:
        raise ValueError("kernel differs")

    with pytest.raises(ValueError):
        searcher().run(tmp_path / "out", tmp_path / "work", verify=broken, trial=Trial(tmp_path / "ctl"))
    assert jsonl(tmp_path / "ctl" / "trials.log") == []
    assert not (tmp_path / "out" / "searcher.jsonl").exists()


def test_the_searcher_refuses_to_run_when_a_study_market_has_an_agent_directory(tmp_path: Path) -> None:
    (tmp_path / "work" / "agent" / IDS[37]).mkdir(parents=True)
    (tmp_path / "ctl").mkdir()
    with pytest.raises(RuntimeError):
        run_searcher(tmp_path, Trial(tmp_path / "ctl"))
    assert jsonl(tmp_path / "ctl" / "trials.log") == []
    assert not (tmp_path / "out" / "searcher.jsonl").exists()


def test_the_searcher_run_twice_gives_the_same_file(tmp_path: Path) -> None:
    first = run_searcher(tmp_path, Trial(tmp_path / "ctl"))
    assert run_searcher(tmp_path, Trial(tmp_path / "ctl")) == first


def killed_child(root: Path, kill_at: int) -> None:
    (root / "ctl" / "pid").write_text(str(os.getpid()))
    try:
        run_searcher(root, Trial(root / "ctl", kill_at=kill_at))
    except BaseException:
        (root / "ctl" / "error").write_text(traceback.format_exc())
        os._exit(3)
    os._exit(0)


@pytest.mark.parametrize("kill_at", [0, 1, 50, 99])
def test_a_killed_searcher_run_again_gives_the_file_of_an_uninterrupted_run(tmp_path: Path, kill_at: int) -> None:
    clean = run_searcher(tmp_path / "clean", Trial(tmp_path / "clean" / "ctl"))
    root = tmp_path / "killed"
    (root / "out").mkdir(parents=True)
    (root / "ctl").mkdir()
    process = multiprocessing.get_context("fork").Process(target=killed_child, args=(root, kill_at))
    process.start()
    process.join(120)
    assert not (root / "ctl" / "error").exists(), (root / "ctl" / "error").read_text()
    assert process.exitcode == -signal.SIGKILL
    assert run_searcher(root, Trial(root / "ctl")) == clean


@settings(max_examples=6, deadline=None)
@given(st.integers(0, 2**32), st.sampled_from([2, 4]))
def test_l7_2_the_searchers_file_depends_on_neither_the_order_markets_finish_nor_the_workers(
    jitter: int, workers: int
) -> None:
    markets = IDS[:24]
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        alone = run_searcher(root / "one", Trial(root / "one" / "ctl"), 1, markets)
        many = run_searcher(root / "many", Trial(root / "many" / "ctl", jitter), workers, markets)
        assert many == alone
        assert [json.loads(line)["id"] for line in many.splitlines()] == markets
