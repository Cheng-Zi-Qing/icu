#!/usr/bin/env python3
import socketserver
import sys
from http.server import BaseHTTPRequestHandler


PNG_BYTES = (
    b"\x89PNG\r\n\x1a\n"
    b"\x00\x00\x00\rIHDR"
    b"\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00"
    b"\x90wS\xde"
    b"\x00\x00\x00\x0cIDATx\x9cc```\x00\x00\x00\x04\x00\x01"
    b"\x0b\xe7\x02\x9d"
    b"\x00\x00\x00\x00IEND\xaeB`\x82"
)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def do_POST(self):
        if self.path != "/models/test-image":
            self.send_error(404)
            return

        if self.headers.get("Authorization") != "Bearer secret-token":
            self.send_error(401)
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(content_length)

        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(PNG_BYTES)))
        self.end_headers()
        self.wfile.write(PNG_BYTES)


def main():
    port_file = sys.argv[1]
    with socketserver.TCPServer(("127.0.0.1", 0), Handler) as server:
        with open(port_file, "w", encoding="utf-8") as handle:
            handle.write(str(server.server_address[1]))
        server.serve_forever()


if __name__ == "__main__":
    main()
