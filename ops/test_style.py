"""The covered code holds to `ruff format`, `ruff check` and `mypy --strict` (CLAUDE.md §2, "Write for the reader").

Frozen code is excluded until its identity forks, and the exclusion is computed from the functions that define those
identities, so a file leaves it the moment it joins a fork:
- the stage 3 harness hash (`gate.agent.harness.harness_hash`): the `.py` files it hashes, with the sandbox's own;
- the two modules that hash their own bytes into a record, `gate.search` (the searchers' pin, `search.identity`) and
  `ingest.events` (the `code_sha256` of every derived version's lineage, `events.derive`);
- the thesis manifest (`thesis.harness.manifest_files`): the modules `thesis.runner` and `thesis.report` load. The
  thesis-refreeze branch replaces that code, so all of `thesis/` is excluded as well as the modules it loads elsewhere.
"""

import json
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]

_FROZEN_FILES = """
import json, sys
from pathlib import Path
from sandbox import session
captured = []
session.identity = lambda files, extra: captured.extend(files) or ""
session.claude_binary = lambda: ""
from gate.agent import harness as stage3
from thesis import harness as thesis
from gate import search
from ingest import events
stage3.harness_hash()
thesis.manifest_hash.__wrapped__("")
hashed = {Path(f).resolve() for f in [*captured, *session.FILES, search.__file__, events.__file__]}
loaded = {p for p in map(Path, thesis.manifest_files.__wrapped__("")) if p.exists()} | hashed
print(json.dumps(sorted(str(p.relative_to(%r)) for p in loaded if p.is_relative_to(%r) and p.suffix == ".py")))
"""


def frozen() -> set[str]:
    """Repo-relative `.py` files that a frozen identity hashes, as the identity functions themselves report them."""
    code = _FROZEN_FILES % (str(REPO), str(REPO))
    out = subprocess.run([sys.executable, "-c", code], cwd=REPO, capture_output=True, text=True, check=True).stdout
    return set(json.loads(out))


def covered() -> list[str]:
    """Every tracked `.py` file outside the frozen identities and `thesis/`."""
    tracked = subprocess.run(["git", "ls-files", "*.py"], cwd=REPO, capture_output=True, text=True, check=True)
    excluded = frozen()
    return sorted(f for f in tracked.stdout.split() if f not in excluded and not f.startswith("thesis/"))


def _run(*command: str) -> None:
    result = subprocess.run([sys.executable, "-m", *command, *covered()], cwd=REPO, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr


def test_the_covered_files_are_formatted() -> None:
    _run("ruff", "format", "--check")


def test_the_covered_files_pass_ruff_check() -> None:
    _run("ruff", "check")


@pytest.mark.xfail(
    strict=True,
    reason="typing is unfinished: 20 of 123 covered files still fail mypy --strict, all behind modules another branch is editing (PROGRESS.md, code-style)",
)
def test_the_covered_files_pass_mypy_strict() -> None:
    _run("mypy")


def test_the_exclusion_is_only_frozen_code() -> None:
    assert "gate/agent/harness.py" in frozen()
    assert "ops/test_style.py" not in frozen()
