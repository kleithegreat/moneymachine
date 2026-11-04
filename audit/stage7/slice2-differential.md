# Slice 2's run differential (finding 3 of `slice2-review-gpt.md`)

2026-11-04 07:59 UTC (02:59 EST), at `0738c2d` (slice 2 and its fixes for findings 1 and 2), a development run, never judged.

## Why N1 "did not rebuild as frozen"

Slice 2 (`e2b4925`) ran on a `stage7` that branched before `main`'s `dd9580d` (2026-10-27). That commit already
settled this exact failure: `market_hash` leaves out the `version` pin that market directories gained after the
corpus froze (`b2c0007`), and every frozen file is still hashed whole
(`audit/decisions.md`, 2026-10-27 21:33 UTC (17:33 EDT)). `n1-rebuild-diagnosis-gpt.md` found the same file from `e2b4925`'s copy of the harness. The later
syncs of `stage7` with `main` brought `dd9580d` in. Its fix stands for the differential: `mmdump` and `refmm`
take the version from the manifest, never from the pin. No code changes here.

Rebuilt at `0738c2d`: N1, edge, liquidation and ruin each match their frozen `market_sha256`.

## Result

`slice2-differential-report.json`: the frozen manifest (`0411a426…`) and corpus (sha checked), `reference/differential.py`'s
own `build`, `null_market`, `edge_markets.MARKETS`, `market_hash`, `verdict` and `chunk`, driven over the markets
this host can rebuild:

- verdicts: 1,196 programs, 0 disagreements;
- runs: 1,170 of the corpus's 3,372 (N1 1,101, edge 61, liquidation 4, ruin 4), 0 disagreements in the trace,
  returns, gross returns, node types and counts, and every node stream byte for byte (3,733,367,834 defined node values).

**Not run: N2 and N3's 2,202 runs.** They bootstrap the real funding store (`gate/nulls.json`: `data/store`,
blob sha256 `d07162b8…`), which this cloud container lacks. The complete check is `differential.run` itself on a
host with `data/store`; until then, slice 2's run preservation holds on N1 and the edge markets only.

The driver differs from `differential.run` only in leaving out N2 and N3 (`markets_of` builds all six):

```python
roots = {"N1": d.null_market(work / "N1", "N1", manifest["seed"])} | {m: f(work / m) for m, f in edge_markets.MARKETS.items()}
assert all(d.market_hash(r) == manifest["markets"][m]["market_sha256"] for m, r in roots.items())
vs = [d.verdict(i, it, work) for i, it in enumerate(items)]                    # in a pool, compute.workers(CHECK_BYTES)
res = [d.chunk(names, texts, m, roots[m], manifest["markets"][m]["version"], work) for each CHUNK of each m in roots]
```

`mm check` needs `data/` to exist in the checkout (its ledger path); an empty one suffices.
