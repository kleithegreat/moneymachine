# Review of B3 round 9 (d944cc5)

GPT (`openai/gpt-6.1-sol#high`, opencode), independent review from a clean worktree (no `data/`), at `d944cc5`; started 2026-11-06 17:55 UTC (12:55 EST), reply received 18:00 UTC (13:00 EST). The reply as given, tool transcript omitted.

## Verdict: revise before freezing

Round 9 restores the decode boundary required by `kernel/SOURCES.md:174–183`. The resolver design does not need another reversal. **However, two test-design defects remain, plus one structural-review wording gap. This is not wording-only.**

### 1. Medium — Result-bearing output is still permitted on stderr

**Place:** `audit/stage7/b3-draft/c76-revision.md:86–87`; `ingest/tests/test_store.py:270–276`.

**Defect:** stdout must be empty, but stderr need only remain invariant. That does not enforce “no result-bearing output” on a refused evaluation (`kernel/SOURCES.md:173,182–183`). This leaves GPT round 8 finding 3 only partially answered.

**Concrete scenario:** a loader projects only the event-time column, prints the number of pre-holdout rows to stderr, and raises the correct refusal. It decodes no forbidden column, its statistic stays constant across the variants, and it retains no state. Both halves as described accept it, just as they accept a silent loader, although only the silent loader satisfies the output prohibition.

I exercised the existing assertion functions with in-memory fixtures: this stderr-statistic model passes all three fixture classes.

**Outcome affected:** C7.6 can accept an evaluation that refuses yet releases a computed research statistic. The paper expressly treats disclosures from rejected candidates as information that can influence selection (`docs/whitepaper.tex:154,315`).

**Required fix:** **test-design change**, not merely wording. Require no stderr output, or restrict it to explicitly permitted refusal diagnostics; invariance alone is insufficient.

### 2. Medium — The state test rejects permissible caching of authorized event times

**Place:** `audit/stage7/b3-draft/c76-revision.md:88–89`; `ingest/tests/test_store.py:268–276`.

**Defect:** removing a file and demanding that the same loader behave like a fresh loader conflates forbidden payload retention with legitimate snapshot or event-time caching. The decode rule permits retaining event times. Moreover, `SOURCES.md:184–186` requires evaluation of pinned bytes, never a reopened path.

**Concrete scenario:** two loaders decode only event times and refuse correctly:

- one refreshes its file inventory on every call;
- another retains the projected event-time inventory for its immutable dataset identity.

After the test deletes the late file, the first can match a fresh loader; the second correctly retains the original crossing, or reports an integrity failure. The criterion fails the second despite no forbidden materialization. An in-memory model retaining **only the authorized inventory** fails the existing checker at `state` on all three fixtures.

**Outcome affected:** a correct loader can fail C7.6, potentially encouraging path-reopening or cache invalidation that the immutable-snapshot contract does not require.

**Required fix:** **test-design change**. Test contamination across explicitly distinct dataset identities/snapshots using the production API. Do not make deletion invalidate an already-pinned snapshot implicitly.

### 3. Low — Structural review stops at “the check,” rather than covering every refusal path

**Place:** `audit/stage7/b3-draft/c76-revision.md:71–77,90–94`; `ingest/tests/test_store.py:359–368,463–464`.

**Defect:** the governing rule correctly says **before the check passes**, but the structural procedure says the check “precedes any other read” and reviewers follow the path “to the check.” Those are weaker instructions. Several amendment controls actually decode values **after catching the refusal**, contrary to the claim that every control decodes before the check.

**Concrete scenario:** a loader projects event times and checks first, then its exception formatter reads `coin`, appending extra information only for `"BTC"`. The supplied variants use `"A"` or generated numeric strings, so that branch need not affect the net. A reviewer stopping at the check can approve the specified projection/order, while a reviewer following the refused path rejects the forbidden decode.

**Outcome affected:** inconsistent structural C7.6 verdicts; a post-check, pre-exit holdout decode can escape the prescribed review scope.

**Required fix:** **wording only**. Require every non-event-time decode or statistic use to be reachable only after **successful completion of the whole holdout check**, and review all failure paths through refusal, diagnostics and cleanup.

## Round 8 disposition

| Finding | Round 9 assessment |
|---|---|
| GPT 1 / Claude 1: premature materialization accepted | Governing rule corrected; finding 3 above concerns review scope. |
| GPT 2 / Claude 2: leaking probes pass | Separate channels, additional variants and named rejecting controls answer the reported probes. The net is appropriately no longer claimed sound. |
| GPT 3: invariant result-bearing output | **Partially open:** finding 1 above. |
| Claude 3: leaf versus top-level schema names | Answered explicitly. |
| Claude 4: eligible/live and shared-file cases missing | Added; evidence/outside-U cases explicitly assigned to Rust’s deferred namesake. |
| Provenance notes | No substantive issue remaining. |

I found no additional resolver or cell-mapping design defect. Both JSONL files match their stated hand construction/generated input prefix. I did not rebuild Lean or run file-writing tests; the probes above used existing assertion functions in memory. No files were changed.
