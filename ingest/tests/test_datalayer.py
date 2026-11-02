"""The data layer fetches only feeds whose hosts have certified terms, and keeps every body with its poll times."""

import gzip
import hashlib
import json
import signal
import subprocess
import sys
import time

import httpx
import pytest

from ingest import datalayer, live


def test_every_declared_feed_has_certified_terms():
    assert datalayer.feeds()["feeds"]


def test_a_feed_without_certified_terms_is_refused(tmp_path):
    spec = {"user_agent": "x", "feeds": [{"name": "x", "source": "ecb", "every_h": 1,
                                          "url": "https://example.org/data"}]}
    (tmp_path / "f.json").write_text(json.dumps(spec))
    with pytest.raises(PermissionError):
        datalayer.feeds(tmp_path / "f.json")


def test_poll_keeps_the_body_content_addressed_with_its_times(tmp_path):
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=b"<data/>")))
    feed = {"name": "ecb-exr", "url": "https://data-api.ecb.europa.eu/service/data/EXR/x", "every_h": 6}
    rec = datalayer.poll(http, feed, tmp_path)
    assert datalayer.body(tmp_path, rec["sha256"]) == b"<data/>"
    assert rec["status"] == 200 and rec["sent"] <= rec["recv"]
    assert [p["feed"] for p in live.read(tmp_path, "datalayer")] == ["ecb-exr"]
    assert datalayer.last_polls(tmp_path) == {"ecb-exr": rec["sent"]}


def test_discover_fetches_the_index_then_the_release_it_names(tmp_path):
    bodies = {"/gdeltv2/lastupdate.txt": b"1 ab http://data.gdeltproject.org/gdeltv2/20261023184500.export.CSV.zip\n",
              "/gdeltv2/20261023184500.export.CSV.zip": b"zip"}
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=bodies[req.url.path])))
    feed = next(f for f in datalayer.feeds()["feeds"] if f["name"] == "gdelt-events")
    rec = datalayer.poll(http, feed, tmp_path)
    assert rec["url"] == "https://data.gdeltproject.org/gdeltv2/20261023184500.export.CSV.zip"
    assert datalayer.body(tmp_path, rec["sha256"]) == b"zip"
    assert [p["feed"] for p in live.read(tmp_path, "datalayer")] == ["gdelt-events/index", "gdelt-events"]
    assert set(datalayer.last_polls(tmp_path)) == {"gdelt-events"}


def test_a_discovered_url_without_certified_terms_is_refused(tmp_path):
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=b"x")))
    feed = {"name": "x", "source": "gdelt", "every_h": 1,
            "discover": {"url": "https://data.gdeltproject.org/i", "pattern": "(x)", "template": "https://example.org/{}"}}
    with pytest.raises(PermissionError):
        datalayer.poll(http, feed, tmp_path)


def test_a_credential_is_sent_but_never_logged(tmp_path):
    seen = []
    http = httpx.Client(transport=httpx.MockTransport(lambda req: seen.append(req) or httpx.Response(200, content=b"{}")))
    feed = {"name": "k", "url": "https://api.example.org/v1/x?series=A", "every_h": 1,
            "auth": {"param": "api_key", "env": "K"}}
    rec = datalayer.poll(http, feed, tmp_path, {"K": "s3cret"})
    assert seen[0].url.params["api_key"] == "s3cret" and seen[0].url.params["series"] == "A"
    ua = {"name": "u", "url": "https://api.example.org/v1/y", "every_h": 1, "auth": {"header": "User-Agent", "env": "U"}}
    datalayer.poll(http, ua, tmp_path, {"U": "Name name@example.org"})
    assert seen[1].headers["User-Agent"] == "Name name@example.org"
    echo = {"name": "e", "url": "https://api.example.org/v1/z", "every_h": 1, "auth": {"param": "key", "env": "K"}}
    echoed = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=b'{"UserID": "s3cret"}')))
    stored = datalayer.body(tmp_path, datalayer.poll(echoed, echo, tmp_path, {"K": "s3cret"})["sha256"])
    assert stored == b'{"UserID": "<credential>"}'
    logged = "".join(p.read_text() for p in tmp_path.glob("datalayer-*.jsonl"))
    assert "s3cret" not in logged and "name@example.org" not in logged and rec["url"] == feed["url"]


def test_secrets_reads_name_value_lines(tmp_path):
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


def fetch_again(out):
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=BODY)))
    return datalayer.poll(http, {"name": "ecb-exr", "url": "https://data-api.ecb.europa.eu/service/data/EXR/x", "every_h": 6}, out)


def test_a_body_write_that_fails_leaves_nothing_a_later_poll_of_the_same_body_reuses(tmp_path):
    assert subprocess.run([sys.executable, "-c", FETCH, str(tmp_path), "4096"]).returncode == 3
    assert datalayer.body(tmp_path, fetch_again(tmp_path)["sha256"]) == BODY


def test_a_recorder_killed_while_writing_a_body_leaves_every_logged_body_readable(tmp_path):
    child = subprocess.Popen([sys.executable, "-c", FETCH, str(tmp_path), "0"])
    raw = tmp_path / "raw"
    while not raw.exists():
        time.sleep(0.0005)
    child.send_signal(signal.SIGKILL)
    child.wait()
    rec = fetch_again(tmp_path)
    assert datalayer.body(tmp_path, rec["sha256"]) == BODY
    assert all(datalayer.body(tmp_path, p["sha256"]) == BODY for p in live.read(tmp_path, "datalayer"))


def test_a_torn_log_line_does_not_stop_a_restart(tmp_path):
    rec = fetch_again(tmp_path)
    log = next(tmp_path.glob("datalayer-*.jsonl"))
    with open(log, "a") as f:
        f.write('{"feed":"ecb-exr","sent":')
    assert datalayer.last_polls(tmp_path) == {"ecb-exr": rec["sent"]}


# GPT's review of the bundle (audit/reviews/2026-11-02-gpt-thesis-fixes.md), F8: a body the old writer damaged.
def damaged_on_disk(out):
    """The body's final .gz as the old writer's killed run could leave it, with the bytes it holds."""
    raw = out / "raw" / f"{hashlib.sha256(BODY).hexdigest()}.gz"
    raw.parent.mkdir(parents=True)
    bad = gzip.compress(BODY)[:4096]
    raw.write_bytes(bad)
    return raw, bad


def test_a_truncated_final_body_is_rewritten_when_its_content_returns(tmp_path):
    damaged_on_disk(tmp_path)
    assert datalayer.body(tmp_path, fetch_again(tmp_path)["sha256"]) == BODY


def test_a_damaged_body_keeps_its_bytes_and_the_repair_is_on_the_record(tmp_path):
    raw, bad = damaged_on_disk(tmp_path)
    fetch_again(tmp_path)
    [(repair)] = list(live.read(tmp_path, "repairs"))
    assert repair["sha256"] == raw.name.removesuffix(".gz") and repair["damaged_sha256"] == hashlib.sha256(bad).hexdigest()
    assert (raw.parent / repair["kept"]).read_bytes() == bad and repair["feed"] == "ecb-exr" and repair["bytes"] == len(bad)


def test_a_body_with_other_content_under_its_name_is_repaired_too(tmp_path):
    raw, _ = damaged_on_disk(tmp_path)
    raw.write_bytes(gzip.compress(b"something else"))
    assert datalayer.body(tmp_path, fetch_again(tmp_path)["sha256"]) == BODY


def test_an_intact_body_is_left_alone_with_nothing_to_record(tmp_path):
    fetch_again(tmp_path)
    raw = next((tmp_path / "raw").glob("*.gz"))
    before = raw.stat().st_mtime_ns
    fetch_again(tmp_path)
    assert raw.stat().st_mtime_ns == before and list(live.read(tmp_path, "repairs")) == []


def test_a_damaged_discovery_index_does_not_stop_the_poll(tmp_path, monkeypatch):
    index = b'<a href="file-7.csv">'
    raw = tmp_path / "raw" / f"{hashlib.sha256(index).hexdigest()}.gz"
    raw.parent.mkdir(parents=True)
    raw.write_bytes(gzip.compress(index)[:6])
    http = httpx.Client(transport=httpx.MockTransport(lambda req: httpx.Response(200, content=index if "index" in str(req.url) else b"csv")))
    feed = {"name": "d", "source": "x", "every_h": 1,
            "discover": {"url": "https://api.example.org/index", "pattern": r"file-(\d+)\.csv", "template": "https://api.example.org/file-{}.csv"}}
    monkeypatch.setattr(datalayer, "certify", lambda feed, url: None)
    assert datalayer.poll(http, feed, tmp_path, {})["url"].endswith("file-7.csv")
