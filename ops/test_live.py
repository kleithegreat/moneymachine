"""The live workloads' manifests keep CLUSTER.md's boundaries: only live volumes, the token only in runners, the
datalayer keys only in its recorder, restricted pods with read-only roots, user namespaces and the bubblewrap profiles
only where sessions run."""

import gzip
import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

import live


def test_manifests_keep_the_boundaries():
    for name in live.WORKLOADS:
        m = live.manifest(name, "sha256:0")
        spec = m["spec"].get("template", m["spec"].get("jobTemplate", {}).get("spec", {}).get("template"))["spec"]
        c, runner = spec["containers"][0], live.WORKLOADS[name][3]
        claims = {v["persistentVolumeClaim"]["claimName"] for v in spec["volumes"] if "persistentVolumeClaim" in v}
        assert claims <= set(live.VOLUMES) | {"mirror"} and not claims & {"inputs", "results"}
        assert (live.TOKEN in c["env"]) == runner
        assert (spec.get("hostUsers") is False) == runner
        assert ("keys" in {v["name"] for v in spec["volumes"]}) == (name == "datalayer")
        assert spec["securityContext"]["seccompProfile"]["type"] == ("Localhost" if runner else "RuntimeDefault")
        assert c["securityContext"]["readOnlyRootFilesystem"] and c["securityContext"]["capabilities"] == {"drop": ["ALL"]}
        assert not spec["automountServiceAccountToken"] and spec["priorityClassName"] == live.NAMESPACE
        assert c["image"].startswith(live.jobs.REGISTRY + "@sha256:")
    assert {n for n, w in live.WORKLOADS.items() if w[3]} == {"thesis", "agent-series", "agent-real"}
    assert live.manifest("thesis", "sha256:0")["spec"]["updateStrategy"] == {"type": "OnDelete"}
    json.dumps([live.manifest(n, "sha256:0") for n in live.WORKLOADS])


def test_the_real_campaign_is_one_attempt_on_the_series_volume_and_pool():
    real, series = (live.manifest(n, "sha256:0")["spec"] for n in ("agent-real", "agent-series"))
    spec = real["template"]["spec"]
    assert real["backoffLimit"] == 0 and spec["restartPolicy"] == "Never"
    assert series["backoffLimit"] == 20 and series["template"]["spec"]["restartPolicy"] == "OnFailure"
    env = spec["containers"][0]["env"]
    assert env == series["template"]["spec"]["containers"][0]["env"] and {e["name"] for e in env} >= {
        "CLAUDE_CODE_OAUTH_TOKEN_TAMU", "CLAUDE_CODE_OAUTH_TOKEN_CORNELL", "CARGO_TARGET_DIR"}
    assert [v["name"] for v in spec["volumes"] if "persistentVolumeClaim" in v] == ["agent"]
    command = spec["containers"][0]["command"]
    assert command[-3:] == ["agent-real", "data/agent/real", "1792613363942"]


def test_the_mirror_appends_refuses_rewritten_history_and_snapshots_ledgers(tmp_path):
    app, out = tmp_path / "app", tmp_path / "mirror"
    live_dir, thesis = app / "data/live", app / "data/thesis"
    for path in live.VOLUMES.values():
        (app / path).mkdir(parents=True)
    (live_dir / "polls-1.jsonl").write_text('{"a":1}\n')
    with sqlite3.connect(thesis / "ledger.sqlite") as db:
        db.execute("create table t (x)"), db.execute("insert into t values (1)")
    live.mirror(app, out)
    with open(live_dir / "polls-1.jsonl", "a") as f:
        f.write('{"a":2}\n')
    live.mirror(app, out)
    assert (out / "hl/polls-1.jsonl").read_text() == '{"a":1}\n{"a":2}\n'
    manifest = json.loads((out / "hl/MANIFEST.json").read_text())["files"]
    assert manifest["polls-1.jsonl"]["size"] == 16
    with sqlite3.connect(out / "thesis/ledger.sqlite") as db:
        assert db.execute("select x from t").fetchall() == [(1,)]
    (live_dir / "polls-1.jsonl").write_text('{"a":9}\n{"a":2}\n{"a":3}\n')
    with pytest.raises(SystemExit):
        live.mirror(app, out)
    (live_dir / "polls-1.jsonl").write_text('{"a":1}\n{"a":2}\n')
    live.mirror(app, out)
    live.verify(app, out)
    (out / "hl/polls-1.jsonl").write_text('{"a":1}\n{"a":3}\n')
    with pytest.raises(SystemExit):
        live.verify(app, out)
    (live_dir / "polls-1.jsonl").unlink()
    with pytest.raises(SystemExit):
        live.mirror(app, out)


@pytest.mark.parametrize("missing", [None, *live.VOLUMES])
def test_verify_refuses_missing_volume_manifests(tmp_path, missing):
    app, out = tmp_path / "app", tmp_path / "mirror"
    for path in live.VOLUMES.values():
        (app / path).mkdir(parents=True)
    if missing is not None:
        live.mirror(app, out)
        live.verify(app, out)
        (out / missing / "MANIFEST.json").unlink()
    with pytest.raises(SystemExit, match="manifest"):
        live.verify(app, out)


@pytest.mark.parametrize("initial", [False, True])
def test_mirror_copies_only_the_log_prefix_before_body_enumeration(tmp_path, monkeypatch, initial):
    monkeypatch.setattr(live, "VOLUMES", {"datalayer": "data/datalayer"})
    app, out = tmp_path / "app", tmp_path / "mirror"
    source = app / "data/datalayer"
    (source / "raw").mkdir(parents=True)
    old_digest = hashlib.sha256(b"old").hexdigest()
    new_digest = hashlib.sha256(b"new").hexdigest()
    (source / "raw" / f"{old_digest}.gz").write_bytes(gzip.compress(b"old"))
    log = source / "datalayer-20261020.jsonl"
    row = json.dumps({"sha256": old_digest}) + "\n"
    log.write_text(row)
    if not initial:
        live.mirror(app, out)
    manifest = out / "datalayer/MANIFEST.json"
    log.write_text(row * 2)
    rglob = Path.rglob

    def publish_after_listing(path, pattern):
        listed = list(rglob(path, pattern))
        if path == source and pattern == "*":
            (source / "raw" / f"{new_digest}.gz").write_bytes(gzip.compress(b"new"))
            with log.open("a") as fh:
                fh.write(json.dumps({"sha256": new_digest}) + "\n")
        return iter(listed)

    with monkeypatch.context() as patcher:
        patcher.setattr(Path, "rglob", publish_after_listing)
        live.mirror(app, out)
    assert (out / "datalayer" / log.name).read_text() == row * 2
    assert f"raw/{new_digest}.gz" not in json.loads(manifest.read_text())["files"]
    live.verify(app, out)
    live.mirror(app, out)
    live.verify(app, out)
    files = json.loads(manifest.read_text())["files"]
    assert f"raw/{new_digest}.gz" in files
    assert gzip.decompress((out / "datalayer/raw" / f"{new_digest}.gz").read_bytes()) == b"new"


def test_malformed_datalayer_lines_do_not_block_later_volumes(tmp_path, monkeypatch):
    monkeypatch.setattr(live, "VOLUMES", {"datalayer": "data/datalayer", "agent": "data/agent"})
    app, out = tmp_path / "app", tmp_path / "mirror"
    for path in live.VOLUMES.values():
        (app / path).mkdir(parents=True)
    raw = b'{"sha256":\n\xff\n'
    (app / "data/datalayer/day.jsonl").write_bytes(raw)
    live.mirror(app, out)
    assert (out / "datalayer/day.jsonl").read_bytes() == raw
    assert (out / "agent/MANIFEST.json").exists()
    live.verify(app, out)
