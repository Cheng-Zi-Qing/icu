#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFIER="$ROOT_DIR/tools/verify_macos_shell.sh"

fail() {
  echo "[test_verify_macos_shell] FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected output to contain: $needle"
  fi
}

make_stub_swift() {
  local path="$1"
  local log_file="$2"

  cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'swift %s\n' "$*" >>"$VERIFY_LOG_FILE"
case "$1" in
  build)
    echo "stub swift build"
    ;;
  test)
    echo "stub swift test"
    ;;
  *)
    echo "unexpected swift subcommand: $1" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$path"
  export VERIFY_LOG_FILE="$log_file"
}

make_stub_check() {
  local path="$1"
  local log_file="$2"

  cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'check %s\n' "$*" >>"$VERIFY_LOG_FILE"
echo "stub manual runtime checks"
EOF
  chmod +x "$path"
  export VERIFY_LOG_FILE="$log_file"
}

make_stub_xcodebuild() {
  local path="$1"
  local mode="$2"

  cat >"$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "$mode" == "xcode-enabled" ]]; then
  echo "Xcode 26.0"
  exit 0
fi
exit 1
EOF
  chmod +x "$path"
}

run_case() {
  local mode="$1"
  local temp_dir output_file log_file stub_swift stub_check stub_xcodebuild output

  temp_dir="$(mktemp -d)"
  output_file="$temp_dir/output.log"
  log_file="$temp_dir/verify.log"
  stub_swift="$temp_dir/swift"
  stub_check="$temp_dir/check_native_shell.sh"
  stub_xcodebuild="$temp_dir/xcodebuild"

  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_swift "$stub_swift" "$log_file"
  make_stub_check "$stub_check" "$log_file"
  make_stub_xcodebuild "$stub_xcodebuild" "$mode"

  if [[ ! -f "$VERIFIER" ]]; then
    fail "missing verifier script: $VERIFIER"
  fi

  VERIFY_MACOS_SHELL_SWIFT_BIN="$stub_swift" \
    VERIFY_MACOS_SHELL_XCODEBUILD_BIN="$stub_xcodebuild" \
    VERIFY_MACOS_SHELL_CHECK_SCRIPT="$stub_check" \
    bash "$VERIFIER" >"$output_file" 2>&1

  output="$(cat "$output_file")"
  assert_contains "$output" "[verify_macos_shell] Running swift build..."
  assert_contains "$output" "[verify_macos_shell] Running manual runtime checks..."
  assert_contains "$(cat "$log_file")" "swift build --package-path $ROOT_DIR/apps/macos-shell --scratch-path "
  assert_contains "$(cat "$log_file")" "check "

  if [[ "$mode" == "xcode-enabled" ]]; then
    assert_contains "$output" "[verify_macos_shell] Running swift test..."
    assert_contains "$(cat "$log_file")" "swift test --package-path $ROOT_DIR/apps/macos-shell --scratch-path "
  else
    assert_contains "$output" "[verify_macos_shell] Skipping swift test because Xcode is not active."
  fi
}

run_case "clt-only"
run_case "xcode-enabled"

echo "[test_verify_macos_shell] PASS"
