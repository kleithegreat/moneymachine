"""Every line written to PROGRESS.md or audit/ under the rule (by a commit descending from its start, or not yet
committed) names an Eastern time beside each UTC time; lines merged in from a branch written before it are not."""

import subprocess
from pathlib import Path

from ops.commitcheck import unpaired

REPO = Path(__file__).resolve().parents[1]
SINCE = "a71111fa92aee5acb33f73ec5c448d387020d6fd"


def git(*args):
    return subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True, check=True).stdout.splitlines()


def test_a_utc_time_needs_its_eastern_time():
    assert unpaired("at 20:13 UTC") and unpaired("20:13 UTC (16:13 EDT) and 21:00 UTC")
    assert not unpaired("at 20:13 UTC (16:13 EDT)") and not unpaired("no time here")


def test_added_lines_pair_their_times():
    under_rule = {"0" * 40, *git("rev-list", "--ancestry-path", f"{SINCE}..HEAD")}
    added = []
    for path in git("diff", "--name-only", "--diff-filter=AM", SINCE, "--", "PROGRESS.md", "audit"):
        for line in git("blame", "--line-porcelain", "--", path):
            if line.startswith("\t"):
                added += [line[1:]] if commit in under_rule else []
            elif len(head := line.split(" ", 1)[0]) == 40:
                commit = head
    for path in git("ls-files", "--others", "--exclude-standard", "--", "audit"):
        added += (REPO / path).read_text(errors="replace").splitlines()
    assert [l for l in added if unpaired(l)] == []
