# Contributing to Virtual Piano AUTO

Thanks for taking the time to contribute.

## Requirements

- For editing: any text editor.
- For testing: **Windows** and **AutoHotkey v2** (the playback engine can only
  be verified there, against a real piano window).
- The repository sanity suite (`tests/smoke.sh`) runs on Linux/macOS too.

## Repository layout

```
src/VirtualPianoAuto.ahk    the application (single self-contained file)
src/VERSION                 application version (semver)
launcher/Piano_Launcher.ahk bootstrapper/updater (downloads latest release)
sourcecode                  legacy shim kept for old launchers
tests/smoke.sh              Linux-friendly sanity checks
.github/workflows/          CI and release automation
```

Do not split the application into `#Include` files: the release asset must
remain a single self-contained `.ahk`.

## Checks before committing

```bash
bash tests/smoke.sh
```

This verifies the layout, ASCII-only sources, balanced quotes, semver and the
release workflow. It does not validate AHK syntax.

## Manual test checklist (Windows + AHK v2)

1. `src/VirtualPianoAuto.ahk` opens without errors.
2. Pasting a sheet and clicking **Aplicar** rewinds progress to `0/n`.
3. **Iniciar** plays, **Parar** pauses, **Resetar** rewinds, `F1` toggles,
   `End` resets, `[`/`]` steps.
4. Chords (`\[c e g]`) play all keys held for HOLD, then release.
5. Sliders and edit fields stay in sync; `Bloquear Vel.` blocks the wheel.
6. Close the window: all held keys are released.

## Releases

Releases are cut from tags matching `src/VERSION`:

```bash
git tag v2.0.0
git push origin v2.0.0
```

The release workflow validates the tag, packages the app, the launcher and
the shim with SHA-256 checksums, and publishes a GitHub Release. The launcher
consumes releases only - pushing to `main` never ships code to users.
