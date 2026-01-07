## NT8 Consul Helper Technical Integration Specification v1.0

```mermaid
sequenceDiagram
    autonumber
    
    participant E as Ensign DYO
    participant SF as signal.txt (ASCII Trigger)
    participant AHK as AHK
    participant STF as status.txt (Safety Gate)
    participant CH as Consul Helper
    participant NT8 as NinjaTrader 8 (SuperDOM)

    Note over CH: Main Safety Controller (Status: CLEAR or BUSY)

    rect rgb(230, 240, 255)
        Note over CH, STF: Status Update Loop 
        CH->>STF: Update Status (CLEAR or BUSY)
    end

    rect rgb(255, 245, 245)
        Note over E, SF: Signal Detection
        alt Row G paints UP Arrow
            E->>SF: Write "BUY" to signal.txt
        else Row H paints DOWN Arrow
            E->>SF: Write "SELL" to signal.txt
        end
    end

    rect rgb(240, 255, 240)
        Note over AHK: Decision & Execution
        AHK->>SF: 1. Detect signal.txt and Read Content
        AHK->>STF: 2. Confirm if Status is "CLEAR"
        
        alt Status == "CLEAR"
            Note right of AHK: [PROCEED]
            alt Content == "BUY"
                AHK->>NT8: 3. Send F4 (Buy Order)
            else Content == "SELL"
                AHK->>NT8: 3. Send F9 (Sell Order)
            end
            AHK->>SF: 4. Delete signal.txt (Reset)
        else Status == "BUSY"
            Note right of AHK: [BLOCK/SKIP]
            AHK->>SF: 4. Delete signal.txt immediately
            Note over AHK, SF: Signal ignored to prevent duplication
        end
    end
```

#### **Step 1 Detect and Parse the Signal File**

The system monitors for the `signal.txt` file from Ensign. When an arrow paints, it reads the ASCII text (`BUY` or `SELL`) to determine the trade direction.

#### **Step 2 Verify the Safety Gate Status**

The AHK checks the `status.txt` file, which my **Consul Helper** refreshes every **100ms**. This step is the "Filter" that checks for any existing working orders in NinjaTrader.

#### **Step 3 Execution or Block**

- **If Status is CLEAR:** The system immediately sends the **F4** or **F9** hot-key to your NT8 SuperDOM to enter the trade.
- **If Status is BUSY:** The system recognizes that you already have a working order or position. To follow your "one position at a time" rule, it **Blocks** the execution and moves directly to Step 4.

#### **Step 4 Delete the Signal File (The Reset)**

Whether the trade was executed or blocked, the `signal.txt` file is **deleted immediately**. By deleting the file during a BUSY state, we effectively "Skip" that signal. This ensures that a new signal from Ensign does not sit waiting and accidentally trigger an order later when the previous trade closes.