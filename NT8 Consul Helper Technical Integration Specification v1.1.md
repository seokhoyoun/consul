## NT8 Consul Helper Technical Integration Specification v1.1

```mermaid
sequenceDiagram
    autonumber
    
    participant E as Ensign DYO
    participant DYO as DYO.txt (Cumulative)
    participant CH as Consul Helper (v1.1)
    participant NT8 as NinjaTrader 8
    participant STF as status.txt (Command Bridge)
    participant AHK as AHK (v1.6.2)

    Note over CH: Controller: Monitoring & Decision Logic

    rect rgb(255, 245, 245)
        Note over E, DYO: Step 1: Signal Detection
        E->>DYO: Append New Signal (Date, Time, Inst, Action)
        Note right of E: e.g., "01-06, 10:56:02, YMH26 Ninja SELL"
    end

    rect rgb(230, 240, 255)
        Note over CH, DYO: Step 2: Intelligent Parsing
        CH->>DYO: Detect File Size Change
        CH->>CH: Extract Instrument (YMH26) & Action (SELL)
    end

    rect rgb(240, 240, 255)
        Note over CH, NT8: Step 3: Mode & Status Verification
        CH->>CH: Check Internal Mode: Is it [AUTO]?
        
        alt Mode == AUTO
            CH->>NT8: Request Status (API Call)
            NT8-->>CH: Return Status (CLEAR or BUSY)
        else Mode == MANUAL
            Note right of CH: Signal logged but ignored (Manual Override)
        end
    end

    rect rgb(240, 255, 240)
        Note over CH, STF: Step 4: Command Transmission
        alt Mode == AUTO AND Status == CLEAR
            CH->>STF: Write Trade Command (e.g., "SELL, YMH26")
        else Status == BUSY
            Note right of CH: Safety Block: Active position exists
        end
    end

    rect rgb(255, 255, 230)
        Note over AHK, NT8: Step 5: Targeted Execution
        AHK->>STF: Read Command from Bridge
        AHK->>NT8: Activate "SuperDOM - YMH26"
        AHK->>NT8: Send Hotkey (F4 or F9)
        AHK->>STF: Clear Bridge (Reset)
    end
```

#### **Step 1. Signal Detection & File Monitoring**

The **Consul Helper** monitors the `C:\Ensign10\OutputLog\DYO.txt` file in real-time by tracking changes in file size. Unlike the previous polling method, the system remains idle until a new signal line is appended to the file, ensuring zero-latency detection with minimal resource consumption.

#### **Step 2. Intelligent Signal Parsing**

When a new signal is detected, the Consul Helper parses the raw data line (e.g., `01-06, 10:56:02, YMH26 Ninja SELL`). It extracts three vital components.

- **Timestamp**: To ensure the signal is current.
- **Instrument Code**: Specifically identifying the target (e.g., `YMH26`) for precise window targeting.
- **Trade Action**: Determining the direction (`BUY` or `SELL`).

#### **Step 3. Real-time Status & Mode Verification**

Immediately after parsing, the Helper verifies the system's readiness based on two conditions:

- **Safety Gate (NT8 Status)**: It queries the NinjaTrader 8 API to confirm if the status is **"CLEAR"** (no existing orders or positions).
- **Operation Mode**: It checks if the UI is set to **"AUTO"** mode. If set to **"MANUAL"**, the signal is ignored to allow for discretionary trading.

#### **Step 4: Command Transmission to AHK**

If both conditions are met (Status: CLEAR & Mode: AUTO), the Consul Helper translates the signal into a specific execution command. It writes this command (e.g., `BUY, YMH26`) to the `status.txt` file, which acts as the bridge to the AHK script.

#### **Step 5: Targeted Hotkey Execution (AHK)**

The **AHK script** reads the command from `status.txt` and performs the final execution:

- **Window Targeting**: It identifies and activates the exact NinjaTrader window matching the instrument (e.g., `SuperDOM - YMH26`).
- **Hotkey Trigger**: It sends the corresponding hotkey (**F4** for Buy, **F9** for Sell) directly to the target window to enter the market.