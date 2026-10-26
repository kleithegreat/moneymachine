# Fourth Stage 1 exit review

**C1.3: met. C1.4: not met on the documented ordered-trace requirement. C1.6: met.** The remaining trace-order difference has no demonstrated false-discovery or leakage consequence under the stated facts.

These judgments use the supplied sources and recorded clean-commit runs at `aeca1b2`; I did not independently rerun them.

## C1.3 — Met

> “At least 8 hand-computed scenarios match exactly, each with its expected cash, positions, fees, funding, and equity worked out in the test…” — `criteria-stage1.md:22`

There are now eight component-complete scenarios:

| Scenario | Five-component assertion |
|---|---|
| Delayed fill, fees and funding | `fixtures.rs:178` |
| Short receiving funding | `fixtures.rs:195` |
| Zero-trade bar | `fixtures.rs:210` |
| Reversal | `fixtures.rs:228` |
| Liquidation | `fixtures.rs:247` |
| Delisting | `fixtures.rs:285` |
| Minimum notional/rounding | `fixtures.rs:304` |
| Missing-bar funding settlement | `fixtures.rs:320` |

The helper compares cash, position, fees, funding and equity together (`fixtures.rs:151–156`). The new scenario explicitly works out the sale proceeds, fee, negative funding payment and resulting equity (`fixtures.rs:192–194`), then asserts:

> `(15000.005, -50.0, 4.995, -10.0, 10000.005)` — `fixtures.rs:195`

I retain the third review’s acceptance of the `1e-9` comparisons as binary64 roundoff handling, not a new objection to “exactly.”

The clean run records the new scenario passing and **18 passed, zero failed** (`c13-fixtures.txt:1,20,25`).

**Remaining issue:** none.

## C1.4 — Not met

> “its trace (decisions, fills, funding, equity) matches the stage 0 Python witness to $1e-6 at every step. Every disagreement found along the way is resolved with its root cause recorded.” — `criteria-stage1.md:23`

The trace is explicitly defined as an **“ordered list”** (`INVARIANTS.md:4–5`).

The revised comparison closes two important gaps:

- It preserves the sequence of timestamp/type runs, so a funding/fill/equity boundary cannot simply disappear through global sorting (`test_differential.py:38–46,60`).
- It compares both equity and reconciliation values to `1e-6` (`test_differential.py:63–66`), alongside fill, decision and funding values (`:68–81`).

However, within each run it still compares a **set** of coins:

> `out[-1][2].add(e.get("coin", ""))` — `test_differential.py:43`

Thus it does not compare the complete ordered sequence of event identities. Under your stated finding—witness insertion order versus kernel venue order—the ordered lists actually differ, although their grouped economic events agree. This is not a demand for byte-identical trace serialization; it concerns the event sequence specified by the ordered-list definition.

The passing replay establishes that grouped agreement on dataset version `1792613363942` (`c14.txt:1–5`). Historical disagreements and their fixes are recorded in `c14-disagreements.md:8–14`.

**Outcome relevance:** the remaining known difference is outcome-neutral under the supplied facts: distinct-coin events of one type at one instant are merely listed differently, phase boundaries are preserved, and monetary results are checked. It does **not** demonstrate a false-discovery or leakage mechanism. Nevertheless, it does not satisfy literal ordered-trace agreement.

## C1.6 — Met

> “Tests show: triggers reject UPDATE and DELETE; the experiment row holds every identity field in paper §5 plus the I7 hashes; a read-only or failing ledger makes `mm eval` emit no statistics and exit nonzero; and two fresh processes produce byte-identical results.” — `criteria-stage1.md:25`

Retaining the third review’s frozen-identity interpretation (`exit-review-gpt-3.md:163–175`), the evidence now covers all requirements:

- **Identity and hashes:** required fields are populated; rules, execution and executable hashes are independently checked (`test_cli.py:24–25,59–71`).
- **Dataset binding:** `data_hash` independently enumerates eligible files, applies the version cutoff, hashes their bytes and names, and compares the aggregate with the experiment row (`test_cli.py:49–56,71`).
- **Append-only ledger:** UPDATE and DELETE are rejected on populated tables (`test_cli.py:76–85`).
- **Failure isolation:** read-only ledger yields exit code 2, empty stdout, no trace and one `R_LEDGER` diagnostic (`test_cli.py:88–95`).
- **Raw-byte determinism:** both fresh subprocesses use `text=False`, and their captured stdout bytes are compared directly (`test_cli.py:38–46,98–100`).

The clean run records these tests passing (`c16-ledger.txt:1,11–17`), with **24 passed** overall (`:35`).

**Remaining issue:** none.

## Exit conclusion

Carrying forward the five previously accepted criteria, **only C1.4 remains unmet**, specifically its ordered-trace requirement. The supplied evidence does not show that this remaining difference changes an economic, false-discovery or leakage outcome.
