"""The live workloads on the homelab cluster (CLUSTER.md): their manifests, applied with the `deployer` account; the
seeding of their volumes from this PC; the gates; and the mirror and backup steps that run in pods.

    python ops/live.py push                          build and push the image; prints its digest
    python ops/live.py apply <digest> <name>...      apply workloads (WORKLOADS' names)
    python ops/live.py seed <digest> <volume> <src:dest>...   copy files of this PC into a volume, checked by sha256
    python ops/live.py gate <digest> <Default|Unmasked>       the credential and sandbox gates in a runner pod
    python ops/live.py view                          the sandbox's view (namespaces, maps, mounts), as the gate records it
In pods: `mirror`, `restic`, `seed-run <volume>`, `gate-run <targets>`.
"""

import hashlib
import json
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import jobs  # noqa: E402

REPO = jobs.REPO
NAMESPACE, CONFIG, NODE, APP = "moneymachine-live", "moneymachine-live.yaml", "prodesk5", "/app/repo"
MIRROR = Path("/srv/moneymachine/mirror")
VOLUMES = {"hl": "data/live", "sources": "data/sources_live", "datalayer": "data/datalayer", "thesis": "data/thesis",
           "agent": "data/agent"}
LEDGERS = ("thesis", "agent")
SECCOMP, APPARMOR = "moneymachine-bwrap.json", "moneymachine-bwrap"
TOKEN = {"name": "CLAUDE_CODE_OAUTH_TOKEN", "valueFrom": {"secretKeyRef": {"name": "claude-token", "key": "CLAUDE_CODE_OAUTH_TOKEN"}}}
PROC = "Unmasked"  # the runners' procMount, as the sandbox gate settled it

# name: (kind, command, {volume: read-only}, runner, (cpu, memory request, memory limit), grace seconds, extra)
WORKLOADS = {
    "hl": ("StatefulSet", ["record", "data/live/universe.json", "venue/hyperliquid/rules.json", "data/live", "480"],
           {"hl": False}, False, ("100m", "256Mi", "512Mi"), 300, {}),
    "sources": ("StatefulSet", ["sources-record", "data/sources_live"], {"sources": False}, False,
                ("100m", "256Mi", "512Mi"), 300, {}),
    "datalayer": ("StatefulSet", ["datalayer-record", "data/datalayer"], {"datalayer": False}, False,
                  ("100m", "256Mi", "512Mi"), 300, {"keys": True}),
    "thesis": ("StatefulSet", ["thesis-run"], {"thesis": False, "datalayer": True}, True, ("500m", "2Gi", "4Gi"), 15_000, {}),
    "agent-series": ("Job", ["agent-null", "agent", "20"], {"agent": False}, True, ("1", "3Gi", "6Gi"), 9_000,
                     {"env": [{"name": "CARGO_TARGET_DIR", "value": f"{APP}/data/agent/kernel"}]}),
    "mirror": ("CronJob", ["ops/live.py", "mirror"], {**{v: v not in LEDGERS for v in VOLUMES}, "mirror": False}, False,
               ("200m", "256Mi", "512Mi"), 600, {"schedule": "*/10 * * * *"}),
    "restic": ("CronJob", ["ops/live.py", "restic"], {v: False for v in LEDGERS}, False, ("200m", "256Mi", "512Mi"), 600,
               {"schedule": "17 * * * *", "envFrom": [{"secretRef": {"name": "restic"}}]}),
}


def kubectl(*args, stdin=None):
    return jobs.kubectl(*args, stdin=stdin, namespace=NAMESPACE, config=CONFIG)


def pod_spec(name, digest, command, volumes, runner, size, grace, extra, proc=PROC):
    """A restricted pod on prodesk5 running `python -m cli <command>` (or `python <script>`), each volume at its repo
    path; a runner (thesis, series, gates) also gets its own user namespace, the bubblewrap profiles and the token."""
    cpu, memory, limit = size
    mounts = [{"name": "tmp", "mountPath": "/tmp"}, {"name": "scratch", "mountPath": "/scratch"}]
    mounts += [{"name": v, "mountPath": "/mirror" if v == "mirror" else f"{APP}/{VOLUMES[v]}", "readOnly": ro}
               for v, ro in volumes.items()]
    vols = [{"name": n, "emptyDir": {"sizeLimit": "2Gi"}} for n in ("tmp", "scratch")]
    vols += [{"name": v, "persistentVolumeClaim": {"claimName": v}} for v in volumes]
    if extra.get("keys"):
        mounts.append({"name": "keys", "mountPath": f"{APP}/.keys.env", "subPath": ".keys.env", "readOnly": True})
        vols.append({"name": "keys", "secret": {"secretName": "datalayer-keys"}})
    profile = ({"type": "Localhost", "localhostProfile": SECCOMP}, {"type": "Localhost", "localhostProfile": APPARMOR}) \
        if runner else ({"type": "RuntimeDefault"}, {"type": "RuntimeDefault"})
    script = command[0].endswith(".py")
    return {
        "serviceAccountName": "live", "automountServiceAccountToken": False, "enableServiceLinks": False,
        "priorityClassName": NAMESPACE, "nodeSelector": {"kubernetes.io/hostname": NODE},
        "terminationGracePeriodSeconds": grace, **({"hostUsers": False} if runner else {}),
        "securityContext": {"runAsUser": 1000, "runAsGroup": 100, "fsGroup": 100, "runAsNonRoot": True,
                            "seccompProfile": profile[0], "appArmorProfile": profile[1]},
        "containers": [{
            "name": name, "image": f"{jobs.REGISTRY}@{digest}", "workingDir": APP,
            "command": ["python", *([] if script else ["-m", "cli"]), *command],
            "env": [*([TOKEN] if runner else []), *extra.get("env", [])], "envFrom": extra.get("envFrom", []),
            "resources": {"requests": {"cpu": cpu, "memory": memory}, "limits": {"memory": limit}},
            "securityContext": {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True,
                                "capabilities": {"drop": ["ALL"]}, **({"procMount": proc} if runner else {})},
            "volumeMounts": mounts}],
        "volumes": vols}


def manifest(name, digest):
    kind, command, volumes, runner, size, grace, extra = WORKLOADS[name]
    meta = {"name": name, "labels": {"app": name}}
    template = {"metadata": {"labels": {"app": name}}, "spec": pod_spec(name, digest, command, volumes, runner, size, grace, extra)}
    if kind == "StatefulSet":
        spec = {"replicas": 1, "serviceName": name, "selector": {"matchLabels": {"app": name}}, "template": template,
                **({"updateStrategy": {"type": "OnDelete"}} if name == "thesis" else {})}
    elif kind == "Job":
        template["spec"]["restartPolicy"] = "OnFailure"
        spec = {"backoffLimit": 20, "template": template}
    else:
        template["spec"]["restartPolicy"] = "Never"
        spec = {"schedule": extra["schedule"], "concurrencyPolicy": "Forbid", "successfulJobsHistoryLimit": 1,
                "jobTemplate": {"spec": {"backoffLimit": 0, "template": template}}}
    return {"apiVersion": "batch/v1" if kind != "StatefulSet" else "apps/v1", "kind": kind, "metadata": meta, "spec": spec}


def apply(digest, *names):
    kubectl("apply", "-f", "-", stdin=json.dumps({"apiVersion": "v1", "kind": "List",
                                                   "items": [manifest(n, digest) for n in names]}))


def run_pod(name, spec):
    """Run one pod to completion; its log, and whether it succeeded. The pod is deleted afterwards."""
    spec["restartPolicy"] = "Never"
    kubectl("apply", "-f", "-", stdin=json.dumps({"apiVersion": "v1", "kind": "Pod", "metadata": {"name": name}, "spec": spec}))
    while (phase := kubectl("get", "pod", name, "-o", "jsonpath={.status.phase}")) not in ("Succeeded", "Failed"):
        time.sleep(5)
    log = kubectl("logs", name)
    kubectl("delete", "pod", name, "--wait=false")
    return log, phase == "Succeeded"


def sha256(path, size=None):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        left = size if size is not None else float("inf")
        while left > 0 and (b := f.read(min(1 << 20, left))):
            h.update(b)
            left -= len(b)
    return h.hexdigest()


def seed(digest, volume, *pairs):
    """Copy `src:dest` pairs (a file or directory of this PC, a path in the volume) through the mirror export; a pod
    copies them into the volume and checks every sha256. An existing file is never overwritten with other content."""
    stage = MIRROR / "seed" / volume
    shutil.rmtree(stage, ignore_errors=True)
    sums = {}
    for pair in pairs:
        src, dest = (Path(p) for p in pair.split(":"))
        for f in [src] if src.is_file() else sorted(p for p in src.rglob("*") if p.is_file()):
            rel = dest / f.relative_to(src) if src.is_dir() else dest
            (stage / rel).parent.mkdir(parents=True, exist_ok=True)
            if f.suffix == ".sqlite":
                with sqlite3.connect(f"file:{f}?mode=ro", uri=True) as a, sqlite3.connect(stage / rel) as b:
                    a.backup(b)
            else:
                shutil.copy2(f, stage / rel)
            sums[str(rel)] = sha256(stage / rel)
    (stage / "SHA256.json").write_text(json.dumps(sums, indent=1))
    spec = pod_spec("seed", digest, ["ops/live.py", "seed-run", volume], {volume: False, "mirror": True}, False,
                    ("100m", "128Mi", "512Mi"), 60, {})
    log, ok = run_pod(f"seed-{volume}", spec)
    print(log)
    if not ok:
        raise SystemExit(f"seeding {volume} failed")


def seed_run(volume):
    src, dst = Path("/mirror/seed") / volume, Path(APP) / VOLUMES[volume]
    sums = json.loads((src / "SHA256.json").read_text())
    for rel, digest in sums.items():
        if (dst / rel).exists() and sha256(dst / rel) != digest:
            raise SystemExit(f"{volume}/{rel} exists with other content")
        (dst / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src / rel, dst / rel)
        if sha256(dst / rel) != digest:
            raise SystemExit(f"{volume}/{rel}: sha256 differs after the copy")
    print(json.dumps({"volume": volume, "files": len(sums)}))


def mirror(app=APP, out="/mirror"):
    """Each volume into /mirror/<volume>: day files (*.jsonl) appended, and refused if one changed below its mirrored
    length; SQLite ledgers as point-in-time snapshots; other files copied whole when they change. MANIFEST.json
    (size and sha256 of each file, the volume's usage) is written last: a reader trusts only what it lists."""
    for vol, path in VOLUMES.items():
        src, dst = Path(app) / path, Path(out) / vol
        if not src.exists():
            continue
        dst.mkdir(parents=True, exist_ok=True)
        old = json.loads((dst / "MANIFEST.json").read_text())["files"] if (dst / "MANIFEST.json").exists() else {}
        new = {}
        for f in sorted(p for p in src.rglob("*") if p.is_file() and p.name != ".writer.lock" and "-wal" not in p.name
                        and not p.name.endswith("-shm")):
            rel, size, prev = str(f.relative_to(src)), f.stat().st_size, old.get(str(f.relative_to(src)))
            (dst / rel).parent.mkdir(parents=True, exist_ok=True)
            if f.suffix == ".sqlite":
                tmp = dst / f"{rel}.tmp"
                with sqlite3.connect(f"file:{f}?mode=ro", uri=True) as a, sqlite3.connect(tmp) as b:
                    a.backup(b)
                tmp.replace(dst / rel)
                new[rel] = {"size": (dst / rel).stat().st_size, "sha256": sha256(dst / rel)}
                continue
            if prev and size == prev["size"] and (dst / rel).exists():
                new[rel] = prev
                continue
            if f.suffix == ".jsonl" and prev:
                if size < prev["size"] or sha256(f, prev["size"]) != prev["sha256"]:
                    raise SystemExit(f"{vol}/{rel} changed below its mirrored length {prev['size']}")
                with open(f, "rb") as a, open(dst / rel, "r+b") as b:
                    a.seek(prev["size"]), b.seek(prev["size"]), b.truncate()
                    shutil.copyfileobj(a, b)
            else:
                shutil.copy2(f, dst / rel)
            new[rel] = {"size": (dst / rel).stat().st_size, "sha256": sha256(dst / rel)}
        usage = shutil.disk_usage(src)
        (dst / "MANIFEST.json.tmp").write_text(json.dumps({"taken": int(time.time() * 1000), "files": new,
                                                           "used": usage.used, "total": usage.total}))
        (dst / "MANIFEST.json.tmp").replace(dst / "MANIFEST.json")


def restic():
    """Hourly: every live ledger, snapshotted with SQLite's backup, into the homelab's restic repository."""
    snap = Path(tempfile.mkdtemp())
    for vol in LEDGERS:
        for f in (Path(APP) / VOLUMES[vol]).rglob("*.sqlite"):
            out = snap / vol / f.relative_to(Path(APP) / VOLUMES[vol])
            out.parent.mkdir(parents=True, exist_ok=True)
            with sqlite3.connect(f"file:{f}?mode=ro", uri=True) as a, sqlite3.connect(out) as b:
                a.backup(b)
    subprocess.run(["restic", "backup", "--host", NAMESPACE, "--tag", "ledgers", "."], cwd=snap, check=True)


VIEW = "cat /proc/self/uid_map /proc/self/gid_map /proc/self/status /proc/self/mountinfo; ls /proc/self/ns /proc"


def view():
    """The sandbox's view from inside a stage 3 session: UID/GID maps, capabilities, namespaces, mounts, processes."""
    from gate.agent import harness
    from sandbox import session

    work = Path(tempfile.mkdtemp())
    harness.build_workspace(work)
    r = subprocess.run(session.sandbox_command(work, harness.CLIENT, ["/bin/sh", "-c", VIEW]), capture_output=True, text=True)
    keep = [l for l in r.stdout.splitlines() if not l.startswith(("Name", "Umask", "State", "Tgid", "Ngid", "Pid", "PPid",
                                                                    "TracerPid", "Vm", "Rss", "Threads", "voluntary",
                                                                    "nonvoluntary", "Cpus", "Mems", "Sig", "Shd", "FD"))]
    return [" ".join(l.split()[4:5] + l.split()[8:9]) if l.count(" - ") == 1 else l for l in keep if not l.isdigit()]


def reach(host, port):
    try:
        socket.create_connection((host, port), timeout=5).close()
        return True
    except OSError:
        return False


def gate_run(targets):
    """In a runner pod: the frozen hashes, the isolation tests, the sandbox's view, the network from the runner, the
    subscription's windows, and one sandboxed session authenticated by the token alone."""
    from gate.agent import campaigns, harness
    from sandbox import session

    tests = subprocess.run([sys.executable, "-m", "pytest", "-q", "-p", "no:cacheprovider", "gate/tests/test_sandbox.py"],
                           capture_output=True, text=True).stdout.strip().splitlines()
    work = Path(tempfile.mkdtemp())
    session.workspace(work, {}, harness.CLIENT, {})
    run = session.run(work, harness.CLIENT, harness.MODEL, 3, 600, "Reply with the single word READY.")
    result = [d for d in map(json.loads, open(work / "transcript.jsonl")) if d.get("type") == "result"]
    print(json.dumps({
        "harness": harness.harness_hash(), "frozen": json.loads((REPO / "audit/stage3/harness.json").read_text())["harness"],
        "tests": tests[-1] if tests else None, "view": view(), "windows": campaigns.windows(),
        "network": {f"{h}:{p}": reach(h, p) for h, p in json.loads(targets)},
        "session": {"stopped": run["stopped"], "exit": run["exit"], **({k: result[-1].get(k) for k in ("is_error", "result")}
                                                                         if result else {}),
                    "models": sorted(result[-1].get("modelUsage", {})) if result else []}}))


# Reachable from a runner: the model API only; refused: every node's services, the API server, the registry, this
# PC's NFS, the cluster's service network, the tailnet, and IPv6.
TARGETS = [("api.anthropic.com", 443), *[(f"192.168.8.{n}", p) for n in (131, 153, 222, 229) for p in (22, 6443, 10250)],
           ("192.168.8.239", 6443), ("192.168.8.240", 443), ("192.168.8.131", 2049), ("10.43.0.1", 443),
           ("100.126.146.120", 22), ("2606:4700:4700::1111", 443)]


def gate(digest, proc):
    spec = pod_spec("gate", digest, ["ops/live.py", "gate-run", json.dumps(TARGETS)], {}, True, ("500m", "1Gi", "2Gi"),
                    60, {}, proc=proc)
    log, ok = run_pod(f"gate-{proc.lower()}", spec)
    out = REPO / "audit/cluster" / f"gate-{proc.lower()}.json"
    out.write_text(log)
    print(log[-3000:], "ok" if ok else "FAILED", out)


if __name__ == "__main__":
    cmd, *args = sys.argv[1:]
    if cmd == "push":
        jobs.push()
    elif cmd == "apply":
        apply(*args)
    elif cmd == "view":
        print("\n".join(view()))
    else:
        {"seed": seed, "seed-run": seed_run, "gate": gate, "gate-run": gate_run, "mirror": mirror, "restic": restic}[cmd](*args)
