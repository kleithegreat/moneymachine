## Overall assessment

**The revision needs changes before it can authorize research-data access or class admission.** Its documentation-only provenance is useful, but does not resolve prior cross-stage exposure, the expanded pre-annex inspection allowance, or the licensing boundary.

This review uses only the three supplied files. Where full licence texts or certificates are referenced but not supplied, I distinguish an **unsupported permission** from a demonstrated prohibition. A source explicitly blocked pending verification is not, by itself, a violation.

## Blocking findings

### B1. “Before any stage 8 inspection” is weaker than the frozen evidence boundary

**Evidence:** The revision acknowledges that RTDSM, BLS, BEA, EDGAR and ECB observations have already been fetched, and potentially seen by agents. It nevertheless dates its protection by “stage 8 inspection” and leaves the class annex to record exposure and “place[] them accordingly.”

The criteria use an information boundary, not a stage label. They require selection and applicable annex decisions before inspection, including auxiliary sources, universe inputs, transformations and overlapping intervals. The revision does not define what placements are permissible after prior exposure.

**Scenario:** An agent has seen ECB observations during data-layer work. The same agent subsequently influences the currency population, study window or choice between ECB and another source. Calling the first access “stage 10” does not make the selection prospective. A fresh reviewer does not erase the earlier influence.

**Minimal fix:** Before further selection, freeze an exposure ledger identifying the observations, versions, intervals, recipients and derived information already disclosed. Specify which evidence is already search/spent and which remains genuinely reserved, including cross-source overlaps. Replace “stage 8 inspection” with inspection by any participant or process capable of influencing the campaign. Do not let an annex retrospectively designate exposed evidence as fresh.

---

### B2. The new definition of “integrity” materially relaxes the frozen pre-annex restriction

**Evidence:** The frozen criteria permit only HTTP status, sizes, hashes, poll times and parse success before annex freeze, and expressly prohibit computing or viewing coverage-by-value statistics. The revision adds:

- row counts;
- key uniqueness;
- `knownAt` ordering;
- missingness counts.

These are deterministic, but determinism does not make them selection-neutral. Missingness counts in particular concern thresholds and denominators the annex is supposed to freeze first.

**Scenario:** Before choosing a window, a reviewer learns that one source has many missing observations in an early period and few afterward. The annex then starts after the troublesome period. No return or signal was inspected, but the evidence being judged influenced its own inclusion.

**Minimal fix:** Restore the frozen whitelist. Additional checks may run only after the applicable choices are frozen, or inside a quarantined process that discloses no diagnostic to the research-selection process. If broader pre-annex inspection is intended, make it an explicit criteria amendment—not a definition of integrity—and account for information already disclosed.

**Related requirement:** Even otherwise permissible ingestion checks must not disclose holdout-derived diagnostics to researchers under C8.6.

---

### B3. The CME admission condition substitutes quotation for permission

**Evidence:** Both files report a CME restriction covering ML/AI/LLM use, including “generating output.” The revision nevertheless assigns Databento CME data a **kernel-only** role and says the commodity backtest tier remains blocked until purchase is decided and the CME terms are **quoted**.

Reading and quoting a prohibition does not establish permission. Nor does keeping raw rows away from an LLM establish that model use, derived outputs or other processing is licensed.

**Scenario:** Full terms confirm the reported restriction. The operator quotes them, purchases Databento data, and uses deterministic code to fit generators, evaluate strategies and produce reports for an AI-assisted research process. The manifest’s stated purchase-and-quotation condition has been met, but the permitted-use question remains unresolved.

**Minimal fix:** Make admission conditional on a documented determination that the **exact intended operations and outputs are permitted** by the full applicable terms. If the reported prohibition covers them and no permission request will be made, exclude that use. Apply the same determination to CME-originated EIA prices and Portara/CQG; a different distributor does not remove upstream restrictions.

---

### B4. “Kernel-only” is not a complete licensing test for the other vendors either

**Evidence:** The proposed rule asks for clauses permitting storage and deterministic processing. The supplied survey also identifies restrictions concerning:

- rights acquired by an LLM provider, for Norgate;
- permission or licensing for Nasdaq information in an AI tool;
- subscription termination and continued use.

Permission to store and process data does not necessarily authorize every research purpose, model use, report recipient or derived output. Conversely, a reuse grant must cover the actual material and use; a convenient licence label alone is insufficient.

**Scenario:** A vendor allows personal storage and ordinary processing, but restricts supplying information to an AI service or requires another licence for a particular use. The operator treats deterministic preprocessing followed by AI-readable reports as sufficient compliance.

**Minimal fix:** Require a source-specific permissions matrix covering acquisition, storage, transformations, model/calibration use, outputs, recipients and termination. Record the applicable upstream terms too. A human classification expresses an intended boundary; it does not supply contractual permission.

The supplied files do **not** establish that Norgate or Massive necessarily prohibit the proposed workflow. They establish that the general boundary is insufficient to decide it.

---

### B5. The debugging and report exceptions leave the information boundary undefined

**Evidence:** Kernel-only rows are said to enter “only deterministic code,” but coding sessions may see “small amounts while debugging.” Agents and reviewers may see “permitted reports,” without a specified report schema or a method for determining permission.

The additional prohibition on restricted fields helps, but does not resolve these exceptions. “Small” is not a contractual permission or a research-information boundary.

**Scenario:** An AI-assisted debugging session receives a few vendor rows or a report containing restricted metadata. Alternatively, a supposedly harmless diagnostic exposes data-quality or performance information before the affected selection is frozen.

**Minimal fix:** Define whether “coding sessions” includes AI recipients. Replace discretionary small samples with source-specific, explicitly permitted disclosures. Freeze report schemas and phase-specific access rules; pre-annex reports must also satisfy the narrower criteria restriction identified in B2.

---

### B6. The Norgate retention exception is broader than the support shown

**Evidence:** The revision leaves retention of hashes and outputs open for every vendor **except Norgate**, reasoning that clause 21 permits Derived Data. The supplied survey does not establish the definition, conditions or post-termination survival of that permission.

A permission concerning defined Derived Data does not automatically establish that every hash, fixture, report or kernel output qualifies and may be retained indefinitely.

**Scenario:** After subscription termination, the project retains outputs on the assumption that they all fall under clause 21. Some are outside its defined scope or remain subject to another restriction.

**Minimal fix:** Keep Norgate retention unresolved until the full clause, definitions and survival provisions support an artifact-by-artifact retention rule. Separate rights to retain, disclose, reuse and reproduce an artifact. An audit record being “independent of vendor rows” does not itself establish those rights.

---

### B7. The unchanged source-selection rules conflict with the proposed routes

There are two concrete ambiguities.

**A. Catalog dates versus observation-derived dates.** Rule 4 requires catalog start and end dates without observations. The existing ECB verification item says those dates are unavailable as metadata and suggests dating series from first and last observations through an annex procedure.

**B. Fifteen-year eligibility versus prospective-only sources.** The revision expressly preserves fifteen years **per proposed series**, but names SOFR, OBFR, TGCR and BGCR for prospective recording without clearly separating recording-only inventory from research eligibility under that rule.

**Scenario:** One reader treats first/last-observation dating as an allowed annex implementation and another treats it as a forbidden source-selection input. Similarly, one reader treats prospective recording as an exception to the fifteen-year rule while another excludes the series.

**Minimal fix:** Preserve the distinction explicitly:

- research-proposed series must satisfy rules 3 and 4;
- recording-only, currently ineligible series are separately labelled and cannot enter research through recording alone;
- observation-derived dating cannot substitute for required catalog metadata without an explicit reviewed rule revision made before the affected evidence is accessed.

The fifteen-year rule concerns catalog history; it should not silently become either a requirement for fifteen years of certified vintages or an exemption for newly recorded series.

---

### B8. The macro extension does not supply a selection rule for its expanded population

**Evidence:** The original class has a specific ECB FX candidate population and eligibility rule. The revision extends it to the “free sources proposed above,” including broad collections such as Fed releases, RTDSM, BLS, BEA and EIA, but does not define:

- which series are targets versus features;
- their candidate population;
- the rule selecting among eligible series;
- how the ECB-specific universe rule relates to them.

“Each certified” is a quality gate, not a selection rule. Annexes may specify study details, but the scope manifest itself must name instruments or feature roles and a universe rule.

**Scenario:** After viewing newly allowed missingness diagnostics, one reader chooses a small, clean macro panel; another chooses every certifiable series. Both can describe their selection as the free-source extension.

**Minimal fix:** Before exposing selection-relevant diagnostics, freeze either stable series identities or an objective metadata-only population and eligibility rule, with target/feature roles. Keep unspecified extensions blocked for research. Any recording-only authorization should be explicit and quarantined.

---

### B9. Lack of independent membership evidence cannot be downgraded to a “qualification”

**Evidence:** The indices section says Norgate membership has no independent source and records this as a qualification. C8.1 requires comparison of the whole expected set with independent historical membership or listing evidence, with zero unexplained errors. The cited EDGAR form types are not shown in these files to supply independent index-constituent membership evidence.

**Scenario:** A constituent strategy uses Norgate membership, reconciles it against the same vendor’s records, and reports the lack of independent evidence as a limitation rather than a failed prerequisite.

**Minimal fix:** State that constituent-universe admission remains blocked until the independent audit requirement is met. For a fixed ETF-proxy study, separately freeze and verify which index-membership requirements are genuinely inapplicable; independently audit the ETF population and lifecycle where required. ETF listing evidence must not be presented as proof of index membership.

## Non-blocking findings

### N1. Purchase decisions are described too much like the remaining class-admission gates

The equities and indices sections say they are blocked until a purchase decision. The documents themselves identify additional gaps: missing dividend declaration dates, merger terms, delisting proceeds and independent membership evidence.

**Scenario:** A reader interprets purchase as making the class ready for admission.

**Minimal fix:** Say “purchase is one prerequisite, not admission,” and list the outstanding certification, lifecycle, accounting and audit gates. The global criteria still require them, so this wording alone does not establish that they have been waived.

---

### N2. The ETF substitution needs clearer claim boundaries

Changing from index levels to labelled ETF instruments is not inherently a relaxation: it is a different instrument scope, and the revision acknowledges that distinction. But “ETF proxy for \<index\>” does not identify the ETF-selection rule, distributions, currency or relevant history.

**Scenario:** Two readers choose different ETFs tracking the same index and obtain materially different histories and outcomes.

**Minimal fix:** Keep the replacement scope blocked until a metadata-only proxy-selection rule and stable identities are frozen. Retain all applicable equity corporate-action and accounting requirements. No ETF result should discharge an index-level or constituent-strategy claim.

---

### N3. Some exclusion rationales are not independently supported by the supplied survey

Examples include the blanket FRED/ALFRED statement that storing and ML use are forbidden, and several compressed multi-source exclusion rows. The supplied combined report does not contain enough quoted terms to validate every such conclusion.

**Scenario:** A future reviewer treats a conservative exclusion as an established, universal legal prohibition.

**Minimal fix:** Link each conclusion to its exact terms record and distinguish “prohibited,” “not verified” and “not selected.” Because these sources remain excluded, this is presently a documentation issue, not an authorized terms violation.

---

### N4. Governing status and reporting remain easy to misread

The file preserves earlier statements, overrides differences through the revision, and retains a reporting example naming only ECB FX and World Bank benchmarks despite the expanded proposed scope.

**Scenario:** Readers disagree about whether an added macro family is merely being recorded, proposed for research, or already admitted.

**Minimal fix:** Add a governing status table separating **recording authorized**, **research proposed**, **annex blocked**, and **admitted**, with tier and outstanding gates. Generate completion wording from the actually admitted scope.

## What is not a finding

- Allowing keys, accounts and purchases is an explicit source-selection change, not inherently a statistical weakening.
- The separately labelled signal-study tier already exists in the frozen criteria; retaining it is not a new relaxation.
- Recording current-vintage sources prospectively is appropriate, provided availability is established for each delivered version—not backdated to a general recording start.
- Unread terms, unavailable independent evidence and incomplete certificates are acceptable **blockers**. They become problematic when a label, purchase, quotation or “qualification” is allowed to substitute for resolving them.
- Opus review of this revision does not itself violate the supplied criteria. It does not replace the required GPT review of class annexes.

**Bottom line:** Resolve B1–B9 before this revision is used as research authorization. None of these findings proves that a contaminated campaign or unlawful use has already occurred; they identify permissions and ambiguities that currently allow one.
