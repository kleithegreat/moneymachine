# B3 round 8 review (Claude): test 3 as non-interference

**Date:** 2026-11-04 13:05 UTC (08:05 EST). **Model:** Claude Opus 5.5 (fresh session, independent reviewer; did not build
round 8). **Reviewed:** `f130354` (`claude/stage7-b3-round8-fix-v4fzlu`), the draft under `audit/stage7/b3-draft/`,
`ingest/store.py`, `ingest/tests/test_store.py`, against `b3-round7-review-{gpt,claude}.md`. Draft not changed.

**Run here, at `f130354`:**
- `PYTHONPATH=. python audit/stage7/b3-draft/resolver_suite.py`: exit 0, files unchanged.
- `lake build` in `reference/lean`: 109 jobs, success. `lean_check.py`: hand 160 of 160 agree with Lean; files equal
  HAND and `generate()`; 481 generated stores (365 resolve, 116 INVALID), 401 with a Parquet image; **1,001 delivered
  pairs** (floor 1,000, reached); smallest REACHED count 68 ("raised to replaced"); 0 observation disagreements. Same
  as round 7 (the suite and Lean are untouched by this commit).
- `ingest/tests/test_store.py`: 26 passed, 3 xfailed. With `--runxfail` the three fail as `holdout-staging.md` says:
  no refusal on the first three variants, `SchemaError` on the List, `ComputeError: Invalid thrift` garbled.
- Probes (below, finding 2): four loaders whose refusal depends on, or which keep, the holdout row's non-event-time
  content; all pass `decides_on_event_times_alone` on all three fixtures (12 of 12).

## 1. Question (1): what SOURCES.md and I8 require

**I8** (`kernel/INVARIANTS.md:16`): "any row with eventTime ≥ holdout start aborts the run … Check at load, on every
row." That is an outcome: the run aborts. Non-interference plus the refusal satisfies I8 as written.

**SOURCES.md §7, "Access authorization"** (`kernel/SOURCES.md:174-183`) says more than a dependence property, in three
places: the stages run "each **reading no more than it needs**"; the holdout stage runs "**on the required sources'
event-time columns alone**", with resolution only "Then"; and "A search evaluation **never materializes a holdout
observation** or a value derived from one (I8, generalized): the holdout stages refuse a crossing **before
resolution**". Preflight's paragraph (`:170`) uses "loaded" as the first of "loaded, initialized, delivered or
evaluated", so loading a row is already materializing it. The text is a read (materialization) limit with the dependence
property as its consequence, not the dependence property alone. The decision of 12:38 UTC (07:38 EST) quotes the
second and third phrases and drops the first and the "never materializes".

So the answer is: **the earlier rule's substance was required, and round 8 weakens the boundary below SOURCES.md.**
Rounds 4–7 over-read in one respect only: "read" meant bytes, and bytes must be read for things SOURCES.md requires
earlier (the footer; `mm`'s dataset identity, which hashes every byte, `:175`, "a search's holdout dataset identities"
on metadata). The required rule is a *decode* limit: before the check passes, no column chunk but the event time's is
decoded, and nothing derived from one is kept. Round 7's Claude review (finding 1, its fix) already said so. The draft
instead certifies the opposite: `c76-revision.md:77-79`, "A loader that reads every column but survives a decoding
error until the holdout check has refused or passed decides on event times alone, and passes", is a loader that loads
the holdout row before the check, which SOURCES.md forbids.

What can leak under each:
- **Non-interference (round 8):** anything not among the compared refusal and stdout/stderr: the loader's process
  state (the production `Store` keeps every decoded row in `self._cache`, `ingest/store.py:59,68-73`, and `as_of`
  builds on it; `Store.revisions`, called from `ingest/events.py`, `labels.py`, `sources_avail.py`, returns them with
  no check), the ledger record a refusal is written to (SOURCES.md:173, not compared), files and logs written, a later
  call in the same process; and, since the test is a sample (finding 2), any predicate of the values that the five
  variants do not separate, in the refusal itself, which research agents see.
- **Decode limit (rounds 4–7 rule, correctly scoped):** only what the footer exposes before the check (per-chunk
  min/max/null count, which for a one-row file is the value; round 7 Claude finding 2), unless the text forbids using
  it, and whatever the instrument misses. Nothing decoded means nothing to cache, log or select a message by.

## 2. Findings, most severe first

**1. The draft certifies a loader that loads holdout rows before the check, below SOURCES.md's access authorization.
High.**
- **Where:** `audit/stage7/b3-draft/c76-revision.md:66-79` ("It is tested as non-interference … A loader that reads
  every column but survives a decoding error … decides on event times alone, and passes");
  `ingest/tests/test_store.py:297-313,328-329` (`surviving`, asserted to pass); `audit/decisions.md`,
  12:38 UTC (07:38 EST), "Why".
- **The failure:** `surviving` decodes every column of the holdout row into `frames` and then refuses. My probe
  `persisting` (same, but storing the decoded rows in a module dict, as `Store._cache` does) passes all three fixtures.
  A slice-5 `as_of` that keeps today's `revisions()` cache and adds the check after it passes C7.6's test 3 while the
  holdout row sits in the gate's long-lived `Store`, reachable by `revisions()`. `outcome()` (`test_store.py:205-215`)
  compares only the exception and captured stdout/stderr, never the loader's state or the ledger record.
- **Outcome it could change:** C7.6's named test 3 passes on a loader violating SOURCES.md:174-183 ("each reading no
  more than it needs", "never materializes a holdout observation", "before resolution"): a leakage outcome certified
  as held. GPT round 7 finding 1's named outcome ("could pass while holdout values are materialized before refusal")
  is not answered but declared acceptable.
- **Fix:** keep the rule SOURCES.md states, scoped as a decode limit (footer and identity bytes may be read; say
  whether footer statistics of other columns may be used, and if so that they are holdout values). Keep
  non-interference as one half of its test; the other half has to see decoding, which no black box does (finding 2):
  a per-implementation structural check (the event-time projection, `columns=["eventTime"]` / a projection mask, is
  the only read before the check, by code path), reviewed, and the limitation stated in the frozen text. If the
  advisor holds that the dependence property is all SOURCES.md means, the paper/SOURCES.md wording must be revised
  first under §3 (Blockers, then the change), not read narrowly in C7.6.

**2. Test 3 does not decide its own rule: four leaking loaders pass. High.**
- **Where:** `ingest/tests/test_store.py:182-186` (`FIXTURES`, five fixed `VARIANTS`), `:227-233`;
  `c76-revision.md:68-71`.
- **The failure:** the variants vary only `coin`, `rate`, `source`, `hash` of the late row, among five fixed values
  (1.0, −7.25, NaN, a List, garbage with the original footer). Probes, each checking event times first like the
  `telling` control and run through `decides_on_event_times_alone`, all pass on all three fixtures:
  - `threshold`: appends " (large)" to the refusal if the holdout row's `rate` > 1000 (false on every variant).
  - `statistics`: the same bit from the footer's `rate` max statistic, no data page decoded.
  - `metadata`: appends the holdout row's `fetchedAt` (from the column, or from its footer statistic when garbled);
    the text's variants "differ only outside the holdout row's event time", which includes `fetchedAt` and
    `tombstone`, but the test never varies them.
  - `persisting` (finding 1).

  ```python
  def threshold(root):
      def as_of(dataset, t, version):
          if refusal := holdout_check(event_times(root, dataset)):
              try:
                  rate = pl.read_parquet(files(root, dataset)[-1], columns=["rate"])["rate"][0]
                  if isinstance(rate, float) and rate > 1000:
                      refusal += " (large)"
              except Exception:
                  pass
              raise ValueError(refusal)
          return event_times(root, dataset)
      return as_of
  ```
  A finite set of variants cannot decide a dependence property; the controls (`resolving_first`, `eager`, `telling`)
  are caught only because they fail on garbage or print the value whole. With one holdout row per fixture, the
  choice of "the crossing event time" (`c76-revision.md:62`) when several rows cross is also undefined, and a loader
  choosing it by value is invisible.
- **Outcome it could change:** C7.6 test 3 passing on a loader whose refusals, recorded and shown to the searching
  agent, carry a bit of a holdout value per evaluation: a leakage outcome, and through it false discoveries.
- **Fix:** with finding 1's structural half, the black-box half becomes a regression net rather than the decision; it
  should still vary `fetchedAt` and `tombstone`, draw values (hypothesis), put a holdout row beside pre-holdout rows
  in one file, compare the loader's state after refusal (a second call on the same `Store` with the holdout file
  removed equals a fresh `Store`'s), and define which crossing event time is named (the least).

**3. "Parquet schema names one column twice, or whose two schemas disagree in their names" decodes two ways on List and
Struct columns. Medium.**
- **Where:** `rules-revision.md:147-148`; `c76-revision.md:55-56`, and `:60` (a schema check).
- **The ambiguity:** a Parquet schema's column (leaf) names for a List column are `element`, its path
  `rate.list.element`; its top-level field name is `rate`. Checked here: polars writes `{"rate": [[1.0, 2.0]],
  "x": [[3.0]]}` with `pq.ParquetFile(...).schema.names == ['eventTime', 'element', 'element']` against
  `schema_arrow.names == ['eventTime', 'rate', 'x']`; Rust `parquet`'s `ColumnDescriptor::name()` is the leaf name too.
  Read by leaves, every file with a List or Struct column is invalid at the schema check, whatever V and before the
  holdout check; read by top-level fields, only its rows' decoding is.
- **Outcome it could change:** test 3's List variant: a loader reading by leaves refuses it as an invalid dataset at
  the schema check, unlike the other variants, and fails test 3 while following the text; GPT's resolver, `mm` and
  Python may also split on post-V rows holding a List (valid by fields, invalid by leaves). The image writes declared
  non-cells as List columns (`c76-revision.md:26-27`); in the current suite only one hand case has one, expected
  INVALID, no List row after V, so today's counts are unchanged.
- **Fix:** "the names of the top-level fields of the Parquet schema (the root's children)", or forbid nested
  columns at the schema check and drop List/Struct from the decoding list.

**4. The fixtures omit the plainest I8 case and the rows the text names. Low.**
- **Where:** `test_store.py:182-183`; `c76-revision.md:61` ("every row (tombstoned, evidence, outside-U and post-V rows
  too)").
- **The gap:** no fixture has a holdout row that is eligible and live (fetched by V, not a tombstone), nor one sharing a
  file with pre-holdout rows; evidence and outside-U rows have no fixture (Python's `as_of` has no U). A loader that
  resolves first and silently drops eligible live holdout rows (as the search store's `event_before` does on write),
  while refusing post-V and tombstoned ones, passes.
- **Outcome it could change:** C7.6 test 3 passing on a loader that delivers or silently drops a holdout observation.
- **Fix:** add the fixture; name where the evidence and outside-U rows are tested (`mm`'s namesake).

## 3. Round 7 findings, at their cause?

| Finding | Answered at its cause? |
|---|---|
| GPT 1, Claude 1: values decoded outside the seam pass | No: the instrument is deleted and the outcome it named is now passed by design (findings 1, 2). |
| Claude 2: footer statistics hold the values | Not moot: a statistics-reading loader passes (finding 2, `statistics`); the text no longer says whether statistics may be used. |
| GPT 2: embedded vs physical duplicate names | Yes for GPT's file (physical `close` twice is now invalid), but the new "disagree in names" clause is ambiguous (finding 3). |
| Claude 3: the schema checks named, null `fetchedAt` after | Yes (`c76-revision.md:58-66`). |
| Claude 4: `mm`'s bound-less path | Yes: `market::load(.., holdout: None)`, `kernel/mm/src/market.rs:361`. |
| Claude 5: `ChunkReader` ranges | Moot (the instrument is deleted). |
| Notes: "crossing's" noun; provenance | Taken (`:62`); see note 1. |

## 4. The draft as text to freeze

- Size: reached, 1,001 delivered pairs ≥ 1,000, over stores that resolve and have a Parquet image, by `lean_check.py`'s
  count; unchanged since round 7, where GPT counted 1,001 independently (999 without the last store).
- Named tests: `test_holdout_check_decides_on_event_times_alone` exists (three strict xfails naming
  `holdout-staging.md`, failing for the recorded reasons); its `mm` namesake does not exist yet (slice 5, authorized
  deferral; it cannot support a pass until it does). It tests what it names only as far as findings 1–2 allow.
- Decodability: finding 3; otherwise no findings in the parts this round changed.
- Lean: untouched this round; 160 of 160 hand cases and 0 observation disagreements; no findings.

## 5. Notes (no outcome)

1. `rules-revision.md:15` lists rounds 3–6 and `:140` says "second to fifth" while listing through round 7.
2. `holdout-staging.md` matches what `--runxfail` shows.

**Verdict: revise first.** The draft reads SOURCES.md's access authorization as dependence alone and passes a loader
that loads holdout rows before the check (finding 1), and its test does not decide even that (finding 2).
