# QWEN.md — Mandatory Shared Instructions & Live State Sync (`Fuel`)

> **CRITICAL FOR QWEN & ANTIGRAVITY**: Whenever `use qwen` or `stop qwen` is triggered, you are continuing the **exact same Weekly Monday & Tuesday Fuel Surcharge automation session** with **Cathy**.
> **ALWAYS read `/home/krithika/workspace/Fuel/chats/SHARED_SESSION_STATE.md` and `/home/krithika/workspace/Fuel/FUEL_AUTOMATION_GUIDE.md` FIRST** before responding so you know the exact 4 Canadian/TL2 fuel surcharge rules (`Oceanex TL2`, `CN 7404 & 7405 Intra-Canada`, `Bison Intermodal Within Canada`, and `Kalibrate Tuesday Release Row 81 Canada Ave(V)`). **ALWAYS update `chats/SHARED_SESSION_STATE.md` + `Fuel_Surcharge_Report.html` + run `query_kg.py --commit-push`** whenever weekly fuel rates are pulled!

## 1. Communication Rules
- **Always address the user as `Cathy`**.
- **100% Plain English — ZERO LaTeX (`$...$`) in Zed chat**:
  - Zed's chat panel does NOT render LaTeX (`\rightarrow`, `\le`); use plain keyboard characters (`->`, `at most`) and never wrap two `$` currency signs on the same line without code ticks.

## 2. Weekly Monday & Tuesday Fuel Surcharge Rules
1. **Monday Fuel (`monday fuel` trigger)**:
   - **Oceanex**: Effective Week + **Full Load TL2 (10,000 – 54,999 lbs)** rate ONLY via `POST https://ws.oceanex.com/ws/website/fuel-surcharge/list` (`{"nbOfWeeks":4}` -> `.results[-1].label` & `.results[-1].tl2`), or `/home/krithika/workspace/Oceanex/run-oceanexfuel.sh`.
   - **CN 7404 (Weekly Intermodal)**: Effective Week + **Avg. Weekly OHD Price** + **Intra-Canada** rate ONLY (`https://www.cn.ca/en/customer-centre/prices-tariffs-transit-times/fuel-surcharge`).
   - **CN 7405 (Monthly Intermodal)**: Current & Upcoming Effective Month + **Avg. OHD Price** + **Intra-Canada** rate ONLY.
   - **Bison Transport**: **Intermodal (Within Canada)** rate ONLY (`https://img.bisontransport.com/public/resources/pdf/documents/bison_transport/1033-canada_crossborder_domestic_fuel_surcharge.pdf`, saved locally to `Bison_FSC_Latest.pdf`).
2. **Tuesday Fuel (`tuesday fuel` / `kalibrate` trigger)**:
   - **Kalibrate – Canada Fuel**: `Diesel -> Retail (Incl. Tax) -> Weekly -> <Year>` (`python3 /home/krithika/workspace/Fuel/get_kalibrate_canada_ave.py` on Linux, or `Get-KalibrateCanadaAveV.ps1` on Windows).
   - Extract **Row 81: `Canada Ave(V)`** from the furthest-right (latest Tuesday) column in `c/L`.

## 3. Mandatory Knowledge Graph & Dual-Agent Sync
- Whenever weekly fuel rates or scripts are updated:
  1. Update `/home/krithika/workspace/Fuel/Fuel_Surcharge_Report.html` and `/home/krithika/workspace/Fuel/chats/SHARED_SESSION_STATE.md`.
  2. Run `python3 /home/krithika/workspace/Fuel/knowledge_graph/query_kg.py --commit-push -m "<message>"` (NEVER `--no-verify`) so `knowledge_graph.db` AND PostgreSQL `pgvector` (`kg_vectors_fuel`) stay 100% synchronized.
