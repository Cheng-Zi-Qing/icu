#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_PATH="$ROOT_DIR/apps/macos-shell"
SWIFT_BIN="${VERIFY_MACOS_SHELL_SWIFT_BIN:-swift}"
XCODEBUILD_BIN="${VERIFY_MACOS_SHELL_XCODEBUILD_BIN:-xcodebuild}"
CHECK_SCRIPT="${VERIFY_MACOS_SHELL_CHECK_SCRIPT:-$ROOT_DIR/tools/check_native_shell.sh}"
source "$ROOT_DIR/tools/swift_package_scratch_path.sh"

SCRATCH_PATH="${VERIFY_MACOS_SHELL_SCRATCH_PATH:-$(swift_package_scratch_path "$PACKAGE_PATH")}"
mkdir -p "$SCRATCH_PATH"

echo "[verify_macos_shell] Running swift build..."
"$SWIFT_BIN" build --package-path "$PACKAGE_PATH" --scratch-path "$SCRATCH_PATH"

echo "[verify_macos_shell] Running manual runtime checks..."
bash "$CHECK_SCRIPT"

if "$XCODEBUILD_BIN" -version >/dev/null 2>&1; then
  echo "[verify_macos_shell] Running swift test..."
  "$SWIFT_BIN" test --package-path "$PACKAGE_PATH" --scratch-path "$SCRATCH_PATH"
else
  echo "[verify_macos_shell] Skipping swift test because Xcode is not active."
fi

echo "[verify_macos_shell] PASS"
