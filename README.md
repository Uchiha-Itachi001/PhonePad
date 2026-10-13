# 📱 PhonePad

> **Turn your smartphone into a zero-latency, high-precision tactile trackpad, numeric keypad, and presentation remote for Windows.**

![PhonePad Banner](image.png)

PhonePad bridges mobile multi-touch digitizers and desktop operating systems over local Wi-Fi and Bluetooth Classic RFCOMM, delivering native laptop touchpad precision, Samsung One UI inspired reactive physics, and instant tactile feedback.

---

## ⚡ Features

### 🎯 Precision Trackpad & Digitizer
- **Sub-Pixel Fractional Accumulator**: Micro-movements (<0.5px) are captured and accumulated across frames for silky-smooth cursor gliding with zero jitter or dropped inputs.
- **Dynamic Samsung One UI Dot Matrix**: Ambient micro-dot grid with reactive magnetic proximity bloom that illuminates under fingers with fluid spring easing.
- **Zero-Latency Pipeline**: Direct binary packet protocol (6-byte frames), Nagle algorithm disabled (`TCP_NODELAY`), immediate socket flush, and decoupled hardware-accelerated painters.

### 🎨 Dynamic Theme Engine & Customizable Pitch
- **5 Bespoke Color Palettes**:
  - 🌿 **Obsidian Emerald** (Samsung One UI dark void `#070C14` + neon emerald `#10B981`)
  - 🔮 **Cyberpunk Neon** (Electric violet `#090514` + radiant magenta `#EC4899`)
  - 🌊 **Nordic Slate** (Oceanic slate `#0B132B` + glacier blue `#38BDF8`)
  - 🖤 **AMOLED True Black** (Zero-power pure black `#000000` + electric lime `#84CC16`)
  - ☀️ **Studio Porcelain** (Crisp daylight studio `#F1F5F9` + deep indigo `#4F46E5`)
- **4 Dot Matrix Density Presets**: Ultra-Dense (10px), Precision Dense (13px default), Balanced (18px), and Ambient (24px).

### 🖐️ Laptop-Grade Multi-Touch Gestures
- **1 Finger**: Precision cursor movement, quick tap to left click, double-tap-and-hold to drag lock.
- **2 Fingers**: Natural vertical & horizontal scrolling, quick tap to right click, horizontal swipe for browser & file explorer **Back / Forward** (`Alt + Left / Right`).
- **3 Fingers**: Native Windows laptop app switcher — holds `Alt` down continuously during horizontal swipe so window cards stay visible, steps through open windows, and switches on finger lift; swipe up for **Windows Task View** (`Win + Tab`); swipe down for **Show Desktop** (`Win + D`).

### 🔢 Virtual Numpad & Media Remote Decks
- **Virtual Numpad**: Full 10-key numeric keypad with tactile haptics, status telemetry pill, and glowing hero `ENTER` key.
- **Studio Remote**: Presentation clicker (`PREV` / `NEXT` slide triggers with Page Up/Down) and media playback dial (`Play / Pause`, `VOL +`, `VOL -`, `MUTE`).
- **Adaptive Horizontal Mode**: 1-tap orientation toggle button in the top status bar. Automatically rearranges the trackpad, numpad, and remote decks into widescreen cockpit layouts.

### 📡 Multi-Wireless Transport
- **Zero-Config Wi-Fi Auto-Discovery**: UDP broadcast beacon on port 4242 pairs PC and phone in <100ms automatically.
- **Bluetooth Classic RFCOMM (SPP)**: Native Winsock Bluetooth listener with SDP service registration (`UUID 00001101-...`) and Android 3-tier fallback.

---

## 🏗️ Architecture

```
PhonePad/
├── phonepad-host/          # High-performance Windows Host Daemon (Rust)
│   ├── src/
│   │   ├── input/          # Win32 SendInput injection & Alt+Tab switcher
│   │   ├── gesture/        # State machine (FSM), ballistics & deadzones
│   │   ├── server/         # TCP listener & Winsock RFCOMM Bluetooth SPP
│   │   └── discovery/      # UDP beacon auto-discovery
│   └── Cargo.toml
│
└── phonepad_mobile/        # Cross-platform Client (Flutter / Dart)
    ├── lib/
    │   ├── core/           # Binary protocol, networking, and theme engine
    │   └── features/       # Trackpad, Numpad, Remote surfaces & Connection Hub
    └── pubspec.yaml
```

---

## 🚀 Getting Started

### Prerequisites
- **Host**: Rust 1.80+ (`cargo`) on Windows 10/11
- **Mobile**: Flutter 3.22+ and Android SDK

### 1. Run the PC Host Daemon
```powershell
cd phonepad-host
cargo run --release
```
The daemon starts listening on port 4242 and announces itself over local UDP broadcast.

### 2. Run the Mobile Client
```powershell
cd phonepad_mobile
flutter run --release
```
The mobile client automatically discovers and connects to your PC on the local network.

---

## 🧪 Running Tests

```powershell
# Test Rust Host Daemon
cd phonepad-host
cargo test

# Test Flutter Mobile Client
cd phonepad_mobile
flutter test
```

---

## 📄 License
MIT License. See [LICENSE](LICENSE) for details.
