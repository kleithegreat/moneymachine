Fresh-context Opus review of stage 7 slice 1 laws, revision 3 (GPT unavailable)

I read laws-v2-draft.md (revision 3), both earlier reviews, and version 1's Spec.lean, Laws.lean, Sim.lean, Machine.lean, Syntax.lean and SEMANTICS.md. I also read sim.rs `run`, machine.rs `deliver_*` and market.rs `resolve`/`known`/`load`, plus SOURCES.md, CERTIFICATES.md, RULES.md §6, INVARIANTS.md, migration-annex.md and the Stage 7 criteria. I edited nothing.

**Verdict: freezing is blocked by eight defects (F1–F8).** The overall shape is right: role payloads on observations, one delivered store read two ways, preflight before evaluate, and `valid` and `matches` written out. But the claim that this reproduces version 1's delivery order is still false, one law is false as stated, and the holdout row check is now weaker than version 1's.

## Blocking defects, most important first

### F1. The holdout row check is later and narrower than version 1's I8
- **Leakage:** yes. **Blocks freezing:** yes.
- **(a) Too late.** Version 1 refuses holdout rows first, at load. In `market.rs::resolve`, each raw row's eventTime is tested before the coin lookup, the tombstone filter, revision selection and the knownAt rule.
  - Revision 3 runs resolution (and, by its admissibility table, the `R_BINDING` payload checks) before the row check.
  - Consider a dataset whose content id is not a holdout id but which spans the holdout period. A search run's refusal code (`R_INVALID_DATASET`, `R_OVERFLOW`, `R_BINDING`, or `R_HOLDOUT`) then reveals properties of holdout-period rows. An agent can repeat this, one bit per run.
- **(b) Too narrow.** `authorizedRows` checks only the resolved observations of delivered sources (`c.obs`). Version 1, and I8 as frozen ("any row … whatever file it came from … Check at load, on every row"), check every row read. That includes non-selected revisions, tombstones, rows of coins outside U, and here also the dependency and evidence datasets the resolver opens.
- **(c) The paired spec change narrows I8.** §8's I8 row ("whose resolved rows have eventTime ≥ …") narrows the frozen text. Under L5.2's ↔, an implementation keeping version 1's stricter check would become non-conforming, which is B1 again.
- **Change:**
  - Order: unbound → (`R_ROLES`) → holdout by identity → holdout by row → resolution → admissibility rejections (`R_BINDING`) → certificates → evaluate.
  - Holdout by row reads only the time column, over every stored row with fetchedAt ≤ V of every dataset the run opens: all revisions, tombstones and unmapped coins.
  - In the model, give `Admission` a field `rows : List (Nat × Int)` holding (source, eventTime) of every stored row read, and define `authorizedRows := mode == .holdout || a.rows.all (·.2 < a.holdoutStart)`.
  - Keep I8's wording unchanged.
  - Evidence declarations have no eventTime, so SOURCES §1 must name the time column I8 uses for them.

### F2. "Within a tick this is version 1's order" is still false
- **False-discovery or leakage:** no. **Blocks freezing:** yes, because it puts C7.4's byte-identity at risk, and §9 marks N1 as resolved.
- **What version 1 does.** `sim.rs` sorts both event feeds together by `(known, coin, slot, i)`, so forum and governance rows interleave by coin. Revision 3 delivers each source in turn, in registry order. Both feeds deliver at the same tick for many coins every hour, so the sequences differ routinely. This is exactly N1(b).
- **`tickOf` is undefined.** If it means "the next hourly tick", warm-up observations (known before wStart + δ) are ordered by their own pre-window hours. That interleaves funding and bars, whereas version 1 delivers all funding, then all bars, at the first tick.
- **The machine state does not depend on cross-source order.** Stores are per source, `maxKnown` is a max, and the causality check is per observation. SOURCES §4 already says "the interleaving of sources is unobservable". Within one source, version 1's tie-break index `i` follows `resolve`'s (coin, eventTime) sort, so per-source order is (known, coin, key) in both versions.
- **Change:**
  - Order `oOrder` by `(known, source, coin, key)` and delete `rank` and `tickOf`. (`rank` also clashes with `Ref.rank`.)
  - Define C7.4's "deliveries" artifact as one stream per source, in (known, coin, key) order, each delivery with its tick. Fix this in the annex before the baseline is captured.
  - Delete the version 1 claims in §1 and §4, and §8's "delivery per tick in registry order".
  - If the baseline was already captured as one interleaved stream, record a Blocker. Do not emulate version 1's event merge.
- **D2 parity.** Revision 3's out-of-order event fix cannot diverge from version 1 under version 1's rules. An earlier-hour row can never be delivered after the current hour's row in the same tick, because event knownAt is eventTime + δ, raised only by fetchedAt. One sentence in the draft should say so.

### F3. Columns the availability rule reads are missing from `accesses`
- **Leakage:** yes. **Blocks freezing:** yes.
- CERTIFICATES §5 puts "availability inputs" in scope. §3 permits a claimed time (e.g. `reportedTime`) only within the entities, columns and event-time interval where it is certified. The resolver reads those columns at run time for every observation.
- The draft calls them "certified at issuance, not run-time accesses". So a run can use rows whose claimed-time basis is outside the grant, giving knownAt values from an uncertified basis, i.e. look-ahead. Field grants catch this only if the verifier happens to restrict them identically, and nothing requires that.
- **Change:** add `times : List String` to `Decl` (the rule's stored time columns; fetchedAt excluded). For each observation, add accesses `⟨o.coin, col, o.key, (start (min o.known o.key), c.stop)⟩` for those columns. The alternative is to amend CERTIFICATES §5 so that a field or role column is granted only over rows whose availability inputs are certified; that would have to be listed in §8 as a change.

### F4. Access columns and grant columns use different names
- **False-discovery or leakage:** no, provided both sides are consistent. **Blocks freezing:** yes; L5.3 would be vacuous or would contradict the implementation.
- `Grant.column` is "one stored column" (CERTIFICATES §5). `Access.column` is an input name (`funding`) or a role-column name (`rate`, `open`).
- In the migrated registry `funding` and `rate` are both the stored column `fundingRate`. No verifier-issued grant would ever cover a model access.
- **Change:** `Decl.fields : Array (String × String × Dim)` (input name, stored column, unit), and `Decl.roles` maps each role column to its stored column. `accesses` then emits stored columns.

### F5. The set to be certified is not closed under dependencies
- **Leakage:** yes, by I8's "never materializes" standard; no statistical effect on what strategies read. **Blocks freezing:** yes.
- `certSet = deliveredSet ++ needed`, but the closure runs only over `needed`. Take a bound derived source the program does not read: it is delivered and certified, but its dependencies are not required to be bound, matched or checked by identity.
- The resolver still reads those upstream datasets to compute the delivered rows' knownAt, which feeds `maxKnown` and so each fill's `inputsKnown`. Only the opaque `a.lineage` guards them against the holdout.
- **Change:** one set, `required := reg.closure n (deliveredSet ++ p.sources ++ [roles.bars, roles.settlement])`, used by `bound`, `authorizedIds` and `certified`. This deletes `needed` versus `certSet`. Each upstream dataset is then checked by identity and pinned by `matches` (upstream ids, then the manifest). `Admission.lineage` becomes redundant and can be deleted, or must be stated as the transitive closure.

### F6. L7 is false as stated
- **False-discovery or leakage:** no. **Blocks freezing:** yes.
- `Node` derives `Inhabited` with first constructor `.input`, so `p.nodes[i]! = .input default` holds for every i ≥ size. There `ms.vals[i]!` is `#[]`, which gives `none`, while the right side can be `some`.
- **Change:** add the hypothesis `i < p.nodes.size`.

### F7. L5 and L6 gain hypotheses that version 1 did not have
- **False-discovery or leakage:** no. **Blocks freezing:** yes; C7.7 says "a weaker statement does not count".
- §6 puts `CheckerAccepted`, `roles.Valid` and `a.Admissible` on every law. Version 1's `L6_bounded` has none, and `L5_binding` has no admissibility hypothesis.
- Both still hold without them: preflight is a pure function, and `evaluate` raises none of the three refusal codes.
- **Change:** state L6 with only `N.Bounded`, and L5 without `Admissible` or `roles.Valid`.

### F8. Definitions the laws depend on are still prose
- **Blocks freezing:** yes. **Leakage:** yes via `lastTick`, see below.
- §9 marks B5 as resolved, but these are still prose:
  - `lastTick`, `tickOf` and the `oOrder` comparator;
  - `Admissible`, which is only a table;
  - `Ctx.make`, `evaluate`, `start`, `deliver` and `MState.deliver`, and `MState.init`'s store sizes;
  - step 9's freshness and price;
  - `Ctx.bars`, `Ctx.rates` and the index;
  - `barAt` and `latestClosed` restated.
- **`lastTick` affects safety.** "Number of ticks before stop" is ambiguous. An undercount would drop field reads from `accesses`, letting uncertified data through. It must be `pol.wStart + (c.bounds.length : Int) * BAR + pol.delta`, the schedule's actual last tick.
- **Change:** write each of these in Lean before freezing.

## Should fix before freezing (none changes a false-discovery or leakage outcome unless stated)

- **N1. L5.6's "occurs anywhere in text" is false read literally.** Mechanism strings and names can contain input names. Define `InputRef v name` inductively on the parsed JSON: `{"input": name}` under weight, a let body or the prediction. It is provable, since `program` interns every let.
- **N2. Where do `a.policy` and `a.verifier` come from?** If they are read from the same mutable `sources/policy.json`, a changed policy matches itself and attack 3 passes. Pin them to the criteria-frozen hash: the kernel build or the run identity, never the file under test. Leakage: yes for attack 3, though only an operator can trigger it.
- **N3. Admissibility enforcement, placement and parity.** Rejections like `R_BINDING` have no place in the refusal order (see F1); place each there.
  - "Binding validation" cannot check clauses that depend on the run's roles (role payload present only for providers, the 4h grid), because a binding knows nothing of the run's roles. Those belong to run admission.
  - `o.coin < intervals.size` must mean that rows of coins outside U are excluded at admission, as version 1 does. Rejecting them would refuse every stage 0 run, while F1 still I8-checks those rows.
- **N4. `accesses` over-approximates, which puts C7.4 at risk; this is the safe direction.**
  - Role reads are listed for every admitted observation.
  - Field reads cover all pre-window history.
  - The annex grants only "W's event-time interval", so baseline runs would get `R_UNCERTIFIED`.
  - Fix, either way:
    - restrict accesses to readable observations:
      - held: delivered at a tick ≥ wStart + δ, or the latest per (source, coin) at that first tick;
      - event: slot in [wStart, lastTick − δ];
      - rates: key in (wStart, stop];
      - bars: the latest opened by wStart + 1h, and every later bar;
      - and drop any access whose use interval is empty;
    - or make the annex grant the whole admitted record.
- **N5. Order of certificate checks.** SOURCES §7 currently checks certificates "before any observation is loaded". Revision 3 moves all of `R_UNCERTIFIED` after resolution. C7.2 allows this, since it only says "before delivery or evaluation", but it relaxes the spec. Split the check:
  - `valid` and `matches` are payload-free, so run them right after holdout by identity;
  - grant scope needs knownAt, so run it after resolution;
  - restate L5's clauses for that order.
- **N6. Duplicate certificate ids.** `a.cert` uses `find?`. Add `(a.certs.map (·.id)).Nodup` to admissibility, or define the id as the hash of the payload.
- **N7. The attack table names laws where C7.7 asks for implementation tests.** C7.7 requires "named tests … reached at the check they target". Rows 3, 5, 8, 9, 15 and 16, and row 6's `matches` part, cite only a law. Add the `mm` test name beside each law, and move row 15's row check before resolution (F1). The table is otherwise right: the expected codes and positive controls fit. Row 16 is correctly L7 plus preflight, because held values never expire and a use-interval expiry is `R_UNCERTIFIED`.
- **N8. Erasure.**
  - `Admission.manifest` is the identity once `DatasetId` is the manifest hash; compare `k.manifest == b.dataset` instead.
  - `Obs.dataset` is fixed by `source` (one binding per source) and no law uses it.
  - `k.id == b.cert` in `matches` repeats the lookup.
  - The `k.rule` check is implied by `k.decl`, because the rule bytes are inside the declaration file. Keep the pin and drop the check.
  - With F2 and F5 adopted, also delete `rank`, `tickOf` and `lineage`.

## Answers to the five questions

**1. Laws.**
- L7 is false (F6). L5.6 is ill-defined (N1).
- L5 and L6 are weakened by their new hypotheses (F7). L5.2 encodes a weaker I8 (F1). L5.3 is vacuous against real grants (F4) and misses availability inputs (F3).
- L1–L4 look true and provable on `evaluate`. Any fixed total order works for L1.
- L3's "equal as sets" is enough for preflight, because every check uses `.all`.
- L5.0–L5.5 are provable once `evaluate` never raises the three refusal codes.

**2. Definitions.**
- Correct and consistent: `closure`, `Registry.Valid`, `Roles.Valid`, `Grant.covers`, `valid` (fuel = certificate count suffices; a cycle is invalid), `MState.input`, `barRow`, `rateRow`, `deliveryPrefix` and `execView`.
- Defective or incomplete: `certSet` (F5), `accesses` (F3, F4, N4), `authorizedRows` (F1), `lastTick`/`tickOf`/`oOrder` (F2, F8), and `Admissible` with the rest of F8's list.
- Freshness and price reproduce version 1: the provider's latest delivered key equals B, and the decision prices at the bar's close.

**3. Delivery.**
- The delivered set matches version 1 if a run's bindings mirror the store's datasets, including unread event feeds. The annex should state that rule.
- Per-source order and definedness match version 1.
- The cross-source order does not (F2), and `tickOf` is undefined. Under F2 both disappear.

**4. L5.** The headline and the refusal non-interference clause (L5.5) are right. The order needs F1 (rows before resolution, over all rows), N5's split, F5's single required set, and the `R_BINDING` and `R_ROLES` placement (N3). The table is right apart from N7.

**5. §8's spec changes.**
- Weakenings:
  - the INVARIANTS I8 row and the SOURCES §7 order (F1);
  - availability inputs silently dropped from the CERTIFICATES §5 scope (F3);
  - certificates checked after loading, relative to SOURCES §7's text (N5).
- Unnecessary, and contradicting SOURCES §4: "registry order per tick" (F2).
- Not a change: "grants are per column" is already §5's wording.
- Acceptable: content identity, the evidence cadence, key and slot, the non-null role columns, the providers being distinct, and deleting SEMANTICS §8's "core datasets".

## The §9 table: does each answer resolve its finding?

| Status | Findings | What remains |
|---|---|---|
| Resolved | D1, D2, D6, D7, D9/N3, D10, N4, N6, N10 | D9/N3 needs F6's bound; D10 needs N3's placement |
| Not resolved | D5/N1 | F2 |
| | B5 | F8 |
| | D11/B1/B2 | F1: the row check is later and narrower than version 1's |
| Partly resolved | D3/B3 | N2, N8 |
| | D4/N2 | F5 |
| | D8 | `evaluate` not written |
| | B4 | F3, F4 |
| | N5 | N1 |
| | N7 | N2 |
| | N8 | N3 |
| | N9 | fields only; roles remain (N4) |

No criterion needs redefining.

Files reviewed:
- /home/kevin/repos/moneymachine-stage7/audit/stage7/laws-v2-draft.md
- /home/kevin/repos/moneymachine-stage7/kernel/mm/src/sim.rs (lines 241–316)
- /home/kevin/repos/moneymachine-stage7/kernel/mm/src/market.rs (`resolve`, line ~252)
- /home/kevin/repos/moneymachine-stage7/reference/lean/Ref/Syntax.lean (`Node`, line 104)
- /home/kevin/repos/moneymachine-stage7/audit/stage7/migration-annex.md (§3 grants, §4 comparison)
