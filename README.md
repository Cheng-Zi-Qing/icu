# I.C.U. — Native macOS Desktop Pet

[中文](README_CN.md) | English

> A Swift/AppKit desktop pet for macOS. A pixel-art capybara by default, health reminders
> while you work, a wardrobe to dress it up, and live reactions to your Claude Code sessions.

[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://www.swift.org/)
[![Platform](https://img.shields.io/badge/macOS-14%2B-green.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## What it does

- **A pet that lives on your desktop.** Pixel-art capybara, idle / working / focus / break
  states, hand-drawn frame animations, gaze tracking, head pats, naps and random idle bits.
- **Health reminders while you work.** Eye-care reminders (20-20-20 by default) and hydration
  reminders computed from your body weight, cup size and work hours.
- **Claude Code awareness.** Connect the pet to Claude Code and it plays a small scene for what
  your agent is doing — reading, searching, writing, running Bash, spawning sub-agents — and
  pokes you when a session is waiting on you.
- **A wardrobe.** Dress the pet from `config/wardrobe.json`; outfits with a full sprite set
  swap every frame.
- **Window behaviour that stays out of the way.** Drag it around with springy physics, it snaps
  to screen edges, hides itself when idle, and peeks its head back out.
- **Overridable copy.** Every user-visible string comes from `config/copy/base.json`, so you can
  reword the pet without recompiling.

Python is no longer part of this project. The app is Swift/AppKit only.

## Quick start

### Requirements

- macOS 14 or later
- Apple Command Line Tools (`xcode-select --install`) — enough to build and run
- Full Xcode is optional; it is only needed if you want `swift test` to run inside `./icu --verify`

### Launch

```bash
git clone https://github.com/Cheng-Zi-Qing/icu.git
cd icu
./icu
```

This runs `swift run ICUShell` for `apps/macos-shell` with an isolated SwiftPM scratch path
(`~/Library/Caches/icu/swiftpm/…`), so you never need to clear `.build` by hand.

First launch puts the pet near the bottom-right corner; later launches restore the last
on-screen position. A work session that was still active when you quit is normalised back to
`idle`, so the pet never boots straight into `working`.

### Verify

```bash
./icu --verify
```

Runs, in order:

1. `swift build` for `apps/macos-shell`
2. the manual runtime checks (`tools/check_native_shell.sh`, plain `swiftc` — no Xcode needed)
3. `swift test`, but only when `xcodebuild` is available; otherwise it is skipped explicitly

### Package a local `.app`

```bash
./icu --package-app
bash tools/check_macos_app_bundle.sh dist/ICU.app
```

Release-flavoured checks (bundle structure plus a detached runtime smoke test):

```bash
VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 \
VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1 \
./icu --verify
```

Signing and notarization notes: [`docs/macos-shell-release.md`](docs/macos-shell-release.md),
env template at `tools/macos_shell_release.env.example`.

## Using the pet

### Menu bar

| Item | What it does |
|------|--------------|
| 显示桌宠 | Show the pet window |
| 衣柜 | Open the wardrobe |
| 设置… | Open the settings window |
| 接入 / 断开 Claude Code | Install or remove the Claude Code hook |
| 退出 | Quit |

The Claude Code item only appears when the `icu-hook` binary can be found next to the app.

### Pet right-click menu

| State | Items |
|-------|-------|
| idle | 开始工作 |
| working | 进入专注 · 暂离 · 下班 |
| focus / break | 回来工作 · 下班 |
| any | 衣柜 · 设置… · (Claude Code) · 隐藏桌宠 · 退出 |

### Work states

`idle → working → focus / break → working → idle`

- 开始工作 arms the eye-care and hydration reminders.
- 进入专注 pauses them and switches the pet to a focus look.
- 暂离 pauses them too; 回来工作 re-arms them and the pet suggests a short break if the focus
  stretch was long.
- 下班 stops everything and cancels pending snoozes.

### Reminder cards

- **Eye care** — countdown card (20 s for 20-20-20, 5 min for the hourly preset) with three
  actions: a random done label (看过了 / 好嘞 / 看完啦 …), 等会儿 (snoozes 5 minutes), and a random
  refusal (我就不 / 不要 / 偏不). The card title is a random quip too, so it never sounds the same twice.
- **Hydration** — no countdown, shows 第 x/y 杯 with a 10-segment progress bar (超额 N 杯 once you are
  past the goal).
- Reminder wording: the card title and button labels are random pools in `Pet/ReminderQuips.swift`;
  the reminder sentence itself (`pet.eye_reminder` / `pet.hydration_reminder`) is overridable through
  the copy catalog.

### Settings window

- 健康资料: 体重, 杯子容量, 每天工作
- 提醒: 护眼方式 — `20-20-20 推荐` (20 min / 20 s), `每小时歇歇` (60 min / 5 min), or
  `自定义` (60 s – 4 h)
- A live line shows the derived hydration plan, e.g. 建议上班时喝 6 杯（约 2050 ml）/ 每 80 分钟提醒一次

Hydration maths: 35 ml per kg per day, 65 % of that inside your work hours, split into cups of
your cup size, one reminder per cup.

### Wardrobe

`config/wardrobe.json` declares items with a slot (`head`, `mouth`, `neck`, `face`), a rarity and
whether you own it by default, plus ready-made 套装. An item with a `sprite_set` (currently
草帽) has a complete frame set under `assets/pets/<pet>/outfits/<sprite_set>/`, so every
animation — idle, work, drag, edge peek, sleep — follows the outfit.

## Claude Code integration

The pet can follow your Claude Code sessions. From the menu bar or the pet menu, choose
接入 Claude Code:

- `icu-hook` (a second executable in the same package) is copied to
  `<App Support>/ICU/bin/icu-hook` and registered in `~/.claude/settings.json`
  (`CLAUDE_CONFIG_DIR` is respected).
- Your `settings.json` is backed up before the first write; your own hooks and settings are kept.
- Every registered hook is `async`, so Claude Code never waits on the pet.
- Uninstalling removes only entries whose command contains `/bin/icu-hook`.

While connected, the pet plays a scene for what the agent is doing
(`assets/pets/<pet>/work/scenes.json`): 思考中, 读取中, 搜索中, 更新中, 运行 Bash, 子 Agent 运行中.
Sessions waiting on a permission prompt or a question get a card so you can jump back to the
right terminal or IDE.

**Privacy boundary.** `icu-hook` records state only. Prompts, commands, tool arguments, model
responses and transcript paths are never written to disk. What is kept: session id, event name,
tool *name*, error kind, the last path component of the working directory (the project folder
name), the frontmost app bundle id, and a timestamp.

## Persistence

Everything lives under App Support:

```
~/Library/Application Support/ICU/
├── config/      # settings.json, wardrobe state, copy overrides
├── state/       # current_state.json, health metrics
├── assets/      # pets installed at runtime
├── agents/      # one JSON per Claude Code session, written by icu-hook
├── logs/
└── bin/         # installed icu-hook
```

Point the whole tree somewhere else for development:

```bash
ICU_APP_SUPPORT_ROOT=/tmp/icu-dev ./icu
```

Copy overrides: drop an `active.json` next to `config/copy/base.json` (App Support first, then the
repo checkout) and only the keys you list change.

### Config files in the repo

| File | What it holds |
|------|---------------|
| `config/settings.json` | First-launch defaults: `edge_snap`, `timers`, `user` |
| `config/wardrobe.json` | Wardrobe items and ready-made suits |
| `config/copy/base.json` | Every user-visible string |

The edge-snap block (`enabled`, `snap_distance`, `peek_width`, `auto_hide_delay`) is read at launch
but has no settings UI yet — edit `config/settings.json` to change it.

## Project structure

```
icu/
├── icu                          # root launcher: ./icu [--verify|--package-app]
├── apps/macos-shell/            # the whole app
│   ├── Sources/ICUShell/        # app target
│   │   ├── Agent/               # Claude Code sessions, hook installer, agent board
│   │   ├── Copy/                # user-visible string catalog + overrides
│   │   ├── Health/              # profile, hydration plan, metrics store
│   │   ├── Menu/                # menu bar panel
│   │   ├── Pet/                 # pet window, animation, behaviour, drag, edge dock, work scenes
│   │   ├── Runtime/             # state machine, settings, persistence, asset lookup
│   │   ├── Settings/            # settings window (pixel form controls)
│   │   ├── Theme/               # pixel theme
│   │   ├── UI/Pixel/            # pixel button / font / icon / paint / window
│   │   └── Wardrobe/            # outfit catalog, window, state
│   ├── Sources/ICUHook/         # Claude Code hook executable
│   ├── Tests/ICUShellTests/     # unit tests (swift test)
│   └── Tests/ManualRuntime/     # headless AppKit runtime checks
├── assets/
│   ├── fonts/                   # pixel fonts + their licenses
│   └── pets/capybara/           # frames, config.json, outfits, cursors
├── config/                      # settings.json, wardrobe.json, copy/base.json
├── tools/                       # build / verify / package / test scripts
│   └── pixel_pets/capybara/     # Node asset pipeline for the pet's frames
└── docs/                        # release guide, animation engine design
```

### Pet asset layout

```
assets/pets/capybara/
├── config.json        # id, name, style, persona notes (metadata only), animation metadata
├── base.png           # fallback still image
├── idle/              # idle animations, one directory per variant (main, chew)
├── idle_act/          # random idle bits (bird, wobble)
├── react/ sleep/      # patted, napping, waking
├── work/              # Agent activity scenes + scenes.json
├── drag/ edge/        # lifted / dizzy frames, edge peek and turn frames
├── cursor/            # grab / grabbing / pat cursors
├── ui/                # menu bar and wardrobe icons
└── outfits/           # per-outfit frame overrides
```

`config.json` `animations` sets `fps`, `loop_mode` and `default_variant` per state. The `persona`
block is documentation only — the app does not read it yet.
`work/scenes.json` maps a scene name to key-frame order and fps, and `"motion": "chase"` makes
the pet slide left and right while playing it.

### Regenerating pet assets

The frames are produced by a small Node pipeline, not by hand:

```bash
node tools/pixel_pets/capybara/build.mjs      # render everything
node tools/pixel_pets/capybara/validate.mjs   # check the output
node tools/pixel_pets/capybara/editor.js      # local pixel editor
```

## Tech stack

| Technology | Purpose |
|------------|---------|
| Swift 5.10 / SwiftPM | Whole app, two executables (`ICUShell`, `icu-hook`) |
| AppKit / Core Animation | Pet window, menus, panels, layered pixel animation |
| Node.js | Pixel-art asset pipeline (`tools/pixel_pets/`) |
| Claude Code hooks | Agent session awareness |

## Scientific basis

The reminders follow published guidance; the citations below are the ones the settings UI
quotes.

### Eye care — 20-20-20 and digital eye strain

- **[The 20/20/20 rule: Practicing pattern and associations with asthenopic symptoms](https://pubmed.ncbi.nlm.nih.gov/37203083/)**
  (Talens-Estarelles et al., *Contact Lens & Anterior Eye* 46:101744, 2023) — using reminders to
  follow the 20-20-20 rule reduces eye fatigue and dry-eye symptoms.
  [Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC10391416/)
- **[Digital Eye Strain — A Comprehensive Review](https://pmc.ncbi.nlm.nih.gov/articles/PMC9434525/)**
  — blink rate falls from about 18.4 to 3.6 blinks/min during screen work, breaking up the tear
  film.
- **[A field study of supplementary rest breaks for data-entry operators](https://pubmed.ncbi.nlm.nih.gov/10877480/)**
  (Galinsky et al., *Ergonomics* 43(5):622, 2000) — supplementary 15-min breaks reduced both
  musculoskeletal discomfort and eyestrain without lowering output; this is the 每小时歇歇 preset.

### Stretch — sedentary work

- **[The short term musculoskeletal and cognitive effects of prolonged sitting during office
  computer work](https://pubmed.ncbi.nlm.nih.gov/30087262/)** — after 2 h of continuous sitting,
  musculoskeletal discomfort rises and creative problem-solving error rates increase.
  [Full text](https://pmc.ncbi.nlm.nih.gov/articles/PMC6122014/)
- **[Assessment of stresses in the cervical spine caused by posture and position of the head](https://pubmed.ncbi.nlm.nih.gov/25393825/)**
  (Hansraj, *Surgical Technology International* 25:277, 2014) — cervical load rises from roughly
  4.5–5.4 kg in neutral to about 12.2 kg at 15° of forward tilt, 22.2 kg at 45° and 27.2 kg at 60°.
- **[Musculoskeletal neck pain in children and adolescents: Risk factors and complications](https://pmc.ncbi.nlm.nih.gov/articles/PMC5445652/)**
  — every participant in the series reported flawed back-and-neck flexion while studying and/or
  using a smartphone.

### Hydration — mild dehydration

- **[The Hydration Equation: Update on Water Balance and Cognitive Performance](https://pmc.ncbi.nlm.nih.gov/articles/PMC4207053/)**
  — a 1–2 % body-fluid loss already increases mental fatigue, lowers attention and slows
  reaction time; thirst is a late signal.
- **[Water, Hydration and Health](https://pmc.ncbi.nlm.nih.gov/articles/PMC2908954/)** — kidneys
  excrete at most about 1 L/hour, so large single drinks are wasted; frequent small sips work
  better. This is why the plan splits the day into cups.

Eye care and hydration reminders are implemented today. Stretch reminders are **not** — the
`stretch_interval` key in `config/settings.json` is not read by the app yet.

## Roadmap

Implemented:

- Desktop pet with state machine, layered pixel animation, gaze, pats, naps
- Eye-care and hydration reminders with snooze
- Settings window with health profile and eye-care presets
- Wardrobe with outfit frame sets
- Edge snapping, auto-hide, edge peek
- Drag physics with stretch and lift poses
- Claude Code session awareness with privacy-preserving hook
- Overridable copy catalog
- Local `.app` packaging, bundle check, runtime smoke test

Not yet:

- Stretch / sedentary reminders (research above is the basis; see the `stretch_interval` gap)
- Health metrics dashboard and daily / weekly reports (raw events and daily/weekly aggregation
exist in `Health/HealthMetricsStore.swift`, but nothing renders them yet)
- More pets — the asset pipeline supports them, only the capybara ships
- Full frame sets for the remaining wardrobe items (only 草帽 has one today)
- More languages (copy is Simplified Chinese; the catalog is built for overrides)
- Cloud sync

## License

MIT — see [LICENSE](LICENSE).

Pixel fonts under `assets/fonts/` keep their own licenses (OFL and friends) in
`assets/fonts/LICENSES/`.
