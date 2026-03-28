# Model Config And Avatar Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把模型配置页与创作页彻底分离，使配置页只管理模型设置，更换形象页承接主题风格、桌宠形象动画、话术三类内容的生成预览应用流程。

**Architecture:** 保留当前 `GenerationSettingsStore`、`ThemeGenerationService` 与 Avatar bridge 的底层数据结构，主要重构 AppKit 窗口控制器的信息架构。配置页改成顶部 tabs 的纯模型设置页；更换形象页演进成顶部 tabs 的创作工作台，并为主题/形象/话术引入 `draft` 与 `applied` 的 UI 状态区分。

**Tech Stack:** Swift 6, AppKit, SwiftPM manual runtime tests, existing ThemeManager / AvatarBuilderBridge

---

## File Structure

- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
  - 改成纯模型设置页，顶部 tabs，移除主题生成执行区
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationCoordinator.swift`
  - 只负责配置窗口生命周期；后续把主题生成动作暴露给创作工作台调用
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
  - 演进为更换形象工作台或其宿主入口，承接顶部 tabs
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarWizardWindowController.swift`
  - 将现有优化提示词 / 图像生成 / 人设生成步骤重构为创作 tab 详情页或复用其内部块
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`
  - 串起新的页面入口与窗口生命周期
- Modify: `apps/macos-shell/Tests/ManualRuntime/GenerationConfigAppKitManualTests.swift`
  - 覆盖纯模型设置页 tabs 与高级设置折叠行为
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
  - 覆盖新的更换形象工作台主题刷新与 tabs 保持行为
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
  - 注册新增手工测试

### Task 1: Convert Generation Config Into A Pure Model Settings Page

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/GenerationConfigAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Write the failing tests for tab-only model config UI**

Add tests that verify:
- 配置页顶部 tabs 仅包含 `文本描述 / 动画形象 / 代码生成`
- 不再出现主题生成执行区
- 默认进入 `文本描述`
- 高级设置默认折叠

- [ ] **Step 2: Run the AppKit manual tests to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL with missing tab labels or stale theme-generation controls.

- [ ] **Step 3: Rebuild `GenerationConfigWindowController` as a pure settings window**

Implement:
- 顶部 tab bar
- 单能力详情面板
- 基础配置 / 高级设置折叠区
- 草稿切 tab 保留

- [ ] **Step 4: Run the AppKit manual tests to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

### Task 2: Move Theme Generation Flow Into Avatar Studio

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationCoordinator.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Write the failing tests for a tabbed avatar studio shell**

Add tests that verify:
- 更换形象页顶部 tabs 包含 `主题风格 / 桌宠形象动画 / 话术`
- `主题风格` tab 显示当前已应用主题、本次使用模型摘要、prompt 区、预览区
- 存在 `生成预览 / 重新生成 / 应用` 三个动作

- [ ] **Step 2: Run the AppKit manual tests to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL with missing tab labels or missing preview/apply controls.

- [ ] **Step 3: Implement the avatar studio host UI**

Implement:
- 顶部像素风 tabs
- 主题风格 tab 的主面板
- 跳转到模型配置页的轻量入口
- `draft` 与 `applied` 的摘要区

- [ ] **Step 4: Run the AppKit manual tests to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

### Task 3: Reframe Avatar Animation And Speech As Preview-First Studio Tabs

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarWizardWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Write the failing tests for preview-first animation and speech tabs**

Add tests that verify:
- `桌宠形象动画` tab 显示 prompt、预览、重新生成、应用
- `话术` tab 显示 prompt、话术预览、重新生成、应用
- 两个 tab 都不直接覆盖当前已应用内容

- [ ] **Step 2: Run the AppKit manual tests to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL with missing preview/apply workflow controls.

- [ ] **Step 3: Implement tab content using existing wizard capabilities**

Implement:
- 复用现有优化提示词、图像生成、人设生成逻辑
- UI 改成 tab 内预览流，而不是 step wizard 心智
- 生成结果先进入草稿区

- [ ] **Step 4: Run the AppKit manual tests to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

### Task 4: End-To-End Verify The New Split

**Files:**
- Modify as needed from previous tasks

- [ ] **Step 1: Run shell verification**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

- [ ] **Step 2: Run launcher verification**

Run: `./icu --verify`
Expected: PASS

- [ ] **Step 3: Manual visual confirmation**

Run: `./icu`
Expected:
- 配置页只显示模型设置
- 更换形象页显示三 tabs
- 主题风格 tab 先生成预览，再应用
