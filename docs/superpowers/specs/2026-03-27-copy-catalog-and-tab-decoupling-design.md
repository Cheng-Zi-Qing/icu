# Copy Catalog And Tab Decoupling Design

**Date:** 2026-03-27

**Status:** Approved in terminal review

## Goal

在当前 macOS Swift 原生壳基础上补两件事：

- 把所有用户可见文案抽离成独立资源文件，允许后续替换、生成和组合
- 把更换形象工作台的三个 tab 彻底解耦，确保主题、形象、话术互不干扰、可自由搭配

本设计是对既有 avatar studio 设计的增量修订，不改变“配置页只管模型、更换形象页负责生成预览应用”的产品边界。

## Product Decisions

### 1. 文案资源独立

用户可见文案不再散落在窗口控制器、菜单模型、错误类型和默认预览数据里。

文案改为由独立资源文件驱动，并通过统一目录层访问。

资源层和主题、形象、话术三条链路保持独立：

- 主题可单独切换
- 形象可单独切换
- 话术可单独切换
- 文案资源也可单独切换

四者可以自由组合，不互相绑定。

### 2. 三个 Tab 的职责边界

`主题风格` tab 只负责展示和生成 GUI 样式。

允许出现的内容：

- 当前已应用样式摘要
- prompt 输入区
- GUI 样式预览
  - 右键菜单
  - 表单输入框
  - 按钮
  - 桌宠气泡 / 状态 chip 的样式
- 生成预览 / 重新生成 / 应用

不再出现：

- 形象信息
- 话术文本内容
- 模型编辑表单

`桌宠形象动画` tab 只负责展示和生成形象与动作。

允许出现的内容：

- 当前已应用形象摘要
- prompt 输入区
- 形象与动作预览
- 生成预览 / 重新生成 / 应用

不再出现：

- 样式预览说明
- 话术说明
- 不必要的模型摘要

`话术` tab 只负责展示和生成文本内容。

允许出现的内容：

- 当前已应用话术摘要
- prompt 输入区
- 文本预览
- 桌宠对话气泡预览
- 生成预览 / 重新生成 / 应用

不再出现：

- 样式说明
- 形象说明
- 与话术无关的 UI 组件预览

## Copy Resource Architecture

### 1. Resource Files

新增独立文案资源目录：

- `config/copy/base.json`

后续允许存在覆盖层：

- `config/copy/active.json`

加载顺序固定为：

1. `base.json`
2. `active.json`

`active` 只覆盖已有语义 key，不改代码结构。

### 2. File Shape

资源文件按领域分组，避免平铺和命名冲突：

- `common`
- `menu`
- `generation_config`
- `theme_studio`
- `avatar_studio`
- `speech_studio`
- `pet`
- `errors`

每个叶子节点都使用稳定语义 key，而不是直接使用界面字符串作为 key。

示例：

```json
{
  "common": {
    "apply_button": "应用",
    "regenerate_button": "重新生成",
    "preview_button": "生成预览",
    "close_button": "关闭"
  },
  "theme_studio": {
    "tab_title": "主题风格",
    "applied_summary_title": "当前已应用主题",
    "prompt_label": "prompt"
  }
}
```

### 3. Runtime Access Layer

Swift 侧新增统一目录层，例如：

- `TextCatalog`
- `UserVisibleCopyKey`

所有用户可见文案都必须通过目录层读取，不允许在 UI 控制器中继续写死字符串。

访问层职责：

- 加载 `base` 和 `active`
- 合并 override
- 提供按 key 读取的稳定接口
- 在 key 缺失时回退到 `base`

本次不做：

- 多语言系统
- 运行时在线翻译
- 热更新编辑器

## Scope Of “User Visible Copy”

本次要抽离：

- 窗口标题、副标题
- tab 名称
- 按钮标题
- 表单 label
- placeholder
- 状态提示
- 默认预览文本
- 默认桌宠气泡文本
- 用户可见错误描述
- 菜单项标题

本次不抽离：

- JSON 字段名
- 内部枚举 rawValue
- 配置文件结构 key
- HTTP payload 字段
- 纯内部日志
- 第三方原始错误对象

如果第三方错误需要展示给用户，必须先映射为平台定义的用户文案，再决定是否附带原始 details。

## UI Simplification Rules

### Theme Studio

预览区只保留样式层元素：

- 菜单
- 表单
- 按钮
- 气泡样式

这里的气泡只展示视觉样式，不承担话术内容创作。

### Avatar Studio

预览区只保留形象层元素：

- 当前形象
- 可选动作
- 生成后的草稿形象

不再展示 GUI 样式说明和话术样例。

### Speech Studio

预览区只保留文本层元素：

- 话术摘要
- 示例文本
- 气泡弹出文本

这里的气泡承担文本预览，不承担样式设计。

## Affected Code Areas

新增：

- `apps/macos-shell/Sources/ICUShell/Copy/`
- `config/copy/base.json`

重点修改：

- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift`
- `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
- `apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift`
- `apps/macos-shell/Sources/ICUShell/Avatar/AvatarBuilderBridge.swift`
- `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetMenuModel.swift`
- `apps/macos-shell/Sources/ICUShell/Menu/StatusItemMenuModel.swift`

测试需要覆盖：

- copy catalog 可加载 base / active
- key 缺失时的回退
- 三个 tab 的内容边界
- 现有 AppKit 手工运行测试中的用户可见文案来源切换

## Non-Goals

本次不做：

- 文案 AI 生成器本身
- 多语言国际化体系
- 文案编辑 GUI
- 主题、形象、话术的真实生成链路重写
- Python 侧所有历史脚本的全量文案资源化

## Implementation Notes

- 当前散落在原生 Swift 壳内的用户可见文案应优先迁入 copy catalog
- avatar studio 的三个 tab 需要按职责重新减重，而不是继续堆叠摘要卡片
- 后续如果要支持 AI 生成一套“说话风格”或“产品文案风格”，产物应直接落到独立 copy 文件，而不是写回主题文件或形象文件
