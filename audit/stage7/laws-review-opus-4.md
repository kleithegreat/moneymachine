Fresh-context Opus review of stage 7 slice 1 laws, revision 4 (GPT unavailable; final review under CLAUDE.md rule 3)

**Verdict: ACCEPT.** I found nothing that could change a false-discovery or leakage outcome. Everything below is non-blocking and can be recorded as known limitations. I edited nothing.

I read `audit/stage7/laws-v2-draft.md` (revision 4) and `laws-review-opus-3.md`. Against them I checked version 1's `reference/lean/Ref/{Sim,Machine,Spec,Laws}.lean`, `kernel/mm/src/market.rs` (`resolve`, `load`), `kernel/{SOURCES,CERTIFICATES,RULES,INVARIANTS}.md`, `audit/stage7/migration-annex.md` and C7.4–C7.7 in `audit/criteria.md`. The worktree was `/home/kevin/repos/moneymachine-stage7`.

## 1. Review 3's leakage findings
- **F1, closed.** `Admission.rows` holds (source, event time) for every stored row of every opened dataset: every revision, tombstone and coin, dependencies included. It is checked after the payload-free checks and before resolution, so no resolver or `R_BINDING` code can depend on rows from the holdout period. This is at least as strict as version 1's `resolve`, which tests eventTime before the coin lookup. I8's wording is kept, and the identity refusal is an addition.
- **F3, closed.** `Decl.times` is now in `accesses` for every observation whose fields can be read.
- **F5, closed.** There is one `required` set: the closure over delivered sources, program sources and role providers. `bound`, `authorizedIds`, `certsMatch` and `inScope` all use it, and `matches` pins the upstream certificates.
- **F8, closed for the leakage part.** `lastTick = wStart + len(bounds)·BAR + δ` is the schedule's real last tick: the last bound b gives b + 4·HOUR + δ. With `pol.Valid` (0 < δ < HOUR), `lastTick < stop`.
- **N2, closed.** The policy and verifier hashes are compiled into the pinned build.

## 2. Do `readable` and `accesses` under-approximate what evaluation reads?
No read that reaches a decision, fill, mark, settlement or return is missing.
- **Held inputs.** The only value a tick can read is the head of the per-(source, coin) store, the maximum by (known, key). An observation known before `firstTick` that is not that maximum is never a head at any tick at or after `firstTick`.
- **Event inputs.** Reads happen exactly at hours wStart … lastTick − δ, and need known ≤ lastTick.
- **Execution reads.** Bars are read at open time b+BAR < stop and through `latestOf`/`latestClosed` (key − BAR < stop). Rates are read at h ≤ stop − BAR. The decision reads the latest delivered provider observation, which is readable, so its time columns are covered too.
- **Use intervals.** Every read time is within [max(min(known, key), firstTick), stop).

There is one technical gap, listed as non-blocking item 1 below.

## 3. Preflight order
The checks run as: bindings → registry → dataset identities → certificates, supersessions and hashes → the time column of every stored row → resolver → admissibility → scope. None reads a payload before the payload-free checks pass. L5.4 states that independence.

## 4. L1 and L7 on held and event cadences
- **L1.** The machine depends only on the per-source delivered stores, so equal delivery prefixes give equal machines. The decision's freshness and price read only the delivered store; closeouts and fills read only `execView`. So L1_values and L1_decisions keep version 1's guarantees for both cadences.
- **L7.** It is exact: a held input reads the last delivered observation, and an event input reads the delivered observation for that hour, otherwise none. That covers "never zero", "nothing survives its tick" and "known later is never defined".
- **Parity with version 1's single event row.** The draft's claim holds: known_H = H + δ forces any later-delivered row to have a larger key.

## Non-blocking (record as known limitations)
1. **`maxKnown` reads observations no grant covers.** It takes the knownAt of every delivered observation, and that value is recorded as a fill's `inputsKnown`. That includes event observations that are delivered but never readable, such as a late pre-window event with slot < wStart whose knownAt falls inside the window. Those observations' time columns have no access, so no grant covers them.
   - **Effect:** only that one trace timestamp. `inputsKnown ≤ decided` always holds, and returns and decisions are unaffected. Holdout rows are already refused by the row check.
   - **Fix, if wanted:** emit `d.times` accesses for every observation with known ≤ lastTick, which adds C7.4 grant needs. Otherwise record it as a limitation.
2. **`MState.init` sets `maxKnown := 0`; version 1 uses −2^63.** With negative timestamps (which C7.6 tests), every ordinary fill would abort with `R_TIMING`. Restore version 1's value.
3. **`bound` runs before `roles.Valid`.** An out-of-range role index then gives `R_INPUT_UNAVAILABLE` rather than `R_ROLES`, and `required` reads a default `Decl`. Swap the two checks, or state the behaviour.
4. **Some definitions are still prose.** `Ctx.admissible` is still `...` with its clauses in prose. `Index.of` and `start`/`step`/`evaluate` are given only by reference to version 1. They need to be in Lean before the proofs.
5. **§9 leaves out three spec changes.**
   - CERTIFICATES §5's "mapping and coverage facts" and SOURCES §7's "transitive dependencies, mapping and coverage inputs" no longer count as run-time accesses; they are certified at issuance and pinned by content identity. This is sound, because derived knownAt is fixed by the pinned upstream bytes and rule, but it should be listed.
   - SOURCES §7's "before any payload is opened" needs an exception for I8's time-column row check.
6. **Event slot column not accessed.** An event source's slot column C is not in `accesses`, nor is the event-time column of rows read only for their keys. This is harmless because knownAt bounds every read.
7. **Listing intervals differ from version 1.** Version 1 derives a delisted coin's interval end from its last traded bar (`market.rs::load`), not from the venue-rules artifact alone. The annex must reconcile this for C7.4's byte identity. Version 1's look-ahead on delisting is unchanged and is already noted as a limitation.
8. **C7.4 risk from over-approximation (safe direction, review 3's N4).**
   - Role accesses cover every bar and rate in the dataset before stop.
   - Held values carried into the run keep pre-window keys.
   - The annex grants only "W's event-time interval", so baseline runs could hit `R_UNCERTIFIED`. Either widen the annex grants or bound the role accesses (bars: the latest opened by wStart + 1h and every later bar; rates: key in (wStart, stop]).
9. **Empty schedule.** If stop ≤ firstTick, every access is dropped, yet `start` still ticks once. Nothing reaches the returns. Node streams would, if emitted. A marginal case.
10. **L5.2 needs a per-position statement.** `.holdout` and `.uncertified` each occur at two positions in the order, so L5.2's "↔" should be stated per check position, not per code.
