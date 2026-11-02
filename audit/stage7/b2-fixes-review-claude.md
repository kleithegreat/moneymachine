# C7.7 review of the B2 fixes (`11da863..4a6a6d4`)

Reviewed 2026-11-02 00:53 UTC (2026-11-01 19:53 EST) by a fresh-context Opus reviewer. I only read files and edited nothing.

**What I checked:**
- `b2-fixes.diff` is byte-identical to `git diff 11da863..HEAD` over the paths you listed.
- The four hashes in `b2-revision.md` §8 match the tree: `Source.lean` `c52d9c66…`, `Resolve.lean` `d4ac6348…`, `Laws.lean` `80d1f575…`, `RULES.md` `5dff7ce6…`.
- `laws-frozen.md`'s tables hash only definition files and RULES.md, never proofs or SOURCES.md, so the §8 table follows the established pattern.

**What I did not do:**
- I did not rebuild Lean. The worktree has no `.lake/build`, and a review of statements gains nothing from a rebuild.
- I did not recompute the evidence counts from `data/`.

**Verdict: FREEZE.** None of the findings below can change a judged outcome under the frozen Lean. Two of them (F-1, F-2) are obligations that B3 and slice 5 must carry. Fixing them does not require reopening the Lean.

## 1. Does each fix do what its ruling says, and nothing else?

**(a) A retraction recorded by the derived revision bounds it: done, and nothing else changed.**
- `Resolve.lean:102-103`: the filter is now just `decide (x.rev.fetchedAt ≤ by_)`.
- `Laws.lean:456-457`: L8_known's existential and universal clauses lost `u.retraction = false`.
- `Proof/Resolve.lean:332-357, 389`: the only proof edits are the `hup` lemma and its single use, which gets one fewer argument.
- The prose matches:
  - the `timeline` docstring (`Resolve.lean:90-91`);
  - RULES.md B2 bullet (`RULES.md:202-204`), which says explicitly that it replaces "not retractions" in the two earlier dated revisions (`:156-157`, `:172-173`). Leaving those lines in place is correct, since dated revisions are append-only;
  - SOURCES.md §5 (`SOURCES.md:129-131`);
  - the annex's lineage paragraph (`migration-annex.md:55-57`);
  - the supersession row in `laws-v2-draft.md`.
- The fix only adds entries to a maximum, so it can only make rows later.

**(b) Unique dependency names in a lineage, and an injective stored-entity encoding: done in `Trusted.canonical`** (`Resolve.lean:198-201`).
- `(r.upstream.map (·.1)).Nodup` is exactly Opus B-2's proposal.
- The encoding clause reads: if two rows of a source share a stored entity, then every entity column has the same cell in both. That is injectivity of tuple → entity, as N-2 and GPT asked.
- The ruling's other half, "no two stored entities map to one coin," is stated where it was ruled to go: in the general contract (`SOURCES.md:86-88`, `CERTIFICATES.md:71`, which is in §3 Tests). It is not in Lean, matching the earlier reviews' conclusion that `Ctx.admissible` already refuses the same-event case.
- Limits of both clauses: F-1 and F-2.

**(c) `Registry.valid` rejects an empty `Dep.sources`: done** (`Source.lean:124-125`, `!dep.sources.isEmpty`).
- `Main.lean:296` checks `reg.valid` before `admit`.
- `mmdump` returns `invalid 0` on any parse failure (`main.rs:480-482`).
- The generator draws an empty source list for 1% of dependencies (`admission_differential.py:33-34`).
- `caseDecl` now builds the generator's real rule, so `ruleOk` is actually exercised. `Main.lean:280` matches `admission_differential.py:56`, and `lean_decl` adds `fetchedAt` to Lean's `times`, so the `.field "fetchedAt"` term types.
- The positive control (570 disagreements with the clause removed, all of them empty-dependency cases) shows the negative case is reached.
- Side effect, intended: the differential now exercises the whole of `Registry.valid` (range, acyclicity, evidence shape, slot, role columns), not just admission.

**(d) The dated SOURCES.md revisions: done.** Each item GPT B2 and Opus listed has a dated sentence that matches the Lean:

| Item | SOURCES.md | Lean |
|---|---|---|
| Event tie order | :98-101 | `Sim.lean:224-231` |
| Retractions | :112-116 | `Resolve.lean:121,127,130`, and `resolveAll`'s slot carry |
| Required set | :161-164 | `Meta.delivered` / `Meta.required`, `Source.lean:264-268` |
| Extra columns not compared | :84-85 | `differs` |
| Staged authorization | :169-178 | `stage1` / `stage2` / resolve / `admissible` / `inScope`, `Sim.lean:495-499` |
| §1 `entity` and `cadence` rows; §2 key | :42, :45, :76-79 | |

One stale clause was left behind (F-3).

The extras ruled to go "with them" are all present: the pinned encoding (CERTIFICATES §5 `:84-85`, annex §5), no exact duplicates (annex `:26-27` and a fixture at `:102`), evidence keys with up to three non-event columns (`admission_differential.py:37`), and the supersession rows.

I found no change beyond the rulings.

## 2. Concrete paths

I checked each path you named against the fixed definitions.

- **Derived value used earlier than it was known.**
  - Scenario: upstream key k is delivered at known 10:01 and tombstoned at fetchedAt 15:00. A derived row is first recorded at 16:00.
  - Now: `upKnown` takes the maximum over both entries, so the row is known no earlier than 15:00 + lag. That is Opus B-1, closed.
  - What remains open: a key the lineage omits, or lists under a name that is not a declared dependency (`known` only looks up `d.deps`' names, so other names are ignored). Both are the recorded lineage-completeness limitation (§5).
- **Duplicate dependency name hiding a key.**
  - Scenario: `[("recording",[poll@T−5m]), ("recording",[late sighting])]`.
  - Excluded under `Trusted`, but only as a decoding obligation: see F-1.
- **Holdout crossing.** The fixes don't touch it. Stage 2 still reads every stored row's event time across the full closure. Counting a retraction in the bound can't move a row across the holdout, because the cutoff is the derived revision's own fetchedAt.
- **Covered zero made unusable.** None of the three fixes can do it:
  - polls are never retracted, and every poll key has a single revision;
  - `recording` names two sources;
  - a covered-zero row lists `recording` once.
- **Upstream key resolving outside its dependency.** Still checked at `Resolve.lean:101`. Every source a dependency names is in `required` through `Decl.depends`.
- **Later correction rewriting an earlier derived observation.** Excluded by the `fetchedAt ≤ by_` cutoff. A retraction recorded after the derived row is excluded the same way as a correction. Each upstream entry's knownAt depends only on its own prefix, since `step` is a left fold and its upstream cutoffs are its own fetchedAt.

**F-1 (non-blocking; leakage test 13, but only through a decoder that doesn't conform; no per-row lineage exists yet).**
- `Trusted.canonical` assumes lineage names are unique (`Resolve.lean:200`). RULES.md says only "A lineage names each dependency once" (`RULES.md:205-206`). Neither says what an implementation does when the stored bytes violate it.
- The parallel case for cells has a stated code, `{"t":1,"t":2}` → `R_ROW` (`RULES.md:239`). Lineage has none.
- Scenario: slice 5 decodes stored lineage first-match-wins. The late key is never consulted, and no Lean law can see that, because L8_known speaks of `find?` and doesn't assume `Trusted`.
- Before slice 5, the spec should name the response (dataset invalid, as for a duplicate column), and B3 needs a hand case for it.
- An alternative with no trusted obligation: look up `r.upstream.filter (·.1 == dep.name) |>.flatMap (·.2)`. That changes L8_known's text, though, and the Nodup route is what was ruled. I note it, but don't require it.

**F-2 (non-blocking; leakage only through an encoder that is not a function).**
- The `canonical` clause gives one direction only: same entity → same columns.
- It does not give the other: same columns → same entity. So it does not say `entity` is a function of the tuple. It is also vacuous if a decoder leaves entity columns out of `cells`, because `cellAt` then returns null on both sides.
- Scenario (evidence, where there is no coin, so the certification alias check doesn't apply): a later revision of a record stored under a second encoding of the same tuple becomes a new key. Its first entry is delivered at its rule value, not at or after its fetchedAt.
- Not reachable on the migrated data: evidence rules are `max(·, fetchedAt)` (annex `:16-17`), and every evidence key has one revision.
- "An injective encoding the certificate pins" (SOURCES.md:61) implies a function, so the gap is in how the Lean states it, not in the intent. B3 should include a case where the same tuple is stored under two encodings. Stating the clause as `r.entity = enc (entityColumns.map (cellAt r.cells))` would close it.

## 3. Is L8_known strong enough? Is anything weakened?

**Not weakened.**
- Universal clause: dropping the `u.retraction = false →` premise lets the bound quantify over more upstream entries, so it is strictly stronger.
- Existential clause: dropping `u.retraction = false ∧` changes nothing in content. Any upstream entry recorded by F implies the upstream head is also recorded by F (timeline order, `timeline_ordered`), and the head is never a retraction. At fuel 0 both forms are false.
- Against the frozen statement it remains stronger, as the earlier round found.

**Not vacuous.** GPT's polls-only witness still applies: one usable poll and a derived row listing it produce a real delivery that satisfies every conjunct.

**Other laws:**
- `Registry.valid` gains a conjunct. That narrows the domain of every law that assumes `reg.Valid` (the L1, L2 and L4 families, L8_known) to exclude exactly the registries `mm` refuses. No reachable run is lost, so no meaning changes. `run`/`admit` don't consult `valid`, and L5_certified doesn't assume it.
- `Trusted.canonical` gains two conjuncts, which formally strengthens L5_certified's hypothesis. Its proof doesn't use `canonical` (`Laws.lean:386-409`), and the conjuncts are satisfiable: tombstones keep their key columns (`ingest/store.py:94-96`). So its meaning is unchanged.
- The retraction change alters what `resolveAll` computes, so "RULES.md §6's resolution" in L5_certified now refers to the fixed resolver, as intended. L5_shape, L7_reads and the L1 family take observations abstractly and are unaffected.
- L8_monotone is unchanged.

## 4. Do the specs agree with the Lean?

The specs agree, apart from the items below.

**F-3 (stale; changes a refusal code only, no leakage or false-discovery outcome).**
- SOURCES.md's Preflight bullet (`SOURCES.md:165-167`) still lists "or does not cover the run's access" as a preflight `R_UNCERTIFIED`, "before any observation is loaded."
- The revised Access-authorization bullet (`:172-174`) and Lean (`Sim.lean:496-499`, `inScope` at position 7, after resolution) check scope after resolution.
- Its order sentence ("checking errors, then missing bindings, then certificates") also leaves out roles and the holdout identity that `stage1` checks between them.
- Scenario: a run with both an invalid dataset and an out-of-scope access gets `R_BINDING` at 6 in Lean, but `R_UNCERTIFIED` by the Preflight text.
- Fix: delete the scope clause and the duplicated order from Preflight, since the Access-authorization bullet now covers both.

**Cosmetic (no outcome):**
- `laws-v2-draft.md:207-208`: the five new rows follow the **Frozen** paragraph with no blank line, so Markdown renders them as part of that paragraph.
- `Resolve.lean:78-79`: the `Entry` docstring still lists only "a tombstone, or a revision whose rule evaluation is rejected." It omits `ok` rejection and unusable lineage, which the `timeline` docstring and SOURCES.md:113 include.
- `RULES.md:204` overruns the line width, and its section heading still says "draft". The heading change belongs to the freeze commit.

**The no-move claim (`b2-revision.md` §6) is sound given its counts.**
- 158,410 live sightings + 3,306 + 315 backfill = 162,031 sighting keys, exactly. So every record is its own key.
- A retraction needs an earlier delivery of the same key (`Resolve.lean:127,130`, the `some p` branch). No key has two revisions and no tombstone exists, so no evidence timeline contains a retraction, and `upKnown` returns the same value before and after the fix.
- Venue sources declare no dependencies.
- The derived sources' own retractions are untouched by this fix.
- I did not recompute the counts.

**Non-blocking (refusal, a C7.4 risk, not leakage):** annex `:26-27` reduces only *exact* duplicates.
- `validAt` collides on (entity, event, fetchedAt), so two records of one (key, id, created) at one observation time that differ only in an undeclared column (`updated_at`, `version`) still invalidate the dataset.
- The counts show none in the data in hand. The fixture at `:102` should include that variant, or the reduction should be defined on the key.

## 5. Are the recorded limitations blocking?

None blocks.

- **N-1 (`differs` ignores lineage): missingness only.**
  - When R2 adds nothing, its value equals R1's, so no information is earlier than it should be. A later differing R3 is delivered at or after its fetchedAt (`later = last.isSome`).
  - It cannot trigger in the migration: the migrated data has one derived revision per key, from a single cut.
- **Lineage completeness: the main remaining leakage guard for derived sources.** No Lean statement over stored rows can express it.
  - C7.3's "recomputes every machine-checkable result" (`criteria.md:855`) covers it in principle.
  - The named verifier test lives only in `b2-revision.md` §7. It should go into C7.3's applicability policy when that is drafted, together with F-1's and F-2's cases.
- **Recorder-set event column: the same reasoning.** It is a certification fact (CERTIFICATES.md:73-74), and it needs a named C7.3 test.

## Verdict

**FREEZE.** No finding is blocking. Carry these forward:
- F-1's decoder response and test, and F-2's both-directions encoding case, into B3 and slice 5.
- The two limitations' tests into C7.3's policy.
- F-3's two clauses and the cosmetic lines can go into the freeze commit.
