# I.C.U. - 你的 AI 健康伙伴

中文 | [English](README.md)

> **I**ntelligent **C**are **U**nit - 可自定义的桌面宠物，在你编码时守护健康
>
> 💡 **I.C.U. = I see u** - 你的专属健康守护者，有个性！

[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](https://www.swift.org/)
[![Platform](https://img.shields.io/badge/Platform-macOS-green.svg)](https://www.apple.com/macos/)
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

这会直接启动 Swift/AppKit 原生 shell。

快速校验命令：

```bash
./icu --verify
```

打包本地 `.app`：

```bash
./icu --package-app
bash tools/check_macos_app_bundle.sh dist/ICU.app
```

### 原生 macOS shell 校验

对于 `apps/macos-shell` 下的 Swift/AppKit shell，简短本地校验命令是：

```bash
./icu --verify
```

这个命令会：
- 运行针对 `apps/macos-shell` 的 `swift build`，并自动使用隔离 scratch path，避免旧 `.build` 缓存污染
- 运行手工 runtime 校验脚本
- 仅在当前环境启用了 Xcode 时才追加 `swift test`，同样走隔离 scratch path

如果机器上只有 `Command Line Tools`，这条命令仍然可用；脚本会明确跳过 `swift test`，而不是直接失败。

底层脚本仍可单独运行：

```bash
bash tools/verify_macos_shell.sh
```

如果要顺手做一次 `.app` release smoke check，可以运行：

```bash
VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 ./icu --verify
```

如果要本地启动原生 shell，运行：

```bash
./icu
```

启动脚本也会自动使用隔离 scratch path，所以不需要再手动清 `apps/macos-shell/.build`。

底层启动脚本仍可单独运行：

```bash
bash tools/run_macos_shell.sh
```

如果要看发布、签名和 notarize 的完整说明，见：

```bash
docs/macos-shell-release.md
```

启动后建议检查：
- 右键桌宠，确认至少能看到 `开始工作 / 进入专注 / 暂离 / 回来工作 / 下班 / 更换形象 / 退出`
- 打开 `菜单栏 -> 更换形象`，确认会出现 Swift 版形象选择器
- 确认生成了 `~/Library/Application Support/ICU/state/current_state.json`
- `ICU_PET_ID=<pet_id>` 现在只作为首次启动回退；日常切换应使用 Swift UI

### 首次设置

1. **选择宠物**：从内置形象中选择或创建自定义形象
2. **配置健康设置**：
   - 菜单栏 → 个人设置
   - 输入体重和杯子容量
3. **可选 AI 设置**：
   - 菜单栏 / 右键菜单 → 模型配置
   - 配置本地 Ollama 或远程 AI 模型

当前用户配置会写到：

```bash
~/Library/Application Support/ICU/config/settings.json
```

桌宠话术 override 会写到：

```bash
~/Library/Application Support/ICU/config/copy/active.json
```

### 日常使用

1. **开始一天**：菜单栏 → 开始工作
2. **保持健康**：响应宠物的温柔提醒
3. **需要专注？**：菜单栏 → 进入专注（暂停提醒）
4. **休息一下**：菜单栏 → 暂离（重置计时器）
5. **结束一天**：菜单栏 → 下班（生成每日报告）

### 创建自定义宠物

1. 菜单栏 → 更换形象，或右键桌宠 → 更换形象
2. **步骤 1**：描述你的宠物（例如："一只淡定的水豚"）
3. **步骤 2**：AI 优化提示词并生成图像
4. **步骤 3**：AI 创建人设和消息
5. 完成！你的独特宠物已就绪

### AI 配置

**三种模型类型：**
- **本地模型**：Ollama 用于提示词优化和人设生成
- **远程文本模型**：OpenAI、Claude 或自定义 API
- **图像模型**：Stable Diffusion 或 HuggingFace 模型

访问方式：菜单栏 / 右键菜单 → 模型配置

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
