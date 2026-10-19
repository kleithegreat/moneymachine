"""mm-agent: the research agent's only tool. Talks to the daemon over ./mm-agent.sock."""

import json
import socket
import sys

USAGE = """usage: ./mm-agent check FILE | eval FILE | select FILE [FILE ...] | budget"""


def call(req):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect("mm-agent.sock")
    s.sendall(json.dumps(req).encode() + b"\n")
    out = b""
    while not out.endswith(b"\n"):
        chunk = s.recv(65536)
        if not chunk:
            break
        out += chunk
    return out.decode().strip()


def main(argv):
    if len(argv) < 1 or argv[0] not in ("check", "eval", "select", "budget"):
        print(USAGE)
        return 2
    cmd, files = argv[0], argv[1:]
    if cmd in ("check", "eval") and len(files) != 1:
        print(USAGE)
        return 2
    texts = []
    for f in files:
        try:
            texts.append(open(f).read())
        except OSError as e:
            print(json.dumps({"ok": False, "error": str(e)}))
            return 1
    print(call({"cmd": cmd, "programs": texts}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
