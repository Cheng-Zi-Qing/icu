# Post-Migration Closeout Design

## Context

Swift 原生桌宠 shell 已经替代旧的 Python 启动链，当前缺口集中在四处：

1. 仍以 `swift run` 为主，没有真正的 `.app` 本地发布链路。
2. 主题、形象、话术虽然已有持久化入口，但缺少跨模块回归保护。
3. 生成能力已按文本 / 动画形象 / 主题代码三类建模，但 provider 规则仍分散在具体 service 里。
4. 文档仍缺少 Swift-first 发布、签名、公证接入说明，以及 Python 残留能力边界。

## Goals

- 让仓库能在无 Xcode 的轻量环境下完成本地 `.app` 组装和基础发布检查。
- 为主题、形象、话术三类用户配置补一致性测试，避免互相覆盖。
- 把生成 provider 规则收束为统一路由层，便于后续接更多模型。
- 更新用户和开发者文档，使 Swift-first 启动、验证、发布路径清晰可执行。

## Non-Goals

- 不在没有 Apple Developer 证书的环境里伪造签名或 notarize 完成状态。
- 不在这一轮删除所有 Python 业务代码；仅继续清除桌宠启动链的遗留耦合。
- 不做新的 GUI 大改版，本轮只补配置和发布基础设施。

## Approach

### 1. Local App Packaging

新增独立发布脚本，基于 Swift build 产出的 `ICUShell` 可执行文件组装一个标准 macOS `.app` bundle：

- 生成 `ICU.app/Contents/MacOS/ICUShell`
- 生成 `ICU.app/Contents/Info.plist`
- 复制运行所需仓库资源到 `Contents/Resources`
- 提供可选签名参数和可选 notarize 参数校验入口

这样可以在不依赖完整 Xcode GUI 的情况下，先得到本地可运行包；后续证书就位后只需补环境变量即可签名。

### 2. Unified Persistence Regression Coverage

现有 `GenerationSettingsStore`、`AvatarSettingsStore`、`CopyOverrideStore` 分别负责一部分配置。本轮补三类跨模块测试：

- 保存生成配置时不丢失当前形象与其他设置
- 保存形象设置时不破坏 generation 配置
- 应用话术 override 时不破坏现有配置目录与主题/形象状态

目标是把“同一份 `config/settings.json` / app support 配置被多个模块安全读写”变成受保护行为。

### 3. Stable Generation Provider Routing

把 provider 校验和能力路由从具体 service 内部提取到统一 provider policy / router：

- 文本描述允许本地文本模型和兼容 OpenAI 的远端文本模型
- 动画形象允许图像/动画 provider
- 主题代码允许代码生成类文本模型

各 service 不再直接硬编码 provider 白名单，而是通过统一路由层取 capability 并验证。

### 4. Documentation and Release Checks

补两类文档：

- 用户文档：如何启动、如何本地打包 `.app`、如何验证桌宠位置/气泡/主题配置
- 开发文档：签名、公证环境变量预留，当前 CLT-only 环境限制，以及保留 Python 模块的职责说明

同时增加一个轻量发布检查脚本，验证 `.app` bundle 结构、可执行文件、Info.plist 关键字段和资源是否完整。

## Testing Strategy

- 先加失败的 ManualRuntime 测试，覆盖持久化一致性和 provider 路由。
- 脚本级测试覆盖 `.app` 打包结果和发布检查。
- 最终通过 `./icu --verify` 和新增发布检查脚本完成验收。

## Risks

- `.app` 运行时路径从仓库根运行切到 bundle 内运行后，资源定位可能暴露新问题。
- 签名和 notarize 只能做接入位，最终上线仍需要真实证书环境验证。
- provider 抽象如果过度设计，会拖累当前轻量方案，因此只保留最小路由和校验层。
