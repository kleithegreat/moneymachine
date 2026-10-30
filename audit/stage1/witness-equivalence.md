# The witness's per-step view (C1.4), rewritten for speed: equivalence

`ingest/witness.py` read `as_of(t_d, version)` twice per step and filtered it per coin. It now reads `as_of(HOLDOUT_START, version)` once and looks up each (coin, B) with `knownAt <= t_d`. The profile (cProfile, 184 s): 162 s in those 6,600 `as_of` calls.

Dataset version 1792613363942, `venue/hyperliquid`. The trace is `witness.run`'s records, one `json.dumps` per line, as `replay` writes them.

| | before (435fb2a) | after |
|---|---|---|
| seconds | 175.6 | 0.3 |
| records | 9,516 | 9,516 |
| trace sha256 | 026696a145899d8dc2b8a96a050771294b7229938853e9d69a7d3febc525e80c | 026696a145899d8dc2b8a96a050771294b7229938853e9d69a7d3febc525e80c |
| worst | 5.107703701726368e-15 (0x1.700c80c3f54e4p-48) | 5.107703701726368e-15 (0x1.700c80c3f54e4p-48) |

The two trace files are also byte-identical (`cmp`), and `worst` equals `audit/stage0/witness.json`.

Why it holds beyond this dataset: in `Store.as_of`, t appears only in the final `.filter(knownAt <= t)`, and every t_d = b + 4h + delta with b + 8h <= HOLDOUT_START precedes HOLDOUT_START. `ingest/tests/test_store.py::test_a_view_is_the_latest_view_filtered_by_known_at` holds this with corrections and tombstones.

Directly on this dataset: at all 3,299 decision times, for funding and bars_4h, `as_of(t_d)` equals `as_of(HOLDOUT_START).filter(knownAt <= t_d)` as whole frames: 6,598 comparisons, 0 unequal. The filter matters here: it withholds 12 rows at or before B, summed over the steps. The rewrite keeps it, and keeps `assert max(known) <= t_d`. The witness does not import the kernel.
