# Kernel version 2: the program's grammar, the market's encoding and the rows

Written 2026-11-15 UTC by Claude Fable 5.2; consolidated, simplified, and **FROZEN** under Kernel Round 20, pinned MPFR, and the honest-but-buggy threat model at the Project Reset (2026-11-25 06:48 UTC / 2026-11-25 01:48 EST). This file is the spec beside the code. Until the build's step 0 moves part A of `audit/program/kernel-v2.md` here, A1 to A16 are there, and this file holds what continues them: **A17, the program** as JSON, and **A18, the market** as the engine receives it. **A19** is the rows the engine writes: the report and the trace. Nothing here decides a rule that part A leaves open without saying so: each such point is marked **Pinned here**, and listed in `audit/program/ledger.md`.

## A17. The program

A program is one JSON document, read strictly: an unknown field, a missing one, a repeated key or a value of the wrong JSON type is `E_PARSE`. Every field below is required.

```json
{
  "version": 2,
  "tick": 60,
  "decide_every": 1,
  "leverage": 1,
  "sources": [{"name": "vol", "unit": "1"}],
  "params": [{"name": "step1", "value": "0.9775", "unit": "1"}],
  "let": [{"name": "calm", "is": {"op": "lt", "args": [{"input": "vol"}, {"const": 0.02, "unit": "1"}]}}],
  "slots": [
    {"name": "first", "side": "buy", "when": {"ref": "calm"},
     "price": {"input": "bid"}, "size": {"exact": "25", "unit": "usd"},
     "tif": "alo", "reduce_only": false},
    {"name": "level1", "side": "buy", "when": {"op": "gt", "args": [{"input": "first_size"}, {"exact": "0", "unit": "coin"}]},
     "price": {"op": "mul", "args": [{"input": "first_price"}, {"param": "step1"}]},
     "size": {"input": "first_size"}, "tif": "alo", "reduce_only": false},
    {"name": "exit", "side": "sell", "when": {"op": "gt", "args": [{"input": "pos"}, {"exact": "0", "unit": "coin"}]},
     "price": {"op": "mul", "args": [{"input": "entry"}, {"exact": "1.0056", "unit": "1"}]},
     "size": "close", "tif": "alo", "reduce_only": true}
  ],
  "probes": [{"name": "calm", "is": {"ref": "calm"}}]
}
```

| Field | Value |
|---|---|
| `version` | the integer 2 |
| `tick` | a whole number of seconds, from 1 (A4) |
| `decide_every` | a whole number of ticks, from 1 (A4) |
| `leverage` | a whole number from 1, as the venue takes them; or an object giving one for each coin of the market. `start` rejects one above the greatest leverage of its coin's tiers, or an object that does not name exactly the market's coins (`E_LEVERAGE`) |
| `sources` | a list of the declared sources the program reads (A3), each a name and the unit the program takes it in. `start` rejects a market that does not declare one of them under that unit (`E_UNKNOWN_INPUT`) |
| `params` | a list of named constants, each a `value` and a `unit`, read by `{"param": name}`. A value that is a JSON number is a float and keeps its bits, so `-0.0` stays; one that is a string is an exact decimal |
| `let` | a list of named expressions, read by `{"ref": name}`. One may read only those before it in the list |
| `slots` | a list of at most 16 (A5), in the order A6 admits them |
| `probes` | a list of named expressions of any type, written to the trace at every tick, for every coin |

**Order is a list's.** Whatever has an order is a JSON list, never an object's keys, which parsers do not agree to keep.

**Names** of params, lets, slots, probes and declared sources match `[a-z][a-z0-9_]{0,31}`. Each kind has its own namespace, and a name repeated within one is `E_PARSE`. A declared source may not take an input's name (`start`, `E_HEADER`).

**Size.** In this order: a text above 1 MiB, or brackets nested more than 130 deep counted outside strings, is `E_SIZE` (the document, a list, an entry, and two for each of an expression's 64 levels less one: an expression of the greatest depth nests exactly 130); then anything that is not this grammar is `E_PARSE`; then more than 4,096 expressions, or one deeper than 64, is `E_SIZE`.

### Types

A type is **bool**, or a **sort** with a **unit**. The sorts are A2's: `exact` and `float`. No expression changes sort but the two crossings.

A unit is a product of base units with whole exponents. It is written as `1` or as factors joined by `*`, then optionally `/` and more factors, a factor being a base unit with an optional `^` and a whole exponent from 1: `1`, `usd/coin`, `1/h`, `coin*usd/h^2`. The base units are stage 6's `usd`, `coin`, `h`, `d`, `y` and `ev`, and one more, **`tick`**, the program's own clock step. A price is `usd/coin`, a size `coin` and money `usd`, so that price times size is money is arithmetic on exponents and no rule of its own. `convert` knows `h`, `d` and `y` and nothing else, as in stage 6. A program that wants hours from ticks multiplies by its own constant of unit `h/tick`: it declared the tick.

### Expressions

Every expression is a JSON object of one of these forms.

| Form | Type |
|---|---|
| `{"const": number, "unit": u}` | float. The binary64 nearest the literal, then one addition of `+0` (`reference/SEMANTICS.md` §2). A literal with no finite binary64 is `E_PARSE` |
| `{"exact": "decimal", "unit": u}` | exact. The decimal as written: an optional `-`, digits, and optionally a point and digits. No exponent |
| `{"param": name}`, `{"ref": name}` | the target's |
| `{"input": name}` | below |
| `{"input": "filled" \| "resting" \| "resting_price", "slot": name}` | exact; below |
| `{"op": name, "args": [...]}`, with `ticks` or `to` where the table says | below |

**Inputs.** A5 gives their values. Their types:

| Input | Type |
|---|---|
| `bid`, `ask`, `mid`, `high`, `low`, `oracle`, `entry`, `first_price`, `resting_price` | exact, `usd/coin` |
| `bid_size`, `ask_size`, `traded`, `pos`, `first_size`, `filled`, `resting` | exact, `coin` |
| `funding` | exact, `1/h` |
| `age` | exact, `tick` |
| `equity`, `free_margin` | exact, `usd`; the account's, so the same for every coin |
| a name in the program's `sources` | float, its unit there |

- **The price inputs,** which the view's staleness makes undefined (A3), are `bid`, `ask`, `mid`, `bid_size`, `ask_size`, `high` and `low`.
- **Pinned here:** a slot with no live order has `resting` of zero and an undefined `resting_price`. `funding` and `oracle` are undefined before the coin's first known settlement, and an unsettled hour leaves them as they were.
- **Pinned here: a program names the sources it reads, with their units,** so that `check` types it with no market. An input in neither this table nor the program's `sources` is `E_UNKNOWN_INPUT` from `check`. `start` gives the same code when the market lacks a source the program names, or has no trade source for `traded` (A5).

**Operators.** `u` and `v` are units.

| Op | Arguments | Result |
|---|---|---|
| `add`, `sub`, `min`, `max` | two of one sort, unit `u` | that sort, `u` |
| `mul`, `div` | two of one sort, units `u`, `v` | that sort, `u·v`, `u/v` |
| `neg` | one number | its type |
| `gt`, `ge`, `lt`, `le` | two of one sort, unit `u` | bool |
| `and`, `or`; `not` | two bools; one | bool |
| `if` | a bool, then two bools or two floats of unit `u` | the branches' type |
| `exact` | a float | exact, its unit |
| `float` | an exact | float, its unit |
| `abs`; `sign` | a float of unit `u` | float, `u`; float, `1` |
| `log`, `exp` | a float of unit `1` | float, `1` |
| `sqrt` | a float whose exponents are all even | float, half of each |
| `clip` | three floats of unit `u` | float, `u` |
| `convert`, with `to` | a float; `to` differs from its unit only in `h`, `d`, `y` | float, `to` |
| `lag`, `mean`, `sum`, `std`, `min_over`, `max_over`, `ema`, each with `ticks` | a float of unit `u` | float, `u` |
| `xs_mean`, `xs_demean` | a float of unit `u` | float, `u` |
| `xs_rank` | a float of unit `1` | float, `1` |
| `ticks_since` | a bool | float, `tick` |

- **Exact operators** are the first three rows on exact arguments, and `exact`. Each is the rational operation. A division by zero is undefined, and so is any operator with an undefined argument. There is no exact `if`: a choice between two prices is two slots.
- **The crossings** are A2's. `float(e)` is the nearest binary64, ties to even, and undefined when that is not finite. `exact(f)` is the rational `f` is, and changes no value.
- **Float operators** are `reference/SEMANTICS.md` §1, §4, §5 and §6 to the bit with two deliberate version-2 changes:
  - **`exp` and `log`** are evaluated via pinned nixpkgs MPFR (`pkgs.mpfr`, `kernel2/lean/c/mpfr_ops.c`), rounded once to 53-bit binary64 with IEEE subnormalization (`kernel-v2.md` A2, X4), correctly rounded where stage 6 took glibc's `libm`: they differ from stage 6's where glibc's is not the nearest binary64.
  - **`sum`, `mean`, and `std` (round 8, exact specification & clarifications round 9):** replace stage 6's running-subtraction sums (`SEMANTICS.md` §6, which drift after evicting outliers and cancel in `sumsq/n − m²`) with a **two-stack sliding-window monoid queue (SWAG) using Chan's parallel variance formula** over `NumOps α`, specified to the bit below so an independent implementer can build B4's v2 reference from this section alone:
    - *Block aggregate `Agg α`:* `empty` ($k = 0$), `bad k` ($k \ge 1$, contains $\ge 1$ `none`), or `good (k, s, μ, m2)` ($k \ge 1$).
    - *Single tick `ofOpt`:* `none ↦ bad 1`; `some v ↦ good (1, v, v, N.zero)`.
    - *Chronological `combine a b`* (older `a` on the left, newer `b` on the right):
      - `combine empty b = b` and `combine a empty = a` (preserving `−0.0` when combined with `empty`);
      - if either side is `bad`, return `bad (k_a + k_b)`;
      - for `good (k_a, s_a, μ_a, m2_a)` and `good (k_b, s_b, μ_b, m2_b)`:
        - `k = k_a + k_b`; `s = N.add s_a s_b`;
        - `δ = N.sub μ_b μ_a`; `w = N.div (N.ofNat k_b) (N.ofNat k)`;
        - `μ = N.add μ_a (N.mul δ w)` when `N.finite δ`, else `N.add (N.mul (N.div (N.ofNat k_a) (N.ofNat k)) μ_a) (N.mul w μ_b)`;
        - `m2 = N.add (N.add m2_a m2_b) (N.mul (N.mul δ δ) (N.mul (N.ofNat k_a) w))`.
    - *Queue push of `x : Option α` (window length `n = ticks ≥ 1`):* initially `front = []`, `back = []`, `backAgg = empty`. Append `x` to `back` and set `backAgg := combine backAgg (ofOpt x)`. Whenever `front.len + back.len > n`: if `front` is empty, walk `back` from newest index `back.len − 1` down to index `1` (omitting evicted index `0` completely), accumulating `acc := combine (ofOpt back[i]) acc` onto `front` (so `front.top` holds the suffix `back[1 .. back.len − 1]`), then set `back := []`, `backAgg := empty`; otherwise pop `front.top`. (Handles `n = 1` with no special case.)
    - *Query:* if `front.len + back.len < n`, return `none`; otherwise let `a = combine (front.top or empty) backAgg`; if `a` is not `good (k, s, μ, m2)`, return `none`; otherwise return `N.keep s` (`sum`), `N.keep μ` (`mean`), or `N.keep (N.sqrt (N.div m2 (N.ofNat n)))` (`std`).
    - *Properties & honest limits:* eliminates stage 6's defect 1 (post-eviction corruption from subtraction) and defect 2 (`sumsq/n − m²` cancellation/overflow in `std`). Exact on every non-negative constant window `[c; n]` (while on `[-0.0, -0.0]` for `n ≥ 2`, `sum = −0.0` and `mean = +0.0` since `δ = +0.0`, and `std([-0.0]) = +0.0`). Because IEEE binary64 addition is non-associative, the `front`/`back` split phase makes a window a deterministic function of the node's input sequence from its first tick (not solely of the last `ticks` values: under cancellation or overflow, different split phases can differ by up to 100% or finite vs. `Undef`; defect 3 is not eliminated). Exact sliding-window superaccumulation is not used in order to keep `NumOps α` parametricity for `L2`, `L3`, and `N1`.
  - B4's reference computes both changes (`kernel-v2.md` B4). There are three restatements more, since stage 6 named the hour and version 2 counts ticks:
  1. **A window's length is `ticks`,** where stage 6 wrote `hours`: a whole number from 1. The `ticks` of a program's window operators, each counted once as written, sum to at most 1,048,576, or it is `E_WINDOW`. That is a choice, made for B5: a float and its mark for each of 17 coins is then under 0.2 GB of the 2 GB, and one window reaches 12 days at a tick of a second and 728 days at a minute.
  2. **`ticks_since`** is stage 6's `hours_since` with the count of ticks for the count of hours: the ticks since the last one at which the condition held, zero at that tick.
  3. **A coin is in view** at a tick unless the end of its listing is known by then. That is stage 6's listing mask: outside it every node is undefined and no window is pushed, and the `xs` operators range over the coins in view whose argument is defined, in the market's coin order.
- At a tick of one hour these are stage 6's operators but for `exp`, `log`, and `sum`/`mean`/`std`, which is B4. Its corpus reads `hours_since(c)` as `mul(ticks_since(c), const 1 [h/tick])`, which multiplies by one.
- **Bools** are computed as stage 6 computes them. A comparison of two exact numbers compares rationals.

### Slots

| Field | Value |
|---|---|
| `name` | a name |
| `side` | `"buy"` or `"sell"` |
| `when` | a bool expression |
| `price` | an exact expression of unit `usd/coin` |
| `size` | an exact expression of unit `coin`, a size; or of unit `usd`, a notional; or the string `"close"` |
| `tif` | `"gtc"`, `"alo"` or `"ioc"` |
| `reduce_only` | `true` or `false` |

A5 and A6 say what a slot does. **Pinned here:** a slot is inactive at a deciding tick when its `when` is false or undefined, and also when its price or its target is undefined, since a wish is a price and a target.

### The verdict

`check` returns `{"ok": true}`, or `{"error": code, "at": where}` for the first fault met, the checks running in the order of this section and, within the expressions, in the order of the document with an operator's arguments before it.

| Code | Fault |
|---|---|
| `E_SIZE` | above |
| `E_PARSE` | not this grammar |
| `E_REF` | a `ref` to no earlier let; a `param` or a `slot` that names none |
| `E_UNKNOWN_INPUT`, `E_UNKNOWN_OP`, `E_ARITY` | an input, an operator, or a count of arguments not in the tables |
| `E_TYPE` | a bool where a number is needed or the reverse; a float where an exact is needed or the reverse, a slot's price and size included |
| `E_UNIT` | units that differ where they must agree; a unit a row does not take; a slot's price not `usd/coin`, or its size neither `coin` nor `usd` |
| `E_WINDOW` | `ticks` missing, not a whole number from 1, or the program's windows above their bound |

## A18. The market

A market reaches the engine as a **header**, which `start` takes with the program, and as **chunks** of events, which `feed` takes. One encoding holds every event, whatever file it came from, and it is the one two readers are compared in (B2).

### The header

One JSON document, read as strictly as a program; a fault is `E_HEADER`. Times are integer milliseconds. Every exact number is a decimal in a string.

```json
{
  "horizon": {"start": 1775174400000, "end": 1793491200000},
  "venue": {"fill": "pessimistic", "lambda": 1000, "delta": 1000, "stale": 60000, "cap": "10000", "minimum": "10"},
  "cash": "10000",
  "coins": [{"name": "BTC", "sz_decimals": 5, "figures": 5, "decimals": 1,
             "tiers": [{"from": "0", "max_leverage": 40}]}],
  "fees": [{"from": 1775174400000, "tier": "base", "maker": "0.00015", "taker": "0.00045"}],
  "sources": {
    "listings": {"lag": 3600000},
    "funding": {"encoding": "string", "lag": 60000, "late": 600000},
    "quotes": {"encoding": "double"},
    "trades": {"encoding": "string"},
    "observations": [{"name": "vol", "unit": "1", "kind": "state", "lag": 60000}]
  },
  "aliases": {"coins": {}, "sources": {}}
}
```

- **`venue`** is A1's record, whole: the fill rule, `λ`, `δ`, `G`, the order cap and the minimum order. Part A's "policy's cap" was this cap, and is now called the venue's.
- **`cash`** is the account's starting cash, above zero.
- **`coins`** are the market's coins, in the order every "coin order" means. A name is 1 to 32 printable ASCII characters with no space. They are the universe: there is no other coin, and an event names one by its place in this list. Each has its rules for the whole run, which no event changes (`kernel-v2.md` A3), and is in the market from the horizon's start until its listing ends. `tiers` rise in `from`, the first from zero.
- **`fees`** are the dated tiers of A8, rising in `from`, the first at or before the horizon's start. The one in force at a time is the last that began at or before it.
- **`sources`**: `listings` (the `lag` of a listing's end) and `funding` are required. A **book market** has `quotes`, and `trades` when it has them. A **bar market** has, in their place, `"bars": {"span": Δ, "half_spread": h, "depth": notional}`, with `h` one decimal or an object of one a coin (A16, B1 to B3); it has of itself the five `state` sources `bar_open`, `bar_high`, `bar_low`, `bar_close` (`usd/coin`) and `bar_volume` (`coin`), which come before the declared ones in the order of sources. Both kinds at once is `E_HEADER`.
- **`lag`** is a source's `known` rule, at least zero: no event of it is known sooner than `lag` after its `time`. For quotes, trades and bars it is `δ` and is not declared.
- **`late`** is funding's registered lateness, below one hour.
- **`aliases`** are A13's bijections, real name to opaque. With them the program is written in the opaque names and every row is written in them.

`start` also rejects: a horizon that meets an unreleased protected window (`R_PROTECTED`); a venue whose `lambda` or `delta` is below zero, whose `stale` is below 1, whose `cap` is not above zero or whose `minimum` is below zero, a `pessimistic` venue on a book market with no trades, a bar market without `Δ < G ≤ 2Δ` or with a half-spread not above zero (`E_VENUE`); a fee rate outside 0 to 1, or a coin's rules with `figures` of zero, `decimals` above 8, `sz_decimals` above 6, no tier, or tiers that do not rise from zero (`E_HEADER`).

### An exact field

Each exact field has a scale `d`: **8** for a price, **6** for a size, **12** for a rate, **2** for a tier's bound. No coin's rules set a scale (study 2's round 17, D337): a perp's lots are `10^−sz_decimals` with `sz_decimals` at most 6, so every lot is a whole multiple of `10⁻⁶`, and a size reads below `10⁹` units. The scale is the field's and no source chooses it. What a source declares is its encoding (A2), and the engine does the rest:

- **`string`:** the reader gives two integers, `n` and `w`: the string's digits as one integer, and the count of digits after its point, zeros at the end not counted. The value is `n · 10⁻ʷ`. The engine rejects `w > d`, and `|n| · 10ᵈ⁻ʷ ≥ 10¹⁵` (`E_DECIMAL`). The reader places digits at no scale and knows no rule of any coin, so it cannot be wrong about one; it knows the fields' scales for one thing, that a number the engine would reject here makes its item one it counts and does not feed (below). **Pinned here:** `"5.0"` at a scale of 0 is 5, since a zero at the end says nothing; A2's "more decimals than the scale" counts digits that say something.
- **`double`:** the reader gives the binary64 untouched, and the engine reads it at `d` (A2, X2), and a price only where it is on its coin's grid, a double's one witness of having been a decimal (`kernel-v2.md` A2).

The header is always `string`.

**A number is read once,** at admission, at its field's scale; no coin's rules enter the reading of a market event, a `double` price's grid apart. What the world keeps of an event and what the view takes of it at its `known` are that reading; the view has no rules of its own (`kernel-v2.md` B1, L1a).

### The price grid

A coin's rules hold `figures`, from 1, and `decimals` (V1). A price is **on the grid** when it is above zero, is a whole multiple of `10^−decimals`, and either has at most `figures` significant figures or is a whole number. A `p` in `[10ᵉ, 10ᵉ⁺¹)` has at most `figures` significant figures when it is a whole multiple of `10^(e − figures + 1)`, so the grid's prices there are the whole multiples of the step `10^max(min(e − figures + 1, 0), −decimals)`. The `min` is the whole numbers: without it the step from `figures` figures up would be above one (`audit/program/arithmetic.py.txt`, `price_grid`, checks the step against a count of digits on every price of a range).

**The rule is the venue's, certified** (`venue/sources.toml`, Hyperliquid's description, "Price grid"): at most 5 significant figures, at most `6 − szDecimals` decimals for a perp, and a whole-number price whatever its figures, so `123456` is a price and `12345.6` is not. A market of the venue's perps therefore gives each coin `figures` of 5 and `decimals` of `6 − sz_decimals`, and its writer refuses a coin whose `sz_decimals` is above 6, of which the page says nothing. The engine takes the two numbers as the coin's rules and knows no venue. The certificate is of the page as read on 2026-11-15; that the venue enforced it at every time of a horizon is V1's assumption, and its witness is in the record: the engine counts each recorded price off the grid, and each size off the lots, of its coin's rules (its `off_rules` rows, A19), and every price of the vault's fills must be on it (brief 3, step 2). Both can show a grid too narrow and neither one too wide, which rests on the page alone.

A buy's price rounds to the greatest grid price at or below it, and to zero when there is none; a sell's to the least at or above. An order at zero is A6's to admit or refuse like any other, and it buys nothing: no ask and no print is at or below it. A bar's print rounds to the nearest grid price, a tie to the higher, and to the least where none is at or below it. An order's size is a whole multiple of `10^−sz_decimals`. A recorded size is read at scale 6, is held to no lots, and is offered to an order as recorded (`kernel-v2.md` A7).

### The chunk

Three flat arrays. `feed` consumes the records in order, and each record takes its values from the front of what the earlier ones left.

- **`records`:** bytes, 24 for each event, little-endian.

  | Bytes | Field |
  |---|---|
  | 0 | `kind`: 0 listing, 1 funding, 2 trade, 3 quote, 4 observation, 5 bar |
  | 1, 2, 3 | `a`, `b`, `c`: small fields, by kind; zero when unused |
  | 4 to 5 | `coin`, unsigned: its place in the header's list |
  | 6 to 7 | `source`, unsigned: an observation's place in the header's list; else zero |
  | 8 to 15 | `time`, signed |
  | 16 to 23 | `known`, signed |

- **`integers`:** signed 64-bit, little-endian.
- **`doubles`:** binary64.

A record's values, in order. **I** is one integer. **F** is one double. **X** is an exact field: two integers from a `string` source, one double from a `double` one.

| Kind | Small fields | Values |
|---|---|---|
| listing (its end) | | none: the coin's position closes at its adverse price there (A3) |
| funding, a settlement | `a` = 1 when an oracle price follows, else 0 | I the hour it settles, in milliseconds; X the rate; X the oracle price, when `a` = 1 |
| funding, an unsettled hour | `a` = 2 | I the hour: the venue's replies show it settled none (What a reader puts in a record), so it pays nothing |
| trade | `a` = 0 when the buyer was the aggressor, 1 when the seller | I the venue's id; X the price; X the size |
| quote | `a`, `b` = the counts of bid and ask levels, each 1 to 20 | for each bid, best first, X its price, X its size; then the asks |
| observation | | F the value |
| bar | | F the open, high, low, close and volume; `time` is the bar's end |

### What `feed` checks

A3's admission and C2 say what a market may hold. Of the encoding itself, `feed` also rejects (`R_MARKET`, naming the case; a number's range is `E_DECIMAL`, a protected date `R_PROTECTED`):

- a chunk whose arrays do not hold exactly its records' values; an unknown kind; a small field out of its range; a coin or a source that is not in the header;
- a `time` outside the horizon;
- a `known` that is not `time + δ` for a trade, a quote or a bar, or is below `time + lag` for any other;
- a funding event whose hour `H` is not a whole hour, whose `time` is outside `[H, H + late]`, or which is the second for its coin and hour;
- a bar whose `time` is not a whole multiple of `Δ`, whose values are not all finite, whose prices are not above zero with the low at most the open and the close and the high at least them, or whose volume is below zero; a trade or a quote on a bar market, and a bar on a book market;
- a market event its reader should have counted (study 2's round 17, D337): a quote crossed, one-sided or not strictly best first; a quote or a print with a price or a size not above zero, or a `string` number its scale cannot place. The reader counts each as holding no item and feeds nothing of it, so one fed is the reader's fault;
- a `double` that is no reading: the nearest binary64 of no `n` in range (`E_DECIMAL`), or a price off its coin's grid. No reader reads a double, so this is the engine's alone to find, and it rejects the market (`kernel-v2.md` A2).

No market event is checked against its coin's rules: those are the venue's rules for orders (`kernel-v2.md` A3; study 2's round 17, D337, deleting round 16's dropped outcome). A quote or a print off them is admitted, and counted by its `off_rules` row (A19). An observation's value may be any double: one that is not finite reads as undefined (A2).

### What a reader puts in a record

**Pinned here** (Argon's finding 3.2, round 7; revised round 8). A reader makes a record from the message a line holds, and from nothing of the line's envelope: not the time a frame or a pull was received, not the connection, not the request. An envelope's clocks are read only where a funding reply shows an hour (below) and where a criterion dates a pull (the vault's fills). **This section is the one statement of the readers' rules** (round 18): `briefs/4-study-2.md` derives the forward record's and `recorder/VAULT.md` the collector's, and each cites it.
- A quote's and a trade's `time` are the venue's stamp in the frame, and their `known` is `time + δ`.
- A row of `fundingHistory` is the funding record of its `coin` at its `time`, naming the hour that time floors to, with its `fundingRate` as X and no oracle price (`a` = 0). Its `known` is its `time` plus the header's funding `lag`, and `premium` is read by nothing. It is a settlement only with its request's `coin`, a `time` in the request's range and a rate A18 places. So one row that many pulls served is one record, and the reader counts the copies (A13).
- **Placed-decimal equality (round 8):** quotes' prices and sizes, trades' prices and sizes, and `fundingHistory` rates are compared as A18 placed decimals (trailing fractional zeros trimmed, so `"0.0001"` equals `"0.00010"` and `"5.0"` equals `"5"`). Two copies of one event that differ only in decimal trailing zeros, key order, whitespace, unread fields or their lines' envelopes are one item, counted.
- **A coin's rules are the header's** (round 20, in place of the listings copies of rounds 8 to 19): in the forward market the registration's, whose copy of the venue's listings also says which of the universe's coins are in the market, those it lists unflagged; nothing of a later copy, its rules or its flags, reaches a run. A later copy would be placed among the matching engine's events by clocks that are not the engine's: ahead of the move it reports, it sizes an order by that move (8.52% against the 5% on a fair market: Neon on study 2's rounds 18 and 20; GPT on its round 19); late, it rolls newer rules back. A rule the venue changes after the registration costs the replica fidelity and nothing else (`kernel-v2.md` V3).
- **An hour the venue did not settle** (study 2's round 20; by hours, a day past, round 20). For each universe coin and whole hour `H` with `w_start ≤ H` and `H + late < w_end`, before its listing's end, that no settlement in the record names and that a whole reply in the record of `H` shows, the reader feeds an **unsettled hour**: a funding record of the coin naming `H` with no rate (`a` = 2), timed `H + late`, known at that time plus funding's lag. It pays and moves nothing, and names its hour for funding's lateness. An hour neither settled nor shown is a **hole**: the reader feeds nothing of it, and the runner's horizon stops before it (`briefs/4-study-2.md`, step 7, wall 3).
  - **A reply shows `H`** of its coin when it is a whole reply of `fundingHistory` (a JSON array each of whose elements the reader reads as a settlement of its request's coin with a `time` in the request's range), its range holds the whole hour (`startTime ≤ H`, and where it has an `endTime`, `endTime ≥ H + 3,599,999`), it holds fewer than 500 rows or a row of a later hour than `H` (a page of 500 reaches its last row and no further), and its line's two clocks, the venue's `Date` (an IMF-fixdate, RFC 9110, section 6.6.1) and our `recv`, are each at or after `H + 25 h`. A `date` that is `null` or unreadable shows nothing, and a reply in a file outside the record of `H` shows nothing of `H`.
  - **Why a day.** The hours are the matching engine's, which neither clock of a reply keeps. A reply both place a day past an hour was made after the engine had finished it, unless both lead the engine by a day (`kernel-v2.md` V24): so it holds whatever either is off by, and for a copy of the venue's history up to a day old. A clock off the other way delays, and the collector asks for a missing hour again every day (`recorder/VAULT.md`). A failed pull leaves no reply; that one leaves out no settlement the venue made is V23, and a row any reply in the record holds outweighs the rest's silence.
- **A listing's end** (round 20, replacing study 2's rounds 14 to 20). A coin's listing ends at the first UTC midnight `M`, from `w_start + 24 h` on, whose day before it, `[M − 24 h, M)`, holds in the record no book or print of the coin, a book or a print of another coin, and 24 hours of the coin each of which **paid nothing:** settled at a rate of zero, or shown unsettled. A delisted coin goes on settling at a rate of zero, its book empty (the pilot, `audit/criteria.md`, stage 0), so an end is read from what it pays and never from silence alone, which a listed coin's record can show too (TON, facts §6; `kernel-v2.md` V25). The reader feeds the end at `M`, known there plus the listings' lag, and nothing of the coin stamped at or after `M`, a relisting's included: each is counted. The day is over at `M`, so an end reads nothing after it and no clock, and a replay that stops at `M` feeds none where one that runs on feeds it first, after that day's end: every replay that runs past `M` feeds the same, and no month is given to the reader. A flag, a withdrawn flag and a relisting within the day are what the rows say of them. A held coin's cash waits a day or two: power, and no claim.
- **The record of a time** (study 2's round 19, D346): an item is read only where its line's file's `since`, which the runner gives from its capture's table, is at most the second month after the UTC month of its time, and any other is counted and not fed. Its time is a book's or a print's stamp, a settlement row's `time`, and for a reply that shows it an hour's own.
- **The vault's fills** (brief 3, step 2; from `recorder/VAULT.md`, round 18): a fill is the fields the replay of given fills reads, parsed, its decimals placed as above, and nothing of its line's envelope; it is one item by its coin, `tid` and `oid`: elements of one key alike in those fields are one fill, counted, and two that differ are a **conflict** of the pull, which the reader reports with the pull wherever in it they stand (round 20; the criterion withholds on it before any chain is asked). A file is **one whole pull** only as far as its own bytes show (Neon's reads of rounds 14 to 17): its stream is complete; it holds at least one line; every line's `request` asks `userFillsByTime` of the vault with `aggregateByTime` false and no `endTime`; each later line's `startTime` is the `time` of the last element of the line before; every page but the last holds 2,000 elements and the last fewer, counted as the venue returned them, read or not; every element whose `time` the reader reads is at or after its page's `startTime` and not before the element before it whose `time` it reads; and the last element of every page but the last has a `time` the reader reads. A page is read element by element: an element the reader cannot read as a fill is reported with its `time`, or where it has none the reader reads, with the readable times on either side of it, and the page's other fills are read. Which pull judges CS2.3 (the earliest whole pull whose first reply was made, by its two clocks, 30 days after the 61 days), its count of distinct fills (an element the reader cannot read counting as one), and what withholds it are the criterion's (`briefs/4-study-2.md`, step 7, wall 5).

**What a reader reads.** Every file its capture hashes, whole, each checked against its hash before a line of it is fed, or what a host kept of it; a file is chosen by no name, which a host's clock wrote (D338). A stream is `complete`, `cut` (its bytes end inside it, as a killed run leaves it), `malformed` (ended cleanly inside a line) or `corrupt` (the decoder rejects a block or a frame header, or a checksum fails), as `recorder/RECORDER.md` (Compression) and `mmrec cat` give them: a cut or malformed stream gives its whole lines, and a corrupt one none, the lines before its fault included, counted (GPT on kernel round 18: a decoder's error read as a cut let a corrupt file's prefix through). The shared decoder returns the state and catches only the zstd stub's decode failure. **What a host keeps of a file** (study 2's round 19, D346): of `l2Book-fast` and `trades`, the lines holding a universe coin's item stamped at or after `w_start` and in the record of its time, whether or not a run's horizon reaches it (`briefs/4-study-2.md`, step 7, wall 3, reads one past its last midnight), and those `Coin_route.classify_line` cannot classify, in order, with the counts of the rest by channel, coin, day and cause and its stream's state, under the file's hash and a checksum of its own; of a corrupt stream, no line; of the other files, the file. A kept form is read as its file is, and one whose checksum fails is read again from its file. `Coin_route.classify_line`, the recorder's router (`recorder/RECORDER.md`), sorts each line of `l2Book-fast` and `trades` into one coin's or `Other`, and a line of a coin outside the universe is skipped unread and uncounted, in a file and in a kept form alike. A reader feeds only records with `w_start ≤ time < w_end`, and counts the rest. **It feeds them in one order** (round 18; GPT's finding 1 on study 2's round 19): A3's, by time, class, coin, kind and source, and records equal in all five in the order acquired, whatever order its files hold them in: for the recorder's files `recorder/RECORDER.md`'s run (numbered in the order runs began, whatever the wall clock did), hour file, line and place in the line. **A duplicate** takes the place of its first copy in that order among the copies in the record of its time, chosen before any horizon's prefix, and **the reader's own records** (a listing's end, an unsettled hour) tie with nothing fed, no two records sharing A3's five keys (study 2's round 20; GPT on kernel round 18). So the events a replay feeds before a time are the record's items stamped before it, in one order, whatever its horizon, and a file's disorder is no fault: fed in the order acquired, a print of March 2 written before one of February 20 would stop a replay that runs past March 2 and not one that stops in February. **One decoder (study 2's rounds 14 and 15):** every line a reader reads, and every line routing classifies, is decoded by `jsont` at the recorders' pin in three fixed passes on one text (`recorder/RECORDER.md`): (1) a depth count at 65 before `jsont` runs (a frame's or a reply's 64 and the stored line's envelope's one; study 2's round 16), so no decode can raise `Stack_overflow` (nothing catches it); (2) `Jsont.ignore` over the whole line (distinguishing whole wrong-shaped JSON from non-JSON); and (3) the typed decode with locations, every integer read from its own bytes by `-?(0|[1-9][0-9]*)` within its range, never from the float, and a member named twice decoded each time with the last kept. A line that holds no item (exceeds depth, not JSON, not its channel's shape, an out-of-range integer or a number A18 cannot place) is counted by channel and cause and feeds nothing. **Prints, one by one (study 2's rounds 16 and 17, D326 and D337):** a `trades` line is read print by print, each print an item or counted, so one print it cannot read among five feeds the four. A print is read by a rule that reads no coin's rules, which is the recorder's router's too: its coin, its side, its `time` and its `tid`, a `px` above zero that scale 8 places (at most 8 decimals, below `10⁷`) and an `sz` above zero that scale 6 places (at most 6, below `10⁹`). A book crossed, one-sided or not strictly best first, or with a price or a size that rule does not read, holds no item and is counted. The reader withholds no book: whether a coin's prints are being read is the recorder's to decide, which sees the socket's order and routes a coin's fast books away from `l2Book-fast` while they are not (`recorder/RECORDER.md`, Routing).

### The order of a millisecond

A3's order of events is `(time, class, coin, kind, source)`, and events equal in all five keep the order the reader fed them, which is the order acquired (What a reader puts in a record). `feed` rejects a record that is before its predecessor in that order.

- A bar stands where a trade would. It becomes its two prints, its quote and its five observations (A16), which no fed event of that coin and millisecond may precede or come between: a bar market has no other print or quote, and a declared source's observation comes after by its kind and its source.
- **Pinned here: all that happens in one millisecond,** in order, which R1 holds the run's records to (`kernel-v2.md` B3). First the fed events, as above, each with all it causes before the next (`kernel-v2.md` A12: a listing's end, a payment, its fills and first quotes, then the check). Then the tick, when the millisecond is one (A4). Then the wishes that arrive at it (A6), which are those of one tick, one a slot and coin: each does its case of A6's three, and the orders they place are admitted in A6's order, every `reduce_only` one first and then the others, each group by coin and slot. That order is also the order in which they take from the quote they arrive at (A7). So a wish sent at a tick with `λ = 0` arrives after that tick, and an order placed at `ℓ` comes after every event of `ℓ`, as A7's "first quote with `time > ℓ`" and L1b need. An order is admitted against the world of its own arrival, never that of its coin's next event. Then, last, the funding check below.
- **Pinned here: the view's order.** At a tick `τ` the view takes every event and effect with `known ≤ τ` that it has not taken, in the order of `known`, and those of one `known` in the order the world met or made them. That order is what "latest" and "in order of delivery" mean (A3). An effect made after a tick in the tick's own millisecond, as a wish's on arriving, is not yet made when the view is taken, and is taken at the next tick. That is seen only at `δ = 0`: at any other `δ` such an effect's `known` is after the tick.

### Funding's lateness

An hour `H` of a coin is **due** when `w_start ≤ H`, `H + late < w_end`, and the coin's listing has not ended by `H + late` (round 20: an end inside the lateness leaves the hour undue, so no hour falls between an end and the record that would name it). A coin is **held into** `H` when its listing has not ended by `H` and its position is not zero after every event with `time < H`. If a coin is held into a due hour and no funding record of it names `H`, a settlement or an unsettled hour (What a reader puts in a record), the run aborts with `R_SETTLEMENT_MISSING`, at the end of the millisecond `H + late`, which `finish` completes for the last hours.

- The payment itself is A9's: at the event's `time`, on the position the world holds at the event, which may differ from the position held into the hour. An unsettled hour pays nothing.
- An hour within `late` of the horizon's end is not due: its event may lie beyond the market. If it is there it is paid.
- An event later than `late` is refused by `feed` (above) and not paid late. The registered lateness is then too short, and registering a longer one is a new identity.

## A19. The rows

The engine writes two texts, the **report** and the **trace** (A12), and writes every byte of them: `feed` and `finish` return the lines of the timestamps they completed, and OCaml moves those bytes to the spool and formats nothing. `confirm` and `guard` read the same texts back. So the rows a study is judged on are never printed or parsed outside Lean.

- **A row is a line,** ended by a line feed, its fields separated by one tab, the first naming its kind. ASCII. No heading line: this section is the heading.
- **Rows are in the machine's order** (A18): an event's rows, then the rows of what it caused, in the order the world did them.
- **A field** is one of:

  | Sort | Written |
  |---|---|
  | time, count, id | a whole number in decimal; a time in milliseconds |
  | coin, slot, tier, a word | the name, the opaque one under aliases |
  | exact | the rational in lowest terms: `n`, or `n/d` with `d` from 2 |
  | float | its 64 bits as 16 hexadecimal digits, lower case |
  | bool, mark | `1` or `0` |
  | undefined, or not applicable | `-` |

### The report

**A day's end** is a UTC midnight `T` with `w_start < T ≤ w_end`. Its rows show the world after every event with `time < T`, and stand before any row of an event at `T`: the `coin` rows of the day, then the `account` row. `confirm` and `guard` both give a day's end its wealth at these rows' prices, so neither reads an event or a tick at `T` into the day that ended there, and a run whose horizon ends at `T` gives the day what a longer run gives it. **The last span ends at the horizon's end,** so every span has rows at its end, written by `finish` for the last, after the last day's.

**A span is read from one row a coin.** At a day's end the bar is a product over spans (K2): a span that ended takes its `span` rows, which stand before that day's rows, and the span open there takes that day's `day` rows. A span's `span` rows that stand after a day's rows are not that day's, at one timestamp or not, so the last span is never counted twice at the horizon's end.

| Kind | Fields, after the kind | When |
|---|---|---|
| `flow` | `time`, `coin`, `what`, `cycle`, `units`, `cash`, `fee`, `before`, `price` | each cash flow, at its event |
| `coin` | `time`, `coin`, `span`, `at`, `price`, `bid`, `quoted`, `first`, `events`, `least`, `funding`, `sum1`, `sum2`, `sum3` | each of the span's coins, in coin order, at each day's end and at the span's end |
| `account` | `time`, `equity`, `absorbed`, `funding`, `long`, `short`, `near`, then for each coin of the header `stale`, `open` | each day's end, after that day's `coin` rows |

**`flow`:**
- `what` is `fill` (an order's), `liquidation`, `settlement`, `funding` or `absorbed`. An absorption has no coin and no cycle.
- `cycle` counts the coin's cycles from 1 (A5).
- `units` is what the row bought, below zero for a sale, and zero for a payment. `cash` is the change in the account's cash, the fee inside it; `fee` is the fee alone. So starting cash plus the rows' `cash` is the world's cash, and a coin's `units` sum to its position (P1).
- A fill's price and fee rate are not fields: a second copy could disagree with the cash. K1's ledger needs two numbers of a fill and divides by nothing but its units, which are never zero: what a unit cost or brought with its fee, `−cash / units`, and for a buy its notional before the fee, `−(cash + fee)`. A trade at the row's price and fee rate is a trade at that cost a unit, which for a fill at several prices is their mean and need not be a decimal (`kernel-v2.md` A12).
- A `funding` row is written at every settlement of a held coin, a payment of zero included, and what a unit paid is `−cash / before`. An unsettled hour pays nothing and has no row.
- `before` is the coin's position before the row. `price` is the coin's price after the row's event.

**`coin`:**
- `span` counts spans from 1. `at` is `day` or `span`, the row's occasion; a span that ends at a midnight has both rows, read as above.
- `price` is the coin's price, and `first` its first in the span: its price at the span's start, or its first after. Both are undefined before the coin's first quote.
- `bid` is the best bid of the coin's latest quote, and `quoted` that quote's `time`. Both are undefined before the coin's first quote. A print moves the price and neither of these, and a listing's end moves neither (study 2's round 14: it holds no price). The coin's bid price (A12) is not a field: it is the lesser of `bid` and `price`, which K1 takes, and a second copy could disagree with them.
- `events`, `least`, `funding`, `sum1`, `sum2`, `sum3` are A12's, since the span began: the count of price events; the least of their returns and zero; the funding a unit paid; the sums of the returns, of their squares and of their cubes.

**`account`:**
- `absorbed`, `funding` and `near` are totals since the horizon's start: what was absorbed, the funding paid less that received, and A7's count of taker fills near an earlier one.
- `long` and `short` are notionals at prices, each at least zero.
- **Pinned here:** a millisecond's state is the world's after everything in it (A18, the order of a millisecond). So a millisecond is stale for a coin when no quote of the coin has a time in the `G` milliseconds that end with it: the millisecond of the quote that ends a gap is not, though a print before that quote in it is (A3). `stale` is the share of the day's milliseconds, those inside the horizon, that are stale; `open` is 1 when the coin had a position or a live order at the end of a stale millisecond: what the account had open across the staleness, as A3 says, which a mark over the whole day could not show (GPT's finding 4, the last pass's round 1). A state within a millisecond would count a fraction of one, which no field can hold (Argon's finding 5.3, the last pass's round 3). Both are `-` for a coin whose listing ended before the day began.

### The trace

| Kind | Fields, after the kind | When |
|---|---|---|
| `print` | `time`, `coin`, `id`, `side`, `price`, `size`, `stale` | every print; `side` is the aggressor's, `stale` the world's mark (A3) |
| `off_rules` | `time`, `coin`, `kind`, `cause` | every admitted quote or print off its coin's rules, one row an event, after a print's own: `kind` is `quote` or `print`, `cause` `grid` where a price is off the grid, else `lots`, a size that is no whole number of lots; V1's and V3's witness counted (study 2's round 17, D337), which moves nothing |
| `funding` | `time`, `coin`, `hour`, `unit` | every settlement; `unit` is what a unit long paid: the rate times the event's oracle price, or with none the coin's price (A9), and `-` where that is undefined, before the coin's first quote. An unsettled hour, which pays nothing, has no row |
| `end` | `time`, `coin`, `price` | every listing's end, with the coin's price there, `-` where it has none; its position closed at its adverse price (`fill` row, `what` of `settlement`) |
| `tick` | `time`, `coin`, `price`, `world`, `view`, then each probe in the program's order | every tick, for each coin in view (A17), in coin order; `world` and `view` are the two stalenesses |
| `placed` | `time`, `coin`, `slot`, `cycle`, `side`, `tif`, `reduce`, `price`, `target`, `remainder` | an order placed; `target` is `close` for one |
| `refused` | `time`, `coin`, `slot`, `cycle`, `reason` | `margin`, `minimum` or `cap` at admission (A6); `post_only` at arrival (A7) |
| `cancelled` | `time`, `coin`, `slot`, `cycle`, `cause` | `replaced`, `inactive`, `ioc`, `cycle_end`, `listing_end` or `liquidation` |
| `fill` | `time`, `coin`, `slot`, `cycle`, `what`, `role`, `tier`, `rate`, `price`, `units`, `fee`, `print` | every fill of the three kinds, one row each however many levels it took (`kernel-v2.md` A7, A12); `price` is its notional over its units; `role` is `maker` or `taker`; `print` is the id of the print that filled a resting order, else `-`; a liquidation's and a settlement's have no slot |
| `paid` | `time`, `coin`, `position`, `cash` | a funding payment of the account |
| `liquidated` | `time` | a liquidation, before its fills |
| `bankrupt` | `time`, `absorbed` | a bankruptcy |
| `cycle_end` | `time`, `coin`, `cycle` | a cycle's end |

The rows from `placed` down are the effects (A1), one row for each, and every effect has one. A bar market's derived prints have the ids 1 and 2 of their bar's end.

### The summary

`finish` returns, with the last rows, how the run ended: completed, with the figures below, or the fault that rejected or aborted it. The summary is that outcome as one JSON object, written by one function: `{"ok": true, "equity": exact, "report": lines, "trace": lines}`, the counts being of the whole run (OCaml adds its readers' dropped counts beside it in the result row, A13); or `{"error": code, "time": t, "detail": text}` for a market rejected or a run aborted. Beside it the result carries the outcome as a flag, true exactly when the run completed: OCaml publishes by the flag and never by reading the text, and every law that speaks of completion reads the same flag (`kernel-v2.md` B2; L0, C1, C2, L1a). After an error OCaml writes no report and no trace, whatever the spool holds (C2, W1).

