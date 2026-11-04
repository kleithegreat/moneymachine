# B3 round 3 review (Claude): the second round's rulings applied to the draft

**Reviewed:** `claude/b3-round-3-advisor-rulings-pmblz5` at `59077b4`, diffed against `origin/stage7`, on 2026-11-04,
against the decision of 2026-11-02 05:55 UTC (00:55 EST) ("B3's fixes are not frozen; second round ruled on") and
`b3-fixes-review-{gpt,claude}.md`. Below, `draft/` is `audit/stage7/b3-draft/` and `suite:N` is a line of
`draft/resolver_suite.py`. Nothing else was edited.

**Run here** (not the full suite): `lake build refmm`, then `draft/lean_check.py`. Output: hand 134 of 134 agree
with Lean; 119 stores, 90 resolve and 29 INVALID; pairs (3,020, 1,332); every REACHED tag on ≥ 12 stores; resolveAll
equals its timelines' delivery in every case. Both `.jsonl` files equal `HAND` and `generate()`. Probes through
`refmm resolve`, also run: `close: 1e309` and an undeclared member nested to depth 65 give INVALID; a slot of 10^30
resolves; a non-derived row's `upstream` of `{` is never read; the integer 2^53+1 is delivered as 2^53.

**Verdict: not ready to freeze, but close.** Every ruling is met, and every case I recomputed is right. Four findings
can change an outcome (F1–F4), and F1 and F2 should be fixed before the text freezes. F5–F7 are cheap
precision fixes. None needs Lean's frozen `Ref/` to change.

## 1. Rulings

| Ruling (decision of 05:55 UTC (00:55 EST)) | Met? | Where |
|---|---|---|
| The decoding law moves to what the resolver reads (metadata, declared cells, lineage); undeclared columns never read | Yes | `rules-revision.md` "What the resolver reads". The flipped cases are at `suite:209-212`. |
| One mapping per representation: JSON in §7, Parquet in SOURCES.md §2 | Yes, with gaps | §7 "The JSON mapping"; the SOURCES.md §2 revision. See F2 and F7. |
| Names what it replaces (R_ROW; §1's floating-point sentence for stored cells); where earlier text differs, it governs | Yes | Revision preamble |
| C7.6's Python participant is `store.as_of`'s bitemporal replacement; the plan and README agree | Yes | `c76-revision.md`, `README.md` step 3, `rust-port-plan.md` slice 5 |
| `mm` runs the cases through the store's Parquet layout, by a stated path | Partly | One file per row is stated. File naming and non-cell images are not (F7). |
| Named loader-level comparison: actual observations against `resolveAll`, per delivery, with values, role payloads, undefined on a retraction, slots and final flags | Yes | `c76-revision.md` test 1; §7's observation format names every one of these, and its controls (final values on every entry, a retraction's stored values, every entry final) are exactly GPT's mutants |
| Retraction CELLS are null | Yes | §7; `case()` at `suite:84` |
| Lean's decoding layer is new code, one more implementation; the large-integer conversion is handled there | Yes | `Main.lean` `rnumber` keeps integer tokens exact. Case-file fields still go through `Ref.Json` (N4). |
| REACHED tags and classes certify what they claim | Yes | `suite:641-691`; the floors now run over Lean's results (`lean_check.py`). Each tag now requires the deciding condition: the rule value below the replaced knownAt, a positive lag, a slot neither its own nor the event time, and a query at or after the retraction. |
| A non-integer case separating binary64 from exact decimal | Yes | `suite:426-428` |
| How results are read | Yes | §7, last bullet |
| The escape lost from the example | Yes | Checked as bytes: `rules-revision.md:19` holds `"t"` and `:45` holds `"BTC"` |
| The size definition's one home in C7.6 | Yes, except N3 | `c76-revision.md` "How much" |
| The date | Yes | 2026-11-04 (N7) |
| Self-checks labeled | Yes | `README.md` "Checks" |
| Two-run checks qualified, carving out late venue-state revisions and global refusal by name | Yes as worded, but see F4 | `rust-port-plan.md` slice 5 |

**Prior findings.** Claude B1, B2a, B2b, S1, S2 and S4 are met. Claude S3's tags are met. The N notes are met or
disclosed: N3, evidence pairs counting, is now stated in C7.6. GPT's finding 1 (the actual observation projection) is
met by test 1. GPT's generator coverage-label defects are met. Its point that input classes count ineligible rows
is not fixed, but I recomputed `classes` on eligible rows of stores that resolve, and every class still has at least
24 stores. That cannot change an outcome.

**Beyond the rulings:** the new `refmm resolve` mode in `Main.lean` and `lean_check.py` are what the ruling on Lean's
decoding layer calls for. `Main.lean` is not hashed by `laws-frozen.md`. The generator's two new shapes (a
reportedTime correction, and a tombstone holding another slot) exist to meet the REACHED floors. Nothing goes further.
One leftover: the draft header's "No Lean changes" should read "no change to frozen Lean (`Ref/`)".

## 2. Cases recomputed

Constants: H = 3,600,000; E = 36,000,000; D = 120,000; K = 36,120,000; F = 180,000,000; P = 36,005,000; LAG = 1,000.

| Case | Recomputed result | Matches |
|---|---|---|
| `suite:171` | The first revision's rule gives max(K, E+3H) = 46,800,000. The second's gives K, which is not raised by its fetchedAt (200) but is raised to the prior knownAt, 46,800,000. Visible: null, null, 200 (the later revision wins the tie). | yes |
| `suite:174` | `reportedTime: "x"` is rejected, so it is a retraction at max(200, 46,800,000). Visible: null, null. | yes |
| `suite:209-212` | Seven texts whose declared cells are those of `b(1)`. Their undeclared members are `extra` holding `{}` or `1e999`, and members named `fetchedAt`, `source`, `hash`, `tombstone` and `upstream`. Each is identical to `b(1)`, so it adds nothing. | yes |
| `suite:426` | `1.00000000000000001` is 1 + 1e-17, which is below half an ulp (1.11e-16), so it is binary64 1.0. Identical, so it adds nothing. | yes |
| `suite:427` | `1.0000000000000002` is nearest 1 + 2^-52. It is a correction at max(K, F) = F. | yes |
| `suite:380` | Entries: at 36,008,000, known 36,007,000 (the poll at 36,006,000 plus LAG), slot E+H; at 20H, known 72,000,000, slot E+2H; the tombstone at 30H, known 108,000,000, keeping E+2H rather than its own E+5H; at 40H, known 144,000,000, slot E+3H. Visible: 36,008,000, 20H, null, 40H. | yes |
| `suite:362` | `up` is fetched at 15H and known at 110H. The second derived revision is known at 110H+LAG, which is more than its fetchedAt (20H) and more than the replaced knownAt (36,007,000). | yes |
| Generator, `suite:489-494` | first ≤ 12H; e = 13H; the first revision's rule gives 16H. The correction is fetched at ≤ 13H with a rule value ≤ 14H, so it is raised to 16H, which is more than both. With `"x"` it is a retraction raised to 16H. This shape is the round 1 B-1 discriminator. | as tagged |

## 3. Findings that can change an outcome

**F1. C7.6's size floor counts pairs the actual loaders may never answer. Fix before the freeze.**
- C7.6 counts (key, query) pairs over every listed key, evidence and outside-U keys included (`c76-revision.md`, "How
  much").
- Recomputed over the 90 resolving stores: of the 3,020 pairs, only **932** are on keys a loader delivers (620 of them
  on multi-revision keys). That is **below 1,000**.
- The frozen bullet says "`store.as_of` and `mm`'s loader agree on at least 1,000 frozen queries".
- Nothing in §7 or C7.6 says the loaders emit §7's result, with timelines of undelivered keys. The only thing the text
  has them deliver is observations.
- **Outcome:** C7.6 could be judged met by its two loader participants on 932 delivered pairs. That is a frozen
  threshold read loosely, and only the human may loosen one.
- **Fix:** both of these:
  - say that each loader emits §7's whole result from its production resolver, not from a second path;
  - make `generate()` continue until the delivered-key pairs reach 1,000 and 200.

**F2. The Parquet mapping does not cover the store as `ingest/store.py` writes it. Fix before the freeze.**
- **The `tombstone` column.** `store.write` adds a `tombstone` column only to files that hold a tombstone (`:93-99`),
  and `live()` treats a missing column as "none tombstoned" (`:46`). The revision gives `tombstone`'s type and its
  null, but not its absence.
- **The lineage of tombstones.** The store's tombstone rows carry only key, `tombstone`, `hash`, `fetchedAt` and
  `source`. So a derived source tombstoned the same way has a null or absent `upstream`. The revision makes the
  lineage of every eligible derived revision decode, tombstones included (Lean's `caseRow` agrees), and says nothing of
  a null or absent `upstream`.
- **Outcome:**
  - An implementer may read an absent `tombstone` column as not decoding, which makes the dataset INVALID and refuses
    every run on it.
  - A derived tombstone with no lineage is INVALID under one reading and a plain retraction under another.
- **Fix:**
  - An absent `tombstone` column is false.
  - A tombstone's lineage is never read. It is a retraction whatever its lineage holds, and the timeline never reads
    it.
  - On any other derived revision, a null or absent `upstream` does not decode.
  - Add a hand case for each, and a named Parquet test for the absent column.
- **Also before the freeze:** the mapping makes the dataset INVALID for any file in which a declared column is not
  Int64, Double, Utf8 or Boolean. An all-null column that Polars writes as type Null, or an Int32, refuses every run on
  that dataset. A census of column types per file of the recorded stores is integrity-only inspection (schema, not
  values). It would show whether the frozen mapping refuses stores stage 7 must read, including the one-revision
  byte-identity check against the old loader (slice 5).

**F3. "A key with no delivery" contradicts "never delivered". Fix the wording before the freeze.**
- The text says "a well-shaped lineage key ... naming a key with no delivery makes the revision unusable"
  (`rules-revision.md`, the paragraph after the decoding list).
- §6's last sentence says evidence keys are "never delivered".
- Read literally together, every revision whose lineage names an evidence key is unusable. Step 3 has the precise rule
  ("a key with no such entry", one fetched no later than r).
- **Outcome:** GPT's resolver, written from the text alone, could follow the wrong sentence. The hand cases would catch
  that, so it would cost a round, not a judged result.
- **Fix:** "naming a key with no entry fetched no later than r (step 3)".

**F4. The two-run carve-out is an exception on outputs, so it excuses any difference.**
- `rust-port-plan.md` slice 5 now reads "byte-identical decisions through t, except where ... a late final revision of
  venue state ... can change ... equity and, through equity, later order sizes".
- Any read-ahead that reaches a decision can be put down to equity, so the check as worded cannot fail where the
  carve-out applies. Its positive control, "a mutant that reads ahead must fail it", then proves nothing.
- **Outcome:** a look-ahead leak through any input is excused as a venue-state effect.
- **Fix:** put the carve-out on the store pairs, not on the comparison. The records that differ between the two stores
  are not revisions of role-providing (venue-state) keys, and both stores pass admission. On such pairs the decisions
  through t are byte-identical, with no exception. Separately, a pair differing only in a late final venue-state
  revision may change fills, funding, marks and equity, but not the inputs any decision through t reads.

## 4. Precision fixes (cheap; the text freezes)

- **F5. Large integers have two readings.**
  - §1 lets an implementation "treat a longer integer token as out of range without computing it".
  - The new law makes every integer a cell, with no range, as a value, slot or `trades`. Lean keeps 10^30 as a slot.
  - The integer-to-binary64 conversion of `num` is unstated: rounding, ties, and an integer past binary64's range.
  - Parquet is Int64, so only GPT's resolver and Lean can disagree. No case reaches this, so no current outcome
    changes.
  - **Fix:**
    - An integer cell outside the signed 64-bit range is not a cell. This makes JSON and Parquet coincide, and is
      one line in `Main.lean`.
    - An integer's `num` is the nearest binary64 value, ties to even.
    - Add a hand case for each.
- **F6. A malformed undeclared JSON member is not pinned.**
  - "Read whole as §1 reads it" makes `"extra": "\ud800"`, a duplicate undeclared key, or depth 65 in an undeclared
    member INVALID. Lean agrees: probed at depth 65.
  - No hand case has one. `1e999` is not malformed under §1. A resolver that skips undeclared members passes the
    suite while disagreeing on such texts.
  - **Fix:** add two hand cases: a lone surrogate and a duplicate key, each in an undeclared member.
- **F7. The Parquet image of a case is under-specified.**
  - "A text that does not decode as JSON has no Parquet image" leaves open several cases that decode as JSON but hold
    something that is not a cell:
    - a top-level `[1]`;
    - `close: [1]`;
    - `close: 1e999` or `1e309`.
  - "One file per row" does not say how files are named. The store names a file `<fetchedAt>.parquet` and refuses a
    second one (`store.py:104-106`), and `suite:192-196` holds two rows of one source at fetchedAt 100.
  - The store's reader concatenates files with `diagonal_relaxed`, which unifies Int64 and Double into Double. That is
    the very cross-file unification the revision forbids. The slice 5 replacement must read each file by its own
    types, and test 2 checks this.
  - **Fix:**
    - A text that is malformed or not an object has no image.
    - A declared member that is not a cell is written as the type test 2 names: List, or an infinite Double.
    - Files are named by row index.

## 5. Notes (no outcome)

- **N1.** `lean_check.py`'s projection check is Lean against itself and has no positive control. It is labeled as
  such, and it is the shape of test 1, not test 1.
- **N2.** The suite now imports `ingest.knownat.evaluate` (`suite:17`, used by `own`) while README step 3 kills
  `ingest/knownat.resolve`. Keep `evaluate` where the frozen suite can import it, or move it with the suite.
- **N3.** The size definition is restated in `resolver_suite.py`'s docstring and README step 2. Point both to C7.6's
  revision.
- **N4.** `refmm resolve` reads the case file's own integers (fetchedAt, version, queries, lags) through
  `Ref.Json.parse`, which turns integers past 64 bits into floats. No case has one.
- **N5.** "Its `coin` cell" assumes a non-evidence source declares `coin` as its one entity column. Say so in §7.
- **N6.** A declaration could name a column `fetchedAt`, `tombstone`, `upstream`, `source` or `hash`. That would
  collide with the Parquet metadata and break `Trusted.canonical`'s assumption. Binding's type checks prevent it in
  practice; one line in SOURCES.md §1 would make it a rule.
- **N7.** Date each revision at its freeze commit, not 2026-11-04, if the freeze is later.
- **N8.** `store.py`'s `live()` counts a stored `tombstone: false` as a tombstone (`is_null`). The draft reads false as
  live. The replacement must follow the draft. The store never writes false, so nothing differs today.

## Verdict

**Do not freeze yet.**
- Fix F1 (the size counted on delivered keys) and F2 (the absent `tombstone` column, tombstone lineage, and a type
  census of the recorded stores).
- Reword F3 and F4.
- Take F5–F7 while the text is open.

None of these changes the timeline algorithm, and every hand expectation stands. Only F2's tombstone-lineage choice
changes the decoding law, so by CLAUDE.md a further review round is needed only on that diff.
