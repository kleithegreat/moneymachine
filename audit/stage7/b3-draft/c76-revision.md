# B3 draft: C7.6's dated revision (not committed to `audit/criteria.md`)

Draft text, from the decisions of 2026-11-02 01:32 UTC (2026-11-01 20:32 EST) ("B3's draft suite is not frozen") and
05:55 UTC (00:55 EST) ("B3's fixes are not frozen; second round ruled on", `audit/decisions.md`). After its review it is
appended beneath C7.6's resolver bullet in `audit/criteria.md` and committed alone, before the suite's freeze and before
anything is judged. The original lines stay as written. Everything below the line is the text.

---

- **Revision of 2026-11-04 (C7.6's resolver bullet), before anything is judged.** Why: the bullet's participants, format
  and size predate the bitemporal resolver (revision of 2026-10-26 23:29 UTC (19:29 EDT) above) and RULES.md §6's B2 and
  B3 revisions (`audit/stage7/laws-frozen.md`); this says what is compared, by whom, and how much. It loosens nothing:
  - **The resolver under test** is RULES.md §6 with its dated revisions through B3, cases in §7's format, stored rows
    mapped to cells by §7 (JSON texts) and SOURCES.md §2 (Parquet).
  - **Who matches exactly:** GPT's resolver, written from RULES.md, SOURCES.md and §7 alone, never the suite;
    `store.as_of`'s bitemporal replacement in `ingest/store.py`, the production path its callers read, never a
    test-only transcription; the actual Rust loader (`mm`); and Lean's `timeline` and `resolveAll` through
    `refmm resolve`. Lean is added; none is removed. `refmm`'s decoding layer is new code, not frozen Lean, so on the
    decoding cases Lean is one more implementation of the text.
  - **How the loaders read a case:** each case is written into the store's Parquet layout, one file per row under its
    source's directory, holding the row's metadata and its declared members by SOURCES.md §2's mapping (undeclared
    members are left out, as neither mapping reads them), and the store's reader (Python) and `mm`'s loader (Rust)
    resolve that store. A case with a text that does not decode as JSON has no Parquet image; GPT's resolver and Lean
    read every case's texts.
  - **What is compared:** every key's whole timeline (fetchedAt, knownAt, retraction, slot, cells and role payload,
    none on a retraction) and, per query, what it sees.
  - **How much:** the suite's size is its (key, query) pairs over the generated stores that resolve (neither invalid nor
    rejected): at least 1,000, at least 200 of them on keys with at least two eligible revisions. Keys never delivered
    (evidence, outside U) count, since their timelines are compared.
  - **Covering:** an earlier value visible until a correction's knownAt, and no fallback through a retraction;
    tombstones and cutoffs; corrected rules; the derivation bound over dependencies spanning sources; strict lineage;
    retractions bounding derived revisions; undecodable slots and role payloads; invalid datasets.
  - **Named loader-level tests**, each with a positive control, since a timeline cannot show them:
    1. **Observations:** on every suite case that resolves, the observations each loader delivers (Python's and
       `mm`'s) equal Lean's `resolveAll`, delivery by delivery: source, coin, event time, fetchedAt, knownAt, slot,
       each value's `num` and the role payload (each binary64 or undefined, undefined on a retraction), retraction and
       final flags. Its controls: a loader delivering the final revision's values on every entry, a retraction's
       stored values, or every entry as final, fails it.
    2. **Parquet as cells:** each type of SOURCES.md §2 maps as stated; Int32, Decimal, Timestamp, Null, List and Struct
       columns, NaN and infinite Doubles in a declared column make the dataset invalid and in an undeclared column are
       never read; one column stored as Int64 in one file and Double in another keeps an integer and a non-integer.
    3. **Holdout staging:** the holdout check reads every stored event time, of tombstoned, evidence, outside-U and
       post-V rows too, before any revision is resolved.
    4. Evidence keys and keys outside U are never delivered.
    5. A dataset whose eligible revisions of one entity map to different coins is invalid.
  - Version 1's suite and its results do not count; C7.6's resolver part is judged only on evidence produced after
    this revision, and is never reported as a pass of the original bullet.
