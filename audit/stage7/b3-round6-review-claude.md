# B3 round 6 review (Claude): the fifth round's findings answered

**Date:** 2026-11-04 11:48 UTC (06:48 EST). **Model:** Claude Opus 5.5 (fresh session, independent reviewer).
**Reviewed:** `4230c36` (`claude/stage7-b3-round6-fix-gtfer7`), against `b3-round5-review-gpt.md` (findings 1–5) and
`b3-round5-review-claude.md` (findings 1–5). Below, `draft/` is `audit/stage7/b3-draft/` and `suite:N` is a line of
`draft/resolver_suite.py`. The draft was not changed.

**Run here, at `4230c36`:**
- `lake build refmm`: 108 jobs, success. Then `draft/lean_check.py`, exit 0:
  - hand: 160 of 160 agree with Lean; both files equal `HAND` and `generate()`;
  - generated: 481 stores, 365 resolve, 116 INVALID, 401 with a Parquet image;
  - size: 1,001 distinct delivered pairs, against at least 1,000;
  - REACHED floors: the fewest are raised to replaced (68) and derived bound past fetchedAt (86);
  - observations: 0 disagreements.
- `resolver_suite.py` run directly fails on `import ingest` without `PYTHONPATH=.`, and has no `__main__` anyway; it
  runs as a module through `lean_check.py`.
- An independent count, written from C7.6's text and not from `delivered` or `image` (its own duplicate-refusing
  reader and int64 check, cells compared type-sensitively), over Lean's results on `resolver_generated.jsonl`:
  1,001 distinct (store, source, entity, event time, query time) pairs; 1,003 occurrences before deduplication; 999
  without the last store, which is the first prefix reaching 1,000; no two generated stores identical. Every image case
  has its version and queries inside int64.
- `pytest ingest/tests/test_store.py`: 17 passed, 3 xfailed. With `--runxfail`, the three strict xfails fail inside
  the loader, at `ingest/store.py:72` (`pl.read_parquet` in `Store.revisions`, called from `as_of` at `:114`), with
  `polars.exceptions.ComputeError: … Invalid thrift: bad data`: the reason `STAGING` and `holdout-staging.md` state.
  The control `test_a_loader_reading_every_column_first_fails_test_3` passes on all three fixtures.
- A probe loader (below, finding 1) that reads every column first but survives a decoding error passes all three of
  test 3's checks, and on an ungarbled store reads every column of the holdout row before refusing it.

## 1. The round 5 findings

| Finding | Answered at its cause? | Where |
|---|---|---|
| GPT 1, duplicate Parquet field names | Yes: such a file makes the dataset invalid, and test 2 names it. "Schema" is unqualified while a column's type comes from `ARROW:schema`; see note 2. | `rules-revision.md:147-148`; `c76-revision.md:52` |
| GPT 2, 1,001 occurrences but 999 pairs | Yes: the size counts distinct 5-tuples, and the suite grew to 481 stores. Reproduced independently (above). | `c76-revision.md:33-36`; `suite:630` |
| GPT 3, a fetchedAt with no Int64 image | Yes: such a case has no image and leaves the comparison and the size. | `c76-revision.md:28-30`; `suite:611-612` |
| GPT 4, the variant failed in its own setup | Yes: `staged` writes the Double before garbling, and the variant now fails in `store.py:72`. | `test_store.py:186-198`, `:260-264` |
| GPT 5, the Rust namesakes do not exist | Noted, not acted on (decision of 11:23 UTC (06:23 EST)). Still true: nothing in `kernel/mm/tests/` names test 3. No outcome changes before slice 5, since C7.6 cannot pass without them. | `c76-revision.md:59-60` |
| Claude 1, same as GPT 4 | Yes | as GPT 4 |
| Claude 2, test 3 passes a loader reading everything first | Only for a loader that fails at its first undecodable byte. The path and the message are fixed, but the garbled-chunk design cannot see a read that does not raise: see finding 1. | `test_store.py:206-244` |
| Claude 3, a second definition of invalidity | Yes, in part: the refusal is the check's own. It created a new gap, which store the comparison runs on (finding 2), and "LO to HI" is undefined in any text (finding 3). | `c76-revision.md:55-59` |
| Claude 4, `upstream` reserved for derived sources only | Yes: SOURCES.md now reserves it for every source, as `mm` and Lean do. | `kernel/SOURCES.md:57`; `Main.lean:413` |
| Claude 5, the fetchedAt −2^63 − 1 hand case | Yes, as GPT 3. | `suite:206` |
| Claude note, the empty exclusion clause | Deleted. Lean's `differs` (`Ref/Resolve.lean:75`) compares values, role columns, times, event, slot and entity, the declared columns, less `fetchedAt` (reserved) and revision columns (none: SOURCES.md has no such field, every declaration says `"revisions": "latest"`). Faithful. | `rules-revision.md:62-63` |

## 2. Findings, most severe first

**1. Test 3 still passes a loader that reads every value column before the holdout check, if the loader survives a
decoding error. High.**
- **Where:** `c76-revision.md:54-67`; `ingest/tests/test_store.py:206-244`.
- **The cause:** the fixture shows a read only when the read raises. Garbled chunks make a premature read visible only
  to a loader that fails at its first undecodable byte. A loader that decodes every column, keeps a decoding failure
  as a per-row or per-file result, makes the holdout check over the event times, and only then reports invalidity
  gives exactly the refusals test 3 expects. This order is a natural one, for example in Rust, where each chunk decodes
  to a `Result` that is checked later. The control (`unstaged`) is only the eager member of the non-staged family.
- **Reproduced:** this probe passes `refuses_crossing` on both `IN_HOLDOUT` rows and `refuses_uncheckable` on
  `UNDECODABLE`. On an ungarbled store with a row in the holdout, it reads that row's every column before it refuses:
  ```python
  for f in files:
      try: frames.append(pl.read_parquet(f))                      # every column, holdout rows included
      except pl.exceptions.PolarsError: bad.append(f); frames.append(pl.read_parquet(f, columns=["eventTime"]))
  # then: a non-Int64 event time → "the holdout check cannot be made"; one ≥ HOLDOUT_START → "holdout crossing: event
  # time … at or after …"; then `bad` → "invalid dataset"
  ```
- **Outcome it could change:** C7.6's named test 3, the only evidence that the holdout check reads only event times
  first, passes on a Python or `mm` loader that brings holdout rows' values into the process before refusing them:
  the premature holdout access that GPT's round 4 finding 3 named. The text's rule ("nothing but the event-time column
  is read") stays true as a rule, but the test named for it does not decide it.
- **Fix:** test what is read, not what fails. For example, each loader opens files through one byte-range reader on
  its production path (pyarrow's `NativeFile` or a file object for Python, Rust's `ChunkReader` for `mm`), and the test
  wraps it, recording the ranges read up to the refusal. It then asserts that none of them meets a column chunk other
  than the event time's, using the footer's byte ranges as the garbling does now. The garbled store can stay as a
  second check. The control then becomes this probe loader, which must fail.

**2. The text does not say whether the loaders' comparison runs with a holdout check, and with one, hand cases that
resolve are refused. Medium.**
- **Where:** `c76-revision.md:21-30` (the image), `:54-59` (the check reads "every row … post-V rows too");
  `ingest/store.py:138` (only the search store has `event_before`); `suite:228`.
- **The gap:** test 3 says the holdout check reads every row's event time and refuses one that is not an integer in
  range, or one in the holdout. Test 1 says each case "is written into the store's Parquet layout" and read by
  `store.as_of`, "the production path its callers read". The text never says which store that is, or whether the
  holdout check is part of what is compared. The counts below come from my own scan of the cases with an image:
  - 8 hand cases hold an event time that is not an integer in range. In 7 the row is eligible (Lean: INVALID; the
    check: "cannot be made", which is not a §7 result). In 1 it is past V and resolves (`suite:228`, a Double event
    time at V = 199).
  - At least 2 hand cases resolve with an event time at or after `HOLDOUT_START` (hand cases 26 and 45, event times
    near 2^62).
  - No generated store does either, so the size is unaffected.
- **Failure:** on the search store, Python's and `mm`'s loaders refuse cases that Lean and GPT's resolver resolve, or
  return a refusal where they return `"INVALID"`. Test 1's "every case" then fails spuriously, or a builder exempts
  cases by hand.
- **Outcome it could change:** C7.6's resolver part (test 1's agreement on the hand cases).
- **Fix:** one sentence in "How the loaders read a case". For example: "each case is read from a store with no
  holdout bound, so the holdout check is not part of the comparison; test 3 alone tests it." Or say which cases leave
  the comparison, and why.

**3. "LO to HI" is defined in no text. Low.**
- **Where:** `c76-revision.md:57`. LO and HI are constants of `kernel/tests/rules/suite.py:21`. RULES.md calls the
  interval "the range" (`kernel/RULES.md:38`).
- **Failure:** `mm`'s namesake test, or GPT, written from the text, must guess the bound: ±2^62 (RULES.md's range, as
  the event column's "in range" in §6) or int64's.
- **Outcome it could change:** whether an Int64 event time between 2^62 and 2^63 − 1 is uncheckable or checked against
  the holdout, so the refusal Python and `mm` give. Both refuse, so nothing leaks.
- **Fix:** "an integer in RULES.md's range [−2^62, 2^62 − 1] (in Parquet, a non-null Int64 in it)".

**4. The crossing refusal's content is required more loosely in the text than in the test. Low.**
- **Where:** `c76-revision.md:56` ("names the holdout boundary and the crossing row's event time, both as integers");
  `test_store.py:206-209` (the literal word `holdout`, and each integer's decimal `str`, as substrings).
- **Failure:**
  - "Names … as integers" does not require the word "holdout" or decimal digits.
  - A Rust refusal reading "crossing: 1775178000000 ≥ boundary 1775174400000" meets the text and fails a Python-style
    check.
  - A refusal reading "… 1,775,174,400,000" meets the text and fails the test.
- **Outcome it could change:** a spurious failure of `mm`'s namesake test, written from the text, or two tests that
  test different things under one name. No leakage either way.
- **Fix:** state it as the uncheckable refusal is stated: "contains `holdout`, and the boundary and the crossing event
  time in decimal".

**5. "RULES.md §6 alone defines" dataset invalidity, but SOURCES.md §2's revision defines it too. Low.**
- **Where:** `c76-revision.md:58-59`; `rules-revision.md:146-148`.
- **The contradiction:** SOURCES.md §2's revision makes the dataset invalid "whatever V" for a `fetchedAt` of
  another type or holding a null, for a `tombstone` of another type, and now for a duplicated column name. All of
  these go beyond §6's "revisions fetched after V are not examined". A file naming `eventTime` twice is in neither
  test, and the text does not order the holdout check and this invalidity.
- **Outcome it could change:** which refusal a loader gives on a store whose file duplicates a column. It is a refusal
  either way, so no leakage. A builder told that §6 "alone" defines invalidity can reasonably skip the Parquet-level
  rules.
- **Fix:** "That is not dataset invalidity (RULES.md §6 and SOURCES.md §2)". Optionally say the schema checks, which
  read only the footer, come first.

## 3. Notes (no outcome)

1. `resolver_suite.py` cannot be run directly (`ModuleNotFoundError: ingest` without `PYTHONPATH=.`). Its docstring
   does not claim it can, and `lean_check.py` runs it correctly.
2. "a file whose schema names one column twice": a column's type comes from `ARROW:schema` where present, but nothing
   says which schema's names count when the Parquet schema and the embedded Arrow schema disagree. Reading "either"
   would decide it one way. No outcome on files the store writes.
3. `rules-revision.md:14-15` still lists the §6 part's sources through round 4, though round 6 changed timeline step 1.
   The provenance is incomplete only.
4. `holdout-staging.md` keeps a parenthesis on round 5's failure ("Round 5's variant failed in its own setup instead").
   That is history, which git already holds; it could go.
5. The size clears its floor by 1 distinct pair (999 without the last store). Any disagreeing participant fails anyway,
   so the margin carries no risk.

**Verdict: revise first.** Test 3 decides staging only for loaders that fail on their first undecodable byte (finding
1), and the comparison's store is unspecified against the holdout check (finding 2). Findings 3–5 are one sentence
each.
