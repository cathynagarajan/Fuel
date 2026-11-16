# Project Rules & AI Agent Operational Guidelines (`Fuel`)

## 0. Mandatory Shared Fuel Protocol for Qwen & Antigravity
1. **Always Address the User as `Cathy`**.
2. **Read `QWEN.md`, `chats/SHARED_SESSION_STATE.md`, & `FUEL_AUTOMATION_GUIDE.md` First**:
   - Whenever `use qwen` or `stop qwen` is triggered, read `/home/krithika/workspace/Fuel/QWEN.md` and `/home/krithika/workspace/Fuel/chats/SHARED_SESSION_STATE.md` immediately so you pull the exact 4 Canadian/TL2 fuel surcharge fields (`Oceanex Full Load TL2`, `CN 7404 & 7405 Intra-Canada`, `Bison Intermodal Within Canada`, and `Kalibrate Row 81 Canada Ave(V)`).
3. **Plain English Only — ZERO LaTeX (`$...$`) in Zed Chat**:
   - Never use LaTeX math (`\rightarrow`, `\le`) in chat responses; use plain keyboard arrows (`->`) and backtick `$` amounts so Zed never interprets two `$` signs as math.

---

## 1. Repository Scope & Single-Repo Isolation
- **Project Root**: `/home/krithika/workspace/Fuel`
- **Primary Developer**: `Cathy` (`Krithika`)
- **Git Remote (`origin`)**: `https://github.com/cathynagarajan/Fuel.git` (Branch: `main`)
- **PostgreSQL `pgvector` Table**: `kg_vectors_fuel` (`192.168.1.155:30432` / database `vectordb`)
- **Single-Repo Mode (`single_repo_mode: true`)**: This repository is an independent project workspace.

---

## 2. Mandatory Pre-Task & Post-Task Knowledge Graph (`query_kg.py`) Workflow
1. **Query Knowledge Graph First (`repo="fuel"` REQUIRED!)**:
   - Always pass `repo="fuel"` when calling `kg_rag_query`:
     ```bash
     python3 /home/krithika/workspace/Fuel/knowledge_graph/query_kg.py --search "<symbol_or_topic>"
     ```
2. **Single-Repo Commit & Push (Antigravity <-> Qwen Dual Sync)**:
   - On every commit, update `/home/krithika/workspace/Fuel/chats/SHARED_SESSION_STATE.md` and `Fuel_Surcharge_Report.html` first, then run:
     ```bash
     python3 /home/krithika/workspace/Fuel/knowledge_graph/query_kg.py --commit-push -m "Describe your change"
     ```
   - NEVER pass `--no-verify` to `git commit`.

---

## 3. Shared 5-Node Cluster GPU Pool (`use-gpu`) & MCP Services
- **Cluster GraphRAG MCP Server (`cluster-graphrag`)** — **ALWAYS pass `repo: "fuel"`**:
  - `kg_rag_query`, `kg_rag_upsert`, `kg_gpu_pool_status`, `kg_webhook_sync`, `kg_pii_guardrail_scan`
