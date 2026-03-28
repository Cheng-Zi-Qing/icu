# I.C.U. - Your AI-Powered Health Companion

[中文](README_CN.md) | English

> **I**ntelligent **C**are **U**nit - A customizable desktop pet that keeps you healthy while you code
>
> 💡 **I.C.U. = I see u** - Your personal health guardian with personality!

[![Python](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-green.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 🌟 What Makes I.C.U. Special

### 🎨 Fully Customizable Avatars & Personalities
- **AI-Generated Pets**: Create your unique desktop companion in minutes
- **Custom Personalities**: Each pet has its own tone, traits, and messages
- **Built-in Collection**: Capybara, cow, horse, seal, and more
- **Zero-Code Creation**: Just describe what you want, AI does the rest

### 💪 Science-Based Health Management
- **Smart Reminders**: Eye care (20-20-20 rule), stretch breaks, hydration tracking
- **Dynamic Algorithms**: Personalized water intake based on your body weight
- **Flow-Friendly**: Manual state control - never interrupts your focus
- **Weekly Reports**: Track your health habits and improvements

### 🤖 AI-First Design
- **Local Privacy**: All AI processing stays on your machine
- **Context-Aware**: Understands what you're working on
- **Personality System**: Pets respond with character-appropriate messages
- **Multi-Model Support**: Ollama local models + remote APIs + image generation

## ✨ Key Features

### 🎭 Create Your Perfect Pet

**Three Ways to Get Your Companion:**
1. **Choose from Built-in Pets**: Capybara, cow, horse, seal, human
2. **AI-Generated Custom Pet**: Describe your ideal pet, AI creates it
3. **Upload Your Own**: Bring your favorite character to life

**Personality System:**
- Each pet has unique traits and speaking style
- AI-generated contextual messages
- Customizable personality descriptions
- Character-appropriate responses

### 💊 Health Management That Works

**Smart Work States:**
- **Idle** 🛌: Rest mode, generates daily health report
- **Working** 💻: Active health monitoring with reminders
- **Focus** 🔕: Pauses reminders, tracks health debt
- **Break** ☕: Resets timers, no penalties

**Science-Based Reminders:**
- **Eye Care**: 20-20-20 rule (every 20 min, look 20 feet away for 20 sec)
- **Stretch**: Movement breaks every 45 minutes
- **Hydration**: Dynamic intervals based on your body weight

**Personalized Hydration:**
```
Daily water = Body weight (kg) × 35ml
Work water = Daily water × 65%
Reminder interval = Work hours ÷ (Water needed ÷ Cup volume)
```

### 📊 Track Your Progress
- Daily health reports with statistics
- Weekly summaries and trends
- Reminder completion rates
- Health debt tracking during focus mode

## 🚀 Quick Start

### Installation

```bash
git clone https://github.com/yourusername/icu.git
cd icu
./icu
```

This launches the Swift/AppKit shell.

Quick verification:

```bash
./icu --verify
```

### Native macOS shell verification

For the Swift/AppKit shell under `apps/macos-shell`, the short local verification command is:

```bash
./icu --verify
```

What it does:
- runs `swift build` for `apps/macos-shell` with an isolated scratch path so stale `.build` caches do not break the package
- runs the manual runtime verification script
- runs `swift test` only when Xcode is active, using the same isolated scratch path

If you only have Command Line Tools installed, this command remains valid. In that environment, the script skips `swift test` explicitly instead of failing.

Low-level helper:

```bash
bash tools/verify_macos_shell.sh
```

To launch the native shell locally:

```bash
./icu
```

The launch script also uses the isolated scratch path automatically, so you should not need to manually clear `apps/macos-shell/.build`.

Low-level helper:

```bash
bash tools/run_macos_shell.sh
```

Useful local checks after launch:
- right-click the pet to verify `开始工作 / 进入专注 / 暂离 / 回来工作 / 下班 / 更换形象 / 退出`
- open `Menu Bar -> Change Avatar` and confirm the Swift selector appears
- confirm `~/Library/Application Support/ICU/state/current_state.json` is created
- `ICU_PET_ID=<pet_id>` is now only a fallback for first launch; regular switching should use the Swift UI

### First Time Setup

1. **Choose Your Pet**: Select from built-in avatars or create a custom one
2. **Configure Health Settings**:
   - Menu Bar → Personal Settings
   - Enter your body weight and cup volume
3. **Optional AI Setup**:
   - Menu Bar → AI Configuration
   - Configure local Ollama or remote AI models

### Daily Usage

1. **Start Your Day**: Menu Bar → Start Work
2. **Stay Healthy**: Respond to gentle reminders from your pet
3. **Need Focus?**: Menu Bar → Enter Focus (pauses reminders)
4. **Take Breaks**: Menu Bar → Break (resets timers)
5. **End Your Day**: Menu Bar → Off Work (generates daily report)

### Create Custom Pet

1. Menu Bar → Change Avatar, or right-click the pet → Change Avatar
2. **Step 1**: Describe your pet (e.g., "a calm capybara")
3. **Step 2**: AI optimizes the prompt and generates images
4. **Step 3**: AI creates personality and messages
5. Done! Your unique pet is ready

### AI Configuration

**Three Model Types:**
- **Local Models**: Ollama for prompt optimization and personality
- **Remote Text Models**: OpenAI, Claude, or custom APIs
- **Image Models**: Stable Diffusion or HuggingFace models

Access via: Menu Bar → AI Configuration

## 📚 Scientific Foundation

I.C.U.'s health reminders are based on peer-reviewed research:

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
| Python 3.9+ | Stdlib-based bridge and residual legacy tooling |
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
