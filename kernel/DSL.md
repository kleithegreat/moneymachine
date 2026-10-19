# Strategy DSL (version 1)

A strategy is a JSON document. The kernel type-checks it, then interprets it as a
causal machine over point-in-time observations. There is no other way to run a
strategy and no way to run host-language code.

```json
{
  "dsl": 1,
  "name": "fade-extreme-funding",
  "mechanism": {
    "counterparty": "levered longs paying for leverage when funding spikes",
    "predictions": ["edge larger when funding is more extreme"],
    "capacity": "small; taker orders <= $10k"
  },
  "params": {"thr": {"value": 0.0001, "unit": "1/h"}},
  "let": {"f": {"input": "funding"}},
  "weight": {"op": "if",
             "args": [{"op": "gt", "args": [{"op": "abs", "args": [{"ref": "f"}]}, {"param": "thr"}]},
                      {"op": "mul", "args": [{"op": "neg", "args": [{"op": "sign", "args": [{"ref": "f"}]}]},
                                             {"const": 0.008333333333333333, "unit": "1"}]},
                      {"const": 0, "unit": "1"}]}
}
```

Top-level fields, all required except `params` and `let`. Unknown fields are rejected everywhere.

| Field | Meaning |
|---|---|
| `dsl` | must be `1` |
| `name` | free text, not part of the strategy's identity |
| `mechanism` | `counterparty`, `predictions` (list), and `capacity`: free text, recorded in the ledger |
| `params` | name → `{"value": number, "unit": unit}`, referenced by `{"param": name}` |
| `let` | name → expression, referenced by `{"ref": name}`. A let may reference only lets defined before it, so there are no cycles |
| `weight` | expression of unit `1`: the target position for each coin as a fraction of account equity (positive is long) |

## Time and evaluation

The machine runs once per coin on an hourly clock. Tick τ = H + δ for every hour H,
with δ = 120 s. At a tick, every observation with knownAt ≤ τ is delivered first,
and then every expression is evaluated once. Inputs hold their latest delivered
value between updates. A 4h bar therefore holds for 4 ticks, and the funding settled
at H arrives at tick H + δ.

The kernel decides at ticks where H is a 4h boundary (00, 04, …, 20 UTC). For each
listed coin, the weight at that tick sets the target position. The kernel holds the
current position for a coin, with no trade, if the funding settled at H or the bar
ending at H has not arrived, or if the weight is undefined or not finite.

An order decided at H + δ is submitted then, and fills at the open of the first bar
that starts at or after submission, i.e. the bar at H + 4h. The fill moves adversely
by the taker cost model and pays the taker fee. If that bar recorded no trade, the
order is unfilled. Funding settles every hour on the position held, at the open of
the 4h bar containing that hour. Settlement comes before a fill at the same instant.

Portfolio rules applied by the kernel, not the strategy:
- If Σ|weight| > 2 across coins, all weights are scaled down to Σ|weight| = 2.
- An order's notional is capped at $10,000; the position moves toward the target by at most that much per decision.
- Sizes are truncated toward zero to the coin's size decimals. Orders under $10 notional are dropped, except a weight of exactly 0, which closes the position in full.
- Maintenance margin is checked at each bar's adverse extreme, and a breach liquidates every position at those prices.
- A coin that is delisted is closed at its last bar's close.

## Units

A unit is a product of base units with integer exponents: `usd`, `coin`, `h`, `d`, `y`.
Syntax: `1`, `usd`, `usd/coin`, `1/h`, `coin*usd/h^2`. The time units are distinct
base units, so a rate per hour and a rate per year are different types.

- `add`, `sub`, `min`, `max`, `clip`, comparisons and `if` branches need identical units.
- `mul` and `div` add or subtract exponents.
- `log`, `exp`, `xs_rank` and the `weight` need unit `1`.
- `sqrt` needs even exponents and halves them.
- `convert` changes time units only, scaling by the exact factor (1 d = 24 h, 1 y = 365 d): `{"op": "convert", "args": [x], "to": "1/y"}`.

## Expressions

Every expression is a JSON object of one of these forms:

| Form | Unit |
|---|---|
| `{"input": "funding"}`: funding rate settled at the latest hour (positive: longs pay) | `1/h` |
| `{"input": "premium"}`: premium reported with that funding row | `1` |
| `{"input": "open" \| "high" \| "low" \| "close"}`: of the latest closed 4h bar | `usd/coin` |
| `{"input": "volume"}`: of the latest closed 4h bar | `coin` |
| `{"const": number, "unit": unit}` | as given |
| `{"param": name}`, `{"ref": name}` | of the target |
| `{"op": name, "args": [...], ...}` | below |

| op | args | extra field | result |
|---|---|---|---|
| `add` `sub` `mul` `div` `min` `max` | 2 | | arithmetic; `div` by 0 is undefined |
| `neg` `abs` | 1 | | same unit |
| `sign` | 1 | | `1`, value −1, 0, or 1 |
| `log` `exp` `sqrt` | 1 | | `log` of x ≤ 0 is undefined |
| `clip` | 3: x, lo, hi | | same unit |
| `gt` `ge` `lt` `le` | 2 | | boolean |
| `and` `or` | 2 booleans | | boolean |
| `not` | 1 boolean | | boolean |
| `if` | condition, then, else | | unit of the branches |
| `convert` | 1 | `to`: unit | rescaled |
| `lag` | 1 | `hours`: integer 1–4380 | the value `hours` ticks ago |
| `mean` `sum` `std` `min_over` `max_over` | 1 | `hours`: integer 1–4380 | over the last `hours` ticks, including the current one |
| `ema` | 1 | `hours`: integer 1–4380 | exponential mean with α = 2 / (hours + 1) |
| `xs_mean` `xs_demean` | 1 | | across listed coins with a defined value at this tick |
| `xs_rank` | 1 of unit `1` | | rank in [0, 1] across those coins (ties averaged; a single coin gets 0.5) |

Every expression is evaluated at every tick, so windows see every tick. `std` uses the
population formula. A window is undefined until it holds `hours` samples, and while any
of them is undefined. `ema` is undefined until it has seen `hours` defined samples; an
undefined sample leaves its state unchanged. Any operation with an undefined argument is
undefined, except `if`: an undefined value in the branch it does not select is ignored.
An undefined condition makes it undefined. Booleans cannot be the weight.

## CLI

See `mm --help`. `mm check FILE` type-checks a strategy without touching data.
`mm eval FILE --campaign C --agent A` evaluates it on the search period and prints its
disclosed statistics. Every check and evaluation is recorded in the ledger before
anything is printed.
