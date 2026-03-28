# Release Runtime Smoke Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `dist/ICU.app` 建立脱离仓库目录的运行 smoke test，并把它接入现有 Swift shell 发布前验证链路。

**Architecture:** 在不引入 UI 自动化框架的前提下，这一轮通过“可控启动诊断 + 独立 app 副本启动脚本 + verify 集成”补齐运行闭环。Swift 侧只增加最小运行时路径诊断和可覆盖的 app support 根路径，shell 侧负责复制 `.app`、隔离运行、采集证据、超时回收与脚本测试。

**Tech Stack:** Swift 6, SwiftPM, AppKit, Bash, existing `./icu --verify` / `tools/check_native_shell.sh` / shell test scripts

---

## File Structure

- Create: `apps/macos-shell/Sources/ICUShell/Runtime/RuntimeLaunchDiagnostics.swift`
  - 负责生成稳定、可 grep 的运行时诊断输出，避免把路径判断逻辑散落在 `AppDelegate.swift`。
- Modify: `apps/macos-shell/Sources/ICUShell/Runtime/AppPaths.swift`
  - 让 `AppPaths.live(...)` 在需要时优先使用 `ICU_APP_SUPPORT_ROOT`，便于 smoke test 把用户写目录重定向到临时位置。
- Modify: `apps/macos-shell/Sources/ICUShell/AppDelegate.swift`
  - 在启动成功路径中输出最小诊断信息，并继续把最终 app support 根注入给 bridge。
- Create: `apps/macos-shell/Tests/ManualRuntime/AppPathsManualTests.swift`
  - 覆盖 app support override 与诊断文案 contract。
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
  - 注册新的 runtime 手工测试。
- Modify: `tools/check_native_shell.sh`
  - 把新 Swift 源文件和手工测试文件纳入现有轻量校验链。
- Create: `tools/smoke_test_macos_app_runtime.sh`
  - 负责复制 `.app` 到临时目录、隔离启动、采集日志、检查 app support 副作用、超时回收。
- Create: `tools/test_smoke_test_macos_app_runtime.sh`
  - 覆盖 smoke script 的成功路径、超时路径、打包脚本调用路径。
- Modify: `tools/verify_macos_shell.sh`
  - 增加 `VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1` 开关，在 bundle 结构检查后追加 detached runtime smoke test。
- Modify: `tools/test_verify_macos_shell.sh`
  - 覆盖新的 verify 分支和脚本调用顺序。
- Modify: `tools/macos_shell_release.env.example`
  - 增加发布前运行闭环的推荐开关示例。
- Modify: `docs/macos-shell-release.md`
  - 明确区分 bundle 结构检查与 detached runtime smoke check。
- Modify: `README.md`
  - 更新英文快速发布验证入口。
- Modify: `README_CN.md`
  - 更新中文快速发布验证入口。

### Task 1: Add App Support Override And Runtime Launch Diagnostics

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Runtime/RuntimeLaunchDiagnostics.swift`
- Create: `apps/macos-shell/Tests/ManualRuntime/AppPathsManualTests.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Runtime/AppPaths.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/AppDelegate.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Write the failing manual runtime tests**

Add tests for:
- `AppPaths.live(...)` 优先使用 `ICU_APP_SUPPORT_ROOT`
- 诊断输出包含 app support root、repo root、运行模式字段

```swift
func testAppPathsLivePrefersICUAppSupportRootOverride() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let paths = try AppPaths.live(
        environment: ["ICU_APP_SUPPORT_ROOT": root.path],
        fileManager: .default
    )

    try expect(paths.rootURL.standardizedFileURL == root.standardizedFileURL, "live paths should honor ICU_APP_SUPPORT_ROOT")
}

func testRuntimeLaunchDiagnosticsIncludeBundleAndAppSupportPaths() throws {
    let appPaths = AppPaths(rootURL: URL(fileURLWithPath: "/tmp/ICU", isDirectory: true))
    let lines = RuntimeLaunchDiagnostics.lines(
        appPaths: appPaths,
        repoRootURL: URL(fileURLWithPath: "/tmp/repo", isDirectory: true),
        bundleResourceURL: URL(fileURLWithPath: "/tmp/ICU.app/Contents/Resources", isDirectory: true)
    )

    try expect(lines.contains { $0.contains("[app_paths] app_support_root=/tmp/ICU") }, "diagnostics should include app support root")
}
```

- [ ] **Step 2: Run the manual runtime checks to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL with missing `RuntimeLaunchDiagnostics` or `AppPaths.live(environment:)` support.

- [ ] **Step 3: Implement the minimal runtime diagnostics**

Implement:
- `AppPaths.live(environment:fileManager:)` with `ICU_APP_SUPPORT_ROOT` override
- `RuntimeLaunchDiagnostics.lines(...)`
- `AppDelegate` startup logging via the new helper

```swift
struct RuntimeLaunchDiagnostics {
    static func lines(appPaths: AppPaths, repoRootURL: URL?, bundleResourceURL: URL?) -> [String] {
        [
            "[app_paths] mode=\(bundleResourceURL == nil ? "repo" : "bundle")",
            "[app_paths] app_support_root=\(appPaths.rootURL.path)",
            "[app_paths] repo_root=\(repoRootURL?.path ?? "nil")",
        ]
    }
}
```

- [ ] **Step 4: Run the manual runtime checks to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/macos-shell/Sources/ICUShell/Runtime/RuntimeLaunchDiagnostics.swift \
  apps/macos-shell/Sources/ICUShell/Runtime/AppPaths.swift \
  apps/macos-shell/Sources/ICUShell/AppDelegate.swift \
  apps/macos-shell/Tests/ManualRuntime/AppPathsManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift \
  tools/check_native_shell.sh
git commit -m "feat: add runtime launch diagnostics"
```

### Task 2: Add Detached App Runtime Smoke Script

**Files:**
- Create: `tools/smoke_test_macos_app_runtime.sh`
- Create: `tools/test_smoke_test_macos_app_runtime.sh`

- [ ] **Step 1: Write the failing shell tests for the smoke script**

Add shell tests for:
- 成功路径：复制 `.app`、启动 bundle binary、采集日志、检查 app support 根
- 超时路径：启动后在超时窗口内未进入稳定状态时返回非零
- 缺少 bundle 时：会先调用打包脚本

```bash
run_success_case() {
  ICU_RUNTIME_SMOKE_APP_BUNDLE_PATH="$temp_dir/ICU.app" \
  ICU_RUNTIME_SMOKE_APP_SUPPORT_ROOT="$temp_dir/app-support" \
  ICU_RUNTIME_SMOKE_TIMEOUT_SECONDS="2" \
  bash "$SMOKE_SCRIPT"
}

run_timeout_case() {
  ICU_RUNTIME_SMOKE_APP_BUNDLE_PATH="$temp_dir/ICU.app" \
  ICU_RUNTIME_SMOKE_TIMEOUT_SECONDS="0" \
  bash "$SMOKE_SCRIPT"
}
```

- [ ] **Step 2: Run the shell tests to verify they fail**

Run: `bash tools/test_smoke_test_macos_app_runtime.sh`
Expected: FAIL because the smoke script does not exist yet.

- [ ] **Step 3: Implement the minimal detached runtime smoke script**

Implement:
- app bundle resolution or on-demand packaging
- temporary copy directory creation
- isolated launch from copied bundle
- log capture and timeout-based process cleanup
- app support root verification using `ICU_APP_SUPPORT_ROOT`

```bash
copied_app="$temp_root/run/ICU.app"
cp -R "$source_app" "$copied_app"
(
  cd "$temp_root/run"
  ICU_APP_SUPPORT_ROOT="$app_support_root" \
  "$copied_app/Contents/MacOS/ICUShell" >"$stdout_log" 2>"$stderr_log" &
  app_pid=$!
)
```

- [ ] **Step 4: Run the shell tests to verify they pass**

Run: `bash tools/test_smoke_test_macos_app_runtime.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tools/smoke_test_macos_app_runtime.sh \
  tools/test_smoke_test_macos_app_runtime.sh
git commit -m "feat: add detached app runtime smoke test"
```

### Task 3: Integrate Detached Runtime Smoke Check Into Verify

**Files:**
- Modify: `tools/verify_macos_shell.sh`
- Modify: `tools/test_verify_macos_shell.sh`
- Modify: `tools/macos_shell_release.env.example`

- [ ] **Step 1: Extend verify script tests with a failing runtime smoke branch**

Add assertions for:
- `VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1` 时会调用新的 smoke script
- 调用顺序是 package -> app bundle check -> runtime smoke
- 默认不开启 runtime smoke 时不触发该分支

```bash
assert_contains "$output" "[verify_macos_shell] Running detached app runtime smoke check..."
assert_contains "$(cat "$log_file")" "runtime-smoke /tmp/ICU.app"
```

- [ ] **Step 2: Run the verifier tests to verify they fail**

Run: `bash tools/test_verify_macos_shell.sh`
Expected: FAIL with missing runtime smoke branch or missing stub invocation.

- [ ] **Step 3: Implement verify integration and env template wiring**

Implement:
- `VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK`
- `VERIFY_MACOS_SHELL_RUNTIME_SMOKE_SCRIPT`
- release env example that demonstrates full pre-release verification

```bash
if [[ "$RUNTIME_SMOKE_ENABLED" == "1" ]]; then
  echo "[verify_macos_shell] Running detached app runtime smoke check..."
  bash "$RUNTIME_SMOKE_SCRIPT" "$APP_BUNDLE_PATH"
fi
```

- [ ] **Step 4: Run the verifier tests to verify they pass**

Run: `bash tools/test_verify_macos_shell.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tools/verify_macos_shell.sh \
  tools/test_verify_macos_shell.sh \
  tools/macos_shell_release.env.example
git commit -m "feat: wire runtime smoke check into verify"
```

### Task 4: Update Release Docs And Run Full Verification

**Files:**
- Modify: `docs/macos-shell-release.md`
- Modify: `README.md`
- Modify: `README_CN.md`

- [ ] **Step 1: Update the docs with the new verification layer**

Document:
- detached runtime smoke check command
- what it proves vs. what bundle structure check proves
- that signing / notarization / Gatekeeper remains next phase

```md
VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 \
VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1 \
./icu --verify
```

- [ ] **Step 2: Run the direct script checks**

Run:
- `bash tools/test_smoke_test_macos_app_runtime.sh`
- `bash tools/test_verify_macos_shell.sh`

Expected: both PASS

- [ ] **Step 3: Run the full release verification chain**

Run:

```bash
VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 \
VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1 \
./icu --verify
```

Expected:
- `swift build` PASS
- manual runtime checks PASS
- `swift test` PASS or explicit Xcode skip
- bundle structure check PASS
- detached runtime smoke check PASS

- [ ] **Step 4: Commit**

```bash
git add docs/macos-shell-release.md README.md README_CN.md
git commit -m "docs: add detached runtime smoke verification guide"
```
