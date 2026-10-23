## Overall assessment

The draft is a useful **proposed scope**, but it is not ready to commit as an unqualified admitted scope. The main issues are:

1. The blocked equity and index entries omit some information the manifest must provide for **each** class.
2. Both admitted universes lack a specified historical candidate population and independent membership evidence.
3. The FX suspension rule permits a hindsight close at the last fixing.
4. A prospective recorder or an assumed revision lag cannot make unrecoverable historical values point-in-time.
5. Monthly commodity benchmarks do not, by themselves, satisfy the frozen criteria’s commodity-contract and accounting requirements.
6. Several source descriptions need metadata and terms verification before they can support the proposed scope.

The draft correctly defers research windows, holdouts, witness strategies, gap limits, recording minima and accounting details to class annexes. Those are not missing manifest fields. However, the annexes must resolve the feasibility issues below before observations are fetched.

## 1. Required manifest content that is missing or incomplete

### Blocked equities and indices still need complete entries

The scope-manifest clause requires proposed sources, instruments or feature roles, universe rules, jurisdictions and venues for **each of the four classes** (`stage8-criteria.md:11–22`).

The equity and index sections name attempted sources and unmet requirements, but:

- equities have no proposed universe rule, jurisdictions or venues;
- indices have no proposed universe rule or jurisdictions;
- the intended instruments are described only broadly.

Blocked status does not require an implementable universe, but the manifest should explicitly identify what is unresolved rather than leave required fields absent.

**Suggested wording:**

> **Equities — blocked.** Intended role: underlying equity signal studies. Proposed universe rule: unresolved; no certified historical candidate population or point-in-time eligibility inputs have been identified among the sources considered. Jurisdictions considered: [enumerate]. Research markets and possible execution venues considered: [enumerate]. Sources considered and the specific access, terms or coverage failure for each are recorded below. No equity observations will be fetched under this scope.

Use the corresponding wording for indices, distinguishing **index-level studies** from **constituent strategies**, which require different membership evidence.

### The admitted universes need candidate-population sources

“Every Pink Sheet commodity” and “every currency with an ECB reference rate” describe eligibility, but do not identify the certified historical population from which candidates are drawn. C8.1 explicitly forbids defining that population as the assets that happen to have price files.

Name, for each universe:

- the historical catalog, listing or registry source;
- stable identifiers and lifecycle evidence;
- how additions, withdrawals, renamings and replacements are represented;
- the independent historical evidence intended for the membership audit.

A current catalog alone is insufficient.

### Clarify the limited research roles

“Macro and rates: admitted” is broader than the instruments actually proposed. The target is ECB FX reference-rate signal studies; yield curves, policy rates and other releases are features. No executable rate instrument is specified.

**Suggested wording:**

> **Macro and rates — proposed for admission as ECB FX reference-rate signal studies, with the listed macro and rate series used as features.** No trading result on a rate instrument is claimed by this scope.

## 2. Selection procedure and outcome-dependent choices

### No explicit return-based selection is present

The stated selection procedure uses documentation, terms, schemas and catalog metadata, and explicitly excludes returns, signals and calibration results. The two history-completeness rules can be legitimate, frozen eligibility rules. Their use of observed availability is not inherently prohibited source selection.

There are, however, several ambiguities to close.

### Make ranking and subsequent scope changes deterministic

“Ranked by history length, then by revision documentation” leaves unspecified:

- whether ranking determines inclusion;
- which history length is measured—source-wide, series-specific or usable point-in-time history;
- how revision documentation is ranked;
- how ties are resolved.

A source with a long history of currently revised values may have little usable point-in-time history.

**Suggested wording:**

> Source eligibility and any priority order are determined solely from identified documentation and catalog metadata captured before observation access. History length is assessed for the proposed series and frequency; documented point-in-time availability is assessed separately. The revision-documentation ordering and tie rule are [specified here]. All sources considered and reasons for inclusion or exclusion are retained.

Also freeze the response to later failures:

> A failed certification or annex prerequisite is recorded as a failure or blocker. Any replacement source, universe-rule change or class-scope change receives a dated, reviewed revision before affected evidence is inspected. Returns, signals and calibration outcomes cannot determine those revisions.

### Avoid treating current venue listings as historical eligibility

The draft appropriately limits HIP-3 listings to projection targets. Make explicit that `xyz:GOLD`, `flx:OIL`, and today’s index perps do not select the historical research universe, benchmarks or search windows. Otherwise current venue availability could reintroduce the popularity-based selection problem identified in `paper-multiasset.tex:13`.

## 3. Point-in-time and survivorship problems

### FX suspension exits currently permit hindsight execution

The rule says a currency leaves at the first missing fixing and its position “closes at the last fixing known to be live” (`scope.md:62`).

At the first missing fixing, the previous fixing is already historical. Knowing that it was published does not establish that a position could have been closed there in response to the later suspension. The final sentence—“The last fixing is never assumed to be the last”—does not repair this.

**Replacement wording:**

> A missing expected fixing or a suspension affects eligibility only when that fact becomes known under the certified availability rule. It cannot cause a retroactive close at an earlier fixing. Existing exposure remains explicitly represented until resolved under the annex’s frozen lifecycle and valuation rules. An unavailable execution price does not create a fill; any unresolved exposure or unidentifiable outcome is reported under the frozen missing-terminal-price policy.

This is especially important because an ECB reference fixing is not an executable quote.

### Specify the FX calendar, cutoff and entry/exit timing

“750 business days” is ambiguous. It needs a certified expected-publication calendar and an exact decision cutoff. A fixing not yet due or not yet available at that cutoff must not be classified as missing.

The rule also needs to distinguish:

- entry qualification using prior observations;
- response to a newly missing expected fixing;
- re-entry after suspension;
- currency identity changes and cessation, including euro adoption.

**Suggested wording:**

> Eligibility is evaluated at the annex’s frozen decision cutoff using the preceding 750 eligible reference-rate publication dates under the certified calendar. Only observations available by that cutoff may qualify a currency. Candidate identities and lifecycle events come from the certified historical reference-rate population, not the current currency list. Entry, suspension, cessation and re-entry policies are frozen before observation access.

### Pink Sheet membership needs historical series identities

A current Pink Sheet workbook or current commodity list could omit discontinued series, incorporate renamed benchmarks, or splice changed specifications.

“Every Pink Sheet commodity” must distinguish a commodity from a particular published benchmark series. Freeze treatment of changes in:

- benchmark specification, grade and location;
- units and currency;
- identifier and name;
- methodology and discontinuation.

**Replacement wording:**

> Candidates are the benchmark-series identities in the certified historical Pink Sheet catalog as known at each decision cutoff, including subsequently discontinued series. Eligibility requires a published value for each of the preceding 120 eligible reference months, available by that cutoff. Benchmark replacements or specification changes are not joined without a separately certified transformation.

The annex must also fix the relationship between decision month and publication month. At an early-month decision, the previous month’s value may not yet have been released. The 120-month window must not shift opportunistically to whichever observations are available.

### “Ties are impossible” does not resolve the universe specification

Set membership removes ranking ties, but does not resolve duplicate identifiers, multiple benchmark variants or lifecycle transitions. Replace that sentence with:

> No ranking is used. Membership is a set of stable benchmark-series identifiers; identifier collisions and benchmark transitions are handled by the frozen mapping and lifecycle rules.

### Prospective recording does not recover historical vintages

The Pink Sheet paragraph allows a “prospective recording procedure or a documented revision rule” to solve the vintage problem. That is too permissive.

Recording now can establish availability and revisions going forward. It cannot establish the values known during a historical 120-month eligibility window. A presumed revision lag, or a rule that treats current values as final, does not recover superseded releases. The same issue applies to historical macro features and catalog membership.

**Replacement wording:**

> Historical use requires recoverable publication and revision evidence satisfying source certification. Prospective recording establishes usable evidence only from its certified start and does not validate earlier vintages retrospectively. A documented revision rule is sufficient only where its evidence establishes which values were available at each decision. Otherwise the affected historical use is blocked; prospective use requires the annex’s frozen duration and event minima.

Historical **candidate-population metadata** needs this treatment too, not just prices and features.

## 4. Source claims requiring verification before commit

The following are verification tasks, not established findings from the supplied material.

| Claim | Required verification |
|---|---|
| **All proposed sources meet the selection rule** | Check the exact proposed series, frequency, start date and metadata-only discovery route. A source-wide history does not establish 15 years for each intended input. |
| **ECB EXR, YC and money-market coverage** | Record exact dataflows, series identifiers, frequency, units, start dates, benchmark definitions, discontinuities and revision policies. “Money-market rates” is not yet a specified feed. |
| **ECB fixing at 14:10 CET** | Distinguish rate determination from publication and recorder availability. Verify the official clock convention and daylight-saving treatment. A fixing time is not automatically a valid `knownAt`. |
| **BIS host, `WS_CBPOL`, `WS_EER` and daily coverage** | Verify the supported API endpoint, dataflow/version identifiers, series-specific frequencies and histories, publication metadata, revision coverage and historical availability evidence. |
| **World Bank API and CMO files** | Verify which documented distribution actually supplies the proposed monthly Pink Sheet history and its catalog metadata. Do not assume `api.worldbank.org` exposes the same dataset, coverage or vintage information as the CMO files. |
| **Treasury monthly average interest rates** | Identify the exact endpoint, units, categories, history, publication evidence and revisions. Distinguish these averages from yields or executable instrument prices. |
| **CFTC legacy history from 1986** | Verify that the intended API dataset supplies that history, rather than a separate archive. Check each report family’s identifiers, coverage, revisions and contract mappings. |
| **CFTC publication Friday 15:30 ET** | Treat that as a schedule to verify, not an unconditional historical availability rule. Holiday delays, postponements and corrections require actual release evidence. |
| **HIP-3 target symbols and histories** | Verify current instrument identity and contract metadata, separately from historical research eligibility. Public API access does not establish operator trading eligibility or a certified execution mapping. |

### Terms evidence is incomplete

The table’s summaries are not a substitute for the quoted permitting clauses, URLs and retrieval dates promised in `scope.md:12–13`. Those details may live in the named certification records, but the manifest should reference identifiable evidence.

“Certified for stage 10” does not establish that a certificate covers the stage 8 feed, fields, historical use and transformations.

**Suggested wording:**

> Terms and any prior certification are referenced by certificate identity and version, with the exact endpoint, dataset and permitted use covered. Prior certification is reused only where its coverage matches the proposed stage 8 use.

There is also an internal selection-rule inconsistency: the procedure requires an official documented **API**, while the World Bank entry includes **CMO files**. Either identify a qualifying API or revise the procedure before commit to permit official documented machine-readable downloads, subject to the same terms and metadata requirements.

### Narrow unsupported exclusion claims

“Every keyless option fails” overstates what the named examples establish. Likewise, the grouped FRED/EIA/BEA/BLS/SEC statement needs source-specific evidence for the exact access route considered.

**Replacement wording:**

> Among the sources considered below, none has yet satisfied the access, terms and historical-data requirements. For each, the record identifies the endpoint or product considered, the documentation consulted, and the specific unmet requirement. This is not a claim that all possible keyless sources have been exhausted.

## 5. Are the class statuses justified?

### Equities: blocked is justified, with narrower support

The draft identifies unmet requirements for historical candidate populations and price/corporate-action histories. That supports blocking the proposed equity work. Complete the required manifest fields and replace the universal exclusion claim with a source-by-source record.

### Indices: blocked is justified for the proposed long-history studies

Short HIP-3 histories do not satisfy the underlying research objective. Specify whether the blocked objective is index-level research, constituent research, or both; the latter has additional point-in-time membership requirements.

### Commodities: unqualified admission is not yet justified

The proposed monthly benchmark studies differ materially from the frozen commodity requirements. C8.2 specifies individual contracts, contract metadata, roll decisions and held-contract PnL; the paper’s research-layer description also specifies futures with explicit roll rules.

Calling a benchmark result a “signal study” correctly limits its interpretation, but does not automatically waive those requirements. The draft also lacks demonstrated historical candidate-population and vintage feasibility.

**Suggested status wording:**

> **Commodities — proposed monthly benchmark signal-study scope; admission blocked pending resolution of its compatibility with the frozen commodity and accounting requirements, historical population evidence, and point-in-time availability.** If benchmark-only studies require a criteria revision, that revision must be explicitly reviewed and frozen before implementation or observations.

### Macro and rates: a plausible proposal, not demonstrated feasibility

ECB FX reference-rate studies are a coherent proposed scope, with macro/rate series as features. Admission remains conditional on the historical candidate population, vintage/publication evidence and corrected lifecycle rules.

Use **“proposed for admission, annex and certification prerequisites outstanding”** if “admitted” is intended to mean selected for investigation. Do not let the label imply that historical feasibility has already been established.

### Projection status and completion wording need separation

The final status sentence is too unconditional. C8.7 requires eligible, certified execution mappings for claimed projections; otherwise signal-study completion is reported separately and execution mapping remains blocked.

**Replacement wording:**

> If the admitted signal-study scopes satisfy their applicable frozen criteria, report completion for those scopes explicitly, with equities and indices blocked. Report venue projections separately: each remains model-dependent and subject to C8.7; where no eligible mapping is certified, execution mapping remains blocked. No signal-study completion is described as venue validation or trading readiness.

Finally, freezing the manifest and annexes does not itself authorize implementation: the stage 7 exit and pilot judged-run ordering prerequisite still applies.
