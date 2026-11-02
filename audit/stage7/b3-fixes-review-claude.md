I couldn't run anything: Python and writes to /tmp both needed approval, so I didn't check that the two `.jsonl` files equal `HAND` and `generate()`, or the README's counts. I recomputed about 60 of the 130 hand cases by hand against `Resolve.lean`, and every one I checked agrees.

# B3 fixes review: C7.6's revised resolver suite, the RULES.md §6–§7 revision, and C7.6's dated revision

**Reviewed:** the `mm-b3-gpt` worktree at `ce0bf0d`, with `b3-fixes.diff` and `b3-rulings.md`, on 2026-11-02. Nothing was edited.

## 1. Rulings implemented, and do the new cases catch the named bugs?

Every ruling in `b3-rulings.md` is implemented. The decoding rules are at `rules-revision.md:15-29`, the cells at `:31-34` and keys at `:36-39`. Slots and roles are at `:41-44`, the timeline restated whole at `:46-61`, and §7 has no reference to Lean (`:68-105`). The suite changes are listed below. Case 44 is fixed: `resolver_suite.py:260` now declares `BARS`.

One change goes beyond the rulings: the `rust-port-plan.md` hunk (two-run checks, `b3-fixes.diff:1108-1124`). It comes from a separate human decision and is already its own commit (`ce0bf0d`). It changes no outcome.

| Bug named in round 1 | Case that catches it (`resolver_suite.py`) |
|---|---|
| No raise to the replaced revision's knownAt | `:164-166`: a correction whose rule gives K is raised to E+3H, so the query at K sees nothing. `:167-168`: a rejected later evaluation retracts at E+3H, not at 200. `:153`: the tombstone case. |
| Derivation bound only on first revisions | `:354-360`: the second derived revision is known at 110H+LAG. Without the bound it gets 110H, because the rule's own dep term is 110H, so lag > 0 is what catches it. |
| Upstream knownAt clamped to the derived revision's fetchedAt | `:354-360`, `:361-363`: the upstream is fetched at 15H and known at 110H. The clamp gives 20H+LAG. Filtering upstream entries by knownAt instead of fetchedAt makes the revision unusable. Both are caught. |
| Min or first over two usable lineage keys | `:365-369`, in both orders |
| Event time used as the slot; a retraction carrying its own slot | `:372-379`: slots E+H and E+2H; the tombstone stores E+5H but keeps E+2H. `:380-383`. |
| Declaration order used as dependency order | `:385-387`, `:388-396` |
| One evidence tuple under two encodings | `:399-406` (a correction, which then bounds a recomputation) and `:407-410` (identical, adds nothing) |
| The final revision's values attached to every delivery | Any entry whose values differ, e.g. `:126-127`, `:438`, `:441`. `case()` fills CELLS from each entry's own revision (`:78-79`). |
| Undecodable role payloads | `:434-437` (bars: null, true, string close; trades 5.0 or null) and `:442-445` (settlement) |
| Integer vs non-integer | `:413-430`: as a value, an entity, a lineage key, a slot and a rule field |

**Bugs that still pass:**
- **A loader that delivers a retraction's stored values** (finding S4).
- **Comparing non-integers by exact decimal instead of binary64.** Only `1e999` (`:199`) tells the two apart (N1).
- **Decoding on the store's real representation** (B1).

## 2. Are the expected results right?

I recomputed these by hand against `Resolve.lean:96-131,160-174`. Every one agrees:

| Cases (`resolver_suite.py`) | Notes |
|---|---|
| `:120-181` | All of them |
| `:164`, `:167` | E+3H, then E+3H. A retraction is `max(200, E+3H)`. |
| `:185-207` | Every INVALID text, against `rules-revision.md:15-24` |
| `:233-264` | |
| `:267` | The recomputation is known at 21H. |
| `:274` | Known at 15H+LAG: the upstream retraction is counted. |
| `:291-299` | All 15 lineage texts |
| `:302-347` | Two-dependency case: E+11000 |
| `:354` | Up is known at 110H; events entries at E+2000 and 110H+LAG; visible: E+8000 three times, then 20H |
| `:361`, `:365` | |
| `:372` | Entries at P+2000 (slot E+H), 20H (E+2H), 30H (retraction, keeps E+2H) and 40H (E+3H); visible: P+3000, 20H, null, 40H |
| `:380-445` | |

I also checked `resolver_hand.jsonl` lines 102-103 against the JSON the suite generates: the escaped `\u0068` row is the same key, the timeline is [E+1000 → E+2000, 20H+1 → 20H+1000], and CELLS come from each entry's own revision.

None is wrong.

## 3. Can it be implemented from the spec alone? Does the revision contradict the frozen Lean?

The timeline (`rules-revision.md:46-61`) matches `timeline` step for step:
- `last` is every eligible revision, including those that add nothing (`Resolve.lean:120`);
- `later = last.isSome` (`:124`);
- the raise to `prev` (`:116`) and the dependency bound, range-checked (`:117`);
- retractions at `max(fetchedAt, prev)` (`:127`, `:130`);
- upstream entries cut at the derived revision's fetchedAt, retractions included (`:102-104`);
- a member naming no dependency is never read (`find?`, `:110`).

The cells rules match `Cell.sameValue` (`:67-69`), and the slot and role rules match `slotOf` and `rolePayload` (`:134-149`). I found no contradiction with the frozen Lean.

**Problems:**

- **B1. Blocking. The decoding law describes a store the actual loader never reads.**
  - `rules-revision.md:15` says "A revision's stored columns and its lineage are JSON texts", and makes the dataset invalid if any member is named `fetchedAt`, `source`, `hash` or `tombstone` (`:18-20`).
  - The real store is typed Parquet, and those metadata are ordinary columns of every row: `ingest/store.py:26` (`META = ["fetchedAt", "source", "hash"]`), `kernel/mm/src/market.rs:167-188,232`.
  - Slice 5's loader decodes "Parquet rows ... with declared columns only" (`rust-port-plan.md:19`). Yet hand case `:198` makes an undeclared nested column INVALID, and SOURCES.md §2 says extra stored columns "are allowed and kept".
  - Nothing specifies how a Parquet row becomes cells, or what fails to decode: types with no cell (Int32, decimal, timestamp, list or struct), NaN or ±Inf doubles, the lineage column's encoding.
  - **Outcomes:**
    - C7.6's "actual Rust loader" either cannot run JSON-text cases, or runs them through a JSON entry point that bypasses the loader's real decoding, which quietly weakens the requirement.
    - On real stores, INVALID vs retraction vs value is undetermined, so implementations that agree on the suite can still disagree in a run.
  - **Re-derivation:**
    - State the law on what the resolver reads: metadata (fetchedAt, tombstone), declared columns as cells, and the lineage. Undecodable declared cells, event column or lineage make the dataset invalid; undeclared columns are never read, as in Lean, where only `times` and declared columns are ever read.
    - Give one mapping per representation: JSON texts in §7, Parquet in SOURCES.md §2 (Int64 → integer, finite Double → non-integer, Utf8 → string, Boolean → boolean, null → null; anything else does not decode).
    - This flips `:195`, `:198` and the `source`/`hash`/`tombstone` members at `:202` from INVALID to "ignored". C7.6 must then say how `mm`'s loader runs the cases (B2b).
- **S1. Fix before the freeze; no judged outcome.** `rules-revision.md:12-13` says the revision "changes no result of the revisions above". Two things contradict that:
  - Under §5 and the bitemporal revision, a malformed stored row was `R_ROW`, which is a rejected evaluation and therefore a retraction. Now it is INVALID.
  - `RULES.md:27-28` says "No value is ever rounded or converted to floating point", but `rules-revision.md:32` rounds stored non-integers to binary64.
  - The revision should name both as replaced. Otherwise frozen text says two contradictory things.
- **S2. Fix before the freeze; no outcome.** At `rules-revision.md:37` the example reads `"BTC"` and `"BTC"`: the escape was lost, so the example says nothing. It should read `"\u0042TC"` and `"BTC"`. The frozen `RULES.md:19-20` has the same defect (`"t"` and `"t"`).
- **N2. Non-blocking.** §7 doesn't say how results are read. If Lean or Rust prints 1.0 as `1`, it would fail exact match. Say that results are read as §1 reads JSON: a non-integer is printed with a fraction or exponent and compared by value.
- **N4. Non-blocking (an independent implementation could disagree).** The restatement sits on top of three earlier layers that still say "not retractions" and "the earliest revision". Per CLAUDE.md §2 and "history in git", replace §6's body with the restatement. Failing that, say "where the text above differs, this governs".
- **N5. Non-blocking (one home per kind).** The size definition in §7 (`:105`) belongs only in C7.6's revision.

Two small gaps are not determined, but no case reaches them: a row naming an undeclared source, and the order within "integers, non-integers ... numbers by value" (`:99`), which I read as type rank first, as `order()` does.

## 4. C7.6's revision text (`c76-revision.md`)

These stand: ≥1,000 pairs, exact match, GPT from the spec alone, "the actual Rust loader", and judging only on evidence produced after the revision. It adds Lean and a floor of 200 pairs on keys with at least two revisions. It is honest about the coverage item it replaces (`:21-23`).

- **B2a. Blocking. It removes a named participant while saying "none is removed" (`:14-16`).**
  - The frozen bullet (`criteria.md:926`) names `store.as_of`, which `ingest/backfill.py:66` and `ingest/witness.py:84-85` still use, with version 1's selection.
  - The revision says only "Python". The README (`:23`) kills `ingest/knownat.resolve`, while `rust-port-plan.md:44-45` keeps "Python (`ingest/knownat.py`)".
  - **Outcome:** a test-only Python transcription could satisfy a bullet that named the production path. That narrows a frozen criterion.
  - **Fix:** name the Python participant (`store.as_of`'s bitemporal replacement), or record `store.as_of`'s retirement with its callers moved. If the bullet narrows, list it under "Decisions awaiting the human's review".
- **B2b. Blocking, together with B1.** "The actual Rust loader (`mm`)" needs a stated path: for example, the harness writes each case into the store's Parquet layout and runs `mm`'s read and resolve. Add a named loader-level test for the Parquet-to-cells mapping.
- **S4. Should fix before the freeze.**
  - CELLS on a retraction is the retraction revision's own cells (`rules-revision.md:101`; `resolver_suite.py:78`). Nothing delivers those: Lean's `vals` are `none` and `role` is `none` (`Resolve.lean:171-172`).
  - So `:17`'s "delivered cells" overstates what is compared, and a loader that delivers a tombstone's stored values passes.
  - **Fix:** make CELLS null on a retraction, as ROLE already is, or add the named loader-level test "a retraction delivers every input undefined".
- The three named loader-level tests (`:25-27`) are otherwise right. "Every stored event time" correctly covers tombstoned, evidence, outside-U and post-V rows (`Source.lean:202`).
- **N10. Non-blocking.** `refmm`'s decoding layer is new code, not frozen Lean. On the decoding cases, Lean is just one more implementation of the text; say so.
- **N3. Non-blocking.** Pairs on evidence and outside-U keys, which are never delivered, count toward the 1,000. The margin (3,012) is large, but say so.
- **N7.** The `2026-11-0X` date placeholder needs filling. No threshold is loosened, apart from B2a.

## 5. Generator

The structure is now really drawn:
- 1–2 dependencies of 1–3 sources each, with lags {0, 1, LAG, 100H};
- an upstream (`up`) known after it is fetched;
- slots from {e, e+H, e+2H, "x", null};
- respellings, an occasional derived-over-derived source, and declarations shuffled;
- derived fetches at upstream + {0, 1, LAG−1, LAG};
- the B-2 shape built on purpose (`:514-523`).

`pairs` counts only stores that resolve (`:548-574`); this is right for what the generator emits. CLASSES is asserted (`:657`).

**S3. Should fix before the freeze, because the tags freeze with the suite.** Several tags certify coverage that isn't there. The hand cases still catch the named bugs, so no judged pass flips today.
- `:605-606` **"known after fetched"** is set on every store, because `up` rows are always written, even when no dependency names `up`. It should require a lineage of a dependency naming `up`.
- `:639-640` **"raised to replaced"** fires whenever the knownAt equals the previous one and exceeds fetchedAt. For example, a BARS correction fetched before K gets K from its own rule. That is exactly round 1's B-1 non-discriminating shape.
- `:641-642` **"derived bound past fetchedAt"** is met when the rule's own dep term decides with lag 0, which a resolver applying the bound only to first revisions also produces. It should require knownAt = upstream time + lag with lag > 0. The upstream time can be computed from the result's upstream timelines and the row's lineage.
- `:636-637` **"retraction keeps slot"** doesn't check that the retraction's own slot (its CELLS) differs from the slot it keeps.
- `:647-648` **"nothing after retraction"** counts a query before the first entry. It should require a query at or after the retraction's knownAt.
- REACHED is checked only once Lean's results exist (README `:20`). Until then the claimed counts are the author's unpublished transcription.
- **N9.** "Two eligible revisions" includes identical repeats. There is plenty of margin.

## Verdict

**Not FREEZE.** These must be fixed first:

1. **B1:** re-derive the stored-bytes law on what the resolver reads (metadata, declared cells, lineage), with a JSON mapping in §7 and a Parquet mapping in SOURCES.md §2. Update `:195`, `:198` and `:202` to match.
2. **B2a:** name C7.6's Python participant in place of `store.as_of`, or record its retirement, and resolve the README vs port-plan conflict.
3. **B2b:** state how `mm`'s loader runs the suite, and add the Parquet decoding as a named loader-level test.

Cheap and done best before the freeze, since the text is frozen afterwards:
- **S1:** say what the revision replaces (§1's floating-point sentence; R_ROW → retraction).
- **S2:** restore the escape in the example.
- **S3:** fix the REACHED tags and the "known after fetched" class.
- **S4:** make retraction CELLS null, or add the named loader-level test.

Non-blocking: N1–N10 above.
