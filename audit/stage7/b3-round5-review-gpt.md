# Review of B3 round 5 (5b02dd3)

GPT (`openai/gpt-6.1-sol#high`, opencode), independent review from a clean worktree (no `data/`), at `5b02dd3`; started 2026-11-04 11:01 UTC (06:01 EST), reply received 11:09 UTC (06:09 EST). The reply as given, tool transcript omitted.

## Findings, most severe first

1. **High — Parquet permits ambiguous column names that the decoding rules do not resolve.**  
   `audit/stage7/b3-draft/rules-revision.md:142–154`  
   No rule rejects duplicate Parquet field names or determines which occurrence is read. I successfully wrote and read a Parquet file containing two Double columns named `close`, holding **1.0** and **2.0**. Both satisfy the stated type mapping. Choosing either occurrence, or rejecting the dataset, is presently unspecified. JSON’s duplicate-member prohibition does not govern a Parquet schema.  
   **Judged outcome:** conforming loaders can disagree on delivered values, admission, and resulting strategy returns.

2. **High — The reported 1,001 comparisons contain only 999 distinct delivered pairs.**  
   `audit/stage7/b3-draft/resolver_suite.py:627–629`; `audit/stage7/b3-draft/c76-revision.md:32–36`  
   `delivered` counts repeated query times separately. Generated JSONL **line 55** contains queries `[46800000, 176400001, 176400001, 180000001]`; the repeated time contributes twice for each of two qualifying keys. Independently counting distinct `(store, source, entity, event, query-time)` pairs gives **999**, not 1,001. The text calls these *pairs* without authorizing repeated occurrences to inflate the floor.  
   **Judged outcome:** C7.6 can pass below 1,000 different delivered comparisons; alternatively, the frozen size rule has two readings.

3. **Medium — The Parquet-image contract cannot represent oversized recording timestamps.**  
   `audit/stage7/b3-draft/c76-revision.md:23–29`; `audit/stage7/b3-draft/resolver_suite.py:603–613`; `audit/stage7/b3-draft/resolver_suite.py:206`  
   The new hand case contains `fetchedAt = -9223372036854775809`. It cannot be written as the required Int64 metadata, yet `image()` returns true; the only stated no-image exception concerns malformed/non-object `cells`. There is also a resolving counterexample: two ordinary eligible revisions followed by a post-V revision with `fetchedAt = 2^63`. Lean resolves it and `delivered()` counts it, but its prescribed Int64 image cannot be constructed. Writing another metadata type instead makes Parquet globally invalid under the new rules.  
   **Judged outcome:** loader comparisons can fail before resolution, or compare different eligibility/validity semantics between JSON and Parquet.

4. **Medium — The undecodable-event-time xfail fails in fixture construction, not in the loader.**  
   `ingest/tests/test_store.py:225–229`; `audit/stage7/holdout-staging.md:6–9`  
   `staged()` has already garbled every non-event column. Line 226 then reads the entire corrupted file to construct the Double event time and raises `polars.exceptions.ComputeError`. Consequently, the Double fixture is never created and `search.as_of` is never called. This test would remain xfailed even after implementing correct staging. The audit record incorrectly attributes all three failures to production loading.  
   **Judged outcome:** the regression provides no evidence that an undecodable post-V event time is refused before values are read.

5. **Medium — The specifically named Rust staging tests still do not exist.**  
   `audit/stage7/b3-draft/c76-revision.md:56–62`; `audit/stage7/rust-port-plan.md:47–49`  
   Neither Rust counterpart exists in `kernel/mm/tests/`. Their implementation is explicitly deferred to slice 5. The existing `holdout_rows_refused_after_metadata` supplies decoded times through a mock callback; it does not exercise Parquet column access. Correcting the directory answered Claude finding 5’s path issue, but not GPT finding 3’s missing executable evidence.  
   **Judged outcome:** the named staging requirement has no physical-loader test for `mm`; it cannot presently support a C7.6 staging pass.

## Round-4 findings, individually

| Finding | Assessment |
|---|---|
| GPT 1 — counting stores without images | Original malformed-text exclusion fixed; **no findings** on that exclusion. Image completeness remains finding 3 above. |
| GPT 2 — metadata-name collisions | Reserved and rejected by Rust and Lean; **no findings**. |
| GPT 3 — missing staging test | Python’s two crossing cases now exercise production loading. Not fully closed: findings 4–5. |
| GPT 4 — fetchedAt versus knownAt counting | Changed to knownAt; **no findings** on that condition. |
| GPT 5 — oversized integers becoming zero | Exact-integer case reader fixes it; **no findings** on Lean’s rejection. |
| GPT 6 — boolean/number file equality | Type-sensitive equality fixes it; **no findings**. |
| Claude 1 — multi-revision floor | Correct qualifying-key condition, but distinct-pair floor remains finding 2. |
| Claude 2 — null column image | Double-null image specified; **no findings** on that answer. Production writer repair/test remains explicitly deferred. |
| Claude 3 — undecodable event time | Refusal specified, but its executable variant is broken: finding 4. |
| Claude 4 — negative-zero `num` | Sign specified and delivered-negative-zero hand case added; **no findings**. |
| Claude 5 — Rust test directory | Path corrected; **no findings** on the path. Test existence remains finding 5. |
| Claude 6 — Arrow schema and metadata types | Schema authority and metadata types specified; **no findings** on those particular corrections. Duplicate names remain finding 1. |

Beyond these findings, **no findings** on Lean’s timeline, lineage, retraction, slot, role, or observation behavior against the stated case contract.

## Reproduced checks

- Ran `resolver_suite.py` with `PYTHONPATH=.`; it exits successfully but has no executable checking entry point.
- `lake build` in `reference/lean`: **successful**.
- `lean_check.py`: **160/160** hand cases agree; both JSONL files match.
- Generated: **478 stores**, **362 resolve**, **116 INVALID**; **398** have an image according to `image()`, including **349 resolving stores**.
- Size: **1,001 reported occurrences; 999 distinct qualifying pairs**.
- All coverage floors pass; smallest REACHED count: **67**.
- Observation-projection disagreements: **0**. This is not a production-loader comparison.
- `ingest/tests/test_store.py`: **16 passed, 3 xfailed**. With xfails disabled, two fail in production loading as recorded; the third fails during fixture construction.
- Rust source-declaration tests: **5 passed**, including metadata-name rejection and its control.

**Verdict: revise first.**
