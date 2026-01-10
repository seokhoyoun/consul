using NinjaTrader.Client;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading;

internal class Program
{
    private static long lastFileSize = 0;
    private static bool isAutoMode = true;
    private static string dyoPath = @"C:\Ensign10\OutputLog\DYO.txt";
    private static string statusFilePath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "status.txt");
    private static string accountPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "account.txt");
    private static string dyoPathConfigFile = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "dyoPath.txt");
    private static string account = "";

    // UI 전용 변수 업데이트
    private static string lastSignalTime = "N/A";
    private static string lastSignalDetail = "N/A"; // [추가] 방향 및 종목 정보 저장

    private static void Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;
        Console.CursorVisible = false;

        try
        {
            if (File.Exists(dyoPathConfigFile))
            {
                string loadedPath = File.ReadAllText(dyoPathConfigFile).Trim();
                if (!string.IsNullOrEmpty(loadedPath)) dyoPath = loadedPath;
            }
            else
            {
                File.WriteAllText(dyoPathConfigFile, dyoPath);
            }

            if (!File.Exists(dyoPath))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(dyoPath));
                File.WriteAllText(dyoPath, "");
            }
            lastFileSize = new FileInfo(dyoPath).Length;

            if (File.Exists(accountPath)) account = File.ReadAllText(accountPath).Trim();
            if (string.IsNullOrEmpty(account))
            {
                Console.Write("[SETUP] Enter Account Name: ");
                account = Console.ReadLine()?.Trim() ?? "Sim101";
                File.WriteAllText(accountPath, account);
            }
        }
        catch (Exception ex) { Console.WriteLine($"Init Error: {ex.Message}"); return; }

        Client ntClient = new Client();
        if (ntClient.Connected(0) != 0)
        {
            Console.WriteLine("[ERROR] NT8 is not running. Please start NinjaTrader.");
            Thread.Sleep(3000);
            return;
        }

        Console.Clear();

        while (true)
        {
            try
            {
                bool isSystemBusy = CheckSystemBusy(ntClient);
                HandleInput(isSystemBusy);

                FileInfo dyoInfo = new FileInfo(dyoPath);

                // 파일이 없거나 크기가 0인 경우 리셋으로 간주
                if (!dyoInfo.Exists || dyoInfo.Length == 0)
                {
                    lastFileSize = 0;
                    lastSignalTime = "N/A";
                    lastSignalDetail = "N/A";
                }
                else if (dyoInfo.Length < lastFileSize)
                {
                    // 파일 리셋 대응 (PowerShell 스크립트 등)
                    lastFileSize = 0;
                    lastSignalTime = "N/A";
                    lastSignalDetail = "N/A";
                }
                else if (dyoInfo.Length > lastFileSize)
                {
                    ProcessNewSignals(ntClient, isSystemBusy);
                    lastFileSize = dyoInfo.Length;
                }

                DrawUI(isSystemBusy, dyoInfo.Exists ? dyoInfo.Length : 0);
                Thread.Sleep(200);
            }
            catch (Exception ex)
            {
                Console.SetCursorPosition(0, 18);
                Console.WriteLine($"[RUNTIME ERROR] {ex.Message} ".PadRight(50));
            }
        }
    }

    private static void HandleInput(bool isBusy)
    {
        if (Console.KeyAvailable)
        {
            var key = Console.ReadKey(true).Key;
            if (key == ConsoleKey.M && !isBusy)
            {
                isAutoMode = !isAutoMode;
            }
        }
    }
    private static void ProcessNewSignals(Client ntClient, bool isBusy)
    {
        using (var stream = new FileStream(dyoPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        using (var reader = new StreamReader(stream))
        {
            stream.Seek(lastFileSize, SeekOrigin.Begin);
            string newLines = reader.ReadToEnd();

            foreach (string line in newLines.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries))
            {
                // 쉼표로 split: 01-10, 08:57:21, YMH26 Ninja SELL
                string[] parts = line.Split(',');

                if (parts.Length >= 3)
                {
                    lastSignalTime = parts[1].Trim(); // 시간 추출

                    // 세 번째 부분에서 instrument와 action 추출
                    string[] detailParts = parts[2].Trim().Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);

                    if (detailParts.Length >= 3 && detailParts[1].Equals("Ninja", StringComparison.OrdinalIgnoreCase))
                    {
                        string instrument = detailParts[0]; // YMH26
                        string action = detailParts[2].ToUpper(); // BUY 또는 SELL

                        // UI 표시용 정보 업데이트
                        lastSignalDetail = $"{action} @ {instrument}";

                        if (isAutoMode && !isBusy)
                        {
                            File.WriteAllText(statusFilePath, $"{action}, {instrument}");
                        }
                    }
                }
            }
        }
    }

    private static bool CheckSystemBusy(Client ntClient)
    {
        if (!isAutoMode) return false; // 리소스 절약을 위해 수동 모드 시 API 호출 생략
        string orders = ntClient.Orders(account);
        return !string.IsNullOrEmpty(orders) && orders.Split('|').Any(id => ntClient.OrderStatus(id) == "Working");
    }

    private static void DrawUI(bool isBusy, long currentSize)
    {
        Console.SetCursorPosition(0, 0);
        Console.WriteLine("╔══════════════════════════════════════════════════╗");
        Console.WriteLine("║           NINJATRADER CONSUL HELPER v1.1.4       ║");
        Console.WriteLine("╠══════════════════════════════════════════════════╣");

        // 1. SYSTEM STATUS
        Console.Write("║  SYSTEM STATUS : ");
        Console.ForegroundColor = isBusy ? ConsoleColor.Red : ConsoleColor.Green;
        Console.Write(string.Format("{0,-32}", isBusy ? "[BUSY]" : "[CLEAR]"));
        Console.ResetColor();
        Console.WriteLine("║");

        // 2. CONTROL MODE
        Console.Write("║  CONTROL MODE  : ");
        string modeStr = isAutoMode ? "[AUTO]" : "[MANUAL]";
        if (isBusy)
        {
            Console.ForegroundColor = ConsoleColor.Gray;
            Console.Write(string.Format("{0,-8} (LOCKED)", modeStr));
            Console.ResetColor();
            Console.Write(string.Format("{0,15}", ""));
        }
        else
        {
            Console.ForegroundColor = isAutoMode ? ConsoleColor.Cyan : ConsoleColor.Yellow;
            Console.Write(string.Format("{0,-32}", modeStr));
        }
        Console.ResetColor();
        Console.WriteLine("║");

        Console.WriteLine("╠══════════════════════════════════════════════════╣");
        Console.WriteLine(string.Format("║  ACCOUNT     : {0,-33} ║", account));
        Console.WriteLine(string.Format("║  DYO PATH    : {0,-33} ║", TruncatePath(dyoPath, 33)));
        Console.WriteLine(string.Format("║  FILE SIZE   : {0,-33} ║", currentSize.ToString("N0") + " bytes"));

        // 3. LAST SIGNAL (Time + Detail 통합 표시)
        string signalDisplay = (lastSignalTime == "N/A") ? "N/A" : $"{lastSignalTime} ({lastSignalDetail})";
        Console.WriteLine(string.Format("║  LAST SIGNAL : {0,-33} ║", signalDisplay));

        Console.WriteLine("╟──────────────────────────────────────────────────╢");
        Console.WriteLine("║ [M] Toggle Mode (Only in CLEAR status)           ║");
        Console.WriteLine(string.Format("║ Current Time : {0,-33} ║", DateTime.Now.ToString("HH:mm:ss")));
        Console.WriteLine("╚══════════════════════════════════════════════════╝");
    }

    private static string TruncatePath(string path, int maxLength)
    {
        if (path.Length <= maxLength) return path;
        return "..." + path.Substring(path.Length - (maxLength - 3));
    }
}