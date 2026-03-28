# PRD 1.6 Phase 1 Native Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Swift/AppKit shell 接管桌宠主路径的最小闭环，至少覆盖本地状态机、开始工作/进入专注/返回工作交互、Application Support 目录初始化，以及一类提醒的原生调度入口。

**Architecture:** 保留旧 Qt 路径作为临时回退，先在 `apps/macos-shell` 内补齐可测试的 shell 基础设施：本地目录与状态存储、运行态状态机、桌宠右键菜单状态驱动、原生提醒调度骨架。第一批实现不接入 Python worker，只为后续 WorkerClient 与 JSON Lines 协议预留边界。

**Tech Stack:** Swift Package Manager, AppKit, XCTest, macOS 14+

---

## File Map

### New files

- `apps/macos-shell/Sources/ICUShell/Runtime/AppPaths.swift`
  统一解析 `~/Library/Application Support/ICU/` 及其子目录，负责目录初始化。
- `apps/macos-shell/Sources/ICUShell/Runtime/ShellState.swift`
  定义 shell 侧主状态、提醒类型、focus 结束分级等 domain model。
- `apps/macos-shell/Sources/ICUShell/Runtime/StateStore.swift`
  负责 shell-owned 当前状态缓存的读写。
- `apps/macos-shell/Sources/ICUShell/Runtime/WorkSessionController.swift`
  实现 `idle/working/focus/break` 状态机与计时。
- `apps/macos-shell/Sources/ICUShell/Runtime/ReminderScheduler.swift`
  原生提醒调度骨架，先支持护眼提醒与 focus 挂起/恢复。
- `apps/macos-shell/Tests/ICUShellTests/WorkSessionControllerTests.swift`
  状态合法迁移、focus 结束分级、工作计时重置测试。
- `apps/macos-shell/Tests/ICUShellTests/StateStoreTests.swift`
  App Support 路径初始化与状态缓存持久化测试。

### Modified files

- `apps/macos-shell/Package.swift`
  修正当前无法运行测试的 package 配置，并显式加入 test target。
- `apps/macos-shell/Sources/ICUShell/AppDelegate.swift`
  初始化 paths/store/controller，并把状态驱动接到 window controller。
- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift`
  接入 `WorkSessionController`，根据当前状态构建右键菜单并响应状态切换。
- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift`
  暂时保留 spike 资源加载逻辑，但为后续状态视觉切换预留更新入口。
- `progress.md`
  记录实现和验证结果。
- `task_plan.md`
  推进阶段状态。

## Task 1: Repair Swift Package Test Harness

**Files:**
- Modify: `apps/macos-shell/Package.swift`
- Test: `apps/macos-shell/Tests/ICUShellTests/SmokeTests.swift`

- [ ] **Step 1: Write the failing smoke test**

```swift
import XCTest
@testable import ICUShell

final class SmokeTests: XCTestCase {
    func testPackageBuilds() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 2: Run test to verify the package currently fails before test execution**

Run: `swift test --package-path apps/macos-shell`

Expected: FAIL while parsing `Package.swift`, proving the harness is currently broken.

- [ ] **Step 3: Apply the minimal package fix**

```swift
let package = Package(
    name: "ICUShell",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ICUShell", targets: ["ICUShell"])
    ],
    targets: [
        .executableTarget(name: "ICUShell", path: "Sources/ICUShell"),
        .testTarget(name: "ICUShellTests", dependencies: ["ICUShell"], path: "Tests/ICUShellTests"),
    ]
)
```

- [ ] **Step 4: Run test to verify the harness now executes**

Run: `swift test --package-path apps/macos-shell`

Expected: PASS for the smoke test.

## Task 2: Application Support Paths and State Store

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Runtime/AppPaths.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Runtime/ShellState.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Runtime/StateStore.swift`
- Create: `apps/macos-shell/Tests/ICUShellTests/StateStoreTests.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/AppDelegate.swift`

- [ ] **Step 1: Write the failing App Support initialization test**

```swift
func testStateStoreCreatesICUStateDirectory() throws {
    let root = temporaryDirectory()
    let paths = AppPaths(rootURL: root)
    let store = try StateStore(paths: paths)

    XCTAssertTrue(FileManager.default.fileExists(atPath: paths.stateDirectory.path))
    XCTAssertEqual(store.currentState().state, .idle)
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `swift test --package-path apps/macos-shell --filter StateStoreTests/testStateStoreCreatesICUStateDirectory`

Expected: FAIL because `AppPaths` and `StateStore` do not exist yet.

- [ ] **Step 3: Implement the minimal paths/store layer**

```swift
struct AppPaths {
    let rootURL: URL
    var stateDirectory: URL { rootURL.appendingPathComponent("state", isDirectory: true) }
}

final class StateStore {
    init(paths: AppPaths) throws { ... }
    func currentState() -> PersistedState { ... }
    func save(_ state: PersistedState) throws { ... }
}
```

- [ ] **Step 4: Run the focused state store tests**

Run: `swift test --package-path apps/macos-shell --filter StateStoreTests`

Expected: PASS

- [ ] **Step 5: Wire initialization into `AppDelegate`**

```swift
let paths = try AppPaths.default()
let store = try StateStore(paths: paths)
```

## Task 3: Work Session Controller

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Runtime/WorkSessionController.swift`
- Create: `apps/macos-shell/Tests/ICUShellTests/WorkSessionControllerTests.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/AppDelegate.swift`

- [ ] **Step 1: Write the failing test for allowed transitions**

```swift
func testAllowsIdleWorkingFocusWorkingBreakWorkingIdleFlow() throws {
    let controller = makeController()
    try controller.startWork()
    try controller.enterFocus(now: at(0))
    let end = try controller.resumeWorking(now: at(35 * 60))
    try controller.takeBreak()
    try controller.resumeFromBreak()
    try controller.stopWork()

    XCTAssertEqual(controller.state, .idle)
    XCTAssertEqual(end, .light)
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `swift test --package-path apps/macos-shell --filter WorkSessionControllerTests/testAllowsIdleWorkingFocusWorkingBreakWorkingIdleFlow`

Expected: FAIL because `WorkSessionController` does not exist yet.

- [ ] **Step 3: Implement the minimal shell state machine**

```swift
final class WorkSessionController {
    private(set) var state: ShellWorkState = .idle
    func startWork() throws { ... }
    func enterFocus(now: Date = .now) throws { ... }
    func resumeWorking(now: Date = .now) throws -> FocusEndSuggestion? { ... }
    func takeBreak() throws { ... }
    func resumeFromBreak() throws { ... }
    func stopWork() throws { ... }
}
```

- [ ] **Step 4: Add a failing test for illegal transitions**

```swift
func testRejectsBreakToFocusShortcut() throws {
    let controller = makeController()
    try controller.startWork()
    try controller.takeBreak()

    XCTAssertThrowsError(try controller.enterFocus())
}
```

- [ ] **Step 5: Run the WorkSessionController test file**

Run: `swift test --package-path apps/macos-shell --filter WorkSessionControllerTests`

Expected: PASS

## Task 4: Menu Wiring in Native Shell

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/AppDelegate.swift`

- [ ] **Step 1: Write the failing test for menu state exposure**

```swift
func testMenuActionsReflectCurrentWorkState() throws {
    let controller = makeController()
    let menuModel = DesktopPetMenuModel(state: controller.state)
    XCTAssertEqual(menuModel.items, [.startWork, .quit])
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `swift test --package-path apps/macos-shell --filter MenuModelTests`

Expected: FAIL because the menu model does not exist yet.

- [ ] **Step 3: Implement minimal menu model and wire callbacks**

```swift
enum PetMenuAction { case startWork, enterFocus, takeBreak, resumeWork, stopWork, closeWindow }
```

`DesktopPetWindow` should build menu entries from current state instead of showing only coordinates.

- [ ] **Step 4: Run shell test suite**

Run: `swift test --package-path apps/macos-shell`

Expected: PASS for harness, state store, work session, and menu model tests.

## Task 5: Native Reminder Scheduler Skeleton

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Runtime/ReminderScheduler.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/AppDelegate.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift`

- [ ] **Step 1: Write the failing test for focus pause behavior**

```swift
func testFocusStateSuspendsEyeCareReminder() throws {
    let scheduler = ReminderScheduler(clock: testClock)
    scheduler.startWorking()
    scheduler.enterFocus()

    XCTAssertFalse(scheduler.isEyeReminderArmed)
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `swift test --package-path apps/macos-shell --filter ReminderSchedulerTests`

Expected: FAIL because `ReminderScheduler` does not exist yet.

- [ ] **Step 3: Implement the minimal scheduler skeleton**

```swift
final class ReminderScheduler {
    private(set) var isEyeReminderArmed = false
    func startWorking() { isEyeReminderArmed = true }
    func enterFocus() { isEyeReminderArmed = false }
    func resumeWorking() { isEyeReminderArmed = true }
    func stop() { isEyeReminderArmed = false }
}
```

- [ ] **Step 4: Run the full shell test suite again**

Run: `swift test --package-path apps/macos-shell`

Expected: PASS

## Verification

- `swift test --package-path apps/macos-shell`
- `swift run --package-path apps/macos-shell ICUShell`
- 验证右键菜单至少能覆盖 `开始工作 / 进入专注 / 暂离 / 回来工作 / 下班 / 退出`
- 验证首次运行会初始化 `~/Library/Application Support/ICU/state/`

