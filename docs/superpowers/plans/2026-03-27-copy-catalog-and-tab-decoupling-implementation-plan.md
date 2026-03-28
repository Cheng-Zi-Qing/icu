# Copy Catalog And Tab Decoupling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Swift 原生壳中的用户可见文案迁入独立 copy 资源文件，并把更换形象工作台的三个 tab 收敛成互不干扰的样式 / 形象 / 文本三条预览流。

**Architecture:** 通过新的 `Copy` 目录层加载 repo 内 `config/copy/base.json` 和运行时 override 文案，并让窗口控制器、菜单模型与用户可见错误统一从 `TextCatalog` 读取文案。Avatar studio 则保留现有三 tab 容器，但重写各 tab 的内容边界，只展示与当前创作维度有关的预览与操作。

**Tech Stack:** Swift 5.10, AppKit, SwiftPM, manual runtime tests, XCTest

---

## File Structure

- Create: `config/copy/base.json`
  - 默认用户可见文案资源
- Create: `apps/macos-shell/Sources/ICUShell/Copy/UserVisibleCopyKey.swift`
  - 稳定语义 key 定义
- Create: `apps/macos-shell/Sources/ICUShell/Copy/TextCatalog.swift`
  - 文案加载、合并、查找和 shared 安装入口
- Create: `apps/macos-shell/Tests/ICUShellTests/TextCatalogTests.swift`
  - copy catalog 的单元测试
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
  - 改为 copy 驱动，并按样式 / 形象 / 文本三类内容减重
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
  - 改为 copy 驱动
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift`
  - 用户可见错误改由 copy 提供
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarBuilderBridge.swift`
  - 用户可见 bridge 错误改由 copy 提供
- Modify: `apps/macos-shell/Sources/ICUShell/Menu/StatusItemMenuModel.swift`
  - 菜单标题改由 copy 提供
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetMenuModel.swift`
  - 菜单标题改由 copy 提供
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
  - 验证 tab 内容边界与 copy override 生效
- Modify: `apps/macos-shell/Tests/ManualRuntime/MenuModelManualTests.swift`
  - 验证菜单标题可被 copy override 替换
- Modify: `apps/macos-shell/Tests/ManualRuntime/GenerationConfigAppKitManualTests.swift`
  - 验证配置页文案来自 copy
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
  - 注册新增手工运行测试

### Task 1: Add Copy Catalog Infrastructure

**Files:**
- Create: `config/copy/base.json`
- Create: `apps/macos-shell/Sources/ICUShell/Copy/UserVisibleCopyKey.swift`
- Create: `apps/macos-shell/Sources/ICUShell/Copy/TextCatalog.swift`
- Test: `apps/macos-shell/Tests/ICUShellTests/TextCatalogTests.swift`

- [ ] **Step 1: Write the failing unit tests for base and active copy loading**

Add tests that verify:
- `TextCatalog` can load `base.json`
- override values replace matching keys
- missing override keys fall back to base values
- missing base keys fall back to a safe inline default passed by the caller

- [ ] **Step 2: Run the unit tests to verify they fail**

Run: `cd apps/macos-shell && swift test --filter TextCatalogTests`
Expected: FAIL with missing `TextCatalog` / `UserVisibleCopyKey`

- [ ] **Step 3: Create the base copy resource file**

Add `config/copy/base.json` with grouped sections:
- `common`
- `menu`
- `generation_config`
- `theme_studio`
- `avatar_studio`
- `speech_studio`
- `pet`
- `errors`

- [ ] **Step 4: Implement the copy catalog**

Implement:
- repo root base path discovery using existing repo-root inference pattern
- optional runtime override loading
- merged dictionary lookup by semantic key
- `TextCatalog.shared` installation API for app runtime and tests

- [ ] **Step 5: Run the unit tests to verify they pass**

Run: `cd apps/macos-shell && swift test --filter TextCatalogTests`
Expected: PASS

### Task 2: Route User-Visible Copy Through The Catalog

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarBuilderBridge.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Menu/StatusItemMenuModel.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetMenuModel.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/MenuModelManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/GenerationConfigAppKitManualTests.swift`

- [ ] **Step 1: Write the failing tests for copy-backed menus and config UI**

Add tests that verify:
- menu item titles change when copy override is installed
- generation config window title / helper text come from copy
- user-visible generation and bridge errors resolve via copy-backed phrasing

- [ ] **Step 2: Run the relevant tests to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL with stale hard-coded labels

- [ ] **Step 3: Replace hard-coded user-visible strings in menus, config UI, and surfaced errors**

Implement:
- copy lookup for menu titles
- copy lookup for configuration labels, buttons, helper text, placeholders
- copy-backed `LocalizedError` descriptions for surfaced errors

- [ ] **Step 4: Run the relevant tests to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

### Task 3: Slim Avatar Studio Tabs To Independent Preview Flows

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Write the failing tests for tab-specific content boundaries**

Add tests that verify:
- `主题风格` tab only shows style-oriented preview blocks
- `桌宠形象动画` tab shows avatar list / preview and does not show style-only cards or speech preview cards
- `话术` tab shows text preview and bubble text preview, but does not show style chrome preview
- overriding copy changes visible tab labels and section titles

- [ ] **Step 2: Run the AppKit manual tests to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL with extra cross-domain preview content or stale labels

- [ ] **Step 3: Rebuild the avatar studio tab bodies around copy-driven labels**

Implement:
- theme tab with only style summary, prompt, style preview, actions
- avatar tab with only avatar summary, prompt, avatar/action preview, actions
- speech tab with only speech summary, prompt, text preview, bubble preview, actions
- default preview text sourced from `TextCatalog`

- [ ] **Step 4: Run the AppKit manual tests to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

### Task 4: End-To-End Verify The Copy Catalog And Studio Split

**Files:**
- Modify as needed from previous tasks

- [ ] **Step 1: Run focused Swift package tests**

Run: `cd apps/macos-shell && swift test --filter TextCatalogTests`
Expected: PASS

- [ ] **Step 2: Run native shell verification**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

- [ ] **Step 3: Run launcher verification**

Run: `./icu --verify`
Expected: PASS

- [ ] **Step 4: Manual confirmation**

Run: `./icu`
Expected:
- 配置页用户可见文案来自 copy catalog
- 三个 tab 的内容边界清晰
- 文案资源未来可被单独替换，不与主题或形象绑定
