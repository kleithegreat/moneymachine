# Stage 7, slice 1: the reference semantics generalized over declarations, and the laws restated (draft, revision 7)

C7.7 requires the Lean semantics to be parameterized by validated declarations and bindings; every stage 6 law to keep
its guarantee for every admitted declaration, held and event cadences included; each law whose definitions change to
be revised, independently reviewed and frozen before its proof; and a binding law under which evaluation is undefined
whenever a required source lacks a valid, matching, in-scope certificate.

**The definitions and law statements are the Lean on branch `stage7`:** `reference/lean/Ref/Source.lean`
(declarations, observations, certificates, admission metadata, the loader, the payload-free stages and the trusted
boundary `Trusted`), `Machine.lean` (the latest observation per source and coin, its reads), `Sim.lean` (delivery,
execution's role projections, run admission, accesses and scope, `admit`, `runProgram`, `run`), `Spec.lean`
(`Program.WF`, prefixes, views, `firstFailure`, `sameShape`, `InputRef`) and `Laws.lean` (L1–L7, proofs `sorry`
until the statements are frozen). This document keeps the design, the attacks, the spec changes and the review
ledger; it does not restate the Lean.

Reviews: four fresh-context Opus reviews while GPT was unavailable (`laws-review-opus-1.md` to `-4.md`) and GPT's
two (`laws-review-gpt-1.md` on revision 5, `laws-review-gpt-2.md` on revision 6's Lean). §10 records every finding
of the last four, its answer, and whether it could change a false-discovery or leakage outcome (CLAUDE.md, rule 3).

## 1. The design, from what the semantics reads

- **Everything a decision reads is delivered.** Inputs, the decision's freshness and its price are reads of delivered
  observations; a role provider's observations carry their role payload and are delivered like any source's.
- **Execution reads venue state at its event time.** Fills, marks, extremes and settlement read the providers' bars
  and rates by open or event time, as version 1 does: the account's state at the venue, applied at that time whatever
  our record's knownAt. A provider's certificate must attest it (`Cert.venueState`, checked in stage 1). The
  guarantee this gives is L1_decisions: decisions depend on execution data only through the execution view at
  decision time, so a record known later than its event time can affect equity, as at the venue, but no input.
- **Version 1's reads and order.** Per source and coin the machine holds the latest delivered observation; a held
  input reads it, an event input only if its slot is the current hour. Within a source, delivery is by (knownAt,
  coin, tie): the event time for held sources (version 1's funding and bars), the resolver position for event sources
  (its feeds). Across sources the interleaving is unobservable (per-source stores, `maxKnown` a maximum), and C7.4
  compares one stream per source.
- **Two kinds of columns, two authorizations.** Value columns (fields, role columns) are data: grants authorize them
  per entity, event time and use interval, checked against every read (`accesses`, `inScope`). Control columns
  (availability inputs, event, slot and entity columns, revision and tombstone columns) are what the resolver reads
  over the whole dataset, and its dependencies' controls, to select records and compute availability; the
  certificate authorizes them explicitly (`Cert.controls`, checked in stage 1 before any read). Resolution may decode
  every row of a bound dataset; a value influences a run only through a read observation, which `accesses` covers.
- **Staged admission, validated entry.** `run` takes the program text and checks the registry, the policy and the
  program first (`R_INVALID`); then metadata only (stage 1), event times only (stage 2, I8), resolution, run
  admission (version 1's structural conditions, no value read) and scope, then evaluation.
- **The trusted boundary is a Lean structure.** `Trusted` names what the implementation guarantees outside the model:
  `rows` is the complete event-time inventory, `resolve` is RULES.md §6 on the stored bytes, bindings name the bytes'
  content identities, certificate ids are payload hashes of issued certificates, supersessions are the ledger's,
  and the holdout configuration is the frozen one. L5_certified states what an admitted run guarantees under it.
  `mm` discharges it by content hashing, the C7.6 resolver suite, the ledger's append-only triggers and the staging
  tests (§8, rows 17 and 18).

## 2. C7.7's named attacks: the law and the named `mm` test that catch each

| # | Attack | Law / check | Named test (planned location) | Expected | Positive control |
|---|---|---|---|---|---|
| 1 | forged ledger passes | verifier writes certificates in its transaction | `kernel/mm/tests/certify.rs::forged_pass_is_not_authority` | no certificate | issuance from the same bundle |
| 2 | missing tests, unjustified inapplicability | policy categories | `certify.rs::missing_test_refused` | issuance refused | a complete bundle |
| 3 | changed thresholds or policy | `matches` (policy pinned in the build) | `certify.rs::changed_policy_uncertified` | `R_UNCERTIFIED` | the frozen policy |
| 4 | replay against another manifest, mapping, extractor or rule | `matches`; verifier for mapping and extractor | `admission.rs::replayed_certificate` | `R_UNCERTIFIED` | the matching dataset |
| 5 | use outside the certified scope | L5, `inScope` | `admission.rs::out_of_scope_access` | `R_UNCERTIFIED` | a run within its grants |
| 6 | data changed after validation | the loader's content identity (trusted boundary) | `admission.rs::changed_data` | `R_UNCERTIFIED` | unchanged data |
| 7 | failed issuance or ledger commit before output | commit before output | `certify.rs::failed_commit_emits_nothing` | no certificate, no output | a committed issuance |
| 8 | a missing source in an unused let or inactive branch | L5.5, unbound check | `admission.rs::unused_let_source_required` | `R_INPUT_UNAVAILABLE` | the source bound |
| 9 | uncertified execution data | providers in `required`, role columns in `accesses` | `admission.rs::uncertified_role_provider` | `R_UNCERTIFIED` | certified providers |
| 10 | feed timestamp posing as trusted availability | verifier availability basis; `times` in `accesses` | `certify.rs::claimed_time_without_live_test` | issuance refused, or `R_UNCERTIFIED` | a server-set time with a passing live test |
| 11 | backdated revisions, superseded-rule outputs, old-revision fallback | C7.6 resolver suite | `kernel/tests/rules/test_three_implementations.py` | the selected revision's knownAt | the hand cases |
| 12 | future-dependent coverage or mapping | verifier coverage and mapping by knownAt | `certify.rs::coverage_from_a_later_poll` | issuance refused | coverage known in time |
| 13 | a derived feed before an upstream input; an upstream control read not authorized | resolver dependency bounds; upstream `controls` (stage 1) | resolver suite; `admission.rs::upstream_controls_unauthorized` | knownAt raised; `R_UNCERTIFIED` | controls authorized |
| 14 | timestamp overflow, malformed rule | C7.6 rule-language suite | `kernel/tests/rules/test_three_implementations.py` | `R_OVERFLOW`, `E_RULE` | in-range rules |
| 15 | holdout through a declaration, binding, alias or derived dependency | L5, stage 1 identity and stage 2 rows over `required` | `admission.rs::holdout_copy_refused`, `holdout_dependency_refused` | `R_HOLDOUT` | the search store |
| 16 | zero-filling, an event held past its tick, a held value expiring wrongly | L7 | `machine.rs::held_and_event_reads` | undefined, never zero | delivered values read as stated |
| 17 | a payload opened before the metadata checks pass | stage 1's type; `mm`'s staging | `admission.rs::superseded_cert_with_unreadable_payload` | `R_UNCERTIFIED`, no read error | a readable payload |
| 18 | non-time columns opened before I8's check | stage 2's type; `mm`'s staging | `admission.rs::holdout_rows_with_unreadable_values` | `R_HOLDOUT`, no read error | values readable |
| 19 | an older correction delivered after the current hour's event row (GPT B7) | L7, version 1's order | `machine.rs::late_correction_undefines_event` | undefined | the current row last |
| 20 | a slot, entity, revision or tombstone column not authorized | `Decl.controls` ⊆ `Cert.controls` (stage 1) | `admission.rs::control_column_unauthorized` | `R_UNCERTIFIED` | controls authorized |
| 21 | an ungranted value read by the initialization tick of an empty window | `useEnd` | `admission.rs::empty_window_initialization` | `R_UNCERTIFIED` | grants covering the first tick |

| 22 | a role provider without a venue-state attestation (GPT R3) | `Cert.venueState` (stage 1) | `admission.rs::provider_without_venue_state` | `R_UNCERTIFIED` | attested provider |
| 23 | a program, registry or policy not validated (GPT R4) | `run` from text, `Registry.valid`, `Policy.valid` | `admission.rs::invalid_inputs` | `R_INVALID` | valid inputs |
| 24 | observations substituted for the bound bytes (GPT R1) | `Trusted.resolve`, `Trusted.identity`; content hashing | `admission.rs::substituted_observations` | `R_UNCERTIFIED` | the bound bytes |

Each test is committed with its expected code before its first judged run (C7 evidence rule).

## 3. Spec and annex changes that go with this (before any proof or baseline capture)

- **SOURCES.md version 2.** §1: the `evidence` cadence; each declaration's availability columns (`fetchedAt`
  included), event-time column (evidence declarations included) and slot column (event sources); fields name their
  stored column; roles map role columns to stored columns. §4: key and slot distinct; every bound source is
  delivered; within a source by (knownAt, coin, event time) for held sources and (knownAt, coin, resolver position)
  for event sources; held reads the latest, event reads the latest
  only if its slot is the current hour; the cross-source interleaving unobservable. §6: role columns non-null and
  finite, the bars key on the 4h grid, providers distinct, checked at run admission (`R_BINDING`, `R_ROLES`); volume
  is not a role column; execution reads role records at event or open time (§1). §7: the three stages of §4; a
  dataset's id is its content identity; grants cover value columns per read; control columns (availability, event,
  slot, entity, revision and tombstone) are authorized per dataset by the certificate's `controls`.
- **CERTIFICATES.md.** §5: a certificate lists the control columns it authorizes for resolution (`controls`); a role
  certificate attests that each record's event time is the venue's application time
  and its value the applied one; grants cover every column a run reads, availability and control columns included,
  and the upstream records a derived observation's knownAt was bounded by; the policy and verifier hashes are
  compiled into the kernel build. Supersession records are admission state, not part of a certificate's payload.
- **INVARIANTS.md.** I8 unchanged; added before it: a search run whose required datasets include a holdout dataset, by
  content identity, is refused (`R_HOLDOUT`). New codes `R_UNCERTIFIED`, `R_BINDING`, `R_ROLES`.
- **SEMANTICS.md.** The latest-observation store and its reads, per-source delivery, the decision's reads from the
  providers' delivered observations, the projections and the staged admission; §8's "core datasets always present"
  deleted.
- **Migration annex §4.** The compared "deliveries" are one stream per source, each delivery with its tick and
  knownAt, in version 1's order (held: knownAt, coin, event time; event: knownAt, coin, array position, the resolver
  position being version 1's array order); the baseline is
  captured in that form. A migrated run binds every dataset version 1 would load, unread event feeds included. The
  annex's grants must cover the accesses of §5 for the baseline runs; if they do not, the access footprint is refined,
  never the evidence widened (GPT N2). Every migrated run's listing intervals equal the fixed baseline loader's
  (`market.rs::load`, a delisted coin ending at its last bar); if they cannot, migration is reported blocked (GPT N7).

## 4. Findings of the last four reviews, their answers, and their effect (CLAUDE.md, rule 3)

Opus review 3 (F, N), Opus review 4 (accepted revision 4; its corrections taken in revision 5), GPT review 1 (B, N):

| Finding | Could change a false-discovery or leakage outcome | Answer |
|---|---|---|
| Opus-3 F1 row check later and narrower than I8 | leakage | stage 2 over every stored row's event time before resolution |
| Opus-3 F2 cross-source order | no | per-source order; superseded by GPT B7's exact order |
| Opus-3 F3, F4 availability columns, stored names | leakage | `Decl.columns`, stored names throughout |
| Opus-3 F5 dependency closure | leakage | one `required`, closed over delivered sources, programs and providers |
| Opus-3 F6, F7 L7 range, hypotheses | no | `i < p.nodes.size`; version 1's domains kept (§7) |
| Opus-3 F8 prose definitions | leakage via `lastTick` | written; the rest becomes Lean before review (N3) |
| Opus-3 N1–N8 | no | taken (InputRef, policy in the build, placements, WF, named tests, erasure) |
| Opus-4 maxKnown's initial value; R_ROLES first; per-position L5 | no | taken |
| GPT B1 preflight order not enforced | leakage | staged `stage1`, `stage2`, `run` with a two-stage `Loader`; tests 17 and 18 |
| GPT B2 certified bytes not linked to observations | leakage | `Loader.Faithful`, the explicit trusted boundary, discharged by content hashing, C7.6 and tests 6, 17, 18 |
| GPT B3 late role observations affect decisions | leakage (if a provider is not venue state) | the execution-role contract: role records are venue state at event time, certified as such (§1, §9) |
| GPT B4 slot and control columns unscoped | leakage | `slotColumn`; `Decl.columns` in every access; test 20 |
| GPT B5 upstream reads unscoped | leakage | upstream control columns authorized by the upstream certificate's `controls`; test 13 |
| GPT B6 empty-window initialization read | leakage | `useEnd`; test 21 |
| GPT B7 event tie order differs from version 1 | false discovery (decisions differ) | version 1's order (event time for held sources, array position for event sources; version 1's own split) and its event read; test 19 |
| GPT N1 positional L5.2 | no | `firstFailure` |
| GPT N2 over-approximated accesses | no (C7.4 risk) | reads from delivery, not `min known key`; annex refines the footprint, never widens evidence |
| GPT N3 incomplete definitions and signatures | no | the next step: compiling Lean with full signatures, reviewed by GPT before any freeze |

| GPT-2 R1 no Lean boundary from certified bytes to observations | leakage | `Trusted` (Source.lean) and `L5_certified`; tests 6, 17, 18, 24 |
| GPT-2 R2 resolver reads outside the footprint (undeliverable rows, tombstones, entity selection) | leakage | value and control columns separated: controls authorized per dataset (`Cert.controls`, stage 1), values per read; run admission reads no value; test 20 |
| GPT-2 R3 execution before knownAt | leakage | the execution clock made explicit: `Cert.venueState` required of providers; L1_decisions the restricted guarantee; test 22 |
| GPT-2 R4 `run` on unvalidated inputs | leakage | `run` takes the text and checks registry, policy and program (`R_INVALID`); valid policy keeps every use interval nonempty; test 23 |
| GPT-2 R5 `L5_shape` false (bars and rates conflated) | false law | `sameShape` compares the role's kind; run admission no longer reads values |
| GPT-2 R6 `L5_text` false without unique names | false law | `reg.Valid` hypothesis |
| GPT-2 R7 the draft's biconditional | no | the Lean's `L5_order` (first failure determines the refusal; none means evaluation) is the statement |
| GPT-2 N4 admission narrower than version 1 | no (C7.4 domain) | run admission reduced to version 1's structural conditions: no finiteness, grid or slot-uniqueness checks |
| GPT-2 N5 over-wide footprint, one grant per access | no (C7.4 risk) | recorded; the annex refines the footprint, never widens evidence |
| GPT-2 N6 cross-source order | no | per-source streams in C7.4 (§3); unobservable to the machine |
| GPT-2 N7 listing intervals | false discovery if they differ | annex requires equality with the baseline loader's intervals, or migration is blocked (§3) |

Recorded limitations, none able to change a false-discovery or leakage outcome: `maxKnown` (a fill's `inputsKnown`)
may reflect a delivered event observation of a pre-window slot, a trace timestamp only; listing intervals from the
venue-rules artifact (above); a held value's use is counted through `useEnd` even after replacement (safe direction).
