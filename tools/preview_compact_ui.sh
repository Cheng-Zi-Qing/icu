#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export ICU_REPO_ROOT="$ROOT_DIR"

echo "[compact_ui_preview] Building preview launcher..."
swiftc -framework AppKit \
  $(find "$ROOT_DIR/apps/macos-shell/Sources/ICUShell" -name '*.swift' ! -name 'main.swift' | sort | tr '\n' ' ') \
  "$ROOT_DIR/apps/macos-shell/Preview/CompactUIPreviewMain.swift" \
  -o "$TMP_DIR/compact-ui-preview"

echo "[compact_ui_preview] Launching preview launcher..."
"$TMP_DIR/compact-ui-preview" &
PREVIEW_PID=$!

# When launched from a terminal, explicitly raise the preview window above the shell.
for _ in {1..40}; do
  if pgrep -x compact-ui-preview >/dev/null 2>&1; then
    osascript -e 'tell application "System Events" to tell process "compact-ui-preview" to set frontmost to true' >/dev/null 2>&1 || true
    break
  fi
  sleep 0.1
done

wait "$PREVIEW_PID"
