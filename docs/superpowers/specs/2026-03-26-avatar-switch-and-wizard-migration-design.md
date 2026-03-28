# Avatar Switch And Wizard Migration Design

日期：2026-03-26

## 背景

当前 Swift/AppKit shell 已经成为默认启动路径，`./icu` 可以直接启动桌宠，但旧 Qt 路径中的两类关键能力还没有迁过来：

1. 用户无法在运行中的 Swift shell 里切换桌宠形象
2. 用户无法在 Swift shell 中新增自定义形象

旧版 Python/Qt 已经具备这些能力：

1. 桌宠右键菜单中有“更换形象”
2. 菜单栏/窗口流里有形象选择器
3. 有一套三步式自定义形象向导
4. 提示词优化、图像生成和 persona 生成复用了 `builder/*` 与 Ollama / Hugging Face

但 Swift shell 目前只在启动时读一次 `ICU_PET_ID`，然后加载静态资源。结果就是：

1. 用户默认路径虽然切到了 Swift，但功能反而比旧路径少
2. `config/settings.json` 中的 `avatar.current_id` 还没有成为 Swift 运行态的真实配置来源
3. “恢复形象切换体验”与“继续废弃 Qt UI”这两个目标同时悬空

## 目标

本次设计完成后，应满足以下条件：

1. 用户能从桌宠右键菜单切换任意现有形象
2. 用户能从菜单栏入口打开同一套“更换形象”流程
3. Swift shell 原生提供形象选择器
4. Swift shell 原生提供自定义形象向导
5. 当前形象持久化到 `config/settings.json`
6. 切换形象后桌宠立即刷新，不需要重启 `./icu`
7. 自定义向导的提示词优化、出图和 persona 生成继续复用 Python `builder/*`

## 非目标

1. 本次不迁移边缘吸附、自动隐藏、探头等窗口行为
2. 本次不重做提醒气泡系统
3. 本次不迁移“个人设置”和 “AI 配置”窗口
4. 本次不把 `builder/*` 的图像生成和 persona 生成链一次性改写成 Swift
5. 本次不实现自绘右键菜单来完全复刻 Qt 的像素风菜单外观

## 设计

### 1. 入口恢复策略

本次恢复两个入口，并收敛到同一个协调器：

1. 桌宠右键菜单增加“更换形象”
2. 菜单栏增加“更换形象”
3. 两处入口都调用同一个 `AvatarCoordinator`

`AvatarCoordinator` 负责：

1. 打开形象选择器
2. 打开自定义形象向导
3. 保存当前形象设置
4. 通知当前桌宠窗口刷新

这样可以避免：

1. 右键菜单和菜单栏各自维护一套逻辑
2. 向导保存成功后只更新一处入口、另一处入口状态滞后

### 2. 形象数据来源与配置持久化

新增两层运行态能力：

1. `AvatarCatalog`
2. `AvatarSettingsStore`

`AvatarCatalog` 负责扫描可用形象并产出列表项数据：

1. 首先扫描 `~/Library/Application Support/ICU/assets/pets`
2. 再扫描 repo 内 `assets/pets`
3. 若同一 `pet_id` 同时存在，优先采用 Application Support 版本

每个形象列表项至少包含：

1. `id`
2. `name`
3. `style`
4. `persona` 摘要
5. `base.png` 预览路径

`AvatarSettingsStore` 负责读写 `config/settings.json` 中的：

```json
{
  "avatar": {
    "current_id": "capybara"
  }
}
```

Swift shell 对当前形象的读取优先级改为：

1. `config/settings.json` 的 `avatar.current_id`
2. `ICU_PET_ID` 仅作为缺省回退
3. 最终回退到 `capybara`

这样可以避免环境变量长期覆盖用户在 UI 中做出的选择。

### 3. Swift 原生形象选择器

新增一个 Swift 原生选择器窗口，使用 AppKit 自定义风格面板实现。

功能要求：

1. 展示全部可用形象
2. 显示当前形象选中态
3. 显示预览图
4. 显示风格和 persona 摘要
5. 提供“选择”“取消”“新增自定义形象”按钮

视觉方向沿用旧版 Qt 的像素风语义，但不强行复制 Qt 组件：

1. 深色背景
2. 等宽字体
3. 绿色高亮
4. 明确的边框和块面
5. 预览与说明并排

### 4. Swift 原生自定义形象向导

新增一个 Swift 原生三步式向导：

1. 提示词输入与优化
2. 图像模型选择与动作图生成
3. persona 生成、名称填写与保存

流程仍保留旧版的产品节奏，但 UI 完全由 Swift/AppKit 提供。

保存结果时，由 Swift 负责最终落盘：

1. 写入 `assets/pets/<pet_id>/base.png`
2. 写入 `assets/pets/<pet_id>/idle/0.png`
3. 写入 `assets/pets/<pet_id>/working/0.png`
4. 写入 `assets/pets/<pet_id>/alert/0.png`
5. 写入 `assets/pets/<pet_id>/config.json`

保存成功后立即：

1. 重新扫描形象目录
2. 将新形象设为当前形象
3. 刷新桌宠显示

### 5. Python Builder Bridge

Swift 不直接散着调用 `builder/prompt_optimizer.py`、`builder/persona_forge.py` 等模块，而是通过单一桥接脚本调用：

`tools/avatar_builder_bridge.py`

桥接脚本对 Swift 暴露四个稳定动作：

1. `optimize-prompt`
2. `list-image-models`
3. `generate-image`
4. `generate-persona`

输出规则统一为 JSON：

1. 成功时输出结构化 JSON 到 stdout
2. 失败时输出结构化错误到 stdout 或 stderr，并以非 0 退出码结束

Swift 侧只关心：

1. 命令参数
2. 退出码
3. JSON 结果
4. 错误摘要

不关心底层具体 import 了哪些 Python 模块。

这样做的好处是：

1. 把 Python 依赖限制在一层薄桥接里
2. 以后彻底移除 Python 时，只需要替换桥接层
3. Swift UI 与底层生成链的契约边界清晰

### 6. 生成链的会话隔离

旧 `builder/*` 中有 checkpoint 目录和默认缓存逻辑，如果直接沿用默认 `/tmp/icu_build`，多个生成步骤可能互相覆盖，甚至把旧会话的结果带到新会话。

因此桥接脚本需要为每次向导会话使用独立临时目录，例如：

`/tmp/icu_avatar_bridge/<session-id>/`

要求：

1. 每次向导打开时分配一个唯一 `session-id`
2. 该会话内的提示词优化、出图和 persona 生成共享这个目录
3. 不同会话之间不能复用 checkpoint 文件

### 7. 图像模型选择的修补边界

旧版 Python 向导虽然提供了“图像模型选择”UI，但底层 `VisionGenerator` 目前仍写死了模型 ID，这意味着旧功能在实现上并没有真正打通。

本次迁移不应把这个问题原样带到 Swift。

因此本次需要做一个有边界的小修补：

1. 桥接层把选中的图像模型配置传给 Python
2. Python 图像生成器按传入模型 ID / URL 发起请求
3. 若未提供模型配置，再回退到当前默认模型

这仍然属于“继续复用 Python builder”，而不是重写 builder。

### 8. 运行时热切换

Swift shell 需要支持运行时换皮，而不是只在启动时决定 `pet_id`。

最小运行时刷新链路如下：

1. 用户从右键菜单或菜单栏选择新形象
2. `AvatarCoordinator` 写回 `config/settings.json`
3. 当前桌宠窗口控制器收到变更通知
4. `DesktopPetView` 更新 `petID`
5. 重新从 `PetAssetLocator` 加载图片
6. 当前桌宠立即显示新形象

这样可以保证“切换后立刻看到结果”，不再要求重启。

### 9. 样式和窗口行为边界

本次只恢复与“形象切换体验”直接相关的原生 UI 风格，不处理复杂窗口行为。

明确包含：

1. Swift 版选择器与向导的像素风语义
2. 右键菜单与菜单栏中的“更换形象”入口
3. 运行时即时切换

明确不包含：

1. 边缘吸附
2. 自动隐藏与探头
3. 自绘气泡系统
4. 自绘右键菜单替换 `NSMenu`

这些能力留到下一批“窗口行为与风格恢复”中处理。

## 备选方案比较

### 方案 A：Swift 原生 UI + Python Builder Bridge

优点：

1. 默认运行链继续保持 Swift-first
2. 用户能立刻拿回形象切换和自定义形象体验
3. Python 依赖被限制在一层明确桥接里

缺点：

1. 需要维护一层 Swift/Python 命令契约
2. 自定义向导仍然依赖 Ollama / HF_TOKEN 等外部环境

本次采用方案 A。

### 方案 B：Swift 只做入口，继续弹旧 PySide 向导

优点：

1. 初始改动最小

缺点：

1. 旧 Qt UI 会重新回到主用户路径
2. 迁移方向被破坏
3. 用户体验割裂

### 方案 C：一次性全部改写成 Swift

优点：

1. 长期最干净

缺点：

1. 范围过大
2. 会显著拖慢当前恢复可用性的节奏
3. 这批需求的核心是“恢复切换体验”，不是“全面替换生成链”

## 测试策略

### 运行态测试

验证以下内容：

1. `AvatarCatalog` 能扫描并列出形象
2. `AvatarSettingsStore` 能读写 `avatar.current_id`
3. 形象切换后 `DesktopPetView` 能立即刷新
4. 向导保存后新形象会出现在列表中

### Bridge 契约测试

验证以下内容：

1. Swift 能正确解析桥接脚本 stdout JSON
2. 非 0 退出码会被转成可读错误
3. 使用 stub bridge 时，不依赖 Ollama / HF_TOKEN 也能完成契约验证

### 手工 smoke test

验证以下内容：

1. 菜单栏入口能打开选择器
2. 桌宠右键菜单能打开选择器
3. 选择现有形象后立即生效
4. 新增自定义形象后无需重启即可切换成功
5. 重启 `./icu` 后仍保留上次选择的形象

## 风险

1. 如果继续只靠环境变量确定当前形象，UI 中的切换结果会在下次启动时失效。
2. 如果桥接层没有统一 JSON 契约，Swift 向导会到处散落命令拼接和错误处理。
3. 如果继续复用共享 checkpoint 目录，多个向导会话之间可能互相污染。
4. 如果图像模型选择仍然没有真正传到 Python 生成器，用户会得到“看起来能选，实际上没生效”的假功能。
5. 如果把边缘吸附和自动隐藏一并塞进这批工作，形象切换恢复节奏会明显变慢。

## 说明

由于当前协作约束不允许启用子代理，本次规格文档采用人工自审代替 spec-review 子代理流程。
