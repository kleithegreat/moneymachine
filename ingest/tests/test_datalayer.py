"""The data layer fetches only feeds whose hosts have certified terms, and keeps every body with its poll times."""

import gzip
import hashlib
import json
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any

import httpx
import pytest

from ingest import datalayer, live


def test_every_declared_feed_has_certified_terms() -> None:
    assert datalayer.feeds()["feeds"]


def test_a_feed_without_certified_terms_is_refused(tmp_path: Path) -> None:
    spec = {
        "user_agent": "x",
        "feeds": [{"name": "x", "source": "ecb", "every_h": 1, "url": "https://example.org/data"}],
    }
    (tmp_path / "f.json").write_text(json.dumps(spec))
    with pytest.raises(PermissionError):
        datalayer.feeds(tmp_path / "f.json")


def test_poll_keeps_the_body_content_addressed_with_its_times(tmp_path: Path) -> None:
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=b"<data/>")))
    feed = {"name": "ecb-exr", "url": "https://data-api.ecb.europa.eu/service/data/EXR/x", "every_h": 6}
    rec = datalayer.poll(http, feed, tmp_path)
    assert datalayer.body(tmp_path, rec["sha256"]) == b"<data/>"
    assert rec["status"] == 200 and rec["sent"] <= rec["recv"]
    assert [p["feed"] for p in live.read(tmp_path, "datalayer")] == ["ecb-exr"]
    assert datalayer.last_polls(tmp_path) == {"ecb-exr": rec["sent"]}


def test_discover_fetches_the_index_then_the_release_it_names(tmp_path: Path) -> None:
    bodies = {
        "/gdeltv2/lastupdate.txt": b"1 ab http://data.gdeltproject.org/gdeltv2/20261023184500.export.CSV.zip\n",
        "/gdeltv2/20261023184500.export.CSV.zip": b"zip",
    }
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=bodies[req.url.path])))
    feed = next(f for f in datalayer.feeds()["feeds"] if f["name"] == "gdelt-events")
    rec = datalayer.poll(http, feed, tmp_path)
    assert rec["url"] == "https://data.gdeltproject.org/gdeltv2/20261023184500.export.CSV.zip"
    assert datalayer.body(tmp_path, rec["sha256"]) == b"zip"
    assert [p["feed"] for p in live.read(tmp_path, "datalayer")] == ["gdelt-events/index", "gdelt-events"]
    assert set(datalayer.last_polls(tmp_path)) == {"gdelt-events"}


def test_a_discovered_url_without_certified_terms_is_refused(tmp_path: Path) -> None:
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=b"x")))
    feed = {
        "name": "x",
        "source": "gdelt",
        "every_h": 1,
        "discover": {"url": "https://data.gdeltproject.org/i", "pattern": "(x)", "template": "https://example.org/{}"},
    }
    with pytest.raises(PermissionError):
        datalayer.poll(http, feed, tmp_path)


def test_a_credential_is_sent_but_never_logged(tmp_path: Path) -> None:
    seen: list[httpx.Request] = []

    def respond(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, content=b"{}")

    http = httpx.Client(transport=httpx.MockTransport(respond))
    feed = {
        "name": "k",
        "url": "https://api.example.org/v1/x?series=A",
        "every_h": 1,
        "auth": {"param": "api_key", "env": "K"},
    }
    rec = datalayer.poll(http, feed, tmp_path, {"K": "s3cret"})
    assert seen[0].url.params["api_key"] == "s3cret" and seen[0].url.params["series"] == "A"
    ua = {
        "name": "u",
        "url": "https://api.example.org/v1/y",
        "every_h": 1,
        "auth": {"header": "User-Agent", "env": "U"},
    }
    datalayer.poll(http, ua, tmp_path, {"U": "Name name@example.org"})
    assert seen[1].headers["User-Agent"] == "Name name@example.org"
    echo = {"name": "e", "url": "https://api.example.org/v1/z", "every_h": 1, "auth": {"param": "key", "env": "K"}}
    echoed = httpx.Client(
        transport=httpx.MockTransport(lambda req: httpx.Response(200, content=b'{"UserID": "s3cret"}'))
    )
    stored = datalayer.body(tmp_path, datalayer.poll(echoed, echo, tmp_path, {"K": "s3cret"})["sha256"])
    assert stored == b'{"UserID": "<credential>"}'
    logged = "".join(p.read_text() for p in tmp_path.glob("datalayer-*.jsonl"))
    assert "s3cret" not in logged and "name@example.org" not in logged and rec["url"] == feed["url"]


def test_secrets_reads_name_value_lines(tmp_path: Path) -> None:
    (tmp_path / "k.env").write_text("# keys\nA=1\n\nB=x=y\n")
    assert datalayer.secrets(tmp_path / "k.env") == {"A": "1", "B": "x=y"}


# GPT's bug hunt (audit/reviews/2026-11-02-gpt-hunt-recorders.md), findings 1 and 2.
BODY = b"".join(bytes([i % 251, i % 241]) * 7 + i.to_bytes(4, "big") for i in range(200_000))
FETCH = """
import hashlib, resource, signal, sys
import httpx
from ingest import datalayer
from ingest.tests.test_datalayer import BODY
out, limit = sys.argv[1], int(sys.argv[2])
http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=BODY)))
feed = {"name": "ecb-exr", "url": "https://data-api.ecb.europa.eu/service/data/EXR/x", "every_h": 6}
if limit:
    signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
    resource.setrlimit(resource.RLIMIT_FSIZE, (limit, limit))
while True:
    try:
        datalayer.poll(http, feed, out)
    except OSError:
        sys.exit(3)
"""


def fetch_again(out: Path) -> dict[str, Any]:
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=BODY)))
    feed = {"name": "ecb-exr", "url": "https://data-api.ecb.europa.eu/service/data/EXR/x", "every_h": 6}
    record: dict[str, Any] = datalayer.poll(http, feed, out)
    return record


def test_a_body_write_that_fails_leaves_nothing_a_later_poll_of_the_same_body_reuses(tmp_path: Path) -> None:
    assert subprocess.run([sys.executable, "-c", FETCH, str(tmp_path), "4096"]).returncode == 3
    assert datalayer.body(tmp_path, fetch_again(tmp_path)["sha256"]) == BODY


@pytest.mark.local
def test_a_recorder_killed_while_writing_a_body_leaves_every_logged_body_readable(tmp_path: Path) -> None:
    child = subprocess.Popen([sys.executable, "-c", FETCH, str(tmp_path), "0"])
    raw = tmp_path / "raw"
    while not raw.exists():
        time.sleep(0.0005)
    child.send_signal(signal.SIGKILL)
    child.wait()
    rec = fetch_again(tmp_path)
    assert datalayer.body(tmp_path, rec["sha256"]) == BODY
    assert all(datalayer.body(tmp_path, p["sha256"]) == BODY for p in live.read(tmp_path, "datalayer"))


def test_a_torn_log_line_does_not_stop_a_restart(tmp_path: Path) -> None:
    rec = fetch_again(tmp_path)
    log = next(tmp_path.glob("datalayer-*.jsonl"))
    with open(log, "a") as f:
        f.write('{"feed":"ecb-exr","sent":')
    assert datalayer.last_polls(tmp_path) == {"ecb-exr": rec["sent"]}


# GPT's review of the bundle (audit/reviews/2026-11-02-gpt-thesis-fixes.md), F8: a body the old writer damaged.
def damaged_on_disk(out: Path) -> tuple[Path, bytes]:
    """The body's final .gz as the old writer's killed run could leave it, with the bytes it holds."""
    raw = out / "raw" / f"{hashlib.sha256(BODY).hexdigest()}.gz"
    raw.parent.mkdir(parents=True)
    bad = gzip.compress(BODY)[:4096]
    raw.write_bytes(bad)
    return raw, bad


def test_a_truncated_final_body_is_rewritten_when_its_content_returns(tmp_path: Path) -> None:
    damaged_on_disk(tmp_path)
    assert datalayer.body(tmp_path, fetch_again(tmp_path)["sha256"]) == BODY


def test_a_damaged_body_keeps_its_bytes_and_the_repair_is_on_the_record(tmp_path: Path) -> None:
    raw, bad = damaged_on_disk(tmp_path)
    fetch_again(tmp_path)
    [(repair)] = list(live.read(tmp_path, "repairs"))
    assert (
        repair["sha256"] == raw.name.removesuffix(".gz") and repair["damaged_sha256"] == hashlib.sha256(bad).hexdigest()
    )
    assert (
        (raw.parent / repair["kept"]).read_bytes() == bad
        and repair["feed"] == "ecb-exr"
        and repair["bytes"] == len(bad)
    )


def test_a_body_with_other_content_under_its_name_is_repaired_too(tmp_path: Path) -> None:
    raw, _ = damaged_on_disk(tmp_path)
    raw.write_bytes(gzip.compress(b"something else"))
    assert datalayer.body(tmp_path, fetch_again(tmp_path)["sha256"]) == BODY


def test_an_intact_body_is_left_alone_with_nothing_to_record(tmp_path: Path) -> None:
    fetch_again(tmp_path)
    raw = next((tmp_path / "raw").glob("*.gz"))
    before = raw.stat().st_mtime_ns
    fetch_again(tmp_path)
    assert raw.stat().st_mtime_ns == before and list(live.read(tmp_path, "repairs")) == []


def test_a_damaged_discovery_index_does_not_stop_the_poll(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    index = b'<a href="file-7.csv">'
    raw = tmp_path / "raw" / f"{hashlib.sha256(index).hexdigest()}.gz"
    raw.parent.mkdir(parents=True)
    raw.write_bytes(gzip.compress(index)[:6])
    http = httpx.Client(
        transport=httpx.MockTransport(
            lambda req: httpx.Response(200, content=index if "index" in str(req.url) else b"csv")
        )
    )
    feed = {
        "name": "d",
        "source": "x",
        "every_h": 1,
        "discover": {
            "url": "https://api.example.org/index",
            "pattern": r"file-(\d+)\.csv",
            "template": "https://api.example.org/file-{}.csv",
        },
    }
    monkeypatch.setattr(datalayer, "certify", lambda feed, url: None)
    assert datalayer.poll(http, feed, tmp_path, {})["url"].endswith("file-7.csv")


@pytest.mark.local
def test_a_recorder_killed_during_a_repair_keeps_the_damaged_bytes_and_repairs_on_restart(tmp_path: Path) -> None:
    raw, bad = damaged_on_disk(tmp_path)
    child = subprocess.Popen([sys.executable, "-c", FETCH, str(tmp_path), "0"])
    while not list(raw.parent.glob("*.damaged-*")):
        time.sleep(0.0002)
    child.send_signal(signal.SIGKILL)
    child.wait()
    assert datalayer.body(tmp_path, fetch_again(tmp_path)["sha256"]) == BODY
    assert [p.read_bytes() for p in raw.parent.glob("*.damaged-*")] == [bad]


# GPT's round 2 review (audit/reviews/2026-11-02-gpt-thesis-round2.md), B5: a kill at each step of a repair.
KILLED_AT = """
import os, signal, sys
import httpx
from ingest import datalayer
from ingest.tests.test_datalayer import BODY
out, step = sys.argv[1], sys.argv[2]
def killed(f):
    def g(*a, **k):
        f(*a, **k)
        os.kill(os.getpid(), signal.SIGKILL)
    return g
if step == "record":
    datalayer.append = killed(datalayer.append)
else:
    datalayer.os.replace = killed(datalayer.os.replace)
http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=BODY)))
datalayer.poll(http, {"name": "ecb-exr", "url": "https://data-api.ecb.europa.eu/service/data/EXR/x", "every_h": 6}, out)
"""


@pytest.mark.local
@pytest.mark.parametrize("step", ["record", "move"])
def test_a_repair_killed_after_any_step_is_on_the_record_with_its_damaged_bytes(tmp_path: Path, step: str) -> None:
    raw, bad = damaged_on_disk(tmp_path)
    assert subprocess.run([sys.executable, "-c", KILLED_AT, str(tmp_path), step]).returncode == -signal.SIGKILL
    assert datalayer.body(tmp_path, fetch_again(tmp_path)["sha256"]) == BODY
    repairs = list(live.read(tmp_path, "repairs"))
    assert repairs and all((raw.parent / r["kept"]).read_bytes() == bad for r in repairs)


def _gdelt_feed() -> dict[str, Any]:
    feed: dict[str, Any] = next(f for f in datalayer.feeds()["feeds"] if f["name"] == "gdelt-events")
    return feed


def test_discover_retries_404_until_200_and_logs_both_in_order(tmp_path: Path) -> None:
    feed = _gdelt_feed()
    index_body = b"1 ab http://data.gdeltproject.org/gdeltv2/20261023184500.export.CSV.zip\n"
    release_url = "https://data.gdeltproject.org/gdeltv2/20261023184500.export.CSV.zip"
    release_responses = iter([httpx.Response(404, content=b"missing"), httpx.Response(200, content=b"zip")])

    def respond(req: httpx.Request) -> httpx.Response:
        if req.url.path == "/gdeltv2/lastupdate.txt":
            return httpx.Response(200, content=index_body)
        return next(release_responses)

    http = httpx.Client(transport=httpx.MockTransport(respond))
    pending: dict[str, tuple[str, int]] = {}
    rec = datalayer.poll_with_retries(http, feed, tmp_path, {}, pending)
    assert rec["status"] == 404
    assert pending == {"gdelt-events": (release_url, datalayer.MAX_DISCOVER_RETRIES)}

    datalayer.retry_pending(http, [feed], tmp_path, {}, pending)
    assert pending == {}

    rows = list(live.read(tmp_path, "datalayer"))
    assert [(r["feed"], r["url"], r["status"]) for r in rows] == [
        ("gdelt-events/index", feed["discover"]["url"], 200),
        ("gdelt-events", release_url, 404),
        ("gdelt-events", release_url, 200),
    ]
    assert datalayer.body(tmp_path, rows[2]["sha256"]) == b"zip"


def test_discover_retries_exhaust_max_attempts_and_stop(tmp_path: Path) -> None:
    feed = _gdelt_feed()
    index_body = b"1 ab http://data.gdeltproject.org/gdeltv2/20261023190000.export.CSV.zip\n"
    release_url = "https://data.gdeltproject.org/gdeltv2/20261023190000.export.CSV.zip"
    release_fetches = 0

    def respond(req: httpx.Request) -> httpx.Response:
        nonlocal release_fetches
        if req.url.path == "/gdeltv2/lastupdate.txt":
            return httpx.Response(200, content=index_body)
        release_fetches += 1
        return httpx.Response(404, content=b"missing")

    http = httpx.Client(transport=httpx.MockTransport(respond))
    pending: dict[str, tuple[str, int]] = {}
    datalayer.poll_with_retries(http, feed, tmp_path, {}, pending)
    assert release_fetches == 1

    for left in range(datalayer.MAX_DISCOVER_RETRIES, 0, -1):
        assert pending == {"gdelt-events": (release_url, left)}
        datalayer.retry_pending(http, [feed], tmp_path, {}, pending)

    assert pending == {}
    assert release_fetches == 1 + datalayer.MAX_DISCOVER_RETRIES
    datalayer.retry_pending(http, [feed], tmp_path, {}, pending)
    assert release_fetches == 1 + datalayer.MAX_DISCOVER_RETRIES


def test_newer_index_discovery_supersedes_older_pending_url(tmp_path: Path) -> None:
    feed = _gdelt_feed()
    url1 = "https://data.gdeltproject.org/gdeltv2/20261023191500.export.CSV.zip"
    url2 = "https://data.gdeltproject.org/gdeltv2/20261023193000.export.CSV.zip"
    url3 = "https://data.gdeltproject.org/gdeltv2/20261023194500.export.CSV.zip"
    index_replies = iter(
        [
            httpx.Response(200, content=b"1 ab http://data.gdeltproject.org/gdeltv2/20261023191500.export.CSV.zip\n"),
            httpx.Response(503, content=b"down"),
            httpx.Response(200, content=b"no match here"),
            httpx.Response(200, content=b"1 ab http://data.gdeltproject.org/gdeltv2/20261023193000.export.CSV.zip\n"),
            httpx.Response(200, content=b"1 ab http://data.gdeltproject.org/gdeltv2/20261023194500.export.CSV.zip\n"),
        ]
    )
    release_replies = {
        "/gdeltv2/20261023191500.export.CSV.zip": httpx.Response(404, content=b"missing"),
        "/gdeltv2/20261023193000.export.CSV.zip": httpx.Response(404, content=b"missing"),
        "/gdeltv2/20261023194500.export.CSV.zip": httpx.Response(200, content=b"zip3"),
    }

    def respond(req: httpx.Request) -> httpx.Response:
        if req.url.path == "/gdeltv2/lastupdate.txt":
            return next(index_replies)
        return release_replies[req.url.path]

    http = httpx.Client(transport=httpx.MockTransport(respond))
    pending: dict[str, tuple[str, int]] = {}

    datalayer.poll_with_retries(http, feed, tmp_path, {}, pending)
    assert pending == {"gdelt-events": (url1, datalayer.MAX_DISCOVER_RETRIES)}

    datalayer.poll_with_retries(http, feed, tmp_path, {}, pending)
    assert pending == {"gdelt-events": (url1, datalayer.MAX_DISCOVER_RETRIES)}

    datalayer.poll_with_retries(http, feed, tmp_path, {}, pending)
    assert pending == {"gdelt-events": (url1, datalayer.MAX_DISCOVER_RETRIES)}

    datalayer.poll_with_retries(http, feed, tmp_path, {}, pending)
    assert pending == {"gdelt-events": (url2, datalayer.MAX_DISCOVER_RETRIES)}

    rec = datalayer.poll_with_retries(http, feed, tmp_path, {}, pending)
    assert rec["url"] == url3 and rec["status"] == 200
    assert pending == {}


@pytest.mark.parametrize("status", [400, 403])
def test_non_retryable_status_does_not_queue_or_keep_pending(tmp_path: Path, status: int) -> None:
    feed = _gdelt_feed()
    url1 = "https://data.gdeltproject.org/gdeltv2/20261023200000.export.CSV.zip"

    def respond_poll(req: httpx.Request) -> httpx.Response:
        if req.url.path == "/gdeltv2/lastupdate.txt":
            return httpx.Response(
                200, content=b"1 ab http://data.gdeltproject.org/gdeltv2/20261023200000.export.CSV.zip\n"
            )
        return httpx.Response(status, content=b"refused")

    http = httpx.Client(transport=httpx.MockTransport(respond_poll))
    pending: dict[str, tuple[str, int]] = {
        "gdelt-events": ("https://data.gdeltproject.org/gdeltv2/old.export.CSV.zip", 4)
    }
    rec = datalayer.poll_with_retries(http, feed, tmp_path, {}, pending)
    assert rec["status"] == status
    assert pending == {}

    pending["gdelt-events"] = (url1, 5)
    datalayer.retry_pending(http, [feed], tmp_path, {}, pending)
    assert pending == {}


def test_network_error_is_retried_and_succeeds_on_200(tmp_path: Path) -> None:
    feed = _gdelt_feed()
    release_url = "https://data.gdeltproject.org/gdeltv2/20261023201500.export.CSV.zip"
    attempts = 0

    def respond(req: httpx.Request) -> httpx.Response:
        nonlocal attempts
        if req.url.path == "/gdeltv2/lastupdate.txt":
            return httpx.Response(
                200, content=b"1 ab http://data.gdeltproject.org/gdeltv2/20261023201500.export.CSV.zip\n"
            )
        attempts += 1
        if attempts == 1:
            raise httpx.ReadTimeout("timed out", request=req)
        return httpx.Response(200, content=b"zip-after-timeout")

    http = httpx.Client(transport=httpx.MockTransport(respond))
    pending: dict[str, tuple[str, int]] = {}
    rec = datalayer.poll_with_retries(http, feed, tmp_path, {}, pending)
    assert rec["status"] is None
    assert pending == {"gdelt-events": (release_url, datalayer.MAX_DISCOVER_RETRIES)}

    datalayer.retry_pending(http, [feed], tmp_path, {}, pending)
    assert pending == {}
    rows = list(live.read(tmp_path, "datalayer"))
    assert [r["status"] for r in rows] == [200, None, 200]
    assert datalayer.body(tmp_path, rows[2]["sha256"]) == b"zip-after-timeout"


def test_uncertified_discovered_url_raises_before_fetching(tmp_path: Path) -> None:
    seen: list[str] = []

    def respond(req: httpx.Request) -> httpx.Response:
        seen.append(str(req.url))
        return httpx.Response(200, content=b"x")

    http = httpx.Client(transport=httpx.MockTransport(respond))
    feed = {
        "name": "x",
        "source": "gdelt",
        "every_h": 1,
        "discover": {"url": "https://data.gdeltproject.org/i", "pattern": "(x)", "template": "https://example.org/{}"},
    }
    pending: dict[str, tuple[str, int]] = {}
    with pytest.raises(PermissionError):
        datalayer.poll_with_retries(http, feed, tmp_path, {}, pending)
    assert seen == ["https://data.gdeltproject.org/i"]
    assert pending == {}

    seen.clear()
    pending["x"] = ("https://example.org/x", 3)
    with pytest.raises(PermissionError):
        datalayer.retry_pending(http, [feed], tmp_path, {}, pending)
    assert seen == []


def test_main_retries_pending_on_ticks_without_delaying_index_schedule_or_other_feeds(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    gdelt = _gdelt_feed()
    ecb = {"name": "ecb-exr", "source": "ecb", "every_h": 6, "url": "https://data-api.ecb.europa.eu/service/data/EXR/x"}
    fake_now = 1_000_000_000

    class FakeStop(threading.Event):
        def __init__(self) -> None:
            super().__init__()
            self.ticks = 0

        def wait(self, timeout: float | None = None) -> bool:
            nonlocal fake_now
            if timeout is not None:
                fake_now += int(timeout * 1000)
                if timeout == datalayer.TICK:
                    self.ticks += 1
                    if self.ticks >= 16:
                        self.set()
            return self.is_set()

    index_calls = 0
    url1 = "https://data.gdeltproject.org/gdeltv2/20261023203000.export.CSV.zip"
    url2 = "https://data.gdeltproject.org/gdeltv2/20261023204500.export.CSV.zip"
    url1_attempts = 0

    def respond(req: httpx.Request) -> httpx.Response:
        nonlocal index_calls, url1_attempts
        if req.url.path == "/gdeltv2/lastupdate.txt":
            index_calls += 1
            if index_calls == 1:
                return httpx.Response(
                    200, content=b"1 ab http://data.gdeltproject.org/gdeltv2/20261023203000.export.CSV.zip\n"
                )
            return httpx.Response(
                200, content=b"1 ab http://data.gdeltproject.org/gdeltv2/20261023204500.export.CSV.zip\n"
            )
        if req.url.path == "/gdeltv2/20261023203000.export.CSV.zip":
            url1_attempts += 1
            return httpx.Response(404, content=b"missing") if url1_attempts < 3 else httpx.Response(200, content=b"z1")
        if req.url.path == "/gdeltv2/20261023204500.export.CSV.zip":
            return httpx.Response(200, content=b"z2")
        return httpx.Response(200, content=b"<ecb/>")

    client = httpx.Client(transport=httpx.MockTransport(respond))
    monkeypatch.setattr(datalayer, "now_ms", lambda: fake_now)
    monkeypatch.setattr(datalayer, "recording", lambda _out: FakeStop())
    monkeypatch.setattr(datalayer, "feeds", lambda: {"user_agent": "test", "feeds": [gdelt, ecb]})
    monkeypatch.setattr(datalayer, "secrets", dict)
    monkeypatch.setattr(httpx, "Client", lambda **_kwargs: client)

    datalayer.main(tmp_path)

    rows = list(live.read(tmp_path, "datalayer"))
    assert [(r["feed"], r["url"], r["status"]) for r in rows] == [
        ("gdelt-events/index", gdelt["discover"]["url"], 200),
        ("gdelt-events", url1, 404),
        ("ecb-exr", ecb["url"], 200),
        ("gdelt-events", url1, 404),
        ("gdelt-events", url1, 200),
        ("gdelt-events/index", gdelt["discover"]["url"], 200),
        ("gdelt-events", url2, 200),
    ]
    assert rows[1]["sent"] < rows[2]["sent"] < rows[3]["sent"] < rows[4]["sent"] < rows[5]["sent"]
    assert rows[5]["sent"] - rows[1]["sent"] >= 900_000
    assert rows[5]["sent"] - rows[1]["sent"] < 960_000
    assert datalayer.body(tmp_path, rows[4]["sha256"]) == b"z1"
    assert datalayer.body(tmp_path, rows[6]["sha256"]) == b"z2"
