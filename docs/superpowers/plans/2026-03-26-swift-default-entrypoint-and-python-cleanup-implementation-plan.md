# Swift Default Entrypoint And Python Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将仓库根入口切到 Swift shell，并完成不影响 builder 工具链的中等力度 Python 启动链与依赖清理。

**Architecture:** 保留 `tools/run_macos_shell.sh` 与 `tools/verify_macos_shell.sh` 作为底层实现，根目录 `./icu` 只做统一入口分发。默认启动走 Swift，`--verify` 走轻量验证。Python 旧 UI 文件本体暂不删，但退出默认入口并从运行依赖里移除 `PySide6` 和 `pytest`，README 同步改成 Swift-first 叙述。

**Tech Stack:** Bash, Swift Package Manager, Command Line Tools, Python builder tooling, Markdown docs

---

## File Map

### New files

- `tools/test_icu_launcher.sh`
  覆盖 `./icu` 默认启动、`./icu --verify` 和非法参数分支的脚本级测试。

### Modified files

- `icu`
  改成 Swift 统一入口，默认调用 `tools/run_macos_shell.sh`，支持 `--verify`。
- `run_pet.py`
  标记为 legacy 入口，避免继续被误认为主路径。
- `requirements.txt`
  移除 `PySide6` 与 `pytest`，保留 builder/图像处理/状态同步仍需要的依赖。
- `requirements-dev.txt`
  保留并补齐测试开发依赖，确保 `pytest` 只存在于开发依赖。
- `README.md`
  Quick Start、技术栈、项目结构与本地运行说明切到 Swift-first。
- `README_CN.md`
  同步中文说明。
- `findings.md`
  记录入口切换与依赖边界决策。
- `progress.md`
  记录实现与验证结果。
- `task_plan.md`
  更新当前默认启动入口与迁移进展。

## Task 1: Add a Failing Test for the Root Launcher

**Files:**
- Create: `tools/test_icu_launcher.sh`
- Test: `tools/test_icu_launcher.sh`

- [ ] **Step 1: Write the failing default-launch test**

```bash
ICU_RUN_SCRIPT="$stub_run" \
ICU_VERIFY_SCRIPT="$stub_verify" \
bash ./icu
```

Expect output to contain:
- launcher start banner
- call into the Swift run script

- [ ] **Step 2: Run the launcher test to verify it fails against the current Python entrypoint**

Run: `bash tools/test_icu_launcher.sh`

Expected: FAIL because `icu` still tries to import/install `PySide6` and launch `src.pet_main`.

- [ ] **Step 3: Extend the test to cover `--verify` and invalid arguments**

Verify:
- `./icu --verify` dispatches to verify script
- `./icu --unknown` exits non-zero with usage text

- [ ] **Step 4: Re-run the launcher test and confirm it still fails before implementation**

Run: `bash tools/test_icu_launcher.sh`

Expected: FAIL for the current legacy Python behavior.

## Task 2: Implement the Swift-First Root Entrypoint

**Files:**
- Modify: `icu`
- Modify: `run_pet.py`
- Test: `tools/test_icu_launcher.sh`

- [ ] **Step 1: Implement the minimal root launcher**

```bash
case "${1:-}" in
  "")
    exec bash tools/run_macos_shell.sh
    ;;
  --verify)
    exec bash tools/verify_macos_shell.sh
    ;;
  *)
    echo "Usage: ./icu [--verify]" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 2: Mark `run_pet.py` as a legacy Python launcher**

Add a short module docstring/comment making clear it is transitional and no longer the default path.

- [ ] **Step 3: Run the launcher test**

Run: `bash tools/test_icu_launcher.sh`

Expected: PASS

- [ ] **Step 4: Smoke-test the real entrypoints**

Run:
```bash
bash ./icu --verify
```

Expected: PASS with the same output as `bash tools/verify_macos_shell.sh`.

## Task 3: Clean Runtime Dependencies

**Files:**
- Modify: `requirements.txt`
- Modify: `requirements-dev.txt`

- [ ] **Step 1: Add the failing dependency expectation to the review checklist**

Target state:
- `requirements.txt` does not contain `PySide6`
- `requirements.txt` does not contain `pytest`
- `requirements-dev.txt` contains `pytest`

- [ ] **Step 2: Verify the current dependency files do not meet that expectation**

Run:
```bash
rg -n 'PySide6|pytest' requirements.txt requirements-dev.txt
```

Expected: `requirements.txt` still contains both entries.

- [ ] **Step 3: Apply the minimal dependency cleanup**

Keep:
- `transitions`
- `requests`
- `Pillow`
- `watchdog`
- `huggingface-hub`
- `rembg`
- `opencv-python`

Move/remove:
- remove `PySide6` from runtime deps
- remove `pytest` from runtime deps
- keep `pytest` in dev deps

- [ ] **Step 4: Re-run the dependency grep**

Run:
```bash
rg -n 'PySide6|pytest' requirements.txt requirements-dev.txt
```

Expected:
- no `PySide6` in either runtime file
- `pytest` only in `requirements-dev.txt`

## Task 4: Update Swift-First Documentation

**Files:**
- Modify: `README.md`
- Modify: `README_CN.md`

- [ ] **Step 1: Add the failing documentation checks**

Need docs to show:
- `./icu` as the default launch command
- `./icu --verify` as the short verification command
- `apps/macos-shell` in the main structure
- no `rumps` in the tech stack

- [ ] **Step 2: Run grep checks to confirm the docs are still inconsistent**

Run:
```bash
rg -n '\./icu --verify|rumps|PySide6|apps/macos-shell' README.md README_CN.md
```

Expected: docs still mention old Python/Qt stack and do not fully present the new root-entry workflow.

- [ ] **Step 3: Update both READMEs**

Document:
- `./icu` launches Swift shell
- `./icu --verify` runs the lightweight verifier
- `tools/run_macos_shell.sh` and `tools/verify_macos_shell.sh` remain lower-level helpers
- `apps/macos-shell` is the primary runtime app path
- Python now mainly serves builder / migration / legacy support

- [ ] **Step 4: Re-run documentation grep**

Run:
```bash
rg -n '\./icu --verify|apps/macos-shell' README.md README_CN.md
```

Expected: matches in both files, with no runtime-stack reliance on `rumps`.

## Task 5: Update Project Tracking Files

**Files:**
- Modify: `findings.md`
- Modify: `progress.md`
- Modify: `task_plan.md`

- [ ] **Step 1: Add tracking expectations**

Record that:
- Swift is now the default startup path
- Python UI is no longer the default entrypoint
- dependency cleanup is intentionally partial and builder-safe

- [ ] **Step 2: Update the tracking files after implementation**

Include:
- the new `./icu` and `./icu --verify` behavior
- the dependency boundary
- what legacy Python remains

- [ ] **Step 3: Re-read the tracking files and ensure they match actual behavior**

Run:
```bash
sed -n '1,260p' findings.md
sed -n '1,260p' progress.md
sed -n '1,220p' task_plan.md
```

Expected: all three files reflect the Swift-first default path.

## Task 6: Final Verification

**Files:**
- Test: `tools/test_icu_launcher.sh`
- Test: `icu`
- Test: `tools/verify_macos_shell.sh`

- [ ] **Step 1: Run the root launcher script test**

Run: `bash tools/test_icu_launcher.sh`

Expected: PASS

- [ ] **Step 2: Run the short verification entrypoint**

Run: `bash ./icu --verify`

Expected: PASS

- [ ] **Step 3: Launch the real app through the short root command**

Run: `bash ./icu`

Expected:
- `ICUShell` builds and launches
- asset load log appears
- state directory is initialized under `~/Library/Application Support/ICU/state`

- [ ] **Step 4: Stop the launched process after confirming startup**

Interrupt the process once the launch log is observed. This is a successful smoke test, not a failure.

## Notes

- 当前会话未获用户授权切换到新 worktree；同时现有迁移实现都还在当前脏工作区中，因此本计划在当前工作区 inline 执行。
- 旧 Python UI 文件本体不在本轮直接删除范围内；本轮只移除其默认入口地位并清理明显不该保留的运行依赖。
