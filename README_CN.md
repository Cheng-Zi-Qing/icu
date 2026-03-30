# I.C.U. - 原生 macOS AI 桌宠

中文 | [English](README.md)

> 一个基于 Swift/AppKit 的 macOS 桌宠项目，默认提供像素风主题、工作状态机，
> 以及轻量的 `./icu` 本地启动入口。

[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](https://www.swift.org/)
[![Platform](https://img.shields.io/badge/Platform-macOS-green.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 当前运行形态

- `./icu` 默认拉起 `apps/macos-shell` 下的原生 Swift/AppKit shell。
- 当前默认 GUI 主题是像素风，已经覆盖桌宠、状态气泡、右键菜单、更换形象页和模型工作台。
- 运行时状态机是 `idle -> working -> focus/break -> working -> idle`。
- 冷启动时如果读到上次持久化的是活动态，会自动归一回 `idle`，但保留窗口位置。
- 首次启动会把桌宠放在屏幕右下角附近；后续启动会优先恢复上次仍然可见的位置。
- 轻量本地开发只需要 Apple Command Line Tools；完整 Xcode 只在你希望 `./icu --verify` 顺带跑 `swift test` 时才需要。
- Python 已经不参与应用启动链路，只保留在形象生成桥接上。
- 当前用户可见文案默认是简体中文，并且已经抽离为可覆盖资源。

## 当前可用能力

- 拉起一个悬浮桌宠，并通过菜单栏面板或桌宠右键菜单控制它。
- 通过 `更换形象` 打开统一工作台，里面分为 `主题风格`、`桌宠形象动画`、`话术` 三个 tab。
- 通过 `生成配置` 配置三类模型能力：`文本描述`、`动画形象`、`主题代码`。
- 所有 AI 生成都走统一节奏：先生成草稿和预览，不满意就重生成，满意后再应用。
- 可以切换内置桌宠，也可以保存 AI 生成的新形象。
- 可以不改代码直接覆盖用户可见文案。

## 🚀 快速开始

### 环境要求

- macOS
- Apple Command Line Tools 或 Xcode
- shell 中能直接执行 `swift`
- 可选：如果希望 `./icu --verify` 里顺带跑 `swift test`，需要完整 Xcode

轻量模式安装 Command Line Tools：

```bash
xcode-select --install
```

### 启动

```bash
git clone https://github.com/yourusername/icu.git
cd icu
./icu
```

这会直接从当前源码目录启动 Swift/AppKit 原生 shell。

启动行为说明：

- 首次启动会把桌宠放到屏幕右下角附近。
- 如果之前保存过仍然可见的位置，后续会自动恢复。
- 如果上次退出前停在 `working`，这次启动会先归一到 `idle`，不会一拉起就直接进入工作中。
- 启动脚本会自动使用隔离的 SwiftPM scratch path，因此一般不需要手工清 `apps/macos-shell/.build`。

### 校验

```bash
./icu --verify
```

这条命令会：

- 运行 `apps/macos-shell` 的 `swift build`
- 运行手工 runtime 校验
- 仅在当前环境启用了完整 Xcode 时才继续跑 `swift test`

如果机器上只有 Command Line Tools，这条命令仍然可用；脚本会明确跳过 `swift test`。

### 打包本地 `.app`

```bash
./icu --package-app
bash tools/check_macos_app_bundle.sh dist/ICU.app
```

底层脚本：

```bash
bash tools/run_macos_shell.sh
bash tools/verify_macos_shell.sh
```

如果要看打包、签名和 notarize 说明，见：

```bash
docs/macos-shell-release.md
```

发布环境变量模板：

```bash
tools/macos_shell_release.env.example
```

可选 release 风格校验：

```bash
VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 \
VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1 \
./icu --verify
```

### 运行时控制

菜单栏面板：

- `显示桌宠`
- `更换形象`
- `生成配置`
- `退出`

桌宠处于待机态时的右键菜单：

- `开始工作`
- `更换形象`
- `生成配置`
- `隐藏桌宠`
- `退出`

桌宠处于工作态时的右键菜单：

- `进入专注`
- `暂离`
- `下班`
- `更换形象`
- `生成配置`
- `隐藏桌宠`
- `退出`

桌宠处于专注或暂离态时的右键菜单：

- `回来工作`
- `下班`
- `更换形象`
- `生成配置`
- `隐藏桌宠`
- `退出`

当前提醒逻辑：

- 进入 `working` 会启动护眼提醒。
- 进入 `focus` 会暂停提醒。
- 从 `focus` 或 `break` 回到工作态后会重新启动提醒。
- 当前 Swift 迁移版已经落地的是护眼提醒；拉伸、补水、日报/周报等流程还没有完整迁移回来。

### 模型工作台（`生成配置`）

`生成配置` 只负责配置模型，不负责生成和应用内容。

当前能力分栏：

- `文本描述`：把 prompt 变成结构化文字意图
- `动画形象`：生成桌宠形象与动作素材
- `主题代码`：把文字意图变成主题草稿

当前支持的 provider：

- `ollama`
- `huggingface`
- `openai-compatible`

每一类能力都会保存这些字段：

- provider
- model
- base URL
- auth JSON
- options JSON

### 统一形象工作台（`更换形象`）

`更换形象` 才是生成、预览、重生成、应用真正发生的地方。

当前 tab：

- `主题风格`
- `桌宠形象动画`
- `话术`

当前统一操作流：

1. 输入原始 prompt。
2. 优化 prompt。
3. 生成预览。
4. 不满意就重生成。
5. 满意后再应用。

各 tab 的职责：

- `主题风格` 会先预览桌宠气泡、右键菜单和表单控件，再决定是否应用主题。
- `桌宠形象动画` 可以浏览已有形象，也可以生成新的 `idle`、`working`、`alert` 动作图，随后保存并应用。
- `话术` 会先生成文本草稿和真实气泡预览，再决定是否应用文案 override。

### 持久化与文件位置

运行时状态：

```bash
~/Library/Application Support/ICU/state/current_state.json
```

模型配置与当前主题选择：

```bash
~/Library/Application Support/ICU/config/settings.json
```

话术与用户可见文案 override：

```bash
~/Library/Application Support/ICU/config/copy/active.json
```

生成后的主题草稿：

```bash
~/Library/Application Support/ICU/state/themes/
```

以源码仓库模式运行时，AI 生成的新桌宠图片素材当前会保存到：

```bash
assets/pets/<avatar_id>/
```

高级用法：覆盖 App Support 根目录：

```bash
ICU_APP_SUPPORT_ROOT=/tmp/icu-dev ./icu
```

### Python 边界

现在只在形象生成桥接层保留 Python：

- `tools/avatar_builder_bridge.py`
- `builder/`

下面这些运行面已经是原生 Swift/AppKit，不再依赖旧 Python 启动路径：

- 应用启动
- 桌宠窗口
- 右键菜单
- 菜单栏面板
- 状态流转
- 主题运行时
- 气泡渲染

## 📚 科学依据

下面这些研究链接描述的是更完整的产品方向。当前 Swift shell 里已经真实启用的是护眼提醒；拉伸、补水和更丰富的报告能力仍然属于后续路线。

### 👁️ 护眼模块：20-20-20 法则与数字眼疲劳 (DES)

**核心研究：**
- **[The 20/20/20 rule: Practicing pattern and associations with asthenopic symptoms](https://pubmed.ncbi.nlm.nih.gov/37203083/)**
  - 证实遵循 20-20-20 法则（每 20 分钟看向 20 英尺外 20 秒）能有效降低眼干、烧灼感、视力模糊等视疲劳症状
  - [PMC 免费全文](https://pmc.ncbi.nlm.nih.gov/articles/PMC10391416/)

**进阶研究：**
- **[Digital Eye Strain - A Comprehensive Review](https://pmc.ncbi.nlm.nih.gov/articles/PMC9434525/)**
  - 使用电脑时眨眼频率断崖式下跌：从 18.4 次/分钟降至 3.6 次/分钟
  - 眨眼减少导致眼表泪膜破裂和水分蒸发，引发数字眼疲劳

### 🧘 拉伸模块：久坐对肌肉骨骼与认知的影响

**核心研究：**
- **[The Short Term Musculoskeletal and Cognitive Effects of Prolonged Sitting During Office Computer Work](https://pubmed.ncbi.nlm.nih.gov/30087262/)**
  - 连续静坐 2 小时后，全身肌肉骨骼不适感显著增加（尤其下背部）
  - 创造性解决问题时的错误率上升
  - 强烈建议通过"微休息"打断久坐
  - [PMC 免费全文](https://pmc.ncbi.nlm.nih.gov/articles/PMC6122014/)

**进阶研究：**
- **[Musculoskeletal neck pain in children and adolescents: Risk factors and complications](https://pmc.ncbi.nlm.nih.gov/articles/PMC5445652/)**
  - 头部中立姿势重量：4.54-5.44 公斤（10-12 磅）
  - 前倾姿势 (FHP) 导致颈椎负荷剧增：
    - 前倾 15°：12.25 公斤
    - 前倾 45°：22.23 公斤
    - 前倾 60°：27.22 公斤（60 磅）
  - 长期 FHP 导致"短信颈"综合征

### 💧 补水模块：轻度脱水对认知表现的影响

**核心研究：**
- **[The Hydration Equation: Update on Water Balance and Cognitive Performance](https://pmc.ncbi.nlm.nih.gov/articles/PMC4207053/)**
  - 仅 1-2% 体液流失（口渴感临界点）就会导致：
    - 精神疲劳增加
    - 注意力下降
    - 反应时间变慢
    - 情绪恶化
  - 不要等渴了再喝水 - 保持高频次、小口径摄入

**进阶研究：**
- **[Water, Hydration and Health](https://pmc.ncbi.nlm.nih.gov/articles/PMC2908954/)**
  - 肾脏最大排尿容积：约 1 升/小时
  - 一次性大量喝水无效 - 超量水分会迅速排出
  - 支持"少量多次、高频滴灌"补水策略

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| Swift 6 / SwiftPM | 原生 macOS shell |
| AppKit | 桌宠窗口与菜单交互 |
| Python 3.9+ | 仅用于形象生成 bridge（非启动链） |
| Ollama | 本地 AI（可选） |
| Hugging Face Inference API | 图像生成 |
| SQLite | 数据持久化 |

## 📁 项目结构

```
icu/
├── icu                     # Swift-first 根启动脚本 (`./icu`)
├── apps/
│   └── macos-shell/        # Swift/AppKit 运行时应用
├── builder/                # AI 生成工具
│   ├── prompt_optimizer.py # 提示词增强
│   ├── vision_generator.py # 图像生成
│   └── persona_forge.py    # 人设创建
├── src/                    # 剩余 legacy 非 UI Python 模块
├── docs/macos-shell-release.md # Swift shell 发布说明
├── assets/pets/            # 宠物形象与配置
└── config/                 # 用户设置
```

## 🎯 开发路线图

- [x] PRD 1.1: FSM + 健康提醒
- [x] PRD 1.2: 桌面宠物 UI
- [x] PRD 1.3: 报告 + AI 助手
- [x] PRD 1.4: 自定义形象创建器
- [ ] 多语言支持
- [ ] 云端同步（可选）
- [ ] 移动端伴侣应用

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

**Made with ❤️ for developers who care about health**
