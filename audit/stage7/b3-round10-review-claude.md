# Review of B3 round 10 (8750c16)

Fresh Claude (Opus 5.5, `claude-opus-5-5-high`, through the Antigravity CLI `agy` 1.4.8 on the human's Google AI Pro plan), the review at the freeze, from a clean worktree (no `data/`) with reads only (commands, writes and web denied in its settings), the round 10 diff given as a file; started 2026-11-06 19:41 UTC (14:41 EST), reply received 19:45 UTC (14:45 EST). The reply as given.

# B3 round 10 review (commit 8750c16)

**Verdict: only wording is left. Under the human's rule, fix the wording below and B3 freezes.**

Round 10 answers all three round 9 findings. Nothing I found needs a design change. Every item below can change a verdict, but each is fixed by a sentence in the criterion. Two also need a small edit to a test fixture, and neither edit changes what is tested.

Scope: I read CLAUDE.md, PROGRESS.md, the whole draft directory, the round 8 and round 9 reviews, the B3 entries in `audit/decisions.md`, the round 10 diff, SOURCES.md, the relevant parts of the paper (§§154, 315), `ingest/store.py`, `ingest/tests/test_store.py` and `kernel/mm/src/market.rs`. I could not run anything. The resolver text, the Lean check and the suite are unchanged since round 9, which GPT checked independently. I re-checked them by reading only.

## Round 9 findings

| Round 9 finding | Round 10 | Status |
|---|---|---|
| 1. stderr only had to be invariant | stdout and stderr must both be empty, and the exception message must be exact ([c76-revision.md L87-91](audit/stage7/b3-draft/c76-revision.md#L87-L91); [test_store.py L261-263](ingest/tests/test_store.py#L261-L263)). The new `counting` control fails at `stderr`. | Closed |
| 2. The state test punished legitimate caching | The test now checks a separate, unchanged dataset, and caching each dataset's event times passes ([L264-267](ingest/tests/test_store.py#L264-L267)). `persisting` still fails at `state`, because its cache is keyed by file name across datasets. | Closed, but the new permission is worded too loosely (finding 1) |
| 3. Structural review stopped at "the check" | The rule is now "until the whole holdout check completes successfully", and reviewers follow every refusal, diagnostic and cleanup path ([L71-78](audit/stage7/b3-draft/c76-revision.md#L71-L78)) | Closed; what "whole" covers is unclear (finding 4) |

## Findings, most severe first

### 1. Low–Medium: the new caching permission doesn't tie the check to the bytes decoded afterwards (wording)

- **Where:**
  - [c76-revision.md L93-95](audit/stage7/b3-draft/c76-revision.md#L93-L95): "Dataset-scoped caching of authorized event-time inventories is permitted; deletion never implicitly invalidates a pinned snapshot", and the passing loader at L103-104.
  - The positive control [`projecting`](ingest/tests/test_store.py#L297-L306).
- **Defect:** For Python, a "dataset" is a name, and the name is a directory that only grows. `projecting` caches the event times by that name with no check that the files are the same, then decodes everything by re-listing the directory (`everything(root, dataset)`). So the check runs on the files as they were at the first call, while the decode reads the files as they are now. SOURCES.md §7 decides "by immutable dataset identity … never by names, paths", and evaluation "reads those admitted bytes, never a reopened path". The permission as worded doesn't say so, and the control shows the opposite shape as the one that passes.
- **Scenario:**
  1. A slice-5 `as_of` is written the way `projecting` is.
  2. A long-lived search `Store` serves `bars_4h`.
  3. A Parquet file with a row past the holdout is then added to `store/bars_4h` by any route other than `Store.write`, which is exactly what the read-side check exists to catch.
  4. The next call passes the check on the stale cache, then decodes and returns the holdout row.

  Reviewer A passes it: caching is explicitly permitted, and decoding follows a successful check. Reviewer B fails it under SOURCES.md §7. The net can't tell them apart because its datasets never change.
- **Outcome it could change:** the structural verdict on test 3, and whether I8 actually holds on reads. That is a leakage outcome.
- **Fix (wording):** "An event-time inventory may be kept only for the immutable bytes it was read from (the pinned file set and its identity). Whatever is decoded after the check comes only from those bytes; a changed file set is a new dataset identity, checked again." In the test, make `projecting` pin its file list and decode those files. That is a fixture edit; the net passes either way.

### 2. Low: the exact-refusal and silence rules are written for Python only; `mm`'s versions are not named (wording)

- **Where:** [c76-revision.md L80-81, L87-97](audit/stage7/b3-draft/c76-revision.md#L80-L97): "facing the same fixtures and variants", "Each call must raise `ValueError` with exactly …", "Nothing may be printed on stdout or stderr", "its production API".
- **Defect:** Rust has no `ValueError`. The text doesn't name `mm`'s production API for the test (L32 names `market::load` only for the comparison), what plays the exception, or which string must match. Today `market::load` refuses with `LoadError::Holdout("row with eventTime {event} >= holdout start {h}")` and names the first crossing it reads, not the least ([market.rs L334](kernel/mm/src/market.rs#L334)). Slice 5 is expected to change that, but the frozen text must say what has to match. Also, SOURCES.md §8 lets commands print once the ledger record is written.
- **Scenario:** Two writers of `mm`'s namesake, one `mm`:
  - One compares `LoadError::Holdout`'s message exactly.
  - Another compares the error's `Display`, which can carry a variant prefix.
  - A third drives the `mm eval` binary, the real production entry point, which prints its refusal code on stderr.

  On the same `mm`, the first can pass while the second and third fail on "exactly" or "nothing on stderr".
- **Outcome it could change:** whether test 3 passes for `mm`, and so C7.6. No leakage risk.
- **Fix (wording):** "For `mm`: `market::load` (or its slice-5 replacement) with `holdout` Some; its `Err`'s `Display` is exactly the same string; nothing is written to the process's stdout or stderr. A distinct dataset is a distinct store root."

### 3. Low: "contains" in the rule against "exactly" in the net, and exact type against `ValueError` (wording plus one test line)

- **Where:**
  - The rule says a crossing refusal "contains `holdout`, the boundary and the least crossing event time" and the uncheckable refusal is "containing 'the holdout check cannot be made'" ([L62-65](audit/stage7/b3-draft/c76-revision.md#L62-L65)).
  - The net says "exactly" ([L87-89](audit/stage7/b3-draft/c76-revision.md#L87-L89)).
  - The test compares `type(e)` by equality ([L243, L261](ingest/tests/test_store.py#L243-L261)), where round 9 used `issubclass`.
- **Scenario:** Take a slice-5 loader raising `class HoldoutRefusal(ValueError)` with "holdout crossing in bars_4h: event time X at or after B". It meets L62-65, and in Python terms it "raises `ValueError`". It fails the net twice: on the type and on the string.

  A second gap: the uncheckable message "an event time is not an Int64" is wrong for a null or out-of-range Int64, which L63-65 also routes to this refusal. The text pins the message only for the Double fixture, so that is no conflict today, just a trap.
- **Outcome it could change:** whether test 3 passes. No leakage risk.
- **Fix:** state the exact strings once, in the rule at L62-65, and have the net refer to them. Then either say "exactly `ValueError`" or put `issubclass` back in the test.

### 4. Low: what "the whole holdout check" covers is not stated (wording)

- **Where:** [L71-73](audit/stage7/b3-draft/c76-revision.md#L71-L73).
- **Defect:** Python's `as_of` sees one dataset. SOURCES.md §7 runs the event-time stage over all the run's required sources, then resolution. `mm` loads funding, bars and events in one call.
- **Scenario:** A slice-5 `mm` checks funding's event times, decodes funding, then checks `bars_4h` and refuses on a crossing there. One reviewer reads "whole" per dataset and passes it. Another reads it as the required set, per SOURCES.md §7, and fails it. The decoded funding rows are before the holdout, so nothing leaks; only the verdict differs.
- **Fix:** "the whole check: every file of every dataset the call reads (for `mm`, the run's required set)".

### 5. Low: the revision's date label (wording)

- **Where:** [c76-revision.md L11](audit/stage7/b3-draft/c76-revision.md#L11): "Revision of 2026-11-04", together with L107-108, which judge C7.6 "only on evidence produced after this revision". [rules-revision.md L12 and L138](audit/stage7/b3-draft/rules-revision.md#L12) carry the same label.
- **Defect:** The text is still changing on 2026-11-06 and will be committed later. Going by the label, evidence produced on 11-05 or 11-06 under round 9's different test 3 counts as "after this revision".
- **Fix:** date both with the `criteria:` commit's timestamp.

## Notes (no outcome)

- L90 calls the exception's message a "fixed refusal diagnostic", but it carries `{least}`, a value computed from the event times the check is allowed to read. "Prescribed" would be accurate; L91's "no computed result or statistic on any channel" should exempt it explicitly.
- Provenance:
  - [README.md L5-6](audit/stage7/b3-draft/README.md#L5-L6) says "third to seventh" but lists rounds 3–8.
  - Neither the README nor [c76-revision.md L3-5](audit/stage7/b3-draft/c76-revision.md#L3-L5) cites `b3-round9-review-gpt.md` or round 10.
- Two sentences in the criterion are not rules:
  - "deletion never implicitly invalidates a pinned snapshot" (L94-95) no longer refers to anything the test does. Finding 1's wording can replace it.
  - The list of rejected controls (L98-104) describes the test file. Freezing it is harmless, but it can go out of date.
- The section of `holdout-staging.md` written before round 10 still says "one stderr". The file is append-only and its round 10 section supersedes that, which is correct.
- No new defect in the resolver, the cell mapping or the size: round 10 does not touch `rules-revision.md`, the JSONL files or `lean_check.py`. The counts claimed (54 passed, 3 strict xfails, 12 controls) match the test file as I count it.

