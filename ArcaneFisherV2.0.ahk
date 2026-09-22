#NoEnv
#SingleInstance Force
#Persistent
SetBatchLines, -1
SetMouseDelay, -1
SendMode, Input
SetWorkingDir, %A_ScriptDir%
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen
SetTitleMatchMode, 2

; ============================================================
; Arcane Fisher V2.1
; AHK v1
;
; Files expected beside this script:
;   Gdip_All.ahk
;   settings.ini
;   fish.ico       (optional)
;   foxy.wav       (optional catch sound)
;   foxy.gif       (optional artwork; not required by scanner)
; ============================================================

; ---------- Load settings.ini ----------
IniRead, RodSlider, settings.ini, Config, RodSlider, 9
if (RodSlider = 10)
    RodKey := "0"
else
    RodKey := RodSlider

IniRead, SystemCanFish, settings.ini, System, CanFish, 1
if (SystemCanFish != 1)
    RodKey := ""

; ---------- User settings ----------
global RodKey := RodKey
global ScanInterval := 35
global CatchCooldown := 900
global RecastDelay := 650
global CastDoubleClickGap := 120
global CenterYOffset := 100

global BrightThreshold := 175
global BrightRequired := 5

global EventR := 20
global EventG := 220
global EventB := 20
global EventTolerance := 38
global EventRequired := 2

global Running := false
global MultiInstance := true
global ShowOverlay := true

global Win1 := 0
global Win2 := 0
global State1 := "idle"
global State2 := "idle"
global LastAction1 := 0
global LastAction2 := 0
global LastCast1 := 0
global LastCast2 := 0
global ScanAfter1 := 0
global ScanAfter2 := 0

OnExit, Cleanup

; Gdip_All.ahk is now at the repository root.
if !FileExist("Gdip_All.ahk")
{
    MsgBox, 48, Error, Gdip_All.ahk was not found beside the script.
    ExitApp
}

if !pToken := Gdip_Startup()
{
    MsgBox, 48, Error, GDI+ failed to start.
    ExitApp
}

; Optional tray icon from the new repo files.
if FileExist("fish.ico")
    Menu, Tray, Icon, fish.ico

; ---------- GUI ----------
Gui, Main:+AlwaysOnTop -MaximizeBox
Gui, Main:Color, 1A1A1A
Gui, Main:Font, s10 cFFFFFF, Segoe UI
Gui, Main:Add, Text, vStatus w300 Center cRed, ROBLOX: NOT FOUND
Gui, Main:Add, Text, vMacroStatus w300 y+8 Center, Macro: IDLE
Gui, Main:Add, Button, gToggleMacro w300 y+12, Start / Stop Autofish (F1)
Gui, Main:Add, CheckBox, vMultiBox gToggleMulti Checked, Multi-Instance
Gui, Main:Add, CheckBox, vOverlayBox gToggleOverlay Checked, Show Scan Overlay
Gui, Main:Add, Text, vInfo w300 y+12 Center, Rod key: %RodKey%  |  Scan: %ScanInterval% ms
Gui, Main:Show, w340 h180, Arcane Fisher V2.1

SetTimer, DiscoverRoblox, 1000
SetTimer, ScanLoop, %ScanInterval%
return

; ---------- Hotkey ----------
F1::
ToggleMacro:
Running := !Running
if Running
{
    GuiControl, Main:, MacroStatus, Macro: FISHING ACTIVE
    DiscoverRoblox()
    PrepareWindows()
}
else
{
    StopAll()
}
return

; ---------- Settings toggles ----------
ToggleMulti:
Gui, Main:Submit, NoHide
MultiInstance := MultiBox
DiscoverRoblox()
return

ToggleOverlay:
Gui, Main:Submit, NoHide
ShowOverlay := OverlayBox
if !ShowOverlay
    HideOverlays()
return

; ---------- Find Roblox clients ----------
DiscoverRoblox:
WinGet, list, List, ahk_exe RobloxPlayerBeta.exe
found := []

Loop, %list%
{
    hwnd := list%A_Index%
    WinGetTitle, title, ahk_id %hwnd%
    if (title = "Roblox" || InStr(title, "Roblox"))
        found.Push(hwnd)
}

if (found.Length() >= 1)
    Win1 := found[1]
else
    Win1 := 0

if (MultiInstance && found.Length() >= 2)
    Win2 := found[2]
else
    Win2 := 0

count := (Win1 ? 1 : 0) + (Win2 ? 1 : 0)

if count
{
    GuiControl, Main:+c00CC66, Status
    GuiControl, Main:, Status, ROBLOX: RUNNING (%count%)
}
else
{
    GuiControl, Main:+cFF4444, Status
    GuiControl, Main:, Status, ROBLOX: NOT FOUND
    if Running
        StopAll()
}
return

; ---------- Main scanner ----------
ScanLoop:
if !Running
    return

if !WinExist("ahk_id " Win1)
    DiscoverRoblox()
if MultiInstance && Win2 && !WinExist("ahk_id " Win2)
    DiscoverRoblox()

if Win1
    ScanInstance(1, Win1)

if MultiInstance && Win2
    ScanInstance(2, Win2)
return

ScanInstance(index, hwnd)
{
    global Running, ShowOverlay
    global BrightThreshold, BrightRequired
    global EventR, EventG, EventB, EventTolerance, EventRequired
    global CatchCooldown, RecastDelay, ScanAfter1, ScanAfter2
    global LastAction1, LastAction2, LastCast1, LastCast2
    global State1, State2, CenterYOffset

    if !WinExist("ahk_id " hwnd)
        return

    now := A_TickCount

    if (index = 1)
    {
        state := State1
        lastAction := LastAction1
        lastCast := LastCast1
        scanAfter := ScanAfter1
    }
    else
    {
        state := State2
        lastAction := LastAction2
        lastCast := LastCast2
        scanAfter := ScanAfter2
    }

    if (now - lastAction < CatchCooldown)
        return

    if (scanAfter && now < scanAfter)
        return

    WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
    if ErrorLevel || ww < 400 || wh < 300
        return

    shortSide := (ww < wh ? ww : wh)
    box := Round(shortSide * 0.22)
    sx := wx + (ww // 2) - (box // 2)
    sy := wy + (wh // 2) - (box // 2) - CenterYOffset

    eventW := Round(ww * 0.28)
    eventH := Round(wh * 0.50)
    ex := wx + ww - eventW
    ey := wy + Round(wh * 0.25)

    bright := CountBright(sx, sy, box, box, BrightThreshold)
    event := CountNearColor(ex, ey, eventW, eventH, EventR, EventG, EventB, EventTolerance)

    if ShowOverlay
        DrawOverlay(index, sx, sy, box, event)

    if (bright >= BrightRequired && event >= EventRequired)
    {
        if (state != "reeling")
        {
            Reel(index, hwnd)
            state := "reeling"
            lastAction := now
        }
        return
    }

    ; Recast if this client has been stuck for 45 seconds.
    if (lastCast && now - lastCast > 45000)
    {
        Recast(index, hwnd)
        state := "casting"
        lastAction := now
        lastCast := now
        scanAfter := now + RecastDelay
    }

    if (index = 1)
    {
        State1 := state
        LastAction1 := lastAction
        LastCast1 := lastCast
        ScanAfter1 := scanAfter
    }
    else
    {
        State2 := state
        LastAction2 := lastAction
        LastCast2 := lastCast
        ScanAfter2 := scanAfter
    }
}

CountBright(x, y, w, h, threshold)
{
    count := 0
    step := 8

    Loop, % Ceil(h / step)
    {
        py := y + ((A_Index - 1) * step)
        Loop, % Ceil(w / step)
        {
            px := x + ((A_Index - 1) * step)
            PixelGetColor, c, %px%, %py%, RGB
            r := (c >> 16) & 255
            g := (c >> 8) & 255
            b := c & 255

            if (r >= threshold && g >= threshold && b >= threshold)
                count++
        }
    }
    return count
}

CountNearColor(x, y, w, h, tr, tg, tb, tolerance)
{
    count := 0
    step := 8

    Loop, % Ceil(h / step)
    {
        py := y + ((A_Index - 1) * step)
        Loop, % Ceil(w / step)
        {
            px := x + ((A_Index - 1) * step)
            PixelGetColor, c, %px%, %py%, RGB

            r := (c >> 16) & 255
            g := (c >> 8) & 255
            b := c & 255

            if (Abs(r-tr) <= tolerance
             && Abs(g-tg) <= tolerance
             && Abs(b-tb) <= tolerance)
                count++
        }
    }
    return count
}

; ---------- Fishing actions ----------
PrepareWindows()
{
    global Win1, Win2, MultiInstance
    global LastCast1, LastCast2, ScanAfter1, ScanAfter2
    global State1, State2

    if Win1
    {
        Cast(Win1)
        LastCast1 := A_TickCount
        ScanAfter1 := A_TickCount + 2000
        State1 := "casting"
    }

    if MultiInstance && Win2
    {
        Sleep, 250
        Cast(Win2)
        LastCast2 := A_TickCount
        ScanAfter2 := A_TickCount + 2000
        State2 := "casting"
    }
}

Cast(hwnd)
{
    global RodKey, CastDoubleClickGap

    if (RodKey = "")
        return

    WinGetPos, x, y, w, h, ahk_id %hwnd%
    cx := x + (w // 2)
    cy := y + (h // 2)

    ControlClick, x%cx% y%cy%, ahk_id %hwnd%, , Left, 1, NA
    Sleep, %CastDoubleClickGap%
    ControlClick, x%cx% y%cy%, ahk_id %hwnd%, , Left, 1, NA
    Sleep, 120
    ControlSend,, %RodKey%, ahk_id %hwnd%
}

Reel(index, hwnd)
{
    global RodKey, RecastDelay
    global LastCast1, LastCast2, ScanAfter1, ScanAfter2

    if (RodKey = "")
        return

    WinGetPos, x, y, w, h, ahk_id %hwnd%
    cx := x + (w // 2)
    cy := y + (h // 2)

    ControlClick, x%cx% y%cy%, ahk_id %hwnd%, , Left, 1, NA
    Sleep, 90
    ControlSend,, %RodKey%, ahk_id %hwnd%

    ; Optional new file: play foxy.wav when a catch is detected.
    if FileExist("foxy.wav")
        SoundPlay, foxy.wav

    if (index = 1)
    {
        LastCast1 := A_TickCount
        ScanAfter1 := A_TickCount + RecastDelay
    }
    else
    {
        LastCast2 := A_TickCount
        ScanAfter2 := A_TickCount + RecastDelay
    }

    SetTimer, Recast1, Off
    SetTimer, Recast2, Off

    if (index = 1)
        SetTimer, Recast1, -850
    else
        SetTimer, Recast2, -850
}

Recast(index, hwnd)
{
    global LastCast1, LastCast2, ScanAfter1, ScanAfter2
    global State1, State2, RecastDelay

    Cast(hwnd)

    if (index = 1)
    {
        LastCast1 := A_TickCount
        ScanAfter1 := A_TickCount + 1800
        State1 := "casting"
    }
    else
    {
        LastCast2 := A_TickCount
        ScanAfter2 := A_TickCount + 1800
        State2 := "casting"
    }
}

Recast1:
if Running && Win1
    Recast(1, Win1)
return

Recast2:
if Running && Win2
    Recast(2, Win2)
return

; ---------- Overlay ----------
DrawOverlay(index, x, y, w, event)
{
    global ShowOverlay

    if !ShowOverlay
        return

    guiName := (index = 1 ? "Scan1" : "Scan2")

    Gui, %guiName%:Destroy
    Gui, %guiName%:+AlwaysOnTop -Caption +ToolWindow +E0x20

    if (event > 2)
        Gui, %guiName%:Color, 00AA55
    else
        Gui, %guiName%:Color, AA3333

    WinSet, Transparent, 80
    Gui, %guiName%:Show, x%x% y%y% w%w% h%w% NoActivate
}

HideOverlays()
{
    Gui, Scan1:Destroy
    Gui, Scan2:Destroy
}

StopAll()
{
    global Running, State1, State2
    Running := false
    State1 := "idle"
    State2 := "idle"
    SetTimer, Recast1, Off
    SetTimer, Recast2, Off
    HideOverlays()
    GuiControl, Main:, MacroStatus, Macro: IDLE
}

Cleanup:
StopAll()
Gdip_Shutdown(pToken)
ExitApp
return

GuiClose:
ExitApp
return

#Include Gdip_All.ahk
