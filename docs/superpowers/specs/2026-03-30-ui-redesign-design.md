# UI Redesign: 更换形象 / 创作工坊 / 生成配置

**Date:** 2026-03-30
**Status:** Approved

## Problem

The current "更换形象" window is a 1720-line monolith that mixes three unrelated concerns (theme studio, avatar animation studio, speech studio) into a single tabbed window. The "生成配置" window has no explicit save button, uses raw JSON strings for auth fields, and tears down/rebuilds the entire UI on every accordion toggle. Both interfaces were Codex-generated and lack coherent UX structure.

## Decisions

| Question | Decision |
|---|---|
| Overall structure | Option A: Three separate, focused windows |
| 更换形象 layout | Left list + right preview |
| 生成配置 layout | Accordion panels |
| 创作工坊 navigation | Left sidebar |
| Scope | All three windows — picker, studio, config |

## Architecture

Right-click menu gains one new entry:

```
更换形象        → AvatarPickerWindowController  (new)
创作工坊        → StudioWindowController         (new, replaces AvatarSelectorWindowController)
生成配置        → GenerationConfigWindowController (rewritten)
```

`AvatarSelectorWindowController` and `AvatarWizardWindowController` are deleted. The menu model and coordinator wiring are updated accordingly.

---

## Window 1: 更换形象 (AvatarPickerWindowController)

**Size:** 520 × 380
**Purpose:** Browse and apply an existing avatar. Nothing else.

### Layout

```
┌─────────────────────────────────────────┐
│  更换形象                           [✕] │
├────────────┬────────────────────────────┤
│ 5 个形象   │                            │
│────────────│      [  96×96 preview  ]   │
│ ▶ 水豚 ●  │                            │
│   海豹     │  水豚                      │
│   马       │  像素风                    │
│   奶牛     │                            │
│   人类     │  慢热稳健，不急不躁…       │
│────────────│                            │
│ ＋ 新建…   │                            │
├────────────┴──────────────┬────────────┤
│                            │  取消  应用│
└────────────────────────────────────────┘
```

### Behaviour

- Selecting a row immediately updates the right-side preview (image + name + style + persona).
- "●" badge marks the currently applied avatar.
- "＋ 新建形象…" opens StudioWindowController on the 形象生成 tab.
- Double-clicking a row is equivalent to clicking Apply.
- Apply closes the window.
- Cancel closes without changing the avatar.

### Components

- `AvatarPickerWindowController` — window lifecycle, delegates
- Left panel: `NSTableView` with thumbnail + name cells
- Right panel: `NSImageView` + labels (name, style, persona)
- Footer: Cancel / Apply buttons

---

## Window 2: 创作工坊 (StudioWindowController)

**Size:** 720 × 520
**Purpose:** AI-assisted creation of themes, avatar animations, and speech styles.

### Layout

```
┌──────────────────────────────────────────────────────┐
│  创作工坊                                       [✕]  │
├─────────────┬────────────────────────────────────────┤
│ 创作工坊    │  [Current applied banner]              │
│─────────────│                                        │
│ ▶ 主题风格  │  [Prompt input — tall text area]       │
│   形象生成  │                                        │
│   话术      │  [Draft preview card]                  │
│             │                                        │
│             │                    优化 prompt  预览  应用│
└─────────────┴────────────────────────────────────────┘
```

### Left Sidebar

Fixed 128 px width. Three nav items: 主题风格 / 形象生成 / 话术. Active item uses accent background. Clicking switches the right content area without rebuilding the sidebar.

### Right Content Area — shared structure

Every tab follows the same three-zone pattern:

1. **Applied banner** — read-only card showing what is currently active (theme name, avatar name, or speech preview). Always visible.
2. **Prompt zone** — label + hint + `NSTextView`. Accepts freeform input.
3. **Draft preview card** — shows the last generated draft summary, or a placeholder if nothing has been generated yet.
4. **Action bar** — right-aligned buttons. Disabled states enforced:
   - "优化 prompt" always enabled once there is input.
   - "预览效果" / "重新生成" enabled only after optimization.
   - "应用" enabled only when a valid draft exists and prompt hasn't changed since last preview.

### Tab: 主题风格

- Applied banner: current ThemePack name + short description.
- Prompt zone: single `NSTextView` for raw prompt.
- Draft preview card: shows generated theme name and a mini chrome preview (menu items + a button + bubble chip rendered with the draft theme tokens).
- Action bar: 优化 prompt → 预览效果 → 应用主题.

### Tab: 形象生成

Two sub-modes, toggled by a segmented control at the top of the content area:

**Browse mode** (default)
- Applied banner: current avatar name + style.
- Read-only avatar list (same visual as picker, but no Apply button).
- Link: "切换形象请使用「更换形象」" — opens AvatarPickerWindowController.

**创建新形象 mode**
- Prompt zone: raw prompt input.
- After optimizing, shows three preview image placeholders (idle / working / alert) with ● / ○ status per action.
- Name field + persona field below previews.
- Action bar: 优化 prompt → 生成预览 → 重新生成 → 保存并应用.
- "保存并应用" is enabled only when all three action images are generated and name is non-empty.

### Tab: 话术

- Applied banner: current speech summary text.
- Prompt zone: describe desired personality, tone, response style.
- Draft preview card: shows generated text samples and a bubble chip preview.
- Action bar: 生成草稿 → 重新生成 → 应用话术.

### Error handling

All generation errors surface in a status label below the action bar (red text). The label is hidden when idle.

---

## Window 3: 生成配置 (GenerationConfigWindowController — rewritten)

**Size:** 560 × 460
**Purpose:** Configure AI backend connections for the three capability types.

### Layout

```
┌──────────────────────────────────────────┐
│  生成配置                           [✕]  │
│  配置每个生成能力的模型和接入方式         │
│──────────────────────────────────────────│
│  ▲ 文字描述          ● 已配置            │
│  ┌────────────────────────────────────┐  │
│  │ 提供商  [Ollama ▾]  模型 [______ ] │  │
│  │ Base URL [________________________]│  │
│  │ Auth Token [___________] （可选）  │  │
│  │                      [测试连接]    │  │
│  └────────────────────────────────────┘  │
│  ▼ 形象动画          未配置              │
│  ▼ 代码生成          未配置              │
│──────────────────────────────────────────│
│                          取消      保存  │
└──────────────────────────────────────────┘
```

### Accordion behaviour

- Each panel header shows: capability name + configured status (● 已配置 / 未配置).
- Clicking the header toggles expand/collapse with an animation.
- Only one panel expanded at a time is **not** enforced — user can compare two panels.
- Expanding/collapsing does **not** rebuild the whole UI; only the panel's content view is shown/hidden.

### Fields

| Field | Input type | Notes |
|---|---|---|
| 提供商 | `NSPopUpButton` dropdown | ollama / huggingface / openai-compatible |
| 模型 | `NSTextField` | plain text |
| Base URL | `NSTextField` | plain text, validated on save |
| Auth Token | `NSTextField` | single string, not JSON; label says "可选" |

Options (`[String: Double]`) are removed from the UI entirely — they are preserved on load/save but not exposed. Advanced users can edit `settings.json` directly.

### 测试连接

Per-panel button. Fires an async ping to the configured base URL with the given model. Shows inline result: ● 已连接 (green) or ✕ 连接失败: \<reason\> (red).

### Save

Single "保存" button in the footer writes all three capability configs atomically. "取消" discards all unsaved changes. There is no auto-save on tab switch.

---

## File Plan

### New files
- `Avatar/AvatarPickerWindowController.swift`
- `Studio/StudioWindowController.swift`
- `Studio/StudioSidebarView.swift`
- `Studio/ThemeStudioContentView.swift`
- `Studio/AvatarStudioContentView.swift`
- `Studio/SpeechStudioContentView.swift`

### Rewritten files
- `Generation/GenerationConfigWindowController.swift` — full rewrite

### Deleted files
- `Avatar/AvatarSelectorWindowController.swift`
- `Avatar/AvatarWizardWindowController.swift`

### Modified files
- `Menu/StatusItemMenuModel.swift` — add 创作工坊 entry, rewire coordinators
- `Avatar/AvatarCoordinator.swift` — open picker or studio as appropriate

---

## Key Constraints

- All windows use `AvatarPanelTheme` for colours/fonts — no new colour literals.
- Generation calls are async (background queue) with request-ID cancellation guard (pattern already established in the existing code).
- `GenerationConfigWindowController` must not auto-save on tab switch; save is explicit only.
- Auth field is a plain string — no JSON parsing for auth in the UI layer.
- `StudioWindowController` sidebar switching must not rebuild the window; only swap the right content view.
