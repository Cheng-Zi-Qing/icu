# I.C.U. - Native macOS AI Desktop Pet

[中文](README_CN.md) | English

> A Swift/AppKit desktop pet for macOS with a default pixel theme, stateful work modes,
> and a lightweight `./icu` launcher for local development.

[![Swift](https://img.shields.io/badge/Swift-6-orange.svg)](https://www.swift.org/)
[![Platform](https://img.shields.io/badge/Platform-macOS-green.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Current Runtime

- `./icu` launches the native Swift/AppKit shell under `apps/macos-shell`.
- The default GUI theme is pixel style and currently covers the desktop pet, status bubble, right-click menu, avatar studio, and model workbench.
- The runtime state machine is `idle -> working -> focus/break -> working -> idle`.
- On cold launch, persisted active sessions are normalized back to `idle` while preserving window placement.
- First launch places the pet near the bottom-right corner; later launches restore the last saved position when it is still visible on screen.
- Lightweight local development works with Apple Command Line Tools installed via `xcode-select --install`; full Xcode is optional and only needed if you want `swift test` during verification.
- Python is no longer part of the app bootstrap path. It is retained only for avatar-generation bridge work.
- Default user-visible copy is currently Simplified Chinese, and the copy catalog is overrideable.

## What You Can Do Today

- Launch a floating desktop pet and control it from the menu bar panel or the pet's right-click menu.
- Use `更换形象` to open a unified studio with three tabs: `主题风格`, `桌宠形象动画`, and `话术`.
- Use `生成配置` as a model workbench for the three capability buckets: `文本描述`, `动画形象`, and `主题代码`.
- Generate drafts, preview them, regenerate if they are not good enough, and only then apply them.
- Switch built-in pets or save AI-generated custom pets.
- Override user-visible copy without recompiling the app.

## 🚀 Quick Start

### Requirements

- macOS
- Apple Command Line Tools or Xcode
- `swift` available in your shell
- Optional: full Xcode if you want `swift test` to run as part of `./icu --verify`

Install Command Line Tools in lightweight mode:

```bash
xcode-select --install
```

### Launch

```bash
git clone https://github.com/yourusername/icu.git
cd icu
./icu
```

This launches the Swift/AppKit shell from the current checkout.

Launch behavior:

- The pet is shown near the bottom-right corner on first launch.
- A saved on-screen position is restored automatically on later launches.
- A previously persisted active work state is normalized to `idle` on launch, so the pet does not immediately come up in `working`.
- The launch script uses an isolated SwiftPM scratch path, so you should not need to manually clear `apps/macos-shell/.build`.

### Verify

```bash
./icu --verify
```

This verification flow:

- runs `swift build` for `apps/macos-shell`
- runs the manual runtime checks
- runs `swift test` only when full Xcode is active

If your machine only has Command Line Tools, `./icu --verify` still works and explicitly skips `swift test`.

### Package a local `.app`

```bash
./icu --package-app
bash tools/check_macos_app_bundle.sh dist/ICU.app
```

Low-level helpers:

```bash
bash tools/run_macos_shell.sh
bash tools/verify_macos_shell.sh
```

For packaging, signing, and notarization notes, see:

```bash
docs/macos-shell-release.md
```

Release env template:

```bash
tools/macos_shell_release.env.example
```

Optional release-flavored verification:

```bash
VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 \
VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1 \
./icu --verify
```

### Runtime Controls

Menu bar panel:

- `显示桌宠`
- `更换形象`
- `生成配置`
- `退出`

Desktop pet right-click menu while idle:

- `开始工作`
- `更换形象`
- `生成配置`
- `隐藏桌宠`
- `退出`

Desktop pet right-click menu while working:

- `进入专注`
- `暂离`
- `下班`
- `更换形象`
- `生成配置`
- `隐藏桌宠`
- `退出`

Desktop pet right-click menu while in focus or break:

- `回来工作`
- `下班`
- `更换形象`
- `生成配置`
- `隐藏桌宠`
- `退出`

Current reminder behavior:

- Entering `working` arms the eye-care and hydration reminders.
- Entering `focus` pauses reminders.
- Returning from `focus` or `break` re-arms reminders.
- The migrated Swift shell currently ships eye-care + hydration reminders plus the daily/weekly health report flow; stretch remains roadmap work.

### Model Workbench (`生成配置`)

`生成配置` is for model configuration only. It does not generate or apply assets by itself.

Current capability tabs:

- `文本描述`: turns a prompt into structured textual intent
- `动画形象`: generates avatar and motion image assets
- `主题代码`: turns textual intent into theme drafts

Current provider set:

- `ollama`
- `huggingface`
- `openai-compatible`

Each capability stores:

- provider
- model
- base URL
- auth JSON
- options JSON

### Unified Avatar Studio (`更换形象`)

`更换形象` is the place where generation, preview, regeneration, and apply actually happen.

Tabs:

- `主题风格`
- `桌宠形象动画`
- `话术`

Current workflow by design:

1. Write the raw prompt.
2. Optimize the prompt.
3. Generate a preview.
4. Regenerate until the draft is acceptable.
5. Apply only when satisfied.

Tab specifics:

- `主题风格` previews the desktop pet bubble, right-click menu chrome, and form controls before applying the theme.
- `桌宠形象动画` can browse installed pets or create a new one by generating `idle`, `working`, and `alert` action images, then saving and applying the result.
- `话术` generates a text draft and a real bubble preview before applying copy overrides.

### Persistence and File Locations

Runtime state:

```bash
~/Library/Application Support/ICU/state/current_state.json
```

Model settings and active theme selection:

```bash
~/Library/Application Support/ICU/config/settings.json
```

Speech and user-visible copy overrides:

```bash
~/Library/Application Support/ICU/config/copy/active.json
```

Generated theme packs:

```bash
~/Library/Application Support/ICU/state/themes/
```

When running from a source checkout, generated custom avatar image assets are currently saved into:

```bash
assets/pets/<avatar_id>/
```

Advanced override for app-support root:

```bash
ICU_APP_SUPPORT_ROOT=/tmp/icu-dev ./icu
```

### Python Boundary

Python is retained only for avatar-generation bridge work:

- `tools/avatar_builder_bridge.py`
- `builder/`

The following runtime surfaces are now native Swift/AppKit and do not depend on the old Python startup path:

- app launch
- desktop pet window
- right-click menu
- menu bar panel
- state transitions
- theme runtime
- bubble rendering

## 📚 Scientific Foundation

The research links below describe the broader product direction. In the current Swift shell, eye-care and hydration reminders plus the health report flow are already active. Stretch and richer coaching remain roadmap work.

### 👁️ Eye Care Module: 20-20-20 Rule & Digital Eye Strain (DES)

**Primary Research:**
- **[The 20/20/20 rule: Practicing pattern and associations with asthenopic symptoms](https://pubmed.ncbi.nlm.nih.gov/37203083/)**
  - Confirms that following the 20-20-20 rule (every 20 minutes, look 20 feet away for 20 seconds) effectively reduces eye dryness, burning sensation, and blurred vision
  - [Full text on PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC10391416/)

**Advanced Research:**
- **[Digital Eye Strain - A Comprehensive Review](https://pmc.ncbi.nlm.nih.gov/articles/PMC9434525/)**
  - Blink rate drops dramatically during computer use: from 18.4 blinks/min to 3.6 blinks/min
  - Reduced blinking causes tear film breakup and evaporation, leading to DES

### 🧘 Stretch Module: Sedentary Impact on Musculoskeletal & Cognition

**Primary Research:**
- **[The Short Term Musculoskeletal and Cognitive Effects of Prolonged Sitting During Office Computer Work](https://pubmed.ncbi.nlm.nih.gov/30087262/)**
  - After 2 hours of continuous sitting, musculoskeletal discomfort increases significantly (especially lower back)
  - Error rates in creative problem-solving tasks increase
  - Strongly recommends micro-breaks to interrupt prolonged sitting
  - [Full text on PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC6122014/)

**Advanced Research:**
- **[Musculoskeletal neck pain in children and adolescents: Risk factors and complications](https://pmc.ncbi.nlm.nih.gov/articles/PMC5445652/)**
  - Head weight in neutral position: 4.54-5.44 kg (10-12 lbs)
  - Forward head posture (FHP) dramatically increases cervical spine load:
    - 15° forward: 12.25 kg
    - 45° forward: 22.23 kg
    - 60° forward: 27.22 kg (60 lbs)
  - Prolonged FHP leads to "text neck" syndrome

### 💧 Hydration Module: Mild Dehydration & Cognitive Performance

**Primary Research:**
- **[The Hydration Equation: Update on Water Balance and Cognitive Performance](https://pmc.ncbi.nlm.nih.gov/articles/PMC4207053/)**
  - Just 1-2% body fluid loss (threshold for thirst sensation) impairs:
    - Mental fatigue increases
    - Attention decreases
    - Reaction time slows
    - Mood deteriorates
  - Don't wait until thirsty - maintain frequent, small-volume intake

**Advanced Research:**
- **[Water, Hydration and Health](https://pmc.ncbi.nlm.nih.gov/articles/PMC2908954/)**
  - Kidney's maximum urine output: ~1 L/hour
  - Drinking large volumes at once is ineffective - excess water is rapidly excreted
  - Supports "frequent small sips" hydration strategy

## 🛠️ Tech Stack

| Technology | Purpose |
|------------|---------|
| Swift 6 / SwiftPM | Native macOS shell |
| AppKit | Desktop pet window and menu interactions |
| Python 3.9+ | Avatar-generation bridge only, not the startup path |
| Ollama | Local AI (optional) |
| Hugging Face Inference API | Image generation |
| SQLite | Data persistence |

## 📁 Project Structure

```
icu/
├── icu                     # Swift-first root launcher (`./icu`)
├── apps/
│   └── macos-shell/        # Swift/AppKit runtime app
├── builder/                # AI generation tools
│   ├── prompt_optimizer.py # Prompt enhancement
│   ├── vision_generator.py # Image generation
│   └── persona_forge.py    # Personality creation
├── docs/macos-shell-release.md # Release and packaging notes
├── src/                    # Remaining legacy non-UI Python modules
├── assets/pets/            # Pet avatars & configs
└── config/                 # User settings
```

## 🎯 Roadmap

- [x] PRD 1.1: FSM + Health Reminders
- [x] PRD 1.2: Desktop Pet Widget
- [x] PRD 1.3: Reports + AI Assistant
- [x] PRD 1.4: Custom Avatar Creator
- [ ] Multi-language support
- [ ] Cloud sync (optional)
- [ ] Mobile companion app

## 📄 License

MIT License - See [LICENSE](LICENSE) file

---

**Made with ❤️ for developers who care about health**
