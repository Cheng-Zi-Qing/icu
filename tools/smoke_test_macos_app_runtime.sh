#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE_PATH="${1:-${ICU_RUNTIME_SMOKE_APP_BUNDLE_PATH:-}}"
PACKAGE_SCRIPT="${ICU_RUNTIME_SMOKE_PACKAGE_SCRIPT:-$ROOT_DIR/tools/package_macos_shell.sh}"
TIMEOUT_SECONDS="${ICU_RUNTIME_SMOKE_TIMEOUT_SECONDS:-10}"
POLL_INTERVAL_SECONDS="${ICU_RUNTIME_SMOKE_POLL_INTERVAL_SECONDS:-0.1}"
KEEP_TEMP="${ICU_RUNTIME_SMOKE_KEEP_TEMP:-0}"
TEMP_ROOT="${ICU_RUNTIME_SMOKE_TEMP_ROOT:-$(mktemp -d)}"
APP_SUPPORT_ROOT="${ICU_RUNTIME_SMOKE_APP_SUPPORT_ROOT:-$TEMP_ROOT/app-support}"

RUN_DIR="$TEMP_ROOT/run"
COPIED_APP="$RUN_DIR/ICU.app"
STDOUT_LOG="$TEMP_ROOT/stdout.log"
STDERR_LOG="$TEMP_ROOT/stderr.log"
APP_PID=""

fail() {
  echo "[smoke_test_macos_app_runtime] FAIL: $*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" 2>/dev/null || true
  fi

  if [[ "$KEEP_TEMP" != "1" ]]; then
    rm -rf "$TEMP_ROOT"
  fi
}

resolve_source_app() {
  if [[ -n "$APP_BUNDLE_PATH" && -d "$APP_BUNDLE_PATH" ]]; then
    printf '%s\n' "$APP_BUNDLE_PATH"
    return 0
  fi

  [[ -x "$PACKAGE_SCRIPT" || -f "$PACKAGE_SCRIPT" ]] || fail "package script not found: $PACKAGE_SCRIPT"
  echo "[smoke_test_macos_app_runtime] App bundle not provided; invoking package script..." >&2
  APP_BUNDLE_PATH="$(bash "$PACKAGE_SCRIPT")"
  [[ -d "$APP_BUNDLE_PATH" ]] || fail "package script did not produce a valid .app path: $APP_BUNDLE_PATH"
  printf '%s\n' "$APP_BUNDLE_PATH"
}

launch_and_wait() {
  local source_app="$1"
  local copied_binary
  local start_time now elapsed
  local expected_app_paths_line

  mkdir -p "$RUN_DIR"
  cp -R "$source_app" "$COPIED_APP"
  copied_binary="$COPIED_APP/Contents/MacOS/ICUShell"
  [[ -x "$copied_binary" ]] || fail "missing executable binary: $copied_binary"
  expected_app_paths_line="[app_paths] app_support_root=$APP_SUPPORT_ROOT"

  (
    cd "$RUN_DIR"
    ICU_APP_SUPPORT_ROOT="$APP_SUPPORT_ROOT" \
      "$copied_binary" >"$STDOUT_LOG" 2>"$STDERR_LOG" &
    echo "$!" >"$TEMP_ROOT/app.pid"
  )
  APP_PID="$(cat "$TEMP_ROOT/app.pid")"
  rm -f "$TEMP_ROOT/app.pid"

  start_time="$(date +%s)"
  while true; do
    if [[ -d "$APP_SUPPORT_ROOT" ]] && grep -Fq "$expected_app_paths_line" "$STDOUT_LOG" "$STDERR_LOG" 2>/dev/null; then
      echo "[smoke_test_macos_app_runtime] PASS"
      echo "[smoke_test_macos_app_runtime] logs: stdout=$STDOUT_LOG stderr=$STDERR_LOG"
      return 0
    fi

    if ! kill -0 "$APP_PID" >/dev/null 2>&1; then
      fail "app exited before reaching stable state (see logs: $STDOUT_LOG, $STDERR_LOG)"
    fi

    now="$(date +%s)"
    elapsed="$((now - start_time))"
    if (( elapsed >= TIMEOUT_SECONDS )); then
      fail "timeout waiting for stable state and runtime log evidence after ${TIMEOUT_SECONDS}s (see logs: $STDOUT_LOG, $STDERR_LOG)"
    fi

    sleep "$POLL_INTERVAL_SECONDS"
  done
}

main() {
  local source_app

  trap cleanup EXIT
  source_app="$(resolve_source_app)"
  launch_and_wait "$source_app"
}

main "$@"
