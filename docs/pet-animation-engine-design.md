# PetAnimationEngine 设计方案

> 桌宠动画系统完全重构 — 2.5D 程序化动画引擎

## 一、背景与目标

### 现有系统的根本问题

| 问题 | 现状 | 影响 |
|---|---|---|
| 逐帧 PNG 切换 | `PetAnimationPlayer` 按 timer 切图 | 流畅度受素材帧数上限约束，切换有明显跳帧感 |
| 静态 transform | `PetMotionEnhancer` 是一组写死常量 | 状态切换是瞬变，无任何过渡 |
| 无分层概念 | 生命感、状态、交互全挤在一个 timer | 无法叠加，优先级无法管理 |
| 无立体感 | NSImageView + 单张 2D 图 | 平面僵硬，"不像活的" |
| 交互几乎为零 | 点击只触发拖拽 | 无爽快感，无反馈 |

### 目标

- **流畅**：动作连续插值，60fps，不再依赖素材帧数
- **生动立体**：2.5D 视差 + 动态阴影 + squash & stretch
- **可爱**：丰富的交互反馈、随机微动作、表情叠加
- **可维护**：声明式动作定义，新增动作不动引擎代码
- **兼容**：保留现有多帧素材播放能力，老素材直接可用

---

## 二、架构总览

```
DesktopPetWindowController
  └─ DesktopPetView (宿主，负责 layout / event 路由)
       ├─ groundShadowLayer      ← 新增：落地椭圆软阴影
       ├─ imageView              ← 保留：承载 2D 素材
       └─ PetAnimationEngine     ← 新增：动画调度核心
            ├─ LifeLayer         ← 持续生命层：呼吸/浮动/摇摆
            ├─ StateLayer        ← 状态动作层：idle/working/focus/break
            ├─ InteractionLayer  ← 交互反馈层：点击/悬停/拖拽
            └─ ExpressionLayer   ← 表情覆盖层：眨眼/惊讶/开心
```

**合成规则**：四层分别产出一个 `LayerTransform`（scale, rotate, translateY, perspective），
引擎在每帧将四层叠加成最终 `CATransform3D` 写入 imageView.layer。

```
finalTransform = life.transform ⊕ state.transform ⊕ interaction.transform ⊕ expression.transform
```

优先级：`InteractionLayer > ExpressionLayer > StateLayer > LifeLayer`
高优先级层可以"覆盖"低优先级层的某个轴，但不能完全取消其他层（保留生命感）。

---

## 三、各层设计

### Layer 0 — LifeLayer（持续生命层）

**职责**：让桌宠永远"活着"，不依赖任何状态触发。

**实现**：三条独立正弦曲线叠加（频率互质，不重复）

```
呼吸：scaleX/Y += sin(t × 2π / 3.2s) × 0.018          -- 3.2s 一周期
浮动：translateY += sin(t × 2π / 4.7s) × 2.5px        -- 4.7s 一周期
摇摆：rotate    += sin(t × 2π / 6.1s) × 0.8°           -- 6.1s 一周期
```

驱动：`CADisplayLink`（60fps），在 `tick(_:)` 里按时间参数求值，**不用 Timer**。

状态机不同时，振幅参数不同：

| 状态 | 呼吸幅度 | 浮动幅度 | 摇摆幅度 |
|---|---|---|---|
| idle | 1.8% | 2.5px | 0.8° |
| working | 1.2% | 1.5px | 1.5° |
| focus | 0.8% | 0.8px | 0.3° |
| break | 2.5% | 3.5px | 1.2° |

参数切换本身也要做过渡（amplitude lerp，0.6s）。

---

### Layer 1 — StateLayer（状态动作层）

**职责**：响应工作状态切换，播放过渡动画到目标姿态。

**声明式 PetStatePosture**（每个状态对应一个静止姿态）：

```swift
struct PetStatePosture {
    var baseScale: CGFloat       // 基础缩放
    var tiltDegrees: CGFloat     // 倾斜角（working 时略微前倾）
    var verticalShift: CGFloat   // 竖向偏移（break 时略微下沉）
    var shadowOpacity: Float     // 阴影不透明度
    var shadowRadius: CGFloat    // 阴影模糊半径
    var transitionDuration: TimeInterval
    var transitionCurve: AnimationCurve
}
```

| 状态 | baseScale | tiltDegrees | verticalShift | 切换曲线 |
|---|---|---|---|---|
| idle | 1.00 | 0° | 0px | ease-out 0.4s |
| working | 1.02 | -2° | 1px | spring (damping 0.7) 0.5s |
| focus | 0.98 | -1° | -1px | ease-in-out 0.6s |
| break | 1.04 | 2° | 2px | spring (damping 0.6) 0.45s |

**状态切换动画**：从当前姿态插值到目标姿态，使用 `CABasicAnimation` + `fillMode = .forwards`。

**多帧素材兼容**：StateLayer 同时驱动 `PetAnimationPlayer` 的帧序列播放（如果有多帧素材）。
单帧或无素材时，StateLayer 只做姿态变换。

---

### Layer 2 — InteractionLayer（交互反馈层）

**职责**：响应鼠标/触摸事件，给出即时爽快的反馈。

#### 2a. 点击反馈 — Squash & Stretch

经典动画 12 原则中的 squash & stretch，"可爱感"核心来源：

```
t=0ms   : 正常
t=0~60ms: scaleX *= 1.18, scaleY *= 0.82  (被按下，横向拉伸竖向压缩)
t=60~120ms: spring 回弹，超量到 scaleX *= 0.95, scaleY *= 1.05
t=120~250ms: spring 回弹至 1.0
```

曲线：spring (stiffness 280, damping 22)

#### 2b. 悬停反馈 — 偏头看你

鼠标在桌宠上时：
- 轻微放大：scale 过渡到 1.05（ease-out 0.2s）
- 视差倾斜：根据鼠标相对于桌宠中心的偏移，施加透视旋转
  ```
  dx = (mouseX - petCenterX) / petWidth   // -0.5 ~ 0.5
  dy = (mouseY - petCenterY) / petHeight
  rotateY = dx × 8°   // 横向偏头
  rotateX = dy × 5°   // 纵向点头
  transform.m34 = -1/500  // 透视深度
  ```
- 过渡：鼠标移动时实时跟随，鼠标离开时 ease-out 0.3s 归零

#### 2c. 拖拽反馈 — 被拎起感

```
拖拽开始: 快速 spring 到 tiltDegrees ±12°（方向随拖拽方向），scale 1.06
          落地阴影变大变淡（模拟高度增加）
拖拽结束: 落下晃动：摇摆 3 次衰减，spring 归零（damping 0.4，0.5s）
```

#### 2d. 双击 — 开心蹦

```
t=0~100ms : 快速跳起 translateY +8px + scale 1.1
t=100~200ms: 落下压缩 scaleX 1.05, scaleY 0.9
t=200~400ms: spring 归零
```

---

### Layer 3 — ExpressionLayer（表情覆盖层）

**职责**：叠加短时表情动作，不影响其他层。

**触发条件**：

| 表情 | 触发时机 | 持续 |
|---|---|---|
| 眨眼 | 随机 (idle 时每 4~8s 一次) | 0.15s |
| 惊讶跳起 | 状态从 idle → working | 0.4s |
| 打哈欠晃 | 长时间无交互 (>60s idle) | 0.8s |
| 点头 | 收到提醒后执行操作 | 0.3s |
| 摇头 | 操作被拒绝/错误 | 0.4s |

**眨眼实现**：
在 imageView 上叠加一个 `blinkOverlayLayer`（透明），用 CAAnimation 模拟眼部遮罩缩放：
- 如果素材有独立眼部帧，切换帧
- 如果没有，对整个 imageView 做快速竖向压缩后弹回（近似效果）

---

## 四、立体感：2.5D 动态阴影系统

### 落地阴影

在 `imageView` 下方新增 `groundShadowLayer: CALayer`（椭圆形，模糊）：

```
shadowLayer.frame  = 椭圆，宽度 = 桌宠宽 × 0.7，高度 = 桌宠宽 × 0.12
shadowLayer.cornerRadius = shadowLayer.frame.height / 2
shadowLayer.backgroundColor = NSColor.black.withAlpha(0.25).cgColor
shadowLayer过滤器 = CIFilter(name: "CIGaussianBlur", radius: 4)
```

**随浮动高度动态变化**：
```
floatHeight = LifeLayer.currentTranslateY   // 当前浮动高度 (0 ~ +2.5px)
shadow.opacity = 0.25 - floatHeight × 0.018  // 越高越淡
shadow.xScale  = 1.0  - floatHeight × 0.012  // 越高越小
```

效果：桌宠呼吸浮动时，阴影同步缩小/变淡，强烈的"悬浮感"。

### 动态层阴影

imageView.layer 的 `shadowRadius` / `shadowOpacity` / `shadowOffset` 也随状态动态变化：

```swift
// 交互时（被点击/悬停）：阴影增大模拟"抬起"
interacting: shadowRadius = 8, opacity = 0.22, offset.y = -2
idle:        shadowRadius = 4, opacity = 0.12, offset.y = -1
```

---

## 五、新文件结构

```
apps/macos-shell/Sources/ICUShell/Pet/
├── DesktopPetView.swift            ← 改造：接入引擎，mouse 事件路由
├── DesktopPetWindowController.swift ← 不动
├── DesktopPetCopy.swift            ← 不动
├── DesktopPetMenuModel.swift       ← 不动
├── ReminderCardView.swift          ← 不动
│
├── Animation/                      ← 全新目录
│   ├── PetAnimationEngine.swift    ← 引擎主入口，管理四层 + CADisplayLink
│   ├── LifeLayer.swift             ← 持续生命层
│   ├── StateLayer.swift            ← 状态动作层
│   ├── InteractionLayer.swift      ← 交互反馈层
│   ├── ExpressionLayer.swift       ← 表情覆盖层
│   ├── AnimationCurve.swift        ← easing 函数库
│   ├── LayerTransform.swift        ← 各层输出 transform 结构体 + 叠加运算
│   └── GroundShadowController.swift ← 落地阴影独立控制器
│
├── PetAnimationModels.swift        ← 保留（帧序列数据结构）
├── PetAnimationPlayer.swift        ← 保留（帧序列播放器，StateLayer 内部用）
└── PetMotionEnhancer.swift         ← 废弃（由引擎替代，保留文件但标注 deprecated）
```

`PetAssetLocator.swift` 完全不动，帧素材加载路径不变。

---

## 六、数据结构

### LayerTransform

```swift
struct LayerTransform {
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0
    var rotateZ: CGFloat = 0.0       // 度
    var rotateX: CGFloat = 0.0       // 度，用于视差
    var rotateY: CGFloat = 0.0       // 度，用于视差
    var translateY: CGFloat = 0.0
    var perspective: CGFloat = 0.0   // transform.m34

    // 叠加两个 LayerTransform（加法合成）
    static func + (lhs: LayerTransform, rhs: LayerTransform) -> LayerTransform

    // 转为 CATransform3D
    var caTransform: CATransform3D { get }
}
```

### AnimationCurve

```swift
enum AnimationCurve {
    case linear
    case easeIn(duration: TimeInterval)
    case easeOut(duration: TimeInterval)
    case easeInOut(duration: TimeInterval)
    case spring(stiffness: CGFloat, damping: CGFloat, duration: TimeInterval)

    func evaluate(at t: CGFloat) -> CGFloat  // t: 0~1 → value: 0~1
}
```

### PetAction（声明式动作）

```swift
struct PetAction {
    var id: String
    var targetTransform: LayerTransform
    var curve: AnimationCurve
    var canBeInterrupted: Bool
    var onComplete: (() -> Void)?
}
```

---

## 七、引擎核心接口

```swift
final class PetAnimationEngine {
    // 外部输入
    func setWorkState(_ state: ShellWorkState)
    func handleMouseEntered(localPosition: CGPoint)
    func handleMouseMoved(localPosition: CGPoint)
    func handleMouseExited()
    func handleMouseDown(localPosition: CGPoint)
    func handleMouseUp()
    func handleDragBegan()
    func handleDragEnded()
    func handleDoubleClick()

    // 表情触发
    func playExpression(_ expression: PetExpression)

    // 生命周期
    func attachTo(layer: CALayer)   // 绑定目标 layer
    func start()
    func pause()
    func stop()

    // 每帧回调（由 CADisplayLink 驱动）
    private func tick(_ link: CADisplayLink)
}
```

`DesktopPetView` 把所有 `mouseDown/Up/Moved/Entered/Exited` 事件转发给引擎，
引擎输出最终 transform 直接写 `imageView.layer.transform`，
同时更新 `groundShadowController`。

---

## 八、实现顺序

| 步骤 | 内容 | 预计改动 |
|---|---|---|
| Step 1 | `LayerTransform` + `AnimationCurve` 基础数据结构 | 2 个新文件 |
| Step 2 | `LifeLayer`：CADisplayLink + 三条正弦叠加 | 1 个新文件 |
| Step 3 | `PetAnimationEngine` 主入口 + `attachTo` + `start/stop` + tick | 1 个新文件 |
| Step 4 | `StateLayer`：声明式姿态 + 过渡插值 | 1 个新文件 |
| Step 5 | `GroundShadowController`：落地阴影 | 1 个新文件 |
| Step 6 | `InteractionLayer`：点击 squash/stretch + 悬停视差 | 1 个新文件 |
| Step 7 | `DesktopPetView` 改造：接线引擎，移除旧 MotionEnhancer 调度 | 改 1 个文件 |
| Step 8 | `ExpressionLayer`：眨眼 + 随机微动作 | 1 个新文件 |
| Step 9 | 气泡/提醒卡片 pop 动画 | 改 `DesktopPetView` |
| Step 10 | 编译验证 + 现有测试通过 | — |

每步独立可测，Step 1~5 完成后就能看到明显的视觉提升。

---

## 九、与现有系统兼容约定

| 现有组件 | 处理方式 |
|---|---|
| `PetAssetLocator` | **完全保留**，资产加载路径不变 |
| `PetAnimationPlayer` | **保留**，StateLayer 内部调用它播放多帧素材 |
| `PetAnimationModels` | **保留**，数据结构不变 |
| `PetMotionEnhancer` | 标注 `@available(*, deprecated)`，引擎稳定后删除 |
| `DesktopPetWindowController` | **不动**，接口不变 |
| `AvatarCoordinator` / `AvatarSettingsStore` | **不动** |

---

## 十、风险与约束

| 风险 | 应对 |
|---|---|
| `CADisplayLink` 主线程压力 | tick 内只做数值计算，写 layer.transform，无 IO；帧率自适应 ProMotion |
| 透视变换 + 阴影同时开启可能触发离屏渲染 | groundShadow 用单独 CALayer 不叠加在 imageView 上，避免 compositing |
| macOS 12 以下 API 兼容 | AnimationCurve.spring 用 `CASpringAnimation`（macOS 10.11+），无问题 |
| 多帧素材帧切换与引擎 transform 冲突 | StateLayer 持有帧切换 timer，与引擎 CADisplayLink 分开，imageView.image 和 layer.transform 是正交的，无冲突 |
