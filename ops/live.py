"""The live workloads on the homelab cluster (CLUSTER.md): their manifests, applied with the `deployer` account, and
the mirror steps that run in pods.

    python ops/live.py push                          build and push the image; prints its digest
    python ops/live.py apply <digest> <name>...      apply workloads (WORKLOADS' names)
In pods: `mirror`, `verify`.
"""

import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from diskguard import VOLUMES as VOLUMES  # noqa: E402
from diskguard import capacity  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
REGISTRY = "git.home.lab/admin/moneymachine"
AUTHFILE = Path.home() / ".config/containers/auth.json"
NAMESPACE, CONFIG, NODE, APP = "moneymachine-live", "moneymachine-live.yaml", "prodesk7", "/app/repo"
MIRROR = Path("/srv/moneymachine/mirror")
MIRROR_VERIFY_WAIT = 2 * 10 * 60  # next ten-minute run plus ten minutes to finish copying
LEDGERS = ("thesis", "agent")
CLAIMS = {**VOLUMES, "ws": "data/ws"}  # ws is not mirrored: one copy, the human's choice of 2026-11-14


Json = dict[str, Any]


Size = tuple[str, str, str]
Workload = tuple[str, list[str], dict[str, bool], Size, int, Json]

# name: (kind, command, {volume: read-only}, (cpu, memory request, memory limit), grace seconds, extra)
WORKLOADS: dict[str, Workload] = {
    "sources": (
        "StatefulSet",
        ["python", "-m", "cli", "sources-record", "data/sources_live"],
        {"sources": False},
        ("100m", "256Mi", "512Mi"),
        300,
        {},
    ),
    "datalayer": (
        "StatefulSet",
        ["python", "-m", "cli", "datalayer-record", "data/datalayer"],
        {"datalayer": False},
        ("100m", "256Mi", "512Mi"),
        300,
        {"keys": True},
    ),
    "ws": (
        "StatefulSet",
        ["mmrec", "run", "data/ws"],
        {"ws": False},
        ("250m", "512Mi", "1Gi"),
        30,
        {},
    ),
    "vault": (
        "CronJob",
        ["mmvault", "run", "data/ws", "--user", "0x53375ca9a649f337d83d0834fec0db97640a2a06"],
        {"ws": False},
        ("100m", "256Mi", "512Mi"),
        30,
        {"schedule": "7 * * * *"},
    ),
    "mirror": (
        "CronJob",
        ["python", "ops/live.py", "mirror"],
        {**{v: v not in LEDGERS for v in VOLUMES}, "mirror": False},
        ("200m", "256Mi", "512Mi"),
        600,
        {"schedule": "*/10 * * * *"},
    ),
    "mirror-verify": (
        "CronJob",
        ["python", "ops/live.py", "verify"],
        {**{v: True for v in VOLUMES}, "mirror": True},
        ("200m", "256Mi", "512Mi"),
        600,
        {"schedule": "41 3 * * *"},
    ),
}


def kubectl(*args: str, stdin: str | None = None) -> str:
    env = os.environ | {"KUBECONFIG": str(Path.home() / ".kube" / CONFIG)}
    return subprocess.run(
        ["kubectl", "-n", NAMESPACE, *args], input=stdin, capture_output=True, text=True, env=env, check=True
    ).stdout


def sha256(path: str | Path, size: int | None = None) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        left = size if size is not None else sys.maxsize
        while left > 0 and (b := f.read(min(1 << 20, left))):
            h.update(b)
            left -= len(b)
    return h.hexdigest()


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


def pod_spec(
    name: str,
    digest: str,
    command: list[str],
    volumes: dict[str, bool],
    size: Size,
    grace: int,
    extra: Json,
) -> Json:
    """A restricted pod on prodesk7 running `command`, each volume at its repo path."""
    cpu, memory, limit = size
    mounts: list[Json] = [{"name": "tmp", "mountPath": "/tmp"}, {"name": "scratch", "mountPath": "/scratch"}]
    mounts += [
        {"name": v, "mountPath": "/mirror" if v == "mirror" else f"{APP}/{CLAIMS[v]}", "readOnly": ro}
        for v, ro in volumes.items()
    ]
    vols: list[Json] = [{"name": n, "emptyDir": {"sizeLimit": "2Gi"}} for n in ("tmp", "scratch")]
    vols += [{"name": v, "persistentVolumeClaim": {"claimName": v}} for v in volumes]
    if extra.get("keys"):
        mounts.append({"name": "keys", "mountPath": f"{APP}/.keys.env", "subPath": ".keys.env", "readOnly": True})
        vols.append({"name": "keys", "secret": {"secretName": "datalayer-keys"}})
    return {
        "serviceAccountName": "live",
        "automountServiceAccountToken": False,
        "enableServiceLinks": False,
        "priorityClassName": NAMESPACE,
        "nodeSelector": {"kubernetes.io/hostname": NODE},
        "terminationGracePeriodSeconds": grace,
        "securityContext": {
            "runAsUser": 1000,
            "runAsGroup": 100,
            "fsGroup": 100,
            "runAsNonRoot": True,
            "seccompProfile": {"type": "RuntimeDefault"},
            "appArmorProfile": {"type": "RuntimeDefault"},
        },
        "containers": [
            {
                "name": name,
                "image": f"{REGISTRY}@{digest}",
                "workingDir": APP,
                "command": command,
                "resources": {"requests": {"cpu": cpu, "memory": memory}, "limits": {"memory": limit}},
                "securityContext": {
                    "allowPrivilegeEscalation": False,
                    "readOnlyRootFilesystem": True,
                    "capabilities": {"drop": ["ALL"]},
                },
                "volumeMounts": mounts,
            }
        ],
        "volumes": vols,
    }


def manifest(name: str, digest: str) -> Json:
    kind, command, volumes, size, grace, extra = WORKLOADS[name]
    meta: Json = {"name": name, "labels": {"app": name}}
    template: Json = {
        "metadata": {"labels": {"app": name}},
        "spec": pod_spec(name, digest, command, volumes, size, grace, extra),
    }
    spec: Json
    if kind == "StatefulSet":
        spec = {
            "replicas": 1,
            "serviceName": name,
            "selector": {"matchLabels": {"app": name}},
            "template": template,
        }
    elif kind == "Job":
        template["spec"]["restartPolicy"] = "OnFailure"
        spec = {"backoffLimit": 20, "template": template}
    else:
        template["spec"]["restartPolicy"] = "Never"
        spec = {
            "schedule": extra["schedule"],
            "concurrencyPolicy": "Forbid",
            "successfulJobsHistoryLimit": 1,
            "jobTemplate": {"spec": {"backoffLimit": 0, "template": template}},
        }
    return {
        "apiVersion": "batch/v1" if kind != "StatefulSet" else "apps/v1",
        "kind": kind,
        "metadata": meta,
        "spec": spec,
    }


def apply(digest: str, *names: str) -> None:
    kubectl(
        "apply",
        "-f",
        "-",
        stdin=json.dumps({"apiVersion": "v1", "kind": "List", "items": [manifest(n, digest) for n in names]}),
    )


def mirror_kind(rel: str | Path) -> str:
    """Writer contract for a volume-relative path; the pilot's sandbox (`archive/pilot`) bound each session's `work/` as /work."""
    rel = Path(rel)
    if "work" in rel.parts[:-1]:
        return "plain"
    return {".jsonl": "day", ".sqlite": "ledger"}.get(rel.suffix, "plain")


def mirror_source[T](source: Path, kind: str, read: Callable[..., T], *args: Any) -> T | None:
    """Only plain-source ENOENT is churn; destination failures and recording loss still alarm."""
    try:
        return read(*args)
    except FileNotFoundError as error:
        if error.filename is None or Path(error.filename) not in (source, *source.parents):
            raise
        if kind != "plain":
            raise SystemExit(f"source {source}: {kind} file vanished") from error
        return None


def mirror(app: str | Path = APP, out: str | Path = "/mirror") -> None:
    """Each volume into /mirror/<volume>, the live data's only copy, every step checked; any failure stops the run:
    - outside sandbox workspaces (`work/`), day files (*.jsonl) only grow: shrinkage, rewrites or disappearance are
      refused;
    - day-file sizes are captured before listing bodies; only those prefixes are copied;
    - every copy's bytes are compared with the source's over the same length;
    - SQLite ledgers outside workspaces are integrity-checked snapshots; their disappearance is refused;
    - other files, including workspace notes of any suffix, are copied whole when their size or mtime changes;
      source disappearance at any read omits them. Writers' transient `*.tmp`, locks and SQLite sidecars are excluded.
    MANIFEST.json (size, mtime and sha256 of each file, the source filesystem's available capacity) is written last."""
    for vol, path in VOLUMES.items():
        src, dst = Path(app) / path, Path(out) / vol
        old = json.loads((dst / "MANIFEST.json").read_text())["files"] if (dst / "MANIFEST.json").exists() else {}
        if not src.exists() and not any(mirror_kind(r) != "plain" for r in old):
            continue
        dst.mkdir(parents=True, exist_ok=True)
        new: dict[str, Json] = {}
        days = {
            p: mirror_source(p, "day", p.stat)
            for p in src.rglob("*.jsonl")
            if p.is_file() and mirror_kind(p.relative_to(src)) == "day"
        }
        files = set(days) | {
            p
            for p in src.rglob("*")
            if p.is_file()
            and mirror_kind(p.relative_to(src)) != "day"
            and p.suffix != ".tmp"
            and p.name != ".writer.lock"
            and "-wal" not in p.name
            and not p.name.endswith("-shm")
        }
        for f in sorted(files):
            rel = str(f.relative_to(src))
            kind = mirror_kind(rel)
            st = days[f] if f in days else mirror_source(f, kind, f.stat)
            if st is None:
                continue
            prev, target = old.get(rel), dst / rel
            if prev and (not target.exists() or target.stat().st_size < prev["size"]):
                raise SystemExit(f"{vol}/{rel}: the mirror lost bytes its manifest lists")
            target.parent.mkdir(parents=True, exist_ok=True)
            tmp = target.with_name(target.name + ".tmp")
            if kind == "ledger":
                with sqlite3.connect(f"file:{f}?mode=ro", uri=True) as a, sqlite3.connect(tmp) as b:
                    a.backup(b)
                    if b.execute("pragma integrity_check").fetchone()[0] != "ok":
                        raise SystemExit(f"{vol}/{rel}: the snapshot fails SQLite's integrity check")
                tmp.replace(target)
                new[rel] = {"size": target.stat().st_size, "mtime": st.st_mtime_ns, "sha256": sha256(target)}
                continue
            if prev and kind == "day" and (st.st_size < prev["size"] or sha256(f, prev["size"]) != prev["sha256"]):
                raise SystemExit(f"{vol}/{rel} changed below its mirrored length {prev['size']}")
            if prev and st.st_size == prev["size"] and st.st_mtime_ns == prev["mtime"]:
                new[rel] = prev
                continue
            if kind == "day":
                start = prev["size"] if prev else 0
                with open(f, "rb") as a, open(target if prev else tmp, "r+b" if prev else "wb") as b:
                    a.seek(start), b.seek(start), b.truncate()
                    left = st.st_size - start
                    while left > 0 and (block := a.read(min(1 << 20, left))):
                        b.write(block)
                        left -= len(block)
                    if left:
                        raise SystemExit(f"{vol}/{rel}: source shrank during the copy")
            else:
                if mirror_source(f, kind, shutil.copy2, f, tmp) is None:
                    tmp.unlink(missing_ok=True)
                    continue
            copied = target if kind == "day" and prev else tmp
            size = copied.stat().st_size
            source_digest = mirror_source(f, kind, sha256, f, size)
            if source_digest is None:
                tmp.unlink(missing_ok=True)
                continue
            if source_digest != (digest := sha256(copied)):
                raise SystemExit(f"{vol}/{rel}: the copy differs from its source")
            if copied != target:
                tmp.replace(target)
            new[rel] = {"size": size, "mtime": st.st_mtime_ns, "sha256": digest}
        if gone := [r for r in old if mirror_kind(r) != "plain" and r not in new]:
            raise SystemExit(f"{vol}: recording files vanished from the source: {gone}")
        usage = capacity(src)
        (dst / "MANIFEST.json.tmp").write_text(
            json.dumps({"taken": int(time.time() * 1000), "files": new, "capacity": usage})
        )
        (dst / "MANIFEST.json.tmp").replace(dst / "MANIFEST.json")


def verify(app: str | Path = APP, out: str | Path = "/mirror") -> None:
    """Daily: verify prefixes; confirm mirror mismatches against a later manifest within MIRROR_VERIFY_WAIT."""
    for vol, path in VOLUMES.items():
        dst = Path(out) / vol
        if not (dst / "MANIFEST.json").exists():
            raise SystemExit(f"mirror {vol}: missing manifest")
        record = json.loads((dst / "MANIFEST.json").read_text())
        pending: set[str] = set()
        deadline = time.monotonic() + MIRROR_VERIFY_WAIT
        while True:
            mismatch = None
            for rel, e in record["files"].items():
                if mirror_kind(rel) == "day":
                    source = Path(app) / path / rel
                    if mirror_source(source, "day", sha256, source, e["size"]) != e["sha256"]:
                        raise SystemExit(f"source {vol}/{rel} differs from its manifest")
                try:
                    matches = sha256(dst / rel, e["size"]) == e["sha256"]
                except FileNotFoundError:
                    matches = False
                if not matches:
                    mismatch = rel
            if mismatch is None:
                break
            latest = json.loads((dst / "MANIFEST.json").read_text())
            if latest != record:
                pending.add(mismatch)
                record = latest
            elif mismatch in pending or (remaining := deadline - time.monotonic()) <= 0:
                raise SystemExit(f"mirror {vol}/{mismatch} differs from its manifest")
            else:
                time.sleep(min(5, remaining))
    print("verified")


if __name__ == "__main__":
    cmd, *args = sys.argv[1:]
    if cmd == "push":
        push()
    elif cmd == "apply":
        apply(*args)
    else:
        commands: dict[str, Callable[..., None]] = {"mirror": mirror, "verify": verify}
        commands[cmd](*args)
