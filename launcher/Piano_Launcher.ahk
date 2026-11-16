; ============================================================================
; Virtual Piano AUTO - Launcher / Updater
; ----------------------------------------------------------------------------
; Downloads the latest Virtual Piano AUTO release from GitHub, verifies its
; SHA-256 checksum, caches it under %LocalAppData%\VirtualPianoAuto and runs it.
;
; Behaviour:
;   online  - fetches the latest release tag; if newer than the cached copy,
;             downloads and verifies it before running
;   offline - runs the cached copy if one exists, otherwise shows an error
;   tampered/corrupt download - aborts (same philosophy as sleep-aur)
;
; Releases are published by .github/workflows/release.yml when a v* tag is
; pushed. Each release carries VirtualPianoAuto.ahk and its .sha256, both
; produced from this repository, so the running code always comes from a
; tagged, auditable release - never from a moving branch.
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

REPO_OWNER := "the-sleepless"
REPO_NAME := "virtual-piano-auto"

CACHE_DIR := A_LocalAppData "\VirtualPianoAuto"
SCRIPT_PATH := CACHE_DIR "\VirtualPianoAuto.ahk"
VERSION_PATH := CACHE_DIR "\VERSION"

try DirCreate(CACHE_DIR)

latestTag := GetLatestReleaseTag()
cachedTag := ReadCachedTag()

if (latestTag && latestTag != cachedTag)
    UpdateCache(latestTag)

if !FileExist(SCRIPT_PATH) {
    if (latestTag = "")
        MsgBox("Could not reach GitHub and no cached copy of Virtual Piano AUTO exists.",
            "Virtual Piano AUTO", "Iconx")
    else
        MsgBox("Failed to download Virtual Piano AUTO and no cached copy exists.",
            "Virtual Piano AUTO", "Iconx")
    ExitApp(1)
}

Run(A_AhkPath ' "' SCRIPT_PATH '"')
ExitApp(0)

; ---------------------------------------------------------------------------

ReadCachedTag() {
    if !FileExist(VERSION_PATH)
        return ""
    try return Trim(FileRead(VERSION_PATH))
    return ""
}

GetLatestReleaseTag() {
    url := "https://api.github.com/repos/" REPO_OWNER "/" REPO_NAME "/releases/latest"
    json := HttpGet(url)
    if (json = "")
        return ""
    if RegExMatch(json, '"tag_name"\s*:\s*"([^"]+)"', &m)
        return m[1]
    return ""
}

; GET request, returns the response body as a string, or "" on failure.
HttpGet(url) {
    try {
        http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)
        http.SetTimeouts(3000, 3000, 3000, 8000)
        http.SetRequestHeader("User-Agent", "VirtualPianoAuto-Launcher")
        http.Send()
        if (http.Status = 200)
            return http.ResponseText
    }
    return ""
}

; GET request, saves the response body as a binary file, or "" on failure.
DownloadFile(url, dest) {
    try {
        http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)
        http.SetTimeouts(3000, 3000, 3000, 15000)
        http.SetRequestHeader("User-Agent", "VirtualPianoAuto-Launcher")
        http.Send()
        if (http.Status != 200)
            return false
        stream := ComObjCreate("ADODB.Stream")
        stream.Type := 1                  ; adTypeBinary
        stream.Open()
        stream.Write(http.ResponseBody)
        stream.SaveToFile(dest, 2)        ; adSaveCreateOverWrite
        stream.Close()
        return true
    }
    return false
}

; Returns the SHA-256 of a file as upper-case hex, or "" if it cannot be computed.
GetSha256(filePath) {
    try {
        ps := "(Get-FileHash -Algorithm SHA256 -LiteralPath '" filePath "').Hash"
        shell := ComObjCreate("WScript.Shell")
        exec := shell.Exec('powershell -NoProfile -Command "' ps '"')
        out := exec.StdOut.ReadAll()
        if RegExMatch(out, '[0-9A-Fa-f]{64}', &m)
            return StrUpper(m[0])
    }
    return ""
}

UpdateCache(tag) {
    base := "https://github.com/" REPO_OWNER "/" REPO_NAME "/releases/download/" tag
    tmp := SCRIPT_PATH ".tmp"

    if !DownloadFile(base "/VirtualPianoAuto.ahk", tmp) {
        try FileDelete(tmp)
        return false
    }

    shaText := HttpGet(base "/VirtualPianoAuto.ahk.sha256")
    expected := ""
    if RegExMatch(shaText, '[0-9A-Fa-f]{64}', &m)
        expected := StrUpper(m[0])

    actual := GetSha256(tmp)

    if (expected = "" || actual = "" || actual != expected) {
        try FileDelete(tmp)
        MsgBox("Checksum verification failed for Virtual Piano AUTO " tag
            ".`nThe cached copy (if any) was kept untouched.",
            "Virtual Piano AUTO", "Iconx")
        return false
    }

    try {
        FileMove(tmp, SCRIPT_PATH, 1)   ; overwrite
        try FileDelete(VERSION_PATH)
        FileAppend(tag, VERSION_PATH)
    } catch {
        try FileDelete(tmp)
        return false
    }
    return true
}
