# B3 draft: C7.6's dated revision (not committed to `audit/criteria.md`)

Draft text, from the decision of 2026-11-02 01:33 UTC ("B3's draft suite is not frozen", `audit/decisions.md`). After
its review it is appended beneath C7.6's resolver bullet in `audit/criteria.md` and committed alone, before the suite's
freeze and before anything is judged. The original lines stay as written. Everything below the line is the text.

---

- **Revision of 2026-11-0X (C7.6's resolver bullet), before anything is judged.** Why: the bullet's "latest revision
  chosen before the availability filter" is version 1's selection, which the human's bitemporal decision of 2026-10-26
  removed (`kernel/RULES.md` §6, its dated revisions through B2, `audit/stage7/laws-frozen.md`, 2026-11-02 00:55 UTC);
  the bullet would otherwise demand the leak the decision fixed. It loosens nothing:
  - **The resolver under test** is RULES.md §6 with its dated revisions through B3, cases in §7's format.
  - **Who matches exactly:** GPT's resolver written from RULES.md, SOURCES.md and §7 alone, never the suite; Python;
    the actual Rust loader (`mm`); and Lean's `timeline` and `resolveAll` through `refmm`, which decodes the case texts
    itself. Lean is added; none is removed.
  - **What is compared:** every key's whole timeline (fetchedAt, knownAt, retraction, slot, delivered cells and role
    payload) and, per query, what it sees.
  - **How much:** at least 1,000 (key, query) pairs from stores that resolve (neither invalid nor rejected), over
    multi-revision, multi-source fixtures, at least 200 of them on keys with at least two eligible revisions.
  - **Covering:** an earlier value visible until a correction's knownAt, and no fallback through a retraction (this
    replaces "the latest revision chosen before the availability filter, with no fallback to an older revision");
    tombstones and cutoffs; corrected rules; the derivation bound over dependencies spanning sources; strict lineage;
    retractions bounding derived revisions; undecodable slots and role payloads; invalid datasets.
  - **Named loader-level tests**, each with a positive control, since a timeline cannot show them: the holdout check
    reads every stored event time before resolution; evidence keys and keys outside U are never delivered; a dataset
    whose eligible revisions of one entity map to different coins is invalid.
  - Version 1's suite and its results do not count; C7.6's resolver part is judged only on evidence produced after
    this revision, and is never reported as a pass of the original bullet.
