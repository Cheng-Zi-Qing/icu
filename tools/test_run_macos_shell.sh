#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$ROOT_DIR/tools/run_macos_shell.sh"

fail() {
  echo "[test_run_macos_shell] FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected output to contain: $needle"
  fi
}

temp_dir="$(mktemp -d)"
output_file="$temp_dir/output.log"
swift_stub="$temp_dir/swift"
trap 'rm -rf "$temp_dir"' EXIT

cat >"$swift_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "swift:$*"
echo "ICU_REPO_ROOT=$ICU_REPO_ROOT"
echo "ICU_PET_ID=${ICU_PET_ID:-}"
EOF
chmod +x "$swift_stub"

if [[ ! -f "$RUNNER" ]]; then
  fail "missing runner script: $RUNNER"
fi

ICU_SHELL_SWIFT_BIN="$swift_stub" \
ICU_PET_ID="seal" \
bash "$RUNNER" >"$output_file" 2>&1

output="$(cat "$output_file")"
assert_contains "$output" "[run_macos_shell] Launching ICUShell..."
assert_contains "$output" "swift:run --package-path $ROOT_DIR/apps/macos-shell --scratch-path "
assert_contains "$output" " ICUShell"
assert_contains "$output" "ICU_REPO_ROOT=$ROOT_DIR"
assert_contains "$output" "ICU_PET_ID=seal"

echo "[test_run_macos_shell] PASS"
