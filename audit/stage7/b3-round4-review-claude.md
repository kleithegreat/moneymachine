# B3 round 4 review (Claude): the third round's findings answered

**Date:** 2026-11-04 10:29 UTC (05:29 EST). **Model:** Claude Opus 5.5 (fresh session, independent reviewer).
**Reviewed:** `f1fe5f7` (`claude/stage7-b3-round4-fix-in2e9x`), against `b3-round3-review-gpt.md` (findings 1–8) and
`b3-round3-review-claude.md` (F1–F7, N1–N8). Below, `draft/` is `audit/stage7/b3-draft/` and `suite:N` is a line of
`draft/resolver_suite.py`. The draft was not changed.

**Run here, at `f1fe5f7`:** `lake build refmm` (108 jobs, success), then `draft/lean_check.py`, exit 0:
- hand: 149 of 149 equal Lean;
- both files equal `HAND` and `generate()` (also checked directly: 149 and 304 entries, the generated file a prefix of
  `stream()`);
- generated: 304 stores, 235 resolve, 69 INVALID; delivered pairs (1,002, 787) against (1,000, 200);
- REACHED: no delivery 191, several entries 191, retraction 135, derived bound past fetchedAt 52, raised to replaced 42,
  retraction raised 78, moved slot 60, retraction keeps slot 52, role 70, nothing after retraction 108;
- observations: `resolveAll` equals its timelines' delivery in every resolving case.

`resolver_suite.py` has no `__main__`; it was run as a module through `lean_check.py` and by the direct file check.
Further counts over Lean's results on the 304 stores: 944 of the 1,002 delivered pairs are in stores holding at least one
multi-revision key of U; 661 are on keys with at least two timeline entries; 614 see a value.

Probes through `refmm resolve`: a lone `close: -0.0` is delivered with bits `0x8000000000000000`; `trades` 2^63 − 1 is
delivered; a slot of 2^62 (a cell outside the time range) resolves; a derived tombstone whose `cells` text is `{` is
INVALID. `Store.write` (Polars 1.40.1) was run on a synthetic dataset to see what it writes.

## 1. The round 3 findings

| Finding | Answered at its cause? | Where |
|---|---|---|
| GPT 1 / Claude F1, the size | Partly. Only delivered pairs are counted now, and `generate` stops at the shortest prefix reaching the floor. The 1,000 still does not count over multi-revision fixtures: see finding 1 below. | `c76-revision.md:31-36`, `suite:594`, `:713` |
| GPT 2, LargeUtf8 lineage | Yes. One string-column definition covers every place a string is named. | `rules-revision.md:141-144` |
| GPT 3, holdout staging | Yes, as a test with a name, a construction and a control. Its path and one case are open: see findings 3 and 5. | `c76-revision.md:52-58` |
| GPT 4 / F5, the integer domain | Yes. An integer is a cell only in int64, in JSON as in Parquet. A non-integer that rounds to infinity is not a cell. `num` is the nearest binary64 value, ties to even. Lean's `J.cell` agrees, and the hand cases at `suite:214-219` and `:478-480` cover it. | `rules-revision.md:24,41-46`; `Main.lean:298-304` |
| GPT 5, cardinality | Yes. `lean()` asserts the count, every `zip` is strict, `same` compares lengths, and the files are compared whole. | `lean_check.py:41,72-91` |
| GPT 6, signed-zero entity | Yes. Lean zeroes entity and lineage cells before keying them, and `suite:455-457` pins it. | `Main.lean:384-389,444,458` |
| GPT 7, retraction keeps slot | Yes. The tag now requires the returned slot to equal the slot of the entry before it. | `suite:686-687` (`reached`) |
| GPT 8, retraction observation | Yes. Only the values and the role payload are undefined on a retraction. fetchedAt, knownAt and slot remain. | `rules-revision.md:78-80` |
| F2, Parquet as the store writes it | Yes for the absent `tombstone` column, a tombstone's lineage (never read), and a null or absent `upstream`, with hand cases at `suite:335-342` and Lean at `Main.lean:448-450`. The census covers `data/store` only: see finding 2 and the notes. | `rules-revision.md:22-34,142-145` |
| F3, "a key with no delivery" | Yes | `rules-revision.md:37-38` |
| F4, the two-run carve-out | Yes. The carve-out now sits on the store pairs, and the venue-state pair checks decision inputs. That is right because a decision is a weight (`DSL.md:35`), and equity only scales the order. | `rust-port-plan.md:61-66` |
| F6, malformed undeclared members | Yes | `suite:214-215` |
| F7, the case's Parquet image | Yes, apart from the type of a null: see finding 2. | `c76-revision.md:21-28` |
| N2–N8 | N3, N5 and N8 are met. N2 holds as written, since `evaluate` stays. N4 and N6 are unchanged and cannot change an outcome. N7 is a reminder for the freeze. | |

## 2. Findings, most severe first

**1. The size floor is still below the bullet's "1,000 frozen queries over multi-revision fixtures", under either
reading. High.**
- **Where:** `c76-revision.md:31-36`; `resolver_suite.py:713` (`SIZE = (1000, 200)`).
- **The bullet:** the frozen C7.6 bullet (`audit/criteria.md:1084`) asks for "at least 1,000 frozen queries over
  multi-revision fixtures". GPT's first B3 review read it the same way (`b3-review-gpt.md:72`).
- **What the revision does:** it counts 1,000 delivered pairs of any kind, plus 200 on keys with at least two
  eligible revisions. It calls the multi-revision fixtures "the required class" and gives it a floor of 200.
- **What the suite reaches:**
  - reading a fixture as a key: **787**;
  - reading a fixture as a store: **944**;
  - counting keys whose timelines have two entries: **661**.
- **The failure:** C7.6 can be judged met on fewer than 1,000 multi-revision queries, while the text says "it loosens
  nothing". The builder's own decision line marks "200 per required class" as a "choice left open". Loosening a frozen
  threshold is the human's call.
- **Outcome it could change:** whether C7.6's resolver part passes on the evidence its bullet requires.
- **Fix:** `SIZE = (1000, 1000)` on keys of at least two eligible revisions, and say so in C7.6. That costs only a
  longer prefix of `stream()`. Otherwise, take the 200 reading to the human as a loosening.

**2. A null declared value can be written as a column of type Null, which §2 makes invalid. Medium.**
- **Where:** `c76-revision.md:24-27` (the image writes declared members "by SOURCES.md §2's mapping");
  `rules-revision.md:146-148`; `ingest/store.py:107`.
- **What `Store.write` writes:** given a fetch whose only row has `close: null`, it writes `close` as Arrow `null`,
  stored as `int32 (Null)`. Reproduced here with Polars 1.40.1.
- **What the text does with it:** the revision makes Null "not a cell", so the whole dataset is INVALID. That agrees
  with SOURCES.md §2 ("an all-null column needs explicit numeric schema metadata").
- **The gap:** neither the case image nor the slice 5 writer says which type a null is written as.
- **The failure, in two places:**
  - **The image:** a harness that writes the hand case `suite:151` (`b(None)`) through Polars gets INVALID where Lean
    resolves. A correct loader then fails test 1, and the temptation is to patch the harness.
  - **The store:** any future fetch whose changed rows hold only nulls in one value column makes the dataset INVALID,
    and every run on it is refused. The census (`README.md:108-111`) shows none today in `data/store`.
- **Outcome it could change:** C7.6's loader comparisons fail spuriously, and runs on live datasets are refused. It
  cannot cause a false pass.
- **Fix:**
  - The image writes a null as its column's type in the other rows, or else as Double.
  - Slice 5's `Store.write` casts each declared column to its declared type (Int64, Double, LargeUtf8 or Boolean),
    with a test that writes a single all-null row.

**3. The holdout check's reading of an event time that does not decode is unspecified. Medium.**
- **Where:** `c76-revision.md:52-53`.
- **What the text says:** the holdout check reads the event-time column "of every row (… post-V rows too)", which
  agrees with Lean's `admit` (`Ref/Source.lean:284`, every stored row). Resolution, by contrast, never examines a row
  fetched after V (`rules-revision.md:26-27`).
- **The case:** `suite:226` resolves a store whose post-V row has the event time `36000000.0`. Neither text says what
  the holdout check does with such a value: refuse, skip, or call the dataset invalid. Lean's `Stored` holds only
  decoded rows, so it cannot say either.
- **The failure:** in a search run on such a store, one loader refuses with a decoding error and another admits. Test
  3's control ("fails … with a decoding error instead") also relies on decoding errors meaning a premature read.
- **Outcome it could change:** whether a search evaluation is refused, and so the loaders' agreement in the run
  differential. It cannot leak holdout data, since a bad value cannot be compared to the holdout start.
- **Fix:** one sentence. For example: "an event time that is not an integer in range refuses the run as invalid,
  before any other column is read". Add a test 3 variant with such a row fetched after V.

**4. The `num` of −0.0 is not pinned. Low.**
- **Where:** `rules-revision.md:43-46`.
- **The text:** `num` is "a non-integer's value", "the binary64 number nearest its decimal value, ties to even". The
  decimal value of `-0.0` is 0, which is equally near to +0 and −0, and both have even significands. The text also
  treats the two zeros as one value.
- **What Lean does:** it delivers the bits `0x8000000000000000` (probe above).
- **Why the hand cases miss it:** no case delivers a −0.0. `suite:156` delivers the first revision, 0.0.
- **The failure:** a loader that normalizes zeros fails test 1 against Lean on a reading the text allows.
- **Outcome it could change:** test 1's agreement only. No decision changes, because −0.0 and +0.0 compute alike.
- **Fix:** "a non-integer's `num` keeps its sign (−0.0 is −0.0)", plus one hand case.

**5. Test 3's Rust test is placed in the Python tree. Low.**
- **Where:** `c76-revision.md:55`.
- **The text:** "its namesake in `kernel/tests/` for `mm`".
- **The repository:** `mm`'s integration tests live in `kernel/mm/tests/*.rs`. `kernel/tests/` holds Python suites
  and case files.
- **Status of the named test:** `test_holdout_check_reads_event_times_alone` does not exist yet, in Python or in Rust.
  That is expected, since slice 5 writes it, but a frozen criterion should point to a real location.
- **Outcome it could change:** none by itself. A judge looking in the named directory finds no Rust test.
- **Fix:** `kernel/mm/tests/`.

**6. Parquet's "type" and the metadata columns do not each decode one way. Low, not reachable through `Store.write`.**
- **Where:** `rules-revision.md:141-149`.
- **Which type is meant:** §2 names Arrow types (Int64, Utf8, LargeUtf8, Timestamp, Null). A file carries two schemas:
  - the Parquet physical and logical types;
  - the embedded `ARROW:schema`.
  They can disagree. For example, a plain INT64 column whose `ARROW:schema` says Duration is "Int64" to one reader
  and "not a cell" to another.
- **The metadata columns:** a null or non-Int64 `fetchedAt`, and a `tombstone` of a type other than Boolean, are not
  covered. With a null fetchedAt, a row's eligibility is undefined.
- **Outcome it could change:** none on stores written by `Store.write`, which writes Int64 `fetchedAt`, Boolean
  `tombstone`, and an `ARROW:schema` that agrees with the Parquet types (checked here).
- **Fix:** one line each:
  - the type is the Parquet logical type, or the embedded Arrow schema where present;
  - a row whose `fetchedAt` is not a non-null Int64, or whose `tombstone` is not Boolean, does not decode, and its
    dataset is invalid.

## 3. Notes (no outcome)

- The census in `README.md:108-111` covers `data/store`. Every type it lists is inside the mapping, and the mapping's
  "nothing else" rules out every other type. Stores that stage 7 migrates later, and the holdout store, may also be
  inspected by schema only. Before slice 5's identity check, run the same census on them.
- The floor is cleared by 2 pairs (1,002). Any participant that disagrees fails the criterion anyway, so the margin
  carries no risk.
- Lean is faithful to the text on everything probed:
  - decoding, including integer ranges, lineage shape, tombstone lineage and null `upstream`;
  - slots of any int64;
  - role payloads;
  - entity keying;
  - `num` of integers;
  - the observation format.
  The one open point is finding 4, which is the text's gap, not Lean's.

**Verdict: revise first.** Finding 1 is a threshold question, cheap to close by raising the multi-revision floor to
1,000 or by asking the human. Findings 2 and 3 each need one sentence. Findings 4–6 are one line each, best taken
while the text is open.
