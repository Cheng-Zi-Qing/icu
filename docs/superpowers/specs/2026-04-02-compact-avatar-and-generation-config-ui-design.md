# Compact Avatar Studio And Generation Config UI Design

**Date:** 2026-04-02

**Status:** Drafted from approved browser and terminal review; pending written-spec review

## Context

当前 macOS Swift shell 里的两个配置窗口都已经可用，但在更小屏幕上都有明显的垂直空间问题：

- [`apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`](/Users/clement/Workspace/icu/apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift) 目前采用“顶部标题 + tab + 大内容卡片 + 底部关闭按钮”的单窗布局，内容主要靠纵向堆叠展开
- `桌宠形象动画` 的浏览态和新建自定义形象态都会把较多说明、预览和输入区堆在同一列中
- [`apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`](/Users/clement/Workspace/icu/apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift) 目前是单列滚动表单，`Provider / Model / Base URL / Auth / Options` 基本共享同一类输入体验
- 生成配置页里的输入栏过小，尤其 `Auth / Options` 这种 JSON 型内容使用单行输入体验很差

这会导致两个直接问题：

1. 更小屏幕下，用户经常无法在一个视口里同时看到当前关键内容和主操作按钮
2. 页面虽然“能滚”，但滚动发生在整块长页上，信息层级不清楚，编辑体验也显得拥挤

## Goals

- 让 `更换形象` 和 `生成配置` 在更小屏幕上也具备合理的可视高度分配
- 优先保证主操作按钮在小屏下更容易被看到，不再被长页面推到视口外
- 把整窗长页改成“固定导航 + 右侧工作区 + 局部滚动”的信息架构
- 让 `新增自定义形象` 从当前单块长内容改成更明确的两步式工作流
- 让 `生成配置` 的高级字段默认折叠，并把 JSON 类配置改成更适合编辑的多行区域

## Non-Goals

- 本次不重做整个视觉主题系统，不推翻现有 `AvatarPanelTheme`
- 本次不改变 `主题风格 / 桌宠形象动画 / 话术` 三 tab 的产品职责边界
- 本次不把新建自定义形象重新做回独立窗口或旧向导
- 本次不引入复杂动画或全新的 UI 框架，仍基于现有 AppKit 视图结构调整

## Confirmed Product Decisions

以下决定已经在浏览器 mockup 和终端确认中被用户接受：

1. 采用方案 A：双栏工作台，而不是完整分段向导或保守折叠方案
2. 设计目标优先面向更小屏幕，不追求完全无滚动，但允许适度滚动或翻页
3. `生成配置` 的高级字段可以默认收起，先展示 `Provider / Model / Base URL`
4. `新增自定义形象` 可以改成更明确的分步式：先 `prompt / 优化 / 生成预览`，再 `名称 / persona / 保存应用`
5. `Auth / Options` 不继续使用“小单行输入框”体验，而改成更适合 JSON 编辑的多行区域

## Chosen Approach

### 1. Shared Small-Screen Layout Pattern

两个窗口统一采用同一类骨架：

- 顶部区变薄，只保留必要标题、简要说明和状态信息
- 左侧承担导航或列表职责
- 右侧承担当前主要编辑和预览职责
- 底部保留明显的主操作区
- 优先让右侧工作区局部滚动，而不是让整窗不断向下增长

这样做的核心收益是：用户在小屏幕上仍能快速知道“我在哪个功能里”“当前看到的是哪部分内容”“接下来该点哪个按钮”。

### 2. Why Not Full Wizard

完整分段向导虽然能进一步压缩高度，但会改变当前工作台心智模型，尤其会让 `更换形象` 和 `生成配置` 看起来像两套新系统。

因此本次采用：

- 整体仍是工作台
- 仅在 `新增自定义形象` 这一块内部使用两步式
- `生成配置` 用基础/高级折叠解决高度问题，而不是拆成完全独立的多页流程

## Avatar Studio Layout

### 1. Window-Level Structure

`AvatarSelectorWindowController` 的窗口结构保持单窗不变，但信息层级改成：

1. 更薄的顶部区：标题、简短副标题、状态条
2. tab 切换条
3. 主内容区：左栏 + 右侧工作区
4. 窗口级底部关闭按钮

窗口不再依赖把所有信息继续向下堆来容纳功能，而是把纵向空间主要留给主内容区。

### 2. Browse Mode

`桌宠形象动画` 的浏览态改成双栏：

- 左栏常驻：
  - 当前 tab 所在上下文
  - 形象列表
- 右侧常驻：
  - 当前已应用摘要
  - 当前草稿摘要
  - 大预览图
  - 主要说明
  - 主操作按钮：`新增自定义形象 / 预览 / 重新生成 / 应用`

`prompt` 输入区不再默认占据过多高度，而是变成右侧工作区里的可折叠区块或次级区块。

### 3. Create Mode

`新增自定义形象` 仍留在 `桌宠形象动画` tab 内，但在现有 `create` 模式内部新增更清晰的两步态：

- `editingPrompt`
- `editingMetadata`

#### Step 1: Prompt And Preview

第一步只关注这些内容：

- 原始 prompt
- 优化后 prompt
- `idle / working / alert` 三态预览
- 相关动作：`优化 prompt / 生成预览 / 重新生成`

#### Step 2: Metadata And Save

第二步只关注这些内容：

- 名称
- persona
- 保存前状态说明
- 主动作：`保存并应用`

左栏仍保留形象列表和“当前模式：新建形象 / 返回现有形象”，作为用户的返回锚点。

### 4. Persistent vs Collapsible Content

`Avatar Studio` 内部的可见性规则如下：

- 浏览态常驻：
  - 左侧列表
  - 右侧大预览
  - 当前已应用/当前草稿摘要
  - 主操作按钮
- 浏览态默认折叠：
  - 长 prompt 编辑区
  - 次要说明文案
  - 更细的状态信息
- 新建态常驻：
  - 步骤切换
  - 当前步骤主内容
  - 主操作按钮
- 新建态默认折叠：
  - 长说明
  - 非关键提示
  - 补充性描述文本

## Generation Config Layout

### 1. Window-Level Structure

`GenerationConfigWindowController` 改成与 Avatar Studio 接近的骨架：

1. 更薄的顶部区：标题、副标题、状态信息
2. 左侧能力导航
3. 右侧表单工作区
4. 右侧底部保存按钮

当前 capability 继续存在，但视觉上不再主要依赖顶部横向 tab 把空间占满，而是更像左侧导航切换工作区。

### 2. Basic vs Advanced Sections

右侧表单拆成两个清晰层级：

- `Basic`
  - `Provider`
  - `Model`
  - `Base URL`
- `Advanced`
  - `Auth`
  - `Options`

`Advanced` 默认收起。用户只有在需要时才展开对应 JSON 配置。

### 3. Input Control Changes

当前“所有字段都像单行输入框”的体验不适合该页面，因此改动如下：

- `Provider`
  - 优先改成更明确的选择控件，减少手填
- `Model`
  - 保留为核心文本输入，但增加高度与宽度优先级
- `Base URL`
  - 保留为核心文本输入，但与 `Model` 一样作为主编辑区中的宽输入
- `Auth`
  - 改成多行 JSON 编辑区域
- `Options`
  - 改成多行 JSON 编辑区域

这会直接解决“输入栏太小”这一当前页面的主要可用性问题。

### 4. Scrolling Strategy

`生成配置` 的滚动规则固定为：

- 左侧能力导航尽量固定
- 右侧表单区内部滚动
- 展开高级字段后，只让右侧局部变得可滚动
- 不靠继续拉高整个窗口去塞下更多输入框

## State Model Adjustments

### 1. Avatar Studio

在现有 `selectedTab` 和 `avatarTabMode` 之外，为新建自定义形象增加一个内部步骤态，例如：

- `editingPrompt`
- `editingMetadata`

约束如下：

- 未生成完整三态预览前，不能进入最终可保存完成态
- Step 2 不会清空 Step 1 已经生成的结果
- 返回浏览态时不自动保存任何资产

### 2. Generation Config

在现有 `selectedCapability` 之外，增加更明确的表单展示状态：

- `basic`
- `advancedExpanded`

切换 capability、保存失败或 JSON 校验失败时，应保留当前 capability 与当前展开状态，避免用户修错时迷失上下文。

## Error Handling

- `prompt` 优化失败时：
  - 不跳出当前视图
  - 不清空输入
  - 直接在当前状态区展示错误
- 预览生成失败时：
  - 保留已有 prompt
  - 保留已存在的其他预览结果
  - 允许用户在原位重试
- 保存失败时：
  - 保持在当前步骤
  - 保留用户已填写的名称和 persona
- `生成配置` 中 JSON 校验失败时：
  - 停留在当前 capability
  - 保持高级区域展开
  - 直接让用户在原位修复

## Testing Strategy

### Manual UI Verification

需要在更小屏幕条件下重点验证：

1. `更换形象` 浏览态不再表现为“整页过长看不全”
2. `新增自定义形象` 两步流清楚，主按钮容易发现
3. `生成配置` 高级字段默认折叠有效
4. `Auth / Options` 的多行编辑体验明显优于当前小单行框
5. 展开高级字段后，主要滚动发生在右侧工作区，而不是整窗继续拉长

### Regression Checks

还需要确认：

1. `主题风格 / 桌宠形象动画 / 话术` 三 tab 仍然能正常切换
2. 新建自定义形象仍遵循“先生成、再预览、满意后保存并应用”
3. `生成配置` 的保存与 JSON 校验逻辑不被布局改造破坏

## Risks

- 如果右侧工作区拆分不够清楚，虽然总高度下降，但用户可能感觉“内容被藏起来了”
- 如果步骤切换做得太像向导，可能削弱当前工作台一致性
- 如果 `Auth / Options` 改成多行区但没有保留足够的错误提示上下文，用户仍会觉得配置难填
- 如果小屏策略只改布局不改控件类型，`生成配置` 的输入体验问题仍不会真正解决

## Expected Outcome

完成后，这两个页面应更接近这样的体验：

- 小屏幕下首先看到的是主内容和主操作，而不是大段上下堆叠的说明
- `更换形象` 的浏览态和新建态职责更清楚
- `新增自定义形象` 的流程被压缩成更自然的两步式
- `生成配置` 的核心字段先露出，高级字段按需展开
- `Auth / Options` 不再因为输入框过小而难以编辑

## Note

由于当前协作约束不允许启用子代理，本次规格文档采用人工自审代替 spec-review 子代理流程。
