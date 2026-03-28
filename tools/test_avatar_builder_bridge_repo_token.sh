#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/config"
PORT_FILE="$TMP_DIR/image.port"
python3 "$ROOT_DIR/tools/testdata/image_inference_stub_server.py" "$PORT_FILE" &
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
    "image_models": [
      {
        "name": "Test SD",
        "url": "http://127.0.0.1:${PORT}/models/test-image",
        "token": "secret-token"
      }
    ]
  }
}
JSON

OUTPUT="$(python3 "$ROOT_DIR/tools/avatar_builder_bridge.py" generate-image --repo-root "$TMP_DIR" --prompt 'pixel art calm capybara' --model-url "http://127.0.0.1:${PORT}/models/test-image" --session-id bridge-test-repo-token)"
IMAGE_PATH="$(python3 - <<'PY' "$OUTPUT"
import json
import sys

print(json.loads(sys.argv[1])["path"])
PY
)"
[[ -f "$IMAGE_PATH" ]]

echo "[test_avatar_builder_bridge_repo_token] PASS"
