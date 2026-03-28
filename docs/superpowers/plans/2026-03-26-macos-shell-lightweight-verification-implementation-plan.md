# macOS Shell Lightweight Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `apps/macos-shell` 建立一个在 CLT-only 环境默认可用、并能在未来自动接入标准测试的统一验证入口。

**Architecture:** 保留现有 SwiftPM `testTarget` 与 `XCTest` 文件不动，新增一个统一验证脚本作为默认入口。脚本固定执行 `swift build` 与手工 runtime 校验，并仅在当前开发目录具备 `xcodebuild` 能力时才追加 `swift test`。

**Tech Stack:** Bash, Swift Package Manager, Command Line Tools, optional Xcode/XCTest

---

## File Map

### New files

- `tools/verify_macos_shell.sh`
  统一默认验证入口，先跑 `swift build` 与 `tools/check_native_shell.sh`，再按环境决定是否追加 `swift test`。
- `tools/test_verify_macos_shell.sh`
  轻量脚本测试，使用 PATH stub 验证默认入口在“无 Xcode”和“有 Xcode”两种模式下的行为。

### Modified files

- `README.md`
  增加默认验证命令说明，避免继续把 `swift test` 当作轻量环境默认入口。
- `README_CN.md`
  同步中文说明。
- `progress.md`
  记录轻量验证链路的新增、环境结论与验证结果。
- `task_plan.md`
  更新当前阶段说明，把轻量默认入口纳入验证策略。

## Task 1: Add a Failing Script Test for the Default Verification Flow

**Files:**
- Create: `tools/test_verify_macos_shell.sh`
- Test: `tools/test_verify_macos_shell.sh`

- [ ] **Step 1: Write the failing CLT-only behavior test**

```bash
run_verify_script_with_stubbed_path "clt-only"
assert_output_contains "[verify_macos_shell] Running swift build..."
assert_output_contains "[verify_macos_shell] Running manual runtime checks..."
assert_output_contains "[verify_macos_shell] Skipping swift test"
```

- [ ] **Step 2: Run the script test to verify it fails because the default verifier does not exist yet**

Run: `bash tools/test_verify_macos_shell.sh`

Expected: FAIL because `tools/verify_macos_shell.sh` is missing.

- [ ] **Step 3: Extend the test to cover the Xcode-enabled branch**

```bash
run_verify_script_with_stubbed_path "xcode-enabled"
assert_output_contains "[verify_macos_shell] Running swift test..."
```

- [ ] **Step 4: Re-run the script test and confirm it still fails for the same missing-script reason**

Run: `bash tools/test_verify_macos_shell.sh`

Expected: FAIL because the production verifier has not been implemented yet.

## Task 2: Implement the Unified Verification Script

**Files:**
- Create: `tools/verify_macos_shell.sh`
- Test: `tools/test_verify_macos_shell.sh`

- [ ] **Step 1: Implement the minimal verifier**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

swift build --package-path "$ROOT_DIR/apps/macos-shell"
bash "$ROOT_DIR/tools/check_native_shell.sh"

if xcodebuild -version >/dev/null 2>&1; then
  swift test --package-path "$ROOT_DIR/apps/macos-shell"
else
  echo "[verify_macos_shell] Skipping swift test because Xcode is not active."
fi
```

- [ ] **Step 2: Run the script test to verify both branches now pass**

Run: `bash tools/test_verify_macos_shell.sh`

Expected: PASS

- [ ] **Step 3: Run the verifier in the current CLT-only environment**

Run: `bash tools/verify_macos_shell.sh`

Expected:
- `swift build` succeeds
- `tools/check_native_shell.sh` succeeds
- `swift test` is skipped with an explicit message

## Task 3: Document the New Default Workflow

**Files:**
- Modify: `README.md`
- Modify: `README_CN.md`

- [ ] **Step 1: Add the failing documentation expectation to the script test notes**

```bash
grep -q "tools/verify_macos_shell.sh" README.md
grep -q "tools/verify_macos_shell.sh" README_CN.md
```

- [ ] **Step 2: Run the grep checks and verify they currently fail**

Run:
```bash
rg -n "verify_macos_shell" README.md README_CN.md
```

Expected: no matches

- [ ] **Step 3: Update both READMEs with the new default verification command**

Document:
- CLT-only default command is `bash tools/verify_macos_shell.sh`
- `swift test` is optional and only expected when Xcode is active

- [ ] **Step 4: Re-run the grep checks**

Run:
```bash
rg -n "verify_macos_shell" README.md README_CN.md
```

Expected: matches in both files

## Task 4: Update Project Tracking Files

**Files:**
- Modify: `progress.md`
- Modify: `task_plan.md`

- [ ] **Step 1: Add the failing expectation for missing default verifier to project notes**

Record that before this change the lightweight path was implicit and split across two commands.

- [ ] **Step 2: Update progress and task tracking after implementation**

Add:
- CLT reinstall fixed manifest-level SwiftPM failure
- `swift build` now passes in current environment
- `swift test` still requires Xcode/XCTest
- `tools/verify_macos_shell.sh` is now the default verification entrypoint

- [ ] **Step 3: Re-read the tracking files and ensure they match actual behavior**

Run:
```bash
sed -n '1,240p' progress.md
sed -n '1,240p' task_plan.md
```

Expected: entries reflect the new default workflow and current environment boundary.

## Task 5: Final Verification

**Files:**
- Test: `tools/test_verify_macos_shell.sh`
- Test: `tools/verify_macos_shell.sh`

- [ ] **Step 1: Run the script-level behavior test**

Run: `bash tools/test_verify_macos_shell.sh`

Expected: PASS

- [ ] **Step 2: Run the default verifier end-to-end**

Run: `bash tools/verify_macos_shell.sh`

Expected:
- `swift build` passes
- `check_native_shell` passes
- explicit skip message for `swift test`

- [ ] **Step 3: Optionally confirm the current Xcode-dependent failure mode remains isolated**

Run: `swift test --package-path apps/macos-shell`

Expected: FAIL with `no such module 'XCTest'` until Xcode is installed and selected.

## Notes

- 当前会话未获得显式的代理委派请求，因此不使用 subagent-driven execution。
- 该计划按 inline execution 执行。
