#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; INITIAL SETTINGS & GUI SETUP
; ==============================================================================
; 하워드 지침서 기반 기본 경로 설정 [cite: 84, 258]
global DefaultLogPath := "C:\Ensign10\Output.txt"
global DefaultStatusPath := "C:\Trading\status.txt"

MyGui := Gui("+AlwaysOnTop", "NT8 Trade Bridge Config")
MyGui.SetFont("s9", "Segoe UI")

; --- Path Configuration Section ---
MyGui.Add("GroupBox", "w380 h120", "File Path Settings")
MyGui.Add("Text", "xp+10 yp+25", "Ensign Output (Signal):")
EditLogPath := MyGui.Add("Edit", "r1 w250", DefaultLogPath)
MyGui.Add("Button", "x+5 yp-2 w60", "Browse").OnEvent("Click", SelectLogFile)

MyGui.Add("Text", "xm+10 yp+35", "Consul Status (Helper):")
EditStatusPath := MyGui.Add("Edit", "r1 w250", DefaultStatusPath)
MyGui.Add("Button", "x+5 yp-2 w60", "Browse").OnEvent("Click", SelectStatusFile)

; --- Monitoring Section ---
MyGui.Add("GroupBox", "xm w380 h100", "Live Monitor")
MyGui.Add("Text", "xp+10 yp+25", "System Status:")
StatusDisplay := MyGui.Add("Text", "x+10 w200 cBlue", "READY")

MyGui.Add("Text", "xm+10 yp+35", "Last Signal Detected:")
SignalDisplay := MyGui.Add("Text", "x+10 w200 cRed", "NONE")

; --- Control Buttons ---
BtnStart := MyGui.Add("Button", "xm w185 h40 Default", "START MONITORING")
BtnStart.OnEvent("Click", StartProcess)
MyGui.Add("Button", "x+10 w185 h40", "STOP").OnEvent("Click", StopProcess)

MyGui.Show()

; ==============================================================================
; FUNCTIONS
; ==============================================================================

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
    BtnStart.Enabled := False
    StatusDisplay.Value := "MONITORING ACTIVE"
    StatusDisplay.Opt("cGreen")
    SetTimer(CheckFiles, 100) ; 100ms 간격으로 감시 시작
}

StopProcess(*) {
    BtnStart.Enabled := True
    StatusDisplay.Value := "STOPPED"
    StatusDisplay.Opt("cRed")
    SetTimer(CheckFiles, 0)
}

CheckFiles() {
    LogPath := EditLogPath.Value
    StatusPath := EditStatusPath.Value

    if !FileExist(LogPath) or !FileExist(StatusPath)
        return

    try {
        ; 1. 상태 및 신호 파일 읽기
        status := FileRead(StatusPath)
        signal := FileRead(LogPath)

        ; 2. 하워드 지침서에 언급된 'Buy Now' / 'Sell Now' 키워드 매칭 [cite: 46, 47, 191]
        if InStr(status, "CLEAR") {
            if InStr(signal, "Buy Now") {
                SignalDisplay.Value := "BUY (F4) SENT"
                ExecuteTrade("F4")
                FileDelete(LogPath) ; 처리 후 파일 삭제하여 중복 방지
            }
            else if InStr(signal, "Sell Now") {
                SignalDisplay.Value := "SELL (F9) SENT"
                ExecuteTrade("F9")
                FileDelete(LogPath)
            }
        } else {
            StatusDisplay.Value := "BUSY (ORDER WORKING)"
            if signal != "" {
                FileDelete(LogPath) ; BUSY 상태일 때 들어온 신호는 삭제 [지침서 논리 반영]
            }
        }
    } catch Error {
        return ; 파일 접근 충돌 시 무시하고 다음 틱에 재시도
    }
}

ExecuteTrade(Key) {
    if WinExist("ahk_exe nt8.exe") {
        WinActivate("ahk_exe nt8.exe")
        Sleep(100) ; 창 활성화 대기
        Send("{" . Key . "}")
    }
}