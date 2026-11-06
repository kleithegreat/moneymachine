# B3 draft: C7.6's dated revision (not committed to `audit/criteria.md`)

Draft text, from the decisions of 2026-11-02 01:32 UTC (2026-11-01 20:32 EST) ("B3's draft suite is not frozen") and
05:55 UTC (00:55 EST) ("B3's fixes are not frozen; second round ruled on", `audit/decisions.md`) and the third to
eighth rounds' reviews (`b3-round{3,4,5,6,7,8}-review-{gpt,claude}.md`), GPT's round 9 review
(`b3-round9-review-gpt.md`), fresh Claude's round 10 review (`b3-round10-review-claude.md`) and Argon's calibration
of round 8 (`b3-round8-calibration-argon.md`), checked against round 10 and answered in round 11;
test 3 by the advisor's decision of 2026-11-04 13:21 UTC (08:21 EST). It is appended beneath C7.6's
resolver bullet in `audit/criteria.md` and committed alone, before the suite's freeze and before anything is judged. The original lines
stay as written. Everything below the line is the text.

---

- **Revision at the freeze (C7.6's resolver bullet), before anything is judged.** Why: the bullet's participants, format
  and size predate the bitemporal resolver (revision of 2026-10-26 23:29 UTC (19:29 EDT) above) and RULES.md §6's B2 and
  B3 revisions (`audit/stage7/laws-frozen.md`); this says what is compared, by whom, and how much. It loosens nothing:
  - **The resolver under test** is RULES.md §6 with its dated revisions through B3, cases in §7's format, stored rows
    mapped to cells by §7 (JSON texts) and SOURCES.md §2 (Parquet).
  - **Who matches exactly:** GPT's resolver, written from RULES.md, SOURCES.md and §7 alone, never the suite;
    `store.as_of`'s bitemporal replacement in `ingest/store.py`, the production path its callers read, never a test-only
    transcription; the actual Rust loader (`mm`); and Lean's `timeline` and `resolveAll` through `refmm resolve`. Lean
    is added; none is removed. `refmm`'s decoding layer is new code, not frozen Lean, so on the decoding cases Lean is
    one more implementation of the text.
  - **How the loaders read a case:** each case is written into the store's Parquet layout and each loader emits §7's
    whole result (every key with an eligible revision, keys never delivered included) and its observations from its
    production resolver, never from a second path. The image: row i of `rows` is the file `<i>.parquet` under its
    source's directory, holding the row's `fetchedAt`, its `tombstone` column only if it is a tombstone (as the store
    writes it), `upstream` as LargeUtf8 (null if null) for a derived source, and its declared members by SOURCES.md §2's
    mapping, a string as LargeUtf8 and a null as a Double null; absent declared members are omitted. A declared member
    that is not a cell is written as a
    List column holding its JSON text, and undeclared members are left out, as neither mapping reads them. No declared
    column may share a name with these metadata columns (SOURCES.md §1): such an `E_DECL` case has no Parquet image.
    Nor does a case with a `cells` text that is malformed under RULES.md §1 (including unpaired surrogates, duplicate
    members and depth above 64), not an object, or a `fetchedAt` outside −2^63 to 2^63 − 1. These cases are left out of
    the loaders' comparison and the size; GPT's resolver and Lean read every case's texts. The comparison's stores
    carry no `holdout_start`, and absent a boundary the holdout check is not made (Python's `Store` built without one,
    as the holdout store is; `mm`'s `market::load` with `holdout` None, the path its holdout mode loads by,
    `kernel/mm/src/market.rs`): test 3 alone tests the check.
  - **What is compared:** every key's whole timeline (fetchedAt, knownAt, retraction, slot, cells and role payload, none
    on a retraction) and, per query, what it sees.
  - **How much:** the suite's size counts distinct **delivered pairs** (store, source, entity, event time, query time)
    over the generated stores that resolve (neither invalid nor rejected) and have a Parquet image: a key in U (of a
    non-evidence source, mapped to a coin of U) with at least two eligible revisions, and a query time at or after the
    knownAt of one of the key's entries, so that by then the loaders have delivered it a value or a retraction. At least 1,000 of them: the bullet's 1,000 frozen queries over
    multi-revision fixtures, each one a query `store.as_of` and `mm`'s loader answer from a delivery. Every other key's
    timeline, and every other query's answer, is compared but not counted.
  - **Covering:** an earlier value visible until a correction's knownAt, and no fallback through a retraction;
    tombstones and cutoffs; corrected rules; the derivation bound over dependencies spanning sources; strict lineage;
    retractions bounding derived revisions; undecodable slots and role payloads; invalid datasets.
  - **Named loader-level tests**, each with a positive control, since a timeline cannot show them:
    1. **Observations:** on every suite case that resolves, the observations each loader delivers (Python's and `mm`'s)
       equal Lean's `resolveAll`, delivery by delivery: source, coin, event time, fetchedAt, knownAt, slot, each value's
       `num` and the role payload (each binary64 or undefined, undefined on a retraction), retraction and final flags.
       Its controls: a loader delivering the final revision's values on every entry, a retraction's stored values, or
       every entry as final, fails it.
    2. **Parquet as cells:** each type of SOURCES.md §2 maps as stated, a string as Utf8 and as LargeUtf8, in a declared
       column and in `upstream`; a file without a `tombstone` column holds no tombstone; a null or absent `upstream`
       makes the dataset invalid on a derived revision and is never read on a tombstone; UInt64, Int32, Decimal,
       Timestamp, Null, List and Struct columns, NaN and infinite Doubles in a declared column make the dataset invalid
       and in an undeclared column are never read; the footer schema checks of SOURCES.md §2 reject duplicate
       top-level names or names reordered between schemas, not repeated leaf names inside distinct List or Struct fields. One column stored
       as Int64 in one file and Double in another keeps an integer and a non-integer. An absent declared member is
       null: without a holdout bound, an absent event time in an eligible row is invalid, in a post-V row is ignored,
       and in an empty file is harmless.
    3. **Holdout staging:** first SOURCES.md §2's footer schema checks (`fetchedAt`'s type, `tombstone`'s type and
       ordered top-level names); an event column's absence or type is not a footer schema error. Then the holdout
       check, on the event-time column of every row (tombstoned, evidence, outside-U and
       post-V rows too). A holdout crossing's refusal message is exactly
       `holdout crossing: event time {least} at or after {boundary}`, with the least crossing event time and the
       boundary in decimal. An event time that is not an integer in RULES.md's range [−2^62, 2^62 − 1]
       (in Parquet, a non-null Int64 in it) is the check's own refusal, not dataset invalidity (RULES.md §6 and
       SOURCES.md §2), with exactly `the holdout check cannot be made: an event time is not a non-null Int64 in range`.
       Any uncheckable event time takes precedence over crossings, regardless of file order. A missing event column
       is null in each row: a nonempty file is uncheckable, an empty file contributes no event times.
       Python's `as_of(dataset, t, version)` raises exactly `ValueError`, not a subclass, with the applicable message.
       For `mm`, the API is `market::load` (or its slice-5 replacement) with `holdout` Some; its `Err`'s `Display`
       is exactly the applicable message. Neither API writes to the process's stdout or stderr: the prescribed refusal diagnostic
       is the only disclosure, with no other computed result or statistic on any channel, even one invariant across
       variants. This tests the loader API, not commands' ledger-recorded output (SOURCES.md §8). Everything else, a null `fetchedAt`
       included, is found after the check passes. **Before the check passes** (SOURCES.md's access authorization: each
       stage "reading no more than it needs", the holdout stage "on the required sources' event-time columns alone",
       and a search evaluation "never materializes a holdout observation"), a loader may read file footers and hash
       bytes for dataset identity; it decodes no column chunk but the event time's, uses no footer statistic of any
       other column, and keeps nothing derived from them. Its test has two halves:
       - **Structural, the decision:** until the whole holdout check completes successfully—every file of every dataset
         the call reads (for `mm`, the run's required set)—each implementation's
         column reads project to event time alone (polars or pyarrow `columns=["eventTime"]`, Rust's projection mask).
         Every non-event-time decode or statistic use must be reachable only after that success. No test decides this
         soundly (a Python loader can reach a reader by any name; `mm`'s call graph crosses crates), so the reviews named
         at the freeze decide it, following every implementation from its first store read through every success and
         failure path, including every refusal, diagnostic and cleanup path through exit. They check output and retained
         state too. This half is not mechanical: decoding forbidden columns even if errors are suppressed or the values
         are never subsequently read fails it, including decoding after catching a refusal.
       - **Behavioural, a regression net, not the decision:** `test_holdout_check_decides_on_event_times_alone` in
         `ingest/tests/test_store.py` for Python, and its namesake in `kernel/mm/tests/` for `mm`, facing the same
         fixtures and variants, under a store path naming neither "holdout" nor the boundary. Each fixture is a row
         before the holdout and two late rows, in their own file or sharing the early row's: their event times one and
          two hours into the holdout, the later first, refused as a crossing naming the earlier; or two Doubles; or an
          Int64 null, −2^62 − 1 or 2^62 after a crossing; or an absent event-time column, each refused as uncheckable.
          Its variants: the late rows eligible and live (fetched by V, not tombstones), fetched after V,
          tombstoned, Int64-null `fetchedAt`, then 32 from a seeded generator, varying every column of the late rows but the event time
         (`fetchedAt`, null included, and `tombstone` too; a value column of another type, a NaN, an infinity, a List)
         and garbling their file but for its event-time chunk, so its footer's statistics differ too. Each call must
         give the applicable exact refusal through its API, with silent output channels, as prescribed above.
         After each refusal, the same loader
         reads an explicitly distinct, nonempty early-only dataset through its production API, matching a fresh loader's
         result and both output channels. Both datasets remain unchanged; each variant gets its own root. An event-time
         inventory may be kept only for the immutable bytes it was read from (the pinned file set and its identity).
         Whatever is decoded after the check comes only from those bytes; a changed file set is a new dataset identity,
         checked again (SOURCES.md §7). Python uses `as_of(dataset, t, version)` for both dataset identities; for `mm`,
         a distinct dataset is a distinct store root, through the API above. Its namesake also adds evidence and
         outside-U late rows, which Python cannot hold.
    4. Evidence keys and keys outside U are never delivered.
    5. A dataset whose eligible revisions of one entity map to different coins is invalid.
  - Version 1's suite and its results do not count; C7.6's resolver part is judged only on evidence produced after this
    revision, and is never reported as a pass of the original bullet.
