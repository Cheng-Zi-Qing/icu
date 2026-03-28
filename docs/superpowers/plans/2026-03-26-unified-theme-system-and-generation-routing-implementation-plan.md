# Unified Theme System And Generation Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Swift shell 建立统一主题底座，默认落地 `PixelTheme`，替换系统右键/状态栏菜单为可主题化弹层，并新增原生生成配置页与第一条 `vibe -> ThemePack -> apply theme` 真实消费链。

**Architecture:** 以数据驱动的 `ThemePack` + `ThemeManager` 作为运行时主题核心，把现有 avatar 面板样式提升为全局主题组件层。菜单体系通过共享的浮层控制器替换 `NSMenu`，业务动作继续复用现有菜单 model。生成链保持 Swift 原生启动路径不变，新增原生能力配置存储和 HTTP 路由，直接消费 `文本描述` 与 `代码生成` 两类能力配置生成并应用主题。

**Tech Stack:** Swift, AppKit, Foundation, URLSession, JSON, Bash

---

## File Map

### New files

- `apps/macos-shell/Sources/ICUShell/Theme/ThemeDefinition.swift`
  定义主题 token、组件 token、运行时主题接口和主题变更通知名。
- `apps/macos-shell/Sources/ICUShell/Theme/ThemePack.swift`
  定义 `ThemePack` contract、校验逻辑和 JSON 编解码。
- `apps/macos-shell/Sources/ICUShell/Theme/PixelTheme.swift`
  内建默认像素风主题，承接当前 `AvatarPanelTheme` 的视觉基线。
- `apps/macos-shell/Sources/ICUShell/Theme/ThemeManager.swift`
  负责加载当前主题、持久化生成后的主题包、回退到 `pixel_default`、广播主题切换。
- `apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift`
  提供窗口、面板、按钮、输入框、文本区、分节标题、状态标签等统一 AppKit 主题化 helper。
- `apps/macos-shell/Sources/ICUShell/Menu/ThemedMenuPanel.swift`
  定义自绘菜单面板、菜单行、分隔线和 section 渲染。
- `apps/macos-shell/Sources/ICUShell/Menu/FloatingPanelController.swift`
  提供共享浮层宿主、外部点击关闭、`Esc` 关闭和窗口层级管理。
- `apps/macos-shell/Sources/ICUShell/Menu/ContextMenuPanelController.swift`
  桌宠右键弹层控制器，负责锚定鼠标点击位置并分发菜单动作。
- `apps/macos-shell/Sources/ICUShell/Menu/StatusItemMenuModel.swift`
  纯数据状态栏菜单模型，定义“显示桌宠 / 更换形象 / 生成配置 / 退出”等动作和 section。
- `apps/macos-shell/Sources/ICUShell/Menu/StatusMenuPanelController.swift`
  状态栏按钮弹层控制器，负责锚定 `NSStatusItem.button` 下方。
- `apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift`
  定义 `text_description / animation_avatar / code_generation` 能力配置、provider enum、auth/options 结构。
- `apps/macos-shell/Sources/ICUShell/Generation/GenerationSettingsStore.swift`
  读写 repo 根目录 `config/settings.json` 中的 `generation.*` 与 `theme.current_id`，且保留现有 `avatar` / `ai` / `timers` 等 sibling 数据。
- `apps/macos-shell/Sources/ICUShell/Generation/GenerationHTTPClient.swift`
  原生 Swift HTTP client，按 provider 调用 Ollama 与 OpenAI-compatible 接口并返回文本/JSON。
- `apps/macos-shell/Sources/ICUShell/Generation/ThemeGenerationService.swift`
  打通 `vibe -> StyleIntent -> ThemePack -> validate -> persist -> apply` 的第一条真实路由。
- `apps/macos-shell/Sources/ICUShell/Generation/GenerationCoordinator.swift`
  收敛“打开生成配置页”“生成并应用主题”“恢复默认像素风”等应用级入口，避免 `AppDelegate` 与 `DesktopPetWindowController` 直接持有过多窗口逻辑。
- `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
  原生 AppKit 配置窗口，管理三类能力配置与最小主题生成区。
- `apps/macos-shell/Tests/ManualRuntime/ThemePackManualTests.swift`
  验证 `ThemePack` 校验、`ThemeManager` 持久化和回退逻辑。
- `apps/macos-shell/Tests/ManualRuntime/GenerationSettingsManualTests.swift`
  验证 `generation` 配置与 `theme.current_id` 的读写不会破坏现有 `settings.json` 结构。
- `apps/macos-shell/Tests/ManualRuntime/ThemeGenerationManualTests.swift`
  使用 stub HTTP transport 验证主题生成链的模型路由顺序、错误处理与主题激活行为。

### Modified files

- `apps/macos-shell/Sources/ICUShell/AppDelegate.swift`
  注入 `ThemeManager` 与 `GenerationCoordinator`，替换状态栏 `NSMenu` 绑定为自绘弹层入口。
- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarPanelTheme.swift`
  退化为兼容层或直接改为调用全局主题组件，避免继续持有局部硬编码样式。
- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
  改为消费统一主题组件，消除直接依赖局部颜色/字体常量。
- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarWizardWindowController.swift`
  改为消费统一主题组件，并让错误/状态展示复用统一主题样式。
- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetMenuModel.swift`
  从单一扁平 `items` 补齐 section 语义，并增加“生成配置”入口。
- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift`
  让桌宠底部状态条、提醒文案样式接入全局主题 token。
- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift`
  用 `ContextMenuPanelController` 替换 `NSMenu.popUpContextMenu(...)`，接入新的菜单动作和生成配置入口。
- `apps/macos-shell/Sources/ICUShell/Runtime/AppPaths.swift`
  增加 `themesDirectory` 目录，供运行时持久化 `ThemePack` 使用。
- `apps/macos-shell/Tests/ManualRuntime/MenuModelManualTests.swift`
  扩展到新菜单 section 和“生成配置”入口的纯数据验证。
- `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
  把新增主题/生成相关手工运行时测试纳入统一轻量验证入口。
- `tools/check_native_shell.sh`
  编译新增 manual runtime tests，并继续完成 AppKit shell 编译校验。
- `tools/verify_macos_shell.sh`
  继续走 `swift build -> manual runtime checks -> optional swift test`，不引入 Xcode 硬依赖。
- `tools/test_verify_macos_shell.sh`
  如果 `verify_macos_shell.sh` 输出或流程发生变化，同步更新 stub 断言。
- `README.md`
  记录新的生成配置页入口与主题生成链使用方式。
- `README_CN.md`
  记录中文说明与本地验证方式。

## Task 1: Add Failing Manual Tests For Theme Pack, Settings Persistence, And Reachability

**Files:**
- Create: `apps/macos-shell/Tests/ManualRuntime/ThemePackManualTests.swift`
- Create: `apps/macos-shell/Tests/ManualRuntime/GenerationSettingsManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/MenuModelManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Write the failing test for `settings.json` generation persistence while preserving existing blocks**

```swift
func testGenerationSettingsStorePersistsCapabilitiesWithoutDroppingAvatarState() throws {
    let root = try makeTemporaryDirectory()
    try writeText(
        at: root.appendingPathComponent("config/settings.json"),
        contents: #"{"avatar":{"current_id":"seal"},"timers":{"eye_interval":1200}}"#
    )

    let store = GenerationSettingsStore(repoRootURL: root)
    try store.save(
        GenerationSettings(
            activeThemeID: "pixel_default",
            textDescription: GenerationCapabilityConfig(
                provider: .ollama,
                baseURL: "http://localhost:11434",
                model: "qwen3.5:35b",
                auth: [:],
                options: ["temperature": 0.7]
            ),
            animationAvatar: GenerationCapabilityConfig(
                provider: .huggingFace,
                baseURL: "https://api-inference.huggingface.co",
                model: "stabilityai/stable-diffusion-xl-base-1.0",
                auth: ["token": "hf_xxx"],
                options: [:]
            ),
            codeGeneration: GenerationCapabilityConfig(
                provider: .openAICompatible,
                baseURL: "https://example.invalid/v1",
                model: "gpt-4.1-mini",
                auth: ["api_key": "sk-test"],
                options: [:]
            )
        )
    )

    let rootObject = try loadJSONObject(at: root.appendingPathComponent("config/settings.json"))
    try expect(rootObject["avatar"] != nil, "generation save should preserve avatar block")
    try expect(rootObject["generation"] != nil, "generation block should be written")
    try expect(((rootObject["theme"] as? [String: Any])?["current_id"] as? String) == "pixel_default", "active theme should be written")
}
```

- [ ] **Step 2: Write the failing test for invalid persisted theme fallback**

```swift
func testThemeManagerFallsBackToPixelThemeWhenStoredPackIsInvalid() throws {
    let repoRoot = try makeTemporaryDirectory()
    let appPaths = try makeTemporaryAppPaths()
    try writeText(
        at: appPaths.themesDirectory.appendingPathComponent("broken.json"),
        contents: #"{"meta":{"id":"broken","name":"Broken","version":1},"tokens":{},"components":{}}"#
    )

    let settingsStore = GenerationSettingsStore(repoRootURL: repoRoot)
    try settingsStore.saveActiveThemeID("broken")

    let manager = ThemeManager(appPaths: appPaths, settingsStore: settingsStore)

    try expect(manager.currentTheme.id == "pixel_default", "invalid stored theme should fall back to pixel default")
}
```

- [ ] **Step 3: Extend the menu model tests to require a reachable generation-config action**

```swift
func testIdleMenuShowsGenerationConfigEntryInUtilitySection() throws {
    let model = DesktopPetMenuModel(state: .idle)
    try expect(
        model.sections == [
            [.startWork],
            [.changeAvatar, .openGenerationConfig],
            [.closeWindow, .quitApp]
        ],
        "desktop menu should expose generation config as a themed-panel action"
    )
}
```

- [ ] **Step 4: Run the lightweight verifier and confirm it fails on missing theme/generation types**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL with missing `GenerationSettingsStore`, `ThemeManager`, or `openGenerationConfig` symbols.

## Task 2: Implement Theme Contracts, Persistence, And Pixel Default Fallback

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Theme/ThemeDefinition.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Theme/ThemePack.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Theme/PixelTheme.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Theme/ThemeManager.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Generation/GenerationSettingsStore.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Runtime/AppPaths.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Implement the theme token hierarchy and `ThemePack` validator**

```swift
struct ThemePack: Codable, Equatable {
    struct Meta: Codable, Equatable {
        var id: String
        var name: String
        var version: Int
        var sourcePrompt: String?
    }

    var meta: Meta
    var tokens: ThemeTokens
    var components: ThemeComponentTokens

    func validate() throws {
        guard !meta.id.isEmpty else { throw ThemePackError.missingMeta("id") }
        guard !tokens.colors.menuBackgroundHex.isEmpty else { throw ThemePackError.missingToken("colors.menuBackgroundHex") }
        guard !components.menuRow.padding.isEmpty else { throw ThemePackError.missingComponent("menuRow.padding") }
    }
}
```

- [ ] **Step 2: Implement `GenerationSettingsStore` on top of repo-root `config/settings.json`**

```swift
final class GenerationSettingsStore {
    func load() throws -> GenerationSettings
    func save(_ settings: GenerationSettings) throws
    func loadActiveThemeID() throws -> String?
    func saveActiveThemeID(_ id: String) throws
}
```

Required behavior:
- Preserve unrelated top-level keys like `avatar`, `ai`, `timers`, `user`
- Write capability config under `generation.text_description`, `generation.animation_avatar`, `generation.code_generation`
- Write active theme under `theme.current_id`

- [ ] **Step 3: Implement `PixelTheme` and `ThemeManager` persistence flow**

```swift
final class ThemeManager {
    private(set) var currentTheme: ThemeDefinition

    init(appPaths: AppPaths, settingsStore: GenerationSettingsStore) throws

    func apply(_ pack: ThemePack) throws
    func resetToPixelDefault() throws
}
```

Required behavior:
- Persist generated packs to `AppPaths.themesDirectory/<theme-id>.json`
- Load `theme.current_id` on startup
- Fall back to built-in `pixel_default` when file missing, JSON invalid, or validation fails
- Post a notification when theme changes so open windows can refresh or rebuild
- Expose a single shared runtime instance installed during app bootstrap, so legacy compatibility shims can read the active theme without building their own store graph

- [ ] **Step 4: Re-run the lightweight verifier**

Run: `bash tools/check_native_shell.sh`

Expected: PASS for new theme/settings tests, or fail only on the next missing routing/UI layer if later tests were added first.

- [ ] **Step 5: Commit the persistence baseline**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Theme \
  apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift \
  apps/macos-shell/Sources/ICUShell/Generation/GenerationSettingsStore.swift \
  apps/macos-shell/Sources/ICUShell/Runtime/AppPaths.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemePackManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/GenerationSettingsManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift \
  tools/check_native_shell.sh
git commit -m "feat: add theme persistence foundation"
```

## Task 3: Add Failing Tests For The Native Theme Generation Route

**Files:**
- Create: `apps/macos-shell/Tests/ManualRuntime/ThemeGenerationManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Write the failing test for routing `vibe` through text-description and code-generation capabilities in order**

```swift
func testThemeGenerationServiceUsesTextThenCodeCapabilities() throws {
    let transport = StubGenerationTransport(
        results: [
            .success(#"{"name":"Moss Pixel","summary":"掌机感、苔藓绿、低饱和"}"#),
            .success(validThemePackJSONString(id: "moss_pixel"))
        ]
    )
    let service = ThemeGenerationService(
        transport: transport,
        settingsStore: makeGenerationSettingsStore(),
        themeManager: makeThemeManager()
    )

    let applied = try service.generateAndApplyTheme(from: "像素风、掌机、苔藓绿")

    try expect(applied.meta.id == "moss_pixel", "service should apply generated theme pack")
    try expect(transport.requestedProviders == [.ollama, .openAICompatible], "service should call text capability before code capability")
}
```

- [ ] **Step 2: Write the failing test for generation failure fallback**

```swift
func testThemeGenerationServiceKeepsCurrentThemeWhenGeneratedPackIsInvalid() throws {
    let transport = StubGenerationTransport(
        results: [
            .success(#"{"name":"Broken Theme","summary":"bad"}"#),
            .success(#"{"meta":{"id":"broken","name":"Broken","version":1},"tokens":{},"components":{}}"#)
        ]
    )
    let themeManager = try makeThemeManagerWithPixelDefault()
    let service = ThemeGenerationService(
        transport: transport,
        settingsStore: makeGenerationSettingsStore(),
        themeManager: themeManager
    )

    do {
        _ = try service.generateAndApplyTheme(from: "损坏主题")
        throw ManualTestFailure("service should throw on invalid generated pack")
    } catch {
        try expect(themeManager.currentTheme.id == "pixel_default", "invalid theme generation must not replace current theme")
    }
}
```

- [ ] **Step 3: Run the manual runtime harness and verify it fails because the service/client do not exist yet**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL with missing `ThemeGenerationService` or `GenerationTransport` symbols.

## Task 4: Implement Native Swift Generation Routing For `vibe -> ThemePack`

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Generation/GenerationHTTPClient.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Generation/ThemeGenerationService.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Theme/ThemeManager.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeGenerationManualTests.swift`

- [ ] **Step 1: Add a transport abstraction so the route is testable without real network calls**

```swift
protocol GenerationTransport {
    func completeJSON(
        prompt: String,
        capability: GenerationCapabilityConfig
    ) throws -> String
}
```

- [ ] **Step 2: Implement the concrete HTTP client for Ollama and OpenAI-compatible providers**

```swift
final class GenerationHTTPClient: GenerationTransport {
    func completeJSON(prompt: String, capability: GenerationCapabilityConfig) throws -> String {
        switch capability.provider {
        case .ollama:
            return try callOllama(prompt: prompt, capability: capability)
        case .openAICompatible:
            return try callOpenAICompatible(prompt: prompt, capability: capability)
        case .huggingFace:
            throw GenerationRouteError.unsupportedProviderForTheme(capability.provider)
        }
    }
}
```

Required behavior:
- `text_description` supports `ollama` and `openai-compatible`
- `code_generation` supports `openai-compatible` and `ollama`
- Authentication comes from `auth`
- Network/JSON/provider failures surface as user-facing errors, not process crashes

- [ ] **Step 3: Implement `ThemeGenerationService` with two-stage prompt pipeline**

```swift
final class ThemeGenerationService {
    func generateAndApplyTheme(from vibe: String) throws -> ThemePack {
        let settings = try settingsStore.load()
        let styleIntentJSON = try transport.completeJSON(
            prompt: makeStyleIntentPrompt(vibe: vibe),
            capability: settings.textDescription
        )
        let themePackJSON = try transport.completeJSON(
            prompt: makeThemePackPrompt(styleIntentJSON: styleIntentJSON),
            capability: settings.codeGeneration
        )
        let pack = try ThemePack.decodeAndValidate(from: themePackJSON)
        try themeManager.apply(pack)
        return pack
    }
}
```

Required behavior:
- Empty vibe is rejected before network call
- Missing capability config throws a recoverable error
- Failed generation leaves the current active theme untouched
- Successful generation persists the new pack and marks it active

- [ ] **Step 4: Re-run the manual runtime harness**

Run: `bash tools/check_native_shell.sh`

Expected: PASS for theme-generation tests.

- [ ] **Step 5: Commit the native generation route**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Generation/GenerationHTTPClient.swift \
  apps/macos-shell/Sources/ICUShell/Generation/ThemeGenerationService.swift \
  apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift \
  apps/macos-shell/Sources/ICUShell/Theme/ThemeManager.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeGenerationManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift \
  tools/check_native_shell.sh
git commit -m "feat: add native theme generation route"
```

## Task 5: Build Shared Themed Components And Migrate Existing Swift Windows

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarPanelTheme.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarWizardWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift`

- [ ] **Step 1: Implement reusable AppKit theming helpers that read from the active theme**

```swift
enum ThemedComponents {
    static func styleWindow(_ window: NSWindow, theme: ThemeDefinition)
    static func makePanel(theme: ThemeDefinition) -> NSView
    static func makeSectionHeader(_ text: String, theme: ThemeDefinition) -> NSTextField
    static func stylePrimaryButton(_ button: NSButton, theme: ThemeDefinition)
    static func styleSecondaryButton(_ button: NSButton, theme: ThemeDefinition)
    static func styleTextField(_ field: NSTextField, theme: ThemeDefinition)
    static func styleTextView(_ textView: NSTextView, theme: ThemeDefinition)
    static func styleStatusChip(_ label: NSTextField, theme: ThemeDefinition)
}
```

- [ ] **Step 2: Convert `AvatarPanelTheme` into a thin compatibility wrapper over `ThemeManager.shared`**

```swift
enum AvatarPanelTheme {
    static func styleWindow(_ window: NSWindow) {
        ThemedComponents.styleWindow(window, theme: ThemeManager.shared.currentTheme)
    }
}
```

Goal:
- Stop storing authoritative colors/fonts in `AvatarPanelTheme`
- Let selector, wizard, and pet status chip all read from the same active theme

- [ ] **Step 3: Migrate selector, wizard, and pet status surfaces to themed components**

Key changes:
- Replace direct `AvatarPanelTheme.text`, `.input`, `.accent` lookups where possible with active theme tokens
- Keep existing layout and interaction flow unchanged
- Style inline status/error labels with theme tokens so generation errors can later reuse the same look
- Subscribe visible windows/views to the theme-change notification, then either re-style in place or rebuild their content tree so a newly generated theme can affect already-open GUI instead of only new windows

- [ ] **Step 4: Compile and verify the AppKit shell**

Run: `bash tools/check_native_shell.sh`

Expected: PASS

Optional when Xcode is active:

Run: `swift test --package-path apps/macos-shell`

Expected: PASS

- [ ] **Step 5: Commit the themed component migration**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarPanelTheme.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarWizardWindowController.swift \
  apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift
git commit -m "feat: migrate native shell windows to shared theme components"
```

## Task 6: Replace The Desktop Right-Click `NSMenu` With A Themed Floating Panel

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Menu/ThemedMenuPanel.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Menu/FloatingPanelController.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Menu/ContextMenuPanelController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetMenuModel.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/MenuModelManualTests.swift`

- [ ] **Step 1: Expand the desktop menu model to expose sectioned data for a themed panel**

```swift
enum DesktopPetMenuAction: String, Equatable {
    case startWork
    case enterFocus
    case takeBreak
    case resumeWorking
    case stopWork
    case changeAvatar
    case openGenerationConfig
    case closeWindow
    case quitApp
}

struct DesktopPetMenuModel: Equatable {
    var sections: [[DesktopPetMenuAction]] {
        switch state {
        case .idle:
            return [[.startWork], [.changeAvatar, .openGenerationConfig], [.closeWindow, .quitApp]]
        case .working:
            return [[.enterFocus, .takeBreak, .stopWork], [.changeAvatar, .openGenerationConfig], [.closeWindow, .quitApp]]
        case .focus, .breakState:
            return [[.resumeWorking, .stopWork], [.changeAvatar, .openGenerationConfig], [.closeWindow, .quitApp]]
        }
    }
}
```

- [ ] **Step 2: Build the shared themed menu panel and floating-panel behavior**

Required behavior:
- Render rows and separators from sectioned menu data
- Close on outside click
- Close on `Esc`
- Reuse one outside-click monitor implementation for both context menu and status menu

- [ ] **Step 3: Replace `NSMenu.popUpContextMenu(...)` with `ContextMenuPanelController`**

```swift
override func rightMouseDown(with event: NSEvent) {
    guard let contentView else { return }
    contextMenuController.present(
        from: menuModelProvider?() ?? DesktopPetMenuModel(state: .idle),
        event: event,
        in: contentView
    )
}
```

- [ ] **Step 4: Re-run the lightweight verifier**

Run: `bash tools/check_native_shell.sh`

Expected: PASS

- [ ] **Step 5: Commit the desktop menu replacement**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Menu/ThemedMenuPanel.swift \
  apps/macos-shell/Sources/ICUShell/Menu/FloatingPanelController.swift \
  apps/macos-shell/Sources/ICUShell/Menu/ContextMenuPanelController.swift \
  apps/macos-shell/Sources/ICUShell/Pet/DesktopPetMenuModel.swift \
  apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift \
  apps/macos-shell/Tests/ManualRuntime/MenuModelManualTests.swift
git commit -m "feat: replace desktop context menu with themed panel"
```

## Task 7: Replace The Status Bar Menu And Add The Native Generation Config Window

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Menu/StatusItemMenuModel.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Menu/StatusMenuPanelController.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Generation/GenerationCoordinator.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/AppDelegate.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`

- [ ] **Step 1: Add the failing menu-model test for the status panel**

```swift
func testStatusItemMenuExposesGenerationConfig() throws {
    let model = StatusItemMenuModel()
    try expect(
        model.sections == [
            [.showPet, .changeAvatar, .openGenerationConfig],
            [.quitApp]
        ],
        "status item menu should expose native generation config entry"
    )
}
```

- [ ] **Step 2: Implement `StatusMenuPanelController` and wire it to `statusItem.button` clicks**

```swift
private func setupStatusBarMenu() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem?.button?.title = "🐾"
    statusItem?.button?.target = self
    statusItem?.button?.action = #selector(toggleStatusPanel)
}
```

Required behavior:
- Do not assign `statusItem?.menu`
- Anchor the panel under the button
- Reuse the shared floating-panel closing behavior

- [ ] **Step 3: Implement `GenerationConfigWindowController` with capability sections and minimal theme-generation UI**

Required UI:
- Three capability sections: `文本描述`, `动画形象`, `代码生成`
- Editable fields per section: provider, base URL, model, auth, options
- `vibe` text input
- “生成并应用主题” button
- “恢复默认像素风” button
- Inline result/error status label

Suggested save/apply flow:

```swift
@objc private func handleGenerateAndApplyTheme() {
    do {
        try persistFormState()
        let pack = try generationCoordinator.generateAndApplyTheme(from: vibeTextView.string)
        statusLabel.stringValue = "已应用主题：\(pack.meta.name)"
    } catch {
        statusLabel.stringValue = error.localizedDescription
    }
}
```

- [ ] **Step 4: Wire generation-config actions from both menus and keep `AppDelegate` thin**

Required behavior:
- Status panel “生成配置” opens the config window
- Desktop right-click panel “生成配置” opens the same config window
- `GenerationCoordinator` owns the window controller lifecycle
- `AvatarCoordinator` remains focused on avatar flows only
- The config window refreshes its own controls when the active theme changes, so generating a theme from that window updates the window itself without requiring reopen

- [ ] **Step 5: Re-run shell verification and launcher tests**

Run: `bash tools/check_native_shell.sh`

Expected: PASS

Run: `bash tools/test_run_macos_shell.sh`

Expected: PASS

Run: `bash tools/test_verify_macos_shell.sh`

Expected: PASS

- [ ] **Step 6: Commit the themed status panel and generation window**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Menu/StatusItemMenuModel.swift \
  apps/macos-shell/Sources/ICUShell/Menu/StatusMenuPanelController.swift \
  apps/macos-shell/Sources/ICUShell/Generation/GenerationCoordinator.swift \
  apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift \
  apps/macos-shell/Sources/ICUShell/AppDelegate.swift \
  apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift \
  tools/test_run_macos_shell.sh \
  tools/test_verify_macos_shell.sh
git commit -m "feat: add themed status panel and generation config window"
```

## Task 8: Finish Verification, Docs, And Runtime Acceptance

**Files:**
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
- Modify: `tools/check_native_shell.sh`
- Modify: `tools/verify_macos_shell.sh`
- Modify: `README.md`
- Modify: `README_CN.md`

- [ ] **Step 1: Make sure every new manual test is compiled by `tools/check_native_shell.sh`**

Run: `bash tools/check_native_shell.sh`

Expected: PASS with:
- Theme/settings/generation manual tests passing
- AppKit shell compiling successfully

- [ ] **Step 2: Re-run the full lightweight verification entrypoint**

Run: `./icu --verify`

Expected:
- `swift build` succeeds
- manual runtime checks pass
- `swift test` runs only when Xcode is active

- [ ] **Step 3: Update docs for the new theme + generation workflow**

Required doc updates:
- How to open the generation config window
- What each capability field means
- How to recover to `PixelTheme`
- Where generated themes are stored
- How to run `./icu --verify`

- [ ] **Step 4: Perform the manual runtime acceptance checklist**

Manual checklist:
- Launch `./icu` and confirm the pet still appears at the desktop bottom-right
- Right-click the pet and confirm a pixel-themed panel appears instead of system `NSMenu`
- Click outside the right-click panel and confirm it closes
- Click the status bar icon and confirm a matching pixel-themed panel appears
- Open the generation config page from both menus and confirm it is the same window
- Save capability settings, restart the app, and confirm values persist
- Generate a valid theme and confirm selector/wizard/status chip all update to the new theme
- Force a generation failure and confirm the app stays usable and falls back to the previous or default theme

- [ ] **Step 5: Commit documentation and verification updates**

```bash
git add \
  apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift \
  tools/check_native_shell.sh \
  tools/verify_macos_shell.sh \
  README.md \
  README_CN.md
git commit -m "docs: document unified theme workflow and verification"
```
