# Agentic Strategy Pods (`pods/`)

Strategy Pods are isolated quantitative research workspaces mounted over a scoped, point-in-time view (`PodView`) of the unified Data Fabric (`fabric/`).

## How a Pod Operates

1. **Mount a Scoped Read View (`fabric/views.py`):**
   - Configure `PodView(pod_id=..., allowed_sources=..., allowed_licenses=..., min_confidence=..., min_quality=..., blinding_mode=..., blind_salt=...)`.
   - Use `blinding_mode="NONE"` during exploratory hypotheses and `blinding_mode="BLINDED_ENTITIES"` to test whether an agent reasons from causal fundamentals/filings rather than memorized ticker names or calendar dates.
2. **Connect via the Causal MCP Server (`fabric/mcp_server.py`):**
   - Launch `python -m fabric --root data/fabric mcp --pod-id <name> --as-of <iso> --blinding <mode>` (or instantiate `CausalFabricService` directly in Python scripts/notebooks).
   - Six causal tools are exposed: `resolve_entity`, `query_pit_series`, `search_documents`, `diff_document_versions`, `sample_spatial_tensor`, and `register_prospective_forecast`.
3. **Score Prospective Forecasts (`fabric/ledger.py`):**
   - Predictions and evidence hashes are appended to the SQLite `ForecastLedger` (protected by `BEFORE UPDATE`/`BEFORE DELETE` triggers and SHA-256 hash chaining) and scored out-of-sample by `mean_brier`, `mean_log_loss`, and `brier_skill_vs_crowd`.
4. **Graduate Execution Strategies (`fabric/adapters/kernel2_pod.py`):**
   - Systematic or bar-executable strategies graduate via `export_kernel2_bar_market(...)` into [`../subprojects/confirmation-wall/kernel2/`](../subprojects/confirmation-wall/kernel2/KERNEL.md) for verified A18 fill/fee/funding replay.

See [`../docs/future-work.md`](../docs/future-work.md) for the five initial exploratory research pods (Pods A–E).
