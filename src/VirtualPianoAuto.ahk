; ============================================================================
; Virtual Piano AUTO
; ----------------------------------------------------------------------------
; AutoHotkey v2 script that automatically plays sheet music on virtual pianos
; (Virtual Piano on the web, Roblox piano plugins, ...).
;
; Project layout (see README):
;   src/VirtualPianoAuto.ahk   <- this file, the actual application
;   launcher/Piano_Launcher.ahk <- bootstrapper/updater (checks GitHub Releases,
;                                  verifies SHA-256, falls back to cached copy)
;   sourcecode                  <- tiny compatibility shim for legacy launchers
;
; This file is packaged into every GitHub Release as `VirtualPianoAuto.ahk`.
; The launcher downloads it from the latest release, so keep this file
; self-contained (no #Include).
;
; Sheet notation:
;   c d e f g a b   note tap (a-z, 0-9, symbols)
;   [c e g]         chord (space- or comma-separated)
;   (space)         short wait  -- 30% of STEP
;   -           medium wait -- 45% of STEP
;   |               bar line    -- 130% of STEP
;   A-Z, shifted symbols (!, @, #, ...) work as shifted keys.
;
; Hotkeys (only while a game/app window is focused -- never on this UI):
;   F1            toggle playback (start/pause)
;   End           stop playback and rewind to the beginning
;   [  ]          step one note/chord forward
;   WheelUp       decrease STEP by 10 (faster)   -- blocked while "Bloquear Vel." is on
;   WheelDown     increase STEP by 10 (slower)   -- blocked while "Bloquear Vel." is on
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

A_MaxHotkeysPerInterval := 500
A_HotkeyInterval := 2000

; Global instances are assigned before any hotkey can fire (hotkeys only
; become active once the auto-execute section finishes).
Piano := ""
PianoUi := ""

; ---------------------------------------------------------------------------
; Tuneable constants
; ---------------------------------------------------------------------------
class Config {
    static StepMin := 15
    static StepMax := 800
    static StepDefault := 200
    static HoldMin := 10
    static HoldMax := 780
    static HoldDefault := 45
    static SpaceRatio := 0.30
    static DashRatio := 0.45
    static BarRatio := 1.30
    static WheelDelta := 10
    static TickMs := 10
}

class Theme {
    static Bg := "121212"
    static Panel := "1E1E1E"
    static Text := "cE0E0E0"      ; leading "c" = AHK color directive
    static Btn := "2D2D2D"
    static BtnPlay := "2E7D32"
    static BtnStop := "C62828"
}

; ---------------------------------------------------------------------------
; Playback engine: state, sheet parsing, key sending, timing
; ---------------------------------------------------------------------------
class Engine {
    __New() {
        this.seq := ""
        this.tokens := []
        this.pos := 1
        this.playing := false

        this.step := Config.StepDefault
        this.hold := Config.HoldDefault
        this.spaceGap := 0
        this.dashGap := 0
        this.barGap := 0

        this.pendingRelease := 0   ; chord pack waiting to be released (0 = none)
        this.chordDownAt := 0      ; A_TickCount when the current chord went down
        this.downKeys := Map()     ; keys currently held down
        this.nextDue := 0          ; A_TickCount when the next token is due (0 = now)
        this.speedLock := false

        this.onState := ""         ; optional callback invoked on state changes

        this.ApplyTempo()
    }

    Clamp(value, lo, hi) {
        return Min(Max(value, lo), hi)
    }

    EmitState() {
        if (this.onState)
            this.onState()
    }

    ; --- tempo ----------------------------------------------------------
    ApplyTempo() {
        this.step := Max(this.step, Config.StepMin)
        this.spaceGap := Round(this.step * Config.SpaceRatio)
        this.dashGap := Round(this.step * Config.DashRatio)
        this.barGap := Round(this.step * Config.BarRatio)
        this.hold := this.Clamp(this.hold, Config.HoldMin, this.step - 5)
    }

    ChangeSpeed(delta) {
        if (this.speedLock)
            return
        this.step := Max(this.step + delta, Config.StepMin)
        this.ApplyTempo()
        this.Rebuild(false)
    }

    ; --- sheet parsing ----------------------------------------------------
    ParseChord(text) {
        keys := Trim(text)
        if (keys = "")
            return []
        out := []
        seen := Map()
        if (InStr(keys, " ") || InStr(keys, ","))
            parts := StrSplit(RegExReplace(keys, "\s+", " "), [A_Space, ","])
        else
            parts := StrSplit(keys)
        for k in parts {
            k := Trim(k)
            if (k != "" && !seen.Has(k))
                seen[k] := 1, out.Push(k)
        }
        return out
    }

    PushWait(ms) {
        n := this.tokens.Length
        if (n && this.tokens[n][1] = 1)
            this.tokens[n][2] += ms
        else
            this.tokens.Push([1, ms])
    }

    BuildTokens() {
        this.tokens := []
        i := 1
        len := StrLen(this.seq)
        while (i <= len) {
            c := SubStr(this.seq, i, 1)
            if InStr("`r`n`t", c) {
                i++
                continue
            }
            if (c = "[") {
                j := InStr(this.seq, "]", , i + 1)
                if (!j) {
                    this.tokens.Push([2, "["])
                    i++
                    continue
                }
                chord := this.ParseChord(SubStr(this.seq, i + 1, j - i - 1))
                this.tokens.Push(chord.Length ? [3, chord] : [2, "[]"])
                i := j + 1
                continue
            }
            if (c = " ")
                this.PushWait(this.spaceGap)
            else if (c = "|")
                this.PushWait(this.barGap)
            else if InStr("-" Chr(0x2013) Chr(0x2014), c)
                this.PushWait(this.dashGap)
            else
                this.tokens.Push([2, c])
            i++
        }
        this.pos := this.Clamp(this.pos, 1, this.tokens.Length + 1)
    }

    Rebuild(resetToStart) {
        wasPlaying := this.playing
        this.playing := false
        this.StopPlayback()
        if (this.pendingRelease) {
            this.SendChordUp(this.pendingRelease)
            this.pendingRelease := 0
        }
        this.ReleaseAllDown()
        this.BuildTokens()
        this.pos := resetToStart ? 1 : this.Clamp(this.pos, 1, this.tokens.Length + 1)
        this.EmitState()
        if (wasPlaying) {
            this.playing := true
            this.StartPlayback()
        }
    }

    ; --- key expansion & sending ------------------------------------------
    ExpandKeyChar(ch, &needShift) {
        static shiftMap := Map(
            "!", "1", "@", "2", "#", "3", "$", "4", "%", "5",
            "^", "6", "&", "7", "*", "8", "(", "9", ")", "0",
            "_", "-", "+", "=", "{", "[", "}", "]", ":", ";",
            "<", ",", ">", ".", "?", "/", "|", "\"
        )
        o := Ord(ch)
        if (o >= 65 && o <= 90)                    ; A-Z -> shifted lowercase
            return needShift := true, Chr(o + 32)
        if shiftMap.Has(ch)
            return needShift := true, shiftMap[ch]
        return needShift := false, ch
    }

    ExpandChord(chord) {
        unshifted := []
        shifted := []
        seenU := Map()
        seenS := Map()
        for ch in chord {
            base := this.ExpandKeyChar(ch, &needShift)
            if (needShift) {
                if !seenS.Has(base) {
                    seenS[base] := 1
                    shifted.Push(base)
                }
            } else if !seenU.Has(base) {
                seenU[base] := 1
                unshifted.Push(base)
            }
        }
        return Map("u", unshifted, "s", shifted, "h", shifted.Length > 0)
    }

    ReleaseAllDown() {
        if !this.downKeys.Count
            return
        s := "{Blind}"
        for k, _ in this.downKeys
            s .= "{" k " up}"
        SendInput(s)
        this.downKeys.Clear()
    }

    SendKeyTap(k) {
        this.ReleaseAllDown()
        base := this.ExpandKeyChar(k, &needShift)
        if (needShift) {
            SendInput("{Blind}{Shift down}{" base "}{Shift up}")
            return
        }
        o := Ord(base)
        if ((o >= 48 && o <= 57) || (o >= 65 && o <= 90) || (o >= 97 && o <= 122))
            SendInput("{Blind}{" base "}")
        else
            SendInput("{Blind}" base)
    }

    SendChordDown(chord) {
        pack := this.ExpandChord(chord)
        out := "{Blind}"
        for k in pack["u"]
            this.downKeys[k] := 1, out .= "{" k " down}"
        if pack["h"] {
            this.downKeys["Shift"] := 1, out .= "{Shift down}"
            for k in pack["s"]
                this.downKeys[k] := 1, out .= "{" k " down}"
        }
        SendInput(out)
        return pack
    }

    SendChordUp(pack) {
        out := "{Blind}"
        if pack["h"] {
            for k in pack["s"]
                this.downKeys.Delete(k), out .= "{" k " up}"
            this.downKeys.Delete("Shift"), out .= "{Shift up}"
        }
        for k in pack["u"]
            this.downKeys.Delete(k), out .= "{" k " up}"
        SendInput(out)
    }

    ; --- playback -----------------------------------------------------------
    StartPlayback() {
        this.nextDue := A_TickCount
        SetTimer(TickCallback, Config.TickMs)
    }

    StopPlayback() {
        SetTimer(TickCallback, 0)
    }

    Tick() {
        if (!this.playing)
            return
        now := A_TickCount
        if (this.nextDue && now < this.nextDue)
            return

        if (this.pendingRelease) {
            pack := this.pendingRelease
            this.pendingRelease := 0
            this.SendChordUp(pack)
            ; Keep the next event on the STEP grid instead of drifting by HOLD.
            this.nextDue := Max(now, this.chordDownAt + this.step)
            this.EmitState()
            return
        }

        if (this.pos > this.tokens.Length) {
            this.StopAndReset()
            return
        }

        t := this.tokens[this.pos]
        this.pos++
        switch t[1] {
            case 1:
                this.nextDue := now + t[2]
            case 2:
                this.SendKeyTap(t[2])
                this.nextDue := now + this.step
            case 3:
                this.chordDownAt := now
                this.pendingRelease := this.SendChordDown(t[2])
                this.nextDue := now + this.hold
        }
        this.EmitState()
    }

    TogglePlay() {
        this.playing := !this.playing
        if (this.playing)
            this.StartPlayback()
        else
            this.StopPlayback()
        this.EmitState()
    }

    PlayOne() {
        if (this.pendingRelease) {
            this.SendChordUp(this.pendingRelease)
            this.pendingRelease := 0
        }
        this.ReleaseAllDown()
        while (this.pos <= this.tokens.Length && this.tokens[this.pos][1] = 1)
            this.pos++
        if (this.pos > this.tokens.Length) {
            this.EmitState()
            return
        }
        t := this.tokens[this.pos]
        this.pos++
        if (t[1] = 2)
            this.SendKeyTap(t[2])
        else
            this.SendChordUp(this.SendChordDown(t[2]))
        this.EmitState()
    }

    StopAndReset() {
        this.playing := false
        this.pos := 1
        this.nextDue := 0
        if (this.pendingRelease) {
            this.SendChordUp(this.pendingRelease)
            this.pendingRelease := 0
        }
        this.ReleaseAllDown()
        this.StopPlayback()
        this.EmitState()
    }
}

; ---------------------------------------------------------------------------
; User interface: dark, non-flickering GUI
; ---------------------------------------------------------------------------
class PianoUI {
    __New(engine) {
        this.engine := engine
        engine.onState := (*) => this.SyncState()

        g := Gui("+AlwaysOnTop", "Virtual Piano AUTO")
        this.gui := g
        this.hwnd := g.Hwnd
        g.BackColor := Theme.Bg
        g.SetFont("s10 " Theme.Text)

        this.edit := g.Add("Edit",
            "w580 h180 +WantTab -E0x200 Background" Theme.Panel " " Theme.Text,
            engine.seq)

        btnApply := g.Add("Text",
            "w90 h30 y+10 Center +0x200 Background" Theme.Btn " " Theme.Text,
            "Aplicar")
        this.btnPlay := g.Add("Text",
            "x+10 w90 h30 Center +0x200 Background" Theme.BtnPlay " cWhite",
            "Iniciar")
        btnReset := g.Add("Text",
            "x+10 w90 h30 Center +0x200 Background" Theme.BtnStop " cWhite",
            "Resetar")
        this.lock := g.Add("CheckBox", "x+20 yp+4", "Bloquear Vel.")
        this.lock.Value := engine.speedLock ? 1 : 0

        g.Add("Text", "xm y+15", "STEP:")
        this.stepEdit := g.Add("Edit",
            "x+5 w60 Number -E0x200 Background" Theme.Panel " " Theme.Text,
            engine.step)
        this.stepSlider := g.Add("Slider",
            "x+5 w150 Range" Config.StepMin "-" Config.StepMax,
            engine.step)

        g.Add("Text", "x+20", "HOLD:")
        this.holdEdit := g.Add("Edit",
            "x+5 w60 Number -E0x200 Background" Theme.Panel " " Theme.Text,
            engine.hold)
        this.holdSlider := g.Add("Slider",
            "x+5 w130 Range" Config.HoldMin "-" Config.HoldMax,
            engine.hold)

        this.statusProg := g.Add("Text", "xm y+15 w150", "Progresso: 0/0")
        g.Add("Text", "x+10 w420", "| F1: Play/Pause | End: Reset | [ ou ]: Passo")

        btnApply.OnEvent("Click", (*) => this.Apply())
        this.btnPlay.OnEvent("Click", (*) => this.engine.TogglePlay())
        btnReset.OnEvent("Click", (*) => this.engine.StopAndReset())
        this.stepSlider.OnEvent("Change", (*) => (
            this.stepEdit.Value := this.stepSlider.Value, this.ApplyParams()))
        this.holdSlider.OnEvent("Change", (*) => (
            this.holdEdit.Value := this.holdSlider.Value, this.ApplyParams()))
        this.lock.OnEvent("Click", (*) => (
            this.engine.speedLock := (this.lock.Value = 1)))

        g.OnEvent("Close", (*) => this.CleanExit())

        ; Immersive dark title bar (best effort, harmless if unsupported).
        try {
            val := 1
            DllCall("dwmapi\DwmSetWindowAttribute",
                "Ptr", g.Hwnd, "Int", 20, "Int*", val, "Int", 4)
            DllCall("dwmapi\DwmSetWindowAttribute",
                "Ptr", g.Hwnd, "Int", 19, "Int*", val, "Int", 4)
        }

        g.Show()
        this.SyncState()
    }

    ParseInt(value, fallback) {
        value := Trim(value "")
        if (value = "")
            return fallback
        if RegExMatch(value, "^\d+$")
            return Integer(value)
        return fallback
    }

    Apply() {
        this.engine.seq := this.edit.Value
        this.ApplyParams()
        this.engine.Rebuild(true)
    }

    ApplyParams() {
        e := this.engine
        e.step := this.ParseInt(this.stepEdit.Value, e.step)
        e.hold := this.ParseInt(this.holdEdit.Value, e.hold)
        e.ApplyTempo()
        this.stepEdit.Value := e.step
        this.holdEdit.Value := e.hold
        this.stepSlider.Value := e.step
        this.holdSlider.Value := e.hold
    }

    SyncState() {
        e := this.engine
        this.btnPlay.Text := e.playing ? "Parar" : "Iniciar"
        this.btnPlay.Opt("Background" (e.playing ? Theme.BtnStop : Theme.BtnPlay))
        this.statusProg.Text := "Progresso: " (e.pos - 1) "/" e.tokens.Length
    }

    CleanExit() {
        this.engine.StopAndReset()
        ExitApp()
    }
}

TickCallback() {
    global Piano
    Piano.Tick()
}

IsTargetActive() {
    global PianoUi
    hwnd := WinActive("A")
    if !hwnd
        return false
    return !PianoUi || hwnd != PianoUi.hwnd
}

Piano := Engine()
PianoUi := PianoUI(Piano)

#HotIf IsTargetActive()
F1::Piano.TogglePlay()
End::Piano.StopAndReset()
[::Piano.PlayOne()
]::Piano.PlayOne()
#HotIf

#HotIf IsTargetActive() && !Piano.speedLock
~WheelUp::Piano.ChangeSpeed(-Config.WheelDelta)
~WheelDown::Piano.ChangeSpeed(Config.WheelDelta)
#HotIf
