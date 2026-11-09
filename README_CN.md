# I.C.U. — 原生 macOS 桌宠

[中文](README_CN.md) | [English](README.md)

> 一个 Swift/AppKit 写的 macOS 桌宠。默认形象是像素风淡定水豚，工作时盯着你的健康，
> 有个衣柜可以给它换装，还能实时跟着你的 Claude Code 会话演小动作。

[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://www.swift.org/)
[![Platform](https://img.shields.io/badge/macOS-14%2B-green.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 它是什么

- **一只住在桌面上的宠物。** 像素风水豚，待机 / 工作 / 专注 / 暂离四种状态，逐帧动画，
  会转头看你鼠标、被你摸头、会打盹，闲着没事随机做点小动作。
- **工作时的健康提醒。** 护眼提醒（默认 20-20-20）和按体重、杯容量、每天工作时长算出来的喝水提醒。
- **能感知 Claude Code。** 你的 Agent 在干什么它就演什么，有会话在等你时它会冒张卡提醒你。
- **衣柜。** 装扮表在 `config/wardrobe.json`；带整套帧的装扮一换，所有动画跟着换。
- **不挡事。** 拖着有弹性物理，松手贴屏幕边，久了自动藏起来只探个头。
- **文案可覆盖。** 界面上所有文字都在 `config/copy/base.json`，改文案不用重新编译。

整个 app 都是 Swift/AppKit，没有 Python。

## 跑起来

```bash
git clone https://github.com/Cheng-Zi-Qing/icu.git
cd icu
./icu
```

需要 macOS 14 及以上和 Apple Command Line Tools（`xcode-select --install`），完整 Xcode 可选。

```bash
./icu --verify       # 编译 + 运行时检查，有 Xcode 时再跑 swift test
./icu --package-app  # 产出 dist/ICU.app
```

签名、公证和发布环境变量模板见 [`docs/macos-shell-release.md`](docs/macos-shell-release.md)。

## 日常使用

菜单栏：显示桌宠 · 衣柜 · 设置… · 接入 / 断开 Claude Code · 退出

右键桌宠：

- 待机 → 开始工作
- 工作中 → 进入专注 · 暂离 · 下班
- 专注 / 暂离 → 回来工作 · 下班
- 任何状态 → 衣柜 · 设置… · 隐藏桌宠 · 退出

开始工作会同时武装护眼和喝水提醒，进入专注和暂离暂停，下班全部停掉。提醒卡都很短，看完就能
划掉——护眼带倒计时，喝水显示「第 x/y 杯」。设置…里放体重、杯容量、每天工作几小时和护眼方式
（20-20-20 / 每小时歇歇 / 自定义），下面实时显示算出来的喝水计划。

## 接入 Claude Code

在菜单栏或宠物菜单里选「接入 Claude Code」：

- 会把 `icu-hook` 拷到 `<App Support>/ICU/bin/icu-hook` 并注册进 `~/.claude/settings.json`
  （尊重 `CLAUDE_CONFIG_DIR`）。第一次写之前会备份你的设置文件，你自己的钩子原样保留；
  卸载只删它加过的条目。
- 注册的每个钩子都是 `async`，Claude Code 不会因为桌宠卡住。
- 接上之后，Agent 在思考、读文件、搜代码、改文件、跑命令、派子 Agent 时桌宠分别演对应的小场景，
  有会话在等你批准或等你回话时会弹卡。

**隐私。** 钩子只记状态。提示词、命令、工具参数、模型回答、对话记录路径一律不落盘。
记的只有：会话 id、事件名、工具名、错误类型、项目文件夹名、前台 app 的 bundle id 和时间戳。

## 数据存在哪

全部在 `~/Library/Application Support/ICU/` 下：`config/` 放设置和文案覆盖，`state/` 放运行时状态和
健康指标，`agents/` 每个 Claude Code 会话一个 JSON，另有 `logs/` 和 `bin/`。
想整个挪别处用 `ICU_APP_SUPPORT_ROOT`。

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

## 许可证

MIT，见 [LICENSE](LICENSE)。

`assets/fonts/` 下的像素字体保留各自的许可证（OFL 等），在 `assets/fonts/LICENSES/`。
