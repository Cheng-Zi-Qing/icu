# I.C.U. - FSM-Based Health Management Desktop Pet

[中文](README_CN.md) | English

> **I**ntelligent **C**are **U**nit - A lightweight, non-intrusive health management desktop pet designed for geeks and knowledge workers
>
> 💡 **I.C.U. = I see u** - I see you! Stop sitting, staring at screens, and forgetting to drink water!

[![Python](https://img.shields.io/badge/Python-3.9+-blue.svg)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-green.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📖 Overview

I.C.U. is a lightweight desktop health assistant based on Finite State Machine (FSM) architecture. Through event-driven state transitions and scientific health reminder algorithms, it helps developers maintain their health while staying in flow.

### Core Philosophy

- **Ultra Lightweight**: Pure Python implementation, minimal dependencies, low resource usage
- **Cross-Platform**: Supports macOS and Linux
- **Zero Interruption**: Manual state switching instead of rigid timers, no flow disruption
- **Science-Based**: Based on 20-20-20 rule, sedentary micro-interventions, cognitive hydration research
- **AI-First**: Local privacy AI + context awareness + zero-code custom avatars

## ✨ Features

### 🔄 Four Work States

| State | Icon | Description | Behavior |
|-------|------|-------------|----------|
| Idle/Off | 🛌 | Zero resource consumption | Destroy all timers, generate daily report |
| Working | 💻 | Main loop running | Eye care (20min), stretch (45min), hydration (dynamic) |
| Focus | 🔕 | Freeze timers | Block popups, record health debt |
| Break | ☕ | Reset timers | No health debt during break |

### 💧 Dynamic Hydration Algorithm

```
Daily water = Body weight (kg) × 35ml
Work water = Daily water × 65%
Dynamic interval = Work hours ÷ (Water needed ÷ Cup volume)
```

- Auto-calculate reminder frequency based on weight and cup size
- Safety threshold: 30-120 minute intervals
- Multi-level feedback: Finished (+100%) / Half cup (+50%) / Later

### 🤖 AI-First Features

- **Context-Aware Engine**: Detects active app, clipboard type, typing activity
- **Zero-Code Avatar**: Generate custom pet in 1 minute with AI
- **Personality System**: AI-generated dialogue matching avatar personality
- **Privacy First**: All sensitive data stays local, never uploaded

## 📦 Installation & Launch

### Requirements

- Python 3.9+
- macOS or Linux

### Quick Start

```bash
git clone https://github.com/yourusername/icu.git
cd icu
./icu
```

Dependencies will be installed automatically on first run.

### Exit

- Right-click pet → Exit
- Menu Bar → Exit

### Development Mode

```bash
# Run tests
python3 tests/test_core.py
python3 tests/test_integration.py
```

## 🚀 Usage

1. **First Launch**: Choose your favorite pet avatar
2. **Configure**: Menu Bar → Settings → Enter weight and cup volume
3. **Start Working**: Menu Bar → Start Work
4. **State Switching**:
   - Need focus: Menu Bar → Enter Focus
   - Take break: Menu Bar → Break
   - End work: Menu Bar → Off Work

## 🛠️ Tech Stack

| Technology | Purpose |
|------------|---------|
| Python 3.9+ | Core language |
| PySide6 | Pet widget UI |
| rumps | macOS menu bar |
| transitions | FSM engine |
| SQLite | Data persistence |
| Ollama | Local AI (optional) |

## 📁 Project Structure

```
icu/
├── icu                     # Launch script
├── src/
│   ├── __main__.py         # Entry point
│   ├── state_machine.py    # FSM core
│   ├── menu_bar.py         # Menu bar UI
│   ├── pet_widget.py       # Pet widget
│   ├── reminder.py         # Reminder logic
│   ├── ai_assistant.py     # AI assistant
│   ├── report_generator.py # Report generator
│   └── database.py         # SQLite persistence
├── assets/pets/            # Pet avatars
├── config/                 # Configuration
└── tests/                  # Tests
```

## 🎯 Roadmap

- [x] PRD 1.1: FSM + Reminders
- [x] PRD 1.2: Pet Widget + Animations
- [x] PRD 1.3: Reports + AI Assistant
- [ ] Weekly reports
- [ ] More pet avatars
- [ ] Cloud sync (optional)

## 📄 License

MIT License - See [LICENSE](LICENSE) file

---

**Made with ❤️ for developers who care about health**
