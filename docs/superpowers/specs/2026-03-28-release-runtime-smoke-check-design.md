# Release Runtime Smoke Check Design

**Date:** 2026-03-28

**Status:** Drafted for user review

## Context

当前 macOS Swift shell 已具备这些能力：

- `./icu --verify` 可以完成 `swift build`、manual runtime checks、可选 `.app` 打包 smoke check
- `./icu --package-app` 可以产出 `dist/ICU.app`
- `tools/check_macos_app_bundle.sh` 可以校验 bundle 结构、可执行文件和运行时资源是否被正确打包

但这仍然只证明“仓库内能 build，bundle 结构看起来正确”，没有证明两个真正关键的问题：

1. `ICU.app` 离开仓库目录之后是否还能正常启动
2. 运行时是否真的只依赖 bundle 内资源和 `~/Library/Application Support/ICU`，而不是隐式依赖当前 repo cwd

在进入签名、公证、Gatekeeper 验证之前，应该先把这个运行闭环补实，否则后面的发布验证即使通过，也可能只是“在开发机仓库目录附近碰巧能跑”。

## Goals

- 为 `dist/ICU.app` 增加“脱离仓库目录运行”的自动化 smoke test
- 让验证结果能明确证明应用资源根、用户配置目录和启动行为都符合发布态预期
- 把这套 smoke test 接入现有 `./icu --verify` 发布检查链路，作为可选但标准的发布前验证
- 更新发布文档，明确区分“结构校验通过”和“隔离运行通过”

## Non-Goals

- 本轮不接入真实 Apple Developer 证书、codesign 身份配置或 notarize 成功判定
- 不在这轮修改桌宠 UI、主题、生成链路或 Python bridge 行为
- 不引入复杂 UI 自动化框架，不做像素级截图对比
- 不尝试验证所有系统权限弹窗，仅关注应用是否能在隔离目录完成基础启动

## Approach

### 1. Add A Detached Runtime Smoke Script

新增一个专用脚本，例如 `tools/smoke_test_macos_app_runtime.sh`，执行顺序固定为：

1. 若不存在 `dist/ICU.app`，先调用现有打包脚本生成
2. 创建临时目录，把 `dist/ICU.app` 复制进去
3. 从临时目录启动该 app，而不是从 repo 根目录启动
4. 采集固定证据：
   - 启动是否成功
   - 进程是否在超时窗口内存活
   - 标准输出 / 标准错误日志
   - 是否创建了 `~/Library/Application Support/ICU`
   - 是否写入了预期的 `config/settings.json` 或其他运行态文件
5. 清理临时副本和后台进程

脚本的目标不是“证明所有功能都可交互”，而是证明它作为独立 `.app` 已经拥有正确的最小运行条件。

### 2. Add Explicit Runtime Evidence Hooks

为了让 smoke test 的失败可定位，需要给运行态补少量、稳定的证据输出，优先放在 shell 启动阶段：

- 当前识别到的 bundle 资源根
- 当前识别到的用户配置目录
- 是否处于 bundle 运行态还是 repo 运行态

这些证据只用于发布 smoke test 和排障，不应把正常日志变成噪声洪流。设计上应采用清晰、可 grep 的单行日志前缀，例如 `[runtime_smoke]` 或 `[app_paths]`。

### 3. Integrate With Verify Pipeline

现有 `./icu --verify` 已有：

- build
- manual runtime checks
- 可选 `.app` 打包 + bundle 结构检查

本轮新增一个更高一级的可选开关，例如：

- `VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1`

当该开关开启时，验证流程顺序变为：

1. `swift build`
2. manual runtime checks
3. `swift test` 或显式 skip
4. `.app` 打包
5. bundle 结构检查
6. 脱仓库运行 smoke test

这样能继续保留轻量验证模式，同时给“发布前检查”一个更可信的终点。

### 4. Clarify Release Documentation

更新发布文档时要把验证层级拆清楚：

- `bundle structure check`
  只说明包结构、资源和二进制存在
- `detached runtime smoke check`
  说明 app 在仓库外也能完成基础启动
- `signing / notarization / Gatekeeper`
  说明这是下一阶段工作，不在本轮宣称完成

文档目标不是堆命令，而是让人知道“每个检查证明了什么，没有证明什么”。

## Testing Strategy

- 脚本级测试：
  为新 smoke script 增加测试，覆盖成功路径、超时路径和日志输出路径
- 集成验证：
  用 `VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1 ./icu --verify` 跑完整链路
- 人工 spot check：
  在生成出的临时目录副本上手动确认 `ICU.app` 可被 `open` 或直接执行启动

## Risks

- AppKit 应用在 CI 或无图形会话环境中的启动行为可能和本地桌面环境不同，因此脚本应明确支持范围，默认针对本机发布前检查
- 如果当前应用首次启动不会立即写配置文件，不能把“未写 settings.json”误判为启动失败；证据条件需要区分“必须存在”和“可选观察项”
- 过度依赖日志文案会让测试脆弱，因此 smoke script 应优先验证路径、进程状态和文件副作用，再辅以日志

## Expected Outcome

完成后，我们可以更准确地说：

- `ICU.app` 不只是“被打出来了”
- 它还能在仓库外、仅依赖 bundle 资源和用户态配置目录完成基础启动

这会成为下一阶段签名、公证和 Gatekeeper 验证的稳定前置条件。
