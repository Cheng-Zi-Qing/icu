#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

REPO_ROOT="$TMP_DIR/repo"
APP_SUPPORT_ROOT="$TMP_DIR/app-support"
mkdir -p "$REPO_ROOT/config" "$APP_SUPPORT_ROOT/config"

PORT_FILE="$TMP_DIR/ollama.port"
python3 "$ROOT_DIR/tools/testdata/ollama_stub_server.py" "$PORT_FILE" &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; rm -rf "$TMP_DIR"' EXIT

for _ in $(seq 1 50); do
  if [[ -f "$PORT_FILE" ]]; then
    break
  fi
  sleep 0.1
done

PORT="$(cat "$PORT_FILE")"

cat > "$REPO_ROOT/config/settings.json" <<'JSON'
{
  "ai": {
    "local_api": {
      "url": "http://127.0.0.1:9"
    },
    "image_models": [
      {
        "name": "Repo SD",
        "url": "repo/model",
        "token": "repo-token"
      }
    ]
  }
}
JSON

cat > "$APP_SUPPORT_ROOT/config/settings.json" <<'JSON'
{
  "ai": {
    "local_api": {
      "url": "__OLLAMA_URL__"
    },
    "image_models": [
      {
        "name": "App Support SD",
        "url": "app/model",
        "token": "app-token"
      }
    ]
  }
}
JSON

python3 - <<'PY' "$APP_SUPPORT_ROOT/config/settings.json" "$PORT"
from pathlib import Path
import sys

path = Path(sys.argv[1])
port = sys.argv[2]
path.write_text(
    path.read_text(encoding="utf-8").replace("__OLLAMA_URL__", f"http://127.0.0.1:{port}"),
    encoding="utf-8",
)
PY

OUTPUT="$(
  ICU_APP_SUPPORT_ROOT="$APP_SUPPORT_ROOT" \
  python3 "$ROOT_DIR/tools/avatar_builder_bridge.py" list-image-models --repo-root "$REPO_ROOT"
)"
echo "$OUTPUT" | rg '"name": "App Support SD"' >/dev/null

PROMPT_OUTPUT="$(
  ICU_APP_SUPPORT_ROOT="$APP_SUPPORT_ROOT" \
  python3 "$ROOT_DIR/tools/avatar_builder_bridge.py" optimize-prompt --repo-root "$REPO_ROOT" --text '一只淡定的水豚'
)"
echo "$PROMPT_OUTPUT" | rg '"prompt": "pixel art calm capybara, solid white background"' >/dev/null

echo "[test_avatar_builder_bridge_app_support] PASS"
