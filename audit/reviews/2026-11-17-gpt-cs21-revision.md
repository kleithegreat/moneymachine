# GPT on the drafted dated revision to study 2's criteria (round 4's D190)

Model `openai/gpt-6.1-sol#high` (opencode), read-only, given the committed criteria, the draft and the design it rests on (`~/.cache/mm-gpt/cs21-rev`), without the advisor's view. The prompt is below the reply. The reply, verbatim:

## Findings

### 1. The lag can add a false discovery by avoiding a committed early termination  
**Fatal — do not commit.**

Construct an otherwise admissible forward record:

- Monthly replays start at day 90 and day 120.
- A settlement for a held coin on day 70 is absent at day 90. The collector obtains it on day 95, within the proposed 30-day writing window.
- No rung is reached through day 69. A lucky price path makes `Wᵇ ≥ 20` at day 80, with no earlier crossing.

**Committed reading:** The day-90 replay runs through the record’s latest midnight, encounters the missing settlement, and aborts under A9/A18. CS2.1 ends at day 69: “Not confirmed.”

**Revised reading:** That replay stops at day 59 and never encounters the missing settlement. At day 120 its horizon reaches day 89; the settlement is now present, and day 80 is named “Earned.”

This construction needs neither misconduct nor a writer violating the proposed window. A no-edge strategy can follow the lucky price path; having no edge does not prohibit a chance crossing.

This establishes an added null rejection relative to the committed stopping rule. It does **not**, by itself, establish that the revised procedure exceeds Ville’s 5% bound. But preserving that ceiling is different from satisfying the project’s stricter requirement that a revision never increase false discoveries.

“Fixed before outcomes” does not prove the required monotonicity.

### 2. The first-attempt cut leaves an operator timing lever  
**Fatal — do not commit.**

Let day `D` have exactly one apparent crossing. Its recorded quotes produce `Wᵇ = 20 + ε`; every other day ends below 20.

An honest recorder suspension delays flushing a genuine adverse print stamped just before `D` ends until `D + 40 days`. Including that print puts day `D` below 20. Such delayed flushes are explicitly contemplated in step 7, test 10 and wall 3.

Two otherwise identical monthly launch choices yield:

- First eligible attempt at `D + 35`: the cut excludes the print permanently; “Earned.”
- First eligible attempt at `D + 45`: the cut includes it; “Not confirmed.”

Choose `D` so both launches fall within the same calendar month. “Once a month” fixes neither launch.

The eventual append-only record is identical. Only launch timing differs. Binding killed attempts prevents retrying a cut, but does not remove control over **when the first cut occurs**.

The claim that launch timing changes nothing holds only under the writer-completeness premise that the design expressly allows to fail. Repair requires an independently fixed, enforceable closure mechanism—not merely stronger assurances about writer timestamps.

### 3. Honest records can lose a claim that the committed judging would license  
**Substantive change, not merely publication delay.**

Suppose the first replay after 61 completed judged days starts on day 75:

- The replica has 10 entries.
- The vault’s recorded fills contain 10 entries, all matched.
- Eleven additional, complete vault round trips occurred on day 60 but are indexed and recorded on day 80. They introduce no position-chain gap and match no replica entry.

**Committed:** CS2.3 is judged on day 75: matched count 10, replica count 10, vault count 10. It is met. The committed text expressly acknowledges round trips appearing after judging as outside that judging.

**Revised:** Day 75’s horizon is day 44, so CS2.3 waits. A subsequent replay includes the eleven round trips: matched count 10, vault count 21. Since `20` is not greater than `21`, the verdict becomes “not shown.”

The original licensed statement was true **of the vault’s fills on record at its committed judging**, not necessarily of every actual vault fill. The revision changes that sampled record and can remove the license on an entirely honest history.

Separately, a complete, immutable record whose first 212 daily returns satisfy CS2.2 is temporarily blinded whenever the first committed eligible replay has a revised horizon below 212. That alone is delay, not permanent loss; the CS2.3 construction demonstrates an actual verdict change.

### 4. “First of a key” changes the judged input, not just its stability  
**Fatal to the assertion that the revision only clarifies timing.**

Take one funding hour whose first stored rate is zero and whose later stored rate is `0.0001`, both present before the first eligible attempt. Set the ledger’s midnight wealth sufficiently close to 20 that the payment decides the crossing.

The revision always selects zero. It can therefore change wealth, variance, subsequent admissions and entries, and the bar.

The committed criteria do not specify a first-version resolution rule. Indeed, A18 rejects a second funding event for the same coin/hour **if both reach the engine**. On that literal input, the committed run ends; the revised reader suppresses the second event and can continue to confirmation.

Conversely, it would be unjustified to assume that the committed reader necessarily selected the latest version: that policy is not stated either.

This underspecification is real, but does not authorize declaring the newly selected policy harmless. Stability proves repeatability, not conservatism.

### 5. Numerical thresholds and judged dates stay fixed; operational meanings do not  
**Fixable wording, but insufficient to cure findings 1–4.**

The draft does not numerically change 20, 730, 212, 61, six minutes, or the matching majority. It does change:

- which events determine a judged day;
- when missing data can terminate the test;
- which vault fills exist at judging;
- the earliest eligible judging replay.

“Horizon reaches day 212” is not equivalent to “the engine has completed day 212.” An attempt with horizon 250 can abort on day 150 or be killed before completing any day. The draft’s explanatory sentence substitutes the former for the committed latter.

Retain an explicit completion requirement, including the successful truncated rerun where applicable. A cut may bind an attempted day without making it a **day run**.

The correction concerning L1 is sound: L1 needs identical event prefixes and compares completed runs. A19 fixes the midnight boundary; neither establishes record completeness or statistical safety.

### 6. Precision and unresolved choices  
**Fixable in text unless they retain the substantive levers above.**

These points need explicit resolution:

- **Normative incorporation:** Are all of wall 3’s rules incorporated, or only its key/order definitions? Pin the incorporated text/version. Wall 3 supplies details absent from the draft: killed attempts, one ledger, whole-line prefixes, ordering and hash-failure handling.
- **Snapshot construction:** How are file enumeration and prefix capture synchronized? What prevents a file created during capture from being inconsistently included? How are concurrent first attempts ordered?
- **Day membership:** Is it determined by event time, settlement hour, `known`, receipt time, or file hour? How are midnight events and items whose corrected timestamp changes their day handled?
- **Cross-day identity:** Is deduplication global or day-local? A restatement moving an event across midnight can otherwise survive under two daily cuts.
- **Historical vault state:** The draft covers “every replay” and “a day”; wall 3 instead reads the historical copy whole. Which historical days receive cuts, and when?
- **Cut integrity and availability:** Specify absent files, partial lines, unavailable prefixes, and whether a broken recording suspends publication or permanently ends the study. Wall 3 does not give a fully mechanical resolution for every such failure.
- **Horizon:** Specify its relationship to actual record reach, the first judged midnight and the 730-day cap. Calendar age alone must not manufacture completed days beyond a stopped record.
- **Clock and launch:** Define the authoritative start instant and synchronization with capture. Monthly frequency does not fix launch time.
- **Writing window:** State whether 30 days is measured from the day’s end. Distinguish the normal writer specification from exceptions; the unconditional assertion that every day is whole is contradicted by the documented exceptions.
- **Late data:** Explicitly state that an item written after 30 days but before the first cut is included, as test 10 requires. Thus “30 days” is not an eligibility deadline.
- **Post-revision evidence:** State which evidence is eligible after commitment and prevent earlier attempts from silently supplying binding cuts.

## Verdict

**Do not commit.** The proposal changes stopping and observation rules and admits both an added null rejection and an operator timing lever. Textual precision alone cannot establish the required no-increase guarantee.

## Prompt

You are an independent reviewer of a proposed dated revision to a frozen, pre-registered criterion. The project's rule: committed criteria lines are never edited; a wrong or underspecified criterion gets a dated revision beneath it, the study is judged only on evidence produced after it, and a revision may never increase false discoveries.

Files here: `criteria-study2.md` (study 2's committed criteria CS2.1 to CS2.3 with their shared definitions, verbatim); `draft-revision.md` (the proposed revision's text, to go beneath the definition of "the days run"); `brief4-step7.md` and `ledger-round4.md` (the design it rests on: how replays read the record, D189 to D193); `kernel-v2.md` and `KERNEL.md` (the engine's semantics, L1 and A19 cited by both).

Judge the revision, not the rest of the design. In particular:
1. Can it increase false discoveries? Construct, if you can, a forward run in which a strategy with no edge is named "earned" or "outgrew" under the revised reading and not under the committed text, or one in which the operator gains any lever (timing, choice of what is read) over the verdict.
2. Can it make a true claim fail? Construct an honest record on which the revision ends or blinds the test where the committed text would not.
3. Does it change any threshold, judged day, or the meaning of CS2.2's and CS2.3's "first replay after"? Is it consistent with the committed words, or does it contradict them?
4. Is its text precise enough that two implementers would read a day identically? Name every ambiguity.

Each finding: the construction, the outcome it changes, and whether it is fatal (do not commit), fixable in the text, or a note. End with a verdict: commit as is, commit with named text changes, or do not commit. Under 1,500 words.
