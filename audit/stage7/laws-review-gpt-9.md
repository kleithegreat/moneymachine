## Verdict

1. **All three items from `laws-review-gpt-8.md` are closed by the Lean as written.**
2. **I found no concrete counterexample to the current law statements.** In particular, the previous `L8_known` counterexample is repaired.
3. **The unrestricted future-record assurance is still false.** Two paths remain beyond venue-state reads and dataset validity.

## Blocking items

### 1. A new key’s first revision can still change an earlier decision

The fetchedAt bound is conditional on `later` (`v2-Resolve.lean:106`). With no previous eligible revision, `last.isSome` is false (`:114–116`), so the first revision can be delivered before it was fetched.

Concrete counterexample:

- A valid, bound, **non-role event source**, with rule `field "t"` and a dimensionless input field `x`.
- Let `H = BAR`, `delta = 1`, query/decision time `T = H + 1`, and dataset cutoff `V = H + 2`.
- Initially, the source has no record for this key.
- Add its first revision: `fetchedAt = H + 2`, `t = H`, slot `H`, and `x = 1`.
- Keep venue records unchanged, and provide all required grants.

The new revision is delivered at **H**, although fetched after **T**. At the decision tick, the input changes from undefined to `1` (`v2-Machine.lean:134–137`); a program using that input as its weight can change from an undefined hold to an order.

This is permitted first-revision backdating, not the repaired first-successful-revision bug. It contradicts `RULES.md:185–187`’s unrestricted assurance. **Either that assurance needs an explicit initial-backfill exception, or first revisions need a recording-time bound.** The current conditional laws do not establish that assurance.

### 2. Future in-run deliveries can still refuse the entire historical run through scope

The provider check fixes the reported invented execution read. However, value-scope admission remains whole-run, independently of dataset validity.

Concrete counterexample:

- Start with an admitted run and a bound non-provider source having no observations.
- Its certificate authorizes all controls but has no value grant for event `E`.
- After an earlier decision time `T`, add a valid first record for `E`, fetched at `F`, using rule `field "fetchedAt"`, with  
  `T < F ≤ lastTick`.
- Keep certificates otherwise valid and matching the updated dataset.

Its knownAt is **F**, so it does **not** enter the earlier delivery prefix. Nevertheless, `readFrom` includes its later delivery (`v2-Sim.lean:455`), `accesses` requires value grants (`:468–471`), and admission rejects the **entire run** with `R_UNCERTIFIED` (`:485–486`).

Thus an earlier decision disappears through future **scope admission**, without a venue-state change or invalid dataset. This does not mutate the earlier machine input; it changes whether any historical output is returned. Exempting it requires explicitly allowing global scope/admission checks, not merely global dataset validity.

## Everything else — short list

- **Old item 1 closed:** `validAt` rejects eligible out-of-range fetchedAt values; retractions use `max fetchedAt prev`, without timestamp substitution (`v2-Resolve.lean:55–59,118–121`).
- **Old item 2 closed:** failed/skipped revisions still establish `last`; subsequent successful revisions receive the fetchedAt bound (`:111–117`).
- **Old item 3 closed:** execution scope now requires both `final` and the selected role provider (`v2-Sim.lean:456–459`).
- **Laws:** no concrete false statement identified; their conditional hypotheses do not imply recording-time prefix invariance.
- **Limits:** static review only; Lean was not executed. No files edited.
