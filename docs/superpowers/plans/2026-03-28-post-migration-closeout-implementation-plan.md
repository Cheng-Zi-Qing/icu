# Post-Migration Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Swift 原生桌宠补齐本地 `.app` 发布链路、配置持久化回归、provider 稳定层与文档说明。

**Architecture:** 在不大改现有 AppKit shell 的前提下，新增薄的 bundle 组装与检查脚本，收束生成 provider 路由，并通过 ManualRuntime 与脚本测试保护主题 / 形象 / 话术的配置一致性。

**Tech Stack:** Swift 6, SwiftPM, AppKit, Bash, JSON configuration

---

### Task 1: 发布脚本与 `.app` bundle 组装

**Files:**
- Modify: `tools/run_macos_shell.sh`
- Create: `tools/package_macos_shell.sh`
- Create: `tools/check_macos_app_bundle.sh`
- Modify: `tools/test_verify_macos_shell.sh`

- [ ] 写出 `.app` 组装与检查脚本的失败用例或脚本断言
- [ ] 实现 bundle 目录、Info.plist、资源拷贝、可执行文件复制
- [ ] 增加可选签名环境变量和 notarize 参数占位
- [ ] 运行脚本级验证，确保本地能产出可检查的 `.app`

### Task 2: 配置持久化一致性回归

**Files:**
- Modify: `apps/macos-shell/Tests/ManualRuntime/GenerationSettingsManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/AvatarSettingsStoreManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/SpeechGenerationManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`

- [ ] 先补主题 / 形象 / 话术互不覆盖的失败测试
- [ ] 实现最小代码修改，使所有新测试通过
- [ ] 把这些测试接入现有 manual runtime 入口

### Task 3: 生成 provider 路由收束

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityRouter.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/ThemeGenerationService.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Generation/SpeechGenerationService.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeGenerationManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/SpeechGenerationManualTests.swift`

- [ ] 先为 capability 路由规则写失败测试
- [ ] 实现统一路由与校验层
- [ ] 移除 service 内分散的 provider 判断
- [ ] 验证现有主题 / 话术生成测试仍通过

### Task 4: 文档、发布说明与最终验证

**Files:**
- Modify: `README_CN.md`
- Modify: `README.md`
- Create: `docs/macos-shell-release.md`
- Modify: `tools/verify_macos_shell.sh`
- Modify: `progress.md`
- Modify: `findings.md`

- [ ] 更新 Swift-first 启动、验证、打包、签名占位和 Python 残留职责说明
- [ ] 补发布检查入口并纳入最终验证步骤
- [ ] 跑完整验证，记录限制和剩余风险
