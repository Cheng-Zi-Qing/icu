#!/usr/bin/env python3
import json
import os
import socketserver
import sys
import time
from http.server import BaseHTTPRequestHandler


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def do_GET(self):
        if self.path != "/api/tags":
            self.send_error(404)
            return

        delay = float(os.getenv("OLLAMA_STUB_TAGS_DELAY_SECONDS", "0"))
        if delay > 0:
            time.sleep(delay)

        self._send_json(
            {
                "models": [
                    {"name": "qwen3.5:35b"},
                ]
            }
        )

    def do_POST(self):
        if self.path != "/api/chat":
            self.send_error(404)
            return

        delay = float(os.getenv("OLLAMA_STUB_CHAT_DELAY_SECONDS", "0"))
        if delay > 0:
            time.sleep(delay)

        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length)
        payload = json.loads(body or b"{}")
        messages = payload.get("messages", [])
        user_message = messages[-1]["content"] if messages else ""

        if "请生成图像提示词" in user_message:
            content = "pixel art calm capybara, solid white background"
        else:
            content = "这是一只很淡定的水豚，会轻声提醒你休息。"

        self._send_json({"message": {"content": content}})

    def _send_json(self, payload):
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def main():
    port_file = sys.argv[1]
    with socketserver.TCPServer(("127.0.0.1", 0), Handler) as server:
        with open(port_file, "w", encoding="utf-8") as handle:
            handle.write(str(server.server_address[1]))
        server.serve_forever()


if __name__ == "__main__":
    main()
