"""The files that must pass `ruff format`, `ruff check` and `mypy --strict` (CLAUDE.md §2, "Write for the reader"),
one per line; the flake check `style` runs the three over them.

The code the deployed recorder image loads (the modules `ingest.sources_record` and `ingest.datalayer` import) is
excluded, since it changes only with the next image.
"""

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SKIPPED = {"data", "result", "__pycache__"}

_FROZEN_FILES = """
import json, sys
from pathlib import Path
from ingest import datalayer, sources_record
recorder = [m.__file__ for m in sys.modules.values() if getattr(m, "__file__", None) and m.__name__.startswith("ingest")]
hashed = {Path(f).resolve() for f in recorder}
print(json.dumps(sorted(str(p.relative_to(%r)) for p in hashed if p.is_relative_to(%r) and p.suffix == ".py")))
"""


def frozen() -> set[str]:
    """Repo-relative `.py` files the deployed recorder image loads."""
    code = _FROZEN_FILES % (str(REPO), str(REPO))
    out = subprocess.run([sys.executable, "-c", code], cwd=REPO, capture_output=True, text=True, check=True).stdout
    return set(json.loads(out))


def covered() -> list[str]:
    """Every `.py` file of the tree outside the frozen identities, build outputs and `data/`."""
    found: set[str] = set()
    for path in REPO.rglob("*.py"):
        parts = path.relative_to(REPO).parts
        if not any(part in SKIPPED or part.startswith((".", "target")) for part in parts):
            found.add(str(path.relative_to(REPO)))
    return sorted(found - frozen())


if __name__ == "__main__":
    print("\n".join(covered()))
