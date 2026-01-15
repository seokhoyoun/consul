
$ensignPath  = "C:\Ensign10\Ensign.exe"
$logFilePath = "C:\Ensign10\outputlog\dyo.txt"
$consulPath  = "C:\AHK(2)\NT8 Helper.exe"
$ahkPath     = "C:\AHK(2)\NT8_Trade_Bridge_Config.ahk"

if (Test-Path $consulPath) {
    Start-Process -FilePath $consulPath
}

if (Test-Path $ahkPath) { 
    Start-Process -FilePath $ahkPath 
}

$process = Start-Process -FilePath $ensignPath -PassThru
$process.WaitForExit()

if (Test-Path $logFilePath) {
    Remove-Item $logFilePath -Force -ErrorAction SilentlyContinue
}