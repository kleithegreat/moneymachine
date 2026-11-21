"""ops/gpt.sh's jail: the reviewed directory is readable and read-only, the output directory writable, and nothing else
under $HOME (this repository, its data/ and token files) is visible."""

import os
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).with_name("gpt.sh")
REPO = Path(__file__).resolve().parent.parent


def jailed(tmp_path: Path, command: str) -> tuple[int, str]:
    review = tmp_path / "review"
    review.mkdir(exist_ok=True)
    (review / "seen.txt").write_text("visible\n")
    prompt = tmp_path / "prompt.txt"
    prompt.write_text("unused\n")
    out = tmp_path / "out"
    env = dict(os.environ, MM_GPT_EXEC=command)
    done = subprocess.run(
        ["bash", str(SCRIPT), str(review), "model", str(prompt), str(out)], env=env, capture_output=True, text=True
    )
    return done.returncode, (out / "run.log").read_text()


@pytest.mark.local
def test_reads_the_reviewed_directory(tmp_path: Path) -> None:
    code, log = jailed(tmp_path, "cat seen.txt")
    assert (code, log) == (0, "visible\n")


@pytest.mark.local
def test_cannot_write_the_reviewed_directory(tmp_path: Path) -> None:
    code, _ = jailed(tmp_path, "echo x > seen.txt")
    assert code != 0
    assert (tmp_path / "review" / "seen.txt").read_text() == "visible\n"


@pytest.mark.local
def test_writes_only_its_output_directory(tmp_path: Path) -> None:
    code, _ = jailed(tmp_path, "echo reply > /out/reply.md")
    assert code == 0
    assert (tmp_path / "out" / "reply.md").read_text() == "reply\n"


@pytest.mark.local
def test_sees_nothing_else_of_home(tmp_path: Path) -> None:
    code, log = jailed(tmp_path, f"ls -A {REPO} {Path.home() / 'repos'}; cat {REPO / 'CLAUDE.md'}")
    assert code != 0
    assert "No such file" in log
