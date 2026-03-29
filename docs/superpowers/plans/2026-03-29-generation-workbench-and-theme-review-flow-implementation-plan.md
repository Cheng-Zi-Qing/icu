# Generation Workbench And Theme Review Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把模型配置页收敛成字段主导的工作台，并把 `更换形象 > 主题风格` 改成 `优化 prompt -> 预览优化稿 -> 应用主题` 的双层审阅链路。

**Architecture:** 先用现有 AppKit manual tests 锁定两类新 contract，再分别在 `GenerationConfigWindowController` 和 `AvatarSelectorWindowController` 做局部重构。`主题风格` 的 prompt 优化直接复用现有 `AvatarBuilderBridge.optimizePrompt()`，通过 `AvatarCoordinator` 注入到 selector，不把 bridge 塞进 `GenerationCoordinator`。所有新增用户可见文案继续落到 `config/copy/base.json`。

**Tech Stack:** Swift 5.10, AppKit, SwiftPM manual runtime tests, `swiftc`-driven verification script, JSON copy catalog

---

## Worktree Notes

- 当前仓库分支是 `master`，未处于独立实现 worktree。
- 进入实现前，先从最新 `master` 创建独立 worktree，再按本计划执行。
- 已批准 spec：
  - `docs/superpowers/specs/2026-03-29-generation-workbench-and-theme-review-flow-design.md`
- 本轮只实现两个已批准子问题：
  - 模型配置页字段主导工作台
  - 主题风格双层 prompt 审阅流
- 不顺手改 `桌宠形象动画` 和 `话术` tab 的交互闭环。

## File Structure

- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
  - 压缩配置页 header，固定单行说明，强化首屏三项核心字段的视觉占比
- Modify: `apps/macos-shell/Sources/ICUShell/Copy/UserVisibleCopyKey.swift`
  - 更新生成配置页默认标题 / 副标题等默认文案
- Modify: `config/copy/base.json`
  - 落地生成配置页的新短文案，以及主题风格新按钮 / 状态 / 空态文案
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`
  - 向 selector 注入主题 prompt 优化 closure，直接复用 `AvatarBuilderBridge.optimizePrompt`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
  - 新增主题 tab 的双 prompt 状态、专属动作栏、禁用规则、预览失效规则
- Modify: `apps/macos-shell/Tests/ManualRuntime/GenerationConfigAppKitManualTests.swift`
  - 更新配置页的 workbench density / copy / viewport contract
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
  - 更新主题 tab 的按钮、优化链路、preview/apply state 约束
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
  - 确保新的 manual tests 被 `tools/check_native_shell.sh` 实际执行
- Optional Modify: `apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift`
  - 仅当 controller-local 约束无法让输入框达到目标工作台比例时再调整共享 text-field 样式

## Task 1: Compress Generation Config Into A Field-Dominant Workbench

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Copy/UserVisibleCopyKey.swift`
- Modify: `config/copy/base.json`
- Modify: `apps/macos-shell/Tests/ManualRuntime/GenerationConfigAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
- Optional Modify: `apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift`

- [ ] **Step 1: Tighten the visible-copy contract to the shorter workbench wording**

Update the copy-backed test in `GenerationConfigAppKitManualTests.swift` so the default window language reflects the field-first workbench instead of the older explanatory page. Keep the override test shape, but change the expected visible strings to the shorter title/subtitle pair:

```swift
_ = try requireLabel(in: contentView, stringValue: "模型工作台")
_ = try requireLabel(in: contentView, stringValue: "这里只配模型；生成、预览、应用都在更换形象页。")
```

Mirror those defaults in:

- `UserVisibleCopyKey.generationConfigWindowTitle`
- `UserVisibleCopyKey.generationConfigWindowSubtitle`
- `config/copy/base.json`

- [ ] **Step 2: Add a first-viewport density test for the three primary fields**

Keep the existing `42pt` field-height contract, and add one new layout assertion that catches “说明太多、字段下沉” regressions. Use the visible `provider` field position after layout to ensure the first editable row starts high enough in the card:

```swift
func testGenerationConfigWindowKeepsCoreFieldsInUpperViewportBand() throws {
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
    contentView.layoutSubtreeIfNeeded()

    let providerField = try requireTextField(in: contentView, placeholder: "provider，如 ollama / huggingface / openai-compatible")
    let fieldFrame = providerField.convert(providerField.bounds, to: contentView)
    let topGap = contentView.bounds.maxY - fieldFrame.maxY

    try expect(topGap <= 170, "generation config should keep the first core field in the upper viewport band")
}
```

This gives the implementer a concrete geometry target without hard-coding every intermediate view frame.

- [ ] **Step 3: Wire the new density test into `ThemeAppKitManualMain`**

Add this call near the existing generation-config block:

```swift
try testGenerationConfigWindowKeepsCoreFieldsInUpperViewportBand()
```

Do not remove the existing `compact frame`, `thicker field density`, and `advanced section` coverage.

- [ ] **Step 4: Run the native shell checks to verify the new workbench expectations fail**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL because the current inner title/header stack is still too tall, and the new copy expectations do not match.

- [ ] **Step 5: Implement the field-dominant workbench layout in `GenerationConfigWindowController`**

Keep the `804x520` window and `42pt` fields, but compress the header and detail stack locally:

```swift
private enum Layout {
    static let windowSize = NSSize(width: 804, height: 520)
    static let contentInset: CGFloat = 16
    static let rootSpacing: CGFloat = 6
    static let contentSpacing: CGFloat = 6
    static let tabSpacing: CGFloat = 8
    static let tabHeight: CGFloat = 30
    static let fieldRowSpacing: CGFloat = 10
    static let labelSpacing: CGFloat = 4
    static let fieldHeight: CGFloat = 42
}
```

Concrete implementation rules:

- Make the outer window subtitle single-line and truncating:

```swift
subtitleLabel.maximumNumberOfLines = 1
subtitleLabel.lineBreakMode = .byTruncatingTail
```

- In `buildCapabilityDetail(for:)`, stop using `AvatarPanelTheme.makeTitleLabel(kind.title)` for the inner card title. Replace it with a smaller accent label so the card reads like a workbench section, not a second page header.
- Keep the one-line detail description, but force it to truncate instead of expanding vertically.
- Keep `provider / model / base_url` in the always-visible section and `auth / options` in the folded advanced section.
- Prefer controller-local spacing changes before touching `ThemedComponents.swift`.

- [ ] **Step 6: Only touch `ThemedComponents.swift` if controller-local constraints still leave the fields visually too thin**

If the `42pt` text fields still render too small after the controller changes, minimally adjust the editable text-field content insets in `ThemedComponents.swift`. Do not restyle buttons, cards, or global panel spacing in this task.

- [ ] **Step 7: Run the native shell checks to verify the workbench layout passes**

Run: `bash tools/check_native_shell.sh`

Expected: PASS, including:

- updated generation-config copy expectations
- `testGenerationConfigWindowUsesCompactFrame`
- `testGenerationConfigWindowUsesThickerFieldDensity`
- `testGenerationConfigWindowKeepsCoreFieldsInUpperViewportBand`

- [ ] **Step 8: Commit the generation workbench changes**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift \
  apps/macos-shell/Sources/ICUShell/Copy/UserVisibleCopyKey.swift \
  config/copy/base.json \
  apps/macos-shell/Tests/ManualRuntime/GenerationConfigAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift
git commit -m "feat: tighten generation config into field-first workbench"
```

If `ThemedComponents.swift` was touched, include it in `git add`.

## Task 2: Rebuild Theme Style Generation Into A Dual-Prompt Review Flow

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- Modify: `config/copy/base.json`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Replace the theme-tab button contract with review-flow actions**

Update `testAvatarSelectorWindowUsesStudioTabsAndThemeBubblePreviewByDefault()` so the theme tab no longer expects the generic action bar. The default theme tab should now expose:

```swift
_ = try requireButton(in: contentView, title: "主题风格")
_ = try requireLabel(in: contentView, stringValue: "当前已应用主题")
_ = try requireLabel(in: contentView, stringValue: "原始 prompt")
_ = try requireLabel(in: contentView, stringValue: "优化后 prompt")
_ = try requireActionButton(in: contentView, title: "优化 prompt")
_ = try requireActionButton(in: contentView, title: "重新优化")
_ = try requireActionButton(in: contentView, title: "预览效果")
_ = try requireActionButton(in: contentView, title: "应用主题")

try expect(findButton(in: contentView, title: "生成预览") == nil, "theme tab should not reuse the generic preview button")
try expect(findButton(in: contentView, title: "重新生成") == nil, "theme tab should not reuse the generic regenerate button")
```

- [ ] **Step 2: Rewrite the existing theme preview/apply tests around optimized prompts**

Update the two existing tests rather than creating parallel variants:

- `testAvatarSelectorThemeTabGeneratesDraftBeforeApplyingTheme`
- `testAvatarSelectorThemeTabRequiresPreviewBeforeApply`

New behavior to lock in:

- optimizer closure receives the raw prompt
- preview closure receives the optimized prompt
- apply still refuses to run before preview succeeds

Give the theme text views explicit identifiers so the tests can target them reliably:

```swift
themePromptView.identifier = NSUserInterfaceItemIdentifier("themeRawPrompt")
themeOptimizedPromptView.identifier = NSUserInterfaceItemIdentifier("themeOptimizedPrompt")
```

Then use a helper in the manual test to find them and drive the state machine:

```swift
let rawPromptView = try requireTextView(in: contentView, identifier: "themeRawPrompt")
rawPromptView.string = "cozy pixel desktop pet"
rawPromptView.didChangeText()

try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
RunLoop.current.run(until: Date().addingTimeInterval(0.05))

try requireActionButton(in: contentView, title: "预览效果").performClick(nil)
RunLoop.current.run(until: Date().addingTimeInterval(0.05))

try expect(optimizedPrompts == ["cozy pixel desktop pet"], "theme optimizer should receive the raw prompt")
try expect(generatedPrompts == ["pixel-art shell with tighter menu"], "theme preview should use the optimized prompt, not the raw prompt")
```

- [ ] **Step 3: Add a new regression test that editing the optimized prompt invalidates apply**

Add:

```swift
func testAvatarSelectorThemeTabInvalidatesApplyWhenOptimizedPromptChanges() throws {
    let previewURL = try makeTinyPNG()
    let generatedPack = makeAppKitTestThemePack(id: "generated_preview_theme")
    var generatedPrompts: [String] = []
    var appliedPackIDs: [String] = []

    let controller = AvatarSelectorWindowController(
        avatars: [
            AvatarSummary(
                id: "capybara",
                name: "水豚",
                style: "像素",
                previewURL: previewURL,
                traits: "稳重",
                tone: "冷静"
            )
        ],
        currentAvatarID: "capybara",
        themePromptOptimizer: { _ in "optimized theme prompt" },
        themeDraftGenerator: { prompt in
            generatedPrompts.append(prompt)
            return generatedPack
        },
        themeDraftApplier: { pack in
            appliedPackIDs.append(pack.meta.id)
        },
        onChoose: { _ in },
        onAddCustom: {},
        onClose: {}
    )

    guard let contentView = controller.window?.contentView else {
        throw TestFailure(message: "selector content view should exist")
    }

    let rawPromptView = try requireTextView(in: contentView, identifier: "themeRawPrompt")
    rawPromptView.string = "cozy pixel desktop pet"
    rawPromptView.didChangeText()
    try requireActionButton(in: contentView, title: "优化 prompt").performClick(nil)
    try requireActionButton(in: contentView, title: "预览效果").performClick(nil)

    let optimizedPromptView = try requireTextView(in: contentView, identifier: "themeOptimizedPrompt")
    optimizedPromptView.string = "edited optimized theme prompt"
    optimizedPromptView.didChangeText()

    try requireActionButton(in: contentView, title: "应用主题").performClick(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))

    try expect(appliedPackIDs.isEmpty, "theme apply should be invalidated when the optimized prompt changes after preview")
}
```

Also add its call to `ThemeAppKitManualMain.main()`.

- [ ] **Step 4: Run the native shell checks to verify the new theme-flow expectations fail**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL because the selector still has a single theme prompt, generic preview/regenerate buttons, and no optimize step.

- [ ] **Step 5: Thread the theme prompt optimizer through `AvatarCoordinator` into `AvatarSelectorWindowController`**

Do not route prompt optimization through `GenerationCoordinator`. Reuse the existing bridge layer directly from `AvatarCoordinator`:

```swift
let controller = AvatarSelectorWindowController(
    avatars: avatars,
    currentAvatarID: try settingsStore.loadCurrentAvatarID(),
    themePromptOptimizer: { [bridge] prompt in
        try bridge.optimizePrompt(prompt)
    },
    themeDraftGenerator: generationCoordinator.map { coordinator in
        { prompt in
            try coordinator.generateThemeDraft(from: prompt)
        }
    },
    // ...
)
```

This keeps the bridge dependency in the avatar flow where it already lives.

- [ ] **Step 6: Replace the theme tab’s single-prompt state with a dual-review state machine**

In `AvatarSelectorWindowController.swift`, add the minimal new state:

```swift
private let themeOptimizedPromptView = NSTextView()
private let themePromptOptimizer: ((String) throws -> String)?

private var themeRawPrompt = ""
private var themeOptimizedPrompt = ""
private var lastPreviewedThemePrompt: String?
```

Keep `pendingThemePack`, but treat it as valid only when:

- `lastPreviewedThemePrompt` exists
- `lastPreviewedThemePrompt == normalizedOptimizedPrompt`

Concrete controller changes:

- `configureTextViews()` should configure both theme text views and assign explicit identifiers
- `buildThemeTabView()` should render:
  - applied theme summary
  - raw prompt section
  - optimized prompt section
  - draft summary
  - preview cards
  - a theme-only action bar
- Add `makeThemeActionBar()` with:
  - `优化 prompt`
  - `重新优化`
  - `预览效果`
  - `应用主题`
- `handleGeneratePreview` / `handleRegeneratePreview` should stop serving the theme tab; add dedicated theme handlers instead
- `renderThemePreview(regenerated:)` must read `themeOptimizedPrompt`, never `themeRawPrompt`
- Any successful optimize or any edit to `themeOptimizedPromptView` must clear:

```swift
pendingThemePack = nil
lastPreviewedThemePrompt = nil
```

- [ ] **Step 7: Route theme optimization failures through friendly user-facing copy and add the new text catalog keys**

In `AvatarSelectorWindowController.showGenerationError(_:)`, prefer:

```swift
if error is AvatarBuilderBridgeError {
    statusLabel.stringValue = UserFacingErrorCopy.avatarMessage(for: error)
} else {
    statusLabel.stringValue = error.localizedDescription
}
```

Add the new theme-tab copy keys to `config/copy/base.json`, for example:

- `theme_studio.raw_prompt_title`
- `theme_studio.optimized_prompt_title`
- `theme_studio.optimized_prompt_hint`
- `theme_studio.optimize_button`
- `theme_studio.reoptimize_button`
- `theme_studio.preview_button`
- `theme_studio.apply_button`
- `theme_studio.optimize_ready_status`
- `theme_studio.preview_requires_optimized_status`
- `theme_studio.optimized_status`
- `theme_studio.reoptimized_status`
- `theme_studio.optimized_placeholder`

Do not leave any new raw string key out of `base.json`, because `testBaseCopyCatalogContainsAllSourceReferencedKeys()` will catch it.

- [ ] **Step 8: Run the native shell checks to verify the reviewed theme flow passes**

Run: `bash tools/check_native_shell.sh`

Expected: PASS, including:

- updated theme tab button contract
- updated preview-before-apply contract
- optimized-prompt routing test
- optimized-prompt edit invalidation test
- base copy catalog integrity

- [ ] **Step 9: Commit the theme review-flow changes**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift \
  config/copy/base.json \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift
git commit -m "feat: add reviewed prompt flow for theme generation"
```

## Final Verification

- [ ] Run: `bash tools/check_native_shell.sh`
  - Expected: PASS
- [ ] Run: `git status --short`
  - Expected: clean working tree after the two commits above
- [ ] Manually launch the app and inspect the two changed surfaces:
  - `模型配置` 首屏是否明显由输入区主导
  - `更换形象 > 主题风格` 是否严格遵循 `优化 prompt -> 预览效果 -> 应用主题`
