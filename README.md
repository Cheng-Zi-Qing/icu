# I.C.U. — Native macOS Desktop Pet

[中文](README_CN.md) | English

> A Swift/AppKit desktop pet for macOS. A pixel-art capybara, health reminders while you work,
> a wardrobe to dress it up, and live reactions to your Claude Code sessions.

[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://www.swift.org/)
[![Platform](https://img.shields.io/badge/macOS-14%2B-green.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## What it is

- A pet that lives on your desktop: pixel-art capybara, idle / working / focus / break states,
  frame-by-frame animation, gaze tracking, head pats, naps and random idle bits.
  Poke it and it reacts to where you poked: a ticklish belly, impatient paws, a sneezy nose,
  a jumpy back, and it turns its back on you if you keep poking.
- Health reminders while you work: eye care (20-20-20 by default) and hydration, computed from
  your weight, cup size and work hours.
- Claude Code awareness: it plays a small scene for whatever your agent is doing, and pokes you
  when a session is waiting on you.
- A wardrobe: dress it up from `config/wardrobe.json`; outfits with a full frame set swap every
  animation.
- It stays out of the way: drag it around with springy physics, it snaps to screen edges and
  hides itself when idle.
- Every user-visible string is overridable in `config/copy/base.json`, no recompile needed.

No Python anywhere — the app is Swift/AppKit only.

## Run it

```bash
git clone https://github.com/Cheng-Zi-Qing/icu.git
cd icu
./icu
```

Needs macOS 14+ and Apple Command Line Tools (`xcode-select --install`); full Xcode is optional.

```bash
./icu --verify       # build + runtime checks, plus swift test when Xcode is present
./icu --package-app  # produce dist/ICU.app
```

Signing, notarization and the release env template: [`docs/macos-shell-release.md`](docs/macos-shell-release.md).

## Day to day

The UI ships in Chinese and English; `Settings… → Language` switches between them, no relaunch
needed. Menu labels below are the English ones.

Menu bar: `Show Pet` · `Wardrobe` · `Settings…` · `Connect Claude Code` / `Disconnect Claude Code` · `Quit`

Right-click the pet:

- not at work → `I'm Starting Work`
- at work → `I Need to Focus` · `Stepping Away` · `Done for Today`
- focusing / away → `I'm Back` · `Done for Today`
- any state → `Wardrobe` · `Settings…` · `Hide Pet` · `Quit`

The menu is you talking; the chip under the pet is the capybara talking (Chilling / With you /
Staying quiet / Waiting). Starting work arms the eye-care and hydration reminders, focusing
and stepping away pause them, and finishing for the day stops everything. Reminders pop up as a card in the middle of the screen while
the capybara acts along (sipping from a cup, looking far away) — hydration shows `Cup x/y`; for eye
care, `Start rest` covers every screen with a night scene and counts down, and you can end early. `Settings…` holds your weight, cup size, work hours and
eye-care preset (`20-20-20 Rec` / `Hourly Break` / `Custom`) and shows the hydration plan that
follows from them.

## Claude Code integration

Pick `Connect Claude Code` in the menu bar or the pet menu:

- `icu-hook` is copied to `<App Support>/ICU/bin/icu-hook` and registered in
  `~/.claude/settings.json` (`CLAUDE_CONFIG_DIR` is respected). Your file is backed up before the
  first write and your own hooks are kept; uninstalling removes only the entries it added.
- Every hook is `async`, so Claude Code never waits on the pet.
- While connected the pet plays a scene per activity — thinking, reading, searching, writing,
  running Bash, spawning sub-agents — and cards any session that is waiting on you.

**Privacy.** The hook records state only. Prompts, commands, tool arguments, model responses and
transcript paths never touch the disk. What it keeps: session id, event name, tool *name*, error
kind, your project folder name, the frontmost app bundle id and a timestamp.

## Where things live

Everything sits under `~/Library/Application Support/ICU/` — `config/` for settings and copy
overrides, `state/` for runtime state and health metrics, `agents/` for one JSON per Claude Code
session, plus `logs/` and `bin/`. Point the whole tree elsewhere with `ICU_APP_SUPPORT_ROOT`.

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
  musculoskeletal discomfort and eyestrain without lowering output; this is the `Hourly Break` preset.

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

## License

MIT — see [LICENSE](LICENSE). Pixel fonts under `assets/fonts/` keep their own licenses (OFL and
friends) in `assets/fonts/LICENSES/`.
