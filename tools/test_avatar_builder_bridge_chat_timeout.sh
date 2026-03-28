#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/config"
PORT_FILE="$TMP_DIR/ollama.port"
OLLAMA_STUB_CHAT_DELAY_SECONDS=31 python3 "$ROOT_DIR/tools/testdata/ollama_stub_server.py" "$PORT_FILE" &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; rm -rf "$TMP_DIR"' EXIT

for _ in $(seq 1 50); do
  if [[ -f "$PORT_FILE" ]]; then
    break
  fi
  sleep 0.1
done

PORT="$(cat "$PORT_FILE")"
cat > "$TMP_DIR/config/settings.json" <<JSON
{
  "ai": {
    "local_api": {
      "url": "http://127.0.0.1:${PORT}"
    }
  }
}
JSON

OUTPUT="$(python3 "$ROOT_DIR/tools/avatar_builder_bridge.py" optimize-prompt --repo-root "$TMP_DIR" --text '一只淡定的水豚')"
echo "$OUTPUT" | rg '"prompt": "pixel art calm capybara, solid white background"' >/dev/null

echo "[test_avatar_builder_bridge_chat_timeout] PASS"
