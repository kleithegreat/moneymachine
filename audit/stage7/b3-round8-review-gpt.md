# Review of B3 round 8 (f130354)

GPT (`openai/gpt-6.1-sol#high`, opencode), independent review from a clean worktree (no `data/`), at `f130354`; started 2026-11-04 12:53 UTC (07:53 EST), reply received 13:05 UTC (08:05 EST). The reply as given, tool transcript omitted.

## Findings, most severe first

### 1. High — Non-interference alone weakens the specified holdout boundary

**Locations:** `audit/stage7/b3-draft/c76-revision.md:66–79`; `ingest/tests/test_store.py:297–310`.

The draft explicitly accepts a loader that decodes every column before checking holdout event times. That is weaker than the existing specification:

- `kernel/SOURCES.md:174–177`: access stages each read “no more than [they need]”; the holdout stage operates on event-time columns “alone,” **then resolution**.
- `kernel/SOURCES.md:182–183`: a search evaluation “never materializes a holdout observation or a value derived from one”; refusal occurs **before resolution**.
- `reference/lean/Ref/Source.lean:226–230` documents the corresponding loader obligation: `rows` reads only event times.
- `reference/lean/Ref/Resolve.lean:187–188` explicitly leaves this staging obligation to executable tests.

**Judgment:** the earlier **semantic read-order restriction** was required. I8 (`kernel/INVARIANTS.md:16`) alone specifies abort-at-load, not a byte-access discipline; SOURCES.md supplies the stronger staging requirement. Non-interference is necessary but not sufficient.

This does **not** vindicate the earlier byte-range instrument. Reading a footer or hashing opaque bytes is not necessarily materializing an observation, and the instrument permitted footer statistics that can reveal a one-row column’s exact value. Its untracked-read loophole also remained. Those were reasons to repair the claimed boundary and its measurement—not to permit full payload decoding.

Under complete output non-interference, the measured refusal/output would disclose no changed holdout content, but decoded holdout values could still exist in frames, caches or other process state. Semantic read-order prevents that premature materialization. The new passing witness deliberately performs it. Lean’s pure non-interference theorem, `L5_staged`, does not establish that an implementation avoided those reads.

**Outcome affected:** C7.6 test 3 could certify a loader violating SOURCES.md’s holdout authorization, while the revision claims it “loosens nothing” (`c76-revision.md:13`).

### 2. High — Test 3 passes loaders whose output or refusal depends on holdout values

**Locations:** `ingest/tests/test_store.py:184–185`, `205–214`, `227–233`.

I substituted loaders **in memory only** and ran the three production-facing cases with `--runxfail`.

**A. Leakage across the supplied variants:** after obtaining the correct event-time refusal, decode the late row’s rate where possible; print identical text to **stderr if the rate is negative**, otherwise to stdout; then raise the correct refusal.

All three cases passed, covering all fifteen fixture variants. Channel selection for each fixture was:

```text
stdout, stderr, stdout, stdout, stdout
```

Thus the supplied `1.0` versus `−7.25` variants disclose a holdout-derived bit. The test loses that distinction at line 214:

```python
printed.out + printed.err
```

It compares concatenated contents, not the two observable channels.

**B. Refusal-message leakage:** append `rate_above_100=<boolean>` to the correct refusal, using false when the rate cannot decode. This also passed all three cases. With unchanged event times, changing only the late row’s rate from `1.0` to `200.0` changed the accepted refusal suffix from false to true. The fixed variants never exercise that partition.

These are actual counterexamples to the proposed test deciding its rule—not merely premature reads with invariant output.

**Outcome affected:** C7.6 test 3 could pass despite an externally observable holdout-value leak, even under the newly weakened non-interference interpretation.

### 3. Medium — Equal output does not establish “no result-bearing output”

**Locations:** `ingest/tests/test_store.py:227–233`; `audit/stage7/b3-draft/c76-revision.md:67–70`.

The assertion permits any output provided it remains equal across variants. It does not enforce SOURCES.md’s prohibition on result-bearing output from a refused evaluation.

I substituted a loader that prints the sum of eligible, pre-holdout rates and then invokes `surviving`. All three production-facing cases passed with `--runxfail`; each variant printed:

```text
pre-refusal rate sum: 1.0
```

That is a computed data statistic emitted before refusal. Its invariance under changes to the late row does not make the disclosure permissible.

**Outcome affected:** C7.6 could certify a refused evaluation that nevertheless releases a research statistic, contrary to `kernel/SOURCES.md:173` and `182–183`.

## Round 7 findings: cause-level disposition

| Round 7 item | Assessment |
|---|---|
| GPT 1 / Claude 1: reads outside the instrument | **Not closed at its cause.** The instrument and obligation were removed; premature materialization is now explicitly accepted. Finding 1 above. |
| GPT 2: physical duplicates hidden by embedded-schema precedence | **Answered in the draft text:** either schema’s duplicate names, or disagreement in names, invalidates the file (`rules-revision.md:147–148`). No additional findings. |
| Claude 2: footer statistics contradict the read claim | The literal byte-read contradiction is removed, but the stronger authorization boundary is not preserved. Findings 1–2 above. |
| Claude 3: schema-check membership and order | **Answered:** explicit footer checks; null `fetchedAt` is checked afterward (`c76-revision.md:58–66`). No findings. |
| Claude 4: boundless Rust comparison path | **Answered:** `market::load(..., holdout=None)` is named (`c76-revision.md:30–33`). No findings. |
| Claude 5: `ChunkReader` instrumentation | The faulty instrument is deleted, so its measurement problem disappears. This does not discharge the original staging obligation. |
| Grammar/provenance notes | Addressed; no findings. |

## Whole-draft checks

Executed at `f130354`, without editing repository files:

- `PYTHONPATH=. python audit/stage7/b3-draft/resolver_suite.py`: success; no standalone checking entry point.
- `lake build` in `reference/lean`: **success, 109 jobs**.
- `lean_check.py`:
  - **160/160** hand expectations agree.
  - Both JSONL files equal their generators.
  - **481 generated stores: 365 resolve, 116 INVALID.**
  - **401** have Parquet images.
  - **1,001 distinct qualifying delivered pairs**; all coverage floors pass.
  - **Zero observation disagreements.**

Independent recount and materialization confirmed:

- **352** generated stores both resolve and have images.
- **1,001 distinct pairs**, versus **1,003 occurrences**: **696 value states, 305 retractions**.
- Every counted key is non-evidence, mapped into U, has at least two eligible revisions, and has an entry known by its query time.
- **999 pairs without the final store.**
- All **401 images**, comprising **7,653 Parquet files**, were materialized and round-tripped.

**Other resolver rules, JSON/Parquet cell mappings and Lean resolver fidelity:** no additional findings. The staging-contract discrepancy is finding 1; passing Lean comparisons cannot settle it.

**Named tests:** Python store suite: **26 passed, 3 xfailed**. With xfails disabled, production fails all three staging cases for the recorded missing-check/decoding behavior. The nine rejecting-control cases and three accepting-witness cases pass, but findings 1–3 limit what they establish. Rust declaration tests: **5 passed**.

The Rust staging namesake and the remaining production-loader comparisons remain deferred to slice 5 (`audit/stage7/b3-draft/README.md:32–38`); they are not existing C7.6 pass evidence. No additional finding on that documented deferral.

**Verdict: revise first.**
