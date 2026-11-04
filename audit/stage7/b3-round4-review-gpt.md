# Review of B3 round 4 (f1fe5f7)

GPT (`openai/gpt-6.1-sol#high`, opencode), independent review from a clean worktree (no `data/`), at `f1fe5f7`; started 2026-11-04 10:24 UTC (05:24 EST), reply received 10:33 UTC (05:33 EST). The reply as given, tool transcript omitted.

   `audit/stage7/b3-draft/c76-revision.md:23–28,31–36`; `audit/stage7/b3-draft/resolver_suite.py:594–611`.  
   The generator counts resolving cases that the same specification says have **no Parquet image**. Nine resolving generated stores contain malformed, post-V `cells` texts. Three contribute counted pairs: generated lines **25, 116 and 206**, contributing **3, 4 and 7** respectively. Excluding cases unavailable to the loaders leaves **988 pairs**, including **777 multi-revision pairs**, not 1,002/787. Silently dropping their malformed rows is not the specified image.  
   **Judged outcome:** C7.6 can claim its 1,000-query production-comparison floor without reaching it.

2. **High — Valid declarations can require two different values in one Parquet column.**  
   `audit/stage7/b3-draft/rules-revision.md:98–108,142–145`; `audit/stage7/b3-draft/c76-revision.md:23–26`.  
   No declaration rule reserves metadata column names (`kernel/SOURCES.md:43–50`). For example, declare `fetchedAt` as a value column, give the revision metadata `fetchedAt: 100`, and put `"fetchedAt": 7` in `cells`. Lean accepts this and delivers **7** as the value. Its required Parquet image needs the single `fetchedAt` column to hold both **100** and **7**. A derived value column named `upstream` similarly collides with lineage storage. Neither the text nor registry checking rejects these declarations.  
   **Judged outcome:** conforming JSON and Parquet participants cannot agree; eligibility, availability or delivered strategy values can change.

3. **High — The newly named holdout-staging test does not exist.**  
   `audit/stage7/b3-draft/c76-revision.md:52–58`.  
   `test_holdout_check_reads_event_times_alone` exists in neither `ingest/tests/test_store.py` nor `kernel/tests/`; its only repository occurrences are prose. Neither specified corrupted-column fixture nor positive control exists. The existing Rust staging test supplies a vector through a mock callback (`kernel/mm/tests/admission.rs:156–169`); it cannot detect opening Parquet value columns prematurely. Python still eagerly reads complete files (`ingest/store.py:72`). Naming the missing executable test has not answered the earlier finding at its cause.  
   **Judged outcome:** the claimed staging check provides no evidence against premature holdout-value access.

4. **Medium — The “delivered” counter uses recording time, not delivery time.**  
   `audit/stage7/b3-draft/c76-revision.md:31–36`; `audit/stage7/b3-draft/resolver_suite.py:608`.  
   A counted query need only follow an entry’s **fetchedAt**, although delivery occurs at **knownAt**. **189 counted pairs precede every entry’s knownAt.** For example, generated case 2 counts a BTC bars query at **28,801,000**, despite its first entry being known only at **36,120,000**. Across the suite, only **854 pairs** have any entry due by the query, including **635 multi-revision pairs**; **655** have a visible non-retraction. Negative-answer tests are useful, but the text’s assertion that these are pairs where the loaders “deliver them” is false.  
   **Judged outcome:** C7.6 can report 1,000 delivered comparisons while testing substantially fewer actual deliveries.

5. **Medium — Lean silently converts oversized metadata integers to zero.**  
   `reference/lean/Main.lean:19–21,482–485,571–574`.  
   Stored texts use the new exact-integer reader, but the surrounding case still uses `Ref.Json.parse`. With an otherwise ordinary bars fixture, `fetchedAt: -9223372036854775809` and version 100, that reader produces a float; `int!` panics and supplies its default **0**. Reproduction exits successfully and emits a normal observation recorded at **0**, instead of `INVALID` for the eligible out-of-range fetchedAt required by `kernel/RULES.md:181–183`.  
   **Judged outcome:** the reference can accept an invalid dataset and disagree with a correctly rejecting independent resolver.

6. **Medium — Frozen-file verification still conflates booleans and numbers.**  
   `audit/stage7/b3-draft/lean_check.py:80`.  
   File equality uses Python’s ordinary `==`, not the type-sensitive `same`. Changing an expected timeline’s retraction flag from `false` to integer `0` still compares equal. The checker then tests the in-code `HAND`, not that altered file expectation, so it can report “files equal” and pass semantically different frozen evidence.  
   **Judged outcome:** C7.6’s frozen-suite identity check can pass an incorrectly typed expected result.

## Previous findings

| Round-3 finding | Round-4 assessment |
|---|---|
| GPT 1; Claude F1 | Not closed: findings 1 and 4 above. |
| GPT 2 | **No findings:** Utf8 and LargeUtf8 now share the string mapping. |
| GPT 3 | Not closed: finding 3 above. |
| GPT 4; Claude F5 | **No findings** on declared-cell integer bounds and integer-to-binary64 rounding. Metadata remains a separate defect above. |
| GPT 5 | **No findings:** missing result cardinality now fails. |
| GPT 6 | **No findings:** signed-zero entities are deduplicated. |
| GPT 7 | **No findings:** changing the returned retraction slot now removes the coverage tag. |
| GPT 8 | **No findings:** retraction timestamps are retained explicitly. |
| Claude F2 | Decoding text corrected; **no findings** on those mappings. Executable loader coverage remains absent. The reported real-store census cannot be independently checked here. |
| Claude F3 | **No findings:** upstream-entry wording corrected. |
| Claude F4 | **No findings:** the carve-out now constrains store pairs, not arbitrary output differences. |
| Claude F6 | **No findings:** malformed undeclared surrogate and duplicate-member cases exist and pass. |
| Claude F7 | Not fully closed: file naming and non-cell images are specified, but findings 1 and 2 prevent a complete loader comparison. |

## Reproduced checks

Ran `resolver_suite.py` with `PYTHONPATH=.`, `lake build` in `reference/lean`, then `lean_check.py`.

- Build succeeds; **149/149** hand cases agree.
- Both JSONL files equal `HAND` and `generate()`.
- **304** generated stores: **235 resolve**, **69 INVALID**.
- Reported size: **1,002 / 787**; Parquet-image-only size: **988 / 777**.
- Every coverage floor passes; the smallest REACHED count is **42**.
- **0** observation-projection disagreements. This remains Lean against its own timelines, not the production loaders.

**Verdict: revise first.**
