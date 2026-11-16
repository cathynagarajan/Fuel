# QWEN.md — Mandatory Shared Instructions & Live State Sync (`Fuel`)

> **CRITICAL FOR QWEN & ANTIGRAVITY**: Whenever `use qwen` or `stop qwen` is triggered, you are continuing the **exact same Weekly Monday & Tuesday Fuel Surcharge automation session** with **Cathy**.
> **ALWAYS read `/home/krithika/workspace/Fuel/chats/SHARED_SESSION_STATE.md` and `/home/krithika/workspace/Fuel/FUEL_AUTOMATION_GUIDE.md` FIRST** before responding, and **ALWAYS update `chats/SHARED_SESSION_STATE.md` + `Fuel_Surcharge_Report.html` + run `query_kg.py --commit-push`** whenever weekly fuel rates are pulled!

## 1. Cathy's Permanent Fuel Surcharge Rules (NEVER VIOLATE!)
1. **Whenever Cathy says `"monday fuel"` or `"fuel"`**:
   - Read `FUEL_AUTOMATION_GUIDE.md` and `Fuel_Surcharge_Report.html`.
   - Pull the latest weekly rates from:
     a) **Oceanex** (`https://ws.oceanex.com/ws/website/fuel-surcharge/list` POST JSON `{"nbOfWeeks":4}` -> Effective Week & Full Load TL2 10,000-54,999 lbs rate).
     b) **CN 7404 & CN 7405** (`https://www.cn.ca/en/customer-centre/prices-tariffs-transit-times/fuel-surcharge` -> Effective Date/Month, Avg. OHD Price, and Intra-Canada rate only).
     c) **Bison Transport** (`https://img.bisontransport.com/public/resources/pdf/documents/bison_transport/1033-canada_crossborder_domestic_fuel_surcharge.pdf` -> Intermodal Within Canada rate only).
   - Update `Fuel_Surcharge_Report.html` and display the clean consolidated table in chat.

2. **Whenever Cathy says `"tuesday fuel"` or `"Kalibrate"`**:
   - Run/fetch Kalibrate Weekly Retail Diesel (`https://charting.kalibrate.com/WPPS/Diesel/Retail%20(Incl.%20Tax)/WEEKLY/2026/Diesel_Retail%20(Incl.%20Tax)_WEEKLY_2026.xlsx`, or `python3 /home/krithika/workspace/Fuel/get_kalibrate_canada_ave.py`), extract the latest Tuesday column for **Row 81 `Canada Ave(V)`**, and update `Fuel_Surcharge_Report.html`.

3. **Formatting Rule**:
   - Always address the user as **`Cathy`**, and use 100% plain English — **ZERO LaTeX (`$...$`)** in Zed chat (`->` instead of `\rightarrow`, and wrap `$` prices in backticks).
