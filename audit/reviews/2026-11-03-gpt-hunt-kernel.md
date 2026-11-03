<!-- GPT (openai/gpt-6.1-sol#high), hunt of the frozen kernel for defects reaching returns, the loss bound or isolation; queued for 2026-11-03 08:27 UTC (03:27 EST), finished by 09:06 UTC (04:06 EST). Static review of 3187aa8; kernel/ is unchanged on main since. -->
# Findings

**The delisting path contains a return-changing lookahead.** I also found exposure-control and sizing defects that change portfolio P&L. I found no new counterexample to the numerical −1 loss bound or bypass of holdout-file isolation.

Static review only: no edits, execution, or data access. These are constructed cases, not claims about recorded campaigns. Earlier hunt findings are excluded.

Examples below use this valid wrapper, with the specified weight expression:

```json
{"dsl":1,"name":"hunt","mechanism":{"counterparty":"-","predictions":[],"capacity":"-"},"weight":WEIGHT}
```

Unless stated otherwise: prices are $100, funding and costs are zero, size decimals are 3, maintenance leverage is 10, observations arrive normally, and the simulation extends beyond the illustrated steps.

## 1. Future trading activity determines today’s allocation

**Paths:** `kernel/mm/src/market.rs:419–427`; `kernel/mm/src/sim.rs:433–451,456–467`.

For a delisted coin, the loader derives its stopping time from its **last traded bar across the loaded history**. The simulator then excludes its weight **eight hours before that stopping time**, before normalizing the other coins’ weights.

That stopping time is neither an observation delivered through the causal machine nor accompanied by an availability time. Future trading activity therefore changes an earlier decision.

**Program:** constant weight:

```json
{"const":2,"unit":"1"}
```

**Concrete market:**

- Two coins, X and Y. X has `delisted = true`.
- Both histories have identical observations available through 08:02.
- In history A, X’s last traded bar ends at 12:00.
- In history B, X continues trading through 20:00.
- Both accounts buy 100 X and 100 Y at 08:00, from their 04:02 decisions.

At **08:02**:

| | History A | History B |
|---|---:|---:|
| X passes `B + 2*BAR <= stop` | No | Yes |
| Y’s normalized target weight | 2 | 1 |
| Additional Y order | Buy 100 | None |

The extra Y order fills at 12:00. If Y then closes at $110 at 16:00, equity is **$12,000 versus $11,000**. The extra $1,000 comes from knowing X’s future cessation of trading—not from any information available at the decision.

**Why checks miss it:** `inputs_known` tracks delivered observations, not the retrospective listing interval. Fill timing and accounting both pass.

- **Likelihood:** conditional on a delisted coin approaching its last traded bar; no adversarial DSL is needed.
- **Reaches:** **portfolio returns and causal isolation**. This is not an I8 file-access bypass, but it violates the paper §6 non-interference target.
- **Reversal criterion:** **met**. This is distinct from the acknowledged snapshot-revision qualification.

## 2. A pending zero-weight close can reopen the position after liquidation

**Paths:** `kernel/mm/src/sim.rs:344–348,365–370,394–413,459–467`.

Liquidation closes the position, but outstanding signed-quantity orders remain executable. A flattening order has no reduce-only semantics and is not canceled or reduced after liquidation.

**Program:**

```json
{"op":"if","args":[
  {"op":"lt","args":[{"input":"premium"},{"const":0,"unit":"1"}]},
  {"const":-0.5,"unit":"1"},
  {"const":0,"unit":"1"}
]}
```

**Concrete market:**

1. Negative premium at 04:00 and 08:00 produces a short of 50 coins, entered at 08:00. Cash is $15,000.
2. Positive premium at 12:00 requests weight zero: buy 50 at 16:00.
3. The 12:00–16:00 bar has high $290 and close $100.
4. Adverse equity is $500, below maintenance of $725. At 16:00, liquidation buys back all 50 at $290, leaving **$500 and no position**.
5. The pending “close” then buys another 50 at the 16:00 open of $100.

**Wrong result:** the zero-weight close leaves the account **long 50**, with cash −$4,500—ten times its remaining equity in exposure. If the next bar falls to $80, it bankrupts. An already-completed flattening request should not create the opposite position; remaining flat preserves the $500.

All fills reconcile and pass the existing checks.

- **Likelihood:** uncommon but ordinary: a pending flattening order coincides with a non-bankrupt liquidation.
- **Reaches:** **portfolio returns**; the example changes a 95% loss into a 100% loss.
- **Loss bound/isolation:** neither is bypassed. The second loss is still capped at −1.
- **Contract:** this exposes missing cancellation/reduce-only semantics, not an arithmetic error in `Book::fill`.

## 3. Mandatory holds consume no gross-exposure budget

**Paths:** `kernel/mm/src/sim.rs:438–461`; also `:333–343` for the resulting held exposure.

Undefined or stale weights cause positions to be held, but those positions disappear from the vector used for gross normalization. Fresh targets receive the entire gross budget again.

**Program:**

```json
{"op":"if","args":[
  {"op":"gt","args":[{"input":"premium"},{"const":0,"unit":"1"}]},
  {"const":2,"unit":"1"},
  {"op":"div","args":[{"const":1,"unit":"1"},{"const":0,"unit":"1"}]}
]}
```

**Concrete market:**

- X has positive premium at 04:00 and 08:00; Y has negative premium.
- X accumulates 200 coins through the $10,000-per-order cap.
- At 12:00 and thereafter, X’s premium becomes negative and Y’s positive.
- X is held at 200 coins because its weight is undefined.
- Y independently accumulates another 200 coins.

At 20:00, equity remains $10,000 but gross exposure is **$40,000**. Every normalized weight vector passed the check. A subsequent 5% common decline loses **20%**, rather than the 10% associated with a two-times portfolio budget. More coins permit further accumulation.

- **Likelihood:** reachable through ordinary undefined signals, source coverage, or stale inputs; deliberate accumulation is also expressible.
- **Reaches:** **portfolio returns and liquidation frequency**, not the −1 bound.
- **Important qualification:** literal I9 bounds the emitted weight vector, and that check passes. The defect is in the advertised *portfolio* control: “hold” retains exposure but reserves no budget. This is a risk-model design gap, not a bypass of the normalization arithmetic.

## 4. New orders use equity from before already-completed fills

**Paths:** `kernel/mm/src/sim.rs:365–370,391–413,430–461`.

The simulator computes `e1`, executes boundary fills, and then sizes the next orders using that unchanged `e1`. Positions are current; equity is not.

**Program:** constant weight:

```json
{"const":1,"unit":"1"}
```

**Concrete market:** flat $100 prices, 10 bps slippage, 0.1% taker fee.

- The 04:02 decision buys 100 coins at 08:00.
- Execution price is $100.10; fee is $10.01.
- After execution, cash is −$20.01 and equity at the latest closed mark is **$9,979.99**.
- At 08:02, sizing nevertheless uses **$10,000** and the updated position of 100 coins.

**Wrong result:** it emits no rebalance. Weight one on actual equity calls for approximately 99.7999 coins: a **0.200-coin sale after truncation**, above the minimum notional. Its absence changes subsequent exposure, fees and returns.

The same discrepancy includes any fill-open/latest-close gap, so it need not be only a few dollars.

- **Likelihood:** routine whenever a boundary fill incurs costs; an actual order difference depends on rounding and minimum notional.
- **Reaches:** **portfolio returns**.
- **Loss bound/isolation:** unchanged.
- **Why reconciliation misses it:** both accounting books correctly record the fill; neither checks which equity the next decision uses.

## 5. Window reporting resurrects an account already bankrupt before the window

**Paths:** `kernel/mm/src/main.rs:107–120,183–186`; bankruptcy state in `kernel/mm/src/sim.rs:357–383`.

`reported()` always starts its compounding accumulator at `INITIAL`, despite its comment explicitly saying an already-bankrupt account stays at zero.

**Program:** constant weight −0.5.

**Concrete market:** the account shorts 50 coins at $100. Before the reporting window, a bar reaches $400, liquidating it into bankruptcy. All later simulator equity marks and returns are zero.

**Wrong result:** once the bankruptcy step is sliced away, `reported()` compounds the remaining zero returns from $10,000. The committed summary reports:

- `final_equity = 10000`
- `total_return = 0`

The underlying account and retained equity trace are at **zero**.

- **Likelihood:** conditional on bankruptcy in the unreported replay prefix, including before a later `--holdout-from`.
- **Reaches:** **reported portfolio equity and total return**. The return BLOB itself remains zero.
- **Consequence limit:** I did not establish a false promotion: zero total return still fails the positive-return requirement.
- **Loss bound/isolation:** unchanged.

## 6. Holdout traces omit boundary fills whose costs enter holdout returns

**Paths:** `kernel/mm/src/main.rs:108–120,169–193`; event ordering in `kernel/mm/src/sim.rs:370,394–413`.

This is lower consequence and **not a reversal trigger by itself**.

**Program:** weight 0.5 while premium is positive, otherwise zero.

**Concrete market:** premium is positive at `H−4h` and negative from H onward, where H is the reporting boundary. The entry fills at H, after the H equity mark; the exit fills at `H+4h`.

The first reported return includes the entry’s fees and slippage because those occur after the preceding equity mark. But trace filtering keeps only events with timestamp **strictly greater than H**, deleting that entry fill.

**Wrong result:** the committed holdout returns include the entry cost, while the disclosed trace and fee/slippage/turnover summaries omit it. For a 50-coin entry at $100.10 with a 0.1% fee, the omitted entry fee is **$5.005**.

- **Likelihood:** ordinary when an order fills exactly at the reporting boundary.
- **Reaches:** trace and cost reporting, **not the judged net-return stream, loss bound, or isolation**.

## Where I looked and found nothing additional

I read all nine files in `kernel/mm/src`, and relevant fixture, event, rewrite and CLI tests.

- **Accounting:** no additional defect established in average-entry accounting, partial reductions, reversals, fee debits, funding signs, or reconciliation.
- **Fill formulas:** adverse side, size-bucket selection, fee calculation and decision-price order cap matched the stated rules.
- **Funding:** a missing required settlement aborts rather than silently becoming zero.
- **Interpreter/type checker:** no new boolean/unit typing escape established. Lag indexing, strict undefined propagation, unselected `if` branches, hourly evaluation and `hours_since` matched their specified semantics.
- **Canonicalization:** no new unsound rewrite established.
- **Loss bound:** no new emitted step return below −1 established.
- **Holdout isolation:** no new I8 row-loading or I11 batch/spending bypass established.
- **Ledger:** successful experiment/result/disclosure insertion remains atomic. The prior append-only and identity findings are not repeated.

Several execution choices above are also transcribed into `reference/SEMANTICS.md`; agreement with that transcription would not remove their economic or causal consequences.

**Checkout qualification:** the named “qualified, not forked” decision was absent from this checkout’s `audit/decisions.md`. I used the reversal criterion supplied in your prompt.
