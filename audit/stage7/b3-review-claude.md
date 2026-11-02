# B3 draft review: the revised C7.6 resolver suite

**Reviewed:** branch `stage7` at `7b778f2`, checked 2026-11-02. Nothing was edited.

**How I checked:**
- The frozen hashes match `laws-frozen.md`'s last table: `Source.lean` c52d9c66…, `Resolve.lean` 726dace3…, `RULES.md` ce849485….
- I recomputed every hand case by hand against `Resolve.lean`'s `timeline` (`:96-131`) and RULES.md §6 with its revisions through B2.
- I tested resolver bugs against the cases by tracing them by hand, not by running them. The sandbox refused every `python3` invocation, so:
  - I could not check that the two `.jsonl` files equal `HAND` and `generate()`;
  - for the generated stores, I could only reason about which code paths they reach.

## 1. Do the expectations agree with the frozen Lean and RULES.md?

All 60 hand expectations agree with `timeline`, and none is wrong. One (case 44) depends on a decoding choice the spec does not make (1d).

The hard cases, recomputed. P = E+5000, LAG = 1000.

| Case | Lines | What I get | Agrees |
|---|---|---|---|
| Covered zero, lineage of polls only | `resolver_suite.py:210-212` | The poll is known at max(P, P+1000) = P+1000. The derived row: the rule gives max(E, P+1000), the lag bound P+2000, and it is a first revision, so its fetchedAt does not raise it. Entry `[P+3000, P+2000, F, E]`. | ✓ |
| A key of a source outside its dependency | `:214-218` | `upKnown` checks `!dep.sources.contains` (`Resolve.lean:101`), so the row is unusable; as a first revision it adds nothing; `[]`. | ✓ |
| A key with no delivery by the derived revision | `:220-222` | The poll is fetched at P+4000, after the derived row at P+3000, so it has no entry by then: unusable. | ✓ |
| No masking | `:223-227` | `mapM`: an unusable SK fails the row even beside a good PK. | ✓ |
| A later upstream correction | `:241-246` | The sighting's entries are [E+1000] and [20H]. The derived row at E+8000 sees only E+1000, so it is known at E+2000 and does not move. The recomputation at 21H is known at max(20H, 21H, E+2000, 20H+LAG) = 21H. | ✓ (but see B-2) |
| A retraction bounding a derived revision | `:248-252` | The sighting retracts at max(15H, E+1000) = 15H. The derived row at 16H takes up = 15H, known at 15H+LAG. | ✓ |
| A repeated dependency name in lineage (F-1) | `:264-266` | INVALID: the duplicate member is already malformed under RULES.md §1 (`:21`). | ✓ (proposed rule) |
| One tuple, two encodings (F-2) | `:198-199`, `:201-208`, `:254-262` | `\u0042TC` with members permuted is the same key, so the revision is identical and adds nothing. `("ab","c")`/`("a","bc")` and `1`/`"1"` are four keys. The escaped `h` in lineage resolves; the string `"1"` has no delivery. | ✓ |
| N-1 | `:291-293` | The second revision has identical cells and `differs` ignores lineage, so it is skipped and the key gets `[]`. | ✓ (freezes a recorded limitation as expected behavior, which is correct for Lean) |
| Derived over derived | `:307-314` | The upstream time is the events row's knownAt P+2000, not its fetchedAt P+3000. | ✓ |
| Two dependencies, each with its own lag | `:295-305` | max(E+6000+1000, E+1000+10000) = E+11000; lacking `b` makes the row unusable. | ✓ |
| Slot does not decode / slot null | `:276-282` | `"x"` as first revision: nothing; the next revision is `later` (`last.isSome`), so it is known at F. Null as a later revision: a retraction that keeps slot E. | ✓ |
| Tombstone tie at the same knownAt | `:152-153` | Both entries are known at 110H; the latest in the timeline is the retraction, so nothing is visible. | ✓ |

I also checked every bars case (`:119-196`): the cutoff, identical repeats, the absent-or-null rule, ±0, tombstone then restore, a first tombstone followed by `later`, REP rejections, overflow, negative times, the INVALID cases and stored key order. All agree.

**Misdescribed comments (no outcome on their own; they hide B-1):**
- `:128` says case 6 tests "a correction fetched before the first's rule time is known at the replaced one's knownAt". Its own rule value is already K, so the raise to the replaced knownAt does no work.
- `:151` says the same of case 17's correction under LATE: its own value is already 110H.

## 2. Would the suite catch a wrong resolver?

Hand cases compare whole timelines, so any knownAt difference in a covered path is caught regardless of query times. That is a real strength.

**Caught by hand cases:**
- dropping the lag (`:210`);
- excluding retractions from the upstream time, the pre-B2 rule (`:248`);
- `filterMap` masking instead of `mapM` (`:223`);
- no source-membership check (`:214`);
- no cut at the derived revision's fetchedAt, i.e. history rewriting (`:220`, `:241`);
- a later revision not raised to its fetchedAt (`:125`, `:150`);
- a retraction that falls back to the older value (`:164`, `:272`);
- `later` computed from deliveries instead of eligible revisions (`:150`, `:162`, `:276`);
- comparing with the last delivered rather than the last stored revision (`:287`, `:291`);
- comparing undeclared columns (`:139`);
- version 1 selection (`:125`);
- a retraction that drops its slot (`:272`);
- a default time substituted for an empty lineage, which loses nothing but delivers a zero it shouldn't (`:229`);
- a polls-only zero lost because the dependency is reduced to its first source (`:210`);
- reading past V (`:120`, `:127`, `:187`);
- keying by raw bytes (`:198`, `:254`).

**Bugs the suite would pass:**

- **B-2 (blocking; leakage).** The derivation bound applied only to a key's first delivered revision.
  - Lean applies it to every revision (`Resolve.lean:117`).
  - No hand case has a later derived revision whose bound (upstream knownAt + lag) exceeds its own fetchedAt and the knownAt it replaces. At `:241` the 21H fetchedAt dominates 20H+LAG.
  - Every upstream rule in the derived hand cases is `max(·, fetchedAt)`, so the upstream knownAt never exceeds the upstream's fetchedAt. With an upstream like `LATE` (fetched at 100, known at 110H), such a resolver delivers a recomputed derived row at 50H instead of 110H+lag: a named test 13 leak of 60 hours.
  - The generator reaches the case only by coincidence: an upstream and a derived fetchedAt in the same hour, offsets less than LAG apart, and lag = 1000.

- **B-1 (blocking; leakage within the spec).** No raise to the replaced revision's knownAt, for values and for rejected-evaluation retractions.
  - Only the tombstone raise is tested (`:152`).
  - A resolver missing `Max.max k p` (`Resolve.lean:116`), or `max(fetchedAt, p)` for a rejected later evaluation (`:130`), passes every hand case.
  - Fix: REP with `reportedTime` E+3H, then a correction to E fetched at 200, should be known at E+3H, not K. Add the same with the second revision rejected.

- **B-3 (blocking; wrong event tick).** The slot always equals the event time.
  - Every hand slot is E or does not decode; the generator draws only E or `"x"` with eventTime E.
  - So a resolver that outputs eventTime as the slot, or makes a retraction carry its own event time instead of the retracted delivery's slot, passes. Event inputs are keyed by slot (SOURCES.md:109-111).
  - Fix: add a slot E+H, a correction that moves the slot, and a retraction after the move, which keeps E+H.

- **Roles: undecodable payloads delivered (blocking, see 4c).** A resolver that skips `rolePayload` in `decodes` (`Resolve.lean:154`) passes. The bars and settlement role providers are what execution reads.

- **Non-blocking (the generator likely covers these through Lean, but no hand case does):**
  - taking the minimum, or the first key, over two usable lineage keys of one dependency: no hand lineage has two usable keys;
  - using min(fetchedAt, knownAt) for the upstream time;
  - an evidence key stored under a second encoding (F-2's own scenario is evidence, which has no coin alias check). Case `:198` covers only a coin-keyed source.

- **Holdout crossing** is outside the resolver. Stage 2 reads event times (`Source.lean:283-284`), and `admission_differential.py` covers it. The resolver-side analog, reading past V or past the derived revision's fetchedAt, is caught.

**Generator.** It is broad in revision sequences (tombstones, corrections, repeats, REP rejections, undecodable slots, absent and foreign lineage keys, partial cutoffs) but it repeats one structure:
- one registry;
- one dependency over `[sight, poll]`;
- one derived event time E, with slot = E;
- lag ∈ {0, 1000};
- evidence rules `max(·, fetchedAt)`;
- no derived over derived, no second dependency;
- no upstream known after its fetchedAt except early sightings;
- no encodings beyond `json.dumps`, no decoding failures.

To make its coverage real:
- draw the registry shape: 1–2 dependencies, 1–3 sources each, lags {0, 1, LAG, 100H};
- include an upstream rule whose value exceeds fetchedAt;
- draw slots from {E, E+H, `"x"`, null}, and several derived event times;
- draw derived fetchedAts relative to upstream ones (+{0, 1, LAG−1, LAG}).

Also, the README's 1,172 pairs (`:5`) count the two INVALID stores (`resolver_suite.py:372-373`). Count only stores that resolve, and add a floor on keys with at least two eligible revisions.

## 3. Can someone implement this from the spec alone?

These are expectations the spec does not determine:

- **a. Undecodable bytes give INVALID.** This is open point 1, and it covers six hand cases (`:181-187`, `:264-269`).
  - Worse, the current spec determines something else. RULES.md §5 gives `R_ROW` for a malformed row (`:85-87`), and the bitemporal revision makes a rejected evaluation a retraction (`:158`). Read literally, that is a per-revision retraction, which is version 1's suite behavior.
  - Blocking, together with 4a.
- **b. RULES.md §7 is stale** (`:219-221`). It still says resolver cases compare "the selected revision's fetchedAt, its effective knownAt or code". The case format exists only in the draft's docstring, which also carries normative rules: "members naming no declared dependency are not read" (`:31`) and the INVALID list (`:32-35`).
  - Move the rules and the format into a dated revision of RULES.md §6–§7, and give GPT that, not the suite file.
- **c. Key order.** "Each source's keys in the order of their first eligible row" (`:39-40`) means stored row order (case `:192` puts ETH, fetched at 50, last).
  - The spec says delivery order is "never stored row order" (RULES.md:179), so a correct implementer may sort by fetchedAt and fail.
  - Compare keys as a set keyed by (source, entity, event), or by a canonical order. This changes only exact-match verdicts.
- **d. Case 44 (`:236-239`) is indeterminate.** Its unread member lists `["bars",…]`, but `bars` is not declared in `derived`.
  - Lean's `Revision.upstream` holds source indices (`Source.lean:306`), so an undeclared source cannot be decoded into it. The self-check's transcription evidently keyed sources by name.
  - Declare `BARS` in that case, as `:214` does. Then decide whether a lineage key naming an undeclared source makes the dataset invalid (the Lean-faithful choice) or names a key with no delivery.
- **e. Lineage key shape is undefined.** It is unclear whether a wrong entity arity (`["sight", ["h"], E]`) or a non-integer event is INVALID or a key with no delivery, and whether an unread member is shape-checked at all. No case reaches these, but the sentence in 4a must settle them.
- **f. Not defined for cells:**
  - nested arrays or objects in a cell, which Lean's `Cell` has no constructor for;
  - an out-of-range or non-integer event column;
  - whether a cells member named `tombstone` (the revision column) is reserved;
  - whether a slot must be on the hour grid (SOURCES.md:109 says on the hour grid; `slotOf` accepts any integer, `Resolve.lean:149`).

  No case reaches these.
- **g. RULES.md must be read in order.** The "not retractions" wording appears at `:156-157` and `:172-173` and is reversed only at `:202-204`. That is determined, but fragile; a consolidated restatement in the new revision would help an independent implementer.

## 4. The README's open points

**(a) Undecodable bytes.** "Dataset invalid" is right.
- Keys are now decoded from the cells, so a revision that does not decode has no key to retract.
- It is a fault of the store or encoder, not of the feed, and `Trusted.canonical` assumes it away. Refusing the run cannot add a false discovery.
- F-1 needs no clause of its own: §1 already makes a duplicate member malformed at any depth. Proposed dated sentence for RULES.md §6:

> **Revision of 2026-11-0X, B3: stored bytes.** A revision's stored columns and its lineage are JSON texts read as §1 reads them. A dataset is invalid, as when two eligible revisions of one key share a fetchedAt, if any eligible revision does not decode:
> - its stored columns are not an object whose members are scalars (an integer, a non-integer number, a string, a boolean or null), or one is named `fetchedAt`, `source`, `hash` or a revision column;
> - its event column is not an integer in range;
> - its lineage is not an object whose every member is an array of keys `[S, [v1, …, vk], e]`, with S a declared source and e an integer.
>
> §5's `R_ROW` is never a resolver result. A lineage member not named by a declared dependency is not read. A key whose entity values match no stored key of S is a key with no delivery.

Add in the same revision: an integer and a non-integer number are different values even when numerically equal (`Cell.sameValue`, `Resolve.lean:67-69`); a slot decodes if and only if it is an integer.

**(b) C7.6's frozen bullet** (`criteria.md:926-929`).
- It must get a dated revision before the suite judges anything. As written it demands "the latest revision chosen before the availability filter", which is the leak the human's 2026-10-26 decision removed. Judging this suite against it would redefine done.
- Commit the revision before the suite's freeze, so the suite is frozen against the coverage list it serves.
- It should say:
  - **Why:** the bitemporal decision (RULES.md:143) and B2 (`laws-frozen.md`, 2026-11-02 00:55 UTC).
  - **The resolver under test** is RULES.md §6 with its dated revisions through B2, and Lean's `timeline` is its reference.
  - **Who must match exactly:** GPT's resolver written from the spec alone, Python, Rust (`mm`'s loader) and Lean through `refmm`. This adds an implementation and removes none.
  - **What is compared:** every key's whole timeline (fetchedAt, knownAt, retraction, slot) and its visibility per query.
  - **How much:** at least 1,000 (key, query) pairs from stores that resolve, over multi-revision, multi-source fixtures, with a floor on keys with at least two revisions.
  - **What must be covered:** an earlier value visible until a correction's knownAt, and no fallback after a retraction (this replaces "latest chosen before the filter"); tombstones and cutoffs; corrected rules; the derivation bound over dependencies spanning sources; strict lineage; retractions bounding derived rows; invalid datasets.
  - **Version 1's suite and results do not count.** The stage is judged only on evidence produced after the revision, and the revision is not reported as a pass of the original.

**(c) The cases not yet covered:**
- **Roles: blocking.** Add `roles` to the case format now, since a format change after the freeze needs a dated revision. Also define `num`: `rolePayload` leaves it as a parameter (`Resolve.lean:134-145`), and `trades` must be `.int`, so `5.0` makes the payload undecodable. Hand cases:
  - a bar with a null `close`, as first revision and as a later one;
  - `trades` as `5.0`;
  - a settlement `rate` as a string.
- **An integer against a double: state the rule (4a), add one case.** Missing it changes only a timeline's shape, never a value, but exact match needs it determined.
- **`validAt`'s one-coin clause:** correctly omitted, since it cannot fail in this format.
- **A non-integer event column:** covered by the sentence in 4a; add one INVALID case.
- **Registry invalidity:** correctly left to `admission_differential.py`.

**(d) The swap.** The plan is right, with three conditions:
1. The freeze commit replaces the suite files and the size check in `test_suite.py`, and removes the old suite's resolver path from `test_three_implementations.py`. `knownat.resolve`, `gpt_resolver.py` and `rule.rs::resolve`/`effective` die in slice 5, when their callers move. Deleting them at the freeze would leave callers broken, and keeping the old test would fail "tests pass before every commit".
2. GPT's new resolver gets RULES.md, SOURCES.md and the case format from RULES.md §7, never the hand expectations.
3. `refmm`'s resolver mode decodes the case texts with `Ref/Json.lean`, not with Python's pre-decoded form. Otherwise the decoding rules of 4a are checked by only one implementation.

## Verdict

**Not FREEZE.** These must be fixed first:

1. **B-1:** hand cases where the raise to the replaced revision's knownAt does work, for a value correction and for a rejected later evaluation. The current comments at `:128` and `:151` claim this but don't test it.
2. **B-2:** hand cases where the derivation bound decides a later derived revision, including an upstream known after its fetchedAt. Extend the generator as in §2.
3. **B-3:** slots that differ from the event time, a slot moved by a correction, and a retraction after the move.
4. **Roles** in the case format, with `num` defined, and their hand cases.
5. **The decoding rules, the cell rules and the case format** into dated revisions of RULES.md §6–§7 (4a, 3b). Settle the open shape questions (3e, 3f) in the same revision. Fix case 44 (3d).
6. **Key order** compared as a set or a canonical order (3c).
7. **C7.6's dated revision** (4b), committed before the suite's freeze and in any case before anything is judged.

Not blocking:
- the misdescribed comments, once B-1 replaces them;
- a hand case with two usable lineage keys, and an F-2 evidence variant;
- the README's pair count excluding INVALID stores.
