#!/usr/bin/env bash
# 旧 Python 后端、AI 生成、形象创建向导都已删除：确认文件不在、Swift 里也没有残留引用。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_SOURCES="$ROOT_DIR/apps/macos-shell/Sources/ICUShell"

fail() {
  echo "[test_python_cleanup] FAIL: $*" >&2
  exit 1
}

assert_missing() {
  local path="$1"
  [[ ! -e "$ROOT_DIR/$path" ]] || fail "expected removed path to be absent: $path"
}

assert_sources_lack() {
  local pattern="$1"
  if grep -rqE "$pattern" "$SWIFT_SOURCES"; then
    fail "Swift sources still reference: $pattern"
  fi
}

removed_paths=(
  "src"
  "tests"
  "builder"
  "data"
  "requirements.txt"
  "requirements-dev.txt"
  "test_bubble.py"
  "tools/avatar_builder_bridge.py"
  "tools/test_avatar_builder_bridge.sh"
  "tools/test_avatar_builder_bridge_app_support.sh"
  "tools/test_avatar_builder_bridge_chat_timeout.sh"
  "tools/test_avatar_builder_bridge_repo_token.sh"
  "tools/test_avatar_builder_bridge_timeout.sh"
  "apps/macos-shell/Sources/ICUShell/Generation"
  "apps/macos-shell/Sources/ICUShell/Avatar"
  "apps/macos-shell/Sources/ICUShell/Health/HealthReportWindowController.swift"
  "apps/macos-shell/Sources/ICUShell/Copy/CopyOverrideStore.swift"
)

for path in "${removed_paths[@]}"; do
  assert_missing "$path"
done

assert_sources_lack 'Generation(Settings|Coordinator|Config|HTTP|Capability)'
assert_sources_lack 'Avatar(Coordinator|Selector|Wizard|BuilderBridge|Catalog|AssetStore)'
assert_sources_lack 'HealthReportWindowController'
assert_sources_lack 'avatar_builder_bridge'

echo "[test_python_cleanup] PASS"
