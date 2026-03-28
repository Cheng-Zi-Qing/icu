# Runtime Bubble And Generation Contracts Design

**Date:** 2026-03-28

**Status:** Approved in browser and terminal review

## Goal

在当前 Swift 原生 macOS 壳上，把两类边界正式固定下来：

- 运行时桌宠气泡家族的视觉与交互 contract
- 主题、形象动画、话术三条生成链路的 draft / preview / apply contract

这份设计不是重新定义产品，而是给现有迁移后的实现补一层稳定约束，避免后续“允许 AI 生成”直接把 GUI 结构、预览逻辑和运行时行为带乱。

## Current Context

仓库里已经具备以下基础：

- `GenerationConfigWindowController` 已经是三类模型能力配置页
- `AvatarSelectorWindowController` 已经承担 `主题风格 / 桌宠形象动画 / 话术` 三个工作室 tab
- 主题生成已能输出 `ThemePack`
- 话术生成已能输出 `SpeechDraft`
- 主题应用已通过 `ThemeManager`
- 话术应用已通过 `CopyOverrideStore`
- 运行时桌宠已经区分 transient bubble 和 persistent status chip

当前缺口主要在三个地方：

- 桌宠气泡、status chip、配置页预览还没有被抽成统一视觉 contract
- 三个工作室 tab 的 generate / regenerate / apply 逻辑虽然存在，但还没有统一成稳定的 draft 生命周期
- “允许 AI 生成”的边界还不够清楚，哪些是 token，哪些是固定结构，尚未正式写死

## Product Decisions

### 1. 右键栏保持纯菜单

右键栏不承载提示块、提示气泡、状态摘要卡片。

右键栏只负责命令类内容，例如：

- 开始工作
- 进入专注
- 暂离
- 更换形象
- 模型配置
- 隐藏
- 退出

右键栏只共享主题 token，不加入气泡结构家族。

### 2. Runtime Bubble Family 固定为两种形态

运行时文本表达只保留两种视觉形态：

- `RuntimeBubble`
- `PersistentStatusChip`

不再新增第三种“像提示又像状态”的中间形态。

### 3. RuntimeBubble 规则

`RuntimeBubble` 是运行时主表达层。

固定规则：

- 位于桌宠形象上方
- 使用带尾巴的气泡结构
- 尾巴必须偏向形象一侧
- 尾巴不能挂在几何正中
- 用于瞬时消息、提醒、建议、短反馈

典型内容包括：

- focus 结束提醒
- stop work 提示
- 护眼提醒
- 临时错误或反馈文案

### 4. PersistentStatusChip 规则

`PersistentStatusChip` 是持续状态层，不承担“说话”的角色。

固定规则：

- 无尾巴
- 使用 bubble family 的紧凑态，而不是完全独立的药丸组件
- 默认位置固定为桌宠形象的贴身下侧
- 用于表达持续状态，例如 `idle / working / focus / break`

### 5. Bubble 和 Chip 的显隐关系

当 `RuntimeBubble` 出现时：

- `PersistentStatusChip` 暂时隐藏

当 `RuntimeBubble` 收回后：

- `PersistentStatusChip` 恢复显示

这条规则是强约束，不允许主题生成或未来视觉风格改写。

目标很直接：

- 同时只保留一条文本主通道
- 避免 transient bubble 和 persistent chip 同时争抢注意力

### 6. 配置页预览必须复刻真实运行时结构

配置页和工作室内的预览，不允许再用普通 chip 代替真实气泡。

主题和话术相关预览必须能表达真实运行时结构：

- 上方带尾巴的 `RuntimeBubble`
- 下侧贴身的 `PersistentStatusChip`
- bubble 出现时 chip 收起

预览允许缩略、静态化，但结构不能失真。

## Theme And Component Contract

### 1. 允许 AI 生成的部分

AI 可以生成和调整的内容限定为主题 token 和受限组件参数。

允许生成的主题 token：

- 颜色系统
- 字体系统
- 圆角
- 边框粗细
- padding / spacing
- 阴影
- 动效时长
- 可选装饰资产

允许在约束内调整的组件参数：

- bubble 最大宽度
- bubble 内边距
- bubble 尾巴偏移范围
- status chip 相对形象的偏移量
- 菜单行密度
- 按钮尺寸等级

### 2. 不允许 AI 改写的部分

以下内容是固定组件 contract，不属于自由生成范围：

- 哪些组件有尾巴，哪些没有
- bubble 尾巴必须偏向形象一侧
- status chip 必须位于贴身下侧
- bubble 出现时 chip 必须隐藏
- 右键栏必须保持纯菜单
- 配置页预览必须复刻真实运行时结构

模型可以决定“看起来像什么”，不能决定“结构规则是什么”。

### 3. 本地 Renderer 优先

代码生成模型第一阶段不直接产出 AppKit 代码，也不直接改运行时 GUI 结构。

它的职责限定为输出结构化主题草稿，例如：

- `ThemePack`
- `ThemeTokens`
- `ThemeComponentTokens`

真正绘制 UI 的仍然是本地固定 renderer。

这条边界的目的：

- 避免模型直接破坏运行时组件 contract
- 把失败面收敛到结构化数据校验，而不是任意代码执行

## Generation Routing

### 1. 模型能力配置页职责固定

`GenerationConfigWindowController` 只负责三类能力配置：

- `text_description`
- `animation_avatar`
- `code_generation`

该页面不负责生成、预览、应用内容。

### 2. 三个工作室 tab 和能力映射固定

`主题风格`：

- 主能力为 `code_generation`
- 输出为结构化 `ThemePack` 草稿

`桌宠形象动画`：

- 主能力为 `animation_avatar`
- 输出为形象与动作相关 draft

`话术`：

- 主能力为 `text_description`
- 输出为 `SpeechDraft`

如有需要，`桌宠形象动画` 可以附带调用 `text_description` 做 prompt 优化或 persona 补充，但其正式产物仍归属 avatar draft，不和 speech draft 混用。

## Draft Lifecycle

### 1. 三个工作室统一状态机

三个 tab 统一采用同一交互闭环：

`prompt -> pending draft -> local preview -> apply`

### 2. Applied 和 Pending 分离

每个 tab 都保留两份状态：

- `applied`
- `pending draft`

规则如下：

- `generate preview` 产生或更新 `pending draft`
- `regenerate` 只替换 `pending draft`
- `apply` 成功后才覆盖 `applied`
- 未点击 `apply` 前，真实运行时状态不变化

### 3. Preview 责任边界

`主题风格` preview 负责：

- 菜单
- 表单
- 按钮
- runtime bubble
- persistent status chip

`桌宠形象动画` preview 负责：

- 当前形象
- 动作关键帧或循环预览
- 不同状态下的形象表现

`话术` preview 负责：

- 状态文案摘要
- bubble 示例文案
- 运行时说话气泡文本效果

工作室之间不能互相挤占职责：

- 主题页不负责话术创作
- 形象页不负责 GUI 样式设计
- 话术页不负责形象与主题细节

## Persistence Boundaries

### 1. 正式生效内容继续持久化

当前持久化职责保持不变：

- 模型配置通过 `GenerationSettingsStore`
- 已应用主题通过 `ThemeManager`
- 已应用话术通过 `CopyOverrideStore`
- 已应用形象动画通过资产与运行时选择逻辑

### 2. Pending Draft 默认不跨重启

`pending draft` 默认只存在于窗口会话内。

本轮不要求：

- 应用前 draft 跨重启恢复
- 草稿历史版本管理
- 草稿回滚中心

窗口关闭后丢失 `pending draft` 是可以接受的，只要 `applied` 稳定且不受影响。

### 3. Apply 的原子性

任何 apply 失败都不能让运行时进入半生效状态。

要求：

- 主题 apply 失败时，不切半套主题
- 话术 apply 失败时，不写坏 active copy
- 形象 apply 失败时，不破坏当前已使用形象

## Local Validation

### 1. Schema Validation

所有生成结果先过结构校验：

- 主题草稿必须能 decode 为合法 `ThemePack`
- 话术草稿必须能 decode 为合法 `SpeechDraft`
- 形象动画草稿也必须有明确结构化 draft，而不是散文式说明

### 2. Contract Validation

除了 schema，还必须过本地 contract 校验。

至少检查：

- 右键栏仍是纯菜单
- runtime bubble 仍是带尾巴结构
- bubble 尾巴偏向形象一侧
- status chip 仍是无尾巴紧凑态
- chip 位置仍为贴身下侧
- bubble 出现时 chip 会隐藏
- 配置页预览复刻运行时结构

### 3. Rendering Validation

即使结构合法，也要确认本地 renderer 能实际渲染 preview。

只要 preview 渲染失败：

- 当前 draft 不能进入 apply

## Error Handling

### 1. 生成失败

生成失败时：

- 保留现有 `applied`
- 保留上一个可用的 `pending draft`
- 在当前 tab 内显示错误状态

不能因为一次超时或鉴权失败，把整个工作台清空。

### 2. 应用失败

应用失败时：

- `applied` 保持原值
- 真实运行时不闪烁、不切半套内容
- 当前 tab 展示可理解的错误原因

### 3. 失败隔离

三个 tab 之间相互隔离：

- 主题失败不影响话术 draft
- 话术失败不影响形象 draft
- 形象失败不影响主题 preview

## Scope Control

本设计收敛为一个可规划的单一实现方向：

- 固定 bubble family contract
- 把生成结果统一为 draft / preview / apply 生命周期
- 对主题、话术、后续形象动画草稿引入统一校验边界

本次不做：

- 自由生成任意 AppKit 组件结构
- 右键栏提示块
- draft 跨重启恢复
- 三个工作室的一次性联动提交
- 重新设计右键栏信息架构

## Affected Code Areas

重点修改区域预计包括：

- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift`
- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift`
- `apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift`
- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- `apps/macos-shell/Sources/ICUShell/Generation/GenerationCoordinator.swift`
- `apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift`
- `apps/macos-shell/Sources/ICUShell/Theme/ThemePack.swift`

如果本轮需要把 avatar 生成也结构化，还会新增或调整：

- avatar draft model
- avatar preview validator
- avatar preview renderer glue

## Testing Boundaries

需要新增或扩展四类测试。

### 1. 数据与校验测试

- `ThemePack` 结构与约束校验
- `SpeechDraft` 校验
- avatar draft 结构校验
- contract validator 测试

### 2. 工作室状态机测试

- generate 产生 pending draft
- regenerate 只替换 pending draft
- apply 前不污染 applied
- apply 成功后覆盖 applied
- apply 失败后保持原 applied

### 3. AppKit 运行时交互测试

扩展现有 `ThemeAppKitManualTests` 覆盖：

- runtime bubble 和 status chip 的独立结构
- bubble 尾巴偏向形象一侧
- status chip 固定在贴身下侧
- bubble 出现时 chip 隐藏
- bubble 收回后 chip 恢复
- 配置页预览与运行时结构保持一致

### 4. 错误路径测试

- 配置缺失
- 超时
- 鉴权失败
- JSON 解析失败
- apply 失败

这些路径都要验证：

- `applied` 不被破坏
- 其他 tab 的 draft 不受影响
- 用户看到的错误文案可理解
