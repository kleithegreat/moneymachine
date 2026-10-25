"""The sandbox's only network path. The sandbox has its own network namespace, holding just a loopback interface.
Inside it, `main` (run as the sandbox's first command) listens on 127.0.0.1:PORT, then execs the agent CLI with
HTTPS_PROXY pointing there. Every connection is relayed to a Unix socket, which `Proxy` serves outside the sandbox.
`Proxy` admits only `CONNECT host:443` to its hosts, and logs every request, admitted or refused, as one JSON line."""

import json
import os
import socket
import sys
import threading
import time

PORT = 3128


def pipe(a, b):
    """Copy bytes both ways until either side closes."""
    def copy(src, dst):
        try:
            while data := src.recv(65536):
                dst.sendall(data)
        except OSError:
            pass
        for s in (src, dst):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass

    t = threading.Thread(target=copy, args=(b, a), daemon=True)
    t.start()
    copy(a, b)
    t.join()
    a.close()
    b.close()


class Proxy:
    def __init__(self, socket_path, hosts, log_path):
        self.hosts, self.log_path, self.lock = set(hosts), log_path, threading.Lock()
        self.server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server.bind(str(socket_path))
        self.server.listen()
        threading.Thread(target=self.serve, daemon=True).start()

    def serve(self):
        while True:
            try:
                conn, _ = self.server.accept()
            except OSError:
                return
            threading.Thread(target=self.handle, args=(conn,), daemon=True).start()

    def handle(self, conn):
        head = b""
        while b"\r\n\r\n" not in head and len(head) < 8192 and (data := conn.recv(4096)):
            head += data
        line = head.split(b"\r\n", 1)[0].decode("latin-1")
        method, target = (line.split() + ["", ""])[:2]
        host, _, port = target.rpartition(":")
        allowed = method == "CONNECT" and host in self.hosts and port == "443"
        with self.lock, open(self.log_path, "a") as log:
            log.write(json.dumps({"t": int(time.time() * 1000), "request": line[:300], "allowed": allowed}) + "\n")
        if not allowed:
            conn.sendall(b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n")
            conn.close()
            return
        try:
            upstream = socket.create_connection((host, 443), timeout=30)
            upstream.settimeout(None)
        except OSError:
            conn.sendall(b"HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n")
            conn.close()
            return
        conn.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        pipe(conn, upstream)

    def close(self):
        """Stop accepting: shutting the socket down wakes the blocked accept, which close alone does not."""
        self.server.shutdown(socket.SHUT_RDWR)
        self.server.close()


def main(socket_path, argv):
    listener = socket.create_server(("127.0.0.1", PORT))
    if os.fork():
        os.environ["HTTPS_PROXY"] = os.environ["HTTP_PROXY"] = f"http://127.0.0.1:{PORT}"
        os.execv(argv[0], argv)
    while True:
        conn, _ = listener.accept()
        upstream = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        upstream.connect(socket_path)
        threading.Thread(target=pipe, args=(conn, upstream), daemon=True).start()


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
