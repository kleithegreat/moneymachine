# Review of B3 round 6 (4230c36)

GPT (`openai/gpt-6.1-sol#high`, opencode), independent review from a clean worktree (no `data/`), at `4230c36`; started 2026-11-04 11:37 UTC (06:37 EST), reply received 11:47 UTC (06:47 EST). The reply as given, tool transcript omitted.

## Findings, most severe first

### 1. High — Test 3 still accepts a loader that reads values before checking the holdout

**Locations:** `ingest/tests/test_store.py:206–244`; `audit/stage7/b3-draft/c76-revision.md:54–67`.

The tests verify the eventual refusal, not that no full-column read preceded it. The negative control tests only a loader that immediately converts its decoding error into an invalid-dataset refusal.

I substituted, **in memory only**, a non-staged `Store.as_of` that:
1. calls `self.revisions(dataset)` first, attempting to read every column;
2. catches a decoding error;
3. scans event times to select the higher-priority holdout-crossing or uncheckable refusal;
4. reports dataset invalidity only if neither applies.

With `--runxfail`, **all six selected tests passed**: the three production-facing staging cases and their three negative-control cases. There were **three forbidden pre-check full-column load attempts**. On uncorrupted files, this loader would materialize the values before refusing.

Thus round 6 fixes the misleading message matches and broken fixture, but does not fully close Claude finding 2. Read-order instrumentation, or equivalent executable evidence, is still needed.

**Judged outcome:** C7.6’s staging requirement could pass for a loader that reads holdout values before refusal, violating the intended holdout-access boundary.

## Round-5 findings, individually

| Finding | Assessment |
|---|---|
| GPT 1 — duplicate Parquet names | **No findings.** `rules-revision.md:147–148` now makes them globally invalid. |
| GPT 2 — repeated queries inflated size | **No findings.** Distinct query times are counted; independently reproduced **1,001 distinct qualifying pairs**. |
| GPT 3 — oversized fetchedAt has no image | **No findings.** Explicitly excluded from the loader comparison and size. |
| GPT 4 — variant failed during setup | **No findings.** Double event time is written before garbling; failure now occurs inside production loading. |
| GPT 5 — missing Rust staging tests | **Still absent**, explicitly deferred under the advisor’s ruling. No new finding on that permitted deferral; these cannot presently support a C7.6 pass. |
| Claude 1 — broken variant setup | **No findings.** Corrected at its cause. |
| Claude 2 — non-staged loader passes | **Not fully closed:** finding 1 above. The supplied negative control fails each case, but another non-staged loader passes all three. |
| Claude 3 — invalidity versus uncheckability | **No findings.** The holdout check now has its own refusal, with the integer range stated explicitly. |
| Claude 4 — upstream reservation | **No findings.** Reserved for every source; Rust and Lean agree. |
| Claude 5 — oversized fetchedAt image | **No findings.** Exclusion is now explicit. |

## Reproduced checks and remaining status

- Executed `resolver_suite.py` with `PYTHONPATH=.`; it has **no standalone checking entry point**.
- `lake build` in `reference/lean`: **successful, 109 jobs**.
- Then `lean_check.py`: **160/160 hand expectations agree**; both JSONL files match their generators.
- Generated: **481 stores; 365 resolve; 116 INVALID; 401 have Parquet images**, including **352 resolving stores**. Independently materialized and read all **401** images file by file.
- Size: **1,001 distinct `(store, source, entity, event, query time)` pairs**, all on qualifying multi-revision keys of U with an entry known by the query. **696** see values; **305** see retractions. Without the last store: **999**.
- Every coverage floor passes; smallest REACHED count: **68**. Observation-projection disagreements: **0**.
- Python store tests: **17 passed, 3 xfailed**. Disabling xfails confirms all three fail in `ingest/store.py:72` with the recorded Parquet decoding error—not fixture construction.
- Rust declaration tests: **5 passed**.
- The remaining production-loader tests named in C7.6, including the Rust staging counterparts, remain slice-5 obligations—not demonstrated loader agreement here.

Beyond finding 1, **no findings** on the revised JSON/Parquet decoding contract or Lean’s fidelity to the stated resolver semantics.

**Verdict: revise first.**
