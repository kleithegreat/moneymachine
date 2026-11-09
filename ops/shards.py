"""One test-suite run across this desktop and the idle nodes (CLUSTER.md section 7)."""

import argparse
import io
import json
import os
import re
import shlex
import shutil
import statistics
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

SSH = [
    "ssh",
    "-T",
    "-o",
    "BatchMode=yes",
    "-o",
    "ConnectTimeout=10",
    "-o",
    "ServerAliveInterval=15",
    "-o",
    "ServerAliveCountMax=4",
    "-o",
    "StrictHostKeyChecking=yes",
]
NODES = {"prodesk5": ("kevin@192.168.8.229", 6), "gmktec": ("kevin@192.168.8.153", 8), "prodesk7": ("prodesk7", 5)}
UNIT = "prodesk7"
UNIT_STAGE = "/var/lib/mmtest/stage"
ROOT = "/home/kevin/.cache/mm-runner"
TMP = "/dev/shm/mm-runner"
LOCAL = "local"
LOCAL_ONLY = (
    "kernel/tests/cli/test_differential.py::test_kernel_matches_witness",
    "reference/tests/",
    "gate/tests/test_sandbox.py",
)
DURATIONS = Path.home() / ".cache/mm-shards/durations.json"
SLOWNESS = "_slowness"
OVERHEAD = "_overhead"
BOUND = 3900
LOG_CAP = 8 << 20
REPORT_CAP = 16 << 20
REMOTE = """set -eu
root=$1
tmp=$2
report=$3
workers=$4
export PATH=$PATH:/nix/var/nix/profiles/default/bin
mkdir -p -m 700 "$root" && cd "$root"
mkdir -p h
parent=$PPID
( while [ "$(ps -o ppid= -p $$ | tr -d ' ')" = "$parent" ]; do sleep 2; done; pkill -TERM -s $$ ) &
watchdog=$!
trap 'kill $watchdog 2>/dev/null; rm -rf -- "$root/in" "$tmp"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
exec 9>lock
flock 9
mkdir -p -m 700 "$tmp"
rm -rf in
find . -maxdepth 1 -name 'report.*.json' -mmin +120 -delete
mkdir in
tar -xz -C in
export HOME="$root/h" XDG_CACHE_HOME="$root/h/cache" XDG_CONFIG_HOME="$root/h/config" TMPDIR="$tmp"
unset CARGO_TARGET_DIR PYTEST_ADDOPTS
[ -d w/.git ] || git init -q w
cd w
mkdir -p data
git fetch -q "$root/in/repo.bundle" HEAD
git reset -q --hard FETCH_HEAD
git clean -fdq
rsync -a "$root/in/files/" ./
xargs -0 -r -a "$root/in/deleted" git rm -q -f --ignore-unmatch --
xargs -0 -r -a "$root/in/manifest" git add -f --
timeout 3600 nice -n 10 nix --extra-experimental-features 'nix-command flakes' develop -c env TMPDIR="$tmp" \\
    pytest -n "$workers" "@$root/in/ids" --shard-report "$report" --basetemp "$tmp/p" -p no:cacheprovider -q
"""


def arguments(argv):
    parser = argparse.ArgumentParser(
        usage="%(prog)s <worktree> [--machines local,prodesk5,gmktec] [pytest selection args...]",
        description="Selection arguments (paths, -k, -m) go to collection only; the shards run the collected ids.",
    )
    parser.add_argument("worktree", type=Path)
    parser.add_argument("--machines", default=",".join([LOCAL, *NODES]))
    args, selection = parser.parse_known_args(sys.argv[1:] if argv is None else argv)
    machines = args.machines.split(",")
    if (
        LOCAL not in machines
        or any(m != LOCAL and m not in NODES for m in machines)
        or len(set(machines)) != len(machines)
    ):
        parser.error(f"--machines takes {LOCAL} and any of {', '.join(NODES)}; every other node is refused")
    if any(a == "--basetemp" or a.startswith(("--basetemp=", "--junitxml", "-p", "-n", "--dist")) for a in selection):
        parser.error("the runner owns --basetemp, --junitxml, -p, -n and --dist")
    worktree = args.worktree.expanduser().resolve()
    try:
        top = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"], cwd=worktree, check=True, capture_output=True, text=True
        ).stdout.strip()
        if Path(top) != worktree or not (worktree / "flake.nix").is_file():
            raise ValueError("expected the root of a worktree containing flake.nix")
    except (OSError, subprocess.CalledProcessError, ValueError) as e:
        parser.error(f"invalid worktree: {e}")
    return worktree, machines, selection


def files(worktree):
    """(names to ship, names deleted here): the current tree, without data/ and ignored files, as NUL-terminated bytes."""
    names = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=worktree,
        capture_output=True,
        check=True,
    ).stdout.split(b"\0")
    kept, gone = [], []
    for name in sorted(set(names) - {b""}):
        path = worktree / os.fsdecode(name)
        if name.split(b"/", 1)[0] == b"data":
            continue
        if not os.path.lexists(path):
            gone.append(name + b"\0")
            continue
        if not path.resolve().is_relative_to(worktree):
            raise ValueError(f"source link escapes the worktree: {path}")
        if path.is_dir():
            raise ValueError(f"nested repositories are not supported: {path}")
        kept.append(name + b"\0")
    return b"".join(kept), b"".join(gone)


def collect(worktree, selection):
    out = subprocess.run(
        ["nix", "develop", "-c", "pytest", "--collect-only", "-q", "-n0", "-p", "no:cacheprovider", *selection],
        cwd=worktree,
        capture_output=True,
        text=True,
        env=dict(os.environ, PYTEST_ADDOPTS=""),
    )
    if out.returncode:
        raise ValueError(f"collection failed:\n{out.stdout[-3000:]}{out.stderr[-3000:]}")
    ids = [line for line in out.stdout.splitlines() if re.match(r"^\S+\.py::", line)]
    if len(set(ids)) != len(ids) or not ids:
        raise ValueError("collection gave no tests or repeated ids")
    return ids


def assign(ids, durations, cores, overhead):
    """{machine: ids}: the local-only tests on the desktop, the rest longest first onto the machine that would finish
    soonest. `cores` is each machine's speed: its cores over how much slower than predicted its last run was; `overhead`
    is the seconds each machine spends outside its tests (transfer, Nix, collection, worker start, the tail)."""
    guess = statistics.median(durations.values()) if durations else 1.0
    load = {m: overhead.get(m, 0.0) for m in cores}
    shards = {m: [] for m in cores}
    local = [i for i in ids if i.startswith(LOCAL_ONLY)]
    rest = sorted((i for i in ids if not i.startswith(LOCAL_ONLY)), key=lambda i: -durations.get(i, guess))
    for i in local:
        shards[LOCAL].append(i)
        load[LOCAL] += durations.get(i, guess) / cores[LOCAL]
    for i in rest:
        m = min(cores, key=lambda m: load[m] + durations.get(i, guess) / cores[m])
        shards[m].append(i)
        load[m] += durations.get(i, guess) / cores[m]
    return shards


def package(worktree, ids, tar_path) -> None:
    manifest, deleted = files(worktree)
    with tempfile.TemporaryDirectory(prefix="mm-bundle-") as scratch:
        bundle = Path(scratch) / "repo.bundle"
        subprocess.run(["git", "bundle", "create", "-q", str(bundle), "HEAD"], cwd=worktree, check=True)
        with tarfile.open(tar_path, "w:gz", compresslevel=1) as tar:
            tar.add(bundle, "repo.bundle")
            for name, data in (("ids", "\n".join(ids).encode() + b"\n"), ("manifest", manifest), ("deleted", deleted)):
                info = tarfile.TarInfo(name)
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
            for name in manifest.split(b"\0")[:-1]:
                tar.add(worktree / os.fsdecode(name), "files/" + os.fsdecode(name), recursive=False)


def run_local(worktree, ids, log, report):
    with tempfile.TemporaryDirectory(prefix="mm-shard-", dir="/dev/shm") as tmp:
        (Path(tmp) / "ids").write_text("\n".join(ids) + "\n")
        command = [
            "nix",
            "develop",
            "-c",
            "env",
            f"TMPDIR={tmp}",
            "pytest",
            f"@{tmp}/ids",
            "--shard-report",
            str(report),
            "--basetemp",
            f"{tmp}/p",
            "-p",
            "no:cacheprovider",
            "-q",
        ]
        return subprocess.run(
            command,
            cwd=worktree,
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            env=dict(os.environ, PYTEST_ADDOPTS=""),
        ).returncode


def run_node(worktree, host, ids, log, report):
    run = uuid.uuid4().hex[:8]
    with tempfile.TemporaryDirectory(prefix="mm-shard-") as scratch:
        tar_path = Path(scratch) / "in.tar.gz"
        package(worktree, ids, tar_path)
        with tar_path.open("rb") as tar:
            try:
                code = subprocess.run(
                    [
                        *SSH,
                        host,
                        shlex.join(["bash", "-c", REMOTE, "bash", ROOT, TMP, f"{ROOT}/report.{run}.json", "auto"]),
                    ],
                    stdin=tar,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    timeout=BOUND,
                ).returncode
            except subprocess.TimeoutExpired:
                code = 124
    try:
        got = subprocess.run(
            [*SSH, host, shlex.join(["sh", "-c", 'cat "$1" && rm -f "$1"', "sh", f"{ROOT}/report.{run}.json"])],
            capture_output=True,
            timeout=60,
        )
    except subprocess.TimeoutExpired:
        return code
    if got.returncode == 0:
        Path(report).write_bytes(got.stdout)
    return code


def unit_file(host, path, cap):
    """At most cap + 1 bytes of a file the unit wrote: more than cap tells the caller it was too big, and nothing is held beyond that."""
    return subprocess.run(
        [*SSH, host, shlex.join(["head", "-c", str(cap + 1), path])], capture_output=True, timeout=60
    ).stdout


def run_unit(worktree, host, ids, log, report, workers):
    """prodesk7: stage the package for `mm-tests@<run>.service` (Homelab role mm-test-node), which runs REMOTE as mmtest
    under its memory cap. The held stdin pipe is the unit's lifeline: if this process dies, the wrapper stops the unit."""
    run = uuid.uuid4().hex[:8]
    stage = f"{UNIT_STAGE}/{run}"
    with tempfile.TemporaryDirectory(prefix="mm-shard-") as scratch:
        tar_path = Path(scratch) / "in.tar.gz"
        package(worktree, ids, tar_path)
        prepare = (
            'find "$1" -mindepth 1 -maxdepth 1 -mmin +180 -exec rm -rf {} + ; umask 027 && mkdir -m 750 "$2" && cd "$2" && '
            'printf %s "$3" > run.sh && printf %s "$4" > workers && : > out.log && : > report.json && chmod 660 out.log report.json && cat > in.tar.gz'
        )
        with tar_path.open("rb") as tar:
            put = subprocess.run(
                [*SSH, host, shlex.join(["sh", "-c", prepare, "sh", UNIT_STAGE, stage, REMOTE, str(workers)])],
                stdin=tar,
                stdout=log,
                stderr=subprocess.STDOUT,
                timeout=600,
            ).returncode
    code = put
    if not put:
        with subprocess.Popen(
            [*SSH, host, shlex.join(["sudo", "mm-tests", "start", run])],
            stdin=subprocess.PIPE,
            stdout=log,
            stderr=subprocess.STDOUT,
        ) as start:
            try:
                code = start.wait(timeout=BOUND)
            except subprocess.TimeoutExpired:
                code = 124
            start.stdin.close()
        text = unit_file(host, f"{stage}/out.log", LOG_CAP)
        log.write(
            text[:LOG_CAP].decode(errors="replace")
            + (f"\n[log truncated at {LOG_CAP} bytes]\n" if len(text) > LOG_CAP else "")
        )
        log.flush()
        data = unit_file(host, f"{stage}/report.json", REPORT_CAP)
        if 0 < len(data) <= REPORT_CAP:
            Path(report).write_bytes(data)
    subprocess.run([*SSH, host, shlex.join(["rm", "-rf", stage])], capture_output=True, timeout=60)
    return code


def shard_result(report):
    try:
        return json.loads(Path(report).read_text())
    except (OSError, ValueError):
        return {}


def rerun(shards, rows):
    """The tests of the nodes that no result or a skip came back for: a node may lack what this PC has."""
    return [
        i for m, part in shards.items() if m != LOCAL for i in part if i not in rows or rows[i]["outcome"] == "skipped"
    ]


def update(durations, slowness, ran, rows, ids, full):
    """(durations, slowness) after a run. Durations are in this PC's seconds: a machine's slowness is how much longer its
    tests took than the stored durations (of the tests that last over half a second), and a run's seconds are divided by
    it. A full collection forgets ids that no longer exist."""
    slowness = dict(slowness)
    for m in set(ran.values()):
        known = [
            (rows[i]["seconds"], durations[i])
            for i, r in ran.items()
            if r == m and i in rows and durations.get(i, 0) > 0.5
        ]
        if known:
            slowness[m] = (slowness.get(m, 1.0) + sum(a for a, _ in known) / sum(b for _, b in known)) / 2
    kept = {i: d for i, d in durations.items() if not full or i in set(ids)}
    for i, m in ran.items():
        if i in rows:
            seconds = rows[i]["seconds"] / slowness.get(m, 1.0)
            kept[i] = (kept[i] + seconds) / 2 if i in kept else seconds
    return kept, slowness


def learn_overhead(overhead, walls, ran, rows, count):
    """Each machine's wall seconds beyond its tests' seconds spread over its `count` cores, averaged with the last value."""
    overhead = dict(overhead)
    for m, wall in walls.items():
        seconds = [rows[i]["seconds"] for i, r in ran.items() if r == m]
        if seconds:
            overhead[m] = (overhead.get(m, 0.0) + max(0.0, wall - sum(seconds) / count[m])) / 2
    return overhead


def write_durations(path, durations, slowness, overhead) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps({**durations, SLOWNESS: slowness, OVERHEAD: overhead}))
    os.replace(temp, path)


def run(worktree, machines, selection) -> int:
    started = time.time()
    ids = collect(worktree, selection)
    try:
        durations = json.loads(DURATIONS.read_text())
    except (OSError, ValueError):
        durations = {}
    slowness = durations.pop(SLOWNESS, {})
    overhead = durations.pop(OVERHEAD, {})
    count = {m: os.cpu_count() if m == LOCAL else NODES[m][1] for m in machines}
    cores = {m: count[m] / slowness.get(m, 1.0) for m in machines}
    shards = assign(ids, durations, cores, overhead)
    out = Path(tempfile.mkdtemp(prefix="mm-shards-"))
    print(f"{len(ids)} tests collected in {time.time() - started:.0f}s; logs in {out}", flush=True)
    for m, part in shards.items():
        predicted = overhead.get(m, 0.0) + sum(durations.get(i, 1.0) for i in part) / cores[m]
        print(f"  {m}: {len(part)} tests, about {predicted:.0f}s", flush=True)

    walls = {}

    def go(m, part, tag=""):
        t = time.time()
        log, report = out / f"{m}{tag}.log", out / f"{m}{tag}.json"
        with log.open("w") as handle:
            if m == LOCAL:
                code = run_local(worktree, part, handle, report)
            elif m == UNIT:
                code = run_unit(worktree, NODES[m][0], part, handle, report, count[m])
            else:
                code = run_node(worktree, NODES[m][0], part, handle, report)
        walls[m] = time.time() - t
        print(f"  {m}{tag} finished: exit {code} in {walls[m]:.0f}s", flush=True)
        return m, code, shard_result(report)

    with ThreadPoolExecutor(len(machines)) as pool:
        results = list(pool.map(lambda kv: go(*kv), [(m, part) for m, part in shards.items() if part]))
    rows, codes, ran = {}, {}, {}
    for m, code, report in results:
        rows.update(report)
        codes[m] = code
        ran.update({i: m for i in report})
    learned = learn_overhead(overhead, walls, ran, rows, count)
    lost = rerun(shards, rows)
    if lost:
        print(f"{len(lost)} tests that a node skipped or gave no result for are rerun here", flush=True)
        _, code, report = go(LOCAL, lost, ".rerun")
        rows.update(report)
        ran.update({i: LOCAL for i in report})
        codes["rerun"] = code
    missing = [i for i in ids if i not in rows]
    kept, slowness = update(durations, slowness, ran, rows, ids, not selection)
    write_durations(DURATIONS, kept, slowness, learned)
    counts = {}
    for r in rows.values():
        counts[r["outcome"]] = counts.get(r["outcome"], 0) + 1
    bad = {i: r for i, r in rows.items() if r["outcome"] in ("failed", "error")}
    for i, r in sorted(bad.items()):
        print(f"{r['outcome'].upper()} {i}\n{r.get('text', '')}", flush=True)
    for i in missing:
        print(f"MISSING {i}: no shard reported it", flush=True)
    print(
        f"{len(rows)} of {len(ids)} tests reported: {', '.join(f'{n} {k}' for k, n in sorted(counts.items()))}; "
        f"{len(missing)} missing; shard exits {codes}; wall {time.time() - started:.0f}s",
        flush=True,
    )
    ok = not bad and not missing and all(c == 0 for c in codes.values())
    if ok:
        shutil.rmtree(out)
    return 0 if ok else 1


def main(argv=None):
    try:
        return run(*arguments(argv))
    except (OSError, ValueError, subprocess.CalledProcessError) as e:
        print(f"shards: {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
