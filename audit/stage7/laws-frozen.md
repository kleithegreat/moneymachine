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
