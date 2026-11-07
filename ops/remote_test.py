import argparse
import os
import shlex
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

NODES = {"prodesk5": "192.168.8.229", "192.168.8.229": "192.168.8.229"}
SSH = ["ssh", "-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "StrictHostKeyChecking=yes"]
EXCLUDED = (
    "kernel/tests/cli/test_differential.py::test_kernel_matches_witness",
    "reference/tests/test_lean_differential.py::test_runs_agree_bit_for_bit",
)
REMOTE = '''set -eu
root=$1
shift
trap 'rm -rf -- "$root"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
export HOME="$root/h" XDG_CACHE_HOME="$root/h/cache" XDG_CONFIG_HOME="$root/h/config" TMPDIR="$root/t"
unset CARGO_TARGET_DIR PYTEST_ADDOPTS
cd "$root/w"
git add -f -A
nice -n 10 nix --extra-experimental-features 'nix-command flakes' develop -c env TMPDIR="$root/t" pytest "$@"
'''


def arguments(argv):
    parser = argparse.ArgumentParser(usage="%(prog)s <worktree> [node] [pytest args...] (see CLUSTER.md)")
    parser.add_argument("worktree", type=Path)
    argv = sys.argv[1:] if argv is None else argv
    args = parser.parse_args(argv[:1])
    tail = argv[1:]
    node = "prodesk5"
    if tail and tail[0] == "--":
        tail = tail[1:]
    elif tail and not tail[0].startswith("-"):
        node, *tail = tail
    if node not in NODES:
        parser.error("only prodesk5 (192.168.8.229) is allowed; prodesk7 and all other destinations are refused")
    if "--" in tail or any(a == "--basetemp" or a.startswith("--basetemp=") for a in tail):
        parser.error("--basetemp is runner-owned; a pytest '--' separator is not supported")
    worktree = args.worktree.expanduser().resolve()
    try:
        top = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=worktree, check=True,
                             capture_output=True, text=True).stdout.strip()
        if Path(top) != worktree or not (worktree / "flake.nix").is_file():
            raise ValueError("expected the root of a worktree containing flake.nix")
    except (OSError, subprocess.CalledProcessError, ValueError) as e:
        parser.error(f"invalid worktree: {e}")
    return worktree, f"kevin@{NODES[node]}", tail


def files(worktree):
    names = subprocess.run(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                           cwd=worktree, capture_output=True, check=True).stdout.split(b"\0")
    kept = []
    for name in sorted(set(names) - {b""}):
        path = worktree / os.fsdecode(name)
        if name.split(b"/", 1)[0] == b"data" or not os.path.lexists(path):
            continue
        if not path.resolve().is_relative_to(worktree):
            raise ValueError(f"source link escapes the worktree: {path}")
        if path.is_dir():
            raise ValueError(f"nested repositories are not supported: {path}")
        kept.append(name + b"\0")
    return b"".join(kept)


def ssh(host, *command, **kwargs):
    return subprocess.run([*SSH, host, shlex.join(command)], **kwargs)


def run(worktree, host, pytest_args):
    manifest = files(worktree)
    root = f"/tmp/rt.{uuid.uuid4().hex[:8]}"
    rsync = ["rsync", "-a", "-e", shlex.join(SSH)]
    with tempfile.TemporaryDirectory(prefix="mm-remote-") as local:
        bundle = str(Path(local) / "repo.bundle")
        subprocess.run(["git", "bundle", "create", bundle, "HEAD"], cwd=worktree, check=True)
        ssh(host, "mkdir", "-m", "700", root, check=True)
        try:
            print(f"Remote: {host}; disposable directory: {root}", flush=True)
            subprocess.run([*rsync, "--", bundle, f"{host}:{root}/repo.bundle"], check=True)
            ssh(host, "sh", "-c", 'set -eu; mkdir "$1/h" "$1/t"; export HOME="$1/h" XDG_CONFIG_HOME="$1/h/config"; '
                'git clone -q --no-checkout "$1/repo.bundle" "$1/w"',
                "sh", root, check=True)
            subprocess.run([*rsync, "--from0", "--files-from=-", "--", f"{worktree}/", f"{host}:{root}/w/"],
                           input=manifest, check=True)
            options = [*pytest_args, "--basetemp", f"{root}/p", "-p", "no:cacheprovider", "-rs"]
            options += [f"--deselect={test}" for test in EXCLUDED]
            result = ssh(host, "bash", "-c", REMOTE, "bash", root, *options)
            print("Remote exclusions (data/store not shipped): " + ", ".join(EXCLUDED), flush=True)
            print(f"Remote pytest command exit status: {result.returncode}", flush=True)
            return result.returncode
        finally:
            ssh(host, "rm", "-rf", "--", root, check=True)


def main(argv=None):
    try:
        return run(*arguments(argv))
    except (OSError, ValueError, subprocess.CalledProcessError) as e:
        print(f"remote_test: {e}", file=sys.stderr)
        return e.returncode if isinstance(e, subprocess.CalledProcessError) else 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
