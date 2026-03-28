#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_PATH="$ROOT_DIR/apps/macos-shell"
SWIFT_BIN="${ICU_PACKAGE_SWIFT_BIN:-swift}"
CODESIGN_BIN="${ICU_PACKAGE_CODESIGN_BIN:-codesign}"
DITTO_BIN="${ICU_PACKAGE_DITTO_BIN:-ditto}"
XCRUN_BIN="${ICU_PACKAGE_XCRUN_BIN:-xcrun}"
APP_NAME="${ICU_PACKAGE_APP_NAME:-ICU}"
APP_VERSION="${ICU_PACKAGE_APP_VERSION:-1.0.0}"
BUNDLE_ID="${ICU_PACKAGE_BUNDLE_ID:-ai.wiz.icu.shell}"
OUTPUT_DIR="${ICU_PACKAGE_OUTPUT_DIR:-$ROOT_DIR/dist}"
SIGN_IDENTITY="${ICU_PACKAGE_SIGN_IDENTITY:-}"
NOTARIZE_ENABLED="${ICU_PACKAGE_NOTARIZE:-0}"
NOTARY_PROFILE="${ICU_NOTARYTOOL_PROFILE:-}"
source "$ROOT_DIR/tools/swift_package_scratch_path.sh"

SCRATCH_PATH="${ICU_PACKAGE_SCRATCH_PATH:-$(swift_package_scratch_path "$PACKAGE_PATH")}"
BUNDLE_PATH="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
RESOURCE_REPO_DIR="$RESOURCES_DIR/repo"
INFO_PLIST="$CONTENTS_DIR/Info.plist"

fail() {
  echo "[package_macos_shell] FAIL: $*" >&2
  exit 1
}

build_binary_path() {
  local bin_path

  if [[ "${ICU_PACKAGE_SKIP_BUILD:-0}" == "1" ]]; then
    bin_path="${ICU_PACKAGE_BINARY_PATH:-}"
    [[ -n "$bin_path" ]] || fail "ICU_PACKAGE_BINARY_PATH is required when ICU_PACKAGE_SKIP_BUILD=1"
    [[ -f "$bin_path" ]] || fail "binary does not exist: $bin_path"
    printf '%s\n' "$bin_path"
    return 0
  fi

  mkdir -p "$SCRATCH_PATH"

  echo "[package_macos_shell] Building release binary..." >&2
  "$SWIFT_BIN" build \
    --package-path "$PACKAGE_PATH" \
    --configuration release \
    --scratch-path "$SCRATCH_PATH" >&2

  bin_path="$(
    "$SWIFT_BIN" build \
      --package-path "$PACKAGE_PATH" \
      --configuration release \
      --scratch-path "$SCRATCH_PATH" \
      --show-bin-path
  )/ICUShell"

  [[ -f "$bin_path" ]] || fail "unable to locate built binary at $bin_path"
  printf '%s\n' "$bin_path"
}

write_info_plist() {
  cat >"$INFO_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>ICUShell</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${APP_VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF
}

copy_runtime_resources() {
  mkdir -p "$RESOURCE_REPO_DIR/config" "$RESOURCE_REPO_DIR/tools"
  cp -R "$ROOT_DIR/assets" "$RESOURCE_REPO_DIR/assets"
  cp -R "$ROOT_DIR/builder" "$RESOURCE_REPO_DIR/builder"
  cp -R "$ROOT_DIR/config/copy" "$RESOURCE_REPO_DIR/config/copy"
  cp "$ROOT_DIR/tools/avatar_builder_bridge.py" "$RESOURCE_REPO_DIR/tools/avatar_builder_bridge.py"
}

sign_bundle_if_needed() {
  [[ -n "$SIGN_IDENTITY" ]] || return 0

  echo "[package_macos_shell] Signing app bundle..."
  "$CODESIGN_BIN" --force --deep --options runtime --sign "$SIGN_IDENTITY" "$BUNDLE_PATH"
}

notarize_bundle_if_requested() {
  [[ "$NOTARIZE_ENABLED" == "1" ]] || return 0

  [[ -n "$SIGN_IDENTITY" ]] || fail "ICU_PACKAGE_SIGN_IDENTITY is required when ICU_PACKAGE_NOTARIZE=1"
  [[ -n "$NOTARY_PROFILE" ]] || fail "ICU_NOTARYTOOL_PROFILE is required when ICU_PACKAGE_NOTARIZE=1"

  local zip_path="$OUTPUT_DIR/$APP_NAME.zip"

  echo "[package_macos_shell] Notarizing app bundle..."
  rm -f "$zip_path"
  "$DITTO_BIN" -c -k --keepParent "$BUNDLE_PATH" "$zip_path"
  "$XCRUN_BIN" notarytool submit "$zip_path" --keychain-profile "$NOTARY_PROFILE" --wait
  "$XCRUN_BIN" stapler staple "$BUNDLE_PATH"
}

main() {
  local binary_path

  binary_path="$(build_binary_path)"

  echo "[package_macos_shell] Packaging app bundle..."
  rm -rf "$BUNDLE_PATH"
  mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

  cp "$binary_path" "$MACOS_DIR/ICUShell"
  chmod +x "$MACOS_DIR/ICUShell"
  write_info_plist
  copy_runtime_resources
  sign_bundle_if_needed
  notarize_bundle_if_requested

  echo "$BUNDLE_PATH"
}

main "$@"
