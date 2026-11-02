# Review: slice 2 is not ready to close

**Blocking findings:** the event declarations have the wrong dependency sets, the checked input representation omits planned provenance, and the required run differential remains unestablished.

This is a static review; I did not execute tests or edit files.

## 1. Event declarations require unrelated evidence sources

**Outcome changed:** a valid forum-only run can become `R_INPUT_UNAVAILABLE` or `R_UNCERTIFIED`; lineage from the wrong feed family becomes admissible.

Both declarations list **all four** evidence sources:

- `sources/forum-events/1.json:14`
- `sources/governance-events/1.json:14`

The annex instead specifies each derived feed’s **own sightings and polls sources** (`audit/stage7/migration-annex.md:16–23`). Thus:

- `forum-events` should depend on `discourse-polls` and `discourse-sightings`;
- `governance-events` should depend on `snapshot-polls` and `snapshot-sightings`.

This is observable under frozen B2, not merely excess documentation:

- Required-set closure follows **every declared dependency source** (`reference/lean/Ref/Source.lean:107–109,267–274`).
- Certificate matching requires the upstream certificate set to match those dependencies (`reference/lean/Ref/Source.lean:255–259`).
- B2 permits lineage keys from any source in the declared list; broadening that list also broadens permitted provenance (`audit/stage7/b2-revision.md:29–32,95–98`).

For example, bind bars, settlement, forum events and both Discourse evidence datasets, with valid matching certificates, but no Snapshot datasets. The annex’s declaration can admit this run. The submitted declaration requires Snapshot bindings and refuses it.

**B2 does not require each lineage to contain a record from every listed source.** The error is the enlarged dependency closure and membership permission, not an obligation to fabricate four-source lineage.

The **four evidence declarations themselves are correct** against the annex and B2: recorder-time event columns, the specified entity tuples, no fields or roles, evidence cadence, and `max(observed/recv, fetchedAt)` (`sources/{discourse,snapshot}-polls/1.json:5–13`; `sources/{discourse,snapshot}-sightings/1.json:5–13`; annex `:16–27`). The event declarations’ other fields, units, cadence and rules also match.

## 2. The input table loses source and field ownership

**Outcome at risk:** the next generic machine/admission implementation can read or require the wrong source, particularly after declaration reordering or renaming.

Frozen Lean’s input contains **source index, field index, cadence flag and unit**. `Registry.inputs` obtains all four from the registry (`reference/lean/Ref/Syntax.lean:71–79`; `reference/lean/Ref/Source.lean:112–116`). Those coordinates drive `Program.sources` and the well-formedness contract (`Source.lean:138–140`; `reference/lean/Ref/Spec.lean:45–61`).

Rust retains only:

```text
name, event, unit
```

(`kernel/mm/src/dsl.rs:68–75`; `kernel/mm/src/source.rs:228–232`).

`Node::Input(k)` indexes that **flattened input table**, not the declaration table. In the committed registry, for example, `forum_posts` is flattened input 0 but belongs to declaration 2. The program retains no declaration or field coordinate.

The current name-based machine adapter conceals this omission; it does not supply the planned representation. The plan explicitly calls for Lean’s provenance-bearing `Input`, while its stated interim exception concerns `Read::of` and the typed slots (`audit/stage7/rust-port-plan.md:15,35`).

**Before closing slice 2, preserve source/field coordinates in the table.** This does not require implementing slice 3 early.

### What the checker does correctly

For name lookup and typing alone, the new path is sound:

- names and units come from declaration fields;
- event status comes from declaration cadence;
- lookup uses the supplied table;
- canonical text and egg input leaves use that table’s name.

See `kernel/mm/src/source.rs:228–232`, `kernel/mm/src/dsl.rs:395–401,548`, and `kernel/mm/src/canon.rs:70`. I found no registry-lookup acceptance/refusal counterexample in these changes.

## 3. The reported checks do not establish the changed contract

**Outcome affected:** regressions in generic input ownership, units or registry selection can survive the reported green checks.

The tests now obtain inputs from the committed registry (`kernel/mm/tests/common/mod.rs:6–8`), but that registry exposes the same **nine legacy input names**. Lean’s executable has four source declarations exposing those same nine inputs—not “four inputs” (`reference/lean/Main.lean:39–48`).

Consequently, agreement on 1,196 old verdicts is useful regression evidence, but does not demonstrate:

- acceptance of a previously unknown declared input;
- rejection of its former name after renaming;
- typing from an altered declaration unit;
- correct source/field ownership after reordering.

The source test checks registry validity and selected legacy properties, not those behaviors (`kernel/mm/tests/sources.rs:10–19`). Admission tests explicitly filter out the new declarations and substitute their own dependency fixture (`kernel/mm/tests/admission.rs:18–23`), so they cannot catch finding 1.

Add focused alternate-registry tests with renamed fields, unfamiliar unit combinations and ownership assertions. The CLI and daemon tests likewise exercise repository defaults, not alternate registry selection (`kernel/tests/cli/test_cli.py:38–42`; `gate/tests/test_agent_daemon.py:25–30`).

### An existing mismatch verdict-only testing misses

This is **pre-existing**, not introduced by slice 2, but qualifies claims of complete frozen-Lean agreement:

```json
{"dsl":1,"name":"z","mechanism":{"counterparty":"","predictions":[],"capacity":""},
 "params":{"z":{"value":-0,"unit":"1"}},"weight":{"param":"z"}}
```

Rust’s serde path preserves the token `-0` as floating negative zero, and parameter parsing retains it (`kernel/mm/src/dsl.rs:221,251–252,336–340`). Lean parses that integer-spelled token as `.int 0`, subsequently producing positive zero (`reference/lean/Ref/Json.lean:134–137`; `Ref/Syntax.lean:170–172,298–302`).

**Outcome:** both verdicts are `ok`, but parameter/node value bits differ. The missing run comparison matters. Resolve this explicitly when claiming full front-end conformance; do not silently alter frozen definitions.

## 4. What “market N1 does not rebuild as frozen” actually means

**Outcome affected:** no current run-equivalence result is established. The message itself is not evidence of a Rust/Lean semantic disagreement.

The precise sequence is:

1. Read and verify the frozen corpus.
2. Build binaries.
3. Reconstruct all markets.
4. Compare each reconstructed market’s hash with its manifest hash.
5. Only then compare verdicts and execute differential chunks.

The exception is the comparison at `reference/differential.py:199–201`. The verdict loop starts at `:202`; execution starts at `:216`.

Therefore, **the failing `differential.run` invocation produced neither the claimed 1,196 verdict comparisons nor any run comparisons**. The verdict count must come from a separate check-only invocation and should be identified as such.

### What is being compared?

`market_hash` hashes every file’s **relative pathname and complete bytes**, including Parquet files, policy, venue files and the version file (`reference/differential.py:55–62`; `gate/markets.py:192–227`). It does not compare decoded observations or returns.

Thus unchanged slice-local market code does not guarantee the hash:

- an earlier generator/store/policy change can alter emitted artifacts;
- a changed dependency/toolchain can alter Parquet bytes without changing decoded values;
- a rebase gap can matter **if it changes those actual reconstruction inputs**.

Conversely, relocation alone does not explain it: absolute directory names and file timestamps are not hashed.

### Is missing data the explanation?

**Not for N1’s generated values.** N1 uses zero funding, fixed volatility, seeded synthetic prices and seeded synthetic events (`gate/markets.py:103–106,132–143,187`; `reference/differential.py:47–52`). It does not bootstrap the real funding store.

N2/N3 do read that store (`gate/markets.py:59–66,78–89,138`; `gate/nulls.json:69–90,130–151`). Moreover, `markets_of` eagerly constructs them before returning to the hash loop (`reference/differential.py:87–90`). Missing required funding data would ordinarily fail reconstruction earlier, rather than explain a completed N1 reconstruction’s unequal hash.

**Assessment:** the integrity check is correctly failing closed. The exact offending artifact is not established by the supplied evidence. “Expected because rebase/data” is not an adequate diagnosis. Restore/reproduce the frozen reconstruction inputs and identify the differing files; do not regenerate the frozen manifest to make this pass. Until then, the plan’s run-preservation check is outstanding (`audit/stage7/rust-port-plan.md:28–38`).

## 5. Registry defaults, run binding and remaining concrete names

These are important limitations, but distinguish them from additional slice-2 blockers:

- **The build fixes a pathname, not registry contents.** The default is `CARGO_MANIFEST_DIR/../../sources`, read at runtime (`kernel/mm/src/main.rs:79–85`). A copied binary without that checkout needs `--sources`; modifying that directory changes what the same binary checks. `mmdump` has the same compiled-path dependency and no registry argument (`reference/mmdump/src/main.rs:181`).
- **Yes, evaluation can use an independently selected registry.** `eval` reads `--sources`, while `load_ctx` independently loads the legacy store/venue; no admitted registry snapshot connects them yet (`main.rs:267–286,479–504`). Registry identity is also absent from the existing experiment-identity construction (`:353–357`). This contradicts the *completed* snapshot contract in `kernel/SOURCES.md:179–182`, but CLI admission wiring is explicitly deferred to slice 6 (`rust-port-plan.md:47–57`).
- Holdout additionally rereads the registry for family checking rather than sharing the already-loaded table (`main.rs:439–442,479–486`). That must disappear with immutable admission.
- `Read::of`, `EVENT_INPUTS`, event-dataset lookup and concrete loader/dataset branches remain identifier-selected behavior (`machine.rs:120–130`; `dsl.rs:64–66,579–585`; `main.rs:109–114`). They violate eventual C7.1, but are covered by the planned machine/loader/admission replacements. I found no additional production-name dispatch newly hidden beyond those deferrals.
- The planned JSON-reader consolidation is also unfinished: the checker still uses serde (`dsl.rs:221`). It should not be described as already ported (`rust-port-plan.md:14`).

## 6. Sixteen rewrites versus seventeen Lean schemas

**The omission is not, by itself, a demonstrated equivalence-key defect.**

Lean’s `ifNotRev` constructs:

```text
if(c, b, a) → if(not(c), a, b)
```

(`reference/lean/Ref/Spec.lean:169–174`). Rust’s existing `if-not` reduces the right-hand term back to the left (`kernel/mm/src/canon.rs:105`). Thus the inverse pair has a common forward representative; an explicit expansion is not necessary merely to give that pair the same key.

However, **symmetric e-class equality does not automatically generate missing reverse terms**. Starting with only `if(c,b,a)`, the directed egg rule does not synthesize `not(c)`. The builder’s explanation is therefore too broad: distinguish equality symmetry from rewrite search direction.

There is already relevant coverage: the random rewrite generator explicitly performs the reverse expansion (`kernel/mm/tests/rules.rs:318`), and hand-built tests compare swapped conditional forms (`kernel/mm/tests/canon.rs:28–30,92`). The random test allows up to ten unmatched keys, so its passing result is not a universal completeness proof (`rules.rs:338–359`). I found no concrete additional failure attributable to omitting this expansion.

## Verdict

**Do not close slice 2 or treat its preservation checks as passed yet.** Before proceeding on that basis:

1. Correct the two event dependency sets and their registered identities.
2. Preserve source/field ownership in checked inputs and test an alternate registry.
3. Diagnose the frozen-market reconstruction mismatch and complete the promised run differential.

The explicitly deferred machine/admission behavior and the `ifNotRev` rule count are **not additional blocking findings**.
