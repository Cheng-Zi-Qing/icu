#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_PATH="$ROOT_DIR/apps/macos-shell"
SWIFT_BIN="${ICU_SHELL_SWIFT_BIN:-swift}"
source "$ROOT_DIR/tools/swift_package_scratch_path.sh"

SCRATCH_PATH="${ICU_SHELL_SWIFT_SCRATCH_PATH:-$(swift_package_scratch_path "$PACKAGE_PATH")}"
mkdir -p "$SCRATCH_PATH"

export ICU_REPO_ROOT="$ROOT_DIR"

echo "[run_macos_shell] Launching ICUShell..."
exec "$SWIFT_BIN" run --package-path "$PACKAGE_PATH" --scratch-path "$SCRATCH_PATH" ICUShell
