## Judgment

**Stage 5’s exit is MET under the frozen criteria as amended and clarified on 2026-10-22.** Discourse and Snapshot qualify as **prospective only**; unlocks remain **blocked**. This is not a pass of the original C5.3 availability requirements, and it does not establish that C5.6’s calibration has passed.

This judgment uses the supplied reports, test definitions, and recorded test results. I have not independently executed the tests or recomputed the datasets.

## C5.1 — Sources: MET for both sources

**Discourse.** `discourse.md` identifies the endpoint, pagination and history depth, polling rate, timestamp classes, original knownAt rule, and its superseding prospective rule. It quotes an affirmative permission for automated access from delvingbitcoin.org, with URL and retrieval date. Its stated request rate is comfortably below half the documented limits.

The versioned mapping uses the forum host rather than a ticker as its upstream key, and includes validity-interval fields. The 50-item labeled sample reports precision of 0.94 and within-sample recall of 1.0 for BTC. The record states that labeling preceded return-linked work and that the mapping golden set passes.

**Snapshot.** `snapshot.md` identifies the GraphQL endpoint, polling query, history depth, documented rate limit, and the distinction between client-claimed creation time and scheduled voting times. Its official-API quotation supplies the permitted-access basis accepted by the dated terms clarification. The prospective knownAt rule is explicit.

The mapping uses the stable space identifier `aavedao.eth`, is versioned, and includes validity-interval fields. The 50-item labeled sample reports AAVE precision and within-sample recall of 1.0. It also reports the incidental PEPE mention as kPEPE in the per-coin summary, consistently with U’s declared convention.

The recall figures are **sample-frame recall**, not evidence of comprehensive discovery of every relevant forum or Snapshot space. The evidence states that limitation rather than presenting these figures as ecosystem-wide recall. No further source-wide recall threshold was frozen.

## C5.2 — Revisions and lineage: MET for the exit datasets, with a recorded predecessor-identity limitation

**Both sources.** The parametrized store test covers edits, tombstones, restorations, and exact fetch boundaries for both `forum` and `space` key schemas. It checks that content becomes visible at the appropriate fetch boundary and that dataset-version cutoffs exclude later revisions. Separate tests cover file immutability and identical refetches.

The exit manifests bind the derived datasets to:

- the derivation-code hash;
- the mapping hash;
- the input-record hash;
- the raw-file hashes;
- the derived-row hash and output-file hash.

The supplied verification reports reproduce the exit datasets identically: **82 Discourse rows and 83 Snapshot rows**. Together with the stored-derivation recompute test, this satisfies the recomputation requirement for the inputs being certified at this exit.

**Discourse’s earlier rewrites require a qualification.** The human-authorized terms purge has a before-and-after hash record. The earlier knownAt-column migration does not: its predecessor hash was never recorded. Consequently, the packet cannot establish or reproduce that predecessor identity. `version-identity.md` correctly records this rather than manufacturing an identity retrospectively.

That is a limitation of the historical migration audit, not an unresolved identity ambiguity in the exit datasets. Their manifests bind explicitly to the retained, post-rewrite raw files, and their recomputation reports agree. I therefore do not treat the missing predecessor hash as a failure of the current exit’s lineage requirement.

It does prevent a stronger claim that every historical raw-file identity remains reconstructible. On the supplied record, that limitation does **not** change the present system’s false-discovery or leakage outcome: no search event dataset is bound, and the exit outputs are reproduced from explicitly identified retained inputs.

## C5.3 — Availability: MET under the amendment for both sources

**Discourse.** The exit report covers **91.1 hours**, exceeding the retained 72-hour requirement. It reports uptime, failed polls, poll gaps, pagination overlap, clock offsets, new-item and edit observations, and the operative availability margin. A live-versus-backfill reconciliation is supplied.

**Snapshot.** Its exit report likewise covers **91.1 hours** and supplies the corresponding uptime, gap, failure, overlap, clock, and item figures. Its reconciliation is supplied separately.

The recorders continued through the exit cut according to `notes.md`. The interruptions are documented. Under the clarification, realized cadence and clock-threshold violations are reported rather than judged for prospective sources; they are not grounds for restarting an uninterrupted 72-hour test.

The reconciliation windows end at the last appropriate live poll preceding each re-backfill. That avoids comparing live observations acquired after the backfill against an earlier backfill state. The small difference between those windows and the availability-report endpoints does not invalidate the reconciliation requirement.

The following distinctions remain important:

- Discourse’s original C5.3 failed and is not now passed retrospectively.
- The clock-offset maximum of about 4.9 seconds is reported, not certified as below one second.
- Neither source has a validated claimed-time rule for historical replay.
- The small new-item denominators do not prevent prospective classification under the amendment.

No additional fresh-segment validation of claimed times is required here, because the amended derivation admits none of those times as availability anchors.

## C5.4 — Coverage: MET for both sources

The coverage report classifies both sources as prospective and reports every coin of U.

**Discourse.** BTC maps to delvingbitcoin.org, with **82 covered hours**, explicit coverage intervals and recording gaps, **17 live-counted items**, and **zero derived search rows**. Every other coin is explicitly unmapped and has no covered intervals or derived rows.

**Snapshot.** AAVE maps to `aavedao.eth`, with **83 covered hours**, explicit intervals and gaps, **three live-counted items**, and **zero derived search rows**. Other coins are explicitly unmapped.

The report distinguishes historical raw items from usable derived search inputs. Thus, the 2,214 historical Discourse items and 241 historical Snapshot items are not represented as historically available event counts.

`derived.md` makes uncovered hours and unmapped coins undefined through absence of a row; covered zero-event hours receive explicit zero rows. The tests exercise the gap behavior. The supplied lineage manifests confirm that all exit-derived rows were written to the holdout side.

The difference between Discourse’s 18 observed new items and 17 live-counted items is not itself a discrepancy: the derived count is coverage- and window-qualified, whereas the availability denominator measures observed new items.

## C5.5 — Kernel integration: MET for both integrated sources

**Aggregation timing is now aligned with the criterion.** For hour label H, evaluation occurs at the tick T = H + δ. The documented count covers knownAt in **(T − 1 hour, T]**, and the row is known at T. This resolves the earlier hour-boundary versus tick-boundary mismatch.

The coverage rule is also causal: it depends only on polls at or before the relevant witness-window endpoint. The prefix-stability test checks that later records do not change an already-available row. The independent implementation reportedly agrees on 2,000 boundary-dense cases under the revised rule.

The other required integration elements have evidence:

- `ev` is a distinct base unit, with a unit-checking test.
- `hours_since` is documented and tested on the tick clock.
- Both event inputs have documented units, missingness, and freshness.
- Event values are not held into later ticks.
- Early delivery relative to knownAt is rejected.
- Holdout splitting and the I8 mutant are identified in the evidence map.
- The required applicable data-layer mutants are reported caught.
- Missing event datasets produce `R_INPUT_UNAVAILABLE` for both inputs.
- The evidence map identifies an end-to-end CLI test for inputs present only in holdout.

The schedule-revision input and its mutant are inapplicable because unlocks are a blocked category. The stage’s source-classification scope permits that outcome; it does not require implementing an unused schedule path merely to mutate it.

## C5.6 — Calibration extended: MET as an amended exit condition; calibration remains deferred

**For both sources, the original calibration work is not completed.** There is no submitted 300-market event-enabled N2/G400 result, and this review must not describe one as passed.

The dated clarification instead establishes an exit condition while calibration is deferred:

1. The search store carries no event dataset.
2. Programs naming the absent inputs are rejected.
3. Calibration evidence becomes mandatory before an event dataset is admitted to search.

The current evidence supports that condition. Both exit manifests report **zero search rows**. The missing-input tests cover both event datasets, including the reported CLI case. The criteria guard checks the canonical `data/store` and fails when an event dataset is present without the required probe and sweep evidence. The supplied record says that guard passes.

The guard’s demonstrated scope is the canonical search store. That supports this exit because the packet identifies it as the store used by the current search and gate workflow. It is not evidence that arbitrary alternative stores or future search configurations are automatically calibration-authorized.

Accordingly, **the amended exit condition is met now**. Before these inputs become searchable, the deferred calibration must actually be completed and its evidence checked. Prospective certification does not supply that authorization.

## Exit rule: MET under the amendment

The submitted evidence supports the required dispositions:

- **Discourse / delvingbitcoin.org:** prospective only.
- **Snapshot / aavedao.eth:** prospective only.
- **Unlocks:** blocked, with the failed paid-endpoint candidate, considered fallback, and human decision recorded under Blockers.

C5.1–C5.5 are met for the integrated prospective sources. C5.6’s amended deferral condition is met. The blocked category has the required record of what was tried.

**There is no remaining exit-blocking NOT MET or INSUFFICIENT EVIDENCE finding in this packet.** The missing predecessor hash is an explicitly bounded audit limitation; original C5.3 validation remains failed or unvalidated as applicable; and event-enabled calibration remains deferred. None should be relabeled as a successful historical validation when Stage 5 is marked complete.
