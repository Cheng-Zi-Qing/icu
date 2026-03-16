# I.C.U. - 你的 AI 健康伙伴

中文 | [English](README.md)

> **I**ntelligent **C**are **U**nit - 可自定义的桌面宠物，在你编码时守护健康
>
> 💡 **I.C.U. = I see u** - 你的专属健康守护者，有个性！

[![Python](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-green.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 🌟 I.C.U. 的特别之处

### 🎨 完全可自定义的形象与人设
- **AI 生成宠物**：几分钟内创建独一无二的桌面伙伴
- **自定义人设**：每个宠物都有自己的语气、特质和消息
- **内置收藏**：水豚、奶牛、马、海豹等
- **零代码创建**：只需描述你想要的，AI 完成其余工作

### 💪 基于科学的健康管理
- **智能提醒**：护眼（20-20-20 法则）、拉伸休息、补水追踪
- **动态算法**：基于体重的个性化饮水量
- **心流友好**：手动状态控制 - 永不打断专注
- **周报统计**：追踪健康习惯和改进

### 🤖 AI 优先设计
- **本地隐私**：所有 AI 处理都在本地完成
- **上下文感知**：理解你正在做什么
- **人设系统**：宠物以符合角色的方式回应
- **多模型支持**：Ollama 本地模型 + 远程 API + 图像生成

## ✨ 核心功能

### 🎭 创建你的完美宠物

**三种获取方式：**
1. **选择内置宠物**：水豚、奶牛、马、海豹、人类
2. **AI 生成自定义宠物**：描述你理想的宠物，AI 创建它
3. **上传自己的**：让你最喜欢的角色活起来

**人设系统：**
- 每个宠物都有独特的特质和说话风格
- AI 生成的上下文消息
- 可自定义人设描述
- 符合角色的回应

### 💊 有效的健康管理

**智能工作状态：**
- **待机** 🛌：休息模式，生成每日健康报告
- **工作** 💻：主动健康监测与提醒
- **专注** 🔕：暂停提醒，追踪健康负债
- **暂离** ☕：重置计时器，无惩罚

**科学提醒：**
- **护眼**：20-20-20 法则（每 20 分钟，看 20 英尺外 20 秒）
- **拉伸**：每 45 分钟运动休息
- **补水**：基于体重的动态间隔

**个性化补水：**
```
每日总需水量 = 体重(kg) × 35ml
工作期间需水量 = 每日总需水量 × 65%
提醒间隔 = 工作时长 ÷ (需水量 ÷ 杯容量)
```

### 📊 追踪你的进步
- 每日健康报告与统计
- 周报总结和趋势
- 提醒完成率
- 专注模式下的健康负债追踪

## 🚀 快速开始

### 安装

```bash
git clone https://github.com/yourusername/icu.git
cd icu
./icu
```

首次运行会自动安装依赖。

### 首次设置

1. **选择宠物**：从内置形象中选择或创建自定义形象
2. **配置健康设置**：
   - 菜单栏 → 个人设置
   - 输入体重和杯子容量
3. **可选 AI 设置**：
   - 菜单栏 → AI 配置
   - 配置本地 Ollama 或远程 AI 模型

### 日常使用

1. **开始一天**：菜单栏 → 开始工作
2. **保持健康**：响应宠物的温柔提醒
3. **需要专注？**：菜单栏 → 进入专注（暂停提醒）
4. **休息一下**：菜单栏 → 暂离（重置计时器）
5. **结束一天**：菜单栏 → 下班（生成每日报告）

### 创建自定义宠物

1. 菜单栏 → 更换形象 → 新增自定义形象
2. **步骤 1**：描述你的宠物（例如："一只淡定的水豚"）
3. **步骤 2**：AI 优化提示词并生成图像
4. **步骤 3**：AI 创建人设和消息
5. 完成！你的独特宠物已就绪

### AI 配置

**三种模型类型：**
- **本地模型**：Ollama 用于提示词优化和人设生成
- **远程文本模型**：OpenAI、Claude 或自定义 API
- **图像模型**：Stable Diffusion 或 HuggingFace 模型

访问方式：菜单栏 → AI 配置

## 📚 科学依据

I.C.U. 的健康提醒基于同行评审的研究：

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
| Python 3.9+ | 核心语言 |
| PySide6 | 桌宠 UI 与对话框 |
| rumps | macOS 菜单栏 |
| Ollama | 本地 AI（可选） |
| HuggingFace | 图像生成 |
| SQLite | 数据持久化 |

## 📁 项目结构

```
icu/
├── icu                     # 启动脚本
├── src/
│   ├── pet_widget.py       # 桌面宠物 UI
│   ├── menu_bar.py         # 菜单栏控制
│   ├── avatar_wizard.py    # 自定义宠物创建器
│   ├── ai_config_dialog.py # AI 模型配置
│   ├── reminder.py         # 健康提醒
│   ├── daily_stats.py      # 统计追踪
│   └── weekly_report.py    # 周报总结
├── builder/                # AI 生成工具
│   ├── prompt_optimizer.py # 提示词增强
│   ├── vision_generator.py # 图像生成
│   └── persona_forge.py    # 人设创建
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
