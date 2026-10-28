"""Sweeps as Indexed Jobs on the cluster (human decision of 2026-10-28; CLAUDE.md, heavy jobs).

    python ops/jobs.py push                                   build the image (`nix build .#image`), push it, print its digest
    python ops/jobs.py submit <run> <sweep> <digest> [node]   one Indexed Job over the sweep's campaign ids (null, mixed, xm)
    python ops/jobs.py status <run>                           done, failed and missing ids
    python ops/jobs.py resubmit <run>                         the missing ids again, after the integrity check
    python ops/jobs.py collect <run>                          results into data/campaigns/<sweep>.jsonl and <sweep>/<id>/
    python ops/jobs.py join | leave                           this PC (node `desktop`) in or out of the cluster

The image holds the research environment and the commit's tree; `mm`, the betas and each Job's id list are staged
content-addressed into the `inputs` volume and checked by hash in every pod. A task runs one campaign in local scratch
(SQLite never over NFS) and moves one file per campaign id, a tar of its result and kept files, into `results`
atomically. A campaign crash is a result (exit 0); an OOM kill fails the index, and `resubmit` reruns it once no
partial output remains (seeds come from the id, so a rerun is the same campaign). A submission's record, with the
image digest and every input hash, is kept beside its results."""

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
INPUTS, RESULTS = Path("/srv/moneymachine/inputs"), Path("/srv/moneymachine/results")
REGISTRY = "git.home.lab/admin/moneymachine"
AUTHFILE = Path.home() / ".config/containers/auth.json"
NAMESPACE = "moneymachine"
NODE = "desktop"
# The namespace's quota (pods, CPUs, requested and limit memory) and each task's measured peak memory with mm 3a732069
# (a null campaign 533 MiB, the long cell 684 MiB; 2026-10-27), with its limit above it and its scratch.
QUOTA = {"pods": 48, "cpu": 34, "memory": 32 * 2**30, "limit": 40 * 2**30}
PEAK = {"null": 560 * 2**20, "mixed": 720 * 2**20, "xm": 720 * 2**20}
LIMIT, SCRATCH = 1100 * 2**20, 2**30


def kubectl(*args, stdin=None):
    env = os.environ | {"KUBECONFIG": str(Path.home() / ".kube/moneymachine.yaml")}
    return subprocess.run(["kubectl", "-n", NAMESPACE, *args], input=stdin, capture_output=True, text=True, env=env,
                          check=True).stdout


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def stage(path):
    """Copy a file into the inputs volume under its sha256 (once), and return the hash."""
    h = sha256(path)
    if not (INPUTS / h).exists():
        shutil.copyfile(path, INPUTS / f".{h}.tmp")
        (INPUTS / f".{h}.tmp").rename(INPUTS / h)
    return h


def stage_bytes(data):
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
    sys.path.insert(0, str(REPO))
    from gate import sweep as sw

    if sweep == "xm":
        sys.path.insert(0, str(REPO / "ops"))
        import crossmachine

        return [s for s in crossmachine.specs() if s["id"].startswith("xm-")]
    return sw.null_specs() if sweep == "null" else sw.mixed_specs(json.loads((sw.OUT / "betas.json").read_text()))


def parallelism(sweep):
    return min(QUOTA["pods"], QUOTA["cpu"], QUOTA["memory"] // PEAK[sweep], QUOTA["limit"] // LIMIT)


def manifest(run, sweep, ids, record, node=None):
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
            "resources": {"requests": {"cpu": "1", "memory": mib(PEAK[sweep]), "ephemeral-storage": mib(SCRATCH)},
                          "limits": {"memory": mib(LIMIT), "ephemeral-storage": mib(2 * SCRATCH)}},
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
            "spec": {"completionMode": "Indexed", "completions": len(ids), "parallelism": min(len(ids), parallelism(sweep)),
                     "backoffLimitPerIndex": 0, "ttlSecondsAfterFinished": 86400,
                     "template": {"metadata": {"labels": {"moneymachine/run": run}}, "spec": pod}}}


def submit(run, sweep, digest, node=None, ids=None):
    """One Indexed Job over the sweep's ids (or the given ones), its record (image, inputs) written first."""
    ids = ids or [s["id"] for s in campaign_specs(sweep)]
    out = RESULTS / run
    out.mkdir(parents=True, exist_ok=True)
    record = {"run": run, "sweep": sweep, "image": digest, "commit": subprocess.run(
                  ["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True, check=True).stdout.strip(),
              "mm": stage(REPO / "kernel/target/release/mm"), "betas": stage(REPO / "data/campaigns/betas.json"),
              "ids": stage_bytes(json.dumps(ids).encode()), "node": node}
    (out / "record.json").write_text(json.dumps(record, indent=1) + "\n")
    print(kubectl("apply", "-f", "-", stdin=json.dumps(manifest(run, sweep, ids, record, node))).strip())


def task(run):
    """In a pod: the campaign at this index, run in scratch, its outputs moved into results as one file."""
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
    """The ids without a result, as a new Job, once the first Job is finished and no partial file remains."""
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
    """Every id once across the runs (a Job and its retries), each ledger on the record's kernel, into the sweep's
    file in id order and its ledgers directory."""
    sys.path.insert(0, str(REPO))
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
