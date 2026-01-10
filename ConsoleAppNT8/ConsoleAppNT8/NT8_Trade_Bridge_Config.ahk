#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; INITIAL SETTINGS & LOAD SAVED CONFIG
; ==============================================================================
global IniFile := "settings.ini"
global NT8_EXE_NAME := "NinjaTrader.exe"

; [수정] 초기 기본 경로를 현재 스크립트 위치의 status.txt로 설정
DefaultStatusPath := A_ScriptDir . "\status.txt"
global SavedStatusPath := IniRead(IniFile, "Paths", "ConsulStatus", DefaultStatusPath)

MyGui := Gui("+AlwaysOnTop", "NT8 Trade Bridge v1.7.1")
MyGui.SetFont("s9", "Segoe UI")

; --- Path Configuration Section ---
MyGui.Add("GroupBox", "w380 h80", "Command Bridge Settings")
MyGui.Add("Text", "xp+10 yp+25", "Consul Status (Bridge File):")
EditStatusPath := MyGui.Add("Edit", "r1 w250", SavedStatusPath)
MyGui.Add("Button", "x+5 yp-2 w60", "Browse").OnEvent("Click", SelectStatusFile)

; --- Control Buttons ---
BtnStart := MyGui.Add("Button", "xm w380 h45 Default", "START EXECUTION ENGINE (SAVE & HIDE)")
BtnStart.OnEvent("Click", StartProcess)

; --- Tray Menu ---
A_TrayMenu.Delete()
A_TrayMenu.Add("Show Config", (*) => MyGui.Show())
A_TrayMenu.Add("Exit Program", (*) => ExitApp())
A_TrayMenu.Default := "Show Config"

MyGui.Show()

; ==============================================================================
; FUNCTIONS
; ==============================================================================

^!s::MyGui.Show()

SelectStatusFile(*) {
    SelectedFile := FileSelect(3, , "Select Status Bridge File", "Text Documents (*.txt)")
    if SelectedFile != ""
        EditStatusPath.Value := SelectedFile
}

StartProcess(*) {
    IniWrite(EditStatusPath.Value, IniFile, "Paths", "ConsulStatus")
    
    ; 브릿지 파일이 없으면 미리 생성하여 C#과의 연결 준비
    if !FileExist(EditStatusPath.Value)
        FileAppend("CLEAR", EditStatusPath.Value)

    MyGui.Hide() 
    TrayTip("NT8 Execution Engine", "Waiting for commands at: " . EditStatusPath.Value, 1)
    SetTimer(CheckCommandBridge, 150) 
}

CheckCommandBridge() {
    StatusPath := EditStatusPath.Value
    if !FileExist(StatusPath)
        return

    try {
        ; 1. Bridge 파일 읽기
        rawContent := Trim(FileRead(StatusPath))
        
        ; 2. 상태값이 아닌 '명령'이 들어왔을 때만 실행
        if (rawContent = "" or rawContent = "CLEAR" or rawContent = "BUSY" or rawContent = "PAUSED")
            return

        ; 3. 명령 파싱 (Format: BUY, YMH26)
        parsed := StrSplit(rawContent, ",")
        if (parsed.Length < 2)
            return

        action := Trim(parsed[1])
        instrument := Trim(parsed[2])

        ; 4. 정확한 SuperDOM 타겟팅 및 실행
        if (action = "BUY") {
            ExecuteTrade("F4", instrument)
        } else if (action = "SELL") {
            ExecuteTrade("F9", instrument)
        }
        
        ; 실행 직후 상태를 CLEAR로 변경하여 중복 실행 방지
        FileOpen(StatusPath, "w").Write("CLEAR") 

    } catch Error {
        return 
    }
}

ExecuteTrade(Key, Inst) {
    targetTitle := "SuperDOM - " . Inst . " ahk_exe " . NT8_EXE_NAME
    
    if WinExist(targetTitle) {
        WinActivate(targetTitle) ;
        Sleep(100) 
        Send("{" . Key . "}")
        TrayTip("Trade Executed", Inst . " : " . Key, 1)
    } else {
        if WinExist("ahk_exe " . NT8_EXE_NAME) {
            WinActivate("ahk_exe " . NT8_EXE_NAME)
            Sleep(100)
            Send("{" . Key . "}")
        }
    }
}