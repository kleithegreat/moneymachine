"""Study 1's manifest (step 7): what the study is, and a hash of every file whose bytes can change a line of
`searcher.jsonl` or `results.jsonl` (audit/program/briefs/1-positive-control.md, step 7)."""

import ast
import hashlib
import json
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from gate import kernel, markets
from gate.agent import campaigns
from gate.agent.harness import MODEL, harness_hash
from gate.control import constants

REPO = Path(__file__).resolve().parents[2]
CONTROL = Path(__file__).resolve().parent
OUT = REPO / "audit" / "control-1"
MANIFEST = OUT / "manifest.json"
ARMS = ("runner", "searcher")


def module_file(root: Path, parts: list[str]) -> Path | None:
    """The file of a dotted module of the repository, as a module or as a package; None for any other."""
    base = root.joinpath(*parts)
    for candidate in (base.with_suffix(".py"), base / "__init__.py"):
        if parts and candidate.is_file():
            return candidate
    return None


def imported(module: Path, root: Path) -> set[Path]:
    """The repository files that `module` imports anywhere in its body: each named module, each package on its way,
    and each name of a `from` import that is itself a module."""
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


def judged_path(root: Path) -> list[Path]:
    """Every file of the repository that an arm imports, through any chain, with the arms, the programs and
    `flake.lock`, in path order."""
    control = root / "gate" / "control"
    todo = [control / f"{arm}.py" for arm in ARMS]
    seen: set[Path] = set()
    while todo:
        module = todo.pop()
        if module not in seen:
            seen.add(module)
            todo.extend(imported(module, root))
    programs = {path for path in (control / "programs").rglob("*") if path.is_file()}
    return sorted(seen | programs | {root / "flake.lock"})


def files(root: Path = REPO) -> dict[str, Path]:
    """Every hashed file by its name: the kernel binary, the funding blob, the null models' parameters, the
    calibration, and the judged path under `root` by its path in the repository."""
    funding = campaigns.OUT / "inputs" / markets.null_params()["N2"]["funding"]["sha256"]
    named = {
        "kernel/mm": kernel.MM,
        "inputs/funding": funding,
        "gate/nulls.json": markets.NULLS,
        "audit/control-1/calibration.json": root / "audit" / "control-1" / "calibration.json",
    }
    judged = {path.relative_to(root).as_posix(): path for path in judged_path(root)}
    return {**named, **judged}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(seed: str, calibration: Path, hashed: Mapping[str, Path]) -> dict[str, Any]:
    """The manifest. A ValueError when the calibration has no strength or a wall stopped."""
    found = json.loads(calibration.read_text())
    stopped = [name for name, wall in found["walls"].items() if wall["status"] == "stop"]
    if found["strength"] is None or stopped:
        raise ValueError(f"the calibration has no strength or a wall stopped: {stopped}")
    values = {name: getattr(constants, name) for name in dir(constants) if name.isupper()}
    return {
        "seed": seed,
        "markets": [f"control-1-m{i:03d}" for i in range(constants.MAX_MARKETS)],
        "strength": found["strength"],
        "constants": json.loads(json.dumps(values)),
        "harness": harness_hash(),
        "model": MODEL,
        "hashes": {name: digest(path) for name, path in hashed.items()},
    }


def write(content: Mapping[str, Any], path: Path = MANIFEST) -> None:
    """Write the manifest; a FileExistsError, with the file unchanged, where one exists."""
    with path.open("x") as handle:
        handle.write(json.dumps(content, indent=2) + "\n")


def verify(path: Path = MANIFEST, hashed: Mapping[str, Path] | None = None) -> dict[str, Any]:
    """The manifest, after recomputing the harness hash and every hash it names, resolved through `hashed`; a
    ValueError naming the first that differs or is missing."""
    content: dict[str, Any] = json.loads(path.read_text())
    resolved = files() if hashed is None else hashed
    if content["harness"] != harness_hash():
        raise ValueError("harness differs from the manifest")
    for name, expected in content["hashes"].items():
        file = resolved.get(name)
        if file is None or not file.is_file():
            raise ValueError(f"{name} is missing")
        if digest(file) != expected:
            raise ValueError(f"{name} differs from the manifest")
    return content
