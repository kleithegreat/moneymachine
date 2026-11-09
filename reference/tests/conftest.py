import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]


@pytest.fixture(scope="session")
def built_mmdump(session_build) -> None:
    session_build(
        "mmdump",
        lambda: subprocess.run(
            ["cargo", "build", "--release", "--offline", "-q"], cwd=REPO / "reference/mmdump", check=True
        ),
    )


@pytest.fixture(scope="session")
def built_refmm(session_build) -> None:
    session_build(
        "lean", lambda: subprocess.run(["lake", "build"], cwd=REPO / "reference/lean", check=True, capture_output=True)
    )
