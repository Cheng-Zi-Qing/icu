#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/config"
PORT_FILE="$TMP_DIR/ollama.port"
python3 "$ROOT_DIR/tools/testdata/ollama_stub_server.py" "$PORT_FILE" &
SERVER_PID=$!
IMAGE_PORT_FILE="$TMP_DIR/image.port"
python3 "$ROOT_DIR/tools/testdata/image_inference_stub_server.py" "$IMAGE_PORT_FILE" &
IMAGE_SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; kill "$IMAGE_SERVER_PID" 2>/dev/null || true; wait "$IMAGE_SERVER_PID" 2>/dev/null || true; rm -rf "$TMP_DIR"' EXIT

for _ in $(seq 1 50); do
  if [[ -f "$PORT_FILE" ]]; then
    break
  fi
  sleep 0.1
done

PORT="$(cat "$PORT_FILE")"
for _ in $(seq 1 50); do
  if [[ -f "$IMAGE_PORT_FILE" ]]; then
    break
  fi
  sleep 0.1
done

IMAGE_PORT="$(cat "$IMAGE_PORT_FILE")"
cat > "$TMP_DIR/config/settings.json" <<'JSON'
{
  "ai": {
    "local_api": {
      "url": "__OLLAMA_URL__"
    },
    "image_models": [
      {
        "name": "Test SD",
        "url": "test/model",
        "token": "secret-token"
      }
    ]
  }
}
JSON
python3 - <<'PY' "$TMP_DIR/config/settings.json" "$PORT"
from pathlib import Path
import sys

path = Path(sys.argv[1])
port = sys.argv[2]
path.write_text(
    path.read_text(encoding="utf-8").replace("__OLLAMA_URL__", f"http://127.0.0.1:{port}"),
    encoding="utf-8",
)
PY

OUTPUT="$(python3 "$ROOT_DIR/tools/avatar_builder_bridge.py" list-image-models --repo-root "$TMP_DIR")"
echo "$OUTPUT" | rg '"name": "Test SD"' >/dev/null
echo "$OUTPUT" | rg '"url": "test/model"' >/dev/null

PROMPT_OUTPUT="$(python3 "$ROOT_DIR/tools/avatar_builder_bridge.py" optimize-prompt --repo-root "$TMP_DIR" --text '一只淡定的水豚')"
echo "$PROMPT_OUTPUT" | rg '"prompt": "pixel art calm capybara, solid white background"' >/dev/null

PERSONA_OUTPUT="$(python3 "$ROOT_DIR/tools/avatar_builder_bridge.py" generate-persona --repo-root "$TMP_DIR" --text '一只淡定的水豚')"
echo "$PERSONA_OUTPUT" | rg '"persona": "这是一只很淡定的水豚，会轻声提醒你休息。"' >/dev/null

IMAGE_OUTPUT="$(python3 "$ROOT_DIR/tools/avatar_builder_bridge.py" generate-image --prompt 'pixel art calm capybara' --model-url "http://127.0.0.1:${IMAGE_PORT}/models/test-image" --token secret-token --session-id bridge-test)"
IMAGE_PATH="$(python3 - <<'PY' "$IMAGE_OUTPUT"
import json
import sys

print(json.loads(sys.argv[1])["path"])
PY
)"
[[ -f "$IMAGE_PATH" ]]
FILE_SIZE="$(wc -c < "$IMAGE_PATH")"
[[ "$FILE_SIZE" -gt 0 ]]

echo "[test_avatar_builder_bridge] PASS"
