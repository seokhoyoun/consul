using NinjaTrader.Client;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;

internal class Program
{
    private static void Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;

        // 1. Setup File Paths
        string instrumentPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "instrument.txt");
        string accountPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "account.txt");
        string statusFilePath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "status.txt");

        List<string> instruments = new List<string>();
        string account = "";

        // Hide the blinking cursor to reduce visual noise
        Console.CursorVisible = false;

        // --- Initial Setup Logic ---
        try
        {
            if (File.Exists(instrumentPath))
            {
                instruments = File.ReadAllLines(instrumentPath)
                                  .Where(line => !string.IsNullOrWhiteSpace(line))
                                  .Select(line => line.Trim())
                                  .ToList();
            }

            if (instruments.Count == 0)
            {
                Console.WriteLine("[SETUP] 'instrument.txt' not found. Enter Instruments (e.g., MES MAR26): ");
                string input = Console.ReadLine();
                if (!string.IsNullOrWhiteSpace(input))
                {
                    instruments = input.Split(',').Select(s => s.Trim()).ToList();
                    File.WriteAllLines(instrumentPath, instruments);
                }
                else return;
            }

            if (File.Exists(accountPath)) account = File.ReadAllText(accountPath).Trim();
            if (string.IsNullOrEmpty(account))
            {
                Console.WriteLine("[SETUP] 'account.txt' not found. Enter Account Name: ");
                account = Console.ReadLine()?.Trim();
                if (!string.IsNullOrEmpty(account)) File.WriteAllText(accountPath, account);
                else return;
            }
        }
        catch (Exception ex) { Console.WriteLine($"[BOOT ERROR] {ex.Message}"); return; }

        Client ntClient = new Client();
        if (ntClient.Connected(0) != 0)
        {
            Console.WriteLine("[CONNECTION ERROR] Ensure NT8 is running.");
            Thread.Sleep(3000);
            return;
        }

        // --- Main Monitoring Loop ---
        while (true)
        {
            try
            {
                bool isSystemBusy = false;
                List<string> posLines = new List<string>();
                List<string> orderLines = new List<string>();

                // Fetch data from NT8
                string rawOrders = ntClient.Orders(account);
                if (!string.IsNullOrEmpty(rawOrders))
                {
                    string[] ids = rawOrders.Split(new[] { '|' }, StringSplitOptions.RemoveEmptyEntries);
                    foreach (var id in ids)
                    {
                        string oStatus = ntClient.OrderStatus(id);
                        if (oStatus.Equals("Working", StringComparison.OrdinalIgnoreCase)) isSystemBusy = true;
                        orderLines.Add(string.Format(" ID: {0,-15} | Status: {1,-12}", id, oStatus));
                    }
                }

                foreach (var inst in instruments)
                {
                    int pos = ntClient.MarketPosition(inst, account);
                    if (pos != 0) isSystemBusy = true;
                    posLines.Add(string.Format(" {0,-15} | Position: {1,4}", inst, pos));
                }

                string filterStatus = isSystemBusy ? "BUSY " : "CLEAR"; // Extra space to clear old chars

                // --- Flicker-Free UI Update ---
                // Instead of Console.Clear(), move the cursor to the top-left
                Console.SetCursorPosition(0, 0);

                Console.WriteLine("╔══════════════════════════════════════════════════╗");
                Console.WriteLine("║           NINJATRADER API STATUS HELPER          ║");
                Console.WriteLine("╠══════════════════════════════════════════════════╣");
                Console.WriteLine(string.Format("║  SYSTEM FILTER STATUS :  {0,-23} ║", filterStatus));
                Console.WriteLine("╠══════════════════════════════════════════════════╣");
                Console.WriteLine(string.Format("║  ACCOUNT: {0,-38} ║", account));
                Console.WriteLine("╟──────────────────────────────────────────────────╢");
                Console.WriteLine("║ [INSTRUMENT POSITIONS]                           ║");
                foreach (var line in posLines) Console.WriteLine(string.Format("║ {0,-48} ║", line));
                Console.WriteLine("╟──────────────────────────────────────────────────╢");
                Console.WriteLine("║ [ACTIVE ORDER LIST]                              ║");

                // Print a fixed number of rows to avoid leftover text
                int maxOrders = 5;
                for (int i = 0; i < maxOrders; i++)
                {
                    string line = (i < orderLines.Count) ? orderLines[i] : " ".PadRight(48);
                    Console.WriteLine(string.Format("║ {0,-48} ║", line));
                }

                Console.WriteLine("╟──────────────────────────────────────────────────╢");
                Console.WriteLine(string.Format("║  Last Update: {0,-34} ║", DateTime.Now.ToString("HH:mm:ss")));
                Console.WriteLine("╚══════════════════════════════════════════════════╝");

                File.WriteAllText(statusFilePath, filterStatus.Trim());
                Thread.Sleep(500);
            }
            catch (Exception ex)
            {
                Console.SetCursorPosition(0, 20); // Move error log to bottom
                Console.WriteLine($"[RUNTIME ERROR] {ex.Message} ".PadRight(50));
                Thread.Sleep(2000);
            }
        }
    }
}