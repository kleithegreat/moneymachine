"""Sweeps as Indexed Jobs on the cluster.

    python ops/jobs.py push | join | leave
    python ops/jobs.py submit <run> <sweep> <digest> [node]      sweep: null | mixed | xm
    python ops/jobs.py status | resubmit <run>
    python ops/jobs.py collect <run>...

`mm`, the betas and each Job's id list are staged by sha256 and checked in every pod. A task runs one campaign in local
scratch (SQLite never over NFS) and renames one tar per campaign id into the results volume. A campaign crash is a
result; an OOM kill fails the index, and `resubmit` reruns it once no partial file remains."""

import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))
INPUTS, RESULTS = Path("/srv/moneymachine/inputs"), Path("/srv/moneymachine/results")
REGISTRY = "git.home.lab/admin/moneymachine"
AUTHFILE = Path.home() / ".config/containers/auth.json"
NAMESPACE = "moneymachine"
NODE = "desktop"
SCRATCH = 2**30


def kubectl(*args, stdin=None):
    env = os.environ | {"KUBECONFIG": str(Path.home() / ".kube/moneymachine.yaml")}
    return subprocess.run(["kubectl", "-n", NAMESPACE, *args], input=stdin, capture_output=True, text=True, env=env,
                          check=True).stdout


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def stage(data):
    """Write bytes into the inputs volume under their sha256 (once), and return the hash."""
    h = hashlib.sha256(data).hexdigest()
    if not (INPUTS / h).exists():
        (INPUTS / f".{h}.tmp").write_bytes(data)
        (INPUTS / f".{h}.tmp").rename(INPUTS / h)
    return h


def push():
    out = subprocess.run(["nix", "build", "--no-link", "--print-out-paths", f"{REPO}#image"], capture_output=True,
                         text=True, check=True).stdout.strip()
    tag = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True, text=True,
                         check=True).stdout.strip()
    subprocess.run(["skopeo", "copy", "--authfile", str(AUTHFILE), f"docker-archive:{out}", f"docker://{REGISTRY}:{tag}"],
                   check=True, capture_output=True)
    digest = json.loads(subprocess.run(["skopeo", "inspect", "--authfile", str(AUTHFILE), f"docker://{REGISTRY}:{tag}"],
                                       capture_output=True, text=True, check=True).stdout)["Digest"]
    print(json.dumps({"tag": tag, "digest": digest, "image": out}))
    return digest


def campaign_specs(sweep):
    """A sweep's specs: `null`, `mixed`, or `xm`, the never-judged mixed test specs of ops/crossmachine.py."""
    from gate import sweep as sw

    if sweep == "xm":
        sys.path.insert(0, str(REPO / "ops"))
        import crossmachine

        return [s for s in crossmachine.specs() if s["id"].startswith("xm-")]
    return sw.null_specs() if sweep == "null" else sw.mixed_specs(json.loads((sw.OUT / "betas.json").read_text()))


def manifest(run, ids, record, node=None):
    from gate.sweep import CAMPAIGN_BYTES

    mib = lambda b: f"{b // 2**20}Mi"
    pod = {
        "priorityClassName": "moneymachine-batch",
        "restartPolicy": "Never",
        "tolerations": [{"key": "moneymachine/batch", "operator": "Equal", "value": "true", "effect": "NoSchedule"}],
        "securityContext": {"runAsNonRoot": True, "runAsUser": 1000, "runAsGroup": 100,
                            "seccompProfile": {"type": "RuntimeDefault"}},
        "containers": [{
            "name": "task",
            "image": f"{REGISTRY}@{record['image']}",
            "command": ["choom", "-n", "1000", "--", "python", "/app/repo/ops/jobs.py", "task", run],
            "env": [{"name": "PYTHONPATH", "value": "/app/repo"}, {"name": "TMPDIR", "value": "/scratch/tmp"}],
            "resources": {"requests": {"cpu": "1", "memory": mib(CAMPAIGN_BYTES), "ephemeral-storage": mib(SCRATCH)},
                          "limits": {"memory": mib(CAMPAIGN_BYTES * 5 // 4), "ephemeral-storage": mib(2 * SCRATCH)}},
            "securityContext": {"allowPrivilegeEscalation": False, "capabilities": {"drop": ["ALL"]}},
            "volumeMounts": [{"name": "inputs", "mountPath": "/inputs", "readOnly": True},
                             {"name": "results", "mountPath": "/results"},
                             {"name": "scratch", "mountPath": "/scratch"}]}],
        "volumes": [{"name": "inputs", "persistentVolumeClaim": {"claimName": "inputs", "readOnly": True}},
                    {"name": "results", "persistentVolumeClaim": {"claimName": "results"}},
                    {"name": "scratch", "emptyDir": {"sizeLimit": mib(2 * SCRATCH)}}]}
    if node:
        pod["nodeSelector"] = {"kubernetes.io/hostname": node}
    return {"apiVersion": "batch/v1", "kind": "Job", "metadata": {"name": f"mm-{run}", "labels": {"moneymachine/run": run}},
            "spec": {"completionMode": "Indexed", "completions": len(ids), "parallelism": len(ids),
                     "backoffLimitPerIndex": 0, "ttlSecondsAfterFinished": 86400,
                     "template": {"metadata": {"labels": {"moneymachine/run": run}}, "spec": pod}}}


def stage_funding():
    """The null models' funding source as the store yields it, staged under its frozen sha256 (gate/fit.py)."""
    import numpy as np

    from gate import markets

    for model in ("N2", "N3"):
        f = markets.null_params()[model]["funding"]
        fund, prem = markets.store_funding(f["store"], f["version"], tuple(c for c in f["coins"] if c not in f["short"]))
        if stage(np.ascontiguousarray(np.r_[fund, prem]).tobytes()) != f["sha256"]:
            raise SystemExit(f"{model}'s funding source differs from its frozen hash")


def submit(run, sweep, digest, node=None, ids=None):
    """One Indexed Job over the sweep's ids (or the given ones), its record written first."""
    ids = ids or [s["id"] for s in campaign_specs(sweep)]
    out = RESULTS / run
    out.mkdir(parents=True, exist_ok=True)
    record = {"run": run, "sweep": sweep, "image": digest, "commit": subprocess.run(
                  ["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True, check=True).stdout.strip(),
              "mm": stage((REPO / "kernel/target/release/mm").read_bytes()),
              "betas": stage((REPO / "data/campaigns/betas.json").read_bytes()), "ids": stage(json.dumps(ids).encode()),
              "node": node}
    stage_funding()
    (out / "record.json").write_text(json.dumps(record, indent=1) + "\n")
    print(kubectl("apply", "-f", "-", stdin=json.dumps(manifest(run, ids, record, node))).strip())


def task(run):
    """In a pod: the campaign at this index."""
    record = json.loads((Path("/results") / run / "record.json").read_text())
    ids = json.loads((Path("/inputs") / record["ids"]).read_bytes())
    cid = ids[int(os.environ["JOB_COMPLETION_INDEX"])]
    final = Path("/results") / run / f"{cid}.tar"
    if final.exists():
        return
    for name in ("mm", "betas", "ids"):
        if sha256(Path("/inputs") / record[name]) != record[name]:
            raise SystemExit(f"input {name} does not match its hash")
    work = Path("/scratch/w")
    (work / "data/campaigns").mkdir(parents=True)
    Path("/scratch/tmp").mkdir(exist_ok=True)
    for entry in Path("/app/repo").iterdir():
        if entry.name != "data":
            (work / entry.name).symlink_to(entry)
    shutil.copyfile(Path("/inputs") / record["betas"], work / "data/campaigns/betas.json")
    (Path("/scratch/k/release")).mkdir(parents=True)
    shutil.copyfile(Path("/inputs") / record["mm"], "/scratch/k/release/mm")
    os.chmod("/scratch/k/release/mm", 0o755)
    os.environ["CARGO_TARGET_DIR"] = "/scratch/k"
    os.chdir(work)
    from gate import campaign, sweep

    sweep.require_frozen_searcher()
    spec = next(s for s in campaign_specs(record["sweep"]) if s["id"] == cid)
    funding = (spec["params"] or {}).get("funding")
    if funding:
        import numpy as np

        from gate.markets import HOLDOUT_START, HOUR, W_START

        t = len(range(W_START, HOLDOUT_START, HOUR))
        data = (Path("/inputs") / funding["sha256"]).read_bytes()
        if hashlib.sha256(data).hexdigest() != funding["sha256"]:
            raise SystemExit("the funding source does not match its frozen hash")
        both = np.frombuffer(data).reshape(2 * t, -1)
        funding["arrays"] = (both[:t], both[t:])
    result = campaign.run_campaign(spec, Path("/scratch/out"))
    tmp = final.with_name(f".{cid}.{os.environ.get('HOSTNAME', 'pod')}.tmp")
    with tarfile.open(tmp, "w") as tar:
        data = json.dumps(result).encode()
        info = tarfile.TarInfo("result.json")
        info.size = len(data)
        tar.addfile(info, io.BytesIO(data))
        for kept in sorted((Path("/scratch/out") / cid).glob("*")):
            tar.add(kept, arcname=kept.name)
    tmp.rename(final)


def state(run):
    record = json.loads((RESULTS / run / "record.json").read_text())
    ids = json.loads((INPUTS / record["ids"]).read_bytes())
    done = {p.name.removesuffix(".tar") for p in (RESULTS / run).glob("*.tar")}
    return record, ids, done


def status(run):
    record, ids, done = state(run)
    job = json.loads(kubectl("get", "job", f"mm-{run}", "-o", "json"))["status"]
    print(json.dumps({"ids": len(ids), "done": len(done), "missing": len(ids) - len(done),
                      "active": job.get("active", 0), "failedIndexes": job.get("failedIndexes", "")}))


def resubmit(run):
    """The ids without a result, as a new Job, once the Job has no active pods and no partial file remains."""
    record, ids, done = state(run)
    job = json.loads(kubectl("get", "job", f"mm-{run}", "-o", "json"))["status"]
    if job.get("active"):
        raise SystemExit(f"mm-{run} still has active pods")
    partial = list((RESULTS / run).glob(".*.tmp"))
    for p in partial:
        p.unlink()
    missing = [i for i in ids if i not in done]
    retry = f"{run}-r{sum(1 for _ in RESULTS.glob(f'{run}-r*')) + 1}"
    print(json.dumps({"missing": len(missing), "partial_removed": len(partial), "retry": retry}))
    if missing:
        submit(retry, record["sweep"], record["image"], record["node"], missing)


def collect(*runs):
    """A Job and its retries: every id once, each ledger on the record's kernel."""
    import lzma
    import sqlite3
    import tempfile

    from gate import sweep as sw

    records = [json.loads((RESULTS / r / "record.json").read_text()) for r in runs]
    sweep_name, mm = records[0]["sweep"], records[0]["mm"]
    if any(r["sweep"] != sweep_name or r["mm"] != mm for r in records):
        raise SystemExit("the runs differ in sweep or binary")
    planned = json.loads((INPUTS / records[0]["ids"]).read_bytes())
    found = {}
    for r in runs:
        for p in (RESULTS / r).glob("*.tar"):
            cid = p.name.removesuffix(".tar")
            if cid in found:
                raise SystemExit(f"{cid} recorded twice")
            found[cid] = p
    if set(found) != set(planned):
        raise SystemExit(f"missing {len(set(planned) - set(found))}, unplanned {len(set(found) - set(planned))}")
    target = sw.OUT / f"{sweep_name}.jsonl"
    if target.exists():
        raise SystemExit(f"{target} exists")
    rows = []
    for cid in sorted(found):
        with tarfile.open(found[cid]) as tar:
            rows.append(json.loads(tar.extractfile("result.json").read()))
            dest = sw.OUT / sweep_name / cid
            dest.mkdir(parents=True, exist_ok=True)
            for m in tar.getmembers():
                if m.name != "result.json":
                    (dest / m.name).write_bytes(tar.extractfile(m).read())
        ledger = sw.OUT / sweep_name / cid / "ledger.sqlite.xz"
        if ledger.exists():
            with tempfile.NamedTemporaryFile(suffix=".sqlite") as f:
                f.write(lzma.decompress(ledger.read_bytes()))
                f.flush()
                if {k for (k,) in sqlite3.connect(f.name).execute("select distinct kernel from experiments")} - {mm}:
                    raise SystemExit(f"{cid}: a kernel other than the record's")
    target.write_text("".join(json.dumps(r) + "\n" for r in rows))
    print(json.dumps({"collected": len(rows), "file": str(target)}))


def join():
    subprocess.run(["systemctl", "start", "k3s"], check=True)


def leave():
    """Cordon and drain this PC's node, leave the cluster, and delete the node."""
    env = os.environ | {"KUBECONFIG": str(Path.home() / ".kube/moneymachine.yaml")}
    subprocess.run(["kubectl", "cordon", NODE], check=True, env=env)
    subprocess.run(["kubectl", "drain", NODE, "--ignore-daemonsets", "--delete-emptydir-data", "--timeout=600s"],
                   check=True, env=env)
    subprocess.run(["systemctl", "stop", "k3s"], check=True)
    subprocess.run(["kubectl", "delete", "node", NODE], check=True, env=env)


if __name__ == "__main__":
    commands = {"push": push, "submit": submit, "task": task, "status": status, "resubmit": resubmit,
                "collect": collect, "join": join, "leave": leave}
    commands[sys.argv[1]](*sys.argv[2:])
