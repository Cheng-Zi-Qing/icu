# Window Placement And Python UI Package Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让桌宠首次启动默认出现在桌面右下角、拖动后记住位置，并清理本机全局旧 Qt/UI Python 包。

**Architecture:** 在现有 `PersistedRuntimeState` 中增加可选窗口位置字段，引入一个独立的窗口定位 helper 负责“默认右下角 / 恢复已保存位置 / 越界回退”。窗口控制器只消费该 helper 并在窗口移动后回写状态。全局 Python 清理只针对 Qt/UI 旧包，builder 相关包保持不动。

**Tech Stack:** Swift, AppKit, Foundation, Bash, pip3

---

## File Map

### New files

- `apps/macos-shell/Sources/ICUShell/Runtime/WindowPlacement.swift`
  纯运行态窗口定位 helper，负责默认右下角计算与保存位置恢复。
- `apps/macos-shell/Tests/ManualRuntime/WindowPlacementManualTests.swift`
  验证首次右下角、恢复已保存位置和越界回退规则。

### Modified files

- `apps/macos-shell/Sources/ICUShell/Runtime/ShellState.swift`
  为 `PersistedRuntimeState` 增加窗口位置字段。
- `apps/macos-shell/Sources/ICUShell/Runtime/WorkSessionController.swift`
  提供读取/写入窗口位置的最小接口。
- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift`
  启动时使用窗口定位 helper，移动后持久化窗口位置。
- `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
  将新窗口定位测试纳入手工 runtime test 入口。
- `tools/check_native_shell.sh`
  把 `WindowPlacement.swift` 与新手工测试编译进轻量验证链路。
- `findings.md`
  记录新定位策略与全局包清理边界。
- `progress.md`
  记录实现与验收结果。
- `task_plan.md`
  更新当前可本地测试状态。

## Task 1: Add Failing Manual Tests for Window Placement

**Files:**
- Create: `apps/macos-shell/Tests/ManualRuntime/WindowPlacementManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Write the failing test for first-launch bottom-right positioning**

```swift
func testDefaultOriginUsesVisibleFrameBottomRight() throws {
    let origin = WindowPlacement.defaultOrigin(
        visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        windowSize: CGSize(width: 128, height: 128)
    )

    try expect(origin.x > 1200, "origin should be near right edge")
    try expect(origin.y < 100, "origin should be near bottom edge")
}
```

- [ ] **Step 2: Write the failing test for restoring a saved position**

```swift
func testResolveInitialOriginPrefersSavedVisiblePosition() throws {
    let saved = SavedWindowPlacement(x: 900, y: 120)
    let origin = WindowPlacement.resolveInitialOrigin(...)
    try expect(origin.x == 900 && origin.y == 120, "saved visible origin should be restored")
}
```

- [ ] **Step 3: Write the failing test for out-of-bounds fallback**

```swift
func testResolveInitialOriginFallsBackWhenSavedPositionIsOutOfBounds() throws {
    let saved = SavedWindowPlacement(x: 5000, y: 5000)
    let origin = WindowPlacement.resolveInitialOrigin(...)
    try expect(origin.x < 1400, "out-of-bounds saved origin should not be used")
}
```

- [ ] **Step 4: Run the lightweight manual runtime test harness and verify it fails because the helper does not exist yet**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL with `cannot find 'WindowPlacement'` or equivalent missing-type errors.

## Task 2: Implement Runtime Window Placement And Persistence

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Runtime/WindowPlacement.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Runtime/ShellState.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Runtime/WorkSessionController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift`

- [ ] **Step 1: Implement the minimal placement models and helper**

```swift
struct SavedWindowPlacement: Codable, Equatable {
    var x: Double
    var y: Double
}

enum WindowPlacement {
    static func defaultOrigin(visibleFrame: CGRect, windowSize: CGSize, margin: CGFloat = 24) -> CGPoint { ... }
    static func resolveInitialOrigin(saved: SavedWindowPlacement?, visibleFrame: CGRect, windowSize: CGSize, margin: CGFloat = 24) -> CGPoint { ... }
}
```

- [ ] **Step 2: Extend persisted runtime state with an optional window placement**

```swift
struct PersistedRuntimeState: Codable, Equatable {
    ...
    var windowPlacement: SavedWindowPlacement?
}
```

- [ ] **Step 3: Add minimal read/write API on `WorkSessionController`**

```swift
var savedWindowPlacement: SavedWindowPlacement? { currentState.windowPlacement }
func persistWindowPlacement(_ placement: SavedWindowPlacement, now: Date = .now) throws { ... }
```

- [ ] **Step 4: Update the window controller to use the helper and persist movement**

Implementation requirements:
- initial position uses saved placement if visible
- otherwise uses bottom-right default
- movement updates persisted placement

- [ ] **Step 5: Run the lightweight verification harness again**

Run: `bash tools/check_native_shell.sh`

Expected: PASS

## Task 3: Validate Real Launch Positioning Behavior

**Files:**
- Test: `icu`
- Test: `tools/run_macos_shell.sh`

- [ ] **Step 1: Launch the app through the short root command**

Run: `bash ./icu`

Expected:
- app launches
- no startup crash
- state file is updated

- [ ] **Step 2: Stop the running app after confirming startup**

Interrupt once the launch log is observed.

- [ ] **Step 3: Inspect the state file for stored window placement**

Run:
```bash
cat "$HOME/Library/Application Support/ICU/state/current_state.json"
```

Expected: JSON includes a non-null window placement object.

## Task 4: Remove Global Qt/UI Python Packages

**Files:**
- Test: global `pip3` environment

- [ ] **Step 1: Inspect current package presence**

Run:
```bash
pip3 list --format=columns | rg 'PySide6|PySide6_Addons|PySide6_Essentials|shiboken6|rumps'
```

Expected: either packages are listed or output is empty.

- [ ] **Step 2: Uninstall the target packages from the global `pip3` environment**

Run:
```bash
pip3 uninstall -y PySide6 PySide6_Addons PySide6_Essentials shiboken6 rumps
```

Expected: installed packages are removed; missing packages report as skipped/not installed.

- [ ] **Step 3: Verify removal**

Run:
```bash
pip3 list --format=columns | rg 'PySide6|PySide6_Addons|PySide6_Essentials|shiboken6|rumps'
```

Expected: no matches.

## Task 5: Update Tracking Files

**Files:**
- Modify: `findings.md`
- Modify: `progress.md`
- Modify: `task_plan.md`

- [ ] **Step 1: Record the positioning rule**

Capture:
- first launch = bottom-right
- dragged position = persisted

- [ ] **Step 2: Record global package cleanup results**

Capture:
- which target packages existed
- whether uninstall actually removed anything or the environment was already clean

- [ ] **Step 3: Re-read the tracking files for consistency**

Run:
```bash
sed -n '1,260p' findings.md
sed -n '1,320p' progress.md
sed -n '1,240p' task_plan.md
```

Expected: all three reflect the new positioning rule and package cleanup state.

## Task 6: Final Verification

**Files:**
- Test: `bash tools/check_native_shell.sh`
- Test: `bash ./icu --verify`
- Test: `bash tools/test_icu_launcher.sh`

- [ ] **Step 1: Run the manual runtime verification**

Run: `bash tools/check_native_shell.sh`

Expected: PASS

- [ ] **Step 2: Run the short verification entrypoint**

Run: `bash ./icu --verify`

Expected: PASS

- [ ] **Step 3: Re-run the root launcher script test**

Run: `bash tools/test_icu_launcher.sh`

Expected: PASS

## Notes

- 当前会话下 `python3 -m pip list` 初步检查未显示 `PySide6` / `shiboken6` / `rumps`，但仍需按 `pip3` 全局环境执行正式卸载与复验。
- 本计划只清理全局 Qt/UI Python 包，不碰 builder 所需依赖。
