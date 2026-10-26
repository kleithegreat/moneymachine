## Verdict

**Not all six findings are closed. `L8_known` is false as written, and non-venue future-information paths remain.**

## Blocking items

### 1. Retraction overflow falsifies `L8_known` and can retract before recording

At `v2-Resolve.lean:113–115`, a failed range check does not reject the timestamp: it emits a retraction at `max (2^62 − 1) prev`.

Concrete counterexample:

- One valid, dependency-free held declaration, with checked rule `field "t"`.
- Original revision: `fetchedAt = 0`, `t = 0`, not a tombstone.
- Later tombstone of the same key: `fetchedAt = F = 2^62`.
- Dataset version `V = F`.

The timeline is:

```text
original:   recorded 0, known 0
tombstone:  recorded F, known F − 1
```

Consequently, `L8_known`’s index-1 requirement (`v2-Laws.lean:247`) asserts **`F ≤ F − 1`**.

Neither `reg.Valid`, `Stored.validAt`, nor `Trusted.canonical` requires fetchedAt to be in range. This counterexample therefore meets the statement’s hypotheses.

It also supplies a non-venue temporal leak: at query time `F − 1`, adding the tombstone recorded at `F` removes the original value. The claimed retraction range check is actually a substitution of a visible timestamp.

### 2. Finding 2: slot fidelity is repaired, but future repair can still change past inputs

Per-revision slot decoding fixes timeline-wide slot borrowing and ignored slot corrections. However, the future-repair effect survives when no revision has yet delivered successfully.

Use an event declaration with rule `field "t"`:

| Revision | fetchedAt | `t` | Slot |
|---|---:|---:|---|
| Original | 0 | 0 | Missing |
| Repair | F | 0 | H |

The original fails `decodes` and is discarded without establishing `prev` (`v2-Resolve.lean:116–120`). The repair differs in its declared slot column, but still enters `known r none`; **the fetchedAt lower bound applies only when `prev` is present** (`:105–108`).

Thus the repair is delivered at **0**, not F. At a tick for hour H before F, the event input changes from undefined to the repaired value. The analogous first successful role-payload repair can change historical freshness.

This is first-*successful*-delivery backdating, not retroactive metadata borrowing. It is consistent with the retained “first delivered revision” rule, but contradicts `RULES.md:170–184`’s unrestricted assurance that only venue-state records can change earlier decisions.

### 3. Finding 5: future non-provider role records can still refuse an earlier run

`Ctx.readFrom` now checks `o.final`, but **does not check that the observation belongs to the run’s selected role provider** (`v2-Sim.lean:454–459`). Actual execution does check the provider (`:189–196`).

Counterexample:

1. Bind an additional held declaration capable of providing bars, but select another declaration as `roles.bars`.
2. Initially, the additional declaration has no observation for historical event E; the run passes.
3. Add a decodable bar record for E, fetched at F after `lastTick`, using rule `field "fetchedAt"`. Its knownAt is F, so it is never delivered during the run.
4. Give its certificate the required controls, but no value grant covering E.

The new record passes `roleOk` because the declaration is role-capable. Execution ignores it because it is not the bars provider. Nevertheless, `readFrom` invents an execution read at `E − BAR`; `accesses` then requires grants, and admission returns **`R_UNCERTIFIED`** (`:468–486`).

An unread, later-recorded **non-provider** record therefore changes historical output/admission. This is not the stated venue-state exception.

## Everything else — short list

- **Finding 1: closed** for the reported dependency-max path: upstream deliveries are filtered by the derived revision’s recording time.
- **Finding 2: partial**, as detailed above; each revision now carries its own slot.
- **Finding 3: closed** on valid resolver output: recording/event tie keys distinguish deliveries; stored position cannot decide the reported tie.
- **Finding 5: partial**, as detailed above; malformed role payloads now become timed retractions rather than structural admission failures.
- **Finding 6: closed** for undeclared-column comparison: `differs` uses declared value/control columns.
- **Finding 7: closed**: validity checks both entity/event and coin/event fetchedAt ties.
- **Other laws:** no additional concrete counterexample identified. Their conditional statements do not establish recorded-time prefix invariance; `deliveryPrefix` still includes mutable `final` flags.
- **Venue-state exception:** retained as stated. Whole-dataset validity and holdout checks also remain global admission conditions.
- **Review limits:** static review only; Lean was not executed. No files edited.
