# Stage 7 law statements, frozen 2026-10-26 23:30 UTC (19:30 EDT)

Human decision of 2026-10-26 (`audit/decisions.md` on main): freeze the law statements after the bitemporal revision.
C7.7 requires each revised law to be reviewed and frozen before its proof. The statements are `reference/lean/Ref/Laws.lean`, over the definitions in the files below, at commit `f35748b6ea8032b6fa27c4c87aab23cf4eee9e08`. From here a statement or a definition it uses changes only by a dated revision in this file, before any proof that depends on it is judged.

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `32fc75d75f6b91413ef9c5f1ddb70bca18f275be3ef97196051d9e738f36d183` |
| `reference/lean/Ref/Resolve.lean` | `fdfe8ca4ea8ad98fc1082e51e0a1a8cff74f16af6eabdf905eaa6083fd66642d` |
| `reference/lean/Ref/Syntax.lean` | `fdc1c9f22336749f26d55a90f3d45c9aab51440f3d74e877196a5f416cd2f243` |
| `reference/lean/Ref/Machine.lean` | `a466142cc5d8e4e05657027d77da33f7a05abb128ba58b00ba7e676bc636735c` |
| `reference/lean/Ref/Sim.lean` | `4ea816a2623a2ee5ffb0aef05629b2e63c0c7e0c1a36b243d154f28d1ae34d64` |
| `reference/lean/Ref/Units.lean` | `d45c5906dc9c638892bbd002cc47eefb69ca2da25f45c3d057a36b19e07f5d54` |
| `reference/lean/Ref/Spec.lean` | `9094d3e65aae38d3a028c562833649bc6aee76acb4ed7da320039cef8500dfdc` |
| `reference/lean/Ref/Laws.lean` | `55ddbf7a198e28fbb0902b662fa75e1c91a214120e105b28eb1931d383d4652d` |
| `kernel/RULES.md` | `6492c17f9a1f338a5e1c43a6abb74afdc230660c4fa2256cded4ec8f29fa15f7` |

Reviews before the freeze: four fresh-context Opus reviews and six GPT reviews (`laws-review-*.md`), their findings and answers in `laws-v2-draft.md` §4. Queued: GPT's review of the bitemporal resolver (revision 12), whose findings become dated revisions here.

## Revision 2026-10-26 23:39 UTC (19:39 EDT), from GPT's review of the bitemporal resolver (`laws-review-gpt-7.md`), before any proof

GPT found no false statement, and seven paths by which later records still changed earlier inputs or admission. Six
are fixed (RULES.md §6, second revision): upstream deliveries counted only if recorded no later than the derived
revision; slots decoded per revision; an undecodable slot or role payload a retraction, so a later revision never
refuses an earlier run; differences judged on declared columns; delivery ties by recording time, never stored order;
validity on both key identities; a role payload allowed on every role-capable declaration, execution reading only
the run's providers; execution-time reads scoped on final revisions only; retraction times range-checked. The
seventh, execution on final revisions, is the stated venue-state exception. Changed statements: `L8_monotone` and
`L8_known` take the timeline's decoding predicate, and `L8_known` bounds a value by the upstream deliveries recorded
no later than it. Changed definitions: `Obs` (its recording time), `Obs.sameShape`, `timeline`, `resolveAll`,
`differs`, `Stored.validAt`, `Ctx.make` (ties), `Ctx.admissible`, `Ctx.readFrom`. Hashes after this revision:

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `210cb1b039c7c9b544227ff8df0616b53050fb22ebb6ec4eb7d1107e45bd9d52` |
| `reference/lean/Ref/Resolve.lean` | `07104b445f3ed46eb02bb18e26b1d8187abae019ea915df1dd1a45a733f81b69` |
| `reference/lean/Ref/Syntax.lean` | `fdc1c9f22336749f26d55a90f3d45c9aab51440f3d74e877196a5f416cd2f243` |
| `reference/lean/Ref/Machine.lean` | `a466142cc5d8e4e05657027d77da33f7a05abb128ba58b00ba7e676bc636735c` |
| `reference/lean/Ref/Sim.lean` | `055aca68a972fad54d36a653961d605bd9eb3e27eb32fee68a7424abf61015b6` |
| `reference/lean/Ref/Units.lean` | `d45c5906dc9c638892bbd002cc47eefb69ca2da25f45c3d057a36b19e07f5d54` |
| `reference/lean/Ref/Spec.lean` | `9094d3e65aae38d3a028c562833649bc6aee76acb4ed7da320039cef8500dfdc` |
| `reference/lean/Ref/Laws.lean` | `ed3a941f92c094978b3fc03ce2adf6aeb831fe6f328e3a4a158b1f1e445f8e43` |
| `kernel/RULES.md` | `a8432f37f7f81fcc135046ec9f8cea74d2f3aff025cd99a039e5366128fba636` |

## Revision 2026-10-26 23:43 UTC (19:43 EDT), from GPT's eighth review (`laws-review-gpt-8.md`), before any proof

Three findings: an out-of-range retraction time was replaced by a visible one, making `L8_known` false (now an
eligible revision with an out-of-range fetchedAt invalidates the dataset, and retractions take no fallback); a key's
first successful revision after failed ones was backdated (now every revision after the key's first eligible one is
known no earlier than its fetchedAt); execution-time scope was assigned to role-capable records of declarations that
are not the run's providers (now only the providers' final records). Statements unchanged; changed definitions:
`Stored.validAt`, `timeline`, `Ctx.readFrom`. Hashes after this revision:

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `210cb1b039c7c9b544227ff8df0616b53050fb22ebb6ec4eb7d1107e45bd9d52` |
| `reference/lean/Ref/Resolve.lean` | `0c19d78695b5d4afc7c9f58215fff7391faac92ed6653bd41b7398c384ec93cb` |
| `reference/lean/Ref/Syntax.lean` | `fdc1c9f22336749f26d55a90f3d45c9aab51440f3d74e877196a5f416cd2f243` |
| `reference/lean/Ref/Machine.lean` | `a466142cc5d8e4e05657027d77da33f7a05abb128ba58b00ba7e676bc636735c` |
| `reference/lean/Ref/Sim.lean` | `2de32c9575b413d6f9d121ac256ffda6f480a0ea6afa1c4a165d9417eebaff23` |
| `reference/lean/Ref/Units.lean` | `d45c5906dc9c638892bbd002cc47eefb69ca2da25f45c3d057a36b19e07f5d54` |
| `reference/lean/Ref/Spec.lean` | `9094d3e65aae38d3a028c562833649bc6aee76acb4ed7da320039cef8500dfdc` |
| `reference/lean/Ref/Laws.lean` | `ed3a941f92c094978b3fc03ce2adf6aeb831fe6f328e3a4a158b1f1e445f8e43` |
| `kernel/RULES.md` | `3ad64611a208fd3225234cbd88593aab16c3f599f276402807b3f9318be728d2` |

## Revision 2026-10-27 01:43 UTC (21:43 EDT): I5 scaled by peak equity (human decision of 2026-10-27, `audit/decisions.md` on main)

`accountingOk` takes the largest |equity| reached at an earlier step (`SState.peak`) and its tolerance is 1e-9 of
max(10,000, |equity|, peak), as `mm`'s (`kernel/INVARIANTS.md`, I5's revision). Changed statement: `NumOps.Bounded`'s
`acc_finite` quantifies over the peak too; its content (a passing check implies finite equity) is unchanged. Main's
version 1 Lean, stage 6's frozen artifact, keeps the earlier I5 and differs from `mm` only on runs that I5's earlier
form aborted. Hashes after this revision:

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `210cb1b039c7c9b544227ff8df0616b53050fb22ebb6ec4eb7d1107e45bd9d52` |
| `reference/lean/Ref/Resolve.lean` | `0c19d78695b5d4afc7c9f58215fff7391faac92ed6653bd41b7398c384ec93cb` |
| `reference/lean/Ref/Syntax.lean` | `fdc1c9f22336749f26d55a90f3d45c9aab51440f3d74e877196a5f416cd2f243` |
| `reference/lean/Ref/Machine.lean` | `a466142cc5d8e4e05657027d77da33f7a05abb128ba58b00ba7e676bc636735c` |
| `reference/lean/Ref/Sim.lean` | `6274e84456526f6ff671a9e181b1c6d5181caf3093822083a31508930b56b3e6` |
| `reference/lean/Ref/Units.lean` | `d45c5906dc9c638892bbd002cc47eefb69ca2da25f45c3d057a36b19e07f5d54` |
| `reference/lean/Ref/Spec.lean` | `178d804d1b70b4cecbf259cee9d9332fcd4c761076f2a86f3cffb318cd542951` |
| `reference/lean/Ref/Laws.lean` | `ed3a941f92c094978b3fc03ce2adf6aeb831fe6f328e3a4a158b1f1e445f8e43` |

## Revision 2026-10-27 14:57 UTC (10:57 EDT): `Program.WF`'s input clause regrouped (content unchanged)

The input clause's four registry conditions are named `InputOK reg inp` and conjoined with the type condition, so
the checker's per-node invariant matches the definition; the conditions themselves are unchanged. `L2_checker` is
proved (`Proof/Checker.lean`, ported: the invariant carries the input table's well-formedness). Hashes after this
revision:

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `210cb1b039c7c9b544227ff8df0616b53050fb22ebb6ec4eb7d1107e45bd9d52` |
| `reference/lean/Ref/Resolve.lean` | `0c19d78695b5d4afc7c9f58215fff7391faac92ed6653bd41b7398c384ec93cb` |
| `reference/lean/Ref/Syntax.lean` | `fdc1c9f22336749f26d55a90f3d45c9aab51440f3d74e877196a5f416cd2f243` |
| `reference/lean/Ref/Machine.lean` | `a466142cc5d8e4e05657027d77da33f7a05abb128ba58b00ba7e676bc636735c` |
| `reference/lean/Ref/Sim.lean` | `6274e84456526f6ff671a9e181b1c6d5181caf3093822083a31508930b56b3e6` |
| `reference/lean/Ref/Units.lean` | `d45c5906dc9c638892bbd002cc47eefb69ca2da25f45c3d057a36b19e07f5d54` |
| `reference/lean/Ref/Spec.lean` | `82cc1ae557735aba6790b489d0b41042ca529e311fd0e98769fe6892aa6096de` |
| `reference/lean/Ref/Laws.lean` | `276ac1f06f6cd15ece2889a80f04fc9829fee3caba9d53e997941f59e538ac6c` |

## Revision 2026-10-27 15:07 UTC (11:07 EDT): one admission, with positions (equivalent; statements unchanged)

`firstFailure` restated the admission checks of `run` one by one, a second copy of the same logic. Now `admit`
returns each refusal with its position (`Abort.position` for the metadata stage, whose codes are distinct within it),
`admission` adds position 0, and `run`, `runProgram` and `firstFailure` are all defined from them; the order, codes
and positions are those of the previous definitions. No law statement changes. Proved since: `L2_checker`,
`L5_admitted`, `L5_order`, `L5_staged` (`Proof/Checker.lean`, `Proof/Admission.lean`). Hashes after this revision:

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `210cb1b039c7c9b544227ff8df0616b53050fb22ebb6ec4eb7d1107e45bd9d52` |
| `reference/lean/Ref/Resolve.lean` | `0c19d78695b5d4afc7c9f58215fff7391faac92ed6653bd41b7398c384ec93cb` |
| `reference/lean/Ref/Syntax.lean` | `fdc1c9f22336749f26d55a90f3d45c9aab51440f3d74e877196a5f416cd2f243` |
| `reference/lean/Ref/Machine.lean` | `a466142cc5d8e4e05657027d77da33f7a05abb128ba58b00ba7e676bc636735c` |
| `reference/lean/Ref/Sim.lean` | `d64a1a10c291f8d9168e46ed67bee1f376831ec6e0e10b1bef063e718f3fbc35` |
| `reference/lean/Ref/Units.lean` | `d45c5906dc9c638892bbd002cc47eefb69ca2da25f45c3d057a36b19e07f5d54` |
| `reference/lean/Ref/Spec.lean` | `45a00da2e54bbaf4aa266dc9fa2a8cc78c24232e6bd715fd1e921ce4a212b34c` |
| `reference/lean/Ref/Laws.lean` | `b9272a12a0c2da161f17d9bfa76f71083306722f2da3a8f5e468c36fae9f3406` |

## Revision 2026-10-31 02:50 UTC (22:50 EDT 2026-10-30): `L5_text` made provable at full strength; statements unchanged

The law's statement and `InputRef`'s text are unchanged. Two gaps stopped any proof (`l5-text-blocker.md`; both reviews
of 2026-10-30, `audit/reviews/2026-10-30-{opus,gpt}-agent-real-l5-text.md` on main). `mentions` was `partial`, so opaque.
And the checker's duplicate-key refusal sat inside the opaque parser, so a proof had to cover a parsed value with two
`weight`s, where `program` compiles the first and `mentions` sees both. Changed definitions:

- `Json.Value.mentions` (`Spec.lean`): total, the same traversal, over `attach` with a termination proof.
- `Json.value` (`Json.lean`): no longer refuses duplicate keys.
- `Json.Value.uniqueKeys` (`Syntax.lean`, new): total, no object at any depth repeats a key.
- `check` (`Syntax.lean`): refuses a parsed value failing `uniqueKeys` with `.parse`, before `program`. `refmm`'s market
  files apply the same guard (`Main.lean`), so the rule has one home.

Why this cannot weaken the guarantee:

- `Value` has only finite terms, so the total `mentions` computes the partial one's function by the same equations, and
  only `InputRef` calls it. `required` and admission do not read it.
- `check` is the same function of the text. Every failure of the old parser was `.parse`, and now a duplicate gives
  `.parse` from the guard or, if a later syntax error comes first, from the parser. Without duplicates the parser
  returns the same value. The size check still comes first.
- `InputRef` now holds of some text with duplicates, where it was `False`. `check` refuses that text, and the law
  assumes `check` accepted, so no accepted program's obligations change.
- None of the routes the reviews rejected is taken: no no-duplicates hypothesis, no axiom, `InputRef` not defined from
  the compiled program, and unused lets, inactive branches and prediction conditions still count.

Evidence, run in scratch (not an audit artifact, regenerable): stage7's `Json.lean` and `Syntax.lean` against these on
1,291 texts (`kernel/tests/{adversarial,admitted}`, `kernel/strategies`, `audit/stage6/differential-corpus.jsonl`) and
7,746 mutants of them with a duplicate key inserted at a random object, some followed by a syntax error or trailing text:
identical verdicts on all 9,037. `mm check` agrees with the revised Lean on all 9,037. `refmm` does not build at this
commit (`Main.lean` predates stage 7's definitions), so the guard in `Main.lean` is uncompiled and C6.4's harness did
not run. The corpus held duplicate keys already (`gpt27`, `gpt28`). A new case in a compiled-away position, a duplicate
inside an unused let, is a build-time check in `Proof/Text.lean`: a new `kernel/tests/adversarial` file would make stage
6's frozen corpus report it missing under `differential.complete` on any rerun. `mm` gives it `E_PARSE` too.

C7.7's independent review of this revision is queued for GPT, and any proof depending on it is not judged before then.
`Json.lean` joins the table, since `check` and `InputRef` both depend on it. `Laws.lean` differs from the last table
only by the proofs committed since. Hashes after this revision:

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `210cb1b039c7c9b544227ff8df0616b53050fb22ebb6ec4eb7d1107e45bd9d52` |
| `reference/lean/Ref/Resolve.lean` | `0c19d78695b5d4afc7c9f58215fff7391faac92ed6653bd41b7398c384ec93cb` |
| `reference/lean/Ref/Json.lean` | `3d166ad3e3b4a842bcb7f1c14353f34d057d50a61ee551fc78a47d55b33b4677` |
| `reference/lean/Ref/Syntax.lean` | `fc2a095308ad30a8393f1453393130a94d5c875c0a1f2b266b06ab074dff1777` |
| `reference/lean/Ref/Machine.lean` | `a466142cc5d8e4e05657027d77da33f7a05abb128ba58b00ba7e676bc636735c` |
| `reference/lean/Ref/Sim.lean` | `d64a1a10c291f8d9168e46ed67bee1f376831ec6e0e10b1bef063e718f3fbc35` |
| `reference/lean/Ref/Units.lean` | `d45c5906dc9c638892bbd002cc47eefb69ca2da25f45c3d057a36b19e07f5d54` |
| `reference/lean/Ref/Spec.lean` | `0cbbf08f623c32ee30ee4abb917a749bffbbb675d7bde09b5b231a5a0ef7b6f6` |
| `reference/lean/Ref/Laws.lean` | `c89ffc74da495c9f94de4a820e109c34b98637b974dc497d663eb6b0085b8797` |

### L5_text revision: independent review and freeze (2026-10-31 06:10 UTC (02:10 EDT))

Independently reviewed by GPT (`audit/stage7/l5-text-review-gpt-2026-10-31.md`), verdict FREEZE: the revision does not
weaken L5_text, and `check`'s returned verdicts and codes are unchanged. Frozen at this time and merged into `stage7`
(`stage7-l5` kept). Hashes of the changed definition files as they stand after the merge, unchanged from the table
above except `Laws.lean`, which carries the L5_text proof:

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Json.lean` | `3d166ad3e3b4a842bcb7f1c14353f34d057d50a61ee551fc78a47d55b33b4677` |
| `reference/lean/Ref/Syntax.lean` | `fc2a095308ad30a8393f1453393130a94d5c875c0a1f2b266b06ab074dff1777` |
| `reference/lean/Ref/Spec.lean` | `0cbbf08f623c32ee30ee4abb917a749bffbbb675d7bde09b5b231a5a0ef7b6f6` |
| `reference/lean/Ref/Laws.lean` | `e3f38840330472c5728462fe61e55c2f4233bdec0eea081dba15d01fbb581d42` |

The proof is re-checked after this freeze in `proof-validation-2026-10-31.md`; that re-check is what counts.

## 06:44 UTC (02:44 EDT) 2026-10-31: `kernel/RULES.md`'s recorded hash, caught up

`09ba199` (2026-10-26, with GPT's ninth review, `laws-review-gpt-9.md`) changed only prose in RULES.md §6: it states two
effects as by design (a key's first revision known at its rule's value; admission refusing a whole run). No law statement
or Lean definition changed, and every proof's validation since used the current file. The table above was not updated
then; this records the file as it stands:

| File | SHA-256 |
|---|---|
| `kernel/RULES.md` | `0f2fee31c078e0d36874ee40651edfa072b81d9241be218ae7e93e53f8342379` |

## 2026-11-02 00:55 UTC (2026-11-01 19:55 EST): B2's revision frozen

Advisor decision (`audit/decisions.md` on main, same time), reviewed under C7.7 in two rounds: the draft by GPT and a fresh Opus (`b2-revision-review-{gpt,claude}.md`, both: do not freeze yet; the blockers ruled on 2026-11-01 20:30 UTC (15:30 EST)), then the fixes' diff by GPT and a fresh Opus (`b2-fixes-review-{gpt,claude}.md`, both: FREEZE). A dependency spans several sources; every changed definition and statement, and every law whose closure changed (all 18), is listed in `b2-revision.md`. Only `L8_known` and `L8_monotone` changed statement. After the fixes' review only comments and prose changed: `Resolve.lean`'s `Entry` docstring, RULES.md's line wrap and this revision's heading, SOURCES.md's stale Preflight clause (`b2-fixes-review-claude.md`, F-3). `Json`, `Syntax`, `Machine`, `Sim`, `Units` and `Spec` are unchanged from the latest tables above. Hashes:

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `c52d9c66653ee08bb383a780fba41c94ee5a292f4a61587f8af5908e4fcdb4bb` |
| `reference/lean/Ref/Resolve.lean` | `726dace325f5a69a1ca4f77a3d6cf14640cf3e31854fadd3af54bb5a127d51b3` |
| `reference/lean/Ref/Laws.lean` | `80d1f575f7ee82005cccb1a00a62752a7353ed982a4b923c58105cedc1ea2551` |
| `kernel/RULES.md` | `ce84948585ec79956bf6b65c00048967973b95ecd41a188d7948e941e3507ec4` |

The proofs are re-checked after this freeze in `proof-validation-b2.md`; that re-check is what counts.

## Revision 2026-11-04 07:00 UTC (02:00 EST): a declaration provides at most one role, under its contract (stage 7 hunt, findings 1 and 2); statements unchanged

`audit/reviews/2026-11-04-claude-hunt-stage7.md` finding 1: `rolePayload` decodes only a declaration's first role, so a
declaration offering both roles and selected for its second was admitted with no execution data. A run selects distinct
providers (`Roles.valid`), so such a declaration could only ever serve one role per run; the payload's single role is
made the registry's rule instead of resolution reading the run's selection. Finding 2 and its review
(`audit/reviews/2026-11-04-gpt-hunt-fixes-review.md`): nothing held a provider to its role's contract. Changed
definitions: `Role.columns` states each role column's unit (SOURCES.md §6), and `Registry.valid`'s role clause, inside
its existing `all`, requires at most one role, its columns `Role.columns`'s, a bars provider held, and every field
reading a role column's stored column in that column's unit; no proof's destructuring moves (`lake build`: 109 jobs, no
`sorry`), and of five `example`s by `decide +kernel` under it, three fail on the previous clause and two are positive controls holding under both. `rolePayload`'s docstring now
says "its declaration's role". `mm` refuses the same when parsing (`source.rs`), as SOURCES.md §1 and §6 state, and also
a bars provider off the 4h grid of eventTime (period 14,400,000, phase 0, slot `eventTime`): that grid stays `mm`'s
alone, Lean's `Decl` having no period and no held slot. No committed declaration breaks either, so no recorded result
moves. The admission differential (`refmm`'s harness now decodes each declaration's fields; the generator keeps
both-role declarations, event-cadence bars providers and fields reading a role column in another unit, refused on both
sides at position 0, and puts every held bars provider on the grid), 5,000 cases on each of seeds 1, 2 and 3: no
disagreement; refused at position 0 in 942, 930 and 969 cases, admitted to resolution in 524, 484 and 469. Against the
previous `Registry.valid`, seed 1 disagrees in 485 cases. Statements unchanged means their text: every law assuming `Registry.Valid` now has a stronger hypothesis, through
`CheckerAccepted` (`L1_values`, `L1_simulator`, `L1_decisions`, `L2_units`, `L2_checker`, `L4_fills`, `L4_orders`) or
directly (`L5_text`, `L8_known`); `L5_admitted` concludes it, so its conclusion is stronger; `L5_order`, `L5_staged`
and `L5_shape` go through `admission`'s `reg.valid` test. No coverage is lost: each new conjunct is implied by `mm`'s
parser, so every registry `mm` admits satisfies it, and the registries excluded are ones neither side admits. Reviewed
under C7.7 by GPT (`audit/reviews/2026-11-04-gpt-hunt-fixes-review-2.md`) and a fresh Claude
(`audit/reviews/2026-11-04-claude-hunt-fixes-review.md`); these laws' proofs are re-checked after this freeze. Hashes:

| File | SHA-256 |
|---|---|
| `reference/lean/Ref/Source.lean` | `dc248cb35fde360fcfe5376908126f164141a0b5d0317434c5cfa39dbabc3c1b` |
| `reference/lean/Ref/Resolve.lean` | `aac4935799921efa9e95bfa7786028d5d7a887ec2b914cb358d6f94bd7e70aea` |

## 2026-11-06 20:50:51 UTC (15:50:51 EST): B3's resolver specification frozen

C7.6's revision was committed alone before this specification and the suite. RULES.md §6 restates the resolver whole,
§7 defines its cases and comparisons, and SOURCES.md §2 defines Parquet as cells. No Lean statement, definition or proof
changes in this freeze. GPT reviewed round 9 (`b3-round9-review-gpt.md`); fresh Claude (Opus 5.5 through the
Antigravity CLI) reviewed round 10 (`b3-round10-review-claude.md`). Gemini 4 Argon's round 8 calibration
(`b3-round8-calibration-argon.md`) halted the first freeze; round 11 answered it. Argon's review at this freeze
(`b3-round11-review-argon.md`) left wording only, now answered under the human's fix-and-freeze rule, without another
round. Production-loader comparisons and structural holdout review remain slice 5's obligations, not evidence claimed
by this freeze. RULES.md's hash after this revision:

| File | SHA-256 |
|---|---|
| `kernel/RULES.md` | `1385c1a5c05074cd8d4336007ee154be6eea20339ab29916e47fd0a7691d2143` |
