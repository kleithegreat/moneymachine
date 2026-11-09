"""Independent synthetic examples from recorder docstrings, CLUSTER §2/§5 and paper §5.

Only signatures/docstrings of production functions were inspected. No recording,
credential, network service or cluster is used. Gaps are not filled by readers;
certification of gap lengths and NTP freshness belongs to separate instruments.
"""

import ctypes
import gzip
import json
import signal
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any

import httpx
import pytest

from ingest import datalayer, live, record, sources_record
from ops import live as mirror


def test_utc_days_preserve_prefixes_and_do_not_invent_gap_rows(tmp_path: Path) -> None:
    """Epoch -1 is 1969-12-31; 0 and 86,399,999 share Jan 1; 172,800,000 is Jan 3."""
    rows = [{"n": n} for n in range(4)]
    for t, row in zip([-1, 0, 86_399_999, 172_800_000], rows):
        before = {p: p.read_bytes() for p in tmp_path.glob("*.jsonl")}
        live.append(tmp_path, "poll", t, row)
        assert all(p.read_bytes().startswith(data) for p, data in before.items())
    assert sorted(len(p.read_text().splitlines()) for p in tmp_path.glob("*.jsonl")) == [1, 1, 2]
    assert list(live.read(tmp_path, "poll")) == rows
    assert list(live.read(tmp_path, "absent")) == []


@pytest.mark.parametrize("tail", [b'{"cut":', b'{"cut":\n'])
def test_torn_records_are_named_skipped_and_never_overwritten(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], tail: bytes
) -> None:
    """Two acknowledged rows straddle one invalid line; all old bytes survive append."""
    live.append(tmp_path, "poll", 0, {"n": 1})
    path = next(tmp_path.glob("poll-*.jsonl"))
    prefix = path.read_bytes() + tail
    path.write_bytes(prefix)
    live.append(tmp_path, "poll", 0, {"n": 2})
    assert path.read_bytes().startswith(prefix)
    assert list(live.read(tmp_path, "poll")) == [{"n": 1}, {"n": 2}]
    assert path.name in capsys.readouterr().err


@pytest.mark.parametrize("tail", [b"\xc3", b"\xe2\x82", b"\xf0\x9f\x98"])
def test_torn_utf8_record_is_skipped_without_hiding_acknowledged_rows(
    tmp_path: Path, capsys: pytest.CaptureFixture[str], tail: bytes
) -> None:
    """A kill can split a UTF-8 character, not only JSON punctuation; intact Unicode still decodes."""
    path = tmp_path / "poll-19700101.jsonl"
    path.write_bytes('{"text":"é"}\n{"text":"'.encode() + tail)
    prefix = path.read_bytes()
    live.append(tmp_path, "poll", 0, {"n": 2})
    assert path.read_bytes().startswith(prefix)
    assert list(live.read(tmp_path, "poll")) == [{"text": "é"}, {"n": 2}]
    assert f"{path}:2" in capsys.readouterr().err


def kill_after_ack(code: str, root: Path) -> None:
    """SIGKILL a real child only after its explicit acknowledgement; never wait by sleeping."""
    child = subprocess.Popen(
        [sys.executable, "-c", code, str(root)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        assert child.stdout is not None
        assert child.stdout.readline().strip() == "ACK"
        child.kill()
        assert child.wait(timeout=10) == -signal.SIGKILL
    finally:
        if child.poll() is None:
            child.kill()
        child.communicate(timeout=10)


@pytest.mark.parametrize("tail", [b'{"torn":', b'{"text":"\xc3'])
def test_acknowledged_append_survives_sigkill_and_torn_successor(tmp_path: Path, tail: bytes) -> None:
    """An acknowledged row survives process death; a subsequent half-row is skipped."""
    kill_after_ack(
        "import os,sys,time\nfrom ingest.live import append\n"
        "from pathlib import Path\np=Path(sys.argv[1])\n"
        "append(p,'poll',0,{'n':1})\n"
        "with next(p.glob('poll-*.jsonl')).open('ab',buffering=0) as f:\n"
        f" f.write({tail!r})\n os.fsync(f.fileno())\n"
        " print('ACK',flush=True)\n time.sleep(60)\n",
        tmp_path,
    )
    live.append(tmp_path, "poll", 0, {"n": 2})
    assert list(live.read(tmp_path, "poll")) == [{"n": 1}, {"n": 2}]


def test_one_writer_and_sigterm_wakes_stop_event(tmp_path: Path) -> None:
    """CLUSTER §2: a second writer exits; SIGTERM wakes the owner without killing it."""
    child = subprocess.Popen(
        [
            sys.executable,
            "-c",
            "import sys\nfrom ingest.live import recording\n"
            "s=recording(sys.argv[1])\nprint('LOCKED',flush=True)\n"
            "assert s.wait(30)\nprint('STOPPED',flush=True)\n",
            str(tmp_path),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        assert child.stdout is not None
        assert child.stdout.readline().strip() == "LOCKED"
        other = subprocess.run(
            [
                sys.executable,
                "-c",
                "import sys\nfrom ingest.live import recording\nrecording(sys.argv[1])",
                str(tmp_path),
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        assert other.returncode != 0
        child.send_signal(signal.SIGTERM)
        assert child.communicate(timeout=10)[0].strip() == "STOPPED"
        assert child.returncode == 0
    finally:
        if child.poll() is None:
            child.kill()
            child.communicate(timeout=10)


@pytest.fixture
def recorder(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> record.Recorder:
    """A listed BTC recorder with no HTTP client and a controlled local clock."""
    monkeypatch.setattr(record, "Info", lambda *args: None)
    monkeypatch.setattr(record, "now_ms", lambda: 0)
    return record.Recorder(120, ["BTC"], tmp_path)


@pytest.mark.parametrize(
    "hour,expected", [(0, {"funding", "bar"}), (3_600_000, {"funding"}), (14_400_000, {"funding", "bar"})]
)
def test_only_four_hour_boundaries_request_bars(recorder: record.Recorder, hour: int, expected: set[str]) -> None:
    assert set(recorder.kinds(hour)) == expected


def test_boundary_poll_waits_five_seconds_and_retries_after_thirty(
    recorder: record.Recorder, monkeypatch: pytest.MonkeyPatch
) -> None:
    """At H=3,600,000: no request at H+4,999; retries at H+5,000 and H+35,000."""
    calls: list[tuple[Any, ...]] = []

    def poll(*args: Any) -> bool:
        calls.append(args)
        return False

    monkeypatch.setattr(recorder, "poll", poll)
    for t, expected in [(3_604_999, 0), (3_605_000, 1), (3_634_999, 1), (3_635_000, 2)]:
        monkeypatch.setattr(record, "now_ms", lambda t=t: t)
        recorder.step()
        first = [call for call in calls if call[3] == "first"]
        assert len(first) == expected
    assert all(call[:3] == ("funding", "BTC", 3_600_000) for call in first)


def test_found_boundary_is_verified_once_at_ten_minutes(
    recorder: record.Recorder, monkeypatch: pytest.MonkeyPatch
) -> None:
    """H=3,600,000: a found first row is re-polled at 4,200,000, not 4,199,999."""
    calls: list[tuple[Any, ...]] = []

    def poll(*args: Any) -> bool:
        calls.append(args)
        return True

    monkeypatch.setattr(recorder, "poll", poll)
    for t, expected in [(3_605_000, 0), (4_199_999, 0), (4_200_000, 1), (4_200_001, 1)]:
        monkeypatch.setattr(record, "now_ms", lambda t=t: t)
        recorder.step()
        verifies = [call for call in calls if call[2:] == (3_600_000, "verify")]
        assert len(verifies) == expected


def test_l2_preserves_server_time_and_local_send_receive_times(
    recorder: record.Recorder, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A snapshot time of 7 is neither the local send 100 nor receive 160, nor an NTP offset."""

    class Info:
        def l2_book(self, coin: str, sig_figs: int | None = None) -> dict[str, Any]:
            assert coin == "BTC"
            return {"time": 7, "levels": [], "precision": sig_figs}

    recorder.l2_info = Info()
    times = iter([100, 160])
    monkeypatch.setattr(record, "now_ms", lambda: next(times))
    rows: list[dict[str, Any]] = []
    monkeypatch.setattr(recorder, "log", rows.append)
    recorder.poll_l2("BTC")
    assert len(rows) == 1
    assert (rows[0]["sent"], rows[0]["recv"], rows[0]["data"]["time"]) == (100, 160, 7)
    assert rows[0]["data"]["precision"] is None
    assert rows[0]["agg"]["precision"] == 4


def get_body(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    content: bytes = b"abc",
    status: int = 200,
    auth: tuple[dict[str, str], dict[str, str]] = ({}, {}),
) -> dict[str, Any]:
    """Synthetic HTTP response; SHA256('abc') is the published 64-digit test vector."""
    times = iter([100, 160])
    monkeypatch.setattr(datalayer, "now_ms", lambda: next(times, 160))
    with httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(status, content=content))) as http:
        row: dict[str, Any] = datalayer.get(http, "synthetic", "https://example.invalid/feed", None, tmp_path, auth)
    return row


def test_datalayer_keeps_body_before_row_and_receive_clock(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """'abc' has 3 bytes; recorder timestamps are 100/160, never a source-supplied knownAt."""
    original = datalayer.append
    seen: list[dict[str, Any]] = []

    def check_body_first(out: Path, prefix: str, t: int, row: dict[str, Any]) -> Any:
        assert datalayer.body(out, row["sha256"]) == b"abc"
        seen.append(row)
        return original(out, prefix, t, row)

    monkeypatch.setattr(datalayer, "append", check_body_first)
    row = get_body(tmp_path, monkeypatch)
    assert row["sha256"] == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    assert (row["sent"], row["recv"], row["status"], row["bytes"]) == (100, 160, 200, 3)
    assert seen == [row]
    assert datalayer.last_polls(tmp_path).keys() == {"synthetic"}


@pytest.mark.parametrize("content,status", [(b"", 200), (b"unavailable", 503)])
def test_empty_and_error_responses_are_recorded_not_synthetic_successes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, content: bytes, status: int
) -> None:
    row = get_body(tmp_path, monkeypatch, content, status)
    assert row["status"] == status
    assert row["bytes"] == len(content)
    assert datalayer.body(tmp_path, row["sha256"]) == content


def test_credentials_are_removed_before_hashing_and_logging(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    row = get_body(tmp_path, monkeypatch, b"token=private-secret", auth=({"key": "private-secret"}, {}))
    assert datalayer.body(tmp_path, row["sha256"]) == b"token=<credential>"
    assert "private-secret" not in json.dumps(row)
    assert all(b"private-secret" not in p.read_bytes() for p in tmp_path.glob("*.jsonl"))


def test_corrupted_body_is_preserved_and_repaired(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    row = get_body(tmp_path, monkeypatch)
    raw = tmp_path / "raw" / (row["sha256"] + ".gz")
    raw.write_bytes(b"damaged gzip")
    get_body(tmp_path, monkeypatch)
    assert datalayer.body(tmp_path, row["sha256"]) == b"abc"
    assert any(p.read_bytes() == b"damaged gzip" for p in tmp_path.rglob("*") if p.is_file())
    assert len(list(live.read(tmp_path, "repairs"))) == 1


def test_datalayer_acknowledged_response_survives_sigkill(tmp_path: Path) -> None:
    kill_after_ack(
        "import sys,time,httpx\nfrom ingest.datalayer import get\n"
        "h=httpx.Client(transport=httpx.MockTransport(lambda r:httpx.Response(200,content=b'abc')))\n"
        "get(h,'synthetic','https://example.invalid/feed',None,sys.argv[1])\n"
        "print('ACK',flush=True)\ntime.sleep(60)\n",
        tmp_path,
    )
    assert datalayer.last_polls(tmp_path).keys() == {"synthetic"}
    assert datalayer.body(tmp_path, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") == b"abc"


def test_kill_between_body_and_row_then_repoll_loses_no_acknowledged_body(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """CLUSTER §5: a body may precede its row, never the reverse; restart may reuse it."""
    kill_after_ack(
        "import sys,time,httpx\nfrom ingest import datalayer as d\n"
        "def pause(out,prefix,t,row):\n assert d.body(out,row['sha256'])==b'abc'\n"
        " print('ACK',flush=True)\n time.sleep(60)\n"
        "d.append=pause\n"
        "h=httpx.Client(transport=httpx.MockTransport(lambda r:httpx.Response(200,content=b'abc')))\n"
        "d.get(h,'synthetic','https://example.invalid/feed',None,sys.argv[1])\n",
        tmp_path,
    )
    assert datalayer.last_polls(tmp_path) == {}
    row = get_body(tmp_path, monkeypatch)
    assert datalayer.body(tmp_path, row["sha256"]) == b"abc"
    assert len(list((tmp_path / "raw").glob("*.gz"))) == 1


@pytest.mark.parametrize("status,unsynced", [(0, False), (0x40, True), (0x01, False)])
def test_kernel_clock_converts_microsecond_bounds_without_inventing_offsets(
    monkeypatch: pytest.MonkeyPatch, status: int, unsynced: bool
) -> None:
    """Linux adjtimex: 1500/250 µs are 1.5/0.25 ms; only STA_UNSYNC (0x40) marks unsynced."""

    class TimexPrefix(ctypes.Structure):
        _fields_ = [
            ("modes", ctypes.c_uint),
            ("offset", ctypes.c_long),
            ("freq", ctypes.c_long),
            ("maxerror", ctypes.c_long),
            ("esterror", ctypes.c_long),
            ("status", ctypes.c_int),
        ]

    class Libc:
        def adjtimex(self, pointer: Any) -> int:
            value = ctypes.cast(pointer, ctypes.POINTER(TimexPrefix)).contents
            value.maxerror, value.esterror, value.status = 1500, 250, status
            return 0

    monkeypatch.setattr(ctypes, "CDLL", lambda *args, **kwargs: Libc())
    reading = sources_record.kernel_clock()
    assert reading == {"maxerror_ms": 1.5, "esterror_ms": 0.25, "unsynced": unsynced}


@pytest.fixture
def volumes(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> tuple[Path, Path]:
    """The five CLUSTER volumes, all synthetic; verification must not wait for a CronJob."""
    app, out = tmp_path / "app", tmp_path / "mirror"
    for relative in ["data/live", "data/sources_live", "data/datalayer", "data/thesis", "data/agent"]:
        (app / relative).mkdir(parents=True)
    monkeypatch.setattr(mirror, "MIRROR_VERIFY_WAIT", 0)
    return app, out


def test_mirror_copies_malformed_bytes_and_catches_up_without_truncation(volumes: tuple[Path, Path]) -> None:
    app, out = volumes
    source = app / "data/live/poll-1970-01-01.jsonl"
    source.write_bytes(b'{"n":1}\n{"torn":')
    mirror.mirror(app, out)
    copied = out / "hl" / source.name
    assert copied.read_bytes() == source.read_bytes()
    with source.open("ab") as stream:
        stream.write(b'\n{"n":2}\n')
    mirror.verify(app, out)
    mirror.mirror(app, out)
    assert copied.read_bytes() == source.read_bytes()
    mirror.verify(app, out)
    for name in ["hl", "sources", "datalayer", "thesis", "agent"]:
        assert (out / name / "MANIFEST.json").is_file()


@pytest.mark.parametrize("damage", ["shrink", "rewrite", "vanish", "short_mirror"])
def test_mirror_refuses_lost_or_rewritten_history_without_advancing_manifest(
    volumes: tuple[Path, Path], damage: str
) -> None:
    app, out = volumes
    source = app / "data/live/poll-1970-01-01.jsonl"
    source.write_bytes(b'{"n":1}\n')
    mirror.mirror(app, out)
    manifest = out / "hl/MANIFEST.json"
    before = manifest.read_bytes()
    if damage == "shrink":
        source.write_bytes(b"{")
    elif damage == "rewrite":
        source.write_bytes(b'{"n":2}\n')
    elif damage == "vanish":
        source.unlink()
    else:
        (out / "hl" / source.name).write_bytes(b"{")
    with pytest.raises((Exception, SystemExit)):
        mirror.mirror(app, out)
    assert manifest.read_bytes() == before


@pytest.mark.parametrize("damage", ["source", "copy", "manifest", "empty"])
def test_verify_refuses_corruption_or_missing_expected_volume(volumes: tuple[Path, Path], damage: str) -> None:
    app, out = volumes
    source = app / "data/live/poll-1970-01-01.jsonl"
    source.write_bytes(b'{"n":1}\n')
    if damage != "empty":
        mirror.mirror(app, out)
    if damage == "source":
        source.write_bytes(b'{"n":2}\n')
    elif damage == "copy":
        (out / "hl" / source.name).write_bytes(b'{"n":2}\n')
    elif damage == "manifest":
        (out / "agent/MANIFEST.json").unlink()
    with pytest.raises((Exception, SystemExit)):
        mirror.verify(app, out)


def test_sqlite_snapshot_includes_committed_wal_and_passes_integrity(volumes: tuple[Path, Path]) -> None:
    app, out = volumes
    db = app / "data/agent/ledger.sqlite"
    with sqlite3.connect(db) as conn:
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("CREATE TABLE evidence(n INTEGER)")
        conn.execute("INSERT INTO evidence VALUES (7)")
        conn.commit()
        mirror.mirror(app, out)
        with sqlite3.connect(out / "agent/ledger.sqlite") as copied:
            assert copied.execute("PRAGMA integrity_check").fetchone() == ("ok",)
            assert copied.execute("SELECT n FROM evidence").fetchall() == [(7,)]
    mirror.verify(app, out)


def test_whole_files_refresh_and_transient_tmp_is_not_published(volumes: tuple[Path, Path]) -> None:
    app, out = volumes
    source = app / "data/datalayer/raw/body.gz"
    source.parent.mkdir()
    source.write_bytes(gzip.compress(b"abc"))
    (source.parent / "body.tmp").write_bytes(b"partial")
    mirror.mirror(app, out)
    assert (out / "datalayer/raw/body.gz").read_bytes() == source.read_bytes()
    assert not (out / "datalayer/raw/body.tmp").exists()
    source.write_bytes(gzip.compress(b"a longer replacement"))
    mirror.mirror(app, out)
    assert (out / "datalayer/raw/body.gz").read_bytes() == source.read_bytes()


def test_concurrent_day_growth_waits_for_the_next_mirror(
    volumes: tuple[Path, Path], monkeypatch: pytest.MonkeyPatch
) -> None:
    """A row and its body arriving during copy wait; the captured prefix stays byte-exact."""
    app, out = volumes
    source = app / "data/datalayer/polls-synthetic.jsonl"
    source.write_bytes(b'{"n":1}\n')
    original = mirror.sha256
    grew: list[bool] = []

    def grow_while_hashing(path: Path, size: int | None = None) -> Any:
        if Path(path).name == source.name and not grew:
            grew.append(True)
            raw = source.parent / "raw/new.gz"
            raw.parent.mkdir()
            raw.write_bytes(gzip.compress(b"abc"))
            with source.open("ab") as stream:
                stream.write(b'{"n":2}\n')
        return original(path, size)

    monkeypatch.setattr(mirror, "sha256", grow_while_hashing)
    mirror.mirror(app, out)
    assert grew == [True]
    assert (out / "datalayer" / source.name).read_bytes() == b'{"n":1}\n'
    mirror.mirror(app, out)
    assert (out / "datalayer" / source.name).read_bytes() == b'{"n":1}\n{"n":2}\n'
    assert gzip.decompress((out / "datalayer/raw/new.gz").read_bytes()) == b"abc"
    mirror.verify(app, out)
