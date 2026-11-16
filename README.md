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

The launcher checks the **latest GitHub Release** every time you run it, downloads the newest build, verifies its **SHA-256** checksum, caches it under `%LocalAppData%\VirtualPianoAuto` and runs it. Offline, it falls back to the cached copy. You always get the newest tagged release - never unreleased code from `main`.

You can also download `VirtualPianoAuto.ahk` from the [latest release](https://github.com/the-sleepless/virtual-piano-auto/releases/latest) and run it directly.

<details>
<summary>Legacy note for launchers from before v2.0.0</summary>

Old launchers (v0.0.1) downloaded the raw `main/sourcecode` file. That file now contains a tiny compatibility shim that fetches the latest release - upgrading works transparently.

</details>

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

`src/VirtualPianoAuto.ahk` is intentionally one file. At its core:

- **`Engine`** — parses the sheet into tokens (`wait` / `key` / `chord`), expands shifted keys, sends input via `SendInput`, and drives a 10 ms timer. Consecutive waits are merged, chords are released on a fixed STEP grid (no tempo drift), and a `downKeys` map guarantees no key is ever left held — even on crash or exit.
- **`PianoUI`** — a dark, `AlwaysOnTop` GUI with a non-editable-look edit field, sliders and an immersive dark title bar (Windows 10 1809+; harmlessly ignored elsewhere).
- Hotkeys use `#HotIf IsTargetActive()`, so they fire only while a game window is focused and stay out of the way while you're in the UI.

---

## 📦 Repository layout

```
src/VirtualPianoAuto.ahk     the application (single self-contained file)
src/VERSION                  application version (semver)
launcher/Piano_Launcher.ahk  bootstrapper/updater (downloads latest release)
sourcecode                   legacy shim kept for pre-2.0 launchers
tests/smoke.sh               Linux-friendly sanity checks
.github/workflows/           CI (smoke tests) and release automation
```

---

## 🚀 Development

Playback can only be verified on Windows with a real piano target, but the repository ships a sanity suite that runs on Linux/macOS:

```bash
bash tests/smoke.sh
```

CI runs it on every push and PR. See [CONTRIBUTING.md](CONTRIBUTING.md) for the manual test checklist and release process.

## 🏷️ Releases

Releases are cut from tags matching `src/VERSION` (`git tag v2.0.0 && git push origin v2.0.0`). The release workflow validates the tag, packages the app, the launcher and the shim with SHA-256 checksums, and publishes a GitHub Release. The launcher consumes releases only — pushing to `main` never ships code to users.

---

## 📜 License

Personal use only. See [LICENSE](LICENSE).

<!-- Badges -->

[shield-repo-latest]: https://img.shields.io/github/v/release/the-sleepless/virtual-piano-auto?style=for-the-badge
[repo-latest]: https://github.com/the-sleepless/virtual-piano-auto/releases/latest

[shield-download-launcher]: https://img.shields.io/badge/Download-launcher.ahk-7C4DFF?style=for-the-badge
[download-launcher]: https://github.com/the-sleepless/virtual-piano-auto/releases/latest/download/Piano_Launcher.ahk
