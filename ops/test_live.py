"""The live workloads' manifests keep CLUSTER.md's boundaries: only live volumes, the token only in runners, the
datalayer keys only in its recorder, restricted pods with read-only roots, user namespaces and the bubblewrap profiles
only where sessions run."""

import json
import sqlite3

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
    assert {n for n, w in live.WORKLOADS.items() if w[3]} == {"thesis", "agent-series"}
    assert live.manifest("thesis", "sha256:0")["spec"]["updateStrategy"] == {"type": "OnDelete"}
    json.dumps([live.manifest(n, "sha256:0") for n in live.WORKLOADS])


def test_the_mirror_appends_refuses_rewritten_history_and_snapshots_ledgers(tmp_path):
    app, out = tmp_path / "app", tmp_path / "mirror"
    live_dir, thesis = app / "data/live", app / "data/thesis"
    live_dir.mkdir(parents=True), thesis.mkdir(parents=True)
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
