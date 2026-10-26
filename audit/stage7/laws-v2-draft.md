# Stage 7, slice 1: the reference semantics generalized over declarations, and the laws restated (revision 12, frozen)

C7.7 requires the Lean semantics to be parameterized by validated declarations and bindings; every stage 6 law to keep
its guarantee for every admitted declaration, held and event cadences included; each law whose definitions change to
be revised, independently reviewed and frozen before its proof; and a binding law under which evaluation is undefined
whenever a required source lacks a valid, matching, in-scope certificate.

**The definitions and law statements are the Lean on branch `stage7`:** `reference/lean/Ref/Source.lean`
(declarations with their rules, observations, certificates, admission metadata, the loader, stored revisions and the
payload-free stages), `Resolve.lean` (RULES.md §5–§6: rule evaluation, selection, effective knownAt, `resolveAll`,
and the trusted boundary `Trusted`), `Machine.lean` (the latest observation per source and coin, its reads), `Sim.lean` (delivery,
execution's role projections, run admission, accesses and scope, `admit`, `runProgram`, `run`), `Spec.lean`
(`Program.WF`, prefixes, views, `firstFailure`, `InputRef`) and `Laws.lean` (L1–L8, proofs `sorry`
until the statements are frozen). This document keeps the design, the attacks, the spec changes and the review
ledger; it does not restate the Lean.

Reviews: four fresh-context Opus reviews while GPT was unavailable (`laws-review-opus-1.md` to `-4.md`) and GPT's
four (`laws-review-gpt-1.md` on revision 5, `-2.md` to `-4.md` on revisions 6 to 8's Lean). §4 records every
finding of the last six, its answer, and whether it could change a false-discovery or leakage outcome
(CLAUDE.md, rule 3).

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
- **Resolution is RULES.md §6 with its bitemporal revision, in Lean** (human decision of 2026-10-26). Each key's
  eligible revisions are delivered in fetchedAt order at their own effective knownAt (`timeline`): a correction no
  earlier than its fetchedAt and than the revision it replaces, every value no earlier than its dependencies'
  upstream knownAt plus delay (L8_monotone, L8_known); a tombstone or rejected revision is a retraction, with no
  fallback. Decisions see, at each tick, the latest revision known by then; execution reads each key's final revision
  as venue state (`Obs.final`). A key with one revision resolves as in version 1 (C7.4's identity is limited to such
  keys). An invalid dataset refuses the run (`R_BINDING`); an unchecked rule or a dependency cycle is an invalid
  registry (`R_INVALID`).
- **The trusted boundary is a Lean structure, and small.** `Trusted` says the loader's inventory is the stored
  revisions' event times and its resolution is `resolveAll` on the stored bytes at the pinned version; bindings name
  the bytes' content identities; certificates are issued, their ids their payloads' hashes; supersessions and the
  admission position are the ledger's current ones; policy, verifier and holdout are the pinned configuration.
  L5_certified states what an admitted run guarantees under it. `mm` discharges it by content hashing, by agreeing
  with the Lean resolver on the C7.6 suites (with the Python and Rust ones), by the ledger's append-only triggers, and
  by the staging tests (§2, rows 17 and 18). A provider's venue-state attestation is the verifier's claim,
  authenticated as issued.
- **What grants authorize.** Grants authorize the use of values in a run: every value of an observation the run
  reads, from its first read, at its (entity, column, event time), which covers every revision of that key.
  Resolution decodes a bound dataset's rows under its valid, matching certificate (the kernel-only boundary's
  deterministic processing); revisions are ordered by fetchedAt, and the only comparison of values is whether a
  revision differs from the one before it, which decides only whether it is delivered and, being a correction, no
  earlier than its fetchedAt.

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
  only if its slot is the current hour; the cross-source interleaving unobservable. §6: providers distinct and a role
  payload exactly on their records, checked at run admission (`R_BINDING`, `R_ROLES`); volume is not a role column;
  execution reads role records at event or open time (§1). §7: the three stages of §4; a
  dataset's id is its content identity; grants cover value columns per read; control columns (availability, event,
  slot, entity, revision and tombstone) are authorized per dataset by the certificate's `controls`.
- **CERTIFICATES.md.** §5: a certificate lists the control columns it authorizes for resolution (`controls`); a role
  certificate attests that each record's event time is the venue's application time
  and its value the applied one (`venueState`); grants cover the value columns a run uses; the policy and verifier
  hashes are compiled into the kernel build. Supersession records are admission state, not part of a certificate's payload.
- **INVARIANTS.md.** I8 unchanged; added before it: a search run whose required datasets include a holdout dataset, by
  content identity, is refused (`R_HOLDOUT`). New codes `R_UNCERTIFIED`, `R_BINDING`, `R_ROLES`, `R_INVALID`.
- **SEMANTICS.md.** The latest-observation store and its reads, per-source delivery, the decision's reads from the
  providers' delivered observations, the projections and the staged admission; its §8's "core datasets always present"
  deleted.
- **Migration annex §4.** The compared "deliveries" are one stream per source, each delivery with its tick and
  knownAt, in version 1's order (held: knownAt, coin, event time; event: knownAt, coin, array position, the resolver
  position being version 1's array order); the baseline is
  captured in that form. A migrated run binds every dataset version 1 would load, unread event feeds included. The
  annex's grants must cover the run's accesses (`Ctx.accesses`) for the baseline runs; if they do not, the access footprint is refined,
  never the evidence widened (GPT N2). Every migrated run's listing intervals equal the fixed baseline loader's
  (`market.rs::load`, a delisted coin ending at its last bar); if they cannot, migration is reported blocked (GPT N7).

## 4. Findings of the last four reviews, their answers, and their effect (CLAUDE.md, rule 3)

Opus review 3 (F, N), Opus review 4 (accepted revision 4; its corrections taken in revision 5), GPT review 1 (B, N):

| Finding | Could change a false-discovery or leakage outcome | Answer |
|---|---|---|
| Opus-3 F1 row check later and narrower than I8 | leakage | stage 2 over every stored row's event time before resolution |
| Opus-3 F2 cross-source order | no | per-source order; superseded by GPT B7's exact order |
| Opus-3 F3, F4 availability columns, stored names | leakage | control columns (`Decl.controls`, authorized by `Cert.controls`), stored names throughout |
| Opus-3 F5 dependency closure | leakage | one `required`, closed over delivered sources, programs and providers |
| Opus-3 F6, F7 L7 range, hypotheses | no | `i < p.nodes.size`; version 1's domains kept (§7) |
| Opus-3 F8 prose definitions | leakage via `lastTick` | written; the rest becomes Lean before review (N3) |
| Opus-3 N1–N8 | no | taken (InputRef, policy in the build, placements, WF, named tests, erasure) |
| Opus-4 maxKnown's initial value; R_ROLES first; per-position L5 | no | taken |
| GPT B1 preflight order not enforced | leakage | staged `stage1`, `stage2`, `run` with a two-stage `Loader`; tests 17 and 18 |
| GPT B2 certified bytes not linked to observations | leakage | `Trusted` (superseding the prose `Loader.Faithful`), discharged by content hashing, C7.6 and tests 6, 17, 18 |
| GPT B3 late role observations affect decisions | leakage (if a provider is not venue state) | the execution-role contract: role records are venue state at event time, certified as such (§1, §9) |
| GPT B4 slot and control columns unscoped | leakage | `slotColumn` among `Decl.controls`, authorized by `Cert.controls`; test 20 |
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

| GPT-3 B1 resolver obligations unstated | leakage | `Trusted.confined` (reads only requested datasets) and `Trusted.provenance` (row, entity, values, role cells, RULES.md §6 knownAt) |
| GPT-3 B2 admission position and policy unauthenticated | leakage | `Trusted.position` (the ledger's current position) and `Trusted.pinned`; `L5_certified` concludes them |
| GPT-3 B3 decoded payloads without access | leakage (GPT-4: a resolver selecting by an ungranted value changes outputs) | first `Trusted.controlsOnly`; now the concrete resolver (GPT-5 rows) |
| GPT-3 L6 narrower than version 1 | no | `L6_bounded` for every evaluation, and for every run |
| GPT-3 documentary inconsistencies | no | fixed (§1, §3, this table) |

| GPT-4 provenance leaves role payloads and slots unbound | leakage | `Trusted.provenance` binds every role component (trade count included) and the slot to their stored cells |
| GPT-4 B3 argument fails (selection by ungranted values) | leakage | as GPT-3 B3 above |
| GPT-4: B2 closed, L6 restored, no false law | — | — |

| GPT-5 selection among revisions by an ungranted value | leakage | the abstract resolver replaced by RULES.md §6 in Lean (`Resolve.lean`): selection by fetchedAt and tombstone per key (L8_selection); `Trusted.controlsOnly` and `provenance` deleted, `Trusted.resolve` is equality with `resolveAll` |
| GPT-5 selection by a control available later | leakage | per-key resolution; knownAt never before the revisions and upstream records it consults (L8_known) |

| GPT-6 duplicate dependency names; `L8_known` false | false law, leakage | dependency names unique (`Decl.ruleOk`); times bound by position |
| GPT-6 later tombstones, corrections and unused-column corrections change earlier decisions | leakage | RULES.md §6's snapshot semantics, shared by version 1: a blocker with bitemporal resolution proposed for the human (PROGRESS.md); the statements are not frozen until it is decided |
| GPT-6 key order from revisions beyond the version | leakage (event tie order) | keys from eligible revisions only |
| GPT-6 unchecked rules read unauthorized columns | leakage | RULES.md §4 checker in `Registry.valid` (types, declared fields and dependencies, constants, floor periods, max arity, lower-bound set) |
| GPT-6 `fetchedAt` shadowing, reserved columns in corrections, number equality | leakage (delay) | recorder time first in the row; reserved and revision columns excluded; numbers compared as values; `Trusted.canonical` |
| GPT-6 invalidity only for keys inside U | no (invalid datasets accepted) | checked over every entity |
| GPT-6 correction bound's range | no | the fetchedAt bound range-checked on its own |
| GPT-6 rule bytes not authenticated | leakage | `Trusted.decls` (declarations, rules included, are the ones their hashes name) |
| GPT-6 R_ROW and JSON-level checks | no | outside the model: canonical decoding is a `Trusted` premise, the JSON layer the C7.6 suite's |
| GPT-6 partial lineage, diagnostics, multi-role | no | RULES.md's existential "no usable upstream knownAt" kept; recorded |

| GPT-6 snapshot look-ahead (human decision, 2026-10-26) | leakage | bitemporal resolution: RULES.md §6 revised, `timeline` and `resolveAll` in Lean, C7.6 and C7.4 revised; the pilot keeps snapshot semantics as a qualification |

| GPT-7 derived availability from later upstream corrections | leakage | upstream deliveries counted only if recorded no later than the derived revision; `L8_known` revised |
| GPT-7 slots taken from any revision | leakage | slots decoded per revision; a retraction keeps the slot it retracts |
| GPT-7 event ties by stored order | leakage | ties by recording time and event time, never stored order |
| GPT-7 execution on final revisions | — (the stated venue-state exception) | stated precisely in RULES.md §6: later evidence of applied venue state may change historical accounting and later sizes; nothing else later changes a decision |
| GPT-7 a future undecodable revision refuses an earlier run | false discovery (selection by refusal) | undecodable slot or role payload is a timed retraction; execution-time scope only on final revisions |
| GPT-7 correction test on undeclared columns | leakage | differences judged on declared columns only |
| GPT-7 validity versus grouping identity | no (invalid datasets accepted) | validity checked on both identities |

| GPT-8 retraction overflow fallback (`L8_known` false) | false law, leakage | out-of-range fetchedAt invalidates the dataset; no fallback |
| GPT-8 first successful revision backdated | leakage | every revision after the key's first eligible one known no earlier than its fetchedAt |
| GPT-8 execution scope on non-provider role records | false discovery (refusal) | execution reads, and scope, only the providers' final records |

| GPT-9: all three closed, no false law; a key's first revision known before its fetch; global admission refusing a run | no (certified backfill; refusal returns no output) | stated in RULES.md §6 as by design |

**Frozen** (human decision of 2026-10-26) at the commit recorded in `audit/stage7/laws-frozen.md`. The bitemporal
resolver is reviewed by GPT after the freeze; a finding becomes a dated revision before any proof is judged.

Recorded limitations, none able to change a false-discovery or leakage outcome: a provider's venue-state attestation
is the verifier's claim; `maxKnown` (a fill's `inputsKnown`)
may reflect a delivered event observation of a pre-window slot, a trace timestamp only; listing intervals from the
venue-rules artifact (above); a held value's use is counted through `useEnd` even after replacement (safe direction).
