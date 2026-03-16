# 竞品调研与差异化设计

## 一、技术架构调研

### 1. Shijima-Qt - 跨平台渲染天花板

**项目地址**: https://github.com/pixelomer/Shijima-Qt

**技术栈**: C++ / Qt6

**核心架构**:
- `PlatformWidget.hpp` - 平台抽象层，处理 macOS/Linux/Windows 差异
- `ShijimaWidget.cc/hpp` - 无边框透明窗口核心
- `AssetLoader.cc/hpp` - 资源加载管道
- `ShijimaHttpApi.cc/hpp` - HTTP API 外部控制接口

**可借鉴点**:
- ✅ **窗口穿透实现**: Qt6 的 `FramelessWindowHint` + 透明背景
- ✅ **资源加载机制**: 支持 zip/rar/7z 压缩包直接加载角色
- ✅ **模块化设计**: Platform 目录分离平台特定代码
- ⚠️ **局限**: C++ 实现，无 AI 集成，角色资源需手动制作

---

### 2. ProDOGtivity - Python 桌宠 + 任务管理

**项目地址**: https://github.com/linyanna/ProDOGtivity

**技术栈**: Python

**核心架构**:
- `Pet.py` - 主入口，桌面宠物 UI
- Canvas API 集成 - 通过 API Key 拉取课程作业
- 事件驱动 UI - Options 按钮触发配置窗口
- 双重任务源 - Canvas 自动 + 手动输入

**可借鉴点**:
- ✅ **Python UI 与调度器结合**: 事件驱动模式
- ✅ **外部 API 集成**: Canvas API 认证流程
- ⚠️ **局限**: 无 AI 能力，动画资源固定，针对学生场景

---

### 3. TamoStudy - 番茄钟 + 拓麻歌子

**项目地址**: https://github.com/narlock/TamoStudy

**技术栈**: Java 8

**核心架构**:
- **Timer 系统**: Pomodoro / Custom Interval / Stopwatch 多模式
- **成就系统**: 12 项成就，4 大类别（时长/外观/连续性/宠物状态）
- **数据持久化**: JSON-simple，存储在 `Documents/TamoStudy/`
- **虚拟宠物状态**: 经验值/快乐度/饥饿度，Tamo Tokens 货币系统

**可借鉴点**:
- ✅ **成就系统设计**: 时长里程碑（24/72/240/1200 小时）
- ✅ **宠物状态管理**: 饥饿度/快乐度与工作时长绑定
- ✅ **多代宠物**: 宠物死亡后可查看历史，支持多代进化
- ⚠️ **局限**: Java 实现，无 AI 能力，宠物外观固定

---

## 二、I.C.U. 的差异化优势

### 🎯 核心差异点：AI-First 设计

| 维度 | 传统桌宠 | I.C.U. |
|------|---------|--------|
| **角色创建** | 手绘像素图 + 手写动画配置 | AI 生成图像 → 自动动画引擎 |
| **文案系统** | 硬编码固定话术 | 本地/云端 LLM 动态生成 |
| **角色适配** | 需要开发者手动添加 | 用户通过 Prompt 5 分钟创建 |
| **个性化** | 预设 5-10 种形象 | 无限可能（AI 生成） |
| **扩展性** | 需要代码修改 | JSON 配置 + AI 推理 |

---

## 三、AI-First 架构设计

### 3.1 AI 驱动的角色生成流程

```
用户输入 Prompt
    ↓
调用 DALL-E / Midjourney / Stable Diffusion
    ↓
生成 1 张静态图（256x256 或 512x512）
    ↓
Python 动画引擎自动生成 8 种状态动画
    ↓
保存到 assets/pets/{角色名}/
    ↓
更新 config/pets.json
```

**关键技术**:
- **图像生成 API**: OpenAI DALL-E 3 / Replicate Stable Diffusion
- **动画引擎**: PIL / Pillow 实现浮动/摇摆/拉伸/跳跃
- **配置热加载**: 无需重启应用，实时预览新角色

---

### 3.2 话术系统升级：多维上下文感知引擎 (Context-Aware Persona Engine)

传统的桌宠提醒是基于时间的机械触发。I.C.U. 的核心差异化在于，它能**"看到"**你在干什么，并结合设定的"人设"生成极具压迫感或个性化的专属话术。

#### 1. 丰富的本地上下文注入 (Local Context Injection)

在触发提醒时，Python 后台会静默收集以下变量，组装成超级 Prompt 发送给本地大模型：

- `active_app`: 当前前台窗口（如 VS Code, iTerm2, Chrome）
- `clipboard_content`: 剪贴板最新内容（如果是报错信息 Traceback，桌宠会据此无情嘲讽）
- `typing_speed`: 过去 5 分钟的键盘敲击频率（判断是陷入沉思还是在疯狂赶代码）
- `health_debt`: 连续专注时长与缺水毫秒数

#### 2. 动态 Prompt 模板范例（以"毒舌监工"人设为例）

```
[System]
你现在是 I.C.U. 桌宠，人设是"尖酸刻薄但内心在乎用户身体的资深技术总监"。
禁止使用 AI 常用套话，语气必须简短、一针见血、带有极客黑话。

[Context]
- 当前活跃窗口：VS Code
- 剪贴板最近捕获：`IndexError: list index out of range`
- 连续久坐时长：124分钟
- 状态：极度缺水

[Task]
用户当前触发了强制休息与喝水提醒。请输出一句不超过 30 个字的警告。
```

#### 3. 大模型返回的数据结构（JSON 强制格式化）

大模型不仅返回文案，还直接控制桌宠的 UI 状态：

```json
{
  "dialogue": "连基础的数组越界都能写出来？难怪你坐了两个小时都没憋出像样的代码。去喝杯水洗洗你干瘪的大脑，现在！",
  "emotion_state": "angry_gaze",
  "action_command": "force_popup_reminder"
}
```

---

### 3.3 视觉款式与灵魂的"零代码"适配 (Zero-Code Persona Mapping)

传统桌宠更换皮肤时，文案和动画是割裂的（换了皮但说的话一样）。I.C.U. 通过大模型实现了**"皮囊与灵魂的统一"**。

#### 工作流设计

**1. 一键导入/生成视觉资产**

用户通过内置的 AI 画图接口（如 DALL-E 3）生成一张精灵图 (Sprite Sheet)，或者直接导入社区的经典素材（如 16-bit 塞尔达、苦逼卡皮巴拉）。

**2. 大模型推理行为树**

用户只需用一句话描述该款式的人设（例如："这是一只看透红尘、精神稳定的卡皮巴拉"）。

**3. 动态映射引擎**

- 底层状态机（FSM）触发 `drinking_reminder` 事件
- 大模型根据卡皮巴拉的人设，将常规的"该喝水了"，动态翻译为：
  > "就算天塌下来，也要泡在温泉里。你呢？你的杯子干得像撒哈拉。"
- 系统读取大模型返回的 `"emotion_state": "zen"`，自动播放卡皮巴拉头顶冒热气的动画帧

**这意味着**：只要有图片资产，大模型就能瞬间赋予它符合外观的特定性格和话术体系，适配新桌宠的时间成本降至 **1 分钟**。

---

### 3.4 用户自定义角色工作流

**传统桌宠**:
1. 用户想要新角色 → 找设计师画图 → 写动画配置 → 修改代码 → 重新编译
2. 时间成本：2-7 天
3. 技术门槛：需要会编程

**I.C.U. (AI-First)**:
1. 用户在设置界面输入 Prompt："一只戴眼镜的程序员猫，像素风格"
2. 点击"生成角色"按钮
3. 等待 30 秒（调用 AI 生成图像）
4. 预览动画效果
5. 保存并切换
6. 时间成本：**5 分钟**
7. 技术门槛：**0**

---

## 四、实现路线图

### Phase 1: 基础架构（当前）
- [x] FSM 状态机
- [ ] Menu Bar UI
- [ ] 桌宠窗口（无边框 + 透明）

### Phase 2: 动画引擎
- [ ] 静态图 → 8 种动画自动生成
- [ ] 动画播放器（tkinter Canvas）
- [ ] 预设 5 种角色测试

### Phase 3: AI 集成（核心差异化）
- [ ] **AI 图像生成接口**
  - OpenAI DALL-E 3 API
  - Replicate Stable Diffusion API
  - 本地 Stable Diffusion（可选）
- [ ] **AI 文案生成接口**
  - OpenAI GPT-4 API
  - Ollama 本地模型
  - 固定话术兜底
- [ ] **用户自定义角色 UI**
  - Prompt 输入框
  - 生成进度条
  - 动画预览窗口
  - 一键保存

### Phase 4: 社区生态
- [ ] 角色市场（用户分享 AI 生成的角色）
- [ ] Prompt 模板库（优质 Prompt 分享）
- [ ] 一键导入他人角色（JSON + 图片）

---

## 五、技术选型建议

### 5.1 坚持 Python + tkinter 的理由

| 方案 | 优势 | 劣势 | 适合 I.C.U. 吗？ |
|------|------|------|-----------------|
| **Python + tkinter** | ✅ 零依赖<br>✅ AI 库丰富<br>✅ 快速迭代 | ⚠️ 性能一般 | ✅ **推荐** |
| **Swift + SwiftUI** | ✅ 原生性能<br>✅ macOS 完美 | ❌ 不跨平台<br>❌ AI 库少 | ❌ 放弃跨平台 |
| **C++ + Qt6** | ✅ 最佳性能<br>✅ 跨平台 | ❌ 开发慢<br>❌ AI 集成难 | ❌ 开发成本高 |
| **Electron** | ✅ 跨平台<br>✅ Web 技术 | ❌ 资源占用大 | ❌ 违背轻量原则 |

**结论**: 坚持 Python + tkinter，因为：
1. AI 生态最成熟（OpenAI SDK / Replicate / Pillow）
2. 快速迭代，适合 AI-First 实验
3. 跨平台（macOS + Linux）
4. 轻量级（相比 Electron）

---

### 5.2 从竞品借鉴的具体代码

#### 借鉴 Shijima-Qt: 窗口穿透

```python
# 参考 ShijimaWidget.cc 的 Qt6 实现
import tkinter as tk

root = tk.Tk()
root.attributes('-topmost', True)        # 置顶
root.attributes('-transparentcolor', 'white')  # 透明
root.overrideredirect(True)              # 无边框

# macOS 特殊处理：允许点击穿透
if sys.platform == 'darwin':
    root.attributes('-alpha', 0.01)  # 几乎透明
```

#### 借鉴 TamoStudy: 成就系统

```python
# 参考 TamoStudy 的 Achievement 类
ACHIEVEMENTS = {
    'eye_care_master': {
        'name': '护眼大师',
        'condition': lambda stats: stats['eye_care_count'] >= 100,
        'reward': '解锁特殊动画'
    },
    'hydration_hero': {
        'name': '补水英雄',
        'condition': lambda stats: stats['water_intake'] >= 2000,  # ml
        'reward': '宠物进化'
    }
}
```

#### 借鉴 ProDOGtivity: 外部 API 集成

```python
# 参考 ProDOGtivity 的 Canvas API 集成
import requests

def generate_pet_image(prompt: str, api_key: str) -> str:
    """调用 DALL-E 3 生成宠物图像"""
    response = requests.post(
        'https://api.openai.com/v1/images/generations',
        headers={'Authorization': f'Bearer {api_key}'},
        json={
            'model': 'dall-e-3',
            'prompt': f'{prompt}, pixel art style, transparent background',
            'size': '1024x1024',
            'n': 1
        }
    )
    return response.json()['data'][0]['url']
```

---

### 4. PomodoroCat - 番茄钟 + 宠物奖励

**项目地址**: https://github.com/shengyuan-lu/PomodoroCat

**技术栈**: Swift (macOS / iOS)

**核心架构**:
- **SwiftUI 交互**: 两个 TabView 作为 NavigationView 子视图，计时器与宠物游戏无缝切换
- **数据管理**: `@AppStorage` 实现全应用数据同步
- **MVVM 模式**: 每个子视图独立视图模型
- **奖励机制**: 猫币基于累积工作时间计算，购买装饰品提升宠物幸福度（上限 100）
- **加速器功能**: 限时内更快速率获得猫币

**可借鉴点**:
- ✅ **克制优雅的 UI**: 商店按钮、物品购买交互设计
- ✅ **时间-奖励绑定**: 工作时长直接转化为虚拟货币
- ✅ **正向激励循环**: 赚币 → 购买 → 提升幸福度
- ⚠️ **局限**: Swift 实现，仅支持 macOS/iOS，无 AI 能力

---

### 5. Cat - 光标追踪桌宠

**项目地址**: https://github.com/mmar/Cat

**技术栈**: Swift / SpriteKit

**核心特性**:
- **极致轻量**: 仅几十 KB
- **光标追踪**: 小猫实时追踪鼠标位置
- **SpriteKit 动画**: 利用游戏引擎实现流畅动画
- **macOS 原生**: 完美集成系统权限

**可借鉴点**:
- ✅ **光标追踪算法**: 实现"I am watching u"的压迫感
- ✅ **屏幕坐标追踪**: 实时获取鼠标位置并转换为宠物动作
- ✅ **性能优化**: 极小体积，资源占用低
- ⚠️ **局限**: Swift 实现，不跨平台，功能单一

---

### 6. ShimeTomo - 现代 macOS 桌宠

**项目地址**: https://github.com/a35hie/ShimeTomo

**技术栈**: Swift / SwiftUI

**核心架构**:
- **SwiftUI 现代化**: 完全基于 SwiftUI 构建，支持 macOS 13.5+
- **简洁界面**: 绿色"Add Folder"按钮导入精灵资源，网格预览选择宠物
- **App Store 就绪**: Apache-2.0 许可，标准 Xcode 项目结构
- **精灵动画**: 编号精灵导入工作流，用户友好的资源管理

**可借鉴点**:
- ✅ **macOS 审美**: 符合现代 macOS 设计语言
- ✅ **资源管理**: 文件夹导入 + 网格预览的用户体验
- ✅ **发布架构**: 适合 Mac App Store 的项目结构
- ⚠️ **局限**: Swift 实现，不跨平台，无 AI 能力

---

## 六、核心竞争力总结

### 传统桌宠的痛点
1. ❌ 角色固定，用户无法自定义
2. ❌ 文案死板，缺乏个性化
3. ❌ 扩展需要编程能力
4. ❌ 开发周期长（新角色需要 2-7 天）

### I.C.U. 的解决方案
1. ✅ **AI 生成角色** - 5 分钟创建专属桌宠
2. ✅ **AI 动态文案** - 每次提醒都不重复
3. ✅ **0 代码扩展** - JSON 配置 + Prompt
4. ✅ **社区生态** - 用户分享 AI 生成的角色

### 技术护城河

#### 1. 本地隐私至上的 AI 架构 (Local-AI Privacy Moat)

区别于必须依赖云端 OpenAI 接口的竞品，I.C.U. 针对 macOS 统一内存架构进行了深度优化。默认接入 Ollama 运行本地大模型（如 Qwen 3.5 27B 或 Llama 3 8B）。

**核心优势**：
- ✅ 实时读取用户的代码编辑器、终端报错和剪贴板内容
- ✅ 生成极其精准的"监视感"语境
- ✅ **绝对保证用户的商业代码和隐私数据不离开本地机器**

这是云端 API 无法做到的。竞品如果要实现类似功能，必须将敏感信息上传到云端，存在严重的隐私和安全风险。

#### 2. Agentic UI (智能体驱动界面)

UI 的切换不由生硬的 if-else 逻辑控制，而是由本地 LLM 根据当前系统语境和健康负债计算出的"情绪向量"直接驱动动画状态。

**工作流**：
```
大模型感知环境 → 大模型产生情绪/决定话术 → 系统解析 JSON 渲染对应的动画
```

这使得 I.C.U. 成为真正的 **Autonomous Agent（自主智能体）**，而非"套壳的番茄钟 + 随机名言生成器"。

#### 3. 其他技术优势

- **动画引擎**: 1 张图 → 8 种动画（竞品需要手绘 8 张）
- **热加载**: 无需重启，实时预览新角色
- **跨平台**: Python 实现，macOS + Linux 通用
- **零代码扩展**: JSON 配置 + Prompt，1 分钟适配新角色

---

## 七、下一步行动

### 立即可做
1. ✅ 完成 FSM 核心 + Menu Bar UI（Phase 1）
2. ✅ 实现动画引擎（Phase 2）
3. ✅ 集成 OpenAI DALL-E 3 API（Phase 3 核心）

### 中期目标
4. 开发"自定义角色"UI 界面
5. 实现 AI 文案生成（OpenAI + Ollama 双模式）
6. 测试用户自定义工作流（5 分钟创建角色）

### 长期愿景
7. 建立角色市场（用户分享 AI 生成的角色）
8. Prompt 模板库（优质 Prompt 社区）
9. 插件系统（第三方开发者扩展）

---

**Sources**:
- [TamoStudy GitHub](https://github.com/narlock/TamoStudy)
- [ProDOGtivity GitHub](https://github.com/linyanna/ProDOGtivity)
- [Shijima-Qt GitHub](https://github.com/pixelomer/Shijima-Qt)
