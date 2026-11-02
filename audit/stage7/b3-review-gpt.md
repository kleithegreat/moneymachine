# Review: do not freeze yet

**The hand-computed timeline expectations are sound. The blockers are specification gaps and missing tests for parts of the claimed full resolver—not incorrect arithmetic.**

This is a static review; I did not run the implementations, verify Git identity or frozen hashes, or edit anything. References below use **Hn** for physical line *n* of `audit/stage7/b3-draft/resolver_hand.jsonl`.

## 1. Expected results

I found **no incorrect timeline expectation among the 60 hand cases as expressed in `audit/stage7/b3-draft/resolver_suite.py`**. However, several `"INVALID"` expectations are proposed semantics, not results presently determined by RULES.md or the frozen Lean.

The applicable frozen baseline is B2’s last entry in `audit/stage7/laws-frozen.md:199–210`. Its strict lineage and retraction-inclusive bounds are implemented in `reference/lean/Ref/Resolve.lean:100–117`.

### Hand recomputation of the difficult cases

Here `E = 36,000,000`, `P = 36,005,000`, and the processing lag is `1,000` ms (`audit/stage7/b3-draft/resolver_suite.py:65–66,100–114`).

| Case | Recomputed result |
|---|---|
| **Covered zero, polls-only lineage: H38** | Poll fetched at `36,006,000` is known at `max(P, fetchedAt) = 36,006,000`. The first count revision is therefore known at **T = 36,007,000**, despite being fetched at `36,008,000`. It is absent at T−1 and visible at T. **Correct.** A first revision need not be bounded by its own fetchedAt; this is explicitly allowed by `kernel/RULES.md:181–189`. |
| **Source outside its dependency: H39** | `bars` is not among `recording`’s sources. The good poll cannot rescue that key. The count’s first revision is unusable and produces no entry. **Correct** (`kernel/RULES.md:200–206`; `reference/lean/Ref/Resolve.lean:100–113`). |
| **No delivery recorded by the derived revision: H40–H41** | The upstream revision fetched at `36,009,000` is excluded by the derived revision’s `36,008,000` recording cutoff. H41 remains unusable beside a good poll: no masking. **Correct.** A late query does not repair missing historical lineage. |
| **Later correction does not move an earlier derived row: H45** | The earlier derived revision sees upstream knownAt `36,001,000`, hence its own knownAt is **`36,002,000`**. The later upstream correction at `72,000,000` cannot move that entry. The recomputation at `75,600,000` is known at `max(72,001,000, 75,600,000, previous knownAt) = 75,600,000`. **Correct**, although that recomputation’s fetchedAt masks the upstream bound in this fixture. |
| **Retraction bounds a derived revision: H46** | The upstream retraction is recorded at `54,000,000`. It participates in the dependency maximum, so the first derived revision is known at **`54,001,000`**, not `36,002,000` and not necessarily its own fetchedAt `57,600,000`. **Correct** (`kernel/RULES.md:202–205`). |
| **Repeated dependency name: H49** | `"INVALID"` is the right proposed response, but **not yet a specified response**. Lean assumes uniqueness through `Trusted.canonical`; it does not decode or reject these bytes itself (`reference/lean/Ref/Resolve.lean:195–201`). Without that assumption, `find?` would simply select the first member. |
| **One tuple under two encodings: H36, H47** | Decoding `"\\u0042TC"` gives `"BTC"`; member order changes nothing. H36 therefore remains one key with one delivery. H47’s escaped lineage host names the existing sighting. **Correct.** H37 also correctly separates concatenation collisions and integer/string IDs. |

The other subtle expectations also agree with the fold:

- H20’s first successful revision remains bounded by fetchedAt after an earlier rejection.
- H54–H55 suppress repeated tombstones/rejections.
- H56 correctly preserves the recorded N-1 limitation: changing only lineage cannot revive identical cells.
- H57 applies each dependency’s own lag before taking the maximum.

These follow `reference/lean/Ref/Resolve.lean:118–131`; N-1 is expressly retained in `audit/stage7/b2-revision.md:124–128`.

**Unsupported rather than numerically wrong:** H30–H32 and H49–H50 require the proposed stored-decoding rule. H33 additionally fixes its eligibility scope: malformed bytes after V do not invalidate that version. The draft acknowledges this in `audit/stage7/b3-draft/resolver_suite.py:32–35`.

## 2. Blocking specification findings

### B1. Stored-decoding failure needs a normative response

**Outcome affected:** whole-dataset refusal versus silently dropping a revision, retaining an older value, or delivering a retraction. Duplicate lineage can otherwise hide late evidence.

RULES.md §5 gives `R_ROW` for malformed **rule-evaluation inputs** (`kernel/RULES.md:85–87`), but that does not establish what happens when the stored resolver input cannot become a canonical revision. The old suite’s `R_ROW` convention is not authority for the revised resolver (`kernel/tests/rules/resolver_suite.py:13–20`).

**“Dataset invalid” is right.** A malformed key may not even identify what to retract; silently skipping malformed history is unsafe. This is the obligation carried into B3 by `audit/stage7/b2-revision.md:140–141` and `audit/stage7/b2-fixes-review-claude.md:80–85`.

RULES.md §6 should gain a dated sentence substantially as follows:

> At dataset version V, any eligible stored revision whose column object or lineage object is malformed under §1, repeats a decoded member name, contains a reserved metadata/revision/tombstone column, lacks an in-range integer key event time, or contains a lineage key other than `[source-name string, entity-cell array, in-range integer event time]` makes the dataset invalid and resolution returns no observations; revisions fetched after V do not participate in this validation, while a canonically decoded revision with a rejected rule evaluation, unusable lineage, or undecodable slot or role payload follows the retraction rules above.

Define admissible entity cells alongside the wire shape. **Do not classify a well-shaped key’s wrong source membership or missing delivery as malformed:** those make the derived revision unusable, as H39–H41 require.

Add direct malformed-`upstream` and invalid-event tests. Existing malformed-cell tests do not exercise a separate lineage decoder.

### B2. C7.6 needs an append-only dated revision before judging

**Outcome affected:** whether an implementation passes the frozen criterion at all.

The contradiction is explicit:

- `audit/criteria.md:926–929` requires latest-revision selection **before** availability.
- `kernel/RULES.md:151–163` requires bitemporal visibility.
- H4 requires the earlier value to remain visible until the correction becomes known.
- The old suite requires the opposite (`kernel/tests/rules/resolver_suite.py:57–58`).

RULES.md’s instruction to revise the suites (`kernel/RULES.md:165–166`) does **not** amend the frozen criterion. `CLAUDE.md:55–57` requires a dated revision and evidence produced afterward.

That revision must preserve the original exactness and independence requirements while stating:

1. Resolution follows the reviewed bitemporal revisions and B2: per-key timelines, causal recording cutoffs, strict lineage, retractions, and no fallback **through a retraction**.
2. The frozen suite still includes at least **1,000 query comparisons over multi-revision fixtures**, cutoffs and corrected rules.
3. The counting unit is explicit. A store-level query now contains several key/query comparisons; this cannot silently become a weaker size requirement dominated by trivial keys or invalid stores.
4. Python and the **actual Rust loader** still participate, alongside GPT’s spec-only implementation; Lean is an **additional** comparator.
5. The revised specification and suite are reviewed and frozen before their implementations are judged.

Do not edit the original criterion or call an old development comparison a pass of the revision.

### B3. The independent implementer needs a complete prose/protocol contract

**Outcome affected:** legitimate independent implementations disagreeing—or agreement obtained by learning Lean instead of implementing the specification.

Two substantive gaps remain:

- **Numeric cells.** The draft specifies IEEE doubles (`audit/stage7/b3-draft/resolver_suite.py:22–25`), whereas RULES.md says no value is rounded or converted to floating point (`kernel/RULES.md:24–29`). Frozen Lean distinguishes `.int 1` from `.num 1.0`; only two `.num` zeros receive special equality (`reference/lean/Ref/Resolve.lean:66–69`). Resolve this explicitly for stored numeric cells, including equality across numeric tags, and add the omitted mixed case. The current examples happen not to distinguish exact-decimal and binary64 interpretations.
- **Undeclared lineage members.** H44 accepts an extra member referring to an undeclared source because it is ignored. The draft states this policy (`audit/stage7/b3-draft/resolver_suite.py:30–31,236–239`), but RULES.md does not clearly specify it for stored lineage. State that such members are structurally validated but not resolved—or adopt another reviewed policy and change the fixture accordingly.

Also extract a **standalone wire-format specification** for the independent implementer. The README says GPT must not see this suite, but its protocol currently lives inside the suite and refers normatively to “Lean’s timeline” (`audit/stage7/b3-draft/README.md:56–59`; `resolver_suite.py:39–48`).

Source/key listing order is a protocol detail, **not a leakage or statistical outcome**. Specify it separately or normalize it in the comparator; it should not require reading `Stored.keys`.

## 3. What wrong implementations could still pass?

The suite catches the principal B2 regressions: globally dropping covered zero, ignoring source membership, masking a missing delivery with a good key, excluding upstream retractions, and allowing later upstream corrections to alter an earlier derived timeline. H38–H46 are useful discriminators.

It nevertheless leaves concrete surviving bugs.

| Surviving bug | Outcome it could change; why it passes |
|---|---|
| **Clamp an upstream delivery’s knownAt to the derived revision’s fetchedAt.** | **Leakage:** a recorded upstream delivery whose rule time is still in the future could make a derived value early. None of the hand lineage cases requires an upstream knownAt later than the derived recording time. Generated evidence events are near 10 h, while derived recordings start at 15 h; their evidence rules are only `max(event, fetchedAt)` (`resolver_suite.py:63–64,342–360`). Add an upstream delivery recorded before the derived row but known afterward. |
| **Resolve sources in declaration order, without handling forward dependencies.** | **Lost covered zero:** reorder declarations so `events` precedes `poll`, and the poll may appear missing. All current hand and generated declarations place dependencies before dependants (`resolver_suite.py:115,295–310,365–367`). Acyclicity does not require declaration order to be topological (`reference/lean/Ref/Source.lean:118–128`). |
| **Canonicalize coin entities, but use raw spellings when encoding stored evidence entities.** | **Split correction/history leakage:** the same evidence tuple under `"h"` and `"\\u0068"` can become two first revisions. H36 tests repeated **coin** rows; H47 tests an escaped **lineage reference**, not two stored evidence encodings. Add two evidence revisions of the same decoded tuple, with a changed declared control and a late correction. This directly closes the evidence-path F-2 scenario (`audit/stage7/b2-fixes-review-claude.md:87–92`). |
| **Ignore role-payload decoding.** | **Missing retraction or changed execution data:** a later malformed settlement rate or bar payload may remain usable. The fixture format has no roles at all (`audit/stage7/b3-draft/README.md:47–49`), although decoding affects timeline construction (`reference/lean/Ref/Resolve.lean:133–154`). |
| **Return correct revision IDs/times but attach the final revision’s values to every delivery.** | **Correction rewriting history**, including changing a historical zero into a later positive count. The output compares no values or role payloads (`resolver_suite.py:42–48`), while `resolveAll` constructs those fields separately (`reference/lean/Ref/Resolve.lean:167–173`). Timeline agreement alone cannot establish full-loader agreement. |
| **Materialize evidence or outside-U keys as strategy observations.** | **Exposure of data that should never be delivered.** Their diagnostic timelines are compared, but their exclusion from actual observations is not. The README acknowledges the distinction (`README.md:15–16`); Lean filters them through `Stored.keys` (`Resolve.lean:50–53,163–166`). |
| **Check holdout only after resolving, or inspect only surviving/in-U revisions.** | **Holdout crossing:** a tombstoned, unusable, outside-U or future-cutoff evidence row could escape the check. This format contains no holdout metadata or staged-read instrumentation. The required check examines every stored event time before resolution (`reference/lean/Ref/Source.lean:226–230,282–284`; `kernel/SOURCES.md:169–178`). |

The last three require **actual-loader/admission tests**, not pretending a timeline diagnostic can observe them. Likewise, omitted lineage and a feed timestamp impersonating recorder time remain certification obligations, not resolver deductions (`audit/stage7/b2-revision.md:129–133`).

### Generator coverage: useful variation, narrow structure

It does more than repeat identical examples: it varies revisions, cutoffs, missing keys, source membership, tombstones, slots and lineages. But it repeatedly uses **one four-source graph**, fixed evidence rules and one event dependency. Multiple dependencies and recursive derivation appear only in isolated hand fixtures (`resolver_suite.py:294–320,324–367`).

The generation counter measures eligible keys multiplied by queries; it does not establish that particular behaviors were reached (`resolver_suite.py:371–373`). The author’s self-check reports empty, single-delivery and retracting derived timelines, but not counts for the critical distinctions (`README.md:63–66`).

Before freezing, add the distinguishing cases above and structural coverage assertions. More random stores of the existing shape are not a substitute.

## 4. Decisions on the README’s open points

### Cases that block

- **Role decoding:** blocks the claim of a *full* resolver suite. Add valid/invalid first payloads, invalid later payloads retracting an earlier delivery, and a role-only column correction.
- **Integer versus double equality:** settle the specification and add the test before asking the independent implementer to match exactly.
- **Invalid event decoding:** add the named refusal rule and representative cases; the current format simply excludes the problem.
- **F-2’s stored evidence path and the future-known upstream case:** add before freeze for the concrete reasons above.

These omissions are identified at `README.md:47–55`; the additional discriminators follow the surviving bugs in §3.

### Cases that may live elsewhere

- **Empty dependency-source lists and cycles:** reasonable to leave to registry/admission tests; these are checked by `Registry.valid` (`Source.lean:121–128`).
- **An entity mapping to inconsistent coins:** impossible under this fixture’s fixed lookup, so it need not be forced into the reduced timeline format. But C7.3 mapping certification is not itself a test of the loader’s `Stored.validAt` obligation (`Resolve.lean:55–61`). Require a named loader-level test.
- **Holdout staging, payload projection and evidence non-delivery:** companion integration tests are mandatory before claiming full-loader conformance, though not necessarily fields in every timeline fixture.

### Planned swap

The direction is correct: replace the old three resolver-suite files, obtain a fresh independent resolver, and retire snapshot resolver paths rather than preserve a compatibility mode (`README.md:56–59`; `audit/stage7/rust-port-plan.md:19,44–46,75–78`).

Keep the sequence explicit:

1. Freeze the corrected specification/protocol and suite alone.
2. Implement replacements and wire them to the real loaders.
3. Remove obsolete resolver implementations and compare Python, Rust, independent GPT and Lean on the frozen artifacts.

Do **not** make old implementations pass by translating the new fixtures into snapshot cases or skipping assertions. Their current incompatibility is expected at this stage, not grounds for implementing before the suite freeze.

Two harness requirements accompany the swap:

- Preserve generated-file regeneration checks and count **meaningful key/query comparisons**, with an explicit invalid-store convention (`kernel/tests/rules/test_suite.py:30–34`).
- Replace shallow `same`: it checks only the outer type, so nested `true` and `1` compare equal in Python (`kernel/tests/rules/test_three_implementations.py:22–38`). That is an **exact-conformance defect**; a representation-only mismatch need not change a financial outcome.

## Verdict

**DO NOT FREEZE YET.**

Fix first:

1. Specify stored-decoding failures and complete the independent wire/prose contract.
2. Append the bitemporal/B2 revision to C7.6 without reducing its independence, exactness, size or actual-loader requirements.
3. Add role decoding, mixed numeric equality, stored evidence re-encoding, future-known upstream and declaration-order discriminators.
4. Make the swap explicitly retain full-loader and staged-admission checks, rather than treating timeline agreement as their replacement.

No hand expectation needs an arithmetic correction. The proposed invalid-data expectations need specification authority before they can judge implementations.
