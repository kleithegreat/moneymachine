# Research Agenda & Strategy Pods (`docs/future-work.md`)

`moneymachine` is structured as an open, multi-modal quantitative experimentation platform anchored by the causal data fabric (`fabric/`) and verified execution subprojects (`kernel2/`). Rather than writing off broad asset classes or data modalities a priori, every hypothesis gets a dedicated pod, clean PIT inputs, and honest out-of-sample grading.

## 5 Exploratory Strategy Pods

### Pod A — Cross-Asset Macro Vintage & Revision Alpha
- **Hypotheses:** Real-time economic surprise and revision velocity ($\Delta_t^{\text{rev}}$ between `ORIGINAL` and `RESTATED` vintages in FRED/ALFRED, BLS, Treasury auctions, and BIS liquidity series) create systematic drifts across sovereign yields, FX pairs, gold, and crypto beta.
- **Fabric Inputs:** `macro_datalayer` (`core.fact_observations` + `revision_diff_observations`), macro announcement calendars (`SCHED`), GDELT policy event velocity.
- **Evaluation:** `bitemporal_asof_join` pairing macro vintage arrivals with high-frequency price reactions; out-of-sample IR and drawdowns net of realistic spreads.

### Pod B — Biotech Regulatory & Clinical Trial Catalyst Graph
- **Hypotheses:** Changes between successive ClinicalTrials.gov v2 snapshots (`snapshot_diff` across recruitment status, target enrollment, primary completion dates, site additions/removals) combined with SEC Form 8-K/10-K risk-factor redlines anticipate regulatory approvals, delays, or buyout catalysts better than market consensus.
- **Fabric Inputs:** `clinicaltrials_v2`, `sec_edgar`, OpenFDA adverse-event surges, company-to-compound entity graph $G(t)$ (`core.pit_edges`), and implied odds in `fact_expectations`.
- **Evaluation:** Entity-blinded agent reasoning (`BLINDED_ENTITIES` mode) scored on `ForecastLedger` against crowd baselines (`brier_skill_vs_crowd`).

### Pod C — Supply-Chain & Geospatial Chokepoint Nowcasting
- **Hypotheses:** Physical constraints—maritime rerouting around Suez/Panama, port dwell anomalies, refinery weather/temperature spikes, grid load stress, and TSMC/semiconductor supplier concentration disclosed in filings—propagate with measurable lag into sector earnings revisions and commodity crack/time spreads.
- **Fabric Inputs:** `core.pit_edges` multi-hop supply dependency graph, `sample_spatial_tensor` environmental/shipping summaries, SEC 10-K/20-F customer-concentration redlines.
- **Evaluation:** Sector relative-value baskets and event probabilities tracked on the prospective ledger.

### Pod D — Information-Flow & Prediction-Market Calibration
- **Hypotheses:** Prediction market CLOBs (Polymarket/Kalshi/Manifold) under-react or over-extrapolate slowly diffusing primary-source evidence (dockets, trial amendments, central-bank minutes, legislative markups) and exhibit exploitable term-structure/liquidity skew.
- **Fabric Inputs:** `polymarket_clob` (`temporal_polarity = 'FCST'` stored strictly separately in `core.fact_expectations`) paired with `PitSearchIndex` primary documents (`OBS`).
- **Evaluation:** Proper scoring rules (`mean_brier`, `mean_log_loss`, `brier_skill_vs_crowd` vs `crowd_baseline`) and calibration curves across horizon buckets.

### Pod E — Microstructure & Cross-Venue Funding / Liquidity Regimes
- **Hypotheses:** Order-book imbalance, liquidity replenishment decay, cross-venue perp funding dispersion, and macro volatility shocks define conditional regimes where execution edge or basis carry outweighs conservative fill/fee drag.
- **Fabric Inputs:** `hyperliquid_ws` (`fabric/adapters/hyperliquid_bridge.py`) + macro regime flags joined causally via `bitemporal_asof_join`.
- **Evaluation:** Graduated through [`fabric/adapters/kernel2_pod.py`](../fabric/adapters/kernel2_pod.py) into `subprojects/confirmation-wall/kernel2` verified A18 Bar Markets (pessimistic fill + fee + staleness accounting). See also [`pods/README.md`](../pods/README.md).

## Cross-Cutting Agentic Research Questions

1. **Blinding Sensitivity:** Does `BLINDED_ENTITIES` mode degrade agent accuracy (revealing ticker memorization/contamination) or preserve alpha (indicating genuine causal document/series reasoning)?
2. **Dynamic Graph Weighting ($G(t)$):** How should `rel_entity_edge.confidence` decay across restatements and stale disclosures?
3. **Structured Diff Compression:** Which filing/trial diff representations give highest signal-to-token efficiency for agentic MCP loops (`diff_document_versions`)?
4. **Ensemble Aggregation & Meta-Calibration:** How should independent Pod A–E forecasts be combined and recalibrated online using historical `ForecastLedger` Brier residuals?

## Verified Execution Subproject (`subprojects/confirmation-wall`)

The Lean-verified A18 Bar Market kernel ([`subprojects/confirmation-wall/kernel2/KERNEL.md`](../subprojects/confirmation-wall/kernel2/KERNEL.md)) and completed intraday confirmation-wall baseline ([`docs/findings.md`](findings.md), [`docs/whitepaper.pdf`](whitepaper.pdf)) remain active as the **execution & statistical verification layer** inside the broader platform. Any strategy generated by Pods A–E that expresses risk via discrete asset bars plugs directly into `kernel2` through `export_kernel2_bar_market`.

## Known Pitfalls & Structural Fabric Defenses

| Classical Pitfall | Fabric Defense |
| --- | --- |
| Revised-data look-ahead | Separate `event_time` from `known_at`; mandatory `known_at <= as_of` in `core.pit_latest` and `PitSearchIndex` |
| Resurrecting retracted points | `row_number() OVER (...)` ranks revisions BEFORE filtering `revision_state <> 'RETRACTED'` |
| `OBS` vs `FCST` label bleed | `polarity` constraint blocks `known_at < event_time` on `OBS` and separates forecasts into `fact_expectations` |
| Backtest name memorization | Salted HMAC `EntityBlinder` masks IDs, aliases, extra terms, and calendar dates |
| Multiple testing / post-hoc editing | Trigger-locked, SHA-256 hash-chained SQLite `ForecastLedger` + append-only `audit/` logs |
