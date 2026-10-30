# GPT re-review of the stage 8 scope manifest (B1, B3-B5), 2026-10-30

Model openai/gpt-6.1-sol#high, run per CLAUDE.md (attachments: scope-manifest.md, exposure.md, the stage 8 criteria, its two earlier reviews). Reply verbatim; not acted on (the findings are material to evaluate).

**The manifest is not yet sufficient to authorize research use.** This review uses only the attached files; referenced certificates, terms records and other ledgers are not verified.

## B1 — Partly closed

The expanded ledger substantially improves the account of earlier exposure, and the manifest now correctly uses an information boundary rather than stage labels.

Two gaps remain:

- The ledger expressly excludes “the stage 10 thesis agents’ reads, which their own ledger records.” That ledger is not supplied, so campaign-relevant cross-stage exposure and overlap are not established here.
- Classifying evidence as search or spent does not repair choices that the criteria required to precede inspection. The ledger documents ECB population, coverage and lifecycle information seen before the later revisions, but the manifest does not require adjudication of which subsequent choices were affected.

**Blocking manifest text:**

> “A class annex places exposed evidence as search or spent and never as fresh.”

**Required change:** Require a complete, frozen campaign-relevant exposure inventory before affected selection resumes, incorporating the omitted reads and tracing relevant artifacts, recipients, indirect disclosures and cross-source overlaps. Require the annex to identify choices already made after exposure and the claims consequently blocked. Explicitly state that search/spent placement does not retrospectively satisfy prospective-freeze requirements.

## B3 — Partly closed

The operation-specific framework now covers upstream CME terms and correctly rejects quotation or a role label as permission. However, it still gates **admission**, while recording and some processing are described as authorized already.

**Blocking manifest text:**

> “Admission of a kernel-only source needs a permissions record quoting the governing clauses, upstream terms included (CME's for Databento, EIA's NYMEX series and Portara/CQG), for each intended operation: acquisition, storage, deterministic transformation, generator fitting and calibration, kernel evaluation, each report shown to an agent or reviewer, recipients, and retention or deletion at termination.”

Also:

> “Databento's certification (operator decision, 2026-10-26) covers acquisition, storage and deterministic kernel processing; outputs shown to agents need their own determination, which is the human's (`PROGRESS.md`, decisions awaiting review).”

**Required change:** Make the relevant permissions determination a prerequisite **before each operation occurs**, not merely before admission. Clearly separate operations covered by the asserted certification from unresolved uses and outputs; block the latter pending determination. If applicable terms prohibit an intended operation and no permission will be sought, exclude that operation.

The absent certificate prevents verification of its asserted coverage; it does not itself demonstrate a violation.

## B4 — Partly closed

The permissions matrix adequately identifies the questions for other vendors, including model use, recipients and termination. The same timing defect remains: unresolved permissions must constrain current operations, not just eventual research admission.

**Blocking manifest text:**

> “Recording stays authorized; research use of any source or class needs every gate below met and a class annex frozen and reviewed.”

Read with the admission-only permission requirement quoted under B3, this leaves earlier acquisition, processing and retention insufficiently gated.

**Required change:** State that recording authorization is conditional on established acquisition and storage rights, and that every subsequent transformation, model use, disclosure and retention operation requires its applicable source-specific permission first. Human classification or ownership of a pending decision is not interim authorization.

## B5 — Partly closed

AI coding sessions are now explicitly recipients, pre-annex disclosures are restricted to the frozen integrity list, and report schemas must be frozen. But the discretionary debugging exception survives.

**Blocking manifest text:**

> “Their debugging allowance is the human's rule and stands as written”

That preserves the earlier allowance:

> “the operator's coding sessions may see small amounts while debugging, preferring counts, hashes, schemas and test results (human decision).”

**Required change:** Replace small-sample discretion with source-specific, explicitly permitted disclosures and phase-specific access rules. Until the AI-disclosure determination is resolved, block that debugging/report route—including after annex freeze. Schema freezing establishes neither contractual permission nor research-information safety. Explicitly preserve C8.6: even otherwise whitelisted integrity checks must not disclose holdout-derived diagnostics to the research process.

## Verdict

**No.** The criteria amendment resolves the earlier keyless-only recording-exception issue, but not these remaining authorization gaps. B1 still needs complete exposure accounting and treatment of missed prospective choices; B3–B5 need enforceable permission gates before the affected operations. No class is currently admitted, and the supplied attachments do not establish authorization to begin research use.
