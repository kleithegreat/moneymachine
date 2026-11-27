# Operations & Commands Reference

Quick-reference guide for building, testing, ingesting data, running the Wiki, and inspecting the live cluster.

## 1. Development Environment & Full Verification

```bash
# Enter polyglot shell (OCaml 5.4, Lean 4.34, Python 3.13, DuckDB, Zstd, uv)
nix develop

# Run all root flake checks, local tests, hook checks, and workload checks
nix run .#test

# Verify moved confirmation-wall Kernel v2 sub-flake
nix flake check -L ./subprojects/confirmation-wall/kernel2
```

Remember to register any brand-new git files with `git add -N <path>` before invoking Nix flake checks (see [Behavioral Quirks](quirks.md)).

## 2. Offline Wiki & Docs Server (`mmwiki`)

```bash
# Serve offline HTML + JSON Wiki on localhost:8080
nix run .#wiki -- --root . --addr 127.0.0.1 --port 8080

# CLI JSON queries for agents
nix run .#mmwiki -- index --root .
nix run .#mmwiki -- search --root . "retraction"
```

## 3. Data Fabric CLI (`python -m fabric` & `mmfabric`)

```bash
# Initialize CAS, DuckDB catalog, Tantivy index, and SQLite ForecastLedger
python -m fabric --root data/fabric init

# Validate YAML source manifests
python -m fabric validate-manifests

# Inspect table counts and ledger status
python -m fabric --root data/fabric status

# Run all causal, provenance, retraction, and hash-chain invariants
python -m fabric --root data/fabric audit

# Ingest local datalayer HTTP/gzip recordings
python -m fabric --root data/fabric ingest-datalayer --live-dir data/datalayer

# Ingest Hyperliquid Parquet archives or WS .jsonl(.zst) captures
python -m fabric --root data/fabric ingest-hl-ws --input data/snapshots/BTC

# Launch scoped FastMCP server for an agent pod
python -m fabric --root data/fabric mcp --pod-id pod_b --blinding BLINDED_ENTITIES

# Direct OCaml CAS CLI (`mmfabric`)
printf 'raw-bytes' | nix run .#mmfabric -- cas-put --root data/fabric
nix run .#mmfabric -- cas-verify --root data/fabric <sha256>
nix run .#mmfabric -- cas-get --root data/fabric <sha256>
```

## 4. Live Homelab Cluster (`moneymachine-live`)

Full Kubernetes & mirror runbook lives in [`../CLUSTER.md`](../CLUSTER.md):

```bash
KUBECONFIG=~/.kube/moneymachine-live.yaml kubectl -n moneymachine-live get pods,jobs,cronjobs
```
