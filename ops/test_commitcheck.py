"""Every line added to PROGRESS.md or audit/ since the rule began names an Eastern time beside each UTC time."""

import subprocess
from pathlib import Path

import pytest

from ops.commitcheck import unpaired

REPO = Path(__file__).resolve().parents[1]
SINCE = "a71111fa92aee5acb33f73ec5c448d387020d6fd"


def git(*args: str) -> list[str]:
    return subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True, check=True).stdout.splitlines()


def test_a_utc_time_needs_its_eastern_time() -> None:
    assert unpaired("at 20:13 UTC") and unpaired("20:13 UTC (16:13 EDT) and 21:00 UTC")
    assert not unpaired("at 20:13 UTC (16:13 EDT)") and not unpaired("no time here")


@pytest.mark.local
def test_added_lines_pair_their_times() -> None:
    diff = git("diff", SINCE, "--", "PROGRESS.md", "audit")
    added = [line[1:] for line in diff if line.startswith("+") and not line.startswith("+++")]
    for path in git("ls-files", "--others", "--exclude-standard", "--", "audit"):
        added += (REPO / path).read_text(errors="replace").splitlines()
    assert [line for line in added if unpaired(line)] == []
