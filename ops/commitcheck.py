"""The commit-msg hook (the dev shell sets core.hooksPath to .githooks): every UTC time has its Eastern time beside it
(ops/test_commitcheck.py checks the same in PROGRESS.md and audit/)."""

import re
import sys
from pathlib import Path

UTC = re.compile(r"\b\d{1,2}:\d{2}(?::\d{2})?\s*UTC\b")
EASTERN = re.compile(r"\b\d{1,2}:\d{2}(?::\d{2})?\s*E[DS]T\b")


def unpaired(line: str) -> bool:
    return len(UTC.findall(line)) > len(EASTERN.findall(line))


def main(message_file: str) -> None:
    lines = Path(message_file).read_text().splitlines()
    message = [line for line in lines if not line.startswith("#")]
    errors = [f"UTC time without its Eastern time: {line}" for line in message if unpaired(line)]
    if errors:
        sys.exit("commit-msg: " + "\n            ".join(errors))


if __name__ == "__main__":
    main(sys.argv[1])
