# Dynamic Desktop Pet Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把当前静态 Swift 桌宠升级为支持 `idle / working / alert` 三类帧序列动画、同状态随机变体切换和轻量代码增强层的动态桌宠底座，同时保持旧单帧资产兼容。

**Architecture:** 在现有 `PetAssetLocator` 基础上增加动画解析 contract，先把资产层统一成“状态 + 变体 + 帧序列”的运行时描述，再引入独立的帧播放器和轻量 motion enhancer，最后由 `DesktopPetView` 负责调度状态切换、定时随机同状态变体和现有主题/文案逻辑。首版不做后台 AI 生成新动作包，不做视频运行时，只做帧序列播放底座。

**Tech Stack:** Swift 6, AppKit, SwiftPM, manual runtime tests via `tools/check_native_shell.sh`, launcher verification via `./icu --verify`

---

## File Structure

- Create: `apps/macos-shell/Sources/ICUShell/Pet/PetAnimationModels.swift`
  - 定义运行时动画描述模型：状态、变体、帧 URL、fps、loop mode、默认值。
- Modify: `apps/macos-shell/Sources/ICUShell/Runtime/PetAssetLocator.swift`
  - 在保留 `displayImageURL(...)` 的同时增加动画解析 API，负责多帧目录解析、旧 `state/0.png` 兼容和降级顺序。
- Create: `apps/macos-shell/Sources/ICUShell/Pet/PetAnimationPlayer.swift`
  - 负责帧索引推进、循环、重置和只读测试钩子。
- Create: `apps/macos-shell/Sources/ICUShell/Pet/PetMotionEnhancer.swift`
  - 负责 `idle / working / alert` 的轻量 transform 增强，不处理主体图片内容。
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift`
  - 从“直接加载单图”改成“调度动画 locator / player / enhancer”，保留点击穿透、状态文案和主题文案刷新逻辑。
- Modify: `apps/macos-shell/Tests/ManualRuntime/PetAssetLocatorManualTests.swift`
  - 覆盖动画解析、多帧优先、单帧兼容、降级链路。
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
  - 覆盖帧推进、状态切换、同状态随机变体和文案/主题不回归。
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
  - 注册新增 runtime 手工测试。
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
  - 注册新增 AppKit 手工测试。
- Modify: `tools/check_native_shell.sh`
  - 把新 source/test 文件加入手工验证编译链。

## Task 1: Add Animation Runtime Models And Asset Resolution

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Pet/PetAnimationModels.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Runtime/PetAssetLocator.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/PetAssetLocatorManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Write the failing runtime tests for animation resolution**

Add tests for:
- 多帧目录 `idle/main/0.png, 1.png` 会返回完整帧序列
- 旧 `working/0.png` 会被归一化成单帧动画
- `config.json` 中的 `default_variant / fps / loop_mode` 会覆盖默认播放参数
- 缺失当前状态时按 `alert -> working -> idle -> base.png` 降级

```swift
func testPetAssetLocatorResolvesVariantFrameSequence() throws {
    let root = try makeTemporaryDirectory()
    let frame0 = root.appendingPathComponent("assets/pets/capybara/idle/main/0.png")
    let frame1 = root.appendingPathComponent("assets/pets/capybara/idle/main/1.png")
    try writeFixtureFile(at: frame0)
    try writeFixtureFile(at: frame1)

    let locator = PetAssetLocator(repoRootURL: root)
    let animation = try locator.resolveAnimation(for: "capybara", preferredAction: "idle")

    try expect(animation.variantID == "main", "locator should resolve main variant")
    try expect(animation.frameURLs.count == 2, "locator should return all frames in order")
}

func testPetAssetLocatorUsesAnimationMetadataOverrides() throws {
    let root = try makeTemporaryDirectory()
    try writeText(
        at: root.appendingPathComponent("assets/pets/capybara/config.json"),
        contents: #"{"animations":{"idle":{"default_variant":"blink","variants":{"blink":{"fps":10,"loop_mode":"once"}}}}}"#
    )

    let locator = PetAssetLocator(repoRootURL: root)
    let animation = try locator.resolveAnimation(for: "capybara", preferredAction: "idle")

    try expect(animation.variantID == "blink", "locator should honor default_variant metadata")
    try expect(animation.framesPerSecond == 10, "locator should honor fps metadata")
    try expect(animation.loopMode == .once, "locator should honor loop_mode metadata")
}
```

- [ ] **Step 2: Run the runtime checks to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL with missing animation models or missing `resolveAnimation(...)`.

- [ ] **Step 3: Implement minimal animation models and locator support**

Implement:
- `PetAnimationModels.swift` with a small `PetAnimationDescriptor` model
- `PetAssetLocator.resolveAnimation(for:preferredAction:)`
- multi-frame directory parsing
- `config.json.animations` metadata parsing for `default_variant / fps / loop_mode`
- legacy `state/0.png` normalization
- fallback order preservation

```swift
struct PetAnimationDescriptor {
    var stateID: String
    var variantID: String
    var frameURLs: [URL]
    var framesPerSecond: Double
    var loopMode: PetAnimationLoopMode
}
```

- [ ] **Step 4: Run the runtime checks to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/macos-shell/Sources/ICUShell/Pet/PetAnimationModels.swift \
  apps/macos-shell/Sources/ICUShell/Runtime/PetAssetLocator.swift \
  apps/macos-shell/Tests/ManualRuntime/PetAssetLocatorManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift \
  tools/check_native_shell.sh
git commit -m "feat: add pet animation asset resolution"
```

## Task 2: Add Frame Playback To DesktopPetView

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Pet/PetAnimationPlayer.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Write the failing AppKit tests for frame playback**

Add tests for:
- `DesktopPetView` 使用多帧 `idle/main/*.png` 时可以推进帧索引
- 只有单帧 legacy 资产时保持静态，不会越界推进

Prefer writing helper-colored PNGs so the test can distinguish frame `0` from frame `1`.

```swift
func testDesktopPetViewAdvancesAnimationFrames() throws {
    let appPaths = try makeTemporaryAppPaths()
    let frame0 = try makeColorPNG(color: .red)
    let frame1 = try makeColorPNG(color: .green)
    try installPetAnimationFrames(appPaths: appPaths, petID: "capybara", state: "idle", variant: "main", frames: [frame0, frame1])

    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 128, height: 128), assetLocator: PetAssetLocator(appPaths: appPaths), petID: "capybara")
    view.advanceAnimationFrameForTesting()

    try expect(view.currentFrameIndexForTesting == 1, "pet view should advance to the next frame")
}
```

- [ ] **Step 2: Run the AppKit manual tests to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL with missing player hooks or static-image-only behavior.

- [ ] **Step 3: Implement the animation player and wire it into DesktopPetView**

Implement:
- `PetAnimationPlayer` with frame array, frame index, timer tick, reset
- `DesktopPetView` image updates via player instead of direct single-image replacement
- small internal testing seams such as `advanceAnimationFrameForTesting`

```swift
final class PetAnimationPlayer {
    func load(_ animation: PetAnimationDescriptor) { /* reset to frame 0 */ }
    func advanceFrame() -> URL? { /* wrap around */ }
}
```

- [ ] **Step 4: Run the AppKit manual tests to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/macos-shell/Sources/ICUShell/Pet/PetAnimationPlayer.swift \
  apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift \
  tools/check_native_shell.sh
git commit -m "feat: add desktop pet frame playback"
```

## Task 3: Add State Switching, Same-State Random Variants, And Motion Enhancement

**Files:**
- Create: `apps/macos-shell/Sources/ICUShell/Pet/PetMotionEnhancer.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
- Modify: `tools/check_native_shell.sh`

- [ ] **Step 1: Write the failing AppKit tests for state-aware animation and variant switching**

Add tests for:
- `setWorkState(.working)` 会切到 `working` 动画族
- `setWorkState(.focus)` 仍然映射到 `working`，`setWorkState(.breakState)` 仍然映射到 `alert`
- 定时随机变体切换只会在当前状态内发生，不会跳去 `alert`
- 当前变体未完整播放一轮前，不允许被随机切换打断
- `idle / working / alert` 三种状态的 enhancer profile 不同

```swift
func testDesktopPetViewRandomVariantSwitchStaysInsideCurrentState() throws {
    let appPaths = try makeTemporaryAppPaths()
    try installPetAnimationFrames(appPaths: appPaths, petID: "capybara", state: "working", variant: "main", frames: [try makeColorPNG(color: .red)])
    try installPetAnimationFrames(appPaths: appPaths, petID: "capybara", state: "working", variant: "focus", frames: [try makeColorPNG(color: .blue)])

    let view = DesktopPetView(frame: NSRect(x: 0, y: 0, width: 128, height: 128), assetLocator: PetAssetLocator(appPaths: appPaths), petID: "capybara")
    view.setWorkState(.working)
    view.triggerVariantRotationForTesting()

    try expect(view.currentAnimationStateForTesting == "working", "variant rotation must stay inside the active state")
}

func testDesktopPetViewDoesNotInterruptVariantBeforeLoopCompletes() throws {
    let view = makeWorkingVariantTestView()
    view.triggerVariantRotationForTesting()

    try expect(view.currentVariantIDForTesting == "main", "pet view must not rotate before a full loop completes")
}
```

- [ ] **Step 2: Run the AppKit manual tests to verify they fail**

Run: `bash tools/check_native_shell.sh`
Expected: FAIL with missing variant rotation or unchanged state animation.

- [ ] **Step 3: Implement same-state randomization and motion enhancement**

Implement:
- `PetMotionEnhancer` profiles for `idle / working / alert`
- state change path that reloads animation family immediately
- cooldown-based same-state variant switching
- “完整播放至少一轮后才允许切换” 的 gate
- internal deterministic seams for testing variant rotation and timer progression, for example:
  - `advanceAnimationFrameForTesting()`
  - `triggerVariantRotationForTesting()`
  - injectable clock / seeded RNG or explicit tick methods

```swift
enum PetMotionProfile {
    case idle
    case working
    case alert
}
```

- [ ] **Step 4: Run the AppKit manual tests to verify they pass**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/macos-shell/Sources/ICUShell/Pet/PetMotionEnhancer.swift \
  apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift \
  tools/check_native_shell.sh
git commit -m "feat: add dynamic stateful pet animation runtime"
```

## Task 4: End-To-End Verify The Dynamic Pet Foundation

**Files:**
- Modify as needed from previous tasks

- [ ] **Step 1: Run the full manual runtime and AppKit checks**

Run: `bash tools/check_native_shell.sh`
Expected: PASS

- [ ] **Step 2: Run launcher verification**

Run: `./icu --verify`
Expected: PASS

- [ ] **Step 3: Manual visual confirmation**

Run: `./icu`
Expected:
- 桌宠在右下角启动
- `idle` 状态有循环动态效果
- 切到 `working / alert` 时动作族立即切换
- 同状态停留一段时间后，只在该状态内切换不同变体
- 主题、右键菜单、状态气泡、话术文案不回归

- [ ] **Step 4: Lightweight performance sanity check**

Run after `./icu` is stable:

```bash
ps -axo pid,ppid,rss,%mem,etime,comm,args | awk '$6 ~ /ICUShell/ || $7 ~ /ICUShell/ {printf "PID=%s RSS=%.1fMB MEM=%s%% ELAPSED=%s CMD=%s\n",$1,$3/1024,$4,$5,$6}'
```

Expected:
- `ICUShell` 进程存在
- 相比静态基线没有异常增长
- 没有因为一次性加载所有状态帧导致明显失控的常驻占用

- [ ] **Step 5: Commit final verification fixes if needed**

```bash
git add apps/macos-shell/Sources/ICUShell/Pet \
  apps/macos-shell/Sources/ICUShell/Runtime/PetAssetLocator.swift \
  apps/macos-shell/Tests/ManualRuntime \
  tools/check_native_shell.sh
git commit -m "test: verify dynamic desktop pet runtime"
```
