# MusicLab 🎵

<p align="center">
  <strong>Learn Music from Zero, Made Easy</strong>
</p>

<p align="center">
  <a href="./README.md">English</a> •
  <a href="./README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.19+-blue.svg" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.3+-blue.svg" alt="Dart">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-lightgrey.svg" alt="Platform">
</p>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🎓 **Systematic Courses** | Jianpu → Staff Notation → Piano, step by step |
| 🎯 **Fun Practice** | Note reading, rhythm, ear training, playing exercises |
| 🎹 **Virtual Piano** | Multi-touch support, 88 keys, recording & playback |
| 🥁 **Metronome** | Adjustable BPM (20-240), multiple time signatures |
| 📝 **Sheet Music** | Create, edit, import (Jianpu/JSON/MusicXML) |
| 🏆 **Achievement System** | Daily check-in, badges, progress tracking |
| 🌍 **i18n** | Chinese & English support |
| 🎨 **Themes** | Light / Dark mode |

## 📸 Screenshots

| Home | Course | Piano | Practice |
|------|--------|-------|----------|
| 🏠 | 📚 | 🎹 | 🎯 |

## 🚀 Quick Start

### Prerequisites

- Flutter >= 3.19.0
- Dart >= 3.3.0
- (Optional) Python 3 + FFmpeg for audio generation

### Installation

```bash
# Clone the project
git clone https://github.com/ayxworxfr/musiclab.git
cd musiclab

# Install dependencies
make install

# Run the app
make run
```

### Run on Different Platforms

```bash
make run          # Chrome (default)
make run-web      # Web (port 8080)
make run-ios      # iOS Simulator
make run-android  # Android Device
```

## 📁 Project Structure

```
lib/
├── app/                      # App Layer
│   ├── app.dart              # App entry & config
│   ├── app_binding.dart      # Global dependencies
│   ├── middlewares/          # Route middlewares
│   └── routes/               # Route definitions
│
├── core/                     # Core Layer
│   ├── audio/                # Audio services (piano, metronome)
│   ├── network/              # HTTP client & interceptors
│   ├── storage/              # Local storage (Hive)
│   ├── theme/                # Theme configuration
│   ├── utils/                # Utilities (music, date, etc.)
│   └── widgets/              # Common widgets
│       └── music/            # Music-specific widgets
│           ├── piano_keyboard.dart
│           ├── jianpu_note_text.dart
│           └── staff_widget.dart
│
├── features/                 # Feature Modules
│   ├── splash/               # Splash screen
│   ├── onboarding/           # Onboarding
│   ├── main/                 # Main navigation
│   ├── home/                 # Home page
│   ├── course/               # Course system
│   ├── practice/             # Practice modules
│   │   ├── note_practice/    # Note recognition
│   │   ├── rhythm_practice/  # Rhythm training
│   │   ├── ear_practice/     # Ear training
│   │   └── piano_practice/   # Playing practice
│   ├── tools/                # Tools
│   │   ├── piano/            # Virtual piano
│   │   ├── metronome/        # Metronome
│   │   ├── sheet_music/      # Sheet music library & editor
│   │   └── reference/        # Reference tables
│   └── profile/              # User profile
│
├── shared/                   # Shared Layer
│   ├── constants/            # Constants
│   ├── enums/                # Enums
│   ├── extensions/           # Extensions
│   └── translations/         # i18n
│
└── main.dart                 # Entry point
```

## 🛠️ Tech Stack

| Category | Technology | Version |
|----------|------------|---------|
| State Management | GetX | 4.6.6 |
| Audio | just_audio | 0.9.36 |
| HTTP | Dio | 5.4.0 |
| Storage | Hive | 2.2.3 |
| UI | ScreenUtil | 5.9.0 |
| Animation | Lottie | 3.1.0 |
| Markdown | flutter_markdown | 0.7.4 |

## 📚 Course System

### Jianpu Basics (10 lessons)
Learn the numbered musical notation (1234567), rhythm, and beats.

### Staff Notation Basics (15 lessons)
Understand the five-line staff, treble and bass clefs.

### Piano Basics (20 lessons)
Learn proper posture, hand position, and play classic beginner pieces.

## 🎹 Audio Generation

The project includes a Python script to generate piano sounds (88 keys), metronome clicks, and effect sounds:

```bash
# Install Python dependencies
make audio-install-deps

# Generate all audio files
make audio

# Clean audio files
make audio-clean
```

## 📝 Make Commands

```bash
# Development
make help          # Show all commands
make install       # Install dependencies
make run           # Run on Chrome
make run-web       # Run on Web (port 8080)
make stop          # Stop running app

# Build
make build-web     # Build for Web
make build-ios     # Build for iOS
make build-android # Build for Android

# Code Quality
make analyze       # Code analysis
make format        # Format code
make test          # Run tests

# Audio
make audio         # Generate audio files
make audio-clean   # Clean audio files
```

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

[MIT License](LICENSE)

---

<p align="center">
  Made with ❤️ for music learners
</p>
