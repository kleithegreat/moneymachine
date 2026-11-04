# B3 round 5 review (Claude): the fourth round's findings answered

**Date:** 2026-11-04 11:10 UTC (06:10 EST). **Model:** Claude Opus 5.5 (fresh session, independent reviewer).
**Reviewed:** `5b02dd3` (`claude/stage7-b3-round5-fix-87erip`), against `b3-round4-review-gpt.md` (findings 1–6) and
`b3-round4-review-claude.md` (findings 1–6). Below, `draft/` is `audit/stage7/b3-draft/` and `suite:N` is a line of
`draft/resolver_suite.py`. The draft was not changed.

**Run here, at `5b02dd3`:**
- `lake build refmm`: 108 jobs, success. Then `draft/lean_check.py`, exit 0:
  - hand: 160 of 160 agree with Lean;
  - both files equal `HAND` and `generate()`;
  - generated: 478 stores, 362 resolve, 116 INVALID, 398 with a Parquet image;
  - size: 1,001, against at least 1,000 (999 without the last store, so the prefix is the shortest);
  - REACHED floors: the fewest are raised to replaced (67) and derived bound past fetchedAt (85);
  - observations: 0 disagreements.
- `resolver_suite.py` has no `__main__`. It was run as a module through `lean_check.py` and through a separate count over
  Lean's results. The count reproduces 1,001, of which:
  - 834 are on keys with at least two timeline entries;
  - 697 see a value;
  - 304 see a retraction.
- `cargo test --test sources`: 5 of 5 pass, including the new metadata-column test and its `spare` control.
- `pytest ingest/tests/test_store.py`: 16 passed and 3 xfailed. With `--runxfail`, all three fail with
  `polars.exceptions.ComputeError: … Invalid thrift: bad data`. The location of that error matters for the variant:
  see finding 1.
- A probe loader that reads every column of every file first, then wraps the Polars error as
  `ValueError("<file>: invalid dataset, a row does not decode")`, passes both parameters of test 3. It also passes the
  variant once the variant's setup is repaired. See finding 2.

## 1. The round 4 findings

| Finding | Answered at its cause? | Where |
|---|---|---|
| GPT 1, size counted over cases with no image | Yes. `image` excludes every store with a malformed or non-object `cells` text. The text says such a case has no image. | `c76-revision.md:28-29`; `suite:603-629` |
| GPT 2, metadata column names | Yes, for the declarations of `mm` and Lean. The text reads two ways on `upstream`: see finding 4. | `kernel/SOURCES.md:55-58`; `source.rs:204-211`; `Main.lean:500` |
| GPT 3, the named test does not exist | The test now exists, but it does not test what it names: see findings 1 and 2. | `ingest/tests/test_store.py:167-229` |
| GPT 4, "delivered" counted from fetchedAt | Yes. The count now starts at an entry's knownAt (`e[1] <= q`). | `suite:626-629`; `c76-revision.md:31-36` |
| GPT 5, oversized metadata integers | Yes. Cases are read by `rparse`, and the hand case `suite:206` gives INVALID. That case has no Parquet image: see finding 5. | `Main.lean:593`, `:312-314` |
| GPT 6, type-blind file equality | Yes. `same` compares the files, and the hand observations are checked against the expected timelines. | `lean_check.py:80`, `:89-91` |
| Claude 1, the 1,000 floor | Yes. 1,000 pairs on keys of at least two eligible revisions, and 1,001 reached. | `c76-revision.md:31-36`; `suite:731` |
| Claude 2, a Null column | Yes, in the image (a Double null) and as slice 5's plan for `Store.write`. | `c76-revision.md:26`; `rust-port-plan.md:47-51` |
| Claude 3, an undecodable event time in the holdout check | The sentence is new, but it defines invalidity outside RULES.md, and its test cannot pass: see findings 1 and 3. | `c76-revision.md:54-56` |
| Claude 4, the sign of −0.0 | Yes. One hand case covers it, checked bit for bit through the observations. | `rules-revision.md:48-49`; `suite:157` |
| Claude 5, the Rust test's path | Yes. The path is now `kernel/mm/tests/`, where the test does not exist yet (slice 5). | `c76-revision.md:57` |
| Claude 6, Parquet's type and the metadata types | Yes | `rules-revision.md:138-150` |

## 2. Findings, most severe first

**1. Test 3's variant fails in its own setup. No loader can pass it, and its strict xfail holds for a reason other
than the one it names. High.**
- **Where:**
  - `ingest/tests/test_store.py:225-226`;
  - `audit/stage7/holdout-staging.md:8-9`.
- **The cause:** `staged` garbles every column but `eventTime` in every file it writes. The variant then calls
  `pl.read_parquet(files[1])` on a garbled file, to recast `eventTime` as Double. That read raises `ComputeError` at
  `test_store.py:226`, inside the test, before `search.as_of` is called.
- **The failure:**
  - The xfail reason (`STAGING`) and `holdout-staging.md` say the loader fails it, but the loader never runs.
  - In slice 5, a correct loader still fails the variant. Its strict xfail never turns into a pass, so the builder
    must edit a test that a frozen criterion names, at the moment it is judged.
- **Outcome it could change:** whether C7.6's named test 3 can be met at all. Its variant, as committed, is evidence of
  nothing about any loader.
- **Fix:** write the Double event time before garbling, for example by letting `staged` take the event-time type. Then
  correct `holdout-staging.md`'s account.

**2. Test 3 and its variant pass a loader that reads every column before any holdout check. High.**
- **Where:** `ingest/tests/test_store.py:209-229` (the tests); `:197-205` (the control); `c76-revision.md:53-62`.
- **Two causes:**
  - **The message match is met by the path.** pytest names the main test's `tmp_path`
    `…/test_holdout_check_reads_event0` (checked here). So `match="holdout"` matches any `ValueError` whose message
    contains the store path.
  - **The non-staged loader's answer is the expected one.** The fixture garbles the eligible row too (`fetchedAt` 100,
    the version). By RULES.md §6, an eligible row that does not decode makes the dataset invalid. So a loader faithful
    to §6 that does no staging at all refuses the variant's store as "invalid", which is exactly what the variant
    expects.
- **The control is not a control of a loader.** It checks that Polars cannot read a garbled column. It shows only that
  a loader letting a Polars exception escape would fail. A loader that turns an undecodable row into an invalid-dataset
  refusal, as §6 requires, is not caught.
- **Reproduced:** the probe loader above reads every column of every file first. It passes:
  - `test_holdout_check_reads_event_times_alone[fetched after the version]`;
  - `test_holdout_check_reads_event_times_alone[tombstone]`;
  - the variant, with its setup repaired as in finding 1.
- **Outcome it could change:** C7.6's named test 3 passes on a loader that reads holdout rows' value columns before the
  holdout check. That is the premature holdout access the test exists to exclude (GPT round 4, finding 3).
- **Fix:**
  - Make each refusal name its cause in a way neither a path nor a decoding refusal can produce. For example, use
    distinct exception types for a holdout crossing, an undecodable event time and an undecodable row. Or match the
    holdout boundary and the event time in the message, with a `tmp_path` whose name lacks "holdout".
  - State the same distinction in the text, so that `mm`'s namesake is held to it too.
  - The control should then be a loader: a non-staged `as_of`, shown to fail each test.

**3. The undecodable-event-time sentence defines dataset invalidity outside RULES.md, and its parenthesis reads two
ways. Medium.**
- **Where:** `c76-revision.md:54-56`; `rules-revision.md:27` ("revisions fetched after V are not examined");
  `suite:228`.
- **Two definitions of invalid:**
  - The criterion says an event time "not an integer in range" in any row, post-V rows included, "refuses the run as an
    invalid dataset".
  - RULES.md §6, as revised, defines an invalid dataset by eligible revisions only. The hand case `suite:228`, a post-V
    row with event time `36000000.0`, resolves.
  - So one store is a valid dataset to the resolver and an invalid one to the holdout check. Which applies depends on
    whether the store carries a holdout bound. That is a second definition of invalidity, living in a criterion rather
    than the rules.
- **The parenthesis:** "in range (in Parquet, a non-null Int64)" can be read two ways for an Int64 event time outside
  [LO, HI] = ±2^62:
  - "in range" refuses it, as RULES.md's event column does;
  - "a non-null Int64" admits it.
- **Outcome it could change:** whether a search evaluation on such a store is refused, and so the agreement of Python
  and `mm` in the run differential. It cannot leak: neither reading compares an undecodable value to the holdout.
- **Fix:**
  - Name the refusal as the holdout check's own ("the holdout check cannot be made"), not as dataset invalidity. Or put
    the rule into RULES.md §6 or admission, beside the holdout check.
  - Say "an integer from LO to HI, in Parquet a non-null Int64 in that range".

**4. `upstream` is reserved only as "a derived source's", but `mm`, Lean and two hand cases reserve it for every source.
Low.**
- **Where:** `kernel/SOURCES.md:57`; `suite:238`; `source.rs:19`; `Main.lean:413`.
- **The text:** read literally, a non-derived declaration naming `upstream` is allowed.
- **The hand cases** take the other reading:
  - `src("bars", times=("eventTime", "upstream"))` expects `E_DECL`, where the literal reading gives a resolution;
  - `src("bars", rule(f("u")), values=("upstream",))` expects `E_DECL`, where the literal reading gives `E_RULE`.
- **Outcome it could change:** a spurious failure of GPT's resolver, written from the text alone, on two hand cases of
  C7.6. No outcome changes for real declarations, since none names a reserved column (checked: `sources/*/*.json`).
- **Fix:** drop "a derived source's", so the parenthesis reads "`upstream`". The store writes `upstream` only for
  derived sources, but reserving it everywhere is the simpler rule, and it is the one already implemented.

**5. The hand case with fetchedAt −2^63 − 1 has no Parquet image, and the text does not exempt it. Low.**
- **Where:** `suite:206`; `c76-revision.md:28-29`; `rules-revision.md` (fetchedAt, a non-null Int64).
- **The gap:** the image writes each row's `fetchedAt` as Int64, and −2^63 − 1 does not fit. The text exempts only a
  case whose `cells` text is malformed or not an object.
- **The failure:** a loader harness must write a case that cannot be written. A builder is then tempted to special-case
  it, or to clamp the value. Either way, test 1's "every case" breaks.
- **Outcome it could change:** the loaders' comparison on one hand case, which can only fail spuriously. The size is
  unaffected, since no generated store holds such a value.
- **Fix:** add "or a `fetchedAt` outside −2^63 to 2^63 − 1" to the no-image sentence.

## 3. Notes (no outcome)

- The timeline's step 1 excludes "`fetchedAt` and the revision and tombstone columns" from identity
  (`rules-revision.md:62-63`). None of these can be a declared column now: `fetchedAt` and `tombstone` are reserved,
  and no case source has revision columns. The clause now excludes nothing. It could be deleted before the freeze.
- Lean is faithful to the text on everything checked:
  - `E_DECL` before `E_RULE`, over all declared columns (values, times, event, slot, entity, roles);
  - `rparse` over the whole case file;
  - −0.0's bits;
  - an out-of-range eligible fetchedAt gives INVALID.
- The one divergence is finding 4's reading of `upstream`, which is the text's gap.
- `mm`'s check covers `times`, field columns, evidence keys and roles. The slot need not be checked separately, since
  it must be one of `times` (`source.rs:180-182`).
- The size clears its floor by 1 pair. Any disagreeing participant fails anyway, so the margin carries no risk.

**Verdict: revise first.** Test 3, the only evidence against premature holdout reads, cannot pass as committed
(finding 1), and once repaired it cannot tell a staged loader from one that reads everything first (finding 2).
Findings 3–5 are one sentence each.
