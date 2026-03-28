#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "[test_python_cleanup] FAIL: $*" >&2
  exit 1
}

assert_missing_file() {
  local path="$1"
  if [[ -e "$ROOT_DIR/$path" ]]; then
    fail "expected removed file to be absent: $path"
  fi
}

assert_file_lacks() {
  local path="$1"
  local pattern="$2"
  if rg -n "$pattern" "$ROOT_DIR/$path" >/dev/null 2>&1; then
    fail "expected $path to not contain pattern: $pattern"
  fi
}

assert_tree_lacks() {
  local pattern="$1"
  shift
  if rg -n "$pattern" "$@" >/dev/null 2>&1; then
    fail "expected tree to not contain pattern: $pattern"
  fi
}

removed_files=(
  "run_pet.py"
  "generate_raw.py"
  "generate_avatars_sdk.py"
  "process_images.py"
  "builder/asset_packer.py"
  "builder/builder.py"
  "builder/vision_slicer.py"
  "src/ai_config_dialog.py"
  "src/ai_config_dialog.py.bak"
  "src/ai_config_dialog_old.py.bak"
  "src/avatar_manager.py"
  "src/avatar_selector.py"
  "src/avatar_wizard.py"
  "src/bubble_label.py"
  "src/daily_report.py"
  "src/model_config_dialog.py"
  "src/pet_main.py"
  "src/pet_widget.py"
  "src/user_config_dialog.py"
  "src/weekly_report.py"
  "tests/test_pet.py"
)

for path in "${removed_files[@]}"; do
  assert_missing_file "$path"
done

assert_file_lacks "requirements.txt" '^requests'
assert_file_lacks "requirements.txt" '^huggingface-hub'
assert_file_lacks "requirements.txt" '^Pillow'
assert_file_lacks "requirements.txt" '^rembg'
assert_file_lacks "requirements.txt" '^opencv-python'
assert_file_lacks "src/ollama_client.py" '^import requests$'

assert_tree_lacks 'PySide6' "$ROOT_DIR/src" "$ROOT_DIR/tests"

echo "[test_python_cleanup] PASS"
