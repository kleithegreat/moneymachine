"""The commit-msg hook (the dev shell sets core.hooksPath to .githooks): every UTC time has its Eastern time beside it
(ops/test_commitcheck.py checks the same in PROGRESS.md and audit/)."""

import re
import sys

UTC = re.compile(r"\b\d{1,2}:\d{2}(?::\d{2})?\s*UTC\b")
EASTERN = re.compile(r"\b\d{1,2}:\d{2}(?::\d{2})?\s*E[DS]T\b")


def unpaired(line):
    return len(UTC.findall(line)) > len(EASTERN.findall(line))


def main(message_file) -> None:
    message = [l for l in open(message_file).read().splitlines() if not l.startswith("#")]
    errors = [f"UTC time without its Eastern time: {l}" for l in message if unpaired(l)]
    if errors:
        sys.exit("commit-msg: " + "\n            ".join(errors))


if __name__ == "__main__":
    main(sys.argv[1])
