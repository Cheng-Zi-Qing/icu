# Generation Workbench And Theme Review Flow Design

**Date:** 2026-03-29

**Status:** Approved in browser and terminal review

## Goal

把当前 macOS shell 里两处仍然“不像最终产品”的交互正式固定下来：

- `生成配置` 页面从“说明偏多的配置页”收敛成输入优先的模型工作台
- `更换形象 > 主题风格` 从通用 `prompt -> preview -> apply` 改成可审阅的 `optimize prompt -> preview optimized prompt -> apply`

这份设计不引入新模块，而是给现有迁移结果补上更清晰的页面职责、交互顺序和状态边界。

## Current Context

仓库当前已经具备以下基础：

- `GenerationConfigWindowController` 已经拆成三个能力 tab
- `AvatarSelectorWindowController` 已经拆成 `主题风格 / 桌宠形象动画 / 话术` 三个工作室 tab
- 生成配置页已完成一次“workbench 化”尝试，但首屏视觉仍然偏说明页
- `主题风格` tab 仍使用通用动作栏，缺少单独的 prompt 优化审阅链路

用户已经明确确认两项方向：

- 配置页采用 `A: 字段主导`
- 主题风格链路采用 `A: 双层审阅`

## Product Decisions

### 1. 生成配置页只负责模型配置

`生成配置` 页面继续保持单一职责：

- 只负责三类模型能力的配置
- 不承载 prompt 编写
- 不承载生成预览
- 不承载结果应用

页面能力分类保持不变：

- `文本描述`
- `动画形象`
- `代码生成`

### 2. 生成配置页采用“字段主导工作台”

每个能力 tab 的首屏结构固定为：

1. 短标题
2. 单行弱说明
3. 三个核心字段
4. 高级配置折叠入口
5. 底部细状态条

核心字段固定为：

- `provider`
- `model`
- `base_url`

高级配置默认折叠，内容固定为：

- `auth`
- `options`

视觉优先级规则：

- 输入区是主视觉
- 标题和说明只负责定向，不抢高度
- 状态文案位于底部，不进入主卡核心区域
- 首屏不允许出现大块无意义留白

这意味着页面目标不是“把输入框加高一点”，而是让用户打开页面时立刻看到一个可填写的工作台。

### 3. 更换形象页面职责继续拆分

`更换形象` 页面继续保留三个互不干扰、可自由搭配的 tab：

- `主题风格`
- `桌宠形象动画`
- `话术`

职责边界继续保持：

- `主题风格` 只负责 GUI 和运行时视觉主题
- `桌宠形象动画` 只负责形象与动作表现
- `话术` 只负责文本人格和气泡内容

三者都允许未来接入 AI 生成，但不能在同一个 tab 内彼此混职。

## Theme Review Flow

### 1. 主题风格 tab 改成双层 prompt 审阅

`主题风格` tab 不再直接使用单个 prompt 输入框驱动预览，而是固定为四段流：

1. 当前已应用主题摘要
2. 原始 `prompt`
3. 优化后 `prompt`
4. 主题预览与应用

其中：

- 原始 `prompt` 是用户输入源
- 优化后 `prompt` 是可审阅、可继续编辑的生成稿
- 真实预览只允许基于优化后 `prompt`

### 2. 交互顺序固定

主题风格 tab 的操作顺序固定为：

1. 用户输入原始 `prompt`
2. 点击 `优化 prompt`
3. 系统生成“优化后 prompt”
4. 用户检查或修改优化稿
5. 点击 `预览效果`
6. 系统基于优化稿生成 `ThemePack draft`
7. 用户满意后点击 `应用主题`

不满意时，允许两种回路：

- 重新执行 `优化 prompt`
- 直接改写“优化后 prompt”再执行 `预览效果`

### 3. 原始 prompt 不被覆盖

双层审阅的核心约束：

- 原始 `prompt` 始终保留
- “优化后 prompt”单独展示，不覆盖原始输入
- 预览和应用阶段不再回读原始 `prompt`

这样可以保留用户意图来源，并让“提示词优化”成为独立、可检查、可替换的一层。

### 4. 主题 tab 不再复用通用动作栏

当前通用动作栏适用于：

- `生成预览`
- `重新生成`
- `应用`

但它不足以表达主题风格的新链路。

因此 `主题风格` tab 必须拥有专属动作区，至少包含：

- `优化 prompt`
- `重新优化`
- `预览效果`
- `应用主题`

并使用明确的启用/禁用规则，而不是沿用其他 tab 的通用按钮集合。

## State Model

### 1. 主题风格状态拆分

`主题风格` tab 的最小状态集合固定为：

- `rawThemePrompt`
- `optimizedThemePrompt`
- `previewedThemePack`
- `appliedThemeSummary`
- `draftThemeSummary`

语义要求：

- `rawThemePrompt` 只表示用户原始输入
- `optimizedThemePrompt` 只表示当前审核中的优化稿
- `previewedThemePack` 只表示最近一次成功预览得到的 draft

### 2. Apply 的前置条件

`应用主题` 只有在下列条件都成立时才可执行：

- 已存在非空 `optimizedThemePrompt`
- 已成功生成过 `previewedThemePack`
- 当前预览结果未失效

下列情况必须让 apply 重新失效：

- 用户修改了优化后 `prompt` 但尚未重新预览
- 用户重新优化了 prompt 但尚未重新预览
- 最近一次预览生成失败

### 3. Preview 的输入源固定

`预览效果` 的输入源固定为 `optimizedThemePrompt`。

如果尚未生成优化稿：

- 不允许直接预览
- 页面应给出明确状态提示，引导用户先执行 `优化 prompt`

## Error Handling

### 1. 优化失败

当 `优化 prompt` 失败时：

- 不清空原始 `prompt`
- 不污染已有的优化稿
- apply 仍保持不可用
- 状态栏显示失败信息

### 2. 预览失败

当 `预览效果` 失败时：

- 不应用任何主题
- 不把失败结果写入 `previewedThemePack`
- `应用主题` 必须不可用
- 保留原始和优化后的 prompt，允许用户继续修改重试

### 3. 用户可见文案边界

所有面向用户的文案继续走独立文本资源：

- tab 标题
- 状态提示
- 按钮标题
- 空态文案
- 错误文案

不允许在视图层继续写死这类字符串。

## Visual Direction

本次不更换视觉主题，只强化当前像素风体系下的层级关系。

需要保持：

- 当前 `PixelTheme` 的整体气质
- 统一的按钮、输入框、边框和卡片 token
- 配置页与更换形象页的风格一致性

需要加强：

- 配置页输入区的占比
- 主题风格 tab 中原始 prompt / 优化稿 / 预览区之间的层次区分
- 让页面更像工作台，而不是信息堆叠页

## Non-Goals

本次设计明确不做：

- 新的主题画风探索
- 模型能力分类调整
- `auth` / `options` 的结构化键值编辑器
- 主题生成模型与主题代码模型的运行时编排重构
- `桌宠形象动画` 和 `话术` tab 的新链路改造

## Implementation Notes

- `GenerationConfigWindowController` 需要进一步压缩 header 占比，并让三项核心字段占据首屏视觉主体
- `AvatarSelectorWindowController` 的 `主题风格` tab 需要从单 prompt 预览流切换为双 prompt 审阅流
- `主题风格` tab 需要新增独立状态和按钮禁用规则，不能继续完全复用通用动作栏
- 与主题风格相关的新按钮、状态提示和空态文案都需要进入文本资源目录
- 现有手工 AppKit 测试需要补上：
  - 配置页首屏字段可见性与密度约束
  - 主题风格“先优化、后预览、再应用”的交互约束
  - 修改优化稿后 apply 重新失效的约束
