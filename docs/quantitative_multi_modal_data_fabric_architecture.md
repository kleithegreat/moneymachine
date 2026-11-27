# Architecture Specification: Composable Multi-Modal Quantitative Data Fabric

## 1. Executive Summary & Core Invariants

This document specifies an open-source, extensible, bitemporal **Data Fabric** designed to sit beneath multiple autonomous AI-agent quantitative strategy pods (e.g., biotech trial forensics, macro/event-driven research, on-chain perpetuals, and physical supply-chain analysis) while operating cleanly on near-zero local compute and storage.

Rather than copying the legacy hedge-fund model of mirroring petabytes of raw vendor feeds into monolithic clusters, this architecture relies on **metadata-first cataloging, zero-copy cloud virtualization, immutable content-addressable provenance, and strict causal isolation**.

### The Six Non-Negotiable Invariants
1. **Strict Causal Bitemporality:** Every observation, document, entity link, and market quote carries both an *event/valid time* and an immutable *knowledge/assertion time*. No query executed at simulated decision time $t$ may observe any byte whose knowledge timestamp exceeds $t$.
2. **Immutable Provenance (CAS-First):** Raw ingested payloads (XBRL filings, API JSON, trial records, binary order-book packets) are written once to Content-Addressable Storage (CAS) keyed by cryptographic hash. All downstream tables retain hash pointers so any AI-agent claim can be traced to exact source bytes.
3. **Zero-Copy Virtualization by Default:** Massive scientific and archival datasets (weather reanalyses, satellite imagery, historical tick archives) are never bulk-copied to local disk; they are mounted as remote byte-range virtual datasets and sliced on demand.
4. **Canonical, Time-Bounded Entity Identity:** Ticker symbols, drug names, wallet addresses, and aircraft tail numbers are mutable aliases, never primary keys. All cross-domain joins resolve through a versioned, confidence-weighted Entity Graph.
5. **First-Class Crowd Expectations:** Primary-source facts only generate alpha relative to what the market already prices. Market-implied beliefs (options skew, EV-to-cash, funding rates, prediction markets, forward curves) are modeled as a shared, standardized surface alongside fundamental observations.
6. **Shared Storage, Scoped Visibility:** Every source lives in one unified catalog, but strategy pods mount strictly declared, license-checked, causally bounded read-only views to prevent combinatorial false discovery, licensing violations, and LLM pretraining leakage.

---

## 2. Formal Mathematical Model

Formalizing the fabric's semantics prevents subtle backtesting bugs (look-ahead bias, survivorship bias, revision leakage, and entity-mapping drift) from silently corrupting agent research.

### 2.1 Bitemporal Observation Space
Let $\mathcal{E}$ be the set of immutable canonical entity identifiers, $\mathcal{S}$ the set of registered data sources, and $\mathcal{T} \subset \mathbb{R}$ represent UTC timestamps at microsecond resolution. Every structured or semi-structured record in the fabric conforms to the generalized bitemporal tuple:

$$x = \left(e,\; s,\; [\tau_{\text{ev}}^{-}, \tau_{\text{ev}}^{+}],\; \tau_{\text{kn}},\; \kappa,\; v,\; \rho,\; h\right)$$

where:
* $e \in \mathcal{E}$ is the canonical entity (or entity pair for relational facts).
* $s \in \mathcal{S}$ is the source connector ID.
* $[\tau_{\text{ev}}^{-}, \tau_{\text{ev}}^{+}] \subset \mathcal{T}$ is the **valid/event time interval** (for instantaneous ticks or filings, $\tau_{\text{ev}}^{-} = \tau_{\text{ev}}^{+} = \tau_{\text{ev}}$).
* $\tau_{\text{kn}} \in \mathcal{T}$ is the **knowledge time** (the exact UTC instant the fact became publicly observable or was ingested live).
* $\kappa \in \{\text{OBS}, \text{FCST}, \text{SCHED}\}$ classifies temporal polarity:
  * **Retrospective Observation ($\text{OBS}$):** Strictly satisfies $\tau_{\text{kn}} \ge \tau_{\text{ev}}^{-}$ (e.g., trade print, quarterly revenue, satellite pass, court filing).
  * **Prospective Forecast / Schedule ($\text{FCST}, \text{SCHED}$):** Permits $\tau_{\text{kn}} < \tau_{\text{ev}}^{-}$ (e.g., NOAA 7-day weather forecast run, scheduled FDA PDUFA date, futures delivery expiry). Separating $\text{OBS}$ from $\text{FCST}$ prevents accidentally substituting ex-post weather reanalysis for ex-ante weather forecasts.
* $v \in \mathcal{V}_s$ is the typed payload (scalar, vector, binary `VARIANT`, `GEOMETRY`, or external tensor slice reference).
* $\rho = (q, \omega) \in [0, 1] \times \{\text{RAW}, \text{REVISED}, \text{RETRACTED}, \text{PROXY}\}$ encodes data-quality/confidence weight $q$ and revision state $\omega$.
* $h = \text{SHA256}(\text{raw\_bytes})$ is the cryptographic pointer into the immutable CAS landing zone.

### 2.2 Point-in-Time (PIT) Filtration & Revision Semantics
Let $\mathcal{D}$ denote the entire universe of recorded facts. At any historical or live decision instant $t \in \mathcal{T}$, the causally admissible information set (filtration) is:

$$\mathcal{F}_t = \{ x \in \mathcal{D} \mid \tau_{\text{kn}}(x) \le t \}$$

For restatable metrics (e.g., SEC financials, USDA WASDE crop estimates, ClinicalTrials.gov endpoints) indexed by key $k = (e, \text{metric}, \tau_{\text{ev}})$, the **Latest-Known-Vintage Operator** $\Pi_t$ returns the single most recent assertion observable at time $t$:

$$\Pi_t(k) = \arg\max_{x \in \mathcal{F}_t(k)} \tau_{\text{kn}}(x)$$

Critically, the fabric also exposes the **Revision-Diff Operator** $\Delta_t^{\text{rev}}(k)$, which compares consecutive vintages $x^{(j)}, x^{(j-1)} \in \mathcal{F}_t(k)$ sorted by $\tau_{\text{kn}}$. In domains like clinical trials and accounting, $\Delta_t^{\text{rev}}$ (e.g., a sponsor quietly weakening a primary endpoint or restating inventory) is frequently higher-signal than the level $\Pi_t(k)$ itself.

For joining two asynchronous series $A$ and $B$ at decision time $t$ with maximum staleness tolerance $\delta_{\max} > 0$, all cross-domain alignment uses **Bitemporal ASOF Join** semantics:

$$(A \bowtie_{\text{ASOF}, t, \delta_{\max}} B)(e, \tau) = \left(a,\; \arg\max_{\substack{b \in \mathcal{F}_t(B, e) \\ \tau - \delta_{\max} \le \tau_{\text{ev}}(b) \le \tau}} \tau_{\text{ev}}(b)\right)$$

### 2.3 Temporal Entity-Resolution Graph
Entity relationships evolve over time (M&A, ticker recycling, spinoffs, executive job changes, aircraft ownership transfers, protocol governance changes). The entity fabric is formalized as a labeled, bitemporal directed multigraph:

$$G(t) = \left(\mathcal{E},\; \mathcal{R}(t)\right)$$

where each directed edge $r \in \mathcal{R}$ is a tuple:

$$r = \left(u,\; v,\; \text{rel\_type},\; [\tau_{\text{start}}, \tau_{\text{end}}),\; \tau_{\text{kn}},\; c,\; h\right)$$

* $u, v \in \mathcal{E}$ are canonical nodes (e.g., `Company`, `Security`, `DrugTrial`, `Aircraft`, `Vessel`, `Facility`, `CryptoProtocol`, `GeoPolygon`).
* $c \in (0, 1]$ is the **linkage confidence**. Deterministic registry links (SEC CIK to Legal Entity Identifier) carry $c = 1.0$; heuristic links (a Delaware LLC holding shell mapped to a public CEO's jet) carry $c < 1.0$, allowing strategy pods to threshold linkage certainty explicitly.
* Active graph projection at time $t$: $\mathcal{R}(t) = \{ r \in \mathcal{R} \mid \tau_{\text{kn}}(r) \le t \;\land\; \tau_{\text{start}}(r) \le t < \tau_{\text{end}}(r) \}$.

### 2.4 Implied-Expectations Surface & Mispricing Functional
Let $Y_{t+H}(e)$ be a future outcome for entity $e$ over horizon $H$ (e.g., binary Phase 3 trial success, quarterly EPS surprise, 7-day perp return, or regional crop yield). Let $\mathcal{M}_t \subset \mathcal{F}_t$ denote the subset of market-clearing pricing instruments linked to $e$ via $G(t)$. The fabric materializes a standardized **Crowd Belief Operator** $\mathcal{B}_t(e, H)$ estimating $\mathbb{E}_{\text{crowd}}[Y_{t+H}(e) \mid \mathcal{M}_t]$ alongside a liquidity/precision weight $\lambda_t(e) \in [0, \infty)$ (e.g., order-book depth, option open interest, or market volume).

Every strategy pod $p$ operates on a scoped view $\mathcal{F}_t^{(p)} \subset \mathcal{F}_t$ and searches for durable divergence:

$$\text{Edge}_{p, t}(e, H) = \mathbb{E}_{p}\left[Y_{t+H}(e) \mid \mathcal{F}_t^{(p)}\right] - \mathbb{E}_{\text{crowd}}\left[Y_{t+H}(e) \mid \mathcal{M}_t\right]$$

weighted by execution friction $C_{\text{exec}}(e, t)$ (spread, borrow cost, funding carry, impact) and precision $\lambda_t(e)$.

### 2.5 Composable Pod Views & Pretraining Leakage Firewall
Each strategy pod $p$ is bound to a declarative **View Specification**:

$$V_p = \left(\mathcal{S}_p,\; \mathcal{L}_p,\; c_{\min, p},\; \beta_p\right)$$

* $\mathcal{S}_p \subset \mathcal{S}$: Explicit allowlist of permitted sources (enforcing domain discipline and bounding false-discovery search space).
* $\mathcal{L}_p$: Permitted license classes (e.g., a live trading pod restricts $\mathcal{L}_p \subseteq \{\text{PUBLIC\_DOMAIN}, \text{CC\_BY}, \text{COMMERCIAL}\}$, automatically blocking `NON_COMMERCIAL` feeds such as OpenSky free-tier ADS-B).
* $c_{\min, p} \in (0, 1]$: Minimum entity-resolution confidence threshold.
* $\beta_p \in \{\text{NONE}, \text{BLINDED\_ENTITIES}, \text{PROSPECTIVE\_ONLY}\}$: Anti-leakage mode for LLM agents. When evaluating an LLM whose pretraining cutoff is $t_{\text{LLM}}$, qualitative agent inference on historical data $t \le t_{\text{LLM}}$ either requires deterministic feature extraction (no LLM judgment in the loop) or `BLINDED_ENTITIES` masking (replacing names, tickers, dates, and molecule strings with salted pseudonyms). True unblinded LLM evaluation is permitted only for $t > t_{\text{LLM}}$ via a cryptographically signed prospective forecast log.

---

## 3. High-Level System Architecture & Open-Source Stack

The fabric is decomposed into six loosely coupled horizontal planes. Every component is open-source, runs locally on a single machine or $10/month VPS at Tier 0, and scales transparently to S3 + dedicated servers without rewriting queries or schemas.

```text
+======================================================================================+
| PLANE 5: CONSUMPTION & AGENT INTERFACE LAYER                                         |
|  [Read-Only MCP Server (as_of_utc enforced)]  [Arrow Flight SQL]  [OpenBB / Marimo]  |
+==========================================^===========================================+
                                           | (Causal Filtration & Pod View Firewall)
+==========================================v===========================================+
| PLANE 4: COMPOSABLE QUERY, TRANSFORM & GOVERNANCE ENGINE                             |
|  [DuckDB Federated Engine]  [SQLMesh PIT Transform DAGs]  [Blinding & License Proxy] |
+======================^===================^========================^==================+
                       |                   |                        |
+======================v===================v========================v==================+
| PLANE 3: CANONICAL SEMANTIC CORE                                                     |
|  [Temporal Entity Graph]  [PIT Corporate Actions]  [Unified Event Log]               |
|  [Implied-Expectations Surface]  [Document Diff & Provenance Index]                  |
+======================^===================^========================^==================+
                       |                   |                        |
+======================v===================v========================v==================+
| PLANE 2: MULTI-MODAL STORAGE LAKEHOUSE                                               |
|  +-----------------------+  +-----------------------+  +--------------------------+  |
|  | Tabular + Spatial     |  | Scientific Tensors    |  | Text & Semantic Index    |  |
|  | DuckLake 1.x          |  | Icechunk + Zarr v3    |  | SQLite FTS5 / Tantivy    |  |
|  | (SQLite/PG Catalog +  |  | (Zero-Copy Virtual    |  | (+ Optional LanceDB /    |  |
|  |  Parquet, Inlining,   |  |  Chunks over S3/GCS   |  |  pgvector linked by      |  |
|  |  VARIANT, GEOMETRY)   |  |  NetCDF/GRIB/COG)     |  |  doc_hash & known_at)    |  |
|  +-----------------------+  +-----------------------+  +--------------------------+  |
+======================^===================^========================^==================+
                       |
+======================v===============================================================+
| PLANE 1: IMMUTABLE RAW LANDING ZONE (Content-Addressable Storage - CAS)              |
|  [Zstd-Compressed Raw Blobs keyed by SHA-256 on Local Disk / Garage / Cloudflare R2] |
+======================^===============================================================+
                       |
+======================v===============================================================+
| PLANE 0: PLUGGABLE INGESTION & CONNECTOR RUNTIME                                     |
|  [Manifest-Driven Connectors (Python/Rust)] [WebSocket Recorders] [Diff Pollers]     |
|  [Arrow/Pydantic Schema Validators] [Dead-Letter Quarantine] [Rate/Budget Guard]     |
+======================================================================================+
```

### Core Open-Source Technology Selection

| Plane | Primary OSS Component | Why This Choice (Zero-Hardware + Extensibility) |
| :--- | :--- | :--- |
| **Catalog & Tabular Lakehouse** | **DuckLake 1.0/1.1** (MIT) over **Apache Parquet** | Stores metadata, ACID snapshots, and time-travel state in an ordinary SQL DB (DuckDB/SQLite locally; PostgreSQL multi-user). Native **Data Inlining** eliminates the small-file problem for live incremental trickles (perp funding, trial diffs). Native **Sorted Tables**, binary **`VARIANT`** (semi-structured payloads), and **`GEOMETRY`** (spatial bounding-box pruning for AIS/ADS-B/farms) collapse four specialized databases into one. |
| **Multidimensional Tensors** | **Icechunk** (Apache 2.0) + **Zarr v3** + **xarray** | Provides Git-like ACID snapshots, branches, and **Virtual Chunks**—allowing local repositories to reference remote ERA5/NOAA/Sentinel-2 byte ranges in AWS Open Data or GCS without copying terabytes locally. |
| **Federated Query Kernel** | **DuckDB** + **Polars** | In-process vectorized execution directly over DuckLake, remote S3 Parquet, local SQLite, and zero-copy Apache Arrow streams from `xarray`/Icechunk. Zero always-on cluster RAM overhead. |
| **Transformation & Lineage** | **SQLMesh** (Apache 2.0) | Virtual data environments, native incremental-by-time-range backfills, column-level lineage, and built-in unit-test audits for bitemporal SQL transforms. |
| **Text & Document Search** | **Tantivy** (Rust) or **SQLite FTS5** + **LanceDB** (optional) | Embedded, file-backed BM25 lexical search (critical for exact drug/ticker/clause lookups) paired optionally with disk-backed vector retrieval—always post-filtered by `known_at <= as_of_utc`. |
| **Object Storage (CAS)** | Local filesystem / **Cloudflare R2** / **Garage** (AGPLv3) | S3-compatible immutable storage with zero egress fees (R2) or lightweight self-hosted distributed storage (Garage). |
| **Ingestion & Orchestration** | **Python (`uv` + `httpx`/`polars`)** & **Rust (`tokio`)** + **Dagster** (or `systemd` timers at Tier 0) | Rust for long-running low-memory live WebSocket collectors (crypto books, AIS, ADS-B); Python for analytical/document connectors; Dagster for asset-centric scheduling and data-quality checks once scaled beyond simple cron. |
| **Transport & Agent Interface** | **Apache Arrow Flight SQL** + **MCP (Model Context Protocol)** | Zero-copy tabular transport to backtesters and strictly typed, causally parameterized read-only tool calls for AI agent pods. |

---

## 4. The Extensibility Core: Connector Contracts & Canonical Schemas

Extensibility requires that adding a 20th data source (e.g., European power grid auctions or Japanese clinical trials) never modifies core query or storage code. Every source enters the fabric through a declarative **Source Manifest** and conforms to a small set of canonical tables.

### 4.1 Declarative Source Manifest (`source_manifest.yaml`)
Every plugin ships a validated manifest registering its temporal semantics, license class, storage strategy, and entity-resolution hooks:

```yaml
source_id: "clinicaltrials_gov_v2"
domain: "biotech_clinical"
modality: "document_and_structured_diff"     # tabular | event_log | document | spatial_stream | tensor_virtual | l3_book
storage_tier: "local_hot_ducklake"           # local_hot_ducklake | local_cold_parquet | remote_virtual_icechunk | on_demand_ephemeral
temporal_semantics: "snapshot_diff"          # append_only | restatable_vintage | prospective_forecast | snapshot_diff
temporal_polarity: "OBS"                     # OBS | FCST | SCHED
license_class: "PUBLIC_DOMAIN"               # PUBLIC_DOMAIN | CC_BY | NON_COMMERCIAL | COMMERCIAL_API | RESTRICTED_INTERNAL
retroactive_history_start: "2000-02-29T00:00:00Z"
live_collection_start: "2026-11-22T00:00:00Z"
cadence: "daily"
entity_resolvers:
  - local_key: "lead_sponsor_name"
    target_node_type: "ORGANIZATION"
    resolver_pipeline: "gleif_sec_fuzzy_v1"
  - local_key: "nct_id"
    target_node_type: "CLINICAL_TRIAL"
    resolver_pipeline: "deterministic_nct"
quality_sla:
  max_freshness_lag_hours: 36
  require_raw_cas_hash: true
  reject_future_known_at: true
```

### 4.2 Canonical Core DDL (DuckLake 1.x / DuckDB SQL)

Five core schemas unify every modality in the fabric. DuckLake's `SORTED BY` accelerates point-in-time pruning, `VARIANT` absorbs heterogeneous source payloads without schema migrations, and `GEOMETRY` handles spatial geofencing natively.

```sql
-- 1. Canonical Entity Registry (Immutable Surrogate IDs)
CREATE TABLE core.dim_entity (
    entity_id       UUID,
    entity_type     VARCHAR,       -- 'ORGANIZATION','SECURITY','DRUG_TRIAL','AIRCRAFT','VESSEL','PROTOCOL','GEO_REGION'
    canonical_name  VARCHAR,
    external_ids    VARIANT,       -- {'figi': '...', 'lei': '...', 'cik': '...', 'nct_id': '...', 'icao24': '...'}
    created_at      TIMESTAMPTZ
);
ALTER TABLE core.dim_entity SET SORTED BY (entity_type, entity_id);

-- 2. Bitemporal Entity-Resolution Graph
CREATE TABLE core.rel_entity_edge (
    src_entity_id   UUID,
    dst_entity_id   UUID,
    rel_type        VARCHAR,       -- 'ISSUES_SECURITY','SPONSORS_TRIAL','OPERATES_AIRCRAFT','PROXIES_FOR','SUPPLIES_TO'
    valid_from      TIMESTAMPTZ,
    valid_to        TIMESTAMPTZ,   -- '9999-12-31T00:00:00Z' if currently active
    known_at        TIMESTAMPTZ,
    confidence      DOUBLE,        -- (0, 1]
    source_id       VARCHAR,
    raw_hash        VARCHAR
);
ALTER TABLE core.rel_entity_edge SET SORTED BY (src_entity_id, known_at, valid_from);

-- 3. Unified Bitemporal Observation & Event Envelope
CREATE TABLE core.fact_observations (
    entity_id       UUID,
    source_id       VARCHAR,
    metric_key      VARCHAR,       -- e.g., 'sec.cash_and_equivalents_usd', 'perp.funding_rate_8h', 'usda.corn_yield_bu_acre'
    polarity        VARCHAR,       -- 'OBS' | 'FCST' | 'SCHED'
    event_start     TIMESTAMPTZ,
    event_end       TIMESTAMPTZ,
    known_at        TIMESTAMPTZ,
    val_num         DOUBLE,        -- Nullable fast-path numeric scalar
    val_unit        VARCHAR,       -- Explicit ISO/SI unit ('USD', 'BPS', 'MM', 'PROB')
    val_payload     VARIANT,       -- Rich structured payload or diff delta
    geom            GEOMETRY,      -- Optional spatial footprint (port polygon, airport, crop county)
    quality_score   DOUBLE,        -- [0, 1]
    revision_state  VARCHAR,       -- 'RAW' | 'REVISED' | 'RETRACTED' | 'PROXY'
    license_class   VARCHAR,
    raw_hash        VARCHAR        -- SHA-256 pointer into CAS
);
ALTER TABLE core.fact_observations SET SORTED BY (metric_key, entity_id, known_at, event_end);

-- 4. Versioned Document & Diff Registry (Filings, Protocols, Dockets, News)
CREATE TABLE core.fact_documents (
    doc_id          UUID,
    entity_id       UUID,
    source_id       VARCHAR,
    doc_type        VARCHAR,       -- 'SEC_10K','SEC_8K','NCT_PROTOCOL','EARNINGS_TRANSCRIPT','COURT_DOCKET','NEWS_ARTICLE'
    version_seq     INTEGER,
    event_time      TIMESTAMPTZ,
    known_at        TIMESTAMPTZ,
    title           VARCHAR,
    cas_uri         VARCHAR,       -- e.g., 'r2://cas/sha256/ab/cd/...'
    raw_hash        VARCHAR,
    prev_hash       VARCHAR,       -- Enables deterministic version diffing
    diff_summary    VARIANT,       -- Structured field-level diff (e.g., changed primary endpoint text)
    license_class   VARCHAR
);
ALTER TABLE core.fact_documents SET SORTED BY (doc_type, entity_id, known_at);

-- 5. Standardized Implied-Expectations Surface
CREATE TABLE core.fact_expectations (
    entity_id       UUID,
    instrument_id   UUID,          -- Linked tradable contract (Equity, Option Chain, Perp, Polymarket Market)
    target_event    VARCHAR,       -- 'TRIAL_READOUT','MACRO_CPI','NEXT_8H_CARRY','M_AND_A_CLOSE'
    horizon_end     TIMESTAMPTZ,
    known_at        TIMESTAMPTZ,
    implied_mean    DOUBLE,        -- e.g., probability in [0,1], EV/Cash multiple, annualized funding, implied move
    implied_vol     DOUBLE,        -- Options IV or dispersion width
    liquidity_score DOUBLE,        -- Order-book depth / OI / volume weight
    source_id       VARCHAR,
    metadata        VARIANT,
    raw_hash        VARCHAR
);
ALTER TABLE core.fact_expectations SET SORTED BY (target_event, entity_id, known_at);
```

### 4.3 Reusable Bitemporal PIT Macro
Every downstream transform and agent tool routes through parameterized PIT macros rather than ad-hoc SQL filters, making look-ahead errors structurally difficult to introduce:

```sql
CREATE MACRO core.pit_latest(as_of_ts, allowed_sources, allowed_licenses, min_quality) AS TABLE
SELECT * EXCLUDE (rn)
FROM (
    SELECT
        *,
        row_number() OVER (
            PARTITION BY entity_id, metric_key, event_start, event_end
            ORDER BY known_at DESC
        ) AS rn
    FROM core.fact_observations
    WHERE known_at <= as_of_ts
      AND source_id IN (SELECT unnest(allowed_sources))
      AND license_class IN (SELECT unnest(allowed_licenses))
      AND quality_score >= min_quality
      AND revision_state <> 'RETRACTED'
)
WHERE rn = 1;
```

---

## 5. Comprehensive Source Integration Blueprint (All 13 Domains)

This section maps **every source discussed**—including structurally messy, legally restricted, or partially observable ones—onto the fabric's primitives without breaking zero-hardware constraints.

### 5.1 Market & Microstructure Domains

| # | Domain & Concrete Sources | Storage Tier & Format | Granularity & Ingestion Mode | Entity Linkage & Special Handling | Known Limitations & Fabric Safeguards |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **Equities, Futures & Options (OHLCV)**<br>Massive (flat S3/API), ThetaData (options), EODHD (global EOD) | `local_hot_ducklake`<br>(Parquet partitioned by `asset_class/year`) | **Daily OHLCV** (full universe incl. delisted: ~2–3 GB). **1-min OHLCV** stored selectively for active research universes. | OpenFIGI + CUSIP/ISIN $\rightarrow$ immutable `SECURITY` ID. **Store raw unadjusted prices + separate `fact_corp_actions` table** (splits, dividends, spinoffs, delisting returns) so PIT adjustments compute dynamically. | Survivorship bias is fatal; every vendor feed is audited against a delisting manifest (`quality_sla` rejects active-only dumps). |
| **2** | **Full CLOB / L3 MBO (Adds, Cancels, Fills)**<br>Databento (45 US equity venues, CME futures) | `on_demand_ephemeral`<br>(Raw DBN $\rightarrow$ cold Parquet cached per study) | Usage-based per-GB pulls for specific `(symbol, date_window)` event studies; evicted to cold storage or purged after feature extraction. | Mapped via exchange instrument ID + venue MIC to `SECURITY`. | **Dark-pool / ATS blind spot:** Off-exchange TRF prints are explicitly tagged `venue_type = 'OFF_EXCHANGE_TRF'` so microstructure models never confuse resting lit-book volume with total market flow. |
| **3** | **Spot FX, OTC Commodities & Corporate Bonds** *(Shaky / Fragmented)*<br>CME FX/Commodity Futures, FINRA TRACE, Sovereign yield curves, ETFs | `local_hot_ducklake` | Daily/hourly exchange-cleared proxy series + TRACE post-trade corporate bond prints. | Modeled via explicit **`PROXIES_FOR` edges** in `rel_entity_edge` (e.g., `CME_6E` $\rightarrow$ `SPOT_EURUSD`, `HYG/TRACE` $\rightarrow$ issuer credit spread) with `revision_state = 'PROXY'` and empirical tracking-error metadata. | No centralized OTC CLOB exists outside dealer networks/Bloomberg IB. Tagging every OTC price with `PROXY` and spread uncertainty prevents agents from assuming executable mid-market fills. |
| **4** | **On-Chain Activity & Crypto Perps**<br>Direct exchange WebSockets (Hyperliquid, Binance, Bybit, dYdX), RPC/Cryo/Allium/Dune exports | `local_hot_ducklake`<br>(DuckLake Data Inlining for live trickles $\rightarrow$ compacted Parquet) | **Recorded live forward:** 1-min/hourly candles, 8h/1h funding rates, open interest, mark/index basis, liquidation streams, and L2 top-of-book snapshots; daily/block-level stablecoin flows and whale wallet tags. | `PROTOCOL` $\leftrightarrow$ `TOKEN` $\leftrightarrow$ `PERP_CONTRACT` $\leftrightarrow$ `WALLET_CLUSTER` (probabilistic $c < 1.0$ for heuristically labeled whale/VC wallets). | Exchange APIs drop historical funding/OI/order-book depth silently. A lightweight Rust collector (`tokio`) writes raw frames to CAS continuously starting Day 0. |

### 5.2 Fundamental, Biomedical & Institutional Domains

| # | Domain & Concrete Sources | Storage Tier & Format | Granularity & Ingestion Mode | Entity Linkage & Special Handling | Known Limitations & Fabric Safeguards |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **5** | **Fundamentals, Filings & Gov Docs**<br>SEC EDGAR (bulk XBRL, 10-K/Q, 8-K, Form 4, 13F, S-1), EIA energy/grid data | CAS (raw HTML/XBRL/PDF) + `local_hot_ducklake` + Tantivy/FTS5 | Incremental RSS/API watcher on EDGAR submissions (`known_at` = exact SEC acceptance timestamp). XBRL tags normalized into canonical accounting lines while preserving original taxonomy tags in `VARIANT`. | Deterministic `SEC_CIK` $\leftrightarrow$ `GLEIF_LEI` $\leftrightarrow$ `ORGANIZATION`. 13F holdings explicitly carry `event_end` (quarter end) vs. `known_at` (filing date up to 45 days later). | XBRL taxonomy drift and restatements are handled natively by `fact_observations` vintages ($\Pi_t$) rather than overwriting historical quarters. |
| **6** | **Pharmaceuticals & Clinical Trials**<br>ClinicalTrials.gov API v2, Duke AACT daily snapshots, openFDA (Drugs@FDA, FAERS), PubMed / PMC / bioRxiv | CAS + `local_hot_ducklake` + Tantivy/FTS5 | Daily incremental sync of ClinicalTrials.gov v2 + AACT structural diffs; quarterly openFDA bulk JSON ingestion; PubMed/bioRxiv abstract/full-text polling filtered by active pipeline entities. | `NCT_ID` $\rightarrow$ `DRUG_MOLECULE` $\rightarrow$ `BIO_TARGET_PATHWAY` $\rightarrow$ `SPONSOR_ORG` $\rightarrow$ `PUBLIC_EQUITY`. | **Core Forensic Signal:** Store full `Record History` version chains in `fact_documents`. Automatically compute structured diffs (`diff_summary`) flagging primary-endpoint edits, enrollment cuts, and completion-date pushbacks. |
| **7** | **Sell-Side Analyst Reports** *(Hard Licensing Wall)*<br>Finnhub / FMP consensus estimates & earnings transcripts; open independent research | `local_hot_ducklake` + `fact_expectations` | Daily consensus EPS/revenue estimate snapshots (preserving revision history) + quarterly earnings call transcripts. | Mapped to `ORGANIZATION` with explicit `coverage_count` and `dispersion_std` fields. | Raw Goldman/Morgan Stanley PDFs are institutionally gated and legally inaccessible. The fabric explicitly records `source_status = 'SUBSTITUTED_CONSENSUS_ONLY'` so agents treat thin/missing sell-side coverage as an observable feature rather than silent missingness. |

### 5.3 Crowd, News, Legal & Digital Exhaust Domains

| # | Domain & Concrete Sources | Storage Tier & Format | Granularity & Ingestion Mode | Entity Linkage & Special Handling | Known Limitations & Fabric Safeguards |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **8** | **Prediction Markets (Crowd Expectations)**<br>Polymarket CLOB/trades, Kalshi API, Metaculus | `local_hot_ducklake` $\rightarrow$ `fact_expectations` | Hourly/event-driven snapshots of mid-probability, bid-ask spread, order-book depth at $\pm 2\%$, and trade volume. | Manually or LLM-assisted mapping from `MARKET_QUESTION` $\rightarrow$ `ENTITY` / `MACRO_EVENT` with explicit expiry `horizon_end`. | Thin markets suffer manipulation and wide spreads; `liquidity_score` automatically down-weights illiquid contracts in the Expectations Surface. |
| **9** | **Mainstream News & Social Media** *(Shaky / Noisy)*<br>GDELT (15-min global event stream), NewsCatcher / LexisNexis (licensed), Bluesky Jetstream, permitted Reddit/X live streams | CAS + `local_hot_ducklake` + Tantivy/FTS5 | Forward-only streaming/polling; deduplicated via MinHash/SimHash into story clusters; headline/body mutations stored as `version_seq` increments in `fact_documents`. | Entity extraction via deterministic dictionary + NER linking to `ORGANIZATION`/`EXECUTIVE`, tagged with extraction confidence $c$ and bot/spam `quality_score`. | Paywalls (WSJ/FT) and API lockouts prevent clean historical social scraping. `live_collection_start` is enforced strictly so backtests never assume historical social data existed prior to recording. |
| **10** | **Government, Legal & Supply-Chain Exhaust**<br>USAspending.gov, Senate LDA, OpenFEC, CourtListener/RECAP, USPTO PatentsView, US Customs Bills of Lading | `local_hot_ducklake` + CAS | Daily/weekly incremental API pulls (contracts awarded, lobbying disclosures, federal dockets, patent assignments, maritime import manifests). | String/address normalization pipeline resolving messy contractor/litigant/consignee names to `GLEIF_LEI` / `ORGANIZATION` with explicit confidence scores $c$. | Corporate parent-subsidiary trees are notoriously fragmented (e.g., defense primes bidding through regional LLCs). Maintained via GLEIF Level 2 parent-child ownership tables updated monthly. |
| **11** | **Digital Attention & Developer Exhaust**<br>Wikimedia Pageviews API, ATS Job Boards (Greenhouse/Lever/Ashby), GitHub / npm / PyPI stats | `local_hot_ducklake` | Hourly/daily incremental snapshots recorded forward; transformed into rolling z-scored velocity features to remove secular growth trends. | Deterministic mapping table (`wikipedia_slug`, `ats_board_token`, `github_org`) $\rightarrow$ `ORGANIZATION` / `PROTOCOL`. | Job postings vanish when closed; daily snapshot diffing (`added_roles`, `removed_roles`, `role_category`) turns transient web pages into a durable historical hiring-velocity archive. |

### 5.4 Physical World: Geospatial, Telemetry & Earth-System Domains

| # | Domain & Concrete Sources | Storage Tier & Format | Granularity & Ingestion Mode | Entity Linkage & Special Handling | Known Limitations & Fabric Safeguards |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **12** | **Flight (ADS-B) & Maritime (AIS) Tracking** *(Noisy / License-Sensitive)*<br>OpenSky Network, ADS-B Exchange / airplanes.live / adsb.lol, FlyItalyADSB; AISStream.io | `local_hot_ducklake` (with `GEOMETRY`) + compressed raw hourly batches in CAS | **Edge-downsampled at ingest:** Never persist raw 1 Hz global pings on zero hardware. Rust stream processor filters to watchlist `ICAO24`/`MMSI` or port/airport geofences, emitting **dwell-time, departure, and arrival events** (`GEOMETRY` + timestamps). | `ICAO24` $\rightarrow$ FAA N-Number Registry $\rightarrow$ Shell LLC $\rightarrow$ `ORGANIZATION` ($c \in [0.4, 0.95]$). `MMSI` $\rightarrow$ `VESSEL` $\rightarrow$ commodity class / port congestion polygons. | **Two hard pitfalls handled by design:** (a) FAA LADD/PIA masking and charter fleets (NetJets) break naive tail-number tracking—flagged via low $c$ and maintenance-flight filters; (b) `NON_COMMERCIAL` feeds (OpenSky free tier) are tagged in `license_class` so commercial pods cannot query them. |
| **13** | **Weather, Satellite & Farming / Ag**<br>ECMWF ERA5 (AWS/GCS), NOAA HRRR/GFS/GHCN-D, Sentinel-2 / Landsat COGs, NASA FIRMS, USDA NASS & WASDE | `remote_virtual_icechunk` (Zero-Copy Tensors) + `local_hot_ducklake` (extracted regional time series & USDA vintages) | **Zero-Copy Spatial Aggregation:** Icechunk Virtual Chunks point to remote S3/GCS Zarr/NetCDF/COG files. On schedule, `xarray` pulls only the byte ranges intersecting registered crop-belt/mine/refinery `GEO_REGION` polygons, writing tiny scalar summaries (soil moisture, HDD/CDD, NDVI anomaly, thermal flare count) into DuckLake. | `GEO_REGION` (crop county, refinery, mine, hydro basin) linked via `OPERATES_AT` / `EXPOSED_TO_REGION` edges to `ORGANIZATION` or `COMMODITY_FUTURE`. | **Forecast vs. Reanalysis Leakage:** ERA5/ARCO-ERA5 overwrites recent ERA5T records and is retrospective (`OBS`). Backtesting weather trading signals must query archived ex-ante GFS/ECMWF forecast runs (`polarity = 'FCST'`) and monthly unrevised WASDE release snapshots (`known_at` = exact 12:00 ET release timestamp). |

---

## 6. Composition & Serving Layer for AI Agent Pods

A serious multi-pod AI quant shop requires strict separation between **data access**, **agent reasoning**, and **quantitative evaluation**.

### 6.1 Composable Transformation DAG (Bronze $\rightarrow$ Silver $\rightarrow$ Gold)
Managed via **SQLMesh** so every model is versioned, unit-tested, and rebuildable from CAS:
1. **Bronze (Immutable Raw):** Raw CAS blobs + minimal 1:1 ingestion tables recording exact receipt timestamps (`ingested_at`).
2. **Silver (Canonical Bitemporal):** Cleaned, deduplicated, unit-standardized records written to `core.fact_observations`, `core.fact_documents`, and `core.rel_entity_edge`, with failed records routed to `quarantine.dead_letter`.
3. **Gold (Domain & Cross-Crowd Primitives):**
   * *Pod-Scoped Materializations:* e.g., `gold_biotech.trial_forensics_panel`, `gold_perps.funding_crowding_panel`, `gold_macro.supply_shock_panel`.
   * *Curated Cross-Asset Crowd Bridges:* Three tiny, clean tables any pod may subscribe to without opening the entire swamp:
     1. `bridge.macro_liquidity_regime` (rates curve, DXY, stablecoin supply velocity)
     2. `bridge.crowd_probability_shifts` (significant repricings on Polymarket/Kalshi/options)
     3. `bridge.entity_attention_spikes` (abnormal filing, news-cluster, and Wikimedia/ATS velocity)

### 6.2 Causally Enforced MCP Interface for AI Agents
AI agents never receive raw SQL write access or unrestricted filesystem mounts. Instead, each pod connects to a lightweight read-only **Model Context Protocol (MCP)** server instantiated with a locked `(pod_id, as_of_utc, blinding_mode)` session context:

* `get_entity_dossier(entity_id)` $\rightarrow$ Returns canonical profile, active corporate/asset graph edges $G(t)$ with $c \ge c_{\min, p}$, and latest expectations $\mathcal{B}_t$.
* `query_pit_metrics(entity_id, metric_keys, lookback_days)` $\rightarrow$ Executes `core.pit_latest(as_of_utc, ...)` and returns typed time series with units and provenance hashes.
* `diff_document_versions(entity_id, doc_type, window_days)` $\rightarrow$ Returns structured diffs between consecutive filings or trial protocols observed on or before `as_of_utc`.
* `search_corpus_pit(query_text, doc_types, top_k)` $\rightarrow$ Queries Tantivy/FTS5 with mandatory pre/post filter `known_at <= as_of_utc`, returning exact excerpts plus `(doc_id, known_at, raw_hash)`.
* `sample_spatial_tensor(region_id, variable, start_date, end_date, polarity)` $\rightarrow$ Triggers a bounded zero-copy Icechunk range read and returns regional summary statistics.
* `submit_forecast_artifact(entity_id, target_event, horizon_end, prob_estimate, rationale_citations)` $\rightarrow$ Writes to an **append-only, hash-chained Prospective Forecast Ledger** so agent calibration (Brier Score, Log Loss, Information Ratio vs. Crowd Baseline) is scored audibly out-of-sample.

---

## 7. Engineering Practices, Governance & Scaling Tiers

### 7.1 Hardware Scaling Without Architectural Rewrites
Because the fabric decouples **metadata** (SQL), **bytes** (Parquet/CAS/Icechunk), and **compute** (DuckDB/Polars), hardware upgrades are pure configuration swaps:

| Deployment Tier | Hardware & Monthly Infra Cost | Catalog & Storage Backend | Capabilities |
| :--- | :--- | :--- | :--- |
| **Tier 0: Zero-Hardware Bootstrap** | Existing laptop + $5–$10/mo VPS (2 vCPU, 4 GB RAM) + Cloudflare R2 (~$1–$5/mo) | DuckLake on local SQLite/DuckDB + local SSD (15–30 GB) + R2 CAS + remote Icechunk virtual chunks | Full Biotech Forensics, On-Chain Perps, Daily Equities, SEC/AACT diffs, Prediction Markets, downsampled AIS/ADS-B geofences, virtual ERA5/Sentinel-2. |
| **Tier 1: Serious Homelab / Dedicated Box** | Single server (64–128 GB RAM, 4–8 TB NVMe/ZFS RAID, ~$100/mo colocated or owned) | DuckLake on PostgreSQL + Garage/MinIO S3 + Tantivy full corpus + optional QuestDB for high-rate tick streams | Full 1-min US equities/options history, broad live crypto L2 recording, full local SEC/PubMed/CourtListener mirror, parallel multi-pod agent runs. |
| **Tier 2: Multi-User / Team Scale** | Cloud object storage (S3/R2) + autoscaling stateless workers | DuckLake on managed Postgres + Iceberg export interoperability + Arrow Flight cluster | Concurrent research teams, large-scale Monte Carlo / walk-forward validation, selective multi-venue L3 studies. |

### 7.2 Reliability, Observability & Data-Quality Gates
* **Schema-First Ingestion:** Every connector emits Apache Arrow RecordBatches validated against strict schemas (types, non-null `known_at`, unit enums, valid UTF-8). Any schema break from an upstream API routes cleanly to a dead-letter bucket with an alert rather than poisoning production tables.
* **Automated Bitemporal CI Invariants:** Every SQLMesh run executes automated assertions:
  1. $\forall x \text{ with } \kappa(x) = \text{OBS}: \tau_{\text{kn}}(x) \ge \tau_{\text{ev}}^{-}(x) - \epsilon_{\text{clock}}$ (catches timestamp-parsing bugs).
  2. $\forall x: \tau_{\text{kn}}(x) \le \text{now}_{\text{UTC}}$ (prevents future-dated ingestion).
  3. Zero orphan `raw_hash` references in Silver/Gold tables (verifies end-to-end provenance).
  4. Pod View License Audit: verifies zero rows with `license_class = 'NON_COMMERCIAL'` appear in any view tagged `execution_eligible = true`.
* **Compaction & Maintenance:** Scheduled `CHECKPOINT` jobs flush DuckLake inlined trickle rows into sorted Parquet files, compact small files, and run snapshot-expiration policies (while preserving long-term audit tags for every published backtest snapshot).

---

## 8. Phased Implementation Roadmap

Building all 13 domains simultaneously causes schema paralysis. Execute in four disciplined vertical milestones that validate every architectural primitive early:

1. **Phase 0 — The Core Kernel (Weeks 1–2):**
   * Stand up DuckLake (SQLite/DuckDB catalog), local/R2 CAS writer (`SHA-256` + Zstd), Source Manifest validator, canonical DDL (`dim_entity`, `rel_entity_edge`, `fact_observations`, `fact_documents`, `fact_expectations`), and the `core.pit_latest` macro suite.
   * Build the read-only causal MCP server skeleton with mandatory `as_of_utc` enforcement and the hash-chained Prospective Forecast Ledger.
2. **Phase 1 — Dual-Vertical Stress Test (Weeks 3–6):**
   * *Pod A (Continuous Numeric):* Deploy a lightweight Rust WebSocket collector for on-chain perp funding, OI, mark/index basis, and candles. Validates DuckLake Data Inlining, live recording, and ASOF joins.
   * *Pod B (Discrete Document + Forensics):* Wire survivorship-free daily US equities + corporate actions, SEC EDGAR incremental XBRL/10-K/8-K watcher, ClinicalTrials.gov v2 / AACT protocol differ, and the EV-to-Cash Expectations Surface. Validates entity resolution, Tantivy PIT search, document diffing, and entity-blinding middleware.
3. **Phase 2 — Crowd Expectations & Event Fabric (Weeks 7–10):**
   * Integrate Polymarket/Kalshi order-book depth into `fact_expectations`, options-implied event moves (ThetaData), GDELT + forward news clustering, and Wikimedia/ATS hiring-velocity collectors.
   * Publish the three curated Cross-Asset Crowd Bridges and verify Pod View isolation.
4. **Phase 3 — Virtualized Physical World & Selective Microstructure (Weeks 11–16):**
   * Configure Icechunk Virtual Chunk repositories pointing to AWS Open Data / GCS (ERA5, NOAA GFS archived forecasts, Sentinel-2) plus local USDA NASS/WASDE vintage tables and `GEO_REGION` entity mappings.
   * Deploy geofenced AIS/ADS-B edge-downsampling collectors with strict `license_class` tagging, USAspending/CourtListener/PatentsView connectors, OTC proxy-graph edges, and the on-demand Databento L3 ephemeral pull helper.