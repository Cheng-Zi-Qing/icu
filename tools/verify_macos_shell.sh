#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_PATH="$ROOT_DIR/apps/macos-shell"
SWIFT_BIN="${VERIFY_MACOS_SHELL_SWIFT_BIN:-swift}"
XCODEBUILD_BIN="${VERIFY_MACOS_SHELL_XCODEBUILD_BIN:-xcodebuild}"
CHECK_SCRIPT="${VERIFY_MACOS_SHELL_CHECK_SCRIPT:-$ROOT_DIR/tools/check_native_shell.sh}"
PACKAGE_SCRIPT="${VERIFY_MACOS_SHELL_PACKAGE_SCRIPT:-$ROOT_DIR/tools/package_macos_shell.sh}"
APP_CHECK_SCRIPT="${VERIFY_MACOS_SHELL_APP_CHECK_SCRIPT:-$ROOT_DIR/tools/check_macos_app_bundle.sh}"
PACKAGE_CHECK_ENABLED="${VERIFY_MACOS_SHELL_PACKAGE_CHECK:-0}"
RUNTIME_SMOKE_ENABLED="${VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK:-0}"
RUNTIME_SMOKE_SCRIPT="${VERIFY_MACOS_SHELL_RUNTIME_SMOKE_SCRIPT:-$ROOT_DIR/tools/smoke_test_macos_app_runtime.sh}"
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

if [[ "$PACKAGE_CHECK_ENABLED" == "1" ]]; then
  echo "[verify_macos_shell] Packaging app bundle for release smoke check..."
  APP_BUNDLE_PATH="$(bash "$PACKAGE_SCRIPT" | tail -n 1)"
  echo "[verify_macos_shell] Running app bundle structure check..."
  bash "$APP_CHECK_SCRIPT" "$APP_BUNDLE_PATH"

  if [[ "$RUNTIME_SMOKE_ENABLED" == "1" ]]; then
    echo "[verify_macos_shell] Running detached app runtime smoke check..."
    bash "$RUNTIME_SMOKE_SCRIPT" "$APP_BUNDLE_PATH"
  fi
fi

echo "[verify_macos_shell] PASS"
