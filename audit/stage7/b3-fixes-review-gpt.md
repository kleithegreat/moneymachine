# Review: not ready to freeze

**The new hand cases close the named timeline gaps, and I found no incorrect hand expectation. One full-loader gap remains: comparing revision cells does not establish that the actual observations carry those values.**

This is a static review. I did not execute regeneration, differentials or the reported mutation checks. Nothing was edited.

Below, **`draft/` means `audit/stage7/b3-draft/`**, and **Hn means physical line n of `draft/resolver_hand.jsonl`**.

## 1. Blocking finding: actual delivered values remain unobserved

**Outcome affected:** historical strategy inputs can acquire a later correction’s values even though every diagnostic timeline comparison passes.

The new format compares `CELLS`, explicitly defined as **the entry’s revision’s declared columns**, and `ROLE` as those columns’ cells (`draft/rules-revision.md:94–104`). The expectation helper implements exactly that: it retrieves the stored revision and copies its cells (`draft/resolver_suite.py:68–79`).

That catches a resolver returning the final revision’s cells **in its diagnostic timeline**. It does not catch the same error in the actual observation projection:

- Frozen Lean constructs observations separately from timelines.
- `resolveAll` assigns numeric `vals`, role payload, slot and `final` at `reference/lean/Ref/Resolve.lean:167–174`.
- A mutation that leaves timelines and their revision cells correct, but uses the last revision’s values at line 172, remains invisible to this case format.
- Likewise, incorrectly retaining values on retractions or marking every observation final is not represented in the diagnostic output.

Naming the actual Rust loader and Lean’s `resolveAll` is necessary, but insufficient when the specified comparison exposes only the timeline representation (`draft/c76-revision.md:14–18`). The three companion loader tests at `:25–27` do not cover this projection.

**Required before freeze:** explicitly require comparison of the actual loader observations against `resolveAll`, including per-delivery values and role payloads, undefined values on retractions, preserved slots and final-entry flags. Existing fixtures can supply the discriminators: H4 for changed historical values, H122 for role-only correction, and H13 for retraction. This can be a named loader-level requirement; the implementations need not be written before freezing it.

## 2. Rulings and discriminating cases

| First-round bug | Case that now catches it | Assessment |
|---|---|---|
| No raise to the replaced knownAt | **H20**, correction; **H21**, rejected later evaluation (`draft/resolver_suite.py:164–168`) | Discriminating: the second revision’s own rule value/fetchedAt cannot supply the expected time. |
| Derivation bound applied only to first revisions | **H94** (`:354–360`) | Discriminating: the later revision needs the additional 1,000 ms beyond the dependency time already present in its rule. |
| Slot substituted with event time; correction does not move slot; retraction uses its own slot | **H98**, plus rejected-slot **H99** (`:372–383`) | Discriminating, including restoration after retraction. |
| Upstream knownAt clamped to recording time | **H94–H95** (`:354–363`) | Discriminating: upstream recorded at 15H is known at 110H. |
| Declaration order treated as dependency order | **H100–H101** (`:385–396`) | Direct and recursive forward dependencies are covered. |
| One evidence tuple split by its encoding | **H102**, changed control; **H103**, unchanged control (`:399–410`) | Both correction and suppression paths are covered. |
| Final values attached to every delivery | **H4/H94**, for returned timeline cells; **H122**, for returned role cells (`:126–127,354–360,438`) | Diagnostic variant caught. **Actual observation-projection variant still passes**, as finding 1 explains. |
| Undecodable role payload accepted | **H112–H121**, bars; **H126–H130**, settlement (`:434–445`) | First rejection, later retraction, boolean/string/null numbers and non-integer trades are covered. |

The other substantive rulings are also represented:

- Whole-lineage validation, including unread members and undeclared sources: `draft/rules-revision.md:15–29`; cases at `draft/resolver_suite.py:291–299`.
- Mixed numeric tags, non-integer events, nested cells and reserved names: `:196–206,413–430`.
- Old case 44 is corrected by declaring `bars`; it is now **H64** (`:260–264`).
- Key ordering is canonical (`:62–65,80`; protocol at `draft/rules-revision.md:98–100`).
- The planned replacement preserves spec-only GPT implementation, independent text decoding, retirement of obsolete paths and deep comparison (`draft/README.md:16–25`).

The swap requirements are **plans**, not completed changes. That is appropriate at this draft stage; they must actually accompany the specified freeze/implementation commits.

### Change beyond these rulings

The diff also changes `audit/stage7/rust-port-plan.md`, adding two-run checks under a separately cited human decision (`b3-fixes.diff:1108–1121`). This is not an implementation of the supplied B3 rulings and should not enter the suite-only freeze commit.

Moreover, its unconditional late-record non-interference statement needs separate qualification: frozen rules expressly allow final venue-state revisions to change historical accounting and subsequent order sizes, and later records can cause global admission refusal (`kernel/RULES.md:185–190`).

**Outcome affected:** an overbroad check could reject a conforming implementation or pressure an implementation to depart from frozen semantics. Keep that separately authorized work outside this freeze.

## 3. Expected results and hand recomputation

I found **no wrong hand timeline, visibility, slot or raw-cell expectation** in the revised definitions. Stored-decoding `"INVALID"` expectations now have proposed normative authority; they are not outputs computed by `timeline` itself.

Some useful recomputations, with H = 3,600,000 ms:

| Case | Recomputed result |
|---|---|
| **H20** | First REP value is `max(36,120,000,46,800,000) = 46,800,000`. Second candidate is 36,120,000, raised to previous knownAt **46,800,000**. Visibility is `[null,null,200]`. |
| **H21** | The second REP evaluation rejects. Its retraction time is `max(200,46,800,000) = 46,800,000`. At that tie the retraction wins; visibility is `[null,null]`. |
| **H94** | Initial derived delivery is known at **36,002,000**. `up` is recorded at 54,000,000 but known at **396,000,000**. The correction recorded at 72,000,000 is therefore known at **396,001,000**, not 72,000,000 or 396,000,000. |
| **H98** | Derived known times are **36,007,000; 72,000,000; 108,000,000; 144,000,000**. Slots are **39,600,000; 43,200,000; 43,200,000; 46,800,000**. The tombstone’s stored 54,000,000 slot is not used. |
| **H102** | Escaped `"h"` remains the same evidence entity. Its changed `created` column produces a correction at **72,000,000**. Recomputed count recorded at 72,000,001 is bounded to **72,001,000**. |
| **H120** | `trades: 5.0` is not `.int`; the later bar is unusable and retracts at **180,000,000**, with no role payload. |

These follow the frozen fold and projections at `reference/lean/Ref/Resolve.lean:100–130,134–174`.

The automatic addition of expected cells is not an independent numerical oracle. It is, however, a straightforward selection of each expected entry’s own revision, rather than of the final revision (`draft/resolver_suite.py:74–79`).

## 4. Independent implementability and frozen-Lean consistency

**The diagnostic resolver protocol is now substantially implementable from the three prose documents alone.** The previous gaps concerning lineage shape, unread members, numeric tags, slots, role decoding, ordering and retractions have been settled.

I found no contradiction between the restated **timeline algorithm** and frozen Lean:

- “later” depends on an earlier eligible revision, not an earlier successful delivery;
- identical revisions compare against the last stored revision;
- upstream entries include retractions and are filtered by recording time;
- every dependency must be usable;
- retractions retain the preceding slot.

Compare `draft/rules-revision.md:46–64` with `reference/lean/Ref/Resolve.lean:96–131,169–173`.

Two boundaries require care:

1. **Actual observation projection is not specified by the new output protocol.** That is the blocking gap above—not an arithmetic disagreement with Lean.

2. **Using frozen `Ref/Json.lean` does not automatically implement the new integer contract.** That parser converts integer tokens outside its signed/unsigned 64-bit limits into floats (`reference/lean/Ref/Json.lean:134–140`). The new stored-cell contract distinguishes integers by spelling, and accepts any integer slot/trades cell (`kernel/RULES.md:24–29`; `draft/rules-revision.md:31–44`). A decoder must preserve those distinctions rather than blindly translate the parser’s resulting tag.

The second point does not invalidate a present hand expectation; the current corpus does not exercise that boundary. It can affect slot/role usability and correction detection on larger integers. It must not be “fixed” by narrowing the prose or changing frozen Lean silently.

The binary64 rule is now an explicit stored-cell revision of §1’s earlier no-rounding wording, rather than a change to integer rule arithmetic (`draft/rules-revision.md:15,31–34`; `kernel/RULES.md:24–29,38–40`).

## 5. C7.6 revision

Apart from the observation-projection gap, the proposed revision preserves the important obligations:

- **Size:** at least 1,000 resolving key/query comparisons, with an additional 200-comparison multi-revision floor.
- **Exactness:** explicitly retained.
- **Independence:** GPT receives the prose contract, never the suite.
- **Actual Rust loader:** explicitly retained; Lean is additional.
- **History:** original criterion lines remain; the incompatible selection clause is quoted and replaced; results are not described as passing the original bullet.

See `draft/c76-revision.md:3–29` against `audit/criteria.md:922–929`. Counting key/query pairs is consistent with the former format’s one-key cases (`kernel/tests/rules/resolver_suite.py:3–7`).

The named holdout, non-delivery and inconsistent-coin tests are appropriate **but not sufficient for full-loader conformance** without finding 1’s projection check. Holdout testing should observe the staging boundary, not merely the eventual refusal: event-time inventory precedes resolution and covers every stored revision (`reference/lean/Ref/Source.lean:226–230,282–284`).

The post-revision evidence rule is correct. **No qualifying post-revision run is supplied here.** The README’s transcription and mutation results are explicitly author self-checks, not the future judged comparison (`draft/README.md:31–42`). They must not be grandfathered in.

Replace `2026-11-0X` with the actual date when appending the revision. Once frozen, the size floors, exactness, independence and loader requirements cannot be loosened autonomously; `CLAUDE.md:38,55–57` reserves frozen-threshold loosening to the human.

## 6. Generator coverage and assertions

**The generator’s variation is real**, not merely repeated stores: it varies dependencies, source subsets, lags, declaration order, numeric/role cells, slots, lineage and recursive derivation (`draft/resolver_suite.py:465–542`).

The size counter excludes the invalidities this particular generator produces: malformed cell text and duplicate eligible key/fetchedAt combinations (`:548–574`). It is **not a general validity checker**—it does not validate rules or lineage—but the current generator does not generate those additional invalidity classes. Its restricted use is sound.

There are nevertheless coverage-label defects:

- **“nothing after retraction”** accepts any null visibility whenever the final entry retracts. The null query may precede the retraction—or every delivery (`:647–648`).
- **“retraction keeps slot”** checks only that the slot is non-null and unlike event time, not that it equals the preceding entry’s slot (`:636–637`).
- **“raised to replaced”** checks coincident times, not whether removing the previous-knownAt bound changes the candidate (`:638–640`). This is the same masking distinction the first review exposed.
- Input-class counts include ineligible rows and invalid stores (`:585–618`). They establish input presence, not reached resolver behavior.

**Outcome affected:** coverage-floor assertions can pass without proving the behaviors their labels suggest. These defects do not demonstrate a surviving current timeline bug: the new hand cases directly discriminate those behaviors. They are coverage-evidence limitations, not additional arithmetic blockers.

Also, `generate()` asserts only `CLASSES`; enforcement of `REACHED` is deferred to the future Lean harness (`:652–658`; `draft/README.md:18–20`). The reported ten-store floors and 34 mutation kills are not reproducible from committed checking code here.

One remaining coverage limitation: all ordinary generated fractional values are exactly representable. An exact-decimal implementation could still pass while disagreeing on, for example, `1.0` versus `1.00000000000000001`, which round to the same binary64 value. This can change correction detection, but is not one of the outstanding first-round timeline bugs.

## Verdict

**Do not freeze yet.**

Before freezing, require an observable, exact comparison of the **actual loader’s per-delivery observation projection**, not just revision cells in diagnostic timelines. Keep the unrelated two-run-plan change outside the suite-only commit.

The new hand expectations themselves need no arithmetic correction.
