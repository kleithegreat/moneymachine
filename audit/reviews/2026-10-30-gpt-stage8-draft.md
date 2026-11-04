**Adopt after the wording corrections below—not verbatim.** The draft closes the remaining *manifest-level gates*, but does not establish that their prerequisites have been satisfied. No class becomes admitted.

## Findings, ranked by consequence

### 1. The proposed deletion remedy could affect statistical reporting; return this point to the human

The licensing objection itself can remain a known limitation. Accepting a licence interpretation does not, by itself, change the statistical procedure.

But the draft goes further: it says the issue **cannot** affect false discoveries or leakage, and that the remedy is deleting the source’s “rows and results” (`audit/stage8/manifest-revision-draft-2026-10-30.md:91–95`, introduced in `e361ecf`).

That conclusion is too broad:

- Freezing a report whitelist does not itself establish information safety. The paper additionally requires minimum aggregation and attempted reconstruction from **combined** reports (`docs/whitepaper.tex:446–449`).
- Deleting restricted artifacts is different from removing campaigns, failures or outcomes from statistical accounting. Selective disappearance of results, or treating replacement work as a fresh attempt, could change false-discovery reporting.
- The existing manifest makes the audit independent of vendor **rows**; it does not authorize erasing results indiscriminately. Retention remains unresolved artifact by artifact (`audit/stage8/scope-manifest.md:172–175,224–225`). C8.6 requires campaign counts, failures, promotions and class choices to remain reported (`audit/criteria.md:1139–1141`).

**This is a prospective defect in the proposed remedy, not evidence that selective deletion has occurred.** Under `audit/decisions.md:349` (`0314a43`), it returns to the human. It does **not** require reopening the accepted CME/Nasdaq interpretation.

Replace the proposed limitation’s statistical-immunity/deletion explanation with:

> The human accepts this licensing uncertainty; that acceptance establishes neither the interpretation’s correctness nor information-boundary safety. All existing disclosure, reconstruction-test and C8.6 requirements remain unchanged. Required deletion of restricted artifacts does not authorize omitting campaigns or outcomes from statistical accounting, reducing the tested family, resetting selection history, or reusing spent evidence. If legally permissible audit evidence cannot be retained, the affected claims are reported as unverifiable or withdrawn, not silently removed or replaced as fresh attempts.

### 2. B1’s ECB chronology is true, but does not establish general prospective compliance

I verified:

- `c2b0811` committed the ECB population and 750-publication-date rule at **2026-10-23 14:24:16 EDT**.
- The first recorded ECB observation disclosure is **14:25 EDT** (`audit/stage8/exposure.md:10`); session `9afc784d`, retrieved through `ctx zoom 77`, corroborates that order.
- Those two rules remain unchanged (`audit/stage8/scope-manifest.md:88–90,233–234`).

**That part is fine.**

The inference at draft lines 21–24 and 69–72 is not established for other choices. The exposure inventory still expressly omits thesis-agent reads (`exposure.md:25–26`). Also, the signal-study criteria were revised in `4a0b34c` at **14:26:15 EDT**, after the recorded disclosure. That was review-driven strengthening, not proof of contamination, but it illustrates why unchanged ECB eligibility rules cannot certify all later decisions.

Choices not yet made are not automatically prospective with respect to evidence already inspected.

Replace the blanket assurance beginning “As of this revision no manifest choice…” with:

> The ECB candidate-population and 750-date eligibility rules were committed in c2b0811 before the recorded ECB observation disclosures and remain unchanged. This establishes chronology only for those rules, not prospective compliance for other choices. Each annex adjudicates already-made and still-unmade choices against prior exposure and the applicable freeze requirements; unsupported claims remain blocked. Search/spent placement supplies no retrospective exemption.

The inventory need not be completed **before adopting this blocking rule**. It must be completed before the affected selection or annex proceeds.

### 3. The permissions fix is sound, but its coverage statement needs narrower attribution

The stale pointer really is stale: `PROGRESS.md:55–57` says “None.” The human decisions exist:

- Licensing boundary and permitted outputs: `audit/decisions.md:129–137`.
- Databento operator determination: `151–155`, committed in `6e379b3`.
- Explicit aggregate-report permission for research agents and reviewers: `168–173`.

Thus, the draft correctly resolves the supposed *pending human decision*. However, “Covered today” (`draft:77–80`) should not read as universal coverage for every source or every deterministic operation.

The Databento record supports the **existence and scope of the operator’s determination**, not independent proof that the legal interpretation is correct (`venue/sources.toml:533–562`). Its missing Subscriber Addendum is explicitly acknowledged there. `ingest/terms.py:19–21` checks record structure, not substantive permission.

Use:

> Coverage is source- and operation-specific. Databento GLBX.MDP3’s acquisition, storage and deterministic kernel processing rest on the recorded operator determination of 2026-10-26; ICE is excluded. No other operation is deemed covered merely because it is deterministic. Aggregate AI-facing reports are human-approved in principle under the decisions of 2026-10-26 17:25 UTC (13:25 EDT) and 23:19 UTC (19:19 EDT), but remain operationally blocked until the applicable permissions record, frozen report schema and disclosure-safety prerequisites are satisfied.

The third review was principally about **permission timing**, not simply another rejection of the human’s legal reading (`manifest-review-gpt-3.md:24–36,40–48`). The draft’s characterization should reflect that.

## Disposition of each finding

| Finding | Closed by the draft? | Evidence assessment |
|---|---|---|
| **B1** | **Yes as a blocking manifest rule**, with the chronology correction above. Inventory completion and annex adjudication remain outstanding. | ECB chronology true; campaign-wide assurance unsupported. |
| **B3** | **Yes, permission timing is corrected.** The human’s accepted interpretation need not be relitigated. | Decisions verified; substantive legal correctness not independently established. |
| **B4** | **Yes**, subject to source-specific coverage rather than a blanket “covered today.” | Acquisition/storage conditions and operation-by-operation prerequisites are appropriate. |
| **B5** | **Yes.** Small-sample discretion is replaced, and C8.6 is expressly preserved. | The human accepted exactly this narrowing (`decisions.md:347`, `0314a43`). |

**The accepted B5 rule is fine:** it narrows access and does not itself weaken false-discovery or leakage protection. To prevent a separate debugging bypass, add:

> Schemas, counts, hashes and test results are disclosures subject to the applicable source permissions, phase restrictions and frozen disclosure boundary; debugging creates no exception.

**Bottom line:** adopt the revision with these corrections, retain every existing blocker, and return the proposed result-deletion implication—not the settled licensing objection—to the human. No protected recordings or raw kernel-only rows were accessed; the worktree is unchanged.
