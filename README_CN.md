# I.C.U. - 基于 FSM 的健康状态管理桌宠

中文 | [English](README.md)

> **I**ntelligent **C**are **U**nit - 专为极客与重度脑力工作者设计的轻量级、非侵入式健康状态管理桌宠
>
> 💡 **I.C.U. = I see u** - 我看见你了，别再久坐/盯屏幕/忘喝水！

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

### 🤖 AI-First 核心差异化

- **多维上下文感知引擎**：识别当前应用、剪贴板类型、键盘活动
- **零代码自定义形象**：AI 生成图像，1 分钟完成
- **人设系统**：AI 自动匹配话术风格
- **隐私保护**：所有敏感数据仅用于本地 AI 推理，不上传云端

## 📦 安装与启动

### 前置要求

- Python 3.9+
- macOS 或 Linux

### 快速启动

```bash
git clone https://github.com/yourusername/icu.git
cd icu
./icu
```

首次运行会自动安装依赖。

### 退出方式

- 右键点击桌宠 → 退出
- Menu Bar → 退出

### 开发模式

```bash
# 运行测试
python3 tests/test_core.py
python3 tests/test_integration.py
```

## 🚀 快速开始

1. **首次启动**：选择你喜欢的桌宠形象
2. **配置参数**：Menu Bar → 设置 → 输入体重和杯子容量
3. **开始工作**：Menu Bar → 开始工作
4. **状态切换**：
   - 需要专注时：Menu Bar → 进入专注
   - 暂时离开时：Menu Bar → 暂离
   - 下班时：Menu Bar → 下班

## 🛠️ 技术栈

| 技术 | 用途 |
|------|------|
| Python 3.9+ | 核心语言 |
| PySide6 | 桌宠 UI |
| rumps | macOS 菜单栏 |
| transitions | 有限状态机引擎 |
| SQLite | 数据持久化 |
| Ollama | 本地 AI（可选） |

## 📁 项目结构

```
icu/
├── icu                     # 启动脚本
├── src/
│   ├── __main__.py         # 应用入口
│   ├── state_machine.py    # FSM 核心
│   ├── menu_bar.py         # Menu Bar UI
│   ├── pet_widget.py       # 桌宠 UI
│   ├── reminder.py         # 提醒逻辑
│   ├── ai_assistant.py     # AI 文案（可选）
│   ├── report_generator.py # 报告生成
│   └── database.py         # SQLite 持久化
├── assets/pets/            # 桌宠形象资源
├── config/                 # 配置文件
└── tests/                  # 测试文件
```

## 🎯 开发路线图

- [x] PRD 1.1: FSM 核心 + 提醒系统
- [x] PRD 1.2: 桌宠 UI + 动画
- [x] PRD 1.3: 报告系统 + AI 扩展
- [ ] 每周报告
- [ ] 更多预设形象
- [ ] 云端同步（可选）

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

**Made with ❤️ for developers who care about health**
