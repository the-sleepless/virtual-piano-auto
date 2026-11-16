# 🎹 Virtual Piano AUTO

An **AutoHotkey v2** script that automatically plays sheet music on virtual pianos — Virtual Piano on the web, Roblox piano plugins, and similar windows. Built for fast playback, rock-solid state handling, and a clean dark UI.

The script features a flicker-free UI, real-time tempo controls, a token-based playback engine that handles notes, chords, timing pauses and bar lines, and a launcher that always pulls the latest build straight from GitHub.

---

## 📋 Requirements

- **[AutoHotkey v2](https://www.autohotkey.com/)** (64-bit recommended)
- **Windows** (the script sends native keystrokes and uses the Windows API)
- A virtual piano window (web or Roblox) to play the sheet on

---

## ⬇️ Download

<div align="center">

[![Version][shield-repo-latest]][repo-latest]
[![Download Launcher][shield-download-launcher]][download-launcher]

</div>

The launcher downloads the latest `sourcecode` from `main` every time you run it, so you always get the newest version automatically.

You can also run `sourcecode` directly: open it with AutoHotkey v2 and it works the same (you just don't get auto-updates).

> **Why is the file called `sourcecode` (no extension)?**
> The launcher downloads `https://raw.githubusercontent.com/the-sleepless/virtual-piano-auto/main/sourcecode`.
> Keeping a single, self-contained file at that exact path is what makes the auto-update flow work. If the path ever changes, the launcher must be updated first.

---

## 🎶 Sheet notation

| Token | Meaning | Timing |
|-------|---------|--------|
| `c d e ...` | tap a key (a–z, 0–9, symbols) | 1 STEP per note |
| `[c e g]` | chord — tap multiple keys together | HOLD down, then released |
| space | short wait | 30% of STEP |
| `-` `–` `—` | medium wait | 45% of STEP |
| `\|` | bar line — longer wait | 130% of STEP |

Chords accept space- or comma-separated keys: `[c e g]` and `[c,e,g]` are the same.

Uppercase letters (`A`) and shifted symbols (`!`, `@`, `#`, ...) are sent as **Shift + key**, deduplicated automatically.

Consecutive waits are merged into one pause, so `   ` (3 spaces) is a single 90% pause, not three separate re-triggers.

---

## ⌨️ Hotkeys

Only active **while your game/app window is focused** — never over the script's own UI.

| Hotkey | Action |
|--------|--------|
| `F1` | Toggle playback (start / pause) |
| `End` | Stop playback and rewind to the beginning |
| `[` or `]` | Play the next note/chord manually (step mode) |
| `WheelUp` | Decrease STEP by 10 (faster) |
| `WheelDown` | Increase STEP by 10 (slower) |

The wheel hotkeys are ignored while **Bloquear Vel.** (speed lock) is checked in the UI.

---

## 🖥️ UI

- **Edit field** — paste your sheet.
- **Aplicar** — parse the sheet into the token engine and rewind.
- **Iniciar / Parar** — start or pause playback.
- **Resetar** — stop and rewind.
- **Bloquear Vel.** — lock the tempo so the mouse wheel can't change it.
- **STEP / HOLD** — base tempo and chord hold time, via edit fields or sliders.
- **Progress** — live position in the sheet (`n/total`).

---

## 🛠️ How it works

`sourcecode` is intentionally one file. At its core:

- **`Engine`** — parses the sheet into tokens (`wait` / `key` / `chord`), expands shifted keys, sends input via `SendInput`, and drives a 10 ms timer. Consecutive waits are merged, chords are released on a fixed STEP grid (no tempo drift), and a `downKeys` map guarantees no key is ever left held — even on crash or exit.
- **`PianoUI`** — a dark, `AlwaysOnTop` GUI with a non-editable-look edit field, sliders and an immersive dark title bar (Windows 10 1809+; harmlessly ignored elsewhere).
- Hotkeys use `#HotIf IsTargetActive()`, so they fire only while a game window is focused and stay out of the way while you're in the UI.

---

## 🚀 Development

There is no automated test suite (playback can only be verified on Windows with a real piano target), so changes must be reviewed extra carefully:

```bash
# Syntax check (requires AutoHotkey v2)
AutoHotkey.exe /iLib sourcecode   # or just open it
```

Project layout is deliberately minimal:

- `sourcecode` — the whole script (required by the launcher's raw URL).
- `README.md` — this file.
- `LICENSE` — personal use only.

Releases are tagged from this repository (`piano-launcher-vX.Y.Z` tags carry the launcher). The main script is consumed directly from `main`, so there is no version skew between launcher and script.

---

## 📜 License

Personal use only. See [LICENSE](LICENSE).

<!-- Badges -->

[shield-repo-latest]: https://img.shields.io/github/v/release/the-sleepless/virtual-piano-auto?style=for-the-badge
[repo-latest]: https://github.com/the-sleepless/virtual-piano-auto/releases/latest

[shield-download-launcher]: https://img.shields.io/badge/Download-launcher.ahk-7C4DFF?style=for-the-badge
[download-launcher]: https://github.com/the-sleepless/virtual-piano-auto/releases/download/piano-launcher-v1.0.0/Piano_Launcher.ahk
