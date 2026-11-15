"""Sweeps as Indexed Jobs on the cluster.

    python ops/jobs.py push | join | leave
    python ops/jobs.py submit <run> <sweep> <digest> [node]      sweep: null | mixed | xm
    python ops/jobs.py resubmit <run>
    python ops/jobs.py collect <run>...
    python ops/jobs.py calibrate <run> <digest>                study 1's calibration over CAL_HOSTS, from this PC

`submit` and `resubmit` block until the Job completes or fails. `mm`, the betas and each Job's id list are staged by
sha256 and checked in every pod. A task runs one campaign in local
scratch (SQLite never over NFS) and renames one tar per campaign id into the results volume. A campaign crash is a
result; an OOM kill fails the index, and `resubmit` reruns it once no partial file remains."""

import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO))
INPUTS, RESULTS = Path("/srv/moneymachine/inputs"), Path("/srv/moneymachine/results")
REGISTRY = "git.home.lab/admin/moneymachine"
AUTHFILE = Path.home() / ".config/containers/auth.json"
NAMESPACE = "moneymachine"
NODE = "desktop"
SCRATCH = 2**30


def kubectl(*args: str, stdin: str | None = None, namespace: str = NAMESPACE, config: str = "moneymachine.yaml") -> str:
    env = os.environ | {"KUBECONFIG": str(Path.home() / ".kube" / config)}
    return subprocess.run(
        ["kubectl", "-n", namespace, *args], input=stdin, capture_output=True, text=True, env=env, check=True
    ).stdout


def sha256(path: str | Path, size: int | None = None) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        left = size if size is not None else sys.maxsize
        while left > 0 and (b := f.read(min(1 << 20, left))):
            h.update(b)
            left -= len(b)
    return h.hexdigest()


def stage(data: bytes) -> str:
    """Write bytes into the inputs volume under their sha256 (once), and return the hash."""
    h = hashlib.sha256(data).hexdigest()
    if not (INPUTS / h).exists():
        (INPUTS / f".{h}.tmp").write_bytes(data)
        (INPUTS / f".{h}.tmp").rename(INPUTS / h)
    return h


def push() -> str:
    out = subprocess.run(
        ["nix", "build", "--no-link", "--print-out-paths", f"{REPO}#image"], capture_output=True, text=True, check=True
    ).stdout.strip()
    tag = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"], cwd=REPO, capture_output=True, text=True, check=True
    ).stdout.strip()
    with tempfile.TemporaryDirectory() as tmp:
        digestfile = Path(tmp) / "digest"
        subprocess.run(
            [
                "skopeo",
                "copy",
                "--authfile",
                str(AUTHFILE),
                "--digestfile",
                str(digestfile),
                f"docker-archive:{out}",
                f"docker://{REGISTRY}:{tag}",
            ],
            check=True,
            capture_output=True,
        )
        digest = digestfile.read_text().strip()
    print(json.dumps({"tag": tag, "digest": digest, "image": out}))
    return digest


def campaign_specs(sweep: str) -> list[dict[str, Any]]:
    """A sweep's specs: `null`, `mixed`, or `xm`, the mixed cells under ids `xm-…` with fixed test betas, never
    judged."""
    from gate import sweep as sw

    if sweep == "xm":
        betas = {f"{m}-s{k}": 0.01 * k for m in ("N2", "N3") for k in (1, 2, 3)} | {"N2-long": 0.1}
        return [s | {"id": "xm-" + s["id"].split("-", 1)[1]} for s in sw.mixed_specs(betas, markets=1)]
    specs: list[dict[str, Any]] = (
        sw.null_specs() if sweep == "null" else sw.mixed_specs(json.loads((sw.OUT / "betas.json").read_text()))
    )
    return specs


def mib(size: int) -> str:
    return f"{size // 2**20}Mi"


def manifest(run: str, ids: list[str], record: dict[str, Any], node: str | None = None) -> dict[str, Any]:
    from gate.sweep import CAMPAIGN_BYTES

    pod: dict[str, Any] = {
        "priorityClassName": "moneymachine-batch",
        "restartPolicy": "Never",
        "tolerations": [{"key": "moneymachine/batch", "operator": "Equal", "value": "true", "effect": "NoSchedule"}],
        "securityContext": {
            "runAsNonRoot": True,
            "runAsUser": 1000,
            "runAsGroup": 100,
            "seccompProfile": {"type": "RuntimeDefault"},
        },
        "containers": [
            {
                "name": "task",
                "image": f"{REGISTRY}@{record['image']}",
                "command": ["choom", "-n", "1000", "--", "python", "/app/repo/ops/jobs.py", "task", run],
                "env": [{"name": "PYTHONPATH", "value": "/app/repo"}, {"name": "TMPDIR", "value": "/scratch/tmp"}],
                "resources": {
                    "requests": {"cpu": "1", "memory": mib(CAMPAIGN_BYTES), "ephemeral-storage": mib(SCRATCH)},
                    "limits": {"memory": mib(CAMPAIGN_BYTES * 5 // 4), "ephemeral-storage": mib(2 * SCRATCH)},
                },
                "securityContext": {"allowPrivilegeEscalation": False, "capabilities": {"drop": ["ALL"]}},
                "volumeMounts": [
                    {"name": "inputs", "mountPath": "/inputs", "readOnly": True},
                    {"name": "results", "mountPath": "/results"},
                    {"name": "scratch", "mountPath": "/scratch"},
                ],
            }
        ],
        "volumes": [
            {"name": "inputs", "persistentVolumeClaim": {"claimName": "inputs", "readOnly": True}},
            {"name": "results", "persistentVolumeClaim": {"claimName": "results"}},
            {"name": "scratch", "emptyDir": {"sizeLimit": mib(2 * SCRATCH)}},
        ],
    }
    if node:
        pod["nodeSelector"] = {"kubernetes.io/hostname": node}
    return {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {"name": f"mm-{run}", "labels": {"moneymachine/run": run}},
        "spec": {
            "completionMode": "Indexed",
            "completions": len(ids),
            "parallelism": len(ids),
            "backoffLimitPerIndex": 0,
            "ttlSecondsAfterFinished": 86400,
            "template": {"metadata": {"labels": {"moneymachine/run": run}}, "spec": pod},
        },
    }


def stage_funding() -> None:
    """The null models' funding source as the store yields it, staged under its frozen sha256 (gate/fit.py)."""
    import numpy as np

    from gate import markets

    for model in ("N2", "N3"):
        stage(np.concatenate(markets.frozen_funding(markets.null_params()[model]["funding"])).tobytes())


def submit(run: str, sweep: str, digest: str, node: str | None = None) -> None:
    """Stage this checkout's inputs once, then launch a new run."""
    ids = [s["id"] for s in campaign_specs(sweep)]
    record = {
        "sweep": sweep,
        "image": digest,
        "commit": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True, check=True
        ).stdout.strip(),
        "mm": stage((REPO / "kernel/target/release/mm").read_bytes()),
        "betas": stage((REPO / "data/campaigns/betas.json").read_bytes()),
        "node": node,
    }
    stage_funding()
    launch(run, record, ids)


def launch(run: str, record: dict[str, Any], ids: list[str]) -> None:
    """Reserve a single-use run name before writing provenance or creating its Job."""
    out = RESULTS / run
    out.mkdir()
    record = record | {"run": run, "ids": stage(json.dumps(ids).encode())}
    (out / "record.json").write_text(json.dumps(record, indent=1) + "\n")
    print(kubectl("create", "-f", "-", stdin=json.dumps(manifest(run, ids, record, record["node"]))).strip())
    while not (
        ended := {c["type"] for c in job(run).get("conditions", []) if c["status"] == "True"} & {"Complete", "Failed"}
    ):
        time.sleep(30)
    print(
        json.dumps(
            {"run": run, "succeeded": job(run).get("succeeded", 0), "failedIndexes": job(run).get("failedIndexes", "")}
        )
    )
    if "Failed" in ended:
        raise SystemExit(f"mm-{run}: an index failed; `resubmit {run}` reruns it after the integrity check")


def job(run: str) -> dict[str, Any]:
    status: dict[str, Any] = json.loads(kubectl("get", "job", f"mm-{run}", "-o", "json"))["status"]
    return status


def task(run: str) -> None:
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
    from gate import campaign, markets, sweep

    sweep.require_frozen_searcher()
    spec = next(s for s in campaign_specs(record["sweep"]) if s["id"] == cid)
    funding = (spec["params"] or {}).get("funding")
    if funding:
        funding["arrays"] = markets.frozen_funding(funding, "/inputs")
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


def state(run: str) -> tuple[dict[str, Any], list[str], set[str]]:
    record = json.loads((RESULTS / run / "record.json").read_text())
    for name in ("mm", "betas", "ids"):
        if sha256(INPUTS / record[name]) != record[name]:
            raise SystemExit(f"input {name} does not match its hash")
    ids = json.loads((INPUTS / record["ids"]).read_bytes())
    done = {p.name.removesuffix(".tar") for p in (RESULTS / run).glob("*.tar")}
    return record, ids, done


def resubmit(run: str) -> None:
    """The ids without a result, as a new Job, once the Job has no active pods and no partial file remains."""
    record, ids, done = state(run)
    if job(run).get("active"):
        raise SystemExit(f"mm-{run} still has active pods")
    partial = list((RESULTS / run).glob(".*.tmp"))
    for p in partial:
        p.unlink()
    missing = [i for i in ids if i not in done]
    retry = f"{run}-r{sum(1 for _ in RESULTS.glob(f'{run}-r*')) + 1}"
    print(json.dumps({"missing": len(missing), "partial_removed": len(partial), "retry": retry}))
    if missing:
        launch(retry, record, missing)


# Peak memory of unpacking one campaign: its decompressed ledger (25 MB the largest, held twice) and an interpreter.
UNPACK_BYTES = 200_000_000


def collect(*runs: str, out: str | Path | None = None) -> None:
    """A Job and its retries, into `out` (the campaigns directory by default): every id once, each ledger on the
    record's kernel."""
    from functools import partial

    from gate import compute
    from gate import sweep as sw

    records = [json.loads((RESULTS / r / "record.json").read_text()) for r in runs]
    sweep_name, mm = records[0]["sweep"], records[0]["mm"]
    if any(r[k] != records[0][k] for r in records for k in ("sweep", "mm", "betas", "image")):
        raise SystemExit("the runs differ in sweep, binary, calibration or image")
    planned = json.loads((INPUTS / records[0]["ids"]).read_bytes())
    found: dict[str, Path] = {}
    for r in runs:
        for p in (RESULTS / r).glob("*.tar"):
            cid = p.name.removesuffix(".tar")
            if cid in found:
                raise SystemExit(f"{cid} recorded twice")
            found[cid] = p
    if set(found) != set(planned):
        raise SystemExit(f"missing {len(set(planned) - set(found))}, unplanned {len(set(found) - set(planned))}")
    out = Path(out or sw.OUT)
    target = out / f"{sweep_name}.jsonl"
    if target.exists():
        raise SystemExit(f"{target} exists")
    with compute.Pool(compute.workers(UNPACK_BYTES)) as pool:
        rows = pool.map(partial(unpack, dest=out / sweep_name, mm=mm), sorted(found.items()))
    target.write_text("".join(json.dumps(r) + "\n" for r in rows))
    print(json.dumps({"collected": len(rows), "file": str(target)}))


def unpack(item: tuple[str, Path], dest: Path, mm: str) -> dict[str, Any]:
    """One campaign's tar into `dest`/<id>/, its ledger checked to carry the record's kernel; returns its result."""
    import lzma
    import sqlite3
    import tempfile

    cid, path = item
    with tarfile.open(path) as tar:
        result = tar.extractfile("result.json")
        assert result is not None
        row: dict[str, Any] = json.loads(result.read())
        (dest / cid).mkdir(parents=True, exist_ok=True)
        for m in tar.getmembers():
            if m.name != "result.json":
                member = tar.extractfile(m)
                assert member is not None
                (dest / cid / m.name).write_bytes(member.read())
    ledger = dest / cid / "ledger.sqlite.xz"
    if ledger.exists():
        with tempfile.NamedTemporaryFile(suffix=".sqlite") as f:
            f.write(lzma.decompress(ledger.read_bytes()))
            f.flush()
            if {k for (k,) in sqlite3.connect(f.name).execute("select distinct kernel from experiments")} - {mm}:
                raise SystemExit(f"{cid}: a kernel other than the record's")
    return row


def join() -> None:
    subprocess.run(["systemctl", "start", "k3s"], check=True)


def leave() -> None:
    """Cordon and drain this PC's node, then leave the cluster; stopping k3s deletes the node (the desktop's NixOS
    config)."""
    env = os.environ | {"KUBECONFIG": str(Path.home() / ".kube/moneymachine.yaml")}
    subprocess.run(["kubectl", "cordon", NODE], check=True, env=env)
    subprocess.run(
        ["kubectl", "drain", NODE, "--ignore-daemonsets", "--delete-emptydir-data", "--timeout=600s"],
        check=True,
        env=env,
    )
    subprocess.run(["systemctl", "stop", "k3s"], check=True)


CAL_HOSTS = (("desktop", 11), ("prodesk7", 10), ("gmktec", 8), ("prodesk5", 6))
CAL_WORKER_BYTES = 512 * 2**20
CAL_ROUND_RETRIES = 2


def cal_weights() -> str:
    return ",".join(str(cores) for _, cores in CAL_HOSTS)


def cal_effect(out: Path, k: int, mode: str, work: Path) -> None:
    """One host's part of study 1's calibration (gate/control/calibrate.py, step 5's behaviour 8): its probe, its
    share of the current set, or, with no share, the deciding run."""
    from functools import partial

    from gate.control import calibrate

    if mode == "probe":
        seconds, result = calibrate.timed_trial(work / "market")
        tmp = out / f".probe-{k}.tmp"
        tmp.write_text(json.dumps({"seconds": seconds, "result": result}))
        tmp.rename(out / f"probe-{k}.json")
        return
    argv = ["--weights", cal_weights()] + (["--share", str(k)] if mode == "share" else [])
    code = calibrate.main(
        argv,
        out=out,
        work=work,
        trial=calibrate.g100_trial,
        blind=calibrate.blind_trial,
        probes=partial(calibrate.file_probes, out, len(CAL_HOSTS)),
        workers=CAL_HOSTS[k][1],
    )
    if mode == "decide" and code:
        print("calibration: a wall stopped (calibration.json)")


def cal_task(run: str, k: str, mode: str) -> None:
    """In a pod: host k's probe or share, with the repo, the staged kernel and the inputs volume in place."""
    record = json.loads((Path("/results") / run / "record.json").read_text())
    if sha256(Path("/inputs") / record["mm"]) != record["mm"]:
        raise SystemExit("input mm does not match its hash")
    work = Path("/scratch/w")
    (work / "data/agent").mkdir(parents=True, exist_ok=True)
    Path("/scratch/tmp").mkdir(exist_ok=True)
    for entry in Path("/app/repo").iterdir():
        if entry.name != "data" and not (work / entry.name).exists():
            (work / entry.name).symlink_to(entry)
    if not (work / "data/agent/inputs").exists():
        (work / "data/agent/inputs").symlink_to("/inputs")
    (Path("/scratch/k/release")).mkdir(parents=True, exist_ok=True)
    shutil.copyfile(Path("/inputs") / record["mm"], "/scratch/k/release/mm")
    os.chmod("/scratch/k/release/mm", 0o755)
    os.environ["CARGO_TARGET_DIR"] = "/scratch/k"
    os.chdir(work)
    cal_effect(Path("/results") / run, int(k), mode, Path("/scratch/trials"))


def cal_manifest(run: str, step: str, k: int, mode: str, record: dict[str, Any]) -> dict[str, Any]:
    node, cores = CAL_HOSTS[k]
    pod = manifest(run, ["calibration"], record, node)["spec"]["template"]["spec"]
    pod["volumes"][2]["emptyDir"]["sizeLimit"] = mib(16 * SCRATCH)
    container = pod["containers"][0]
    container["command"] = [
        "choom",
        "-n",
        "1000",
        "--",
        "python",
        "/app/repo/ops/jobs.py",
        "cal-task",
        run,
        str(k),
        mode,
    ]
    container["resources"] = {
        "requests": {"cpu": str(cores), "memory": mib(cores * CAL_WORKER_BYTES), "ephemeral-storage": mib(4 * SCRATCH)},
        "limits": {"memory": mib(cores * CAL_WORKER_BYTES * 5 // 4 + 2**30), "ephemeral-storage": mib(16 * SCRATCH)},
    }
    name = f"mm-{run}-{step}-{k}"
    return {
        "apiVersion": "batch/v1",
        "kind": "Job",
        "metadata": {"name": name, "labels": {"moneymachine/run": run}},
        "spec": {
            "completions": 1,
            "backoffLimit": 0,
            "ttlSecondsAfterFinished": 86400,
            "template": {"metadata": {"labels": {"moneymachine/run": run}}, "spec": pod},
        },
    }


def cal_local(out: Path, mode: str) -> subprocess.Popen[bytes]:
    """Host 0, this PC, runs its part beside the pods, from the checkout, on the staged kernel."""
    env = os.environ | {"CARGO_TARGET_DIR": str(out / "k"), "PYTHONPATH": str(REPO)}
    script = f"import sys; sys.path.insert(0, 'ops'); import jobs; jobs.cal_effect(jobs.Path({str(out)!r}), 0, {mode!r}, jobs.Path({str(Path.home() / '.cache/mm-calibration' / out.name)!r}))"
    return subprocess.Popen([sys.executable, "-c", script], cwd=REPO, env=env)


def cal_step(run: str, step: str, mode: str, record: dict[str, Any]) -> bool:
    """Every host's part of one step at once: this PC locally, the nodes as Jobs. True when all succeeded."""
    out = RESULTS / run
    local = cal_local(out, mode)
    names = []
    for k in range(1, len(CAL_HOSTS)):
        spec = cal_manifest(run, step, k, mode, record)
        names.append(spec["metadata"]["name"])
        kubectl("create", "-f", "-", stdin=json.dumps(spec))
    ended: dict[str, str] = {}
    while len(ended) < len(names):
        time.sleep(30)
        for name in names:
            status = json.loads(kubectl("get", "job", name, "-o", "json"))["status"]
            done = {c["type"] for c in status.get("conditions", []) if c["status"] == "True"} & {"Complete", "Failed"}
            if done:
                ended[name] = done.pop()
    ok = local.wait() == 0 and all(state == "Complete" for state in ended.values())
    print(json.dumps({"step": step, "local": local.returncode, "jobs": ended}), flush=True)
    return ok


def merge_shares(out: Path, step: str) -> int:
    """Append every host's complete share lines to the merged log, then keep each share file under its step's name;
    lines repeated across rounds count once (behaviour 8)."""
    added = 0
    with (out / "calibration.jsonl").open("a") as merged:
        for share in sorted(out.glob("share-*.jsonl")):
            text = share.read_text()
            complete = text[: text.rfind("\n") + 1]
            merged.write(complete)
            added += complete.count("\n")
            share.rename(out / f"{share.stem}.{step}.jsonl")
    return added


def calibrate(run: str, digest: str) -> None:
    """Study 1's calibration over CAL_HOSTS: probes, then rounds of shares merged here, then the deciding run.
    Rerun with the same run name, it resumes from the merged log."""
    from gate.control import calibrate as cal

    out = RESULTS / run
    if not out.exists():
        out.mkdir()
        record = {
            "kind": "calibration",
            "image": digest,
            "commit": subprocess.run(
                ["git", "rev-parse", "HEAD"], cwd=REPO, capture_output=True, text=True, check=True
            ).stdout.strip(),
            "mm": stage(cal_kernel().read_bytes()),
            "hosts": CAL_HOSTS,
            "run": run,
        }
        (out / "record.json").write_text(json.dumps(record, indent=1) + "\n")
    record = json.loads((out / "record.json").read_text())
    (out / "k/release").mkdir(parents=True, exist_ok=True)
    shutil.copyfile(INPUTS / record["mm"], out / "k/release/mm")
    os.chmod(out / "k/release/mm", 0o755)
    probed = all((out / f"probe-{k}.json").exists() for k in range(len(CAL_HOSTS)))
    if not probed and not cal_step(run, "probe", "probe", record):
        raise SystemExit("calibration: a probe failed")
    rounds = len([f for f in out.glob("share-0.r*.jsonl") if re.fullmatch(r"share-0\.r\d+\.jsonl", f.name)])
    tries = 0
    while cal.next_set(cal.parse([out / "calibration.jsonl"])) is not None:
        step = f"r{rounds}" if tries == 0 else f"r{rounds}t{tries}"
        ok = cal_step(run, step, "share", record)
        print(json.dumps({"step": step, "merged": merge_shares(out, f"r{rounds}" if ok else step)}), flush=True)
        if ok:
            rounds, tries = rounds + 1, 0
        elif (tries := tries + 1) > CAL_ROUND_RETRIES:
            raise SystemExit(f"calibration: round {rounds} failed {tries} times; its pods' logs say why")
    local = cal_local(out, "decide")
    if local.wait() != 0:
        raise SystemExit("calibration: the deciding run failed")
    print((out / "calibration.json").read_text())


def cal_kernel() -> Path:
    from gate import kernel

    mm: Path = kernel.MM
    return mm


if __name__ == "__main__":
    commands: dict[str, Callable[..., object]] = {
        "push": push,
        "submit": submit,
        "task": task,
        "resubmit": resubmit,
        "collect": collect,
        "join": join,
        "leave": leave,
        "calibrate": calibrate,
        "cal-task": cal_task,
    }
    commands[sys.argv[1]](*sys.argv[2:])
