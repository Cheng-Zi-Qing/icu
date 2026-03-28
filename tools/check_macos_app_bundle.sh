#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-${ICU_APP_BUNDLE_PATH:-}}"

fail() {
  echo "[check_macos_app_bundle] FAIL: $*" >&2
  exit 1
}

assert_exists() {
  local path="$1"
  [[ -e "$path" ]] || fail "expected path to exist: $path"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected content to include: $needle"
  fi
}

[[ -n "$APP_PATH" ]] || fail "usage: check_macos_app_bundle.sh <path-to-app>"
[[ -d "$APP_PATH" ]] || fail "app bundle does not exist: $APP_PATH"

info_plist="$APP_PATH/Contents/Info.plist"
binary="$APP_PATH/Contents/MacOS/ICUShell"
resource_root="$APP_PATH/Contents/Resources/repo"

assert_exists "$info_plist"
assert_exists "$binary"
[[ -x "$binary" ]] || fail "expected executable binary at $binary"
assert_exists "$resource_root/assets/pets/capybara/base.png"
assert_exists "$resource_root/config/copy/base.json"
assert_exists "$resource_root/tools/avatar_builder_bridge.py"
assert_exists "$resource_root/builder/prompt_optimizer.py"

info_contents="$(cat "$info_plist")"
assert_contains "$info_contents" "<string>ICUShell</string>"
assert_contains "$info_contents" "<key>LSUIElement</key>"

echo "[check_macos_app_bundle] PASS"
