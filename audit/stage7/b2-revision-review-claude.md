# C7.7 review of the B2 draft (`1e2c604..96712ee`)

Reviewed 2026-11-01 20:28 UTC (15:28 EST) by a fresh-context Opus reviewer, reading only. I read the draft and its diff, both B2 consults, port plan §3, RULES.md §6, SOURCES.md §1, §2 and §5, the annex, `Sim.lean`'s `Ctx.make` and `Ctx.admissible`, `Machine.lean`'s `deliver` and the earlier GPT reviews 6 to 9. The four hashes in `b2-revision.md` §6 match the tree. `Sim`, `Machine` and `Spec` are unchanged. I did not rebuild Lean or rerun `b2-closure.lean`: the worktree has no build cache, and a capped build adds nothing to a review of statements.

**Verdict: not ready to freeze.** Two findings block: B-1 and B-2. Both are small fixes inside the definitions this revision already reopens, and neither touches the B2 design itself.

## 1. Do the new definitions say what they should?

### B-1 (blocking): a retraction recorded before the derived revision does not bound it
**Outcome it could change:** leakage, named test 13 ("a derived feed available before an upstream input").

- **Where:** `Resolve.lean:101-103` filters `!x.retraction && fetchedAt ≤ by_`. `Laws.lean:456-458` has the same premise, `u.retraction = false →`. RULES.md:157, :173 and :202-203 and SOURCES.md:119 say "not retractions".
- **Scenario:**
  - An upstream key k (a funding row, or a sighting; C5 says vanished items become tombstones, `criteria.md:442`) is delivered at known 10:01.
  - It is tombstoned at fetchedAt 15:00, a retraction known at 15:00.
  - A derived row is first recorded at F = 16:00, so it saw the tombstone. Its value leaves k out, and its lineage lists k because it read k.
  - `upKnown` ignores the retraction and returns 10:01. Because this is the key's first revision, the row is known at its rule value, say 10:05.
  - Result: a value delivered at 10:05 depends on information recorded at 15:00. For first-revision backfills, which is all of the migrated history, the derivation bound is the only protection (b2-review-claude §2(b)2).
- **Why the filter exists, and why it is now wrong:** it predates the cutoff. GPT-7 excluded later retractions because the bound then ran over the whole timeline up to V. The recorded-no-later-than cutoff from the same revision now handles "later". So the filter only hides retractions the transformation could actually see.
- **Fix (a deletion):**
  - Drop `!x.retraction &&` from `upKnown`'s filter.
  - Drop `u.retraction = false →` from L8_known's bound, and the retraction conjunct from its existence clause. The first entry is never a retraction, so "some entry recorded by F" is the same condition.
  - Amend RULES.md and SOURCES.md to match.
- **Effect:** it can only make rows later, so it cannot add leakage. It does not affect a covered zero, because polls are not tombstoned.

### B-2 (blocking): a duplicate dependency name in a row's lineage hides keys
**Outcome it could change:** leakage, test 13. It also makes the new RULES.md:204 claim "one unusable key is never masked by another" false under the Lean as written.

- **Where:** `Resolve.lean:109` takes `r.upstream.find? (·.1 == dep.name)`, the first entry only. `Revision.upstream` is a list (`Source.lean:303`), and `Trusted.canonical` (`Resolve.lean:195`) requires unique names for cells but not for lineage.
- **Scenario:**
  - A row has `upstream = [("recording", [poll@T−5m]), ("recording", [sighting recorded at F' > F])]`.
  - Lean bounds the row by the poll alone and delivers it at T.
  - The second entry, the late or unusable key, is never examined. L8_known still holds, because it quantifies over the same `find?` entry.
- **Fix:** add `(r.upstream.map (·.1)).Nodup` to `Trusted.canonical`. It mirrors the cell clause, and with it L8_known's "the lineage for dep" is the row's whole lineage. Defining the lookup as `filter`/`flatMap` would also work, but it changes the statement text. The flaw predates B2, but B2 is where the masking claim is made.

### Non-blocking findings

**N-1. `differs` ignores lineage, so strict lineage can lose a row for good.**
- **Outcome:** missingness only (definedness of derived rows, mainly on the stage 10 forward track). No leakage.
- **Where:** `Resolve.lean:74-76`, `:119` and `:125`.
- **Scenario:**
  - Revision R1 at F1 lists a poll recorded just after F1, so it is unusable. Nothing is delivered, but `last := R1`.
  - The recomputation R2 at F2 has identical cells and good lineage. It counts as "identical to the one before it" and adds nothing.
  - The key is never delivered.
- B2's strict `mapM` makes the first step more likely. Comparing `upstream` in `differs` would deliver R2 as a correction, at or after F2. Consider it now or record it as a limitation.

**N-2. The entity encoding is an unstated decoding obligation.**
- **Outcome:** leakage only through a non-injective decoder.
- `Revision.entity : String` stands for an evidence tuple (key, id, created), but neither `Trusted` nor the `Revision` docstring requires the encoding to be injective. SOURCES.md:59 does say "compared exactly as a tuple".
- If two tuples alias, a lineage key of a sighting recorded after F still finds the alias's earlier delivery and passes the new existence clause. Timing stays conservative, but the B2 strictness is defeated.
- Fix: state it in `Trusted.canonical`, or in the `Revision` docstring and as a B3 suite case.

**N-3. Duplicate sightings make the whole dataset invalid.**
- **Outcome:** run refusal, which is a C7.4 risk, not leakage.
- For sightings, observed equals fetchedAt for both live records and backfills (annex :21-23). So two equal sightings at one observation time collide on `(entity, event, fetchedAt)`, and `validAt` (`Resolve.lean:59-61`) invalidates the dataset.
- The annex should state that the store holds no exact duplicates, and a C7.4 fixture should check it.

**N-4. Evidence revisions are kept out of U by decoding alone.**
- They get `coin = none` only by decoding. `Ctx.make`'s filter (`Sim.lean:222-223`) backs this up, so no outcome changes. The draft's §5.4 states this correctly.

**Paths I looked for and found closed:**
- **Key of a source outside its dependency.** `Resolve.lean:100` checks membership. The dependency's sources are in `depends` (`Source.lean:53`), so they are in `required`'s closure. Each is then certified and holdout-checked: `L5_certified`, stage 2 over every stored row's event, and evidence's event is `observed`/`recv`.
- **A later correction moving an earlier derived row.** The cutoff at `fetchedAt ≤ F` holds, and an upstream entry's known depends only on its own prefix.
- **A covered zero.** Polls are known at `recv ≤ b ≤ T`, so the row is usable at T. The only exceptions are N-1 and N-3.
- **The holdout.** An evidence row observed during the holdout fails stage 2, and a lineage key with no stored row is unusable.

## 2. Are L8_known and L8_monotone strong enough?

- **L8_monotone:** only the key parameter changed (`Laws.lean:432-441`). Its content is unchanged and it is not vacuous.
- **L8_known:**
  - The frozen clauses are kept word for word, apart from the key type.
  - Three conjuncts are new: a nonempty lineage, source membership, and a delivery recorded by F. Each is non-trivial and matches `b2-revision.md:39-42`.
  - Nothing is weakened compared with the frozen statement.
- **Two gaps:**
  - It inherits B-1's retraction premise, so it is weaker than the intended bound.
  - Its "the lineage" means only the first `find?` entry (B-2).
- **After both fixes:** the bound loses `u.retraction = false →`, so it is strictly stronger. The proof change is local to `hup`.

## 3. The 18 laws whose definition closure changes

Each law's meaning is preserved. Mapping a frozen registry (`source := i`) to the new one (`sources := [i]`) gives the same `depends`, `valid`, `closure` and `matches`.

| Law | What changes | Meaning preserved? |
|---|---|---|
| L1 ×3, L2_units, L4 ×2 | Only the `Registry.Valid` hypothesis. Range and acyclicity now cover every source of a dependency. | Yes |
| L2_checker, L3_rewrite | `WF` and closure | Yes |
| L5_admitted, L5_order, L5_staged, L5_shape, L6_bounded | Abstract over `stage1`/`required` | Yes. "Required" now includes every source of every dependency, transitively. This is the intended strengthening, and it closes the test-15 path the first-source mutant demonstrates (1,364 disagreements). |
| L5_text | `required` ⊇ the program's sources | Yes |
| L5_certified | "RULES.md §6's resolution" now means the entity-keyed `resolveAll` | Yes. Its holdout clause covers evidence through the declared event column. |
| L7_reads | Structures only | Yes |
| L8 ×2 | See §2 | See §2 |

`b2-closure.lean` traverses statement types and definition bodies, not proofs. That is the right closure, and the table is plausible.

## 4. Do the specs agree with the Lean?

- **Agree:** the RULES.md B2 bullets, SOURCES.md §1 and §5, the annex keys and lineage, port plan §3, and `source.rs`'s controls (equal to Lean's as a set).
- **Contradict the Lean today (not a judged outcome):** the "not retractions" text at RULES.md:157, :173 and :202-203 and SOURCES.md:119. These are B-1, and they change together with it.
- **Stale:**
  - SOURCES.md:75 still says revisions are "keyed by (coin, `eventTime`)". It should now say stored entity and event time, or the evidence declaration's own columns.
  - SOURCES.md:41's `entity` row still says it "must be `"coin"`", with no pointer to evidence declarations.
  - RULES.md:192's heading says "(draft, frozen only after its review…)". Change it at the freeze.
  - These can change no outcome, but slice 5 reads SOURCES.md §2.
- **Coverage gap in `admission_differential.py:36-38`:** it never generates an evidence key with two non-event columns. The annex's sightings shape, (key, id, created) plus observed, has three, so the multi-column `entityColumns` case is never exercised. The only possible outcome is a refusal mismatch on controls. Cheap to add.
- **Cosmetic:** `Resolve.lean:92` and `Source.lean:37` exceed the file's line width.

## 5. The open questions

1. **Empty `Dep.sources` (draft §5.5):** leave `Registry.valid` as it is.
   - The laws take `reg.Valid` as a hypothesis, so a weaker Lean validity yields stronger theorems.
   - Such a declaration only makes its rows unusable.
   - `mm` rejects it, and the differential never generates one.
   - Record this as settled. The same reasoning covers the evidence event column being in `times`, which `mm` checks and Lean need not.
2. **Two stored entities mapped to one coin (§5.3):** keep the draft's behavior.
   - At different event times, entity keys and coin keys give the same timelines.
   - At one event time, each key with any entry has a final entry, so `Ctx.admissible` (`Sim.lean:444-450`) refuses the run at position 6. The frozen Lean instead merged them silently as a correction.
   - Moving this into `validAt` as an injectivity check would refuse the same cases one stage earlier and add nothing.
   - RULES.md:197-199 is accurate.
3. **Lineage completeness (§5.6):** agreed, it stays a known limitation that C7.3's verifier carries.
4. **The event column as a certification fact (§5.7):** agreed.
   - CERTIFICATES.md:62 covers it in principle ("a producer's timestamp value alone is never evidence").
   - Add an explicit verifier test that an evidence declaration's event column is set by the recorder, for C7.3.
5. **Evidence `coin = none` (§5.4):** no change. Add a B3 suite case: an evidence row decoded with a coin produces no delivered observation.

## Required before FREEZE

1. **B-1:** drop the retraction filter from `upKnown` and L8_known, amend RULES.md and SOURCES.md to match, re-prove `timeline_known`.
2. **B-2:** add `(r.upstream.map (·.1)).Nodup` to `Trusted.canonical`.

Then record new hashes in `b2-revision.md` §6 and rerun the build, the axiom check and the admission differential. Fixing N-1, N-2 and the SOURCES.md:75 staleness in the same revision is recommended; none of them blocks the freeze.
