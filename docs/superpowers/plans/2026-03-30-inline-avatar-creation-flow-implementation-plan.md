# Inline Avatar Creation Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `新增自定义形象` 从旧 `AvatarWizardWindowController` 迁回 `更换形象 > 桌宠形象动画` tab 的内联创作态，并保持 `优化 prompt -> 生成预览 -> 保存并应用` 的闭环。

**Architecture:** 先用现有 AppKit manual tests 锁定 `browse/create` 双模式 contract，再把旧向导里真正需要的能力迁成 controller 注入的 closures：prompt 优化、三态动作预览生成、persona 初稿、资产保存。`AvatarCoordinator` 负责把 bridge / settings / asset store 接到这些 closures 上，`AvatarSelectorWindowController` 只管理 UI 状态机，不再直接打开旧向导。

**Tech Stack:** Swift 5.10, AppKit, SwiftPM manual runtime tests, `swiftc`-driven verification script, JSON copy catalog, Python avatar bridge

---

## Worktree Notes

- 当前仓库仍在 `master`，且不是独立实现 worktree。
- 开始执行前，先从最新 `master` 创建独立 worktree，再按本计划逐任务推进。
- 已批准 spec：
  - `docs/superpowers/specs/2026-03-30-inline-avatar-creation-flow-design.md`
- 本轮只处理主入口迁移和内联创作态。
- 不顺手处理气泡尾巴、状态栏主题化、prompt 优化 capability 收口。

## File Structure

- Create: `apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift`
  - 定义内联创作态最小模型：`CreationStage`、`InlineAvatarPreviewDraft`、`InlineAvatarSaveRequest`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
  - 增加 `browse/create` 模式、内联创作态 UI、按钮启用规则、生成与保存状态流
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`
  - 去掉旧 `onAddCustom -> presentAvatarWizard()` 主入口，改为向 selector 注入优化 / 预览 / 保存 closures
- Modify: `config/copy/base.json`
  - 增加内联创作态所需文案：模式头、返回按钮、保存按钮、空态 / 错误 / 成功状态等
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
  - 锁定内联创作态 UI contract、优化 / 预览 / 保存行为 contract、取消与门槛规则
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
  - 注册新增 manual tests，确保 `tools/check_native_shell.sh` 会真实执行
- Optional Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarWizardWindowController.swift`
  - 仅在编译或 copy 依赖需要时做最小清理；本轮不以删除整个类为目标

## Task 1: Lock The Inline Create-Mode Shell Contract

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- Modify: `config/copy/base.json`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Write the failing AppKit tests for entering and leaving inline create mode**

Add two new tests in `ThemeAppKitManualTests.swift`:

```swift
func testAvatarSelectorAvatarTabEntersInlineCreateMode() throws
func testAvatarSelectorInlineCreateModeReturnsToBrowseModeWithoutClosing() throws
```

Lock these visible contracts:

- 进入 `桌宠形象动画` tab 后点击 `新增自定义形象`
- 不关闭 selector 窗口
- 渲染 `当前模式：新建形象`
- 渲染 `返回现有形象`
- 渲染 `保存并应用`
- 左侧形象列表仍然存在
- 点击 `返回现有形象` 后回到浏览态，并重新显示 `预览与说明`

Use the existing control helpers:

```swift
try requireButton(in: contentView, title: "桌宠形象动画").performClick(nil)
try requireButton(in: contentView, title: "新增自定义形象").performClick(nil)
_ = try requireLabel(in: contentView, stringValue: "当前模式：新建形象")
_ = try requireButton(in: contentView, title: "返回现有形象")
```

- [ ] **Step 2: Register the new tests in the AppKit manual main**

Add both calls in `ThemeAppKitManualMain.swift` near the existing avatar-selector block:

```swift
try testAvatarSelectorAvatarTabEntersInlineCreateMode()
try testAvatarSelectorInlineCreateModeReturnsToBrowseModeWithoutClosing()
```

- [ ] **Step 3: Run the native shell checks to verify the new shell contract fails**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL because `AvatarSelectorWindowController` still closes and calls the legacy add-custom callback instead of rendering an inline create mode.

- [ ] **Step 4: Add the copy-backed labels needed for the new shell**

Add only the minimal new copy keys under `avatar_studio` in `config/copy/base.json`:

- `create_mode_title`
- `return_to_library_button`
- `save_and_apply_button`
- `create_prompt_title`
- `create_optimized_prompt_title`
- `create_actions_title`
- `create_save_info_title`

Do not add new copy infrastructure. Reuse the controller’s existing `copy("avatar_studio.*", fallback:)` pattern.

- [ ] **Step 5: Implement the browse/create mode shell in `AvatarSelectorWindowController`**

Add a small dedicated model file:

```swift
enum InlineAvatarCreationStage: Equatable {
    case empty
    case drafted
    case previewReady
    case saving
}
```

Then extend the selector with an avatar-tab-local mode:

```swift
private enum AvatarTabMode {
    case browse
    case create
}
```

Implementation rules:

- remove the legacy `onAddCustom` callback from the controller initializer
- clicking `新增自定义形象` only flips `avatarTabMode = .create`
- keep the left list card visible in both modes
- in `create` mode, replace the right detail card with a create workspace shell
- clicking `返回现有形象` restores `browse`
- clicking `handleCancel()` still closes the whole selector window

- [ ] **Step 6: Run the native shell checks to verify the shell contract passes**

Run: `bash tools/check_native_shell.sh`

Expected: PASS for the two new inline-mode tests, while all existing theme / speech / menu / pet tests remain green.

- [ ] **Step 7: Commit the inline create-mode shell**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift \
  config/copy/base.json \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift
git commit -m "feat: add inline avatar creation mode shell"
```

## Task 2: Lock The Inline Create-Mode State Machine

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- Modify: `config/copy/base.json`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Write the failing AppKit tests for optimize, preview gating, and cancel behavior**

Add these tests:

```swift
func testAvatarSelectorInlineCreateModeOptimizesRawPromptAndUsesOptimizedPromptForPreview() throws
func testAvatarSelectorInlineCreateModeRequiresThreePreviewsAndNameBeforeSave() throws
func testAvatarSelectorInlineCreateModeCancelKeepsDraftUnsaved() throws
```

Behavior to lock:

- raw prompt and optimized prompt are separate text views with stable identifiers
- `优化 prompt` receives the raw prompt
- `生成预览` consumes the optimized prompt, not the raw prompt
- `保存并应用` stays disabled until `idle / working / alert` previews all exist and name is non-empty
- `取消` leaves `create` mode without calling save

Use a preview generator stub that records the prompt:

```swift
avatarPreviewGenerator: { prompt in
    generatedPrompts.append(prompt)
    return InlineAvatarPreviewDraft(
        actionImageURLs: [
            "idle": idleURL,
            "working": workingURL,
            "alert": alertURL,
        ],
        suggestedPersona: "稳重、冷静、慢半拍"
    )
}
```

- [ ] **Step 2: Register the new state-machine tests**

Add the three test calls in `ThemeAppKitManualMain.swift`.

- [ ] **Step 3: Run the native shell checks to verify the state-machine tests fail**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL because the create-mode shell still has no optimized-prompt contract, no preview-ready gate, and no save gating.

- [ ] **Step 4: Implement the controller-local creation draft and button rules**

Extend `InlineAvatarCreationModels.swift` with:

```swift
struct InlineAvatarPreviewDraft: Equatable {
    var actionImageURLs: [String: URL]
    var suggestedPersona: String
}

struct InlineAvatarSaveRequest: Equatable {
    var name: String
    var persona: String
    var actionImageURLs: [String: URL]
}
```

Then add controller state:

- `creationRawPrompt`
- `creationOptimizedPrompt`
- `creationPreviewDraft`
- `creationDraftName`
- `creationDraftPersona`
- `creationStage`

UI rules:

- `优化 prompt` always enabled in `create` mode
- `生成预览` enabled only when optimized prompt is non-empty
- `重新生成` enabled after one successful preview
- `保存并应用` enabled only when `creationStage == .previewReady` and name is non-empty
- `取消` always returns to browse mode without persisting

Do not call bridge or asset store directly from the controller. Use injected closures only.

- [ ] **Step 5: Run the native shell checks to verify the state-machine contract passes**

Run: `bash tools/check_native_shell.sh`

Expected: PASS for:

- inline create-mode entry / exit tests
- optimized-prompt / preview input-source tests
- save gating test
- cancel-without-save test

- [ ] **Step 6: Commit the create-mode state machine**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift \
  config/copy/base.json \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift
git commit -m "feat: add inline avatar creation state machine"
```

## Task 3: Wire Bridge-Backed Preview Generation And Save/Applying

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift`
- Modify: `config/copy/base.json`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Write the failing AppKit test for full inline create save/apply flow**

Add:

```swift
func testAvatarSelectorInlineCreateModeSavesAndAppliesGeneratedAvatar() throws
```

Lock this sequence:

- enter `create` mode
- optimize prompt
- generate preview
- fill `名称`
- click `保存并应用`
- save closure receives the three generated URLs and persona draft
- existing `onChoose` path receives the returned avatar ID
- selector closes after successful save/apply

Use stubs like:

```swift
avatarSaveHandler: { request in
    savedRequests.append(request)
    return "custom_capybara"
}
```

and assert:

```swift
try expect(savedRequests.count == 1, "save should run exactly once")
try expect(chosenAvatarIDs == ["custom_capybara"], "saved avatar should be applied through the existing choose path")
```

- [ ] **Step 2: Run the native shell checks to verify the save/apply integration test fails**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL because the controller still lacks bridge-backed preview generation and save/apply wiring.

- [ ] **Step 3: Extend the selector initializer with inline creation closures**

Add injected closures such as:

```swift
avatarPromptOptimizer: ((String) throws -> String)?
avatarPreviewGenerator: ((String) throws -> InlineAvatarPreviewDraft)?
avatarSaveHandler: ((InlineAvatarSaveRequest) throws -> String)?
```

Then implement:

- optimize button -> `avatarPromptOptimizer`
- preview/regenerate button -> `avatarPreviewGenerator`
- auto-fill persona from `suggestedPersona` only when the current persona draft is empty or still equals the previous suggestion
- save button -> `avatarSaveHandler`
- on successful save, call existing `onChoose(savedAvatarID)` and close the selector

- [ ] **Step 4: Wire `AvatarCoordinator` to the existing bridge and stores**

In `presentAvatarPicker()`:

- remove the legacy `onAddCustom` wiring entirely
- pass `avatarPromptOptimizer` as `bridge.optimizePrompt`
- build `avatarPreviewGenerator` by:
  - reading `try settingsStore.loadImageModels()`
  - choosing the first configured image model
  - calling `bridge.generateImage(...)` three times with `idle / working / alert` action suffixes
  - calling `bridge.generatePersona(...)` to build the initial persona suggestion
- build `avatarSaveHandler` by calling:

```swift
try assetStore.saveCustomAvatar(
    name: request.name,
    persona: request.persona,
    generatedActionImageURLs: request.actionImageURLs
)
```

Do not expose model popup or token fields in the new UI. Model selection remains owned by configuration storage, not the create-mode surface.

- [ ] **Step 5: Retire the old wizard from the main flow**

After the selector call site no longer needs it:

- remove `wizardController` from `AvatarCoordinator`
- remove `presentAvatarWizard()` from `AvatarCoordinator`
- keep `AvatarWizardWindowController.swift` compiling for now unless cleanup is trivial

This keeps the old class available for short-term compatibility tests, but removes it from the user-facing path.

- [ ] **Step 6: Run the native shell checks to verify the bridge/save flow passes**

Run: `bash tools/check_native_shell.sh`

Expected: PASS, including the new full save/apply inline creation test.

- [ ] **Step 7: Commit the bridge-backed inline creation flow**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift \
  config/copy/base.json \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift
git commit -m "feat: inline custom avatar creation flow"
```

## Task 4: End-To-End Verification And Runtime Smoke

**Files:**
- Modify as needed from previous tasks only

- [ ] **Step 1: Run the native shell manual verification**

Run: `bash tools/check_native_shell.sh`

Expected: PASS

- [ ] **Step 2: Run the full lightweight verification entrypoint**

Run: `./icu --verify`

Expected:

- `swift build` passes
- manual runtime checks pass
- if Xcode is still inactive, the script explicitly prints `Skipping swift test because Xcode is not active.`

- [ ] **Step 3: Manual UI smoke-check the new main flow**

Run: `./icu`

Expected:

- 右键桌宠 -> `更换形象`
- 进入 `桌宠形象动画`
- 点击 `新增自定义形象`
- 当前窗口进入内联创作态，不弹旧向导
- 成功完成一次 `优化 prompt -> 生成预览 -> 保存并应用`
- 保存成功后桌宠立即切换到新形象

- [ ] **Step 4: Commit any final cleanup after verification**

```bash
git status --short
```

If only planned files changed and verification is green:

```bash
git add <remaining planned files>
git commit -m "test: cover inline avatar creation flow"
```

If no cleanup was needed, skip this commit.
