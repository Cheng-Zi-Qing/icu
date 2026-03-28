# macOS Shell 轻量验证链路设计

日期：2026-03-26

## 背景

当前 `apps/macos-shell` 已能在仅安装 `Command Line Tools` 的机器上通过 `swift build` 构建，也能通过 [`tools/check_native_shell.sh`](/Users/clement/Workspace/icu/tools/check_native_shell.sh) 完成手工 runtime 校验。

但标准测试链路仍有两个现实约束：

1. `swift test` 依赖 `XCTest`，在未安装完整 Xcode 的机器上会失败。
2. 现有默认入口分散在 `swift build` 与 `tools/check_native_shell.sh` 之间，轻量工作流没有被显式固定，后续容易再次误用 `swift test`。

因此需要一个明确的双轨验证方案：保留未来接回 Xcode/XCTest 的能力，同时让 CLT-only 环境成为当前默认工作流。

## 目标

本次设计完成后，应满足以下条件：

1. 在只有 `Command Line Tools` 的机器上，存在一个统一、稳定、默认可用的验证入口。
2. 当前手工 runtime 校验链路继续保留，不回退到仅靠口头约定的状态。
3. `Package.swift` 中的 `testTarget` 和现有 `XCTest` 文件继续保留，为未来安装 Xcode 后恢复标准测试留出空间。
4. 当机器上未来具备 Xcode/XCTest 能力时，同一个默认入口可以自动追加标准测试，而不是要求手工切换流程。

## 非目标

1. 本次不删除 `XCTest` 测试目标。
2. 本次不为项目引入 Bazel、Tuist、Make 等额外构建系统。
3. 本次不把现有全部手工测试迁移到 `swift-testing` 或自定义测试框架。
4. 本次不要求解决 macOS 应用签名、Archive、Simulator 等完整 Xcode 工作流问题。

## 设计

### 1. 统一默认入口

新增一个 shell 验证脚本，作为 `apps/macos-shell` 的默认验证命令。脚本始终执行以下两步：

1. `swift build --package-path apps/macos-shell`
2. `tools/check_native_shell.sh`

这两步都已在当前 CLT-only 环境中验证可用，因此它们应构成默认入口的稳定基础。

### 2. 保留并自动探测 Xcode/XCTest 链路

默认脚本保留对标准测试链路的自动探测能力：

1. 如果当前环境具备 `XCTest` 或等价的 Xcode 能力，则额外执行 `swift test --package-path apps/macos-shell`
2. 如果当前环境不具备该能力，则脚本明确打印“跳过标准测试链路”，但整体命令仍然成功

这样可以保证：

1. 当前用户无需安装 Xcode 也能继续开发
2. 未来一旦装好 Xcode，不需要再修改仓库结构或切换到另一套命令

### 3. 现有测试目标保持不动

保留以下文件和配置：

1. [`apps/macos-shell/Package.swift`](/Users/clement/Workspace/icu/apps/macos-shell/Package.swift) 中的 `testTarget`
2. [`apps/macos-shell/Tests/ICUShellTests/SmokeTests.swift`](/Users/clement/Workspace/icu/apps/macos-shell/Tests/ICUShellTests/SmokeTests.swift)

这样做的原因是：

1. 当前轻量工作流解决的是“默认验证入口”，不是“永久放弃标准测试”
2. 未来装好 Xcode 后，这些内容可以直接重新参与验证，不需要再回填

### 4. 文档与命令约定

项目内需要把默认命令明确写出来，避免继续出现“本地到底该跑哪条命令”的歧义。默认命令应当是新脚本，而不是裸跑 `swift test`。

如果未来存在 README、开发者文档或进度文件引用验证命令，也应同步改成新默认入口。

## 备选方案比较

### 方案 A：只保留现状，不新增入口

优点：

1. 改动最少

缺点：

1. 轻量工作流仍然是隐式约定
2. 后续很容易再次误触 `swift test`
3. 不利于团队或后续会话恢复上下文

### 方案 B：删除 `XCTest`，彻底切到手工测试

优点：

1. 当前环境最干净

缺点：

1. 未来恢复标准测试成本更高
2. 会把“当前缺 Xcode”误固化为长期架构决策

### 方案 C：双轨保留，但轻量链路默认化

优点：

1. 兼容当前环境
2. 不阻断未来接回标准测试
3. 默认命令清晰，可重复执行

缺点：

1. 需要维护一个额外脚本

本次采用方案 C。

## 测试策略

### CLT-only 环境

验证以下内容：

1. 新默认脚本能成功运行 `swift build`
2. 新默认脚本能成功调用 `tools/check_native_shell.sh`
3. 在缺少 Xcode/XCTest 时，脚本以“跳过标准测试链路”结束，而不是失败

### 具备 Xcode 的未来环境

验证以下内容：

1. 新默认脚本仍能先通过 `swift build`
2. 新默认脚本仍能通过 `tools/check_native_shell.sh`
3. 新默认脚本会自动追加 `swift test --package-path apps/macos-shell`

## 风险

1. 如果标准测试链路探测条件写得不稳，可能在部分机器上误判可用性。
2. 如果项目文档不更新，用户仍可能直接运行 `swift test`，造成误解。
3. 未来装好 Xcode 后，标准测试可能暴露出与当前轻量链路不同的新问题，但这属于正确暴露，不应被视为本次方案缺陷。

## 说明

由于当前协作约束不允许启用子代理，本次规格文档采用人工自审代替 spec-review 子代理流程。

当前仓库工作区已存在未提交内容，本次仅写入规格文档，不在此步骤执行额外 git commit。
