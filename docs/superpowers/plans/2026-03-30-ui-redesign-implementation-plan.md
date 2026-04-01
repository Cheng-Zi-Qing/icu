# UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `2026-03-30-ui-redesign-design.md` 落成可交付实现，并按最新确认的职责边界收掉 `创作工坊 > 形象生成` 与 `更换形象` 之间的重复心智。

**Architecture:** 当前 worktree 已经有 `AvatarPickerWindowController`、`StudioWindowController` 和重写后的 `GenerationConfigWindowController`，所以本计划不从零搭三套窗口，而是先用现有 AppKit manual tests 锁定最新 contract，再把 `AvatarStudioContentView` 从 `browse/create` 双模式收成“当前已应用形象参考卡 + 单一创作工作区”。`AvatarCoordinator` 继续负责共享 refresh / apply 链路，`AvatarPickerWindowController` 继续做唯一的现有形象浏览入口，`GenerationConfigWindowController` 本轮只保回归，不做额外重构。

**Tech Stack:** Swift 5.10, AppKit, SwiftPM, manual runtime tests, `bash tools/check_native_shell.sh`, `./icu --verify`, JSON copy catalog, Python avatar bridge

---

## Worktree Notes

- 当前分支为 `ui-redesign-implementation`，写计划时 worktree 干净。
- 已批准 spec：
  - `docs/superpowers/specs/2026-03-30-ui-redesign-design.md`
- 这份 spec 跨三个窗口，但当前代码里 picker / studio / config 三套窗口都已经存在。
- 本计划只安排“当前代码和最新 spec 之间仍有偏差”的实现步骤，尤其是：
  - 去掉 `创作工坊 > 形象生成` 里重复的现有形象浏览 UI
  - 保留 `更换形象` 作为唯一的现有形象浏览 / 切换入口
  - 保留 `生成配置` 现有 contract，只做回归验证
- 不要重新引入 `AvatarSelectorWindowController.swift` 或 `AvatarWizardWindowController.swift`。

## File Structure

- Modify: `apps/macos-shell/Sources/ICUShell/Studio/AvatarStudioContentView.swift`
  - 删掉 `browse/create` 双模式、列表卡、详情卡和模式切换控件
  - 改成“当前已应用形象参考卡 + 单一创作工作区”
  - 继续承载 prompt 优化、预览生成、保存并应用状态机
- Modify: `apps/macos-shell/Sources/ICUShell/Studio/StudioWindowController.swift`
  - 把 `形象生成` tab 的 launch semantics 收敛到同一个工作区
  - 不再把 `.avatarCreate` 当作独立 UI 模式处理
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`
  - 保持 picker / studio / runtime 共享的 avatar apply 与 refresh 链路
  - 调整 picker 的 “＋ 新建形象…” 跳转，让它落到新的 avatar workspace 语义上
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarPickerWindowController.swift`
  - 保持现有形象列表与 Apply contract
  - 仅在 studio launch 语义变化时做最小接线调整
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift`
  - 删除已不再需要的 `AvatarStudioMode`
  - 保留 `InlineAvatarCreationStage`、`InlineAvatarPreviewDraft`、`InlineAvatarSaveRequest`
- Modify: `config/copy/base.json`
  - 为 avatar workspace 新增最小 copy key，例如 `open_picker_button`
  - 只在最后清掉确认无引用的旧 browse-mode 文案
- Optional Modify: `apps/macos-shell/Sources/ICUShell/Copy/UserVisibleCopyKey.swift`
  - 仅当共享 copy key 需要强类型入口时再加；不要为了 avatar-studio 局部文案扩展无用枚举
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
  - 重写 avatar studio 相关 shell / gating / integration tests
  - 保留 picker、theme、speech、menu、pet runtime 现有 coverage
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
  - 同步新的 avatar studio test 函数名，确保 `check_native_shell.sh` 真正执行到最新 contract
- No planned change: `apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift`
  - 除非 avatar studio 改动意外打破 config regression，否则本轮不主动修改它

## Task 1: Lock The Single-Workspace Avatar Tab Contract

**Files:**
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`
- Modify: `config/copy/base.json`
- Modify: `apps/macos-shell/Sources/ICUShell/Studio/AvatarStudioContentView.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift`

- [ ] **Step 1: Replace the old browse/create shell tests with the new avatar-workspace contract**

Replace the old shell-focused tests:

```swift
func testStudioAvatarBrowseModeShowsReadOnlyListAndPickerLink() throws
func testStudioAvatarCreateModeLaunchTargetStartsInCreateState() throws
```

with:

```swift
func testStudioAvatarTabShowsReferenceCardAndCreationWorkspace() throws
func testStudioAvatarLaunchTargetUsesSharedWorkspaceWithoutModeChrome() throws
```

Lock these visible contracts:

- 点击 `形象生成` 后直接看到 `当前分区：形象生成`
- 看到 `当前已应用形象`
- 看到 `打开更换形象`
- 看到 `avatarCreateRawPrompt` 和 `avatarCreateOptimizedPrompt`
- 看到 `优化 prompt / 生成预览 / 重新生成 / 保存并应用`
- 不再渲染 `当前模式：新建形象`
- 不再渲染 `返回现有形象`
- 不再渲染 studio 内的 avatar `NSTableView`

Use assertions in this shape:

```swift
_ = try requireLabel(in: contentView, stringValue: "当前已应用形象")
_ = try requireButton(in: contentView, title: "打开更换形象")
_ = try requireTextView(in: contentView, identifier: "avatarCreateRawPrompt")
try expect(
    allSubviews(in: contentView).contains(where: { $0 is NSTableView }) == false,
    "studio avatar tab should no longer duplicate the picker list UI"
)
```

- [ ] **Step 2: Update the AppKit manual runner to use the new shell test names**

In `ThemeAppKitManualMain.swift`, replace the old two function calls with the new names so the red/green cycle hits the revised contract.

- [ ] **Step 3: Run the native shell checks to verify the new shell tests fail**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL because `AvatarStudioContentView` still renders segmented browse/create chrome, a read-only avatar list, and browse-mode-only affordances.

- [ ] **Step 4: Add only the new copy key needed for the picker handoff button**

Add the minimal new avatar-studio copy key in `config/copy/base.json`:

- `open_picker_button`

Use a value like:

```json
"open_picker_button": "打开更换形象"
```

Do not delete `create_mode_title` / `return_to_library_button` yet in this step. Leave cleanup for the final regression task.

- [ ] **Step 5: Collapse `AvatarStudioContentView` into a single workspace shell**

Refactor the view to remove dual-mode chrome:

- delete `AvatarStudioMode` from `InlineAvatarCreationModels.swift`
- remove `mode`, `modeControl`, `browseContainer`, `createContainer`
- remove `buildBrowseContainer()`, `buildAvatarListCard(...)`, `buildAvatarDetailCard(...)`
- remove `present(mode:)`, `enterBrowseMode(...)`, `enterCreateMode(...)`, `handleModeChanged()`, `handleReturnToAvatarLibrary()`
- replace them with one top reference card that shows:
  - current avatar preview image
  - avatar name
  - avatar style
  - short persona / traits summary
  - `打开更换形象` button
- keep the existing create prompt / preview / save action area mounted at all times

The reference card should reuse the same current-avatar data source the old browse card used; do not introduce a second store or new coordinator API just to render it.

- [ ] **Step 6: Run the native shell checks to verify the single-workspace shell passes**

Run: `bash tools/check_native_shell.sh`

Expected: PASS for the two new shell tests, while existing picker / theme / speech / config / runtime tests remain green.

- [ ] **Step 7: Commit the shell simplification**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Studio/AvatarStudioContentView.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift \
  config/copy/base.json \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift
git commit -m "refactor: collapse studio avatar tab into single workspace"
```

## Task 2: Keep The Avatar Creation State Machine Inside The New Shell

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Studio/AvatarStudioContentView.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Rewrite the avatar generation tests around the single workspace**

Update or replace the old create-mode-specific tests:

```swift
func testStudioAvatarCreateModeOptimizesRawPromptAndUsesOptimizedPromptForPreview() throws
func testStudioAvatarCreateModePreviewGenerationReturnsWithoutBlockingUI() throws
func testStudioAvatarCreateModeRequiresThreePreviewsAndNameBeforeSave() throws
func testStudioAvatarCreateModeSavesAndAppliesGeneratedAvatar() throws
```

with workspace-oriented equivalents:

```swift
func testStudioAvatarWorkspaceOptimizesRawPromptAndUsesOptimizedPromptForPreview() throws
func testStudioAvatarWorkspacePreviewGenerationReturnsWithoutBlockingUI() throws
func testStudioAvatarWorkspaceRequiresThreePreviewsAndNameBeforeSave() throws
func testStudioAvatarWorkspaceSavesAndAppliesGeneratedAvatar() throws
```

Lock these behaviors:

- raw prompt and optimized prompt stay separate
- preview generation consumes the optimized prompt
- preview / regenerate / save disable while preview is in flight
- save still waits for all `idle / working / alert` previews plus a non-empty name
- successful save keeps studio open, refreshes the top reference card, clears the draft fields, and leaves the avatar tab ready for another creation pass
- no test should depend on `返回现有形象` or a browse-mode transition

- [ ] **Step 2: Update the manual runner with the new workspace test names**

Replace the old avatar create-mode test calls in `ThemeAppKitManualMain.swift` with the renamed workspace variants.

- [ ] **Step 3: Run the native shell checks to verify the workspace state-machine tests fail**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL because the current save-complete path still returns to browse mode, the top reference card does not refresh as the new source of truth, and old mode-only controls are still baked into the state transitions.

- [ ] **Step 4: Re-implement the save / refresh flow without any browse-mode fallback**

Keep the existing creation draft state:

- `creationRawPrompt`
- `creationOptimizedPrompt`
- `creationPreviewDraft`
- `creationDraftName`
- `creationDraftPersona`
- `creationStage`

Then adjust the flow rules:

- `refreshAppliedAvatarSummary()` should update both the summary text and the new reference-card fields
- `updateCreateModeUI()` becomes the only draft-render function; it must not branch on a removed mode enum
- `completeSaveAndApply(with:)` should:
  - set `currentAvatarID = avatarID`
  - refresh the reference card from shared avatar data
  - reset the draft via `resetInlineAvatarCreationDraft()`
  - leave the same avatar workspace visible
- changing the optimized prompt must still invalidate any previous preview draft
- error handling must continue to leave the current applied avatar unchanged

Do not move bridge / asset-store work into the view. Keep using injected closures only.

- [ ] **Step 5: Run the native shell checks to verify the workspace state machine passes**

Run: `bash tools/check_native_shell.sh`

Expected: PASS for:

- optimized-prompt contract
- async preview non-blocking contract
- save gating contract
- save/apply refresh contract without browse-mode fallback

- [ ] **Step 6: Commit the workspace state-machine update**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Studio/AvatarStudioContentView.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift
git commit -m "feat: keep avatar generation flow inside shared workspace"
```

## Task 3: Rewire Picker And Coordinator Integration Around The Simplified Avatar Workspace

**Files:**
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Studio/StudioWindowController.swift`
- Modify: `apps/macos-shell/Sources/ICUShell/Avatar/AvatarPickerWindowController.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift`
- Modify: `apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift`

- [ ] **Step 1: Update the picker-to-studio integration tests to the new contract**

Update the existing integration coverage:

```swift
func testAvatarPickerCreateButtonLaunchesStudioAvatarCreateTarget() throws
func testSavingNewAvatarRefreshesPickerAndStudioAvatarLists() throws
```

to:

```swift
func testAvatarPickerCreateButtonLaunchesStudioAvatarWorkspace() throws
func testSavingNewAvatarRefreshesPickerListAndStudioReferenceCard() throws
```

Lock these behaviors:

- picker `＋ 新建形象…` still opens studio on the `形象生成` tab
- the opened studio shows `当前已应用形象` plus `打开更换形象`, not the old read-only avatar list
- saving a new avatar refreshes the picker table rows without reopening the picker
- saving a new avatar refreshes the studio top reference card without reopening the studio
- studio `打开更换形象` must open picker through the injected callback and keep the studio window visible

Use assertions in this shape:

```swift
try expect(
    waitForCondition(timeout: 0.2) { pickerTableView.numberOfRows == 3 },
    "picker should refresh to include the newly saved avatar without reopening"
)
_ = try requireLabel(in: studioContentView, stringValue: "当前已应用形象")
_ = try requireButton(in: studioContentView, title: "打开更换形象")
```

- [ ] **Step 2: Update `ThemeAppKitManualMain` to call the renamed integration tests**

Keep the existing avatar picker and studio coverage in place; only replace the outdated integration names.

- [ ] **Step 3: Run the native shell checks to verify the integration tests fail**

Run: `bash tools/check_native_shell.sh`

Expected: FAIL because studio launch and refresh semantics still depend on the now-removed browse/create distinction, and the shared refresh test still expects a studio-side avatar list.

- [ ] **Step 4: Simplify studio launch semantics in the coordinator and controller**

Implementation rules:

- in `StudioWindowController`, treat `.avatarBrowse` and `.avatarCreate` as the same visible avatar workspace
- do not let `setSelectedTarget(_:)` call any removed mode API on `AvatarStudioContentView`
- in `AvatarCoordinator.presentStudio(...)`, keep routing picker and menu entrypoints through the same `StudioWindowController` instance
- for picker `onCreateNew`, either:
  - switch to `presentStudio(target: .avatarBrowse)`, or
  - keep `.avatarCreate` as a compatibility alias

Pick one and keep it consistent; do not keep two different visual behaviors.

- `refreshAvatarControllers(selectedAvatarID:)` must continue to update both picker and studio when the current avatar changes
- `onOpenAvatarPicker` from the studio reference card must open picker without dismissing the studio window

- [ ] **Step 5: Run the native shell checks to verify the new routing passes**

Run: `bash tools/check_native_shell.sh`

Expected: PASS for picker launch, shared refresh, and all existing menu / window reuse / runtime tests.

- [ ] **Step 6: Commit the coordinator and picker integration update**

```bash
git add \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarCoordinator.swift \
  apps/macos-shell/Sources/ICUShell/Studio/StudioWindowController.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/AvatarPickerWindowController.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift \
  apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift
git commit -m "refactor: align picker and studio avatar routing"
```

If `AvatarPickerWindowController.swift` did not change, omit it from `git add`.

## Task 4: Run Final Regression And Remove Dead Browse-Mode Debris

**Files:**
- Modify: `config/copy/base.json`
- Optional Modify: `apps/macos-shell/Sources/ICUShell/Copy/UserVisibleCopyKey.swift`
- Optional Modify: `apps/macos-shell/Sources/ICUShell/Studio/AvatarStudioContentView.swift`
- Optional Modify: `apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift`

- [ ] **Step 1: Confirm which old browse-mode strings and helpers are now unused**

Run:

```bash
rg -n "create_mode_title|return_to_library_button|list_title|detail_title|AvatarStudioMode|handleModeChanged|enterBrowseMode|enterCreateMode" \
  config/copy/base.json \
  apps/macos-shell/Sources/ICUShell \
  apps/macos-shell/Tests/ManualRuntime
```

Expected: only intentionally retained compatibility references remain.

- [ ] **Step 2: Delete dead copy keys and helpers only after the last consumer is gone**

Clean up the dead browse-mode leftovers:

- remove `AvatarStudioMode` if still present
- remove old browse-mode-only methods from `AvatarStudioContentView`
- remove unused avatar-studio copy keys from `config/copy/base.json`
- only touch `UserVisibleCopyKey.swift` if a new strongly typed copy key was added and now needs a default

Do not perform speculative copy cleanup. If a key is still referenced, leave it alone and move on.

- [ ] **Step 3: Run the native shell regression suite**

Run: `bash tools/check_native_shell.sh`

Expected: PASS

- [ ] **Step 4: Run the packaged verification entrypoint**

Run: `./icu --verify`

Expected:

- `swift build` succeeds
- runtime smoke checks pass
- if the machine only has Command Line Tools, `swift test` may be skipped explicitly by the script

- [ ] **Step 5: Manual smoke-check the actual app**

Run:

```bash
./icu
```

Verify these interactions manually:

- `更换形象` opens the picker and still applies an existing avatar
- picker `＋ 新建形象…` opens studio on the avatar workspace
- studio `打开更换形象` reopens the picker without closing the studio
- `保存并应用` updates the running pet immediately and leaves the studio on the same avatar tab
- `生成配置` still opens and preserves the current accordion / save / test-connection behavior

- [ ] **Step 6: Commit the final cleanup and verification checkpoint**

```bash
git add \
  config/copy/base.json \
  apps/macos-shell/Sources/ICUShell/Copy/UserVisibleCopyKey.swift \
  apps/macos-shell/Sources/ICUShell/Studio/AvatarStudioContentView.swift \
  apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift
git commit -m "chore: clean up avatar studio browse-mode leftovers"
```

If some optional files were untouched, omit them from `git add`.
