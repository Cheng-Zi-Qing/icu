#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_SCRIPT="$ROOT_DIR/tools/smoke_test_macos_app_runtime.sh"

fail() {
  echo "[test_smoke_test_macos_app_runtime] FAIL: $*" >&2
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

assert_not_exists() {
  local path="$1"
  [[ ! -e "$path" ]] || fail "expected path not to exist: $path"
}

assert_process_dead() {
  local pid="$1"
  if kill -0 "$pid" >/dev/null 2>&1; then
    fail "expected process to be stopped: $pid"
  fi
}

make_stub_app() {
  local app_root="$1"
  local mode="$2"
  local binary="$app_root/Contents/MacOS/ICUShell"

  mkdir -p "$(dirname "$binary")"
cat >"$binary" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mode="${ICU_TEST_STUB_MODE:-success}"
runtime_mode="bundle"

if [[ "$mode" == "repo-mode" ]]; then
  runtime_mode="repo"
fi

if [[ "$mode" != "no-evidence" ]]; then
  echo "[app_paths] mode=${runtime_mode}"
  echo "[app_paths] app_support_root=${ICU_APP_SUPPORT_ROOT:-}"
  echo "[runtime_smoke] launched_binary=$0"
fi

if [[ -n "${ICU_TEST_PID_FILE:-}" ]]; then
  echo "$$" >"$ICU_TEST_PID_FILE"
fi

if [[ "$mode" == "success" || "$mode" == "no-evidence" || "$mode" == "repo-mode" ]]; then
  mkdir -p "${ICU_APP_SUPPORT_ROOT:-}/logs"
  echo "runtime-ok" >"${ICU_APP_SUPPORT_ROOT:-}/runtime.marker"
fi

sleep 30
EOF
  chmod +x "$binary"
  echo "$mode" >"$app_root/.stub_mode"
}

run_success_case() {
  local temp_dir output temp_root app_support_root output_path stdout_log app_pid_file app_pid

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_app "$temp_dir/ICU.app" "success"
  temp_root="$temp_dir/smoke-temp"
  app_support_root="$temp_dir/app-support"
  output_path="$temp_dir/output.log"
  app_pid_file="$temp_dir/app.pid"

  ICU_TEST_STUB_MODE="success" \
  ICU_TEST_PID_FILE="$app_pid_file" \
  ICU_RUNTIME_SMOKE_APP_BUNDLE_PATH="$temp_dir/ICU.app" \
  ICU_RUNTIME_SMOKE_APP_SUPPORT_ROOT="$app_support_root" \
  ICU_RUNTIME_SMOKE_TIMEOUT_SECONDS="2" \
  ICU_RUNTIME_SMOKE_TEMP_ROOT="$temp_root" \
  ICU_RUNTIME_SMOKE_KEEP_TEMP="1" \
  bash "$SMOKE_SCRIPT" >"$output_path" 2>&1

  output="$(cat "$output_path")"
  stdout_log="$temp_root/stdout.log"
  assert_contains "$output" "[smoke_test_macos_app_runtime] PASS"
  assert_exists "$temp_root/run/ICU.app/Contents/MacOS/ICUShell"
  assert_exists "$temp_root/stdout.log"
  assert_exists "$temp_root/stderr.log"
  assert_exists "$app_support_root/runtime.marker"
  assert_contains "$(cat "$stdout_log")" "[app_paths] mode=bundle"
  assert_contains "$(cat "$stdout_log")" "[app_paths] app_support_root=$app_support_root"
  assert_contains "$(cat "$stdout_log")" "[runtime_smoke] launched_binary=$temp_root/run/ICU.app/Contents/MacOS/ICUShell"
  app_pid="$(cat "$app_pid_file")"
  assert_process_dead "$app_pid"
}

run_missing_runtime_evidence_case() {
  local temp_dir output_path status

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_app "$temp_dir/ICU.app" "no-evidence"
  output_path="$temp_dir/output.log"

  set +e
  ICU_TEST_STUB_MODE="no-evidence" \
  ICU_RUNTIME_SMOKE_APP_BUNDLE_PATH="$temp_dir/ICU.app" \
  ICU_RUNTIME_SMOKE_APP_SUPPORT_ROOT="$temp_dir/app-support" \
  ICU_RUNTIME_SMOKE_TIMEOUT_SECONDS="1" \
  ICU_RUNTIME_SMOKE_TEMP_ROOT="$temp_dir/smoke-temp" \
  ICU_RUNTIME_SMOKE_KEEP_TEMP="1" \
  bash "$SMOKE_SCRIPT" >"$output_path" 2>&1
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "expected missing runtime evidence case to fail"
  fi
  assert_contains "$(cat "$output_path")" "[smoke_test_macos_app_runtime] FAIL: timeout"
}

run_repo_mode_case() {
  local temp_dir output_path status

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_app "$temp_dir/ICU.app" "repo-mode"
  output_path="$temp_dir/output.log"

  set +e
  ICU_TEST_STUB_MODE="repo-mode" \
  ICU_RUNTIME_SMOKE_APP_BUNDLE_PATH="$temp_dir/ICU.app" \
  ICU_RUNTIME_SMOKE_APP_SUPPORT_ROOT="$temp_dir/app-support" \
  ICU_RUNTIME_SMOKE_TIMEOUT_SECONDS="1" \
  ICU_RUNTIME_SMOKE_TEMP_ROOT="$temp_dir/smoke-temp" \
  ICU_RUNTIME_SMOKE_KEEP_TEMP="1" \
  bash "$SMOKE_SCRIPT" >"$output_path" 2>&1
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "expected repo mode case to fail"
  fi
  assert_contains "$(cat "$output_path")" "[smoke_test_macos_app_runtime] FAIL: timeout"
}

run_timeout_case() {
  local temp_dir output_path

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  make_stub_app "$temp_dir/ICU.app" "timeout"
  output_path="$temp_dir/output.log"

  set +e
  ICU_TEST_STUB_MODE="timeout" \
  ICU_RUNTIME_SMOKE_APP_BUNDLE_PATH="$temp_dir/ICU.app" \
  ICU_RUNTIME_SMOKE_TIMEOUT_SECONDS="0" \
  ICU_RUNTIME_SMOKE_TEMP_ROOT="$temp_dir/smoke-temp" \
  ICU_RUNTIME_SMOKE_KEEP_TEMP="1" \
  bash "$SMOKE_SCRIPT" >"$output_path" 2>&1
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "expected timeout case to fail"
  fi
  assert_contains "$(cat "$output_path")" "[smoke_test_macos_app_runtime] FAIL: timeout"
}

run_invalid_explicit_bundle_case() {
  local temp_dir output_path package_stub package_log status invalid_bundle

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  output_path="$temp_dir/output.log"
  package_log="$temp_dir/package.log"
  package_stub="$temp_dir/package_macos_shell.sh"
  invalid_bundle="$temp_dir/not-found.app"

  cat >"$package_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "packager-called" >>"$ICU_TEST_PACKAGE_LOG"
echo "/tmp/should-not-be-used.app"
EOF
  chmod +x "$package_stub"

  set +e
  ICU_TEST_PACKAGE_LOG="$package_log" \
  ICU_RUNTIME_SMOKE_APP_BUNDLE_PATH="$invalid_bundle" \
  ICU_RUNTIME_SMOKE_PACKAGE_SCRIPT="$package_stub" \
  ICU_RUNTIME_SMOKE_TIMEOUT_SECONDS="1" \
  ICU_RUNTIME_SMOKE_TEMP_ROOT="$temp_dir/smoke-temp" \
  ICU_RUNTIME_SMOKE_KEEP_TEMP="1" \
  bash "$SMOKE_SCRIPT" >"$output_path" 2>&1
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "expected invalid explicit bundle case to fail"
  fi
  assert_contains "$(cat "$output_path")" "[smoke_test_macos_app_runtime] FAIL: explicit app bundle path is invalid"
  assert_not_exists "$package_log"
}

run_missing_bundle_packages_case() {
  local temp_dir source_app package_stub package_log output_path output

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  source_app="$temp_dir/packaged/ICU.app"
  make_stub_app "$source_app" "success"
  package_log="$temp_dir/package.log"
  package_stub="$temp_dir/package_macos_shell.sh"
  output_path="$temp_dir/output.log"

  cat >"$package_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "packager-called" >>"$ICU_TEST_PACKAGE_LOG"
echo "$ICU_TEST_PACKAGE_OUTPUT"
EOF
  chmod +x "$package_stub"

  ICU_TEST_STUB_MODE="success" \
  ICU_TEST_PACKAGE_LOG="$package_log" \
  ICU_TEST_PACKAGE_OUTPUT="$source_app" \
  ICU_RUNTIME_SMOKE_APP_SUPPORT_ROOT="$temp_dir/app-support" \
  ICU_RUNTIME_SMOKE_PACKAGE_SCRIPT="$package_stub" \
  ICU_RUNTIME_SMOKE_TIMEOUT_SECONDS="2" \
  ICU_RUNTIME_SMOKE_TEMP_ROOT="$temp_dir/smoke-temp" \
  ICU_RUNTIME_SMOKE_KEEP_TEMP="1" \
  bash "$SMOKE_SCRIPT" >"$output_path" 2>&1

  output="$(cat "$output_path")"
  assert_contains "$output" "[smoke_test_macos_app_runtime] PASS"
  assert_contains "$(cat "$package_log")" "packager-called"
}

if [[ ! -f "$SMOKE_SCRIPT" ]]; then
  fail "missing smoke script: $SMOKE_SCRIPT"
fi

run_success_case
run_missing_runtime_evidence_case
run_repo_mode_case
run_timeout_case
run_invalid_explicit_bundle_case
run_missing_bundle_packages_case

echo "[test_smoke_test_macos_app_runtime] PASS"
