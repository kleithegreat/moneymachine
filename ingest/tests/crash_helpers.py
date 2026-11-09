"""Black-box subprocess cuts at public-operation boundaries, with seeded timing jitter."""

import importlib
import json
import os
import random
import selectors
import signal
import subprocess
import sys
import time


def checkpoint(name, interactive):
    print(json.dumps({"checkpoint": name}), flush=True)
    if interactive and sys.stdin.readline() != "go\n":
        raise RuntimeError("crash controller disconnected")


def acknowledge(value):
    print(json.dumps({"ack": value}), flush=True)


def command(module, root, phase):
    return [sys.executable, "-m", "ingest.tests.crash_helpers", module, str(root), phase]


def kill_during(module, root, target, seed):
    """SIGKILL the worker and its children after a seeded delay from `target`; return completed-call acks."""
    child = subprocess.Popen(
        command(module, root, "crash"),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
        bufsize=0,
    )
    acks = []
    deadline = time.monotonic() + 60
    selector = selectors.DefaultSelector()
    selector.register(child.stdout, selectors.EVENT_READ)
    try:
        while time.monotonic() < deadline:
            assert selector.select(max(0, deadline - time.monotonic())), f"worker stalled before {target}"
            line = child.stdout.readline()
            assert line, f"worker exited before {target}: {child.stderr.read()}"
            event = json.loads(line)
            if "ack" in event:
                acks.append(event["ack"])
                continue
            child.stdin.write(b"go\n")
            child.stdin.flush()
            if event["checkpoint"] == target:
                time.sleep(random.Random(seed).uniform(0, 0.025))
                os.killpg(child.pid, signal.SIGKILL)
                rest, stderr = child.communicate(timeout=10)
                acks.extend(json.loads(line)["ack"] for line in rest.splitlines() if "ack" in json.loads(line))
                assert child.returncode == -signal.SIGKILL, stderr
                return acks
        raise AssertionError(f"worker never reached {target}")
    finally:
        selector.close()
        if child.poll() is None:
            os.killpg(child.pid, signal.SIGKILL)
        child.communicate(timeout=10)


def recover(module, root):
    result = subprocess.run(command(module, root, "recover"), capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, result.stdout + result.stderr


if __name__ == "__main__":
    module, root, phase = sys.argv[1:]
    importlib.import_module(module).worker(root, phase == "crash")
