"""A daemon's socket: one JSON request line per connection, answered by `handle(request)` with bytes (one
line). A line that is not JSON reaches `handle` as {"cmd": None, "raw": its first 200 bytes}."""

import json
import socketserver
import threading
from pathlib import Path

MAX_REQUEST = 1 << 20


class Server:
    def __init__(self, socket_path, handle):
        class Handler(socketserver.StreamRequestHandler):
            def handle(self):
                raw = self.rfile.readline(MAX_REQUEST)
                try:
                    req = json.loads(raw)
                except json.JSONDecodeError:
                    req = {"cmd": None, "raw": raw[:200].decode("utf-8", "replace")}
                self.wfile.write(handle(req if isinstance(req, dict) else {"cmd": None, "raw": str(req)[:200]}) + b"\n")

        self.socket_path = Path(socket_path)
        self.socket_path.unlink(missing_ok=True)
        self.server = socketserver.ThreadingUnixStreamServer(str(self.socket_path), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.socket_path.unlink(missing_ok=True)
