# Weekly Fuel Surcharge Automation Guide

## Overview
Cathy collects weekly fuel surcharge rates every **Monday** and **Tuesday** into a consolidated table ([Fuel_Surcharge_Report.html](file:///home/krithika/workspace/Fuel/Fuel_Surcharge_Report.html)).

## 1. Monday Fuel Sources (Ready Every Monday at 9:00 AM PST or on demand)
1. **Oceanex** (`https://www.oceanex.com/forms-references/fuel-surcharge/`)
   - **Field Required:** Effective Week + **Full Load TL2 (10,000 – 54,999 lbs)** rate (e.g., `118.1%`).
   - **Direct JSON API (bypasses Cloudflare 403!):** `POST https://ws.oceanex.com/ws/website/fuel-surcharge/list` with `{"nbOfWeeks":4}` -> `.results[-1].label` & `.results[-1].tl2`.
   - **Dedicated Folder & 1-Click Tool:** [/home/krithika/workspace/Oceanex](file:///home/krithika/workspace/Oceanex/) (Linux: `run-oceanexfuel.sh` / `get_oceanex_fuel.py`, Windows: `Run-OceanexFuel.bat` / `Get-OceanexFuel.ps1`).
2. **CN Rail** (`https://www.cn.ca/en/customer-centre/prices-tariffs-transit-times/fuel-surcharge`)
   - **CN 7404 (Weekly Intermodal):** Effective Week, **Avg. Weekly OHD Price** (e.g., `$6.127`), and **Intra-Canada** rate only (e.g., `39.26%`).
   - **CN 7405 (Monthly Intermodal):** Effective Month, **Avg. OHD Price**, and **Intra-Canada Monthly rate** only.
3. **Bison Transport** (`https://img.bisontransport.com/public/resources/pdf/documents/bison_transport/1033-canada_crossborder_domestic_fuel_surcharge.pdf`)
   - **Field Required:** **Intermodal (Within Canada)** only (e.g., `42.04%`).

## 2. Tuesday Fuel Source (Ready Every Tuesday after Kalibrate updates)
4. **Kalibrate – Canada Fuel** (`https://charting.kalibrate.com/#dataAnalytics`)
   - **Selection:** `Diesel` -> `Retail` -> `Weekly` -> `2026` -> `Excel`
   - **Direct Excel URL:** `https://charting.kalibrate.com/WPPS/Diesel/Retail%20(Incl.%20Tax)/WEEKLY/2026/Diesel_Retail%20(Incl.%20Tax)_WEEKLY_2026.xlsx`
   - **Helper Script (Linux):** `python3 /home/krithika/workspace/Fuel/get_kalibrate_canada_ave.py`
   - **Helper Script (Windows):** `powershell -ExecutionPolicy Bypass -File Get-KalibrateCanadaAveV.ps1`
   - **Field Required:** Latest Tuesday week column (e.g., `11/10`) for **Row 81: `Canada Ave(V)`** toward the bottom of the sheet (e.g., `253.3`).
