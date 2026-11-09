# I.C.U. — 原生 macOS 桌宠

[中文](README_CN.md) | [English](README.md)

> 一个 Swift/AppKit 写的 macOS 桌宠。默认形象是像素风淡定水豚，工作时盯着你的健康，
> 有个衣柜可以给它换装，还能实时跟着你的 Claude Code 会话演小动作。

[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://www.swift.org/)
[![Platform](https://img.shields.io/badge/macOS-14%2B-green.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 它是什么

- **一只住在桌面上的宠物。** 像素风水豚，待机 / 工作 / 专注 / 暂离四种状态，逐帧手绘动画，
  会转头看你鼠标、被你摸头、会打盹，闲着没事随机做点小动作。
- **工作时的健康提醒。** 护眼提醒（默认 20-20-20）和按体重、杯容量、每天工作时长算出来的喝水提醒。
- **能感知 Claude Code。** 接入后，你的 Agent 在读文件、搜代码、改文件、跑命令、派子 Agent 时，
  桌宠分别演对应的小场景；有会话在等你批准或等你回话时，它会冒张卡提醒你。
- **衣柜。** 装扮表在 `config/wardrobe.json`；带整套帧的装扮（目前是草帽）一换，所有动画跟着换。
- **不挡事的窗口行为。** 拖着有弹性物理，松手贴屏幕边，久了自动藏起来只探个头。
- **文案可覆盖。** 界面上所有文字都来自 `config/copy/base.json`，改文案不用重新编译。

这个项目已经没有 Python 了，整个 app 都是 Swift/AppKit。

## 快速开始

### 环境要求

- macOS 14 及以上
- Apple Command Line Tools（`xcode-select --install`）——够编译、够跑
- 完整 Xcode 可选，只在你想让 `./icu --verify` 里跑 `swift test` 时才需要

### 启动

```bash
git clone https://github.com/Cheng-Zi-Qing/icu.git
cd icu
./icu
```

它会用独立的 SwiftPM scratch 路径（`~/Library/Caches/icu/swiftpm/…`）跑
`swift run ICUShell`，不用手动清理 `.build`。

首次启动桌宠出现在右下角附近，之后恢复上次还在屏幕上的位置。退出时还开着的工作会话会被规范
回 `idle`，不会一开机就进 `working`。

### 校验

```bash
./icu --verify
```

按顺序做三件事：

1. 编译 `apps/macos-shell`
2. 跑手动运行时检查（`tools/check_native_shell.sh`，直接用 `swiftc`，不需要 Xcode）
3. 跑 `swift test`——只有当 `xcodebuild` 可用时才跑，否则明确跳过

### 打包本地 `.app`

```bash
./icu --package-app
bash tools/check_macos_app_bundle.sh dist/ICU.app
```

带发布级检查（bundle 结构 + 脱离终端的运行时冒烟测试）：

```bash
VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 \
VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1 \
./icu --verify
```

签名和公证说明见 [`docs/macos-shell-release.md`](docs/macos-shell-release.md)，
环境变量模板在 `tools/macos_shell_release.env.example`。

## 怎么用

### 菜单栏

| 菜单项 | 作用 |
|--------|------|
| 显示桌宠 | 把桌宠窗口显示出来 |
| 衣柜 | 打开衣柜窗口 |
| 设置… | 打开设置窗口 |
| 接入 / 断开 Claude Code | 装上或卸掉 Claude Code 钩子 |
| 退出 | 退出 app |

只有在 `icu-hook` 可执行文件找得到时，菜单里才会出现 Claude Code 那一项。

### 桌宠右键菜单

| 状态 | 菜单项 |
|------|--------|
| 待机 | 开始工作 |
| 工作中 | 进入专注 · 暂离 · 下班 |
| 专注 / 暂离 | 回来工作 · 下班 |
| 任何状态 | 衣柜 · 设置… ·（Claude Code）· 隐藏桌宠 · 退出 |

### 工作状态

`待机 → 工作 → 专注 / 暂离 → 工作 → 待机`

- **开始工作**：同时武装护眼和喝水提醒。
- **进入专注**：暂停两类提醒，桌宠换成专注的样子。
- **暂离**：同样暂停；**回来工作**重新武装，并且如果刚才专注得够久，桌宠会建议你歇一会儿。
- **下班**：全部停掉，包括还没到点的「等会儿」。

### 提醒卡

- **护眼**：带倒计时的卡片（20-20-20 是 20 秒，每小时歇歇是 5 分钟），三个操作——主按钮文字随机
  （看过了 / 好嘞 / 看完啦…）、「等会儿」（5 分钟后再来一次）、拒绝也是随机的（我就不 / 不要 / 偏不）。
  卡片标题同样随机抽，不会天天一个腔调。
- **喝水**：不倒计时，显示「第 x/y 杯」加 10 格进度条；超过目标是「超额 N 杯」。
- 提醒文案：卡片标题和按钮文字来自 `Pet/ReminderQuips.swift` 里的随机池；提醒那句话本身
  （`pet.eye_reminder` / `pet.hydration_reminder`）可以走文案表覆盖。

### 设置窗口

- **健康资料**：体重、杯子容量、每天工作几小时
- **提醒**：护眼方式——`20-20-20 推荐`（20 分钟 / 20 秒）、`每小时歇歇`（60 分钟 / 5 分钟）、
  `自定义`（60 秒到 4 小时）
- 下面实时显示算出来的喝水计划，例如「建议上班时喝 6 杯（约 2050 ml）」「每 80 分钟提醒一次」

喝水算法：每公斤体重每天 35 ml，工作时段喝掉其中 65%，按你的杯容量分成若干杯，一杯一次提醒。

### 衣柜

`config/wardrobe.json` 里每件装扮有槽位（`head` / `mouth` / `neck` / `face`）、稀有度和是否默认拥有，
另外配了好几套套装。带 `sprite_set` 的装扮（目前是草帽）在
`assets/pets/<pet>/outfits/<sprite_set>/` 下有一整套帧，待机、干活、拖拽、贴边探头、睡觉全都跟着换。

## 接入 Claude Code

桌宠可以跟着你的 Claude Code 会话。在菜单栏或宠物菜单里选「接入 Claude Code」：

- 会把 `icu-hook`（同一个 package 里的第二个可执行文件）拷到
  `<App Support>/ICU/bin/icu-hook`，并注册进 `~/.claude/settings.json`（尊重 `CLAUDE_CONFIG_DIR`）。
- 第一次写之前会备份你的 `settings.json`；你自己的钩子和其他设置原样保留。
- 注册的每个钩子都是 `async`，Claude Code 不会因为桌宠卡住。
- 卸载只删命令里带 `/bin/icu-hook` 的条目。

接上之后，桌宠按 Agent 在干的活演 `assets/pets/<pet>/work/scenes.json` 里的场景：
思考中、读取中、搜索中、更新中、运行 Bash、子 Agent 运行中。有会话在等你批准工具或等你回话时会弹卡，
方便你跳回对应的终端或 IDE。

**隐私边界。** `icu-hook` 只记状态。提示词、命令、工具参数、模型回答、对话记录路径一律不落盘。
记的只有：会话 id、事件名、工具**名**、错误类型、工作目录的最后一段（项目文件夹名）、
前台 app 的 bundle id 和时间戳。

## 数据存在哪

全部在 App Support 下：

```
~/Library/Application Support/ICU/
├── config/      # settings.json、衣柜存档、文案覆盖
├── state/       # current_state.json、健康指标
├── assets/      # 运行时安装的宠物
├── agents/      # 每个 Claude Code 会话一个 JSON，由 icu-hook 写
├── logs/
└── bin/         # 安装好的 icu-hook
```

开发时想把整棵树挪别处：

```bash
ICU_APP_SUPPORT_ROOT=/tmp/icu-dev ./icu
```

文案覆盖：在 `config/copy/active.json` 里放要改的键（先找 App Support，再找仓库），
没写的键保持原样。

### 仓库里的配置文件

| 文件 | 内容 |
|------|------|
| `config/settings.json` | 首次启动时的默认值：`edge_snap`、`timers`、`user` |
| `config/wardrobe.json` | 装扮表和现成套装 |
| `config/copy/base.json` | 界面上每一条文字 |

贴边那一组参数（`enabled`、`snap_distance`、`peek_width`、`auto_hide_delay`）启动时会读，
但设置窗口里还没有对应项，要改只能动 `config/settings.json`。

## 项目结构

```
icu/
├── icu                          # 根启动器：./icu [--verify|--package-app]
├── apps/macos-shell/            # 整个 app
│   ├── Sources/ICUShell/        # 主 target
│   │   ├── Agent/               # Claude Code 会话、钩子安装、Agent 面板
│   │   ├── Copy/                # 界面文案表 + 覆盖
│   │   ├── Health/              # 健康资料、喝水计划、指标存储
│   │   ├── Menu/                # 菜单栏面板
│   │   ├── Pet/                 # 宠物窗口、动画、行为、拖拽、贴边、干活场景
│   │   ├── Runtime/             # 状态机、设置、持久化、素材查找
│   │   ├── Settings/            # 设置窗口（像素风表单控件）
│   │   ├── Theme/               # 像素主题
│   │   ├── UI/Pixel/            # 像素按钮 / 字体 / 图标 / 绘制 / 窗口
│   │   └── Wardrobe/            # 装扮表、窗口、状态
│   ├── Sources/ICUHook/         # Claude Code 钩子可执行文件
│   ├── Tests/ICUShellTests/     # 单元测试（swift test）
│   └── Tests/ManualRuntime/     # 无头 AppKit 运行时检查
├── assets/
│   ├── fonts/                   # 像素字体及其许可证
│   └── pets/capybara/           # 帧、config.json、装扮、光标
├── config/                      # settings.json、wardrobe.json、copy/base.json
├── tools/                       # 编译 / 校验 / 打包 / 测试脚本
│   └── pixel_pets/capybara/     # 生成宠物帧的 Node 管线
└── docs/                        # 发布指南、动画引擎设计
```

### 宠物素材布局

```
assets/pets/capybara/
├── config.json        # id、名字、风格、人设备注（仅作记录）、动画参数
├── base.png           # 兜底静态图
├── idle/              # 待机动画，一个目录一个变体（main、chew）
├── idle_act/          # 随机小动作（bird、wobble）
├── react/ sleep/      # 被摸、打盹、醒来
├── work/              # Agent 干活场景 + scenes.json
├── drag/ edge/        # 拎起 / 转晕帧、贴边探头和转身帧
├── cursor/            # grab / grabbing / pat 光标
├── ui/                # 菜单栏和衣柜图标
└── outfits/           # 按装扮覆盖的帧
```

`config.json` 的 `animations` 给每个状态配 `fps`、`loop_mode`、`default_variant`。
`persona` 那段目前只是文档，app 还没有读它。
`work/scenes.json` 把场景名映射到关键帧顺序和 fps；`"motion": "chase"` 表示边演边把窗口左右挪
（搜索时追球）。

### 重新生成宠物素材

帧是一个小 Node 管线产出的，不是手抠的：

```bash
node tools/pixel_pets/capybara/build.mjs      # 渲染全部素材
node tools/pixel_pets/capybara/validate.mjs   # 校验产物
node tools/pixel_pets/capybara/editor.js      # 本地像素编辑器
```

## 技术栈

| 技术 | 用途 |
|------|------|
| Swift 5.10 / SwiftPM | 整个 app，两个可执行文件（`ICUShell`、`icu-hook`） |
| AppKit / Core Animation | 宠物窗口、菜单、面板、分层像素动画 |
| Node.js | 像素素材管线（`tools/pixel_pets/`） |
| Claude Code 钩子 | Agent 会话感知 |

## 科学依据

提醒节奏参照下面这些已发表研究，设置界面里引用的就是它们。

### 护眼：20-20-20 与数字眼疲劳

- **[The 20/20/20 rule: Practicing pattern and associations with asthenopic symptoms](https://pubmed.ncbi.nlm.nih.gov/37203083/)**
  （Talens-Estarelles 等，*Contact Lens & Anterior Eye* 46:101744，2023）——用提醒落实 20-20-20
  能减轻眼疲劳和干眼症状。[全文](https://pmc.ncbi.nlm.nih.gov/articles/PMC10391416/)
- **[Digital Eye Strain — A Comprehensive Review](https://pmc.ncbi.nlm.nih.gov/articles/PMC9434525/)**
  ——看屏幕时眨眼频率从约 18.4 次/分掉到 3.6 次/分，泪膜破裂加快。
- **[A field study of supplementary rest breaks for data-entry operators](https://pubmed.ncbi.nlm.nih.gov/10877480/)**
  （Galinsky 等，*Ergonomics* 43(5):622，2000）——每天多加两次 15 分钟休息，肌肉不适和眼酸都减少，
  产出不降；这就是「每小时歇歇」预设的依据。

### 拉伸：久坐

- **[The short term musculoskeletal and cognitive effects of prolonged sitting during office computer work](https://pubmed.ncbi.nlm.nih.gov/30087262/)**
  ——连续坐 2 小时后肌肉骨骼不适明显上升，创造性解题的错误率也上升。
  [全文](https://pmc.ncbi.nlm.nih.gov/articles/PMC6122014/)
- **[Assessment of stresses in the cervical spine caused by posture and position of the head](https://pubmed.ncbi.nlm.nih.gov/25393825/)**
  （Hansraj，*Surgical Technology International* 25:277，2014）——颈椎负荷从正中位的约 4.5–5.4 kg
  升到前倾 15° 的约 12.2 kg、45° 的 22.2 kg、60° 的 27.2 kg。
- **[Musculoskeletal neck pain in children and adolescents: Risk factors and complications](https://pmc.ncbi.nlm.nih.gov/articles/PMC5445652/)**
  ——该研究纳入的受试者全部报告学习和 / 用手机时存在错误的颈背屈曲姿势。

### 补水：轻度脱水

- **[The Hydration Equation: Update on Water Balance and Cognitive Performance](https://pmc.ncbi.nlm.nih.gov/articles/PMC4207053/)**
  ——体液流失 1–2 % 就足以加重精神疲劳、降低注意力、减慢反应速度；口渴是迟到的信号。
- **[Water, Hydration and Health](https://pmc.ncbi.nlm.nih.gov/articles/PMC2908954/)**——肾脏每小时
  最多排约 1 L 尿，一次猛灌大量水会被直接排掉；少量多次更有效，所以喝水计划是分成杯的。

目前实现的是护眼和喝水提醒。**拉伸提醒还没有**——`config/settings.json` 里的 `stretch_interval`
现在没有任何代码读它。

## 开发路线图

已完成：

- 桌宠本体：状态机、分层像素动画、眼神跟随、摸头、打盹
- 护眼与喝水提醒，支持「等会儿」
- 设置窗口：健康资料 + 护眼方式预设
- 衣柜与整套换装帧
- 贴边吸附、自动藏边、探头扒边
- 拖拽物理：拉伸与拎起姿势
- Claude Code 会话感知（钩子不记对话内容）
- 文案表覆盖
- 本地 `.app` 打包、bundle 检查、运行时冒烟测试

还没做：

- 拉伸 / 久坐提醒（上面的研究就是依据，缺口在 `stretch_interval` 没人读）
- 健康指标看板和日报 / 周报（`Health/HealthMetricsStore.swift` 里已经有原始事件和按日 / 周的
  汇总计算，但没有任何界面去渲染）
- 更多宠物（素材管线支持，目前只发了水豚）
- 剩下装扮的整套帧（目前只有草帽有）
- 多语言（文案是简体中文，但文案表就是为覆盖设计的）
- 云同步

## 许可证

MIT，见 [LICENSE](LICENSE)。

`assets/fonts/` 下的像素字体保留各自的许可证（OFL 等），在 `assets/fonts/LICENSES/`。
