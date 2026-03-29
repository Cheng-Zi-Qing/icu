# Context Menu And Config Workbench Density Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把右键菜单收回到贴近桌宠的工具菜单尺度，并把模型配置页改成更像“表单工作台”的工作界面。

**Architecture:** 先用 AppKit manual tests 锁定新的菜单 / 配置页比例 contract，再分别在 `ThemedMenuPanel` 和 `GenerationConfigWindowController` 做局部收敛。默认不碰 studio，也不主动修改共享主题层；只有当本地 layout 无法达成“厚字段工作台”时，才最小化调整 `ThemedComponents`。

**Tech Stack:** Swift 5.10, AppKit, SwiftPM, manual runtime tests, shell verification scripts

---

## Worktree Notes

- 当前 worktree 在写计划时是干净的，分支为 `runtime-bubble-contracts`
- 现有 spec 已确认并通过规格审查：
  - `docs/superpowers/specs/2026-03-29-context-menu-and-config-workbench-density-design.md`
- 本轮只实现两个独立子问题：
  - 右键菜单收小
  - 模型配置页改成表单工作台
- 不要顺手修改 `AvatarSelectorWindowController.swift` 或其它 studio 页面文件

## File Structure

- Modify: `apps/macos-shell/Sources/ICUShell/Menu/ThemedMenuPanel.swift`
  - 把菜单从主面板尺度收回到工具菜单尺度；优先只改几何常量
- Modify: `apps/macos-shell/Sources/ICUShell/Menu/ContextMenuPanelController.swift`
  - 仅当菜单缩小后锚点显得漂移时，最小化调整 pinning 逻辑
- Modify: `apps/macos-shell/Tests/ManualRuntime/MenuPanelAppKitManualTests.swift`
  - 更新菜单宽高 / 行高 contract；必要时更新 anchor baseline 断言
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
  - 确保 `check_native_shell.sh` 实际执行到本轮更新过的 menu / generation contract tests
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
  - 把窗口改成更矮更宽的 workbench form，压缩头部信息，提升字段高度，维持“基础默认 / 高级折叠”
- Modify: `apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift`
  - 仅当本地 layout 无法让字段达到“工作台厚度”时最小化调整共享输入框样式
- Modify: `apps/macos-shell/Tests/ManualRuntime/GenerationConfigAppKitManualTests.swift`
  - 更新窗口尺寸、字段高度、默认可见结构 contract

## Task 1: Shrink The Context Menu Back To Tool-Menu Scale

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Menu/ThemedMenuPanel.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Menu/ContextMenuPanelController.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/MenuPanelAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Update the existing menu preferred-size test to the tool-menu contract**

Update `testThemedMenuPanelUsesCompactPreferredSize` so the same five-row fixture now expects the smaller workbench-balanced tool menu:

```swift
func testThemedMenuPanelUsesCompactPreferredSize() throws {
    let sections = [
        ThemedMenuPanelSection(items: [
            ThemedMenuPanelItem(id: "start", title: "开始工作"),
        ]),
        ThemedMenuPanelSection(items: [
            ThemedMenuPanelItem(id: "avatar", title: "更换形象"),
            ThemedMenuPanelItem(id: "generation", title: "生成配置"),
        ]),
        ThemedMenuPanelSection(items: [
            ThemedMenuPanelItem(id: "hide", title: "隐藏桌宠"),
            ThemedMenuPanelItem(id: "quit", title: "退出"),
        ]),
    ]
    let preferredSize = ThemedMenuPanel.preferredSize(for: sections)

    try expect(preferredSize.width == 184, "context menu should return to the lighter tool-menu width")
    try expect(preferredSize.height == 184, "context menu should use the reduced tool-menu height contract")
}
```

- [ ] **Step 2: Update the existing row-height and anchor tests to the smaller menu density**

Update `testThemedMenuPanelRowsHonorExpandedRowHeight` and `testContextMenuPanelControllerKeepsExpandedMenuPinnedToLegacyBaseline`, and add one taller real-state height-scaling contract:

```swift
func testThemedMenuPanelPreferredHeightScalesForWorkingMenuState() throws {
    let model = DesktopPetMenuModel(state: .working)
    let sections = model.sections.map { section in
        ThemedMenuPanelSection(
            items: section.map { action in
                ThemedMenuPanelItem(
                    id: action.rawValue,
                    title: action.title,
                    tone: action == .quitApp ? .destructive : .standard
                )
            }
        )
    }

    let preferredSize = ThemedMenuPanel.preferredSize(for: sections)
    try expect(preferredSize.width == 184, "working-state menu should keep the tool-menu width")
    try expect(preferredSize.height == 246, "working-state menu height should still scale with the real seven-row runtime menu")
}

func testThemedMenuPanelRowsHonorExpandedRowHeight() throws {
    // same fixture
    try expect(heightConstraint?.constant == 28, "menu row buttons should shrink to the lighter tool-menu row height")
    try expect(button.frame.height == 28, "menu row buttons should measure 28pt tall after layout")
}


func testContextMenuPanelControllerKeepsExpandedMenuPinnedToLegacyBaseline() throws {
    let expandedSize = NSSize(width: 184, height: 184)
    let expandedFrame = controller.frame(for: expandedSize, clickPoint: clickPoint)
    let expectedExpandedY = clickPoint.y - legacyMenuHeight + anchorInset
    try expect(expandedFrame.origin.y == expectedExpandedY, "the controller should keep taller menus pinned to the legacy bottom baseline")
}
```

- [ ] **Step 3: Wire the updated menu tests into `ThemeAppKitManualMain`**

Ensure `ThemeAppKitManualMain.main()` actually calls:

```swift
try testThemedMenuPanelUsesCompactPreferredSize()
try testThemedMenuPanelPreferredHeightScalesForWorkingMenuState()
try testThemedMenuPanelRowsHonorExpandedRowHeight()
try testContextMenuPanelControllerKeepsExpandedMenuPinnedToLegacyBaseline()
```

Keep the existing render / dispatch / floating-panel coverage in place; this step only makes the scripted red/green checkpoints trustworthy.

- [ ] **Step 4: Run the native shell checks to verify the menu tests fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL because the menu still reports `208x210` and `32`-point rows.

- [ ] **Step 5: Implement the lighter tool-menu geometry in `ThemedMenuPanel`**

Update `ThemedMenuPanel.Layout` to the smaller tool-menu constants:

```swift
static let panelWidth: CGFloat = 184
static let outerPadding: CGFloat = 10
static let rootSpacing: CGFloat = 4
static let sectionRowSpacing: CGFloat = 3
static let rowHeight: CGFloat = 28
```

Keep section structure, destructive tone, and hover behavior unchanged.

Do not change menu information architecture or row styling beyond the geometry constants.

- [ ] **Step 6: Verify whether `ContextMenuPanelController` needs a code change**

The new five-row menu is still taller than the `174` legacy baseline, so the existing `frame(for:)` rule should continue to pin the bottom edge correctly. Only edit `ContextMenuPanelController.swift` if the updated anchor test fails or runtime visual review shows drift.

- [ ] **Step 7: Run the native shell checks to verify the smaller menu passes**

Run: `bash tools/check_native_shell.sh`
Expected: PASS, including the updated menu preferred size / row height assertions.

- [ ] **Step 8: Commit the tool-menu density changes**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Menu/ThemedMenuPanel.swift \
  apps/macos-shell/Sources/ICUShell/Menu/ContextMenuPanelController.swift \
  apps/macos-shell/Tests/ManualRuntime/MenuPanelAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift
git commit -m "fix: rebalance context menu to tool-menu density"
```

If `ContextMenuPanelController.swift` was not touched, omit it from `git add`.

## Task 2: Turn Generation Config Into A Workbench Form

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/GenerationConfigAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Tighten `testGenerationConfigWindowUsesCompactFrame` to the workbench window size**

Update the existing test in-place so `ThemeAppKitManualMain` does not need a rename follow-up:

```swift
func testGenerationConfigWindowUsesCompactFrame() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
    let service = ThemeGenerationService(
        transport: StubGenerationTransport(
            results: [
                .success(#"{\"name\":\"Moss Pixel\",\"summary\":\"掌机感、苔藓绿、低饱和\"}"#),
                .success(validThemePackJSONString(id: "moss_pixel"))
            ]
        ),
        settingsStore: settingsStore,
        themeManager: themeManager
    )
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
    )
    let controller = coordinator.openGenerationConfig()
    guard let contentSize = controller.window?.contentView?.frame.size else {
        throw TestFailure(message: "generation config window content view should exist")
    }

    try expect(contentSize == NSSize(width: 804, height: 520), "generation config should use the wider, shorter workbench frame")
}

```

- [ ] **Step 2: Add `testGenerationConfigWindowUsesThickerFieldDensity` to the active manual runner and tighten it to the workbench control height**

Keep the existing test name, but update the assertion target:

```swift
func testGenerationConfigWindowUsesThickerFieldDensity() throws {
    let settingsStore = try makeGenerationSettingsStore()
    let themeManager = try makeThemeManagerWithPixelDefault()
    let service = ThemeGenerationService(
        transport: StubGenerationTransport(
            results: [
                .success(#"{\"name\":\"Moss Pixel\",\"summary\":\"掌机感、苔藓绿、低饱和\"}"#),
                .success(validThemePackJSONString(id: "moss_pixel"))
            ]
        ),
        settingsStore: settingsStore,
        themeManager: themeManager
    )
    let coordinator = GenerationCoordinator(
        settingsStore: settingsStore,
        themeManager: themeManager,
        generationService: service
    )
    let controller = coordinator.openGenerationConfig()
    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "generation config window content view should exist")
    }
    let modelField = try requireTextField(in: contentView, placeholder: "model")
    let heightConstraint = modelField.constraints.first { constraint in
        constraint.firstAttribute == .height && constraint.firstItem === modelField
    }
    try expect(heightConstraint?.constant == 42, "generation config should promote fields to the workbench height class")
}
```

Also add this call to `ThemeAppKitManualMain.main()`:

```swift
try testGenerationConfigWindowUsesThickerFieldDensity()
```

- [ ] **Step 3: Extend the section-visibility test so advanced fields stay collapsed by default**

In `testGenerationConfigWindowCapabilityDetailUsesBasicAndAdvancedSections`, add an assertion like:

```swift
try expect(
    findTextField(in: contentView, placeholder: "auth JSON，如 {\"api_key\":\"sk-xxx\"}") == nil,
    "advanced fields should stay folded by default"
)
```

Prefer asserting the visible contract over brittle traversal details. If an existing spacing assertion depends on a fragile stack hierarchy, replace it with checks on:

- content size
- field height
- basic labels being visible
- advanced labels / fields being hidden until expanded

- [ ] **Step 4: Run the native shell checks to verify the workbench tests fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL because the window is still `720x600`, fields are `34` high, and the page still presents the older taller layout.

- [ ] **Step 5: Change `GenerationConfigWindowController.Layout` to the approved workbench constants**

Reshape the config window toward the approved `Workbench Balanced` structure:

```swift
static let windowSize = NSSize(width: 804, height: 520)
static let contentInset: CGFloat = 16
static let rootSpacing: CGFloat = 8
static let contentSpacing: CGFloat = 8
static let tabHeight: CGFloat = 30
static let fieldRowSpacing: CGFloat = 10
static let labelSpacing: CGFloat = 5
static let fieldHeight: CGFloat = 42
```

- [ ] **Step 6: Rebuild the page rhythm so the form, not blank space, becomes the main visual**

Within `GenerationConfigWindowController.swift`:

- keep the current tab architecture
- keep “基础默认 / 高级折叠”
- compress the header into a shorter title/subtitle block
- keep the detail card as the main surface
- make the field column visually dominant
- keep the bottom status label but reduce its vertical claim on the page
- if the current scroll-view chrome adds unnecessary panel-in-panel weight, localize the detail container so the card remains the main visual surface

- [ ] **Step 7: Verify that default/basic and advanced/collapsed behavior still works after the layout rewrite**

Before touching shared theme code, confirm these behaviors still hold in the updated controller:

- the three tabs still switch capability detail
- only `provider` / `model` / `baseURL` are visible by default
- `auth` / `options` still appear only after toggling advanced
- draft edits still survive tab switches

- [ ] **Step 8: Adjust shared text-field styling only if the local layout still leaves fields visually too small**

If, after Step 6, `42`-point fields still read as thin due to shared styling, make the smallest necessary change in `ThemedComponents.styleTextField` so single-line fields feel like workbench controls.

Do **not** change shared styling if the local `GenerationConfigWindowController` reflow already satisfies the visual goal. This step is conditional; leaving `ThemedComponents.swift` untouched is valid.

- [ ] **Step 9: Run the native shell checks to verify the workbench form passes**

Run: `bash tools/check_native_shell.sh`
Expected: PASS, including:

- updated `804x520` config frame assertion
- `42`-point field height assertion
- advanced section still collapsed by default
- all pre-existing generation-config behavior tests still green

- [ ] **Step 10: Commit the workbench-form config changes**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift \
  apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift \
  apps/macos-shell/Tests/ManualRuntime/GenerationConfigAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift
git commit -m "feat: convert generation config into a workbench form"
```

If `ThemedComponents.swift` was not touched, omit it from both `git add` and the implementation diff.

## Task 3: Run Full Verification For The Refined Density Pair

**Files:**
- Modify: none unless verification exposes a missing fix

- [ ] **Step 1: Run the native shell verification**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

- [ ] **Step 2: Run the verify script**

Run: `bash tools/test_verify_macos_shell.sh`
Expected: PASS

- [ ] **Step 3: Run the packaged verify flow**

Run: `VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1 ./icu --verify`
Expected: PASS

- [ ] **Step 4: Launch the latest runtime for visual review**

Run: `./icu`
Expected: runtime desktop pet appears, the right-click menu feels lighter relative to the pet, and model config reads as a wider workbench form.

- [ ] **Step 5: Commit only if a verification-only fix was required**

If verification found a last-mile issue that required code changes, stage only those files and commit with:

```bash
git commit -m "fix: polish menu and config workbench density"
```

If no verification fix was needed, do not create an extra commit.
