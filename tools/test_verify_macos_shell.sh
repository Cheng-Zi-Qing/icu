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

make_stub_package() {
  local path="$1"
  local log_file="$2"

  cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'package %s\n' "$*" >>"$VERIFY_LOG_FILE"
echo "/tmp/ICU.app"
EOF
  chmod +x "$path"
  export VERIFY_LOG_FILE="$log_file"
}

make_stub_app_check() {
  local path="$1"
  local log_file="$2"

  cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'app-check %s\n' "$*" >>"$VERIFY_LOG_FILE"
echo "bundle verified"
EOF
  chmod +x "$path"
  export VERIFY_LOG_FILE="$log_file"
}

make_stub_runtime_smoke() {
  local path="$1"
  local log_file="$2"
  local mode="${3:-ok}"

  cat >"$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf 'runtime-smoke %s\n' "\$*" >>"\$VERIFY_LOG_FILE"
if [[ "$mode" == "fail" ]]; then
  echo "runtime smoke failed" >&2
  exit 23
fi
echo "runtime smoke ok"
EOF
  chmod +x "$path"
  export VERIFY_LOG_FILE="$log_file"
}

assert_line_order() {
  local file_path="$1"
  local first="$2"
  local second="$3"
  local first_line second_line

  first_line="$(awk -v pattern="$first" 'index($0, pattern) { print NR; exit }' "$file_path")"
  second_line="$(awk -v pattern="$second" 'index($0, pattern) { print NR; exit }' "$file_path")"

  if [[ -z "$first_line" || -z "$second_line" ]]; then
    fail "unable to find line order markers: '$first' then '$second'"
  fi

  if (( first_line >= second_line )); then
    fail "expected '$first' to appear before '$second' in $file_path"
  fi
}

run_case() {
  local mode="$1"
  local package_check_enabled="${2:-0}"
  local runtime_smoke_enabled="${3:-0}"
  local temp_dir output_file log_file stub_swift stub_check stub_xcodebuild stub_package stub_app_check stub_runtime_smoke output

  temp_dir="$(mktemp -d)"
  output_file="$temp_dir/output.log"
  log_file="$temp_dir/verify.log"
  stub_swift="$temp_dir/swift"
  stub_check="$temp_dir/check_native_shell.sh"
  stub_xcodebuild="$temp_dir/xcodebuild"
  stub_package="$temp_dir/package_macos_shell.sh"
  stub_app_check="$temp_dir/check_macos_app_bundle.sh"
  stub_runtime_smoke="$temp_dir/smoke_test_macos_app_runtime.sh"

  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_swift "$stub_swift" "$log_file"
  make_stub_check "$stub_check" "$log_file"
  make_stub_xcodebuild "$stub_xcodebuild" "$mode"
  make_stub_package "$stub_package" "$log_file"
  make_stub_app_check "$stub_app_check" "$log_file"
  make_stub_runtime_smoke "$stub_runtime_smoke" "$log_file" "ok"

  if [[ ! -f "$VERIFIER" ]]; then
    fail "missing verifier script: $VERIFIER"
  fi

  VERIFY_MACOS_SHELL_SWIFT_BIN="$stub_swift" \
    VERIFY_MACOS_SHELL_XCODEBUILD_BIN="$stub_xcodebuild" \
    VERIFY_MACOS_SHELL_CHECK_SCRIPT="$stub_check" \
    VERIFY_MACOS_SHELL_PACKAGE_SCRIPT="$stub_package" \
    VERIFY_MACOS_SHELL_APP_CHECK_SCRIPT="$stub_app_check" \
    VERIFY_MACOS_SHELL_RUNTIME_SMOKE_SCRIPT="$stub_runtime_smoke" \
    VERIFY_MACOS_SHELL_PACKAGE_CHECK="$package_check_enabled" \
    VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK="$runtime_smoke_enabled" \
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

  if [[ "$package_check_enabled" == "1" ]]; then
    assert_contains "$output" "[verify_macos_shell] Packaging app bundle for release smoke check..."
    assert_contains "$output" "[verify_macos_shell] Running app bundle structure check..."
    assert_contains "$(cat "$log_file")" "package "
    assert_contains "$(cat "$log_file")" "app-check /tmp/ICU.app"
  fi

  if [[ "$runtime_smoke_enabled" == "1" ]]; then
    assert_contains "$output" "[verify_macos_shell] Running detached app runtime smoke check..."
    assert_contains "$(cat "$log_file")" "runtime-smoke /tmp/ICU.app"
    assert_line_order "$log_file" "package " "app-check /tmp/ICU.app"
    assert_line_order "$log_file" "app-check /tmp/ICU.app" "runtime-smoke /tmp/ICU.app"
  else
    if [[ "$(cat "$log_file")" == *"runtime-smoke "* ]]; then
      fail "runtime smoke should not run by default"
    fi
  fi
}

run_case_expect_failure() {
  local mode="$1"
  local package_check_enabled="${2:-0}"
  local runtime_smoke_enabled="${3:-0}"
  local temp_dir output_file log_file stub_swift stub_check stub_xcodebuild stub_package stub_app_check stub_runtime_smoke output

  temp_dir="$(mktemp -d)"
  output_file="$temp_dir/output.log"
  log_file="$temp_dir/verify.log"
  stub_swift="$temp_dir/swift"
  stub_check="$temp_dir/check_native_shell.sh"
  stub_xcodebuild="$temp_dir/xcodebuild"
  stub_package="$temp_dir/package_macos_shell.sh"
  stub_app_check="$temp_dir/check_macos_app_bundle.sh"
  stub_runtime_smoke="$temp_dir/smoke_test_macos_app_runtime.sh"

  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_swift "$stub_swift" "$log_file"
  make_stub_check "$stub_check" "$log_file"
  make_stub_xcodebuild "$stub_xcodebuild" "$mode"
  make_stub_package "$stub_package" "$log_file"
  make_stub_app_check "$stub_app_check" "$log_file"
  make_stub_runtime_smoke "$stub_runtime_smoke" "$log_file" "fail"

  if [[ ! -f "$VERIFIER" ]]; then
    fail "missing verifier script: $VERIFIER"
  fi

  if VERIFY_MACOS_SHELL_SWIFT_BIN="$stub_swift" \
    VERIFY_MACOS_SHELL_XCODEBUILD_BIN="$stub_xcodebuild" \
    VERIFY_MACOS_SHELL_CHECK_SCRIPT="$stub_check" \
    VERIFY_MACOS_SHELL_PACKAGE_SCRIPT="$stub_package" \
    VERIFY_MACOS_SHELL_APP_CHECK_SCRIPT="$stub_app_check" \
    VERIFY_MACOS_SHELL_RUNTIME_SMOKE_SCRIPT="$stub_runtime_smoke" \
    VERIFY_MACOS_SHELL_PACKAGE_CHECK="$package_check_enabled" \
    VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK="$runtime_smoke_enabled" \
    bash "$VERIFIER" >"$output_file" 2>&1; then
    fail "expected verifier to fail when runtime smoke check fails"
  fi

  output="$(cat "$output_file")"
  assert_contains "$output" "[verify_macos_shell] Running detached app runtime smoke check..."
  assert_contains "$(cat "$log_file")" "runtime-smoke /tmp/ICU.app"
  assert_line_order "$log_file" "app-check /tmp/ICU.app" "runtime-smoke /tmp/ICU.app"

  if [[ "$output" == *"[verify_macos_shell] PASS"* ]]; then
    fail "verifier should not print PASS when runtime smoke check fails"
  fi
}

run_case "clt-only"
run_case "xcode-enabled"
run_case "clt-only" "1"
run_case "clt-only" "1" "1"
run_case_expect_failure "clt-only" "1" "1"

echo "[test_verify_macos_shell] PASS"
