#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGER="$ROOT_DIR/tools/package_macos_shell.sh"
CHECKER="$ROOT_DIR/tools/check_macos_app_bundle.sh"

fail() {
  echo "[test_package_macos_shell] FAIL: $*" >&2
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
    fail "expected output to contain: $needle"
  fi
}

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

stub_binary="$temp_dir/ICUShell"
cat >"$stub_binary" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "ICUShell stub"
EOF
chmod +x "$stub_binary"

if [[ ! -f "$PACKAGER" ]]; then
  fail "missing packager script: $PACKAGER"
fi

if [[ ! -f "$CHECKER" ]]; then
  fail "missing app bundle checker: $CHECKER"
fi

output="$(
  ICU_PACKAGE_SKIP_BUILD=1 \
  ICU_PACKAGE_BINARY_PATH="$stub_binary" \
  ICU_PACKAGE_OUTPUT_DIR="$temp_dir/dist" \
  ICU_PACKAGE_APP_NAME="ICUTest" \
  bash "$PACKAGER"
)"

app_path="$temp_dir/dist/ICUTest.app"
macos_binary="$app_path/Contents/MacOS/ICUShell"
info_plist="$app_path/Contents/Info.plist"
resource_root="$app_path/Contents/Resources/repo"

assert_contains "$output" "[package_macos_shell] Packaging app bundle..."
assert_contains "$output" "$app_path"
assert_exists "$app_path"
assert_exists "$macos_binary"
assert_exists "$info_plist"
assert_exists "$resource_root/assets/pets/capybara/base.png"
assert_exists "$resource_root/config/copy/base.json"
assert_exists "$resource_root/tools/avatar_builder_bridge.py"
assert_exists "$resource_root/builder/prompt_optimizer.py"

check_output="$(bash "$CHECKER" "$app_path")"
assert_contains "$check_output" "[check_macos_app_bundle] PASS"

echo "[test_package_macos_shell] PASS"
