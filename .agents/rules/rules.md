# Project Rules & AI Agent Operational Guidelines (`Fuel`)

## 0. Cathy's Permanent Fuel Surcharge Rules (Applies to Antigravity & Qwen!)

1. **Whenever Cathy says `"monday fuel"` or `"fuel"`**:
   - Read `FUEL_AUTOMATION_GUIDE.md` and `Fuel_Surcharge_Report.html`.
   - Pull the latest weekly rates from:
     a) **Oceanex** (`https://ws.oceanex.com/ws/website/fuel-surcharge/list` POST JSON `{"nbOfWeeks":4}` -> Effective Week & Full Load TL2 10,000-54,999 lbs rate).
     b) **CN 7404 & CN 7405** (`https://www.cn.ca/en/customer-centre/prices-tariffs-transit-times/fuel-surcharge` -> Effective Date/Month, Avg. OHD Price, and Intra-Canada rate only).
     c) **Bison Transport** (`https://img.bisontransport.com/public/resources/pdf/documents/bison_transport/1033-canada_crossborder_domestic_fuel_surcharge.pdf` -> Intermodal Within Canada rate only).
   - Update `Fuel_Surcharge_Report.html` and display the clean consolidated table in chat.

2. **Whenever Cathy says `"tuesday fuel"` or `"Kalibrate"`**:
   - Run/fetch Kalibrate Weekly Retail Diesel (`https://charting.kalibrate.com/WPPS/Diesel/Retail%20(Incl.%20Tax)/WEEKLY/2026/Diesel_Retail%20(Incl.%20Tax)_WEEKLY_2026.xlsx`, or `python3 /home/krithika/workspace/Fuel/get_kalibrate_canada_ave.py`), extract the latest Tuesday column for **Row 81 `Canada Ave(V)`**, and update `Fuel_Surcharge_Report.html`.

3. **Shared Qwen <-> Antigravity & Formatting Protocol**:
   - Always address the user as **`Cathy`**.
   - Read `QWEN.md` and `chats/SHARED_SESSION_STATE.md` first on mode switches (`use qwen` / `stop qwen`).
   - Use 100% plain English in Zed chat — **ZERO LaTeX (`$...$`)** (`->` instead of `\rightarrow`, and wrap `$` prices in backticks).

---

## 1. Repository Scope & Single-Repo Isolation
- **Project Root**: `/home/krithika/workspace/Fuel`
- **Primary Developer**: `Cathy` (`Krithika`)
- **Git Remote (`origin`)**: `https://github.com/cathynagarajan/Fuel.git` (Branch: `main`)
- **PostgreSQL `pgvector` Table**: `kg_vectors_fuel` (`192.168.1.155:30432` / database `vectordb`)
- **Single-Repo Mode (`single_repo_mode: true`)**: This repository is an independent project workspace.

---

## 2. Mandatory Pre-Task & Post-Task Knowledge Graph (`query_kg.py`) Workflow
1. **Single-Repo Commit & Push (Antigravity <-> Qwen Dual Sync)**:
   - On every commit, update `/home/krithika/workspace/Fuel/chats/SHARED_SESSION_STATE.md` and `Fuel_Surcharge_Report.html` first, then run:
     ```bash
     python3 /home/krithika/workspace/Fuel/knowledge_graph/query_kg.py --commit-push -m "Describe your change"
     ```
   - NEVER pass `--no-verify` to `git commit`.
