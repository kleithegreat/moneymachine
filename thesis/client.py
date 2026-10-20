"""thesis-agent: a thesis agent's only tool. Talks to the daemon over ./thesis-agent.sock."""

import json
import socket
import sys

USAGE = ("usage: ./thesis-agent markets | prices MARKET | fetch URL | register FILE | positions | exit ID REASON"
         " | forecast P")
ARITY = {"markets": 0, "prices": 1, "fetch": 1, "register": 1, "positions": 0, "exit": 2, "forecast": 1}


def call(req):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect("thesis-agent.sock")
    s.sendall(json.dumps(req).encode() + b"\n")
    out = b""
    while not out.endswith(b"\n"):
        chunk = s.recv(65536)
        if not chunk:
            break
        out += chunk
    return out.decode().strip()


def main(argv):
    if not argv or argv[0] not in ARITY or len(argv) - 1 != ARITY[argv[0]]:
        print(USAGE)
        return 2
    args = argv[1:]
    if argv[0] == "register":
        try:
            args = [open(args[0]).read()]
        except OSError as e:
            print(json.dumps({"ok": False, "error": str(e)}))
            return 1
    print(call({"cmd": argv[0], "args": args}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
