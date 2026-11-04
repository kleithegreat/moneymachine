# B3 round 7 review (Claude): the sixth round's findings answered

**Date:** 2026-11-04 12:27 UTC (07:27 EST). **Model:** Claude Opus 5.5 (fresh session, independent reviewer).
**Reviewed:** `fdc07ac` (`claude/stage7-b3-round7-fix-7aqm8b`), against `b3-round6-review-gpt.md` (finding 1) and
`b3-round6-review-claude.md` (findings 1–5, notes 2–4). Below, `draft/` is `audit/stage7/b3-draft/`. The draft was not
changed.

**Run here, at `fdc07ac`:**
- `lake build` in `reference/lean`: 109 jobs, success. Then `draft/lean_check.py`, exit 0:
  - hand: 160 of 160 agree with Lean; both files equal `HAND` and `generate()`;
  - generated: 481 stores, 365 resolve, 116 INVALID, 401 with a Parquet image;
  - size: **1,001 distinct delivered pairs**, against at least 1,000;
  - REACHED floors: the fewest are raised to replaced (68) and derived bound past fetchedAt (86);
  - observations: 0 disagreements.
- `resolver_suite.py` (`PYTHONPATH=.`): exit 0, no output; it has no checking entry point and runs through
  `lean_check.py`. `resolver_suite.py`, both JSONL files, `reference/` and `kernel/` are byte-identical to `4230c36`
  (`git diff --stat 4230c36 fdc07ac` touches only the three draft texts), so round 6's independent count from the text
  (1,001 distinct pairs on multi-revision keys of U with an entry known by the query, in resolving image cases; 999
  without the last store) still holds.
- `pytest ingest/tests/test_store.py`: 26 passed, 6 xfailed. With `--runxfail` all six fail inside the production
  loader for the stated reason: as written, `refuses_crossing`/`refuses_uncheckable` get `DID NOT RAISE` (no holdout
  check on reads); garbled, `ComputeError: Invalid thrift: bad data` at `ingest/store.py:56` (`_read`, from
  `revisions:82`, from `as_of:124`). None reaches the byte-range assertion: the xfails show the missing check, not the
  instrument. The 12 control cases pass: both controls fail every case, and the event times alone pass the range check.
- `pytest ingest/tests gate/tests/test_markets.py gate/tests/test_kernel_defects.py reference/tests/test_resolution.py`
  (every test using `Store`): 157 passed, 13 xfailed.
- The seam changes no result: `pl.read_parquet(path)` and `pl.read_parquet(open(path, "rb"))` gave equal schemas and
  frames on 38 files (Null, LargeUtf8, List, Struct, NaN, ±inf, Timestamp, Int32, Double event times, with and without
  statistics, 1–3 row groups). Polars infers hive partitions only for a directory and globs only a path, so a file
  object loses neither on store paths.
- Production reads: the only Parquet decode of a store in Python is `ingest/store.py:56`; `audit/stage5/purge.py` is a
  spent audit script; `ingest/events.py:118` hashes store files' raw bytes outside the seam (not a decode, not in
  `as_of`). `mm`'s loader (`kernel/mm/src/market.rs:205-208`) reads each file whole (`fs::read`, for the dataset hash)
  and then decodes it through `SerializedFileReader::new(File::open(..))`.

## 1. The round 6 findings

| Finding | Answered at its cause? | Where |
|---|---|---|
| GPT 1 / Claude 1, test 3 passes a loader surviving a decoding error | Partly. The test now records what is read through `open_parquet`, and the round 6 probe (`surviving`) is a control that fails every case. But the instrument is opt-in: a loader decoding every column outside the seam, or a seam buffering each file whole, passes all six cases (finding 1). | `test_store.py:190-279`; `c76-revision.md:61-66` |
| Claude 2, which store the comparison runs on | Yes for Python: "each case is read from a store with no holdout bound". For `mm`, "a store with no holdout bound" has no counterpart (finding 4). | `c76-revision.md:30-31` |
| Claude 3, "LO to HI" undefined | Yes: RULES.md's range [−2^62, 2^62 − 1], stated. | `c76-revision.md:58-59` |
| Claude 4, the crossing refusal's content | Yes: "contains `holdout`, and the boundary and the crossing event time in decimal", as the test checks. One word is missing (note 1). | `c76-revision.md:57-58`; `test_store.py:265` |
| Claude 5, "§6 alone" defines invalidity | Yes: "(RULES.md §6 and SOURCES.md §2)", and the schema checks come first. "Schema checks, which read only the footer" includes one that is not a footer check (finding 3). | `c76-revision.md:55`, `:60-61` |
| Claude note 2, which schema's names count | Yes: the embedded Arrow schema where present, else the Parquet schema. | `rules-revision.md:147-148` |
| Claude note 3, provenance of the §6 part | Yes: `b3-round{3,4,5}` (round 7 did not change the §6 part). | `rules-revision.md:15` |
| Claude note 4, the history parenthesis | Deleted. | `holdout-staging.md` |

## 2. Findings, most severe first

**1. Test 3 passes a loader that decodes every value column before the holdout check, by reading it outside the
seam. High.**
- **Where:** `c76-revision.md:61-66` ("each loader opens every Parquet file through one byte-range reader … asserts that
  every file was opened through it"); `ingest/tests/test_store.py:274-279` (`{p for p, _, _ in reads} == set(files)`).
- **The cause:** the instrument sees only reads through the wrapped reader, and the test asserts only that every file
  was read through it at least once, not that nothing else read it. Two probes, run here against all six cases (the
  three fixtures, as written and garbled), pass every one:
  1. `pl.read_parquet(str(f))` for every file first (a `try` keeping a decoding failure), then the event times through
     the seam (the test's own `event_times`), then the holdout check. On the as-written store it decodes the holdout
     row's every column before refusing. Reading by path is polars' idiomatic call, and the one `store.py` used until
     this commit.
  2. `open_parquet` itself returning `io.BytesIO(Path(p).read_bytes())`: the whole file is in the process before any
     check; the wrapper records only what is taken from the buffer.
- **Rust is worse:** `mm`'s loader already reads every byte of every file outside any `ChunkReader`
  (`market.rs:205`, `fs::read` for the dataset hash) before decoding. Either the text allows reads outside the reader
  (then probe 1's analog, a second `SerializedFileReader` or one over those `Bytes`, passes `mm`'s namesake) or it
  forbids them (then the hash must move after the check, which the text does not say). The project's own reading of
  "read" (`ingest/holdout.py:3`: hashing bytes "without parsing them, so no holdout value is read") is a decode; the
  instrument's is bytes through one reader. The text picks neither completely.
- **Outcome it could change:** C7.6's named test 3, the only evidence that the holdout check precedes every value
  read, passes a Python or `mm` loader that decodes holdout rows' values first: the boundary GPT round 4 finding 3 and
  both round 6 reviews named.
- **Fix:** define what "read" means and make the instrument complete for it. If it is a decode (consistent with the
  dataset hash): "every decode of a store file goes through that reader, and no file of the store is opened otherwise
  except to hash its bytes", and the test asserts that the number of opens of each file (for example Linux inotify
  `IN_OPEN` on the dataset directory, which sees native opens) equals the seam's opens plus the hashing ones, with
  probe 1 as a third control. If it is bytes, the hash goes after the check, and the seam's body is fixed to return
  the open file itself.

**2. Every loader that passes test 3 reads the holdout row's values, from the footer's statistics. Medium.**
- **Where:** `c76-revision.md:55-56` ("nothing but the event-time column is read"), `:66` ("the footer and file
  metadata may be read"); `ingest/store.py:117` (`write_parquet` with polars' default statistics).
- **The contradiction:** a Parquet footer holds each column chunk's min, max and null count. In the fixture, each file
  holds one row, so the footer of the holdout file holds that row's `coin` and `rate` exactly (checked here: `rate` min
  = max = the stored value; its 8 bytes lie inside the footer). The test's own witness (`event_times`) reads the footer
  whole, so the rule as written cannot be met by any loader, and the test permits what the rule forbids. The test also
  permits page indexes and bloom filters of value columns (they lie outside every column chunk), which hold per-page
  min and max.
- **Outcome it could change:** what C7.6 certifies about holdout access: the text claims that no value of a holdout row
  enters the process before the check, and every passing loader brings in its min/max (for a one-row fetch, the
  values). No judged result rests on the check yet (`holdout-staging.md`).
- **Fix:** state it: "the footer is read, including its statistics of every column; nothing else outside the
  event-time chunk", so the boundary claimed is the boundary tested; or have `Store.write` write without statistics
  from slice 5 on and state that files written before keep them (they are immutable). The advisor's choice; either way
  the text and the test say the same thing.

**3. "The schema checks, which read only the footer" includes a check that reads data, and the order of the others is
unstated. Low.**
- **Where:** `c76-revision.md:55`; `rules-revision.md:146-148`.
- **The gap:** SOURCES.md §2's revision makes the dataset invalid "whatever V" for a `fetchedAt` that "holds a null".
  That is decided by the `fetchedAt` chunk (or the footer's null count, which statistics need not carry), not by the
  schema. A loader that counts it a schema check reads a column other than the event time's before the holdout check
  and fails test 3; one that does not has no stated order between this invalidity and a holdout crossing. A file with
  no event-time column is in neither list (schema invalidity, or uncheckable?).
- **Outcome it could change:** which refusal Python and `mm` give on such a store (no leakage; a refusal either way),
  and a spurious failure of `mm`'s namesake written from the text.
- **Fix:** name the schema checks (column types, `tombstone`'s type, duplicate names, the event-time column present)
  and say a null `fetchedAt` is found after the holdout check passes.

**4. "A store with no holdout bound" has no counterpart in `mm`. Low.**
- **Where:** `c76-revision.md:30-31`; `kernel/mm/src/main.rs:48` ("the holdout boundary comes from the store's own
  policy.json"), `admission.rs:128-129` (the crossing refusal in `Mode::Search` only).
- **The gap:** Python's store without a bound is `Store(root)`, the holdout store's production configuration. `mm`
  always reads a boundary from `policy.json` and drops the crossing refusal only in holdout mode, which needs a
  campaign and finalists. A builder of `mm`'s comparison will either add a flag (a second path, which "never from a
  second path" forbids) or set the boundary past every event time, under which the uncheckable refusal still fires on
  the 8 hand cases with non-integer event times (round 6 Claude finding 2), so `mm` disagrees with Lean on them.
- **Outcome it could change:** C7.6's test 1 agreement for `mm` on those hand cases.
- **Fix:** name `mm`'s bound-less production path (its holdout-mode load), or say the comparison's stores carry no
  `holdout_start` and the check, absent a boundary, is not made.

**5. `mm`'s instrument, a wrapped `ChunkReader`, does not give byte ranges as the text assumes. Low.**
- **Where:** `c76-revision.md:63-65`; `parquet-60.0.0/src/file/reader.rs:90-97`, `serialized_reader.rs:721`, `:939`.
- **The gap:** `ChunkReader::get_read(start)` returns an open-ended reader (for `File`, a `BufReader` that pulls 8 KiB
  ahead), and parquet 60 reads page headers through it. A wrapper recording calls sees a start, not a range; one
  recording below a `BufReader` counts read-ahead into the next chunk, so a staged loader fails on any file under
  8 KiB (every store file of a small fetch).
- **Outcome it could change:** a spurious failure of `mm`'s namesake, or a namesake that records only starts and so
  sees nothing.
- **Fix:** "the ranges of `get_bytes` and the bytes consumed from `get_read`'s reader, the wrapper's own reader not
  buffering".

## 3. Notes (no outcome)

1. `c76-revision.md:57`: "a holdout crossing's contains `holdout`" lacks its noun ("a holdout crossing's refusal").
2. `pl.read_parquet` on a file object copies the file into memory where a path was memory-mapped: the slice-5 loader
   should read through pyarrow over the seam anyway (`holdout-staging.md`), so this lasts only until then.
3. The embedded Arrow schema and the Parquet schema can disagree in their names only in a crafted file; the store never
   writes one.

**Verdict: revise first.** Test 3 still does not decide its rule: a loader decoding values outside the seam passes it
(finding 1), and the footer it permits holds the values the rule forbids (finding 2). Findings 3–5 are a sentence each.
