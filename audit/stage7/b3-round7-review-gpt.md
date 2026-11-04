# Review of B3 round 7 (fdc07ac)

GPT (`openai/gpt-6.1-sol#high`, opencode), independent review from a clean worktree (no `data/`), at `fdc07ac`; started 2026-11-04 12:13 UTC (07:13 EST), reply received 12:28 UTC (07:28 EST). The reply as given, tool transcript omitted.

## Findings, most severe first

### 1. High — Test 3 still passes a loader that reads values before refusing

**Locations:** `ingest/tests/test_store.py:274–279`; `audit/stage7/b3-draft/c76-revision.md:61–65`.

The assertion establishes that every fixture file had **some recorded read**, not that **every read** went through the seam. An additional path-based read is invisible once the loader also reads event times through `open_parquet`.

I substituted `Store.as_of` **in memory only** with a loader that:
1. Calls `pl.read_parquet(path)` on every file, materializing every column where possible and retaining decoding failures.
2. Reads event times through the wrapped seam.
3. Gives the required crossing or uncheckable refusal.

With `--runxfail`, **all 18 selected tests passed**: six production-facing staging cases and twelve control cases. The substituted loader made **12 unrecorded full-column attempts**, materializing **six rows** on the ungarbled fixtures—including the holdout rows.

The new instrumentation does reject both supplied controls, and closes round 6’s error-survival loophole **when all reads use the seam**. It does not enforce that premise. The current production `Store` has no bypass; that static fact does not make the test reject a future bypass.

**Judged outcome:** C7.6’s staging test could pass while holdout values are materialized before refusal. GPT finding 1 and Claude finding 1 are therefore not completely closed.

### 2. Medium — Embedded-schema precedence leaves physical duplicate columns ambiguous

**Location:** `audit/stage7/b3-draft/rules-revision.md:142–150`.

The duplicate-name rule examines **only the embedded Arrow schema when present**. It neither rejects duplicate physical Parquet names in that case nor defines how disagreeing embedded names identify physical chunks.

I constructed an in-memory Parquet file with:
- Physical fields `coin, eventTime, fetchedAt, close, close`, containing `close` values **1 and 2**.
- Embedded Arrow fields `coin, eventTime, fetchedAt, close, other`, all uniquely named and type-compatible.

The revised duplicate-name rule does not invalidate this file. PyArrow exposes both physical `close` columns; conversion to a name-keyed dictionary retains **2**. Treating the embedded names as positional authority instead identifies **1** as `close`. The text does not specify that association.

Thus choosing one schema for the duplicate check does not itself ensure one decoding.

**Judged outcome:** The frozen Parquet-as-cells contract could permit different delivered values—or validity decisions—across implementations, changing C7.6’s exact-agreement result. Claude note 2 is not fully resolved.

## Round-6 disposition

| Item | Assessment |
|---|---|
| GPT 1; Claude 1 — premature reads | Partially answered; finding 1 above remains. |
| Claude 2 — comparison’s holdout bound | **No findings.** The comparison explicitly uses stores without a holdout bound. |
| Claude 3 — undefined LO/HI | **No findings.** The interval is explicit. |
| Claude 4 — refusal content | **No findings.** Text and executable checks now agree. |
| Claude 5 — sources of dataset invalidity | **No findings.** Both specifications are cited; footer schema checks precede staging. |
| Claude note 2 — schema identity | Finding 2 above. |
| Claude note 3 — provenance | The §6 list now includes round 5 but still omits round 6 (`rules-revision.md:15`). No judged-outcome finding. |
| Claude note 4 — stale historical parenthesis | **No findings.** Removed. |

## Reproduced checks

- `resolver_suite.py` executes successfully with `PYTHONPATH=.`; it has no standalone checking entry point.
- `lake build`: **successful, 109 jobs**. Then `lean_check.py`:
  - **160/160** hand expectations agree.
  - Both JSONL files equal their generators.
  - **481 generated stores:** **365 resolve**, **116 INVALID**.
  - **401** have Parquet images; **352** both resolve and have images.
  - Independently counted **1,001 distinct qualifying five-tuples**, versus **1,003 occurrences**: **696 value states**, **305 retractions**. Every counted key is non-evidence, mapped into U, has at least two eligible revisions, and has an entry known by the query time.
  - Without the final store: **999 pairs**.
  - Independently materialized and round-tripped all **401 generated images**, totaling **7,653 Parquet files**.
  - All coverage floors pass; smallest REACHED count **68**. Observation disagreements: **0**.

**Lean fidelity:** beyond the Parquet contract issue above, **no findings**.

**Tests:** Python store suite **26 passed, 6 xfailed**. With xfails disabled, the three ungarbled cases fail because production gives no refusal; the three garbled cases fail inside production decoding with `ComputeError: … Invalid thrift: bad data`—the recorded reasons, not fixture failures. Rust declaration tests: **5 passed**.

The Rust staging namesakes and remaining production-loader comparison tests remain absent, explicitly deferred to slice 5. They cannot currently support a C7.6 pass; no additional finding on that authorized deferral.

**Seam behavior:** no active production Python store read bypasses it. Parent-versus-current comparisons produced identical revisions and **48 identical `as_of` results**. No result-changing seam defect found.

**Verdict: revise first.**
