import os
import shutil
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path

import pytest

FILTER = Path(__file__).parent / "oci/forward-window.exclude"


def test_forward_window_days_are_not_pulled(tmp_path):
    src, dst = tmp_path / "src", tmp_path / "dst"
    src.mkdir()
    dst.mkdir()
    days = [date(2026, 10, 20) + timedelta(d) for d in range(0, 120)]
    for d in days:
        (src / f"polls-{d:%Y%m%d}.jsonl").touch()
    (src / ".writer.lock").touch()
    subprocess.run(["rsync", "-a", f"--exclude-from={FILTER}", f"{src}/", f"{dst}/"], check=True)
    pulled = {p.name for p in dst.iterdir()}
    for d in days:
        inside = date(2026, 11, 1) <= d < date(2027, 1, 31)
        assert (f"polls-{d:%Y%m%d}.jsonl" in pulled) != inside, d
    assert ".writer.lock" in pulled


@pytest.fixture
def oracle_pull(tmp_path):
    root, source = tmp_path / "repo", tmp_path / "source"
    scripts, tools = root / "ops/oci", tmp_path / "bin"
    scripts.mkdir(parents=True)
    tools.mkdir()
    for name in ("pull.sh", "forward-window.exclude", "publish.py"):
        shutil.copy2(FILTER.parent / name, scripts / name)
    base = root / "data/live-oci"
    base.mkdir(parents=True)
    (base / "host.env").write_text("MM_OCI_ID=000000000001\nMM_OCI_IP=fixture.invalid\n")
    (base / "last-pull").write_text("last-good\n")
    (root / "PROGRESS.md").write_text("# Progress\n\n## Blockers\n\n")
    for volume in ("live", "clock", "datalayer", "sources_live"):
        (source / volume).mkdir(parents=True)
    destination = base / "000000000001/live"
    destination.mkdir(parents=True)
    (tools / "rsync").write_text(
        '#!/usr/bin/env bash\nargs=("$@")\nvolume="${args[-2]%/}"\nvolume="${volume##*/}"\n'
        'args[-2]="$FAKE_OCI/$volume/"\nexec "$LOCAL_RSYNC" "${args[@]}"\n')
    (tools / "rsync").chmod(0o755)

    def run():
        return subprocess.run(["bash", str(scripts / "pull.sh")], capture_output=True, text=True,
                              env={"PATH": f"{tools}:{os.environ['PATH']}", "HOME": str(tmp_path),
                                   "FAKE_OCI": str(source), "LOCAL_RSYNC": shutil.which("rsync")})

    return root, source / "live", destination, run


@pytest.mark.parametrize("incoming", [b"A\n", b"A\nC\n", b"A\nC\nD\n"])
def test_oracle_pull_refuses_a_source_that_does_not_extend_its_copy(oracle_pull, incoming):
    root, source, destination, run = oracle_pull
    name = "polls-20261020.jsonl"
    (source / name).write_bytes(incoming)
    (destination / name).write_bytes(b"A\nB\n")

    result = run()

    assert result.returncode != 0
    assert "no longer extends" in result.stderr
    assert (destination / name).read_bytes() == b"A\nB\n"
    assert (root / "data/live-oci/last-pull").read_text() == "last-good\n"
    report = (root / "PROGRESS.md").read_text()
    assert "Cloud recorder pull failing" in report and "no longer extends" in report


@pytest.mark.parametrize("incoming", [b"A\nB\n", b"A\nB\nC\n"])
def test_oracle_pull_accepts_an_identical_or_extended_source(oracle_pull, incoming):
    root, source, destination, run = oracle_pull
    name = "polls-20261020.jsonl"
    (source / name).write_bytes(incoming)
    (destination / name).write_bytes(b"A\nB\n")

    result = run()

    assert result.returncode == 0, result.stdout + result.stderr
    assert (destination / name).read_bytes() == incoming
    assert "Cloud recorder pull failing" not in (root / "PROGRESS.md").read_text()


@pytest.mark.parametrize("kill_first", [False, True])
def test_overlapping_pulls_preserve_the_longest_history(tmp_path, kill_first):
    short, long, destination = (tmp_path / name for name in ("short", "long", "destination"))
    for path in (short, long, destination):
        path.mkdir()
    name = "polls.jsonl"
    (destination / name).write_bytes(b"A\n")
    (short / name).write_bytes(b"A\nB\n")
    (long / name).write_bytes(b"A\nB\nC\n")
    publisher = FILTER.parent / "publish.py"
    pause = """
import runpy, sys
from pathlib import Path
module = runpy.run_path(sys.argv[1])
replace = Path.replace
def paused(path, target):
    print('before replace', flush=True)
    sys.stdin.readline()
    return replace(path, target)
Path.replace = paused
module['publish'](sys.argv[2], sys.argv[3])
"""
    first = subprocess.Popen([sys.executable, "-c", pause, str(publisher), str(short), str(destination)],
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    second = None
    try:
        assert first.stdout.readline() == "before replace\n"
        second = subprocess.Popen([sys.executable, str(publisher), str(long), str(destination)],
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            second.communicate(timeout=0.5)
        except subprocess.TimeoutExpired:
            pass
        if kill_first:
            first.kill()
            first.communicate(timeout=5)
        else:
            first.communicate(input="continue\n", timeout=5)
            assert first.returncode == 0
        _, error = second.communicate(timeout=5)
        assert second.returncode == 0, error
        assert (destination / name).read_bytes() == b"A\nB\nC\n"
    finally:
        for proc in (first, second):
            if proc is not None and proc.poll() is None:
                proc.kill()
                proc.communicate()
