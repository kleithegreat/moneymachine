"""An agent's only tool inside the sandbox: one command per call, sent to its daemon over a Unix socket in
the workspace. The workspace writes SPEC above this text: the socket's name, the usage line, and per command
its arity (a count, or "+" for one or more) and whether its arguments are files to send as text."""

import json
import socket
import sys


def call(req):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SPEC["socket"])
    s.sendall(json.dumps(req).encode() + b"\n")
    out = b""
    while not out.endswith(b"\n"):
        chunk = s.recv(65536)
        if not chunk:
            break
        out += chunk
    return out.decode().strip()


def main(argv):
    spec = SPEC["commands"].get(argv[0]) if argv else None
    refusal, status = None, 0
    args = argv[1:]
    if spec is None or (len(argv) - 1 != spec[0] if spec[0] != "+" else len(argv) < 2):
        refusal, status = SPEC["usage"], 2
    elif "file" in spec:
        try:
            args = [open(a).read() for a in args]
        except (OSError, UnicodeError, ValueError) as e:
            refusal, status = f"unreadable FILE: {e}", 1
    print(call({"cmd": argv[0] if refusal is None else None, "args": args if refusal is None else [],
                "argv": argv, "refusal": refusal}))
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
