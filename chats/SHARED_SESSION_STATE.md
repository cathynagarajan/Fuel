# Shared Antigravity <-> Qwen Live Session State (`Fuel`)

> **Purpose**: Single source of truth shared between **Antigravity** and **Qwen** (`QWEN.md` + `rules.md` + `kg_vectors_fuel`). Both agents MUST read this file first and update it whenever pulling weekly fuel surcharges so mode switches (`use qwen` / `stop qwen`) never lose context.

- **Developer Preferred Name**: **Cathy**
- **Last Synced**: `2026-11-16`

---

## 1. Latest Pulled Weekly Fuel Surcharge Rates (Week of Monday, November 16, 2026)

| Carrier / Source | Category | Effective Date | Avg. OHD Price | Rate / Price |
| :--- | :--- | :--- | :--- | :--- |
| **Oceanex** | Full Load TL2 (10,000 – 54,999 lbs) | November 16, 2026 | — | **`118.1%`** |
| **CN 7404** | Intra-Canada (Weekly Intermodal) | November 16, 2026 | **`$6.127`** | **`39.26%`** |
| **CN 7405** | Intra-Canada (Monthly Intermodal) | November 2026 | **`$6.291`** | **`40.64%`** |
| **CN 7405 (Upcoming)** | Intra-Canada (Monthly Intermodal) | December 2026 | **`$6.252`** | **`40.18%`** |
| **Bison Transport** | Intermodal (Within Canada) | November 16 – 30, 2026 | — | **`42.04%`** |
| **Kalibrate (Tuesday Release)** | Canada Ave(V) – Diesel Retail (Incl. Tax) | Releases Tue, Nov 17, 2026 *(Prior 11/10)* | — | *Pending Tue (`253.3 c/L` on `11/10`)* |

---

## 2. Exact Source Endpoints & Scripts
1. **Oceanex TL2 JSON API (Cloudflare-free)**:
   - `POST https://ws.oceanex.com/ws/website/fuel-surcharge/list` with JSON body `{"nbOfWeeks":4}` -> `.results[-1].label` and `.results[-1].tl2`.
   - Companion Linux launcher: `/home/krithika/workspace/Oceanex/run-oceanexfuel.sh` (`get_oceanex_fuel.py`).
2. **CN 7404 & CN 7405 Intra-Canada**:
   - `https://www.cn.ca/en/customer-centre/prices-tariffs-transit-times/fuel-surcharge` (extract ONLY **Intra-Canada** and **Avg. OHD Price**; exclude US/Cross-Border/Carload).
3. **Bison Transport Intermodal (Within Canada)**:
   - PDF URL: `https://img.bisontransport.com/public/resources/pdf/documents/bison_transport/1033-canada_crossborder_domestic_fuel_surcharge.pdf` -> saved locally to `/home/krithika/workspace/Fuel/Bison_FSC_Latest.pdf` (extract ONLY **Intermodal (Within Canada)**).
4. **Kalibrate Tuesday Release (`Row 81: Canada Ave(V)`)**:
   - Direct Excel URL: `https://charting.kalibrate.com/WPPS/Diesel/Retail%20(Incl.%20Tax)/WEEKLY/2026/Diesel_Retail%20(Incl.%20Tax)_WEEKLY_2026.xlsx`
   - Linux script: `python3 /home/krithika/workspace/Fuel/get_kalibrate_canada_ave.py`
   - Windows script: `powershell -ExecutionPolicy Bypass -File /home/krithika/workspace/Fuel/Get-KalibrateCanadaAveV.ps1`
   - HTML Report output: `/home/krithika/workspace/Fuel/Fuel_Surcharge_Report.html`
