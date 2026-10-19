# Kernel invariants

Times are UTC milliseconds. The holdout start, δ and W come from `policy.json`.
A run is one strategy evaluated on one dataset version. Its trace is the ordered list of
decisions, orders, fills, settlements and equity marks.

| | Invariant | Enforced by | Violation |
|---|---|---|---|
| I1 | Every observation delivered to a strategy at tick τ has knownAt ≤ τ under the run's dataset version. A strategy reads nothing else. | The machine accepts input only through `deliver(obs, τ)`, which aborts if obs.knownAt > τ. The DSL has no clock, lead, index or path access. | `R_CAUSALITY` |
| I2 | For each fill: max knownAt of the decision's inputs ≤ t_decision ≤ t_submission ≤ t_fill. | Trace check after every fill. | `R_TIMING` |
| I3 | A decision's fill names its source bar (coin, openTime). That bar is the first bar of the coin with openTime ≥ t_submission, openTime ≤ t_fill, and trades ≥ 1; otherwise the order is unfilled. reference = the bar's open. price = reference · (1 + s · bps / 1e4), with s = +1 for a buy (qty > 0) and −1 for a sell, and bps = cost[coin][side][bucket], where the bucket is "1000" if \|qty\| · reference ≤ 1000 and "10000" otherwise. fee = \|qty\| · price · taker_fee. A liquidation or delisting closeout names the bar whose close or adverse extreme it uses (high when buying back, low when selling), with that bar's eventTime ≤ t_fill, and the same price and fee formulas. | Trace check after every fill, against the bar table. | `R_FILL` |
| I4 | A program runs only if it type-checks: every operation is dimensionally consistent (DSL.md, Units), time bases differ unless converted, and `weight` has unit `1`. | Type checker before any data is opened. | `E_*` (below) |
| I5 | Equity = cash + Σ qty · mark, with mark the coin's last closed bar close. At every 4h step, \|equity − (initial + realized + unrealized − fees + funding)\| ≤ $1e-5, where the right side comes from an independent average-entry ledger. | Check at every step. | `R_ACCOUNTING` |
| I6 | Every result-bearing output goes through `disclose()`. It commits the experiment row, the result row and the disclosure row in one SQLite transaction before writing anything. If the commit fails, it writes no statistic and exits nonzero. The ledger tables have triggers that abort UPDATE and DELETE. A type-check rejection is disclosed (`kind = reject`) without opening data. | `disclose()` is the only writer of stdout results; triggers. | `R_LEDGER` |
| I7 | The same experiment identity gives a byte-identical result. The identity is: strategy canonical hash, params, universe, window, dataset version, sha256 of every store file with fetchedAt ≤ version, rules.json hash, execution.json hash, conventions (δ, decision grid, fill rule), kernel build hash, and seed. | No wall clock, randomness or iteration-order dependence in evaluation. Identity is hashed into the result. | test |
| I8 | In search mode, any row with eventTime ≥ holdout start aborts the run, whatever file it came from: input, fill bar, funding, or mark. | Check at load, on every row. | `R_HOLDOUT` |
| I9 | Σ\|w\| ≤ 2 after scaling. Order notional at the decision price (the price it was sized at; the fill price is unknown then) ≤ $10 000. Sizes are truncated to szDecimals. Orders under $10 are dropped unless they exactly close a position. Maintenance margin (1 / (2 · min tier maxLeverage)) is checked at each bar's adverse extreme, and a breach liquidates every position there. A non-finite or undefined weight means hold, and is recorded. | Portfolio step, then a trace check. | `R_PORTFOLIO` |

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
