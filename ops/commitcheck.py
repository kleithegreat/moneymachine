"""The commit-msg hook (the dev shell sets core.hooksPath to .githooks): every UTC time has its Eastern time beside it
(ops/test_commitcheck.py checks the same in PROGRESS.md and audit/), and a commit adding more lines than it removes
says why on a line starting `Why:`."""

import re
import subprocess
import sys

UTC = re.compile(r"\b\d{1,2}:\d{2}(?::\d{2})?\s*UTC\b")
EASTERN = re.compile(r"\b\d{1,2}:\d{2}(?::\d{2})?\s*E[DS]T\b")


def unpaired(line):
    """Whether a line names more UTC times than Eastern ones."""
    return len(UTC.findall(line)) > len(EASTERN.findall(line))


def main(message_file):
    message = [l for l in open(message_file).read().splitlines() if not l.startswith("#")]
    errors = [f"UTC time without its Eastern time: {l}" for l in message if unpaired(l)]
    numstat = subprocess.run(["git", "diff", "--cached", "--numstat"], capture_output=True, text=True, check=True).stdout
    added = removed = 0
    for row in numstat.splitlines():
        a, r, _ = row.split("\t", 2)
        if a != "-":
            added, removed = added + int(a), removed + int(r)
    if added > removed and not any(l.startswith("Why:") for l in message):
        errors.append(f"adds {added} lines and removes {removed}: say why on a line starting 'Why:'")
    if errors:
        sys.exit("commit-msg: " + "\n            ".join(errors))


if __name__ == "__main__":
    main(sys.argv[1])
