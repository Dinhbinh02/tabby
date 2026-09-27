<p align="center">
  <img src="Resources/AppIcon.png" alt="Tabby Icon" width="128" height="128" />
</p>

<h1 align="center">Tabby</h1>

<p align="center">
  <b>A lightweight, blazing-fast window switcher for macOS with zero delay.</b>
</p>

<p align="center">
  <a href="https://github.com/Dinhbinh02/tabby/releases/latest"><img src="https://img.shields.io/github/v/release/Dinhbinh02/tabby?color=blue&style=flat-square" alt="Latest Release" /></a>
  <a href="https://github.com/Dinhbinh02/tabby/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg?style=flat-square" alt="License" /></a>
  <img src="https://img.shields.io/badge/platform-macOS%2013.0%2B-orange.svg?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-5.9%2B-red.svg?style=flat-square" alt="Swift" />
</p>

---

## ✦ Features

- **⚡ Zero-Delay Switching:** Fast window enumeration with native CoreGraphics event tapping.
- **🎨 Glassmorphic HUD:** Compact macOS-native switcher interface with real-time app icons and window titles.
- **⌨️ Keyboard Navigation:**
  - Hold `⌘` and press `Tab` / `⇧ Tab` to cycle through open windows.
  - Release `⌘` (or press `Return` / `Space`) to switch to the selected window.
  - Press `⌘ Q` to quit the selected app directly from the switcher.
  - Press `⌘ W` to close the selected window.
  - Click outside or press `Esc` to dismiss.
- **⚙️ Settings & Customization:**
  - Custom trigger shortcut (record any key combination).
  - Appearance themes: System, Light, Dark.
  - Ignore Applications list: Exclude specific apps from the switcher.
  - Launch at login & Automatic update checks from GitHub.

---

## 📥 Installation

Download the latest `Tabby-vX.X.X.dmg` from the **[Releases Page](https://github.com/Dinhbinh02/tabby/releases/latest)**.

1. Open `.dmg` and drag **Tabby** into `/Applications`.
2. Launch Tabby.
3. Grant **Accessibility** permission when prompted.

> [!TIP]
> **First-time launch on macOS:**
> If macOS displays an unidentified developer prompt:
> - Right-click (or `Control` + click) `Tabby.app` in `/Applications` > **Open** > **Open**.
> - Or run in Terminal:
>   ```bash
>   xattr -cr /Applications/Tabby.app
>   ```

---

## ⌨️ Shortcuts Reference

| Action | Shortcut |
| :--- | :--- |
| **Open Switcher & Next Window** | `⌘ Tab` (or configured shortcut) |
| **Previous Window** | `⌘ ⇧ Tab` |
| **Navigate** | `←` `→` `↑` `↓` Arrow keys |
| **Switch to Window** | Release `⌘` / `Return` / `Space` / Click item |
| **Quit Selected App** | `⌘ Q` |
| **Close Selected Window** | `⌘ W` |
| **Dismiss Switcher** | `Escape` or Click outside |

---

## 🛠️ Building from Source

```bash
# Clone the repository
git clone https://github.com/Dinhbinh02/tabby.git
cd tabby

# Build and assemble Tabby.app
./bundle.sh

# Or build distributable DMG
./create_dmg.sh
```

---

## 📄 License

Tabby is released under the [MIT License](LICENSE).
