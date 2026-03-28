#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$ROOT_DIR/icu"

fail() {
  echo "[test_icu_launcher] FAIL: $*" >&2
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
trap 'rm -rf "$temp_dir"' EXIT

run_stub="$temp_dir/run_stub.sh"
verify_stub="$temp_dir/verify_stub.sh"
package_stub="$temp_dir/package_stub.sh"
python_stub="$temp_dir/python3"
pip_stub="$temp_dir/pip3"

cat >"$run_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "RUN_STUB:$*"
EOF
chmod +x "$run_stub"

cat >"$verify_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "VERIFY_STUB:$*"
EOF
chmod +x "$verify_stub"

cat >"$package_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "PACKAGE_STUB:$*"
EOF
chmod +x "$package_stub"

cat >"$python_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "PYTHON_STUB:$*" >&2
exit 1
EOF
chmod +x "$python_stub"

cat >"$pip_stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "PIP_STUB:$*" >&2
exit 1
EOF
chmod +x "$pip_stub"

if [[ ! -f "$LAUNCHER" ]]; then
  fail "missing launcher: $LAUNCHER"
fi

default_output="$(
  PATH="$temp_dir:$PATH" \
  ICU_RUN_SCRIPT="$run_stub" \
  ICU_VERIFY_SCRIPT="$verify_stub" \
  bash "$LAUNCHER" 2>&1
)" || true
assert_contains "$default_output" "RUN_STUB:"

verify_output="$(
  PATH="$temp_dir:$PATH" \
  ICU_RUN_SCRIPT="$run_stub" \
  ICU_VERIFY_SCRIPT="$verify_stub" \
  bash "$LAUNCHER" --verify 2>&1
)" || true
assert_contains "$verify_output" "VERIFY_STUB:"

package_output="$(
  PATH="$temp_dir:$PATH" \
  ICU_RUN_SCRIPT="$run_stub" \
  ICU_VERIFY_SCRIPT="$verify_stub" \
  ICU_PACKAGE_SCRIPT="$package_stub" \
  bash "$LAUNCHER" --package-app 2>&1
)" || true
assert_contains "$package_output" "PACKAGE_STUB:"

set +e
invalid_output="$(
  PATH="$temp_dir:$PATH" \
  ICU_RUN_SCRIPT="$run_stub" \
  ICU_VERIFY_SCRIPT="$verify_stub" \
  ICU_PACKAGE_SCRIPT="$package_stub" \
  bash "$LAUNCHER" --unknown 2>&1
)"
invalid_status=$?
set -e

if [[ $invalid_status -eq 0 ]]; then
  fail "invalid launcher argument should exit non-zero"
fi

assert_contains "$invalid_output" "Usage: ./icu [--verify|--package-app]"

echo "[test_icu_launcher] PASS"
