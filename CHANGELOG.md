# Changelog

## 2.0.0 - 2026-11-16

Complete restructure of the repository and update flow.

### Changed

- Repository is now organized like sleep-aur: `src/VirtualPianoAuto.ahk`,
  `launcher/Piano_Launcher.ahk`, `tests/`, `.github/workflows/`.
- The launcher is now a real updater: it queries the latest GitHub Release,
  downloads and SHA-256-verifies `VirtualPianoAuto.ahk`, caches it under
  `%LocalAppData%\VirtualPianoAuto` and falls back to the cached copy when
  offline. Releases are published automatically by a workflow when a `v*` tag
  is pushed.
- `sourcecode` at the repository root is now a tiny compatibility shim that
  fetches the latest release; existing launchers keep working.
- The application itself was rewritten into an `Engine`/`PianoUI` class
  architecture, with a fixed chord-scheduling bug (the next event is pinned
  to the STEP grid instead of drifting by HOLD after every chord) and a
  crash-proof STEP/HOLD parser.
- CI runs `tests/smoke.sh` on Linux for every push and pull request.

### Added

- `CHANGELOG.md`, `CONTRIBUTING.md`, `.gitignore`.
- `tests/smoke.sh` sanity suite (ASCII check, quote balance, VERSION/semver,
  release workflow packaging).
- Release workflow publishes the app, the launcher, the legacy shim and
  their SHA-256 checksums.
