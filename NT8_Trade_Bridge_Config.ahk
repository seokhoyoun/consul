#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; INITIAL SETTINGS & LOAD SAVED CONFIG
; ==============================================================================
global IniFile := "settings.ini"
global NT8_EXE_NAME := "NinjaTrader.exe"
global LastFileSize := 0
global TargetInst := ""

; INI 파일에서 저장된 경로들을 읽어옵니다.
global SavedLogPath := IniRead(IniFile, "Paths", "EnsignLog", "C:\Ensign10\OutputLog\DYO.txt")
global SavedStatusPath := IniRead(IniFile, "Paths", "ConsulStatus", "C:\Trading\status.txt")
global SavedInstPath := IniRead(IniFile, "Paths", "InstrumentFile", "C:\Trading\instrument.txt")

MyGui := Gui("+AlwaysOnTop", "NT8 Trade Bridge v1.6.1")
MyGui.SetFont("s9", "Segoe UI")

; --- Path Configuration Section ---
MyGui.Add("GroupBox", "w380 h160", "File Path Settings") 

MyGui.Add("Text", "xp+10 yp+25", "Ensign DYO.txt (Signal Trigger):")
EditLogPath := MyGui.Add("Edit", "r1 w250", SavedLogPath)
MyGui.Add("Button", "x+5 yp-2 w60", "Browse").OnEvent("Click", SelectLogFile)

MyGui.Add("Text", "xm+10 yp+35", "Consul Status (Helper):")
EditStatusPath := MyGui.Add("Edit", "r1 w250", SavedStatusPath)
MyGui.Add("Button", "x+5 yp-2 w60", "Browse").OnEvent("Click", SelectStatusFile)

; [추가] Instrument Config 경로 설정
MyGui.Add("Text", "xm+10 yp+35", "Instrument Config (Targeting):")
EditInstPath := MyGui.Add("Edit", "r1 w250", SavedInstPath)
MyGui.Add("Button", "x+5 yp-2 w60", "Browse").OnEvent("Click", SelectInstFile)

; --- Control Buttons ---
BtnStart := MyGui.Add("Button", "xm w380 h45 Default", "START MONITORING (SAVE & HIDE)")
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

SelectLogFile(*) {
    SelectedFile := FileSelect(3, , "Select Ensign DYO.txt File", "Text Documents (*.txt)")
    if SelectedFile != ""
        EditLogPath.Value := SelectedFile
}

SelectStatusFile(*) {
    SelectedFile := FileSelect(3, , "Select Status File", "Text Documents (*.txt)")
    if SelectedFile != ""
        EditStatusPath.Value := SelectedFile
}

; [추가] instrument.txt 파일 선택 함수
SelectInstFile(*) {
    SelectedFile := FileSelect(3, , "Select Instrument Config File", "Text Documents (*.txt)")
    if SelectedFile != ""
        EditInstPath.Value := SelectedFile
}

StartProcess(*) {
    global LastFileSize, TargetInst
    
    ; 설정값 저장
    IniWrite(EditLogPath.Value, IniFile, "Paths", "EnsignLog")
    IniWrite(EditStatusPath.Value, IniFile, "Paths", "ConsulStatus")
    IniWrite(EditInstPath.Value, IniFile, "Paths", "InstrumentFile")
    
    ; [추가] 시작 시 설정된 경로에서 종목명 읽기
    if FileExist(EditInstPath.Value) {
        content := Trim(FileRead(EditInstPath.Value))
        if content != ""
            TargetInst := StrSplit(content, "`n", "`r")[1] ; 첫 줄만 가져옴
    }

    if FileExist(EditLogPath.Value)
        LastFileSize := FileGetSize(EditLogPath.Value)
    
    MyGui.Hide() 
    TrayTip("NT8 Trade Bridge v1.6.1", "Monitoring Started with Target: " . (TargetInst = "" ? "General" : TargetInst), 1)
    SetTimer(CheckFiles, 200)
}

CheckFiles() {
    global LastFileSize
    LogPath := EditLogPath.Value
    StatusPath := EditStatusPath.Value

    if !FileExist(LogPath) or !FileExist(StatusPath)
        return

    try {
        status := Trim(FileRead(StatusPath))
        if (status = "PAUSED") ;
            return

        CurrentSize := FileGetSize(LogPath)
        if (CurrentSize <= LastFileSize) {
            LastFileSize := CurrentSize
            return
        }

        FileObj := FileOpen(LogPath, "r")
        FileObj.Seek(LastFileSize)
        NewLines := FileObj.Read()
        FileObj.Close()
        LastFileSize := CurrentSize

        Loop Parse, NewLines, "`n", "`r" {
          
            if (A_LoopField = "")
                continue
            
            if (status = "CLEAR") { ;
                if InStr(A_LoopField, "Ninja BUY") ;
                    ExecuteTrade("F4")
                else if InStr(A_LoopField, "Ninja SELL") ;
                    ExecuteTrade("F9")
            }
        }
    } catch Error {
        return 
    }
}

ExecuteTrade(Key) {
    global TargetInst
    ; [보완] 종목명이 있으면 특정 SuperDOM을, 없으면 전체 NT8 창을 타겟팅
    targetTitle := (TargetInst != "") ? "SuperDOM - " . TargetInst . " ahk_exe " . NT8_EXE_NAME : "ahk_exe " . NT8_EXE_NAME
    
    if WinExist(targetTitle) {
        WinActivate(targetTitle)
        Sleep(150)
        Send("{" . Key . "}")
        TrayTip("Trade Sent", (TargetInst = "" ? "Active Window" : TargetInst) . " : " . Key, 1)
    } else {
        ; Fallback: 특정 종목 창이 없으면 실행 중인 NT8 프로세스에 전송
        if WinExist("ahk_exe " . NT8_EXE_NAME) {
            WinActivate("ahk_exe " . NT8_EXE_NAME)
            Sleep(150)
            Send("{" . Key . "}")
        }
    }
}