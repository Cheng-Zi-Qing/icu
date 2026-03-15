# I.C.U. - 基于 FSM 的健康状态管理桌宠

> **I**ntelligent **C**are **U**nit - 专为极客与重度脑力工作者设计的轻量级、非侵入式健康状态管理桌宠

[![Python](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)
[![macOS](https://img.shields.io/badge/macOS-11.0+-green.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📖 项目简介

I.C.U. 是一款基于有限状态机（FSM）架构的 macOS 桌面宠物应用，通过事件驱动的状态切换和科学的健康提醒算法，帮助开发者在保持心流的同时关注健康。

### 核心理念

- **0 打扰**：摒弃死板的定时器，采用手动状态切换，不打断心流
- **科学依据**：基于 20-20-20 法则、久坐微干预、认知水合作用等医学研究
- **个性化**：动态水合算法根据体重和杯容量定制提醒频率
- **可爱陪伴**：多种桌宠形象可选，支持自定义

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

### 🤖 AI 文案系统（可选）

- 集成本地 Ollama API，生成个性化提醒文案
- 每个形象预设独特人设和语气风格
- 降级方案：API 失败时使用默认文案库

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| Python 3.9+ | 核心语言 |
| PySide6 | 桌宠 UI（透明窗口、边缘吸附） |
| rumps | Menu Bar 状态切换 |
| transitions | 有限状态机引擎 |
| SQLite | 数据持久化 |
| Ollama API | AI 文案生成（可选） |

## 📦 安装

### 前置要求

- macOS 11.0+
- Python 3.9+
- （可选）Ollama（用于 AI 文案生成）

### 安装步骤

```bash
# 克隆仓库
git clone https://github.com/yourusername/icu.git
cd icu

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 运行应用
python main.py
```

### 可选：安装 Ollama

```bash
# 使用 Homebrew 安装
brew install ollama

# 下载推荐模型
ollama pull qwen2.5:7b
```

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

## 🙏 致谢

- 基于 20-20-20 法则的护眼提醒
- 久坐微干预研究
- 认知水合作用理论

---

**Made with ❤️ for developers who care about health**
