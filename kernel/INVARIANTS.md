# Kernel invariants

Times are UTC milliseconds. The holdout start, δ and W come from the store's own `policy.json`, written at ingestion, never from the caller.
A run is one strategy evaluated on one dataset version. Its trace is the ordered list of
decisions, orders, fills, settlements and equity marks.

| | Invariant | Enforced by | Violation |
|---|---|---|---|
| I1 | Every observation delivered to a strategy at tick τ has knownAt ≤ τ under the run's dataset version. A strategy reads nothing else. | The machine accepts input only through `deliver(obs, τ)`, which aborts if obs.knownAt > τ. The DSL has no clock, lead, index or path access. | `R_CAUSALITY` |
| I2 | For each fill, closeouts included (their times all equal the closeout time): max knownAt of the decision's inputs ≤ t_decision ≤ t_submission ≤ t_fill. | Trace check after every fill. | `R_TIMING` |
| I3 | qty ≠ 0. A decision's fill names its source bar (coin, openTime): the first bar of the coin with openTime ≥ t_submission. That bar must have openTime ≤ t_fill and trades ≥ 1, and the step's equity must be positive (I10); otherwise the order is unfilled and does not roll to a later bar. reference = the bar's open. price = reference · (1 + s · bps / 1e4), with s = +1 for a buy (qty > 0) and −1 for a sell, and bps = cost[coin][side][bucket], where the bucket is "1000" if \|qty\| · reference ≤ 1000 and "10000" otherwise. fee = \|qty\| · price · taker_fee. A closeout names the coin's latest bar with eventTime ≤ t_fill. A liquidation's reference is that bar's adverse extreme (high when buying back, low when selling), and a delisting's is its close. The same price and fee formulas apply. | Trace check after every fill, against the bar table. | `R_FILL` |
| I4 | A program runs only if it type-checks: every operation is dimensionally consistent (DSL.md, Units), time bases differ unless converted, and `weight` has unit `1`. | Type checker before any data is opened. | `E_*` (below) |
| I5 | Equity = cash + Σ qty · mark, with mark the coin's last closed bar close. At every 4h step, \|equity − (initial + realized + unrealized − fees + funding + absorbed)\| ≤ 1e-9 · max(\|equity\|, $10,000), where the right side comes from an independent average-entry ledger and `absorbed` is I10's shortfall. A non-finite difference fails the check. | Check at every step. | `R_ACCOUNTING` |
| I6 | Every result-bearing output goes through `disclose()`. It commits the experiment row, the result row and the disclosure row in one SQLite transaction before writing anything. If the commit fails, it writes no statistic and exits nonzero. The ledger tables have triggers that abort UPDATE and DELETE. A type-check rejection is disclosed (`kind = reject`) without opening data. | `disclose()` is the only writer of stdout results; triggers. | `R_LEDGER` |
| I7 | The same experiment identity gives a byte-identical result. The identity is: strategy canonical hash, params, universe, window, dataset version, sha256 of every store file with fetchedAt ≤ version, rules.json hash, execution.json hash, conventions (the whole policy: δ, settlement latency and window bounds; the decision grid and fill rule), kernel build hash, and seed. | No wall clock, randomness or iteration-order dependence in evaluation. Identity is hashed into the result. | test |
| I8 | In search mode, any row with eventTime ≥ holdout start aborts the run, whatever file it came from: input, fill bar, funding, or mark. | Check at load, on every row. | `R_HOLDOUT` |
| I9 | Σ\|w\| ≤ 2 after scaling. Order notional at the decision price (the price it was sized at; the fill price is unknown then) ≤ $10 000. Sizes are truncated to szDecimals. Orders under $10 are dropped unless they exactly close a position. Maintenance margin (1 / (2 · min tier maxLeverage)) is checked at each bar's adverse extreme, and a breach liquidates every position there. A non-finite or undefined weight means hold, and is recorded. | Portfolio step, then a trace check. | `R_PORTFOLIO` |
| I10 | Losses are capped at the account's equity, as on the venue. A 4h step whose equity, after margin and delisting, is not positive is a bankruptcy: every position still held is liquidated at its bar's adverse extreme, and the venue absorbs the negative balance (cash becomes 0). An order due at a step whose equity is not positive is unfilled, as the venue rejects an order without margin. Equity is 0 from then on, so no later order is sized. Every step return is equity / previous equity − 1 while both are positive, −B at the bankruptcy step and 0 after it, so it is ≥ −B, with B = 1. | The bankruptcy step, then a check on each step return. The Lean reference model proves the check never fires (`reference/lean/Ref/Laws.lean`, L6_bounded). | `R_BOUND` |
| I11 | A holdout batch is read whole from a file before any of it is evaluated, its trials (equivalence key with parameter values) are exactly those the selecting agent froze in the campaign, and its window is claimed in the holdout store's `spent.jsonl` under an exclusive lock before the first evaluation. A window overlapping a claimed one is never evaluated, whichever ledger asks. | Checks before loading the holdout. | `R_HOLDOUT_FAMILY`, `R_HOLDOUT_SPENT` |

## Rejection codes (type checker)

| Code | Meaning |
|---|---|
| `E_PARSE` | not valid DSL JSON: unknown, missing or duplicate field, wrong JSON type, `dsl` ≠ 1 |
| `E_UNKNOWN_INPUT` | input not in the schema |
| `E_UNKNOWN_OP` | op not in DSL.md |
| `E_ARITY` | wrong number of args |
| `E_UNIT` | dimension mismatch, bad unit syntax, `convert` across non-time units, `sqrt` of odd exponents |
| `E_DIMENSIONLESS` | `weight`, `log`, `exp` or `xs_rank` not of unit `1` |
| `E_BOOL` | boolean where a number is needed, or the reverse |
| `E_WINDOW` | `hours` missing, not an integer, or outside 1–4380 |
| `E_REF` | undefined, forward or cyclic `ref`, or undefined `param` |
| `E_SIZE` | more than 4096 nodes or nesting deeper than 64 |

## Threat matrix

| # | Mechanism | Invariant | Expected |
|---|---|---|---|
| T1 | negative `lag` hours (a lead) | I1 | `E_WINDOW` |
| T2 | zero or fractional window | I1 | `E_WINDOW` |
| T3 | future-looking op name (`lead`, `shift`, `future`, …) | I1 | `E_UNKNOWN_OP` |
| T4 | offset or time field on an input (`{"input": "close", "offset": -1}`) | I1 | `E_PARSE` |
| T5 | input outside the schema (`next_open`, `fill_price`, `eventTime`, `mark`) | I1 | `E_UNKNOWN_INPUT` |
| T6 | adding a price to a rate | I4 | `E_UNIT` |
| T7 | mixing `1/h` and `1/y` without `convert` | I4 | `E_UNIT` |
| T8 | dimensional weight (e.g. weight = close) | I4 | `E_DIMENSIONLESS` |
| T9 | relabeling an input's unit with an extra field | I4 | `E_PARSE` |
| T10 | `convert` between non-time units | I4 | `E_UNIT` |
| T11 | `log`/`exp` of a dimensional value | I4 | `E_DIMENSIONLESS` |
| T12 | boolean weight or boolean arithmetic | I4 | `E_BOOL` |
| T13 | forward or cyclic `let` | I4 | `E_REF` |
| T14 | non-finite constant (JSON cannot express one; out-of-range literals fail to parse) | I4 | `E_PARSE` |
| T15 | huge or deep program | I4 | `E_SIZE` |
| T16 | `--store` pointing at holdout files, or a copy of them | I8 | `R_HOLDOUT` |
| T17 | ledger unwritable (read-only file) while asking for results | I6 | `R_LEDGER`, no statistics on any channel |
| T18 | window longer than the cap | I1 | `E_WINDOW` |
| T19 | unknown top-level field (`"execution": {...}`, `"fill": "close"`) | I1/I3 | `E_PARSE` |
| T20 | `xs_rank` of a dimensional value | I4 | `E_DIMENSIONLESS` |
| T21 | duplicate object keys, which parsers resolve differently (the ledger's record and the run could disagree) | I6/I7 | `E_PARSE` |

Portfolio attacks (huge weights, many coins at full size, sign flips every bar) are not
rejected. They are clamped under I9, and tests check the trace against I9.

## Fill-check cases (`mm check-fills`)

One JSON object per line:

```
{"id": "c0",
 "taker_fee": 0.00045,
 "cost_bps": {"buy": [c_le_1k, c_gt_1k], "sell": [c_le_1k, c_gt_1k]},
 "bars": [{"open_time": ms, "event": ms, "open": x, "high": x, "low": x, "close": x, "trades": n}, ...],
 "fill": {"why": "fill" | "liquidation" | "delisting", "qty": signed coins (> 0 buys),
          "inputs_known": ms, "decision_price": x, "decided": ms, "submitted": ms, "filled": ms,
          "source_open": ms, "reference": x, "price": x, "fee": x}}
```

All bars belong to the fill's coin, sorted by `open_time`, at most one per `open_time`. `event` is the bar's close time. `cost_bps[side][0]`
applies when |qty| · reference ≤ 1000, `[1]` otherwise. Prices compare exactly, as IEEE
doubles: price must equal `reference * (1.0 + s * bps / 1e4)` computed in that order, and fee
`abs(qty) * price * taker_fee`.

The verdict is the first failing rule: `R_TIMING` (I2), then `R_FILL` (I3), then
`R_PORTFOLIO` (an order of `why = "fill"` whose |qty| · decision_price exceeds $10 000).
Otherwise it is `ok`.
