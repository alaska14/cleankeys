<div align="center">
  <img src="docs/assets/CleanKeys-Cover-Final.png" alt="CleanKeys Banner" width="800">
  <br><br>
  
  [![Get it on Gumroad](https://img.shields.io/badge/Get_it_on_Gumroad-%242.99+-102039?style=for-the-badge&logo=gumroad&logoColor=white)](https://monolabapps.gumroad.com/l/cleankeys)
  [![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey?style=for-the-badge)](LICENSE)
  [![AlternativeTo](https://img.shields.io/badge/AlternativeTo-Listed-blue?style=for-the-badge)](https://alternativeto.net/software/cleankeys-by-monolab/)
</div>

<br>

# CleanKeys

> **Distraction-free volume & brightness on macOS. Fully headless.**

Ever been immersed in a movie, video edit, live stream, or fullscreen game, only to be interrupted by a giant semi-transparent square in the center of your screen every time you adjust volume or screen brightness?

**CleanKeys** eliminates those intrusive HUD popups completely, giving you seamless, uninterrupted control over your Mac's hardware media keys.

---

## ✨ Key Features

- 🎬 **Movie Night & Fullscreen Immersion:** Change volume and brightness while watching movies, shows, or streams without distractive on-screen overlays breaking your focus.
- 🍃 **Fully Headless & Menu-Bar-Free:** Most utilities clutter your top menu bar with yet another icon. CleanKeys is completely headless—zero menu bar items, zero Dock icon. It simply works silently in the background.
- 🔇 **Silences All Intrusive Popups:** Suppresses on-screen volume, mute, display brightness, and keyboard illumination HUD banners.
- 🎮 **Pro Workflow & Gaming:** Ideal for full-screen games, video editing (Final Cut Pro, Premiere, DaVinci Resolve), and keynote presentations where popups ruin the visual.
- ⚡ **Near-Zero Battery Impact:** Lightweight native AppKit, no dependencies or Electron. Idles at ~0% CPU and only wakes when you press a media key.
- 🛑 **Frictionless Control:** Wondering how to quit or pause without a menu bar icon? Simply open CleanKeys from Applications or Spotlight anytime—it will gracefully detect it is already running and pop up a clean 1-click dialog: *Keep Running* or *Quit CleanKeys*.

---

## 🔒 Security & Privacy Guarantee

Because CleanKeys intercepts hardware aux keys, macOS asks for **Accessibility Permission** on first launch.

Here is our explicit privacy promise:
1. **Zero Text Keystroke Logging:** CleanKeys uses Apple's native `CGEventTap` strictly filtered to auxiliary media keys (`NX_KEYTYPE_SOUND_UP`, `SOUND_DOWN`, `MUTE`, `BRIGHTNESS_UP`, `BRIGHTNESS_DOWN`, `ILLUMINATION_UP`, `ILLUMINATION_DOWN`). It **never** reads, monitors, or logs your text keystrokes or passwords.
2. **Zero Network Connections:** CleanKeys contains **zero networking code**. It does not connect to any servers, makes zero telemetry or analytics calls, and operates 100% locally and offline on your machine.
3. **Open Verification:** You can inspect network activity via macOS Little Snitch or Activity Monitor. CleanKeys uses 0 KB of network bandwidth forever.

---

## 📦 Installation

### Get CleanKeys on Gumroad (recommended)
**[monolabapps.gumroad.com/l/cleankeys](https://monolabapps.gumroad.com/l/cleankeys)** gives you the ready-to-use app as a DMG, plus future updates. Open the DMG and drag `CleanKeys.app` to `/Applications`.

> **First launch:** MonoLab apps are not notarized by Apple yet. If macOS says the app can't be verified, right-click the app → **Open** (or System Settings → Privacy & Security → **Open Anyway**) once.

> **Permissions:** CleanKeys needs **Accessibility** access (System Settings → Privacy & Security) to read the media keys. Display brightness keys are handled for the built-in display; with an external monitor as main display, macOS's normal behaviour is used.

### Build from source
CleanKeys is open source (MIT). If you prefer to build it yourself, you need Apple's Command Line Tools (`xcode-select --install`):
```bash
git clone https://github.com/alaska14/cleankeys.git
cd cleankeys
./build.sh          # creates build/CleanKeys.app
```

## 💬 Feedback & Feature Requests

Have a suggestion, found an edge case, or want to report a bug?
- **[Open an Issue](https://github.com/alaska14/cleankeys/issues)** right here on GitHub.
- Bought it on Gumroad? Just reply to your receipt email.

Crafted with care by **MonoLab**.
