# Runtime Bubble And Generation Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把桌宠运行时气泡家族、工作室预览结构，以及主题/话术 draft 的本地 contract 校验收敛成稳定实现，确保 `生成 -> 预览 -> 再生成 -> 应用` 不会破坏运行时结构。

**Architecture:** 通过一个共享的 bubble presentation contract 固定 runtime bubble、status chip 和 studio preview 的结构与布局规则，并把 theme/speech 生成结果在进入 preview/apply 前统一经过本地 validator。Avatar tab 保持现有“选择/预览/应用”路径，不在这一轮引入新的持久化 avatar draft schema，只把边界锁死，避免 scope 膨胀。

**Tech Stack:** Swift 5.10, AppKit, SwiftPM, manual runtime tests, shell verification scripts

---

## File Structure

- Create: `apps/macos-shell/Sources/ICUShell/Pet/PetBubblePresentationContract.swift`
  - 定义共享的 bubble family 布局与显示规则，包括尾巴偏移、chip 贴身下侧位置、bubble 激活时的 chip 隐藏策略
- Create: `apps/macos-shell/Sources/ICUShell/Avatar/PetBubblePreviewSceneView.swift`
  - 预览专用 AppKit 视图，复刻运行时 bubble + chip 结构，供主题页和话术页复用
- Create: `apps/macos-shell/Sources/ICUShell/Generation/StudioDraftContractValidator.swift`
  - 对 `ThemePack` 和 `SpeechDraft` 做本地 preview/apply contract 校验
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift`
  - 运行时桌宠视图，改为使用共享 bubble contract，并在 bubble 活跃时隐藏 chip
- Modify: `apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift`
  - 抽出 bubble/chip 共享样式入口，避免 preview 和 runtime 分叉
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
  - 主题/话术预览改为复用 `PetBubblePreviewSceneView`，并在生成预览前调用 validator
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/ThemeGenerationService.swift`
  - 生成主题草稿后接入本地 contract validator，确保进入 preview 的 pack 至少满足 bubble/menu/chip 预览所需 token
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/SpeechGenerationService.swift`
  - 复用 validator 统一约束 preview/apply 前的 speech draft 校验入口
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
  - 新增 runtime bubble contract 和 preview parity 相关断言
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
  - 注册新增 AppKit 手工测试
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemePackManualTests.swift`
  - 增加 theme preview/apply contract validator 的非 AppKit 测试
- Modify: `apps/macos-shell/Tests/ManualRuntime/SpeechGenerationManualTests.swift`
  - 增加 speech draft contract validator 的非 AppKit 测试
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
  - 注册新增非 AppKit 手工测试
- Modify: `tools/check_native_shell.sh`
  - 将新增源文件纳入 runtime/AppKit 手工测试编译清单

## Task 1: Lock The Runtime Bubble Family Contract

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Pet/PetBubblePresentationContract.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Write the failing AppKit tests for the runtime contract**

Add tests that verify:
- the transient bubble tail is offset toward the pet instead of centered
- the persistent status chip lives in the pet’s lower side area, not as a centered bottom pill
- showing a transient bubble hides the status chip while the bubble is visible
- dismissing the transient bubble restores the status chip

Example test shape:

```swift
func testDesktopPetViewHidesStatusChipWhileTransientBubbleIsVisible() throws {
    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 160, height: 160))
    view.setStatusText("专注中")
    view.showTransientMessage("看看远处", duration: 0.05)

    let statusLabel = try requireStatusLabel(in: view)
    let tailView = try requireTransientBubbleTail(in: view)

    try expect(statusLabel.isHidden, "status chip should hide while bubble is active")
    try expect(tailView.frame.midX > tailView.superview!.frame.midX, "tail should be off-center toward the pet")
}
```

- [ ] **Step 2: Run the AppKit manual tests to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL with missing helpers or with assertions showing the current bubble tail is centered and the status chip stays visible during transient bubble display.

- [ ] **Step 3: Implement the shared runtime bubble contract**

Create `PetBubblePresentationContract.swift` with:
- a stable tail alignment rule for runtime bubble scenes
- a stable chip anchor rule for the persistent status chip
- a simple visibility policy such as `showsStatusChipWhenBubbleHidden`

Update `DesktopPetView.swift` to:
- compute bubble tail placement from the shared contract
- place the chip using the shared lower-side offset instead of the current bottom strip assumptions
- hide/show the status chip together with transient bubble lifecycle
- keep copy text behavior unchanged so hidden chip text still refreshes correctly

Extract any shared bubble/chip styling from `DesktopPetView.applyTheme()` into `ThemedComponents.swift` so preview and runtime can share the same visual language.

Example implementation shape:

```swift
enum PetBubblePresentationContract {
    static let statusChipOffset = CGPoint(x: -26, y: -4)
    static let transientTailHorizontalInset: CGFloat = 28
}

func showTransientMessage(_ text: String, duration: TimeInterval = 3) {
    statusLabel.isHidden = true
    transientBubbleLabel.stringValue = text
    layoutTransientBubble()
    transientBubbleContainer.isHidden = false
    transientBubbleTail.isHidden = false
    ...
}
```

- [ ] **Step 4: Run the AppKit manual tests to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS, including the new runtime bubble contract assertions.

- [ ] **Step 5: Commit the runtime contract changes**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Pet/PetBubblePresentationContract.swift \
  apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift \
  apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift \
  tools/check_native_shell.sh
git commit -m "feat: lock desktop pet bubble family contract"
```

## Task 2: Mirror The Runtime Bubble Family In Studio Previews

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Avatar/PetBubblePreviewSceneView.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Write the failing AppKit tests for preview parity**

Add tests that verify:
- the theme tab bubble preview uses a real bubble scene instead of a standalone chip
- the speech tab bubble preview uses the same off-center tail rule as runtime
- the preview scene hides the persistent chip while the transient bubble is the active text layer
- the right-side chrome preview remains menu/form/button only and does not grow a tooltip/notice block

Example test shape:

```swift
func testAvatarSelectorThemeTabUsesRuntimeBubbleScenePreview() throws {
    let controller = makeAvatarSelectorForTesting()
    let contentView = try requireContentView(controller)

    let bubbleScene = try requireBubblePreviewScene(in: contentView)
    try expect(findPreviewStatusChip(in: bubbleScene)?.isHidden == true, "preview chip should hide while preview bubble is active")
    try expect(requirePreviewBubbleTail(in: bubbleScene).frame.midX > bubbleScene.frame.midX, "preview tail should be off-center")
}
```

- [ ] **Step 2: Run the AppKit manual tests to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL because the current preview cards still render a chip-only preview instead of the runtime bubble family structure.

- [ ] **Step 3: Replace ad-hoc preview cards with a shared preview scene**

Create `PetBubblePreviewSceneView.swift` as a focused AppKit view that:
- renders the pet thumbnail
- renders the transient bubble with shared tail placement
- renders the persistent chip in the shared lower-side position
- supports a mode where the chip is hidden while the bubble is active

Update `AvatarSelectorWindowController.swift` to:
- use `PetBubblePreviewSceneView` in both theme and speech tabs
- keep the theme tab’s chrome preview as pure menu/form/button preview
- keep avatar tab responsibilities unchanged
- continue using draft text from `themeBubblePreviewText` and `speechBubblePreviewText`
- consume `PetBubblePresentationContract` instead of duplicating preview-only offsets so runtime and preview stay visually locked together

Example implementation shape:

```swift
let previewScene = PetBubblePreviewSceneView(
    petImage: currentAvatarSummary().flatMap { NSImage(contentsOf: $0.previewURL) },
    bubbleText: themeBubblePreviewText,
    statusText: DesktopPetCopy.statusText(for: .idle),
    showsTransientBubble: true
)
```

- [ ] **Step 4: Run the AppKit manual tests to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS, including preview parity checks for theme and speech tabs.

- [ ] **Step 5: Commit the preview parity changes**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Avatar/PetBubblePreviewSceneView.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift \
  tools/check_native_shell.sh
git commit -m "feat: mirror runtime bubble family in studio previews"
```

## Task 3: Validate Theme And Speech Drafts Before Preview Or Apply

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Generation/StudioDraftContractValidator.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/ThemeGenerationService.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/SpeechGenerationService.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemePackManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/SpeechGenerationManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Write the failing manual tests for preview/apply contract validation**

Add tests that verify:
- a generated theme pack missing bubble/menu preview-critical fields is rejected before preview
- a speech draft with empty required fields is rejected through the shared validator entry point
- failed regenerate calls do not clear the last valid pending draft
- apply still requires a valid preview draft and does not mutate `applied` state on validation failure

Example test shape:

```swift
func testThemeDraftValidatorRejectsPackMissingBubbleTokens() throws {
    var pack = PixelTheme.pack
    pack.tokens.colors.overlayHex = ""

    do {
        try StudioDraftContractValidator.validateThemePreview(pack)
        throw ManualTestFailure(message: "validator should reject incomplete preview theme packs")
    } catch let error as ThemePackError {
        try expect(error == .missingToken("colors.overlayHex"), "overlay token is required for bubble rendering")
    }
}
```

- [ ] **Step 2: Run the non-AppKit manual tests to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL with missing validator entry points or with tests showing incomplete drafts still pass into preview/apply.

- [ ] **Step 3: Implement the shared draft validator and wire it into generate/preview/apply**

Create `StudioDraftContractValidator.swift` with focused entry points such as:
- `validateThemePreview(_ pack: ThemePack) throws`
- `validateSpeechPreview(_ draft: SpeechDraft) throws`

Wire it into:
- `ThemeGenerationService.generateThemeDraft` after `ThemePack.decodeAndValidate`
- `SpeechGenerationService.generateSpeechDraft` after `draft.validate()`
- `AvatarSelectorWindowController.renderThemePreview` and `renderSpeechPreview` before mutating `pendingThemePack` / `pendingSpeechDraft`

Keep state semantics strict:
- if validation fails, do not clear the last valid pending draft
- if validation fails, do not mutate applied summaries
- `regenerate` replaces only the pending draft after validation succeeds
- `pendingThemePack` / `pendingSpeechDraft` stay in controller memory only, while `applied` continues to flow through `ThemeManager` and `CopyOverrideStore`

Example implementation shape:

```swift
let pack = try ThemePack.decodeAndValidate(from: themePackJSON)
try StudioDraftContractValidator.validateThemePreview(pack)
return pack
```

- [ ] **Step 4: Run the non-AppKit and AppKit manual tests to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS, including the new validator and pending-draft lifecycle assertions.

- [ ] **Step 5: Commit the validation and draft lifecycle changes**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Generation/StudioDraftContractValidator.swift \
  apps/macos-shell/Sources/ICUShell/Generation/ThemeGenerationService.swift \
  apps/macos-shell/Sources/ICUShell/Generation/SpeechGenerationService.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemePackManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/SpeechGenerationManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift \
  tools/check_native_shell.sh
git commit -m "feat: validate studio drafts before preview and apply"
```

## Task 4: End-To-End Verify The Bubble Contract And Generation Flow

**Files:**
- Modify as needed from previous tasks

- [ ] **Step 1: Run the full native shell manual verification**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

- [ ] **Step 2: Run launcher verification**

Run: `bash tools/test_verify_macos_shell.sh`
Expected: PASS

- [ ] **Step 3: Run end-to-end shell verification with packaging and runtime smoke enabled**

Run: `VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1 ./icu --verify`
Expected: PASS

- [ ] **Step 4: Manual runtime confirmation**

Run: `./icu`
Expected:
- 桌宠 transient bubble 位于形象上方且尾巴偏向形象一侧
- status chip 位于贴身下侧
- transient bubble 出现时 chip 暂时隐藏，收回后恢复
- 主题页和话术页预览与运行时 bubble family 结构一致
- 右键栏仍是纯菜单，没有提示块

- [ ] **Step 5: Commit any final verification-only adjustments**

```bash
git add -A
git commit -m "test: verify runtime bubble and draft contracts"
```
