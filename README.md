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

Dependencies install automatically on first run.

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

1. Menu Bar → Change Avatar → Add Custom Avatar
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

- **20-20-20 Rule**: American Academy of Ophthalmology recommendation for reducing digital eye strain
- **Sedentary Breaks**: Research shows movement breaks every 30-60 minutes reduce health risks
- **Hydration Formula**: Based on European Food Safety Authority (EFSA) guidelines (35ml/kg body weight)
- **Cognitive Performance**: Studies link proper hydration and breaks to improved focus and productivity

## 🛠️ Tech Stack

| Technology | Purpose |
|------------|---------|
| Python 3.9+ | Core language |
| PySide6 | Pet widget & dialogs |
| rumps | macOS menu bar |
| Ollama | Local AI (optional) |
| HuggingFace | Image generation |
| SQLite | Data persistence |

## 📁 Project Structure

```
icu/
├── icu                     # Launch script
├── src/
│   ├── pet_widget.py       # Desktop pet UI
│   ├── menu_bar.py         # Menu bar control
│   ├── avatar_wizard.py    # Custom pet creator
│   ├── ai_config_dialog.py # AI model configuration
│   ├── reminder.py         # Health reminders
│   ├── daily_stats.py      # Statistics tracking
│   └── weekly_report.py    # Weekly summaries
├── builder/                # AI generation tools
│   ├── prompt_optimizer.py # Prompt enhancement
│   ├── vision_generator.py # Image generation
│   └── persona_forge.py    # Personality creation
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
