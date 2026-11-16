#!/usr/bin/env bash
# Sanity checks for this repository. Designed to run on Linux/macOS CI
# (AutoHotkey itself is Windows-only).
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "$(readlink -f -- "$0")")/.." && pwd)
cd "$ROOT"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

ok() {
    printf 'ok: %s\n' "$*"
}

AHK_FILES=(sourcecode src/VirtualPianoAuto.ahk launcher/Piano_Launcher.ahk)

for file in "${AHK_FILES[@]}"; do
    [[ -f $file ]] || fail "missing file: $file"
done
ok "all expected files exist"

[[ -f src/VERSION ]] || fail "missing src/VERSION"
VERSION=$(tr -d '[:space:]' < src/VERSION)
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]] || fail "invalid VERSION: $VERSION"
ok "src/VERSION is semver ($VERSION)"

grep -q "^#Requires AutoHotkey v2.0" src/VirtualPianoAuto.ahk || fail "app does not require AutoHotkey v2.0"
grep -q "^#Requires AutoHotkey v2.0" launcher/Piano_Launcher.ahk || fail "launcher does not require AutoHotkey v2.0"
grep -q "^#Requires AutoHotkey v2.0" sourcecode || fail "shim does not require AutoHotkey v2.0"
ok "all scripts declare AutoHotkey v2.0"

for file in "${AHK_FILES[@]}"; do
    if grep -n -P '[^\x00-\x7F]' "$file" >/dev/null; then
        grep -n -P '[^\x00-\x7F]' "$file" >&2 || true
        fail "$file contains non-ASCII bytes (encoding hazard)"
    fi
done
ok "all scripts are pure ASCII"

for file in "${AHK_FILES[@]}"; do
    if grep -n $'\r' "$file" >/dev/null; then
        fail "$file contains CR line endings"
    fi
done
ok "no CRLF line endings"

# Count double quotes only outside single-quoted strings, which are a valid
# AHK way to embed double quotes (e.g. in regexes).
for file in "${AHK_FILES[@]}"; do
    awk '
        {
            line = $0
            gsub(/\x27[^\x27]*\x27/, "", line)
            n = gsub(/"/, "\"", line)
            if (n % 2 == 1) { printf "odd quote count in %s line %d: %s\n", FILENAME, NR, $0 > "/dev/stderr"; exit 1 }
        }
    ' "$file"
done
ok "even quote counts on every line"

grep -q 'releases/latest' launcher/Piano_Launcher.ahk && grep -q 'releases/download' launcher/Piano_Launcher.ahk \
    || fail "launcher does not reference the releases URLs"
ok "launcher targets GitHub Releases"

grep -q "VirtualPianoAuto.ahk" .github/workflows/release.yml \
    || fail "release workflow does not package VirtualPianoAuto.ahk"
ok "release workflow packages the app"

[[ -f LICENSE ]] || fail "missing LICENSE"
[[ -f README.md ]] || fail "missing README.md"
grep -q "## " README.md || fail "README.md looks empty"
ok "README and LICENSE present"

printf '\nAll smoke tests passed.\n'
