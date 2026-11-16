## Review

The printed-arithmetic reconstruction and daily-row interpretation are reasonable **empirical reconciliations**. They do not establish that the settlements cannot affect study 2’s judged results.

This is a design review of the supplied files and arithmetic, not an independent reproduction of the raw-record counts or a review of the rewritten tests.

### 1. D105 changes a judged input, not merely a diagnostic

**Outcomes potentially changed: CS2.1’s rung crossings and crossing dates; CS2.2’s variance ratio or judged status; CS2.3’s entry matches.**

The argument “no judged run reads `userFunding`” addresses the wrong dependency. Judged runs read **funding payments**, through:

- the replica’s cash, margin, admissions and own-state inputs;
- `confirm`’s cash, subsequent scales and termination;
- the bar’s funding returns and holding bound;
- the guard’s cash and termination.

Replacing oracle price \(O\) with coin price \(P\) changes a long’s payment by
\[
q\rho(O-P).
\]
Nothing makes that difference vanish in these instruments.

A direct CS2.1 construction is sufficient: arrange a day’s coin-price-funded wealth at the bid to be \(20+\epsilon\), with the oracle-funded version paying an additional amount greater than \(\epsilon\). One reports “earned”; the other does not. The comparison is exact, not rounded to a report’s displayed precision. Alternatively, put the confirmer’s cash between the two payment amounts: one version ends immediately and the other continues.

For CS2.2, `held` explicitly distinguishes variance ratios infinitesimally outside its boundary (`4-study-2.md`, step 1, test 5). A small funding perturbation can therefore change its verdict. For CS2.3, changed cash can change order admission, or a trigger reading `equity` or `free_margin`, and thus first fills.

The vault’s 53.03 USDC is the **sum of absolute daily net amounts**, as the supplied script computes it—not necessarily gross absolute hourly funding. Within-day cancellation can make that smaller. Neither it nor the sampled `premium` bounds the replica’s, confirmer’s or guard’s exposure.

**Required:** treat D105 as a result-affecting modelling decision. Consistency between historical and forward runs is defensible; it is not proof of equivalence to oracle funding. Either register and qualify the synthetic funding model explicitly, or specify an oracle-based alternative and its missing-data policy. A diagnostic with no pass mark cannot establish outcome invariance.

### 2. D98’s exact fee can also move judged figures

**Outcomes potentially changed: CS2.1, CS2.2 and, through admissions or account-dependent triggers, CS2.3.**

Even accepting V19’s bound in its stated base-tier/notional domain, “at most one millionth per fill” does not imply “no judged figure changes.”

On an otherwise identical path, choose terminal wealth between the exact-fee and cut-fee results, straddling 20. The rung verdict differs. The same boundary argument applies to CS2.2’s exact variance comparison.

Nor is a whole-run ordering established merely because each exact fee is higher. Different fees can change affordability, positions and later funding. `kernel-v2.md` already rejects analogous whole-run ordering arguments for fills.

There is **no mathematical necessity to abandon exact rational accounting**. It is a coherent idealized model. But conservation does not itself forbid venue fees: an integer cut fee is also an exact rational cash flow. The choice concerns which fee function the model charges.

**Required:** withdraw the outcome-invariance claim and adjudicate this as a modelling choice. Keeping exact fees is acceptable only without claiming that venue-cut fees cannot change the criteria.

### 3. D101’s two ties can hold for a wrong ledger

**Outcomes potentially changed if such defects escape the independent checks: CS2.1 and CS2.2 through fees, positions and cash; CS2.3 through entry-dependent exits or admissions.**

The ties are useful compatibility checks, but neither identifies the exact ledger uniquely.

**Fee counterexample:** charge the printed fee itself. It satisfies
\[
0\leq \text{ledger fee}-\text{printed fee}\leq1
\]
with difference zero, while violating A8 whenever the exact fee differs.

**Cost counterexample:** after a partial close, set the ledger’s remaining cost to the venue’s `E`. Thereafter `c = E` satisfies the permitted interval although it is not the exact remaining cost.

The supplied made-up case demonstrates this:

- correct remaining cost: 3,702 millionths;
- venue `E`: 3,701;
- wrong ledger cost: 3,701.

With `m = 1`, the tie passes. At the final sale at 2,000 units, that wrong ledger realizes 2,299 millionths rather than the correct 2,298; both remain below the printed 2,301. Thus the one-sided `closedPnl` comparison also passes.

These mutants **do not satisfy the complete specification**: the exact-fee test, partial-close characterization and A1 should reject them. The finding is specifically that the venue ties do not independently prove the ledger right.

**Required:** retain those independent checks and explicitly test these mutants. Replace “that the ledger’s cost is the venue’s” with the narrower compatibility claim actually established.

There is a further limit to the inequality: binary64 multiplication can round upward. For
`E = 1,000,000,001`, `p = 1,000,000,000`, closing one lot, the stated double cut leaves `1,000,000,000`, while exact remaining cost is `1,000,000,000 − 1/1,000,000,000`. Hence `E ≤ c` is not a universal consequence of the reconstruction. Its observed validity must not become a general arithmetic guarantee.

### 4. D103’s daily test cannot identify hourly charged positions

**Outcomes potentially changed: CS2.1 and CS2.2 through funding cash and termination; CS2.3 through the replica’s resulting account state.**

For a day, the test essentially constrains the number of held hours, \(\sum q_h\), and \(\sum q_h\rho_h\). Those aggregates do not identify the hourly sequence.

Concrete example:

| Hour | Rate | Correct size | Wrong charged size |
|---|---:|---:|---:|
| 1 | 0.0001 | 3 | 4 |
| 2 | 0.0002 | 3 | 1 |
| 3 | 0.0003 | 3 | 4 |

Both give:

- three samples;
- mean size 3;
- weighted mean rate 0.0002;
- total payment 0.0018 at the test’s price of 1.

Every daily assertion passes. At coin prices 100, 200, 100, however, the payments total **0.24 versus 0.20**. Intermediate cash failures can differ even when final cash totals agree.

Two hours with equal rates also allow their sizes to trade places undetected.

Therefore the daily rows witness aggregate compatibility, not every hour, charged size or ordering. The independent U1 law and event-level synthetic tests remain essential.

Also, `venue_funding` reconstructs positions **at the hour**, whereas the new replay test uses the settlement’s **actual stamp**. They need not agree when a fill lies between those times. O14 correctly identifies this missing case; the existing counts do not settle it.

**Required:** narrow V21’s witness claim, preserve event-level assertions, and add the aggregate-collision and late-stamp constructions.

### 5. The new cash-measurement test admits a constant predictor

**Outcome potentially changed: the reported V8 discrepancy and the claim’s stated fidelity evidence; no criterion changes directly because this measurement judges nothing. This is a note, not an independent verdict blocker.**

In `4-study-2.md`, step 4, test 5, both cases use the same sizes, prices, rates and settlement count. Only venue `usdc` changes.

A broken predictor that always returns a model payment of 0.06, then subtracts the supplied venue amount, passes both cases. Add cases changing size, rate, price and count independently, plus no holdings, zero rate and an empty trace.

The larger suite does contain meaningful positive cases: an engine that never fills or a confirmer that never confirms cannot pass it. The daily funding test also rejects an empty ledger **provided it iterates the independently supplied venue rows**, rather than deriving its entire test domain from emitted payments.

## Other settlements

- **D96–D97 and D100:** acceptable as reconstructed rules fitting the historical record, with the stated long-only scope. Selecting an operation order among alternatives is model selection even without fitted numeric parameters; correctly reserving unseen fills for prediction matters.
- **D104:** measuring rather than inventing unavailable historical oracle cash is honest. A daily discrepancy is not a bound on hourly errors or other instruments’ errors.
- **D106:** daily overlapping collection is coherent for a non-judging witness. One row finalized within 15 days does not establish universal finalization within 30; retain the explicit “not witnessed” outcome.
- **D99/O11:** nothing supplied shows a direct reader of venue `closedPnl` in the criteria. Keep its cash interpretation conditional until certified; reconstruction alone does not establish it.

## Verdict

**not accepted** — blocked by the unsupported claim that funding-price and fee choices cannot affect judged results, and by treating non-identifying ledger and daily-funding checks as stronger witnesses than they are. Exact accounting and daily reconciliation may remain, but their modelling consequences, witness limits and adversarial tests must be settled explicitly.
