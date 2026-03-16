# I.C.U. - 基于 FSM 的健康状态管理桌宠

> **I**ntelligent **C**are **U**nit - 专为极客与重度脑力工作者设计的轻量级、非侵入式健康状态管理桌宠

[![Python](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-green.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📖 项目简介

I.C.U. 是一款基于有限状态机（FSM）架构的轻量级桌面健康助手，通过事件驱动的状态切换和科学的健康提醒算法，帮助开发者在保持心流的同时关注健康。

### 核心理念

- **极致轻量**：纯 Python 实现，最小依赖，资源占用低
- **跨平台**：支持 macOS 和 Linux
- **0 打扰**：摒弃死板的定时器，采用手动状态切换，不打断心流
- **科学依据**：基于 20-20-20 法则、久坐微干预、认知水合作用等医学研究
- **AI-First**：本地隐私 AI + 上下文感知 + 零代码自定义形象

## ✨ 核心功能

### 🔄 四种工作状态

| 状态 | 图标 | 说明 | 行为 |
|------|------|------|------|
| 待机/下班 | 🛌 | 零资源消耗 | 销毁所有计时器，生成每日报告 |
| 工作/活跃 | 💻 | 主循环运行 | 护眼(20min)、拉伸(45min)、补水(动态) |
| 深度专注 | 🔕 | 冻结计时器 | 屏蔽弹窗，记录健康负债 |
| 暂离/餐饮 | ☕ | 重置计时器 | 离开期间不产生健康负债 |

### 💧 动态水合算法

```
每日总需水量 = 体重(kg) × 35ml
工作期间需水量 = 每日总需水量 × 65%
动态提醒间隔 = 工作时长 ÷ (需水量 ÷ 杯容量)
```

- 自动根据体重和杯子容量计算提醒频率
- 安全阈值：间隔 30-120 分钟
- 多梯度反馈：一口干了(+100%) / 喝了半杯(+50%) / 稍后再喝

### 📊 健康提醒与记录

- **护眼提醒**：每 20 分钟，基于 20-20-20 法则
- **拉伸提醒**：每 45 分钟，预防久坐伤害
- **补水提醒**：动态间隔，个性化定制
- **专注补偿**：退出专注状态时，根据时长弹出补偿提醒

所有提醒均记录用户响应（已完成/延迟/忽略），用于生成报告。

### 📈 每日/每周报告

**每日报告**（下班时自动生成）：
- 工作时长统计（总时长、专注次数、暂离次数）
- 健康行为达成率（护眼、拉伸、补水）
- 家庭任务派发（回家需补水量）

**每周报告**（每周日生成）：
- 本周工作概览（总时长、日均时长、专注占比）
- 健康行为趋势（折线图、柱状图）
- 个性化改进建议

### 🤖 AI-First 核心差异化

#### 多维上下文感知引擎

本地收集工作上下文，生成精准提醒：
- **当前应用**：识别 VS Code / iTerm2 等开发工具
- **剪贴板类型**：检测报错信息（不上传内容）
- **键盘活动**：判断是陷入沉思还是疯狂赶代码
- **健康负债**：连续专注时长与缺水毫秒数

**隐私保护**：所有敏感数据仅用于本地 AI 推理，不上传云端。

#### 零代码自定义形象

传统桌宠需要 2-7 天手绘动画，I.C.U. 只需 **1 分钟**：

1. 输入 Prompt："一只戴眼镜的程序员猫，像素风格"
2. AI 生成图像（DALL-E 3）
3. 自动生成 8 种状态动画（浮动/摇摆/拉伸/跳跃）
4. 一句话描述人设："佛系禅意的卡皮巴拉"
5. AI 自动匹配话术风格

#### AI 分层架构

- **形象生成**：云端多模态（DALL-E 3 / Replicate）
- **文案生成**：
  - 简单模式：云端/本地可选
  - 高级模式：仅本地 Ollama + 上下文感知

### 🎨 桌宠形象系统

内置 5 种预设形象，支持自定义：

| 形象 | 性格 | 风格 |
|------|------|------|
| 仰卧起坐海豹 | 努力励志 | 16-bit 像素风 |
| 苦逼的牛 | 丧系吐槽 | 16-bit 像素风 |
| 苦逼的马 | 悲惨 emo | 8-bit 复古风 |
| 淡定水豚 | 佛系禅意 | 16-bit 像素风 |
| 社畜人类 | 真实打工人 | 16-bit 像素风 |

**动画引擎**：只需提供 1 张静态图，代码自动生成所有状态动画（浮动、摇摆、拉伸、跳跃等）

### 🤖 灵活的文案系统

三种模式可选：

1. **固定话术**（默认）：零依赖，内置文案库
2. **本地大模型**：调用 Ollama 等本地 API
3. **云服务**：调用 OpenAI/Claude 等云端 API

每个形象预设独特人设和语气风格，自动降级保证可用性。

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| Python 3.9+ | 核心语言 |
| tkinter | 轻量级 GUI（Python 内置） |
| transitions | 有限状态机引擎 |
| SQLite | 数据持久化（Python 内置） |
| requests | HTTP 请求（可选，用于云服务） |

**设计原则**：最小依赖，开箱即用

## 📦 安装

### 前置要求

- Python 3.9+
- macOS 或 Linux

### 安装步骤

```bash
# 克隆仓库
git clone https://github.com/yourusername/icu.git
cd icu

# 安装依赖（仅需一个外部包）
pip install transitions

# 运行应用
python main.py
```

### 可选：配置 AI 文案

**本地模型（推荐）：**
```bash
# 安装 Ollama
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5:7b
```

**云服务：**
在配置文件中设置 API Key（支持 OpenAI/Claude/其他兼容服务）

## 🚀 快速开始

1. **首次启动**：选择你喜欢的桌宠形象
2. **配置参数**：Menu Bar → 设置 → 输入体重和杯子容量
3. **开始工作**：Menu Bar → 开始工作
4. **状态切换**：
   - 需要专注时：Menu Bar → 进入专注
   - 暂时离开时：Menu Bar → 暂离
   - 下班时：Menu Bar → 下班

## 📁 项目结构

```
icu/
├── main.py                 # 应用入口
├── src/
│   ├── state_machine.py    # FSM 核心
│   ├── menu_bar.py         # Menu Bar UI
│   ├── pet_widget.py       # 桌宠 UI
│   ├── hydration.py        # 动态水合算法
│   ├── reminder.py         # 提醒逻辑
│   ├── database.py         # SQLite 持久化
│   ├── report_generator.py # 报告生成
│   └── ai_assistant.py     # AI 文案（可选）
├── assets/
│   └── pets/               # 桌宠形象资源
│       ├── seal/
│       ├── cow/
│       └── ...
├── config/
│   └── pets.json           # 形象配置
├── tests/                  # 测试文件
└── docs/                   # 文档
    └── prd/                # PRD 文档
```

## 🎯 开发路线图

- [x] PRD 文档完成
- [ ] Phase 1: FSM 核心 + Menu Bar UI
- [ ] Phase 2: 桌宠 UI + 动画 + 形象系统
- [ ] Phase 3: 动态水合算法 + 提醒逻辑
- [ ] Phase 4: SQLite 持久化 + 数据记录
- [ ] Phase 5: 每日/每周报告生成
- [ ] Phase 6: AI 文案集成（可选）
- [ ] Phase 7: 测试 + 打包

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

### 开发环境设置

```bash
# 安装开发依赖
pip install -r requirements-dev.txt

# 运行测试
pytest

# 代码格式化
black src/
```

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 📚 科学依据

本项目的健康提醒算法基于以下科学研究：

### 护眼模块：20-20-20 法则与数字眼疲劳

**The 20/20/20 rule: Practicing pattern and associations with asthenopic symptoms**

详细研究了 20-20-20 法则的实际执行情况，证实了遵循该法则（每 20 分钟看向 20 英尺外 20 秒）能有效干预和降低眼干、烧灼感、视力模糊等视疲劳（Asthenopia）症状。

- PubMed: https://pubmed.ncbi.nlm.nih.gov/37203083/
- 免费全文: https://pmc.ncbi.nlm.nih.gov/articles/PMC10391416/

### 拉伸模块：久坐的肌肉骨骼与认知影响

**The Short Term Musculoskeletal and Cognitive Effects of Prolonged Sitting During Office Computer Work**

通过实验室测试证实，在办公室电脑前连续静坐 2 小时后，不仅全身所有区域的肌肉骨骼不适感会显著增加（尤其是下背部），且受试者的"创造性解决问题"时的错误率也会上升。论文强烈建议必须通过"微休息（Micro-breaks）"来打断久坐。

- PubMed: https://pubmed.ncbi.nlm.nih.gov/30087262/
- 免费全文: https://pmc.ncbi.nlm.nih.gov/articles/PMC6122014/

### 补水模块：轻度脱水对认知表现的影响

**The Hydration Equation: Update on Water Balance and Cognitive Performance**

权威综述性文献指出：仅仅 1% 到 2% 的轻度体液流失（这正好是引发"口渴感"的临界点），就足以导致精神疲劳、注意力下降、反应时间变慢以及情绪恶化。这印证了不要等渴了再喝水，必须在工作期间高频次、小口径地摄入。

- 免费全文: https://pmc.ncbi.nlm.nih.gov/articles/PMC4207053/

---

**Made with ❤️ for developers who care about health**
