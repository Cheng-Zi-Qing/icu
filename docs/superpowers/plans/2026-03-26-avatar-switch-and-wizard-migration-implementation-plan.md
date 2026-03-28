# Avatar Switch And Wizard Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Swift shell 恢复“更换形象”和“新增自定义形象”能力，并保持 Swift 作为默认 UI 路径。

**Architecture:** 通过 `AvatarCoordinator` 收敛右键菜单与菜单栏入口，新增 `AvatarCatalog` 与 `AvatarSettingsStore` 管理形象清单和当前形象配置。Swift 原生选择器与向导负责 UI，底层提示词优化、出图和 persona 生成继续通过单一 Python bridge 调用 `builder/*`，结果由 Swift 落盘并热刷新到当前桌宠。

**Tech Stack:** Swift, AppKit, Foundation, Python, Bash, JSON, Ollama, Hugging Face

---

## File Map

### New files

- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCatalog.swift`
  扫描 Application Support / repo 两处 `assets/pets`，产出可显示的形象列表和元数据。
- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSettingsStore.swift`
  读写 `config/settings.json` 中的 `avatar.current_id`。
- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarBuilderBridge.swift`
  统一封装 Swift 到 `tools/avatar_builder_bridge.py` 的命令调用、JSON 解析与错误处理。
- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`
  统一处理菜单入口、选择器、向导、保存设置与刷新当前桌宠。
- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
  Swift 原生形象选择器面板。
- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarWizardWindowController.swift`
  Swift 原生三步式自定义形象向导。
- `apps/macos-shell/Tests/ManualRuntime/AvatarCatalogManualTests.swift`
  验证形象扫描、目录优先级与列表数据。
- `apps/macos-shell/Tests/ManualRuntime/AvatarSettingsStoreManualTests.swift`
  验证当前形象读写与回退逻辑。
- `apps/macos-shell/Tests/ManualRuntime/AvatarBuilderBridgeManualTests.swift`
  使用 stub bridge 验证 JSON 契约和错误处理。
- `tools/avatar_builder_bridge.py`
  Python bridge，向 Swift 暴露 `optimize-prompt` / `list-image-models` / `generate-image` / `generate-persona`。
- `tools/test_avatar_builder_bridge.sh`
  验证 Python bridge 的基本命令分发与 JSON 输出。

### Modified files

- `apps/macos-shell/Sources/ICUShell/AppDelegate.swift`
  注入 `AvatarCoordinator`，恢复菜单栏“更换形象”入口。
- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetMenuModel.swift`
  为右键菜单增加“更换形象”动作。
- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift`
  支持运行时切换 `petID` 并立即重载图片。
- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift`
  将菜单动作交给 `AvatarCoordinator`，提供当前桌宠刷新入口。
- `apps/macos-shell/Sources/ICUShell/Runtime/PetAssetLocator.swift`
  视需要暴露更稳定的候选目录能力，避免扫描逻辑与渲染逻辑分叉。
- `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
  把新增手工 runtime 测试纳入轻量验证入口。
- `tools/check_native_shell.sh`
  将新增 Avatar 源文件与手工测试编译进轻量验证链路。
- `builder/vision_generator.py`
  让图像生成真正接受桥接层传入的模型 ID / URL，而不是写死模型。
- `README.md`
  记录 Swift shell 中的形象切换与自定义向导入口。
- `README_CN.md`
  记录中文使用说明。
- `findings.md`
  记录本次迁移边界与 builder bridge 约束。
- `progress.md`
  记录实现与验收结果。
- `task_plan.md`
  更新当前阶段与可本地测试项。

## Task 1: Add Failing Manual Tests For Avatar Catalog And Settings

**Files:**
- Create: `apps/macos-shell/Tests/ManualRuntime/AvatarCatalogManualTests.swift`
- Create: `apps/macos-shell/Tests/ManualRuntime/AvatarSettingsStoreManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Write the failing test for scanning repo avatar metadata**

```swift
func testAvatarCatalogListsRepoAvatar() throws {
    let root = try makeTemporaryDirectory()
    let petDir = root
        .appendingPathComponent("assets", isDirectory: true)
        .appendingPathComponent("pets", isDirectory: true)
        .appendingPathComponent("capybara", isDirectory: true)
    try writeFixtureFile(at: petDir.appendingPathComponent("base.png"))
    try writeFixtureFile(
        at: petDir.appendingPathComponent("config.json"),
        contents: #"{"id":"capybara","name":"卡皮巴拉","style":"16-bit 像素风"}"#
    )

    let catalog = AvatarCatalog(repoRootURL: root, appAssetsRootURL: nil)
    let avatars = try catalog.loadAvatars()

    try expect(avatars.map(\.id) == ["capybara"], "catalog should list repo avatar")
}
```

- [ ] **Step 2: Write the failing test for `settings.json` current avatar persistence**

```swift
func testAvatarSettingsStorePersistsCurrentAvatarID() throws {
    let root = try makeTemporaryDirectory()
    let store = AvatarSettingsStore(repoRootURL: root)

    try store.saveCurrentAvatarID("seal")

    let current = try store.loadCurrentAvatarID()
    try expect(current == "seal", "settings store should persist current avatar")
}
```

- [ ] **Step 3: Run the manual runtime harness and verify it fails for missing Avatar types**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL with missing `AvatarCatalog` / `AvatarSettingsStore` symbols.

## Task 2: Implement Avatar Catalog And Settings Store

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCatalog.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSettingsStore.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Runtime/PetAssetLocator.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Implement minimal avatar metadata model and catalog**

```swift
struct AvatarSummary: Equatable {
    var id: String
    var name: String
    var style: String
    var previewURL: URL
}

struct AvatarCatalog {
    func loadAvatars() throws -> [AvatarSummary] { ... }
}
```

- [ ] **Step 2: Implement `AvatarSettingsStore` to read/write `config/settings.json`**

```swift
final class AvatarSettingsStore {
    func loadCurrentAvatarID() throws -> String?
    func saveCurrentAvatarID(_ id: String) throws
}
```

- [ ] **Step 3: Re-run the manual runtime harness**

Run: `bash tools/check_native_shell.sh`

Expected: PASS for catalog/settings tests, or fail only on the next missing bridge layer if you already added more tests.

## Task 3: Add Failing Bridge Contract Tests And Python Bridge

**Files:**
- Create: `apps/macos-shell/Tests/ManualRuntime/AvatarBuilderBridgeManualTests.swift`
- Create: `tools/avatar_builder_bridge.py`
- Create: `tools/test_avatar_builder_bridge.sh`
- Create: `tools/testdata/avatar_builder_bridge_stub.py`
- Create: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarBuilderBridge.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
- Modify: `tools/check_native_shell.sh`
- Modify: `builder/vision_generator.py`

- [ ] **Step 1: Write the failing bridge contract test using a stub command**

```swift
func testAvatarBuilderBridgeParsesOptimizePromptJSON() throws {
    let bridge = AvatarBuilderBridge(
        executable: URL(fileURLWithPath: "/abs/path/to/tools/testdata/avatar_builder_bridge_stub.py")
    )

    let prompt = try bridge.optimizePrompt("一只淡定的水豚")
    try expect(prompt.contains("pixel art"), "bridge should parse optimized prompt from JSON")
}
```

- [ ] **Step 2: Run the manual runtime harness and verify it fails because the bridge is missing**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL with missing `AvatarBuilderBridge`.

- [ ] **Step 3: Implement the Swift bridge with JSON stdout parsing and non-zero exit handling**

```swift
struct AvatarBuilderBridge {
    func optimizePrompt(_ text: String) throws -> String { ... }
    func listImageModels() throws -> [BridgeImageModel] { ... }
    func generateImage(...) throws -> URL { ... }
    func generatePersona(_ text: String) throws -> String { ... }
}
```

- [ ] **Step 4: Implement `tools/avatar_builder_bridge.py` with four commands**

Required commands:
- `optimize-prompt`
- `list-image-models`
- `generate-image`
- `generate-persona`

- [ ] **Step 5: Patch `builder/vision_generator.py` so selected model ID/URL is actually honored**

Run: `bash tools/test_avatar_builder_bridge.sh`

Expected: PASS

- [ ] **Step 6: Re-run the manual runtime harness**

Run: `bash tools/check_native_shell.sh`

Expected: PASS

## Task 4: Add Failing Runtime Switch Tests And Implement Refresh Path

**Files:**
- Modify: `apps/macos-shell/Tests/ManualRuntime/AvatarSettingsStoreManualTests.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/AppDelegate.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetMenuModel.swift`

- [ ] **Step 1: Write the failing test for switching current avatar ID**

```swift
func testAvatarSettingsStoreUpdatesCurrentAvatarID() throws {
    let root = try makeTemporaryDirectory()
    let store = AvatarSettingsStore(repoRootURL: root)

    try store.saveCurrentAvatarID("horse")

    try expect(try store.loadCurrentAvatarID() == "horse", "current avatar should update")
}
```

- [ ] **Step 2: Run the manual runtime harness and verify the new test fails if needed**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL only if the new behavior is not yet implemented.

- [ ] **Step 3: Add menu actions and coordinator wiring**

Implementation requirements:
- 右键菜单增加“更换形象”
- 菜单栏增加“更换形象”
- 两处入口都走 `AvatarCoordinator`

- [ ] **Step 4: Add runtime refresh support to `DesktopPetView`**

```swift
func setPetID(_ petID: String) {
    self.petID = petID
    setWorkState(currentWorkState)
}
```

- [ ] **Step 5: Re-run the manual runtime harness**

Run: `bash tools/check_native_shell.sh`

Expected: PASS

## Task 5: Build Swift Selector And Wizard UI

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarWizardWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`
- Modify: `README.md`
- Modify: `README_CN.md`

- [ ] **Step 1: Add the minimal selector UI that lists avatars and returns a chosen ID**

Implementation requirements:
- preview
- style label
- persona summary
- choose / cancel / add custom avatar buttons

- [ ] **Step 2: Add the minimal wizard shell with three steps**

Implementation requirements:
- 文本描述与优化提示词
- 选择图像模型并生成 `idle` / `working` / `alert`
- 生成人设、填写名称并保存

- [ ] **Step 3: Implement save-and-use flow**

Implementation requirements:
- Swift 写入 `assets/pets/<pet_id>/...`
- Swift 写入 `config.json`
- Swift 更新 `settings.json`
- 保存成功后立即切到新形象

- [ ] **Step 4: Launch the app and manually validate the selector and wizard**

Run: `bash ./icu`

Expected:
- 菜单栏可打开选择器
- 右键菜单可打开选择器
- 现有形象切换立即生效
- 新增自定义形象后立即可用

## Task 6: Update Tracking Files And Final Verification

**Files:**
- Modify: `findings.md`
- Modify: `progress.md`
- Modify: `task_plan.md`
- Test: `bash tools/check_native_shell.sh`
- Test: `bash ./icu --verify`
- Test: `bash tools/test_icu_launcher.sh`
- Test: `bash tools/test_avatar_builder_bridge.sh`

- [ ] **Step 1: Record the migration boundary**

Capture:
- Swift 恢复形象切换和自定义形象向导
- 生成链仍经由 Python bridge
- 边缘吸附 / 自动隐藏留到下一批

- [ ] **Step 2: Record verification results**

Capture:
- 手工 runtime 验证
- bridge 脚本验证
- `./icu --verify`
- 本地 smoke test

- [ ] **Step 3: Run final verification commands**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

Run: `bash tools/test_avatar_builder_bridge.sh`
Expected: PASS

Run: `bash ./icu --verify`
Expected: PASS

Run: `bash tools/test_icu_launcher.sh`
Expected: PASS

## Notes

- 当前环境下 `swift test --package-path apps/macos-shell` 仍不作为默认验证链路，因为缺少 Xcode / `XCTest`。
- 当前推荐通过 stub bridge 做契约验证，避免手工测试依赖 Ollama 和 `HF_TOKEN`。
- 本计划恢复的是“形象切换与自定义形象向导”；边缘吸附、自动隐藏和更复杂窗口行为不包含在这次实现里。
