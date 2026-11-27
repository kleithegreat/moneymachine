# Behavioral Quirks, Traps & Operational Footguns

A living reference of subtle constraints, historical gotchas, and tool behaviors that trip up agents and humans working in `moneymachine`.

---

## 1. Causal Data Fabric Quirks

- **Retractions must never resurrect earlier vintages (`core.pit_latest`):**
  In SQL window functions, ALWAYS assign `row_number() OVER (PARTITION BY entity_id, source_id, metric, event_time ORDER BY known_at DESC, revision_id DESC, obs_id DESC)` inside the CTE *before* filtering `revision_state <> 'RETRACTED'` in the outer query (`fabric/catalog.py`). Filtering retractions before ranking resurrects `revision_id = 1` when `revision_id = 2` is a retraction. Proved formally in [`fabric/lean/Fabric/Causal.lean`](../fabric/lean/Fabric/Causal.lean) (`pitLatest_no_resurrection`).
- **`OBS` vs. `FCST`/`SCHED` causality check:**
  `FabricCatalog.add_observation` and `add_document` reject `known_at < event_time` whenever `polarity == "OBS"`. Future target dates (FDA PDUFA dates, earnings schedules, consensus/prediction market odds) must use `polarity = "SCHED"` or `polarity = "FCST"` (or live in `core.fact_expectations`).
- **Tantivy `term_set_query` with empty lists:**
  Passing an empty list `[]` to `tantivy.Query.term_set_query` must short-circuit in Python (`PitSearchIndex.search` returns `[]` immediately when `allowed_sources == ()` or `allowed_licenses == ()`).
- **DuckLake `SET SORTED BY` and offline Nix builds:**
  Standard local DuckDB tables reject `ALTER TABLE ... SET SORTED BY (...)`. `FabricCatalog` only runs `LOAD ducklake` and `SET SORTED BY` when `ducklake_data_path` is explicitly provided (remember Nix build sandboxes have no network access to install remote DuckDB extensions).
- **Entity Blinding (`BLINDED_ENTITIES`) limitations:**
  `EntityBlinder` deterministically masks canonical names, aliases, external IDs (`ticker`, `cik`, etc.), extra terms, and ISO calendar dates, and `CausalFabricService` maintains bidirectional entity/document alias maps per session. However, LLMs can still sometimes fingerprint famous historical crises from qualitative phrasing—use blinded historical replays for rapid iteration and hash-chained `ForecastLedger` prospective bets as ground truth.

---

## 2. Python Typing, Style & Frozen Modules

- **`pyproject.toml` `follow_imports = "skip"` + `pydantic`:**
  Because root `mypy` runs with `strict = true` and `follow_imports = "skip"`, third-party base classes become `Any` unless listed in `[[tool.mypy.overrides]]` with `follow_imports = "normal"`. Keep `["pytest.*", "_pytest.*", "pydantic.*", "pydantic_core.*"]` there.
- **Frozen live-cluster recorder modules (`ops/style.py`):**
  `ops/style.py` dynamically imports `ingest.datalayer` and `ingest.sources_record` and excludes them from the default `style` check so deployed container hashes don't churn unnecessarily. Because callers with `follow_imports = "skip"` see excluded module returns as `Any`, annotate/coerce return boundaries explicitly (e.g. `bytes(datalayer.body(...))` in `fabric/adapters/datalayer_bridge.py`). Also run explicit `ruff` + `mypy` directly against `ingest/datalayer.py` whenever editing it.
- **`ingest/live.py` torn JSONL lines:**
  `live.read()` prints warnings to stderr and skips malformed/torn lines quietly—do not assume 100% of logged hashes correspond to readable `.gz` bodies (`datalayer_bridge.py` skips missing/corrupt bodies cleanly).

---

## 3. Nix Flakes, Builders & Git Hooks

- **`nix eval --impure --expr 'builtins.getFlake (toString ./.)'` trap:**
  Evaluating `.` impurely via `builtins.getFlake` hashes the entire multi-GB `data/` tree and hangs or fills memory. Always use `nix develop`, `nix flake check`, `nix run .#test`, or `nix eval --inputs-from . nixpkgs#...`.
- **`git add -N` required before flake checks:**
  Flakes inspect only git-tracked and intent-to-add files. Newly created files remain invisible to `nix flake check`, `style`, and `fabric` until registered via `git add -N <path>` (NEVER add `data/`, `_build/`, `.lake/`, or secrets).
- **`ops/check-times.sh` UTC/Eastern timestamp pairing:**
  `.githooks/pre-commit` enforces two hard rules on `PROGRESS.md` and `audit/` (outside `audit/reviews/`):
  1. `PROGRESS.md` byte size must stay `<= 12,288` bytes (`checks.x86_64-linux.progress-cap`).
  2. Every added/modified line containing `HH:MM UTC` (including seconds) MUST pair an Eastern timestamp (`HH:MM EST` or `HH:MM EDT`) on the **same line**.
- **`prodesk7` remote builder memory cap (`CLUSTER.md` §6):**
  `prodesk7` enforces a strict `mmtest.slice` 5 GiB cgroup cap with no swap for remote Nix builds. Pass `--builders ""` locally if running heavy multi-core Lean/OCaml builds that would pressure a builder node.

---

## 4. OCaml & Lean Conventions

- **Zero wildcard `with _` exception handlers (`CLAUDE.md` §2):**
  Catch specific exceptions (`Sys_error _`, `Core_unix.Unix_error _`, `Zstd_error _`) across `recorder/`, `fabric/ocaml/`, and `wiki/server/`.
- **Strict compiler warnings:**
  All dune projects inherit `-w +a-4-40-41-42-44-45-70 -warn-error +a` plus `ocamlformat` 0.29.0 (`janestreet` profile) and `ppx_js_style`.
- **Lean 4.34 deprecations under `warningAsError = true`:**
  Avoid deprecated lemmas like `if_pos` / `if_neg` (use `simp` / `↓reduceIte`) and never include `sorry`, `admit`, `axiom`, or `native_decide` (`checks.x86_64-linux.fabric-proofs` rejects them).

---

## 5. Live Cluster & Hardware Operations (`prodesk7`)

- **Unexplained power loss (2026-11-22):**
  `prodesk7` powered off without kernel panic logs (`13:00`–`17:06 UTC`, `08:00`–`12:06 EST`), leaving a ~4h07m gap in `ws`, `sources`, and `datalayer`. Check hardware power path, BIOS AC recovery, and NVMe upgrade before ~April 2027.
- **PVC quota quirk:**
  `local-path` PVs do not enforce disk quotas—`ws` shares `prodesk7`'s root filesystem. Monitor capacity (`ops/diskguard.py`).
- **GDELT `lastupdate.txt` 404 timing:**
  GDELT publishes index filenames ~134s before the export zip is downloadable; `ingest/datalayer.py` retries pending exports up to 10 fixed ticks without shifting schedule cadence.
- **Embargoed forward window:**
  Never open or read `~/embargo/oci-forward-window/` or modify `data/` payloads inside code tasks.
