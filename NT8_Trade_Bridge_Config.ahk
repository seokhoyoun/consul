#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; INITIAL SETTINGS & LOAD SAVED CONFIG
; ==============================================================================
global IniFile := "settings.ini"
global NT8_EXE_NAME := "NinjaTrader.exe"

; INI 파일에서 기존 경로를 읽어옵니다. 파일이 없으면 하워드 지침서의 기본값을 사용합니다. 
global SavedLogPath := IniRead(IniFile, "Paths", "EnsignLog", "C:\Ensign10\Output.txt")
global SavedStatusPath := IniRead(IniFile, "Paths", "ConsulStatus", "C:\Trading\status.txt")

MyGui := Gui("+AlwaysOnTop", "NT8 Trade Bridge v1.5")
MyGui.SetFont("s9", "Segoe UI")

; --- Path Configuration Section ---
MyGui.Add("GroupBox", "w380 h120", "File Path Settings")
MyGui.Add("Text", "xp+10 yp+25", "Ensign Output (Signal):")
EditLogPath := MyGui.Add("Edit", "r1 w250", SavedLogPath)
MyGui.Add("Button", "x+5 yp-2 w60", "Browse").OnEvent("Click", SelectLogFile)

MyGui.Add("Text", "xm+10 yp+35", "Consul Status (Helper):")
EditStatusPath := MyGui.Add("Edit", "r1 w250", SavedStatusPath)
MyGui.Add("Button", "x+5 yp-2 w60", "Browse").OnEvent("Click", SelectStatusFile)

; --- Control Buttons ---
BtnStart := MyGui.Add("Button", "xm w380 h45 Default", "START MONITORING (SAVE & HIDE)")
BtnStart.OnEvent("Click", StartProcess)

; --- Tray Menu (숨겨진 UI 복구용) ---
A_TrayMenu.Delete()
A_TrayMenu.Add("Show Config", (*) => MyGui.Show())
A_TrayMenu.Add("Exit Program", (*) => ExitApp())
A_TrayMenu.Default := "Show Config"

MyGui.Show()

; ==============================================================================
; FUNCTIONS
; ==============================================================================

; [단축키: Ctrl+Alt+S를 누르면 설정창이 다시 나타납니다]
^!s::MyGui.Show()

SelectLogFile(*) {
    SelectedFile := FileSelect(3, , "Select Ensign Output File", "Text Documents (*.txt)")
    if SelectedFile != ""
        EditLogPath.Value := SelectedFile
}

SelectStatusFile(*) {
    SelectedFile := FileSelect(3, , "Select Status File", "Text Documents (*.txt)")
    if SelectedFile != ""
        EditStatusPath.Value := SelectedFile
}

StartProcess(*) {
    ; 현재 입력된 경로를 INI 파일에 저장합니다.
    IniWrite(EditLogPath.Value, IniFile, "Paths", "EnsignLog")
    IniWrite(EditStatusPath.Value, IniFile, "Paths", "ConsulStatus")
    
    MyGui.Hide() 
    TrayTip("NT8 Trade Bridge", "Settings Saved. Monitoring started.", 1)
    SetTimer(CheckFiles, 100) 
}

CheckFiles() {
    LogPath := EditLogPath.Value
    StatusPath := EditStatusPath.Value

    if !FileExist(LogPath) or !FileExist(StatusPath)
        return

    try {
        ; 1. 파일 읽기 (하워드의 지침서에 따른 ASCII 로그 모니터링) [cite: 84, 194]
        status := FileRead(StatusPath)
        signalRaw := FileRead(LogPath)

        if signalRaw == ""
            return

        ; 2. 신호 분석 (Format: BUY/SELL, INSTRUMENT)
        parsedData := StrSplit(signalRaw, ",")
        if (parsedData.Length < 2)
            return

        command := Trim(parsedData[1])
        instrument := Trim(parsedData[2])

        ; 3. Consul Helper의 상태 게이트 확인
        if InStr(status, "CLEAR") {
            if (command == "BUY") {
                ExecuteTrade("F4", instrument)
                FileDelete(LogPath) 
            }
            else if (command == "SELL") {
                ExecuteTrade("F9", instrument)
                FileDelete(LogPath)
            }
        } else {
            ; BUSY 상태일 때 신호 삭제 (하워드 로직 준수)
            FileDelete(LogPath)
        }
    } catch Error {
        return 
    }
}

ExecuteTrade(Key, Inst) {
    ; 타이틀과 실행파일을 조합한 정확한 윈도우 타겟팅
    targetWin := "SuperDOM - " . Inst . " ahk_exe " . NT8_EXE_NAME
    
    if WinExist(targetWin) {
        WinActivate(targetWin) 
        Sleep(150) 
        Send("{" . Key . "}")
        TrayTip("Trade Executed", Inst . " : " . Key . " sent.", 1)
    } else {
        TrayTip("Window Error", "Could not find: " . targetWin, 3)
    }
}