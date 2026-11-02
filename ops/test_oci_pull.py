import os
import shutil
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path

import pytest

from ops.oci.publish import publish

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
    (base / "host.env").write_text("MM_OCI_ID=000000000001\nMM_OCI_IP=192.0.2.1\n")
    (base / "last-pull").write_text("last-good\n")
    (root / "PROGRESS.md").write_text("# Progress\n\n## Blockers\n\n- Existing blocker.\n\n## Qualifications\n\nUnchanged.\n")
    for volume in ("live", "clock", "datalayer", "sources_live"):
        (source / volume).mkdir(parents=True)
    destination = base / "000000000001/live"
    destination.mkdir(parents=True)
    (tools / "rsync").write_text(
        '#!/usr/bin/env bash\nprintf "%s\\n" "$@" >> "$RSYNC_ARGS"\n'
        'if [ -n "${RSYNC_ERROR:-}" ]; then printf "%s\\n" "$RSYNC_ERROR" >&2; exit 255; fi\n'
        'args=("$@")\nvolume="${args[-2]%/}"\nvolume="${volume##*/}"\n'
        'args[-2]="$FAKE_OCI/$volume/"\nexec "$LOCAL_RSYNC" "${args[@]}"\n')
    (tools / "rsync").chmod(0o755)

    def run(**extra_env):
        return subprocess.run(["bash", str(scripts / "pull.sh")], capture_output=True, text=True,
                              env={"PATH": f"{tools}:{os.environ['PATH']}", "HOME": str(tmp_path),
                                   "FAKE_OCI": str(source), "LOCAL_RSYNC": shutil.which("rsync"),
                                   "RSYNC_ARGS": str(root / "rsync.args"), **extra_env})

    return root, source / "live", destination, run


@pytest.mark.parametrize("incoming", [b"A\n", b"A\nC\n", b"A\nC\nD\n"])
def test_oracle_pull_refuses_a_source_that_does_not_extend_its_copy(oracle_pull, incoming):
    root, source, destination, run = oracle_pull
    name = "polls-20261020.jsonl"
    (source / name).write_bytes(incoming)
    (destination / name).write_bytes(b"A\nB\n")
    os.utime(source / name, (100, 100))
    os.utime(destination / name, (200, 200))

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


def test_oracle_pull_does_not_checksum_history(oracle_pull):
    root, source, destination, run = oracle_pull
    assert run().returncode == 0
    assert "--checksum" not in (root / "rsync.args").read_text().splitlines()


def test_publish_does_not_read_unchanged_hard_links(tmp_path, monkeypatch):
    source, destination = tmp_path / "stage", tmp_path / "destination"
    source.mkdir()
    destination.mkdir()
    target = destination / "polls.jsonl"
    target.write_bytes(b"history\n")
    (source / target.name).hardlink_to(target)
    original = Path.open

    def refuse_history_read(path, *args, **kwargs):
        assert path.name != target.name, "unchanged inode was opened for comparison"
        return original(path, *args, **kwargs)

    with monkeypatch.context() as patcher:
        patcher.setattr(Path, "open", refuse_history_read)
        publish(source, destination)
    assert target.read_bytes() == b"history\n"


@pytest.mark.parametrize("divergent", ["a.jsonl", "b.jsonl", "c.jsonl"])
def test_oracle_pull_publishes_healthy_files_despite_one_divergence(oracle_pull, divergent):
    root, source, destination, run = oracle_pull
    for name in ("a.jsonl", "b.jsonl", "c.jsonl"):
        (destination / name).write_bytes(b"old\n")
        (source / name).write_bytes(b"different\n" if name == divergent else b"old\nnew\n")
    (source / "new.jsonl").write_bytes(b"new file\n")
    result = run()
    assert result.returncode != 0 and divergent in result.stderr
    assert "no longer extends" in result.stderr
    for name in ("a.jsonl", "b.jsonl", "c.jsonl"):
        assert (destination / name).read_bytes() == (b"old\n" if name == divergent else b"old\nnew\n")
    assert (destination / "new.jsonl").read_bytes() == b"new file\n"
    assert (root / "data/live-oci/last-pull").read_text() == "last-good\n"


@pytest.mark.parametrize("names", [("a.jsonl", "b.jsonl"), ("a\ncontinuation.jsonl", "b.jsonl")])
def test_oracle_pull_reports_every_divergence_and_clears_the_blocker_after_recovery(oracle_pull, names):
    root, source, destination, run = oracle_pull
    progress = root / "PROGRESS.md"
    original = progress.read_bytes()
    for name in names:
        (destination / name).write_bytes(b"old\n")
        (source / name).write_bytes(b"divergent\n")
    result = run()
    report = progress.read_text()
    for name in names:
        (source / name).write_bytes(b"old\nnew\n")
    recovered = run()

    assert result.returncode != 0
    assert recovered.returncode == 0, recovered.stderr
    assert progress.read_bytes() == original
    assert all(name.replace("\n", " ") in result.stderr for name in names)
    assert result.stderr.count("no longer extends") == 2
    assert len(result.stderr.splitlines()) == 1 and "; " in result.stderr
    assert len(report.splitlines()) == len(original.decode().splitlines()) + 1


def test_oracle_pull_keeps_only_the_last_rsync_error_line_and_recovers(oracle_pull):
    root, source, destination, run = oracle_pull
    progress = root / "PROGRESS.md"
    original = progress.read_bytes()
    last_line = "rsync error: unexplained error (code 255) at io.c(232) [Receiver=3.4.1]"
    result = run(RSYNC_ERROR=f"ssh: connect to host 192.0.2.1 port 22: Connection timed out\n{last_line}")
    report = progress.read_text()
    last_good = (root / "data/live-oci/last-pull").read_text()
    recovered = run()

    assert result.returncode != 0 and recovered.returncode == 0
    assert progress.read_bytes() == original
    assert "192.0.2.1" not in report + result.stderr
    assert all(f"{volume}: {last_line}" in report for volume in ("live", "clock", "datalayer", "sources_live"))
    assert len(report.splitlines()) == len(original.decode().splitlines()) + 1
    assert last_good == "last-good\n"


def test_publish_replaces_a_recorder_status_file_and_still_refuses_a_diverged_log(tmp_path):
    source, destination = tmp_path / "staged", tmp_path / "copy"
    source.mkdir()
    destination.mkdir()
    (destination / "recorder.json").write_text('{"started": 1}')
    (source / "recorder.json").write_text('{"started": 2}')
    (destination / "day.jsonl").write_text("a\nb\n")
    (source / "day.jsonl").write_text("a\nc\n")
    with pytest.raises(SystemExit, match="day.jsonl"):
        publish(source, destination)
    assert (destination / "recorder.json").read_text() == '{"started": 2}'
    assert (destination / "day.jsonl").read_text() == "a\nb\n"


def test_publish_reports_all_divergences_on_one_line(tmp_path):
    source, destination = tmp_path / "source", tmp_path / "destination"
    source.mkdir()
    destination.mkdir()
    for name in ("a.jsonl", "b.jsonl"):
        (source / name).write_bytes(b"divergent\n")
        (destination / name).write_bytes(b"old\n")
    with pytest.raises(SystemExit) as error:
        publish(source, destination)
    assert error.value.code == "; ".join(f"{destination / name}: source no longer extends destination"
                                         for name in ("a.jsonl", "b.jsonl"))


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


def test_oracle_pull_skips_a_writer_s_transient_tmp_file(oracle_pull):
    """Claude's round 2 review, R7: rsync exits 24 when a listed `.tmp` vanishes before its copy."""
    root, source, destination, run = oracle_pull
    (source.parent / "datalayer/raw").mkdir()
    (source.parent / "datalayer/raw/ab.tmp").write_bytes(b"partial")
    assert run().returncode == 0
    assert not (destination.parent / "datalayer/raw/ab.tmp").exists()
