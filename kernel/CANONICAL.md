# Equivalence key (stage 4)

The strategy hash of stages 0–3 is unchanged. The equivalence key is a second, versioned identity:
1. Build the `weight` DAG as an `egg` term. Each node is a symbol plus children: `input/close`,
   `const/<f64 bits hex>/<unit>`, `param/<name>/<unit>`, `lag/<hours>`, `convert/<factor bits hex>`,
   and the op names of DSL.md otherwise.
2. Saturate with the rule set R below, with deterministic limits (30 iterations, 20,000 nodes,
   no time limit).
3. Extract the term of fewest nodes, ties broken by its serialization (a total order).
4. The key is sha256 of `R_VERSION`, a newline, and the extracted serialization.

A statistical trial is (equivalence key, parameter values). The prediction condition is not
part of the key.

## Semantics the rules must respect

IEEE-754 binary64 with signed zeros; undefined values propagate through every operation except
the unselected branch of `if`; every node is evaluated at every tick, so windows inside either
branch of an `if` see every tick; `min`/`max` are Rust's `f64::min`/`f64::max`; comparisons
yield 1.0 or 0.0, and `and`/`or`/`not` treat any nonzero as true.

## R (version 1)

| Rule | Why it is exact |
|---|---|
| `neg(neg x) → x` | Negation flips only the sign bit; twice restores every bit, including on zeros; undefined stays undefined. |
| `abs(abs x) → abs x` | `abs` clears the sign bit; clearing it twice is the same. |
| `abs(neg x) → abs x` | `neg` flips the sign bit, `abs` then clears it. |
| `mul(x, const 1 [1]) → x` | IEEE x · 1 = x exactly, including −0 · 1 = −0. The constant has unit 1, so the unit is unchanged. |
| `div(x, const 1 [1]) → x` | x / 1 = x exactly, including on zeros. The divisor is nonzero, so no undefined value appears. |
| `sub(x, const +0 [u]) → x` | x − (+0) = x exactly, including −0 − (+0) = −0. The constant has x's unit, as type checking already requires. |
| `add(a, b) ↔ add(b, a)` | IEEE addition is commutative bit for bit, including signed-zero results; undefined if either is undefined. |
| `mul(a, b) ↔ mul(b, a)` | The same for multiplication. The result's unit, the sum of exponents, is symmetric. |
| `and(a, b) ↔ and(b, a)`, `or(a, b) ↔ or(b, a)` | Both are evaluated strictly, with an undefined argument giving undefined, so order is irrelevant. |
| `not(not c) → c` | c is boolean (1.0 or 0.0) by typing, so `not` twice returns the same value; undefined stays undefined. |
| `if(not c, a, b) ↔ if(c, b, a)` | The same branch is selected for every defined c; an undefined c gives undefined either way; both branches are evaluated every tick in both forms. |
| `gt(a, b) ↔ lt(b, a)`, `ge(a, b) ↔ le(b, a)` | The same comparison of the same two finite values. |

## Rejected laws, with counterexamples

| Law | Counterexample under the kernel's semantics |
|---|---|
| `add(add(a, b), c) = add(a, add(b, c))` | a = 1e16, b = −1e16, c = 1 gives 1 versus 0. |
| `mul(a, add(b, c)) = add(mul(a, b), mul(a, c))` | Rounding: a = 0.1, b = 0.2, c = 0.3. |
| `add(x, const 0) = x` | x = −0 gives +0. |
| `min(a, b) = min(b, a)`, `max(a, b) = max(b, a)` | With a = −0 and b = +0, `f64::min` may return either. |
| `if(c, x, x) = x` | When c is undefined, the left side is undefined and the right is not. |
| `and(false, c) = false` | When c is undefined, the left side is undefined. |
| `xs_demean(xs_demean x) = xs_demean x` | For [1, 2, 4], the first pass leaves a mean of about −1.5e-16. |
| `convert(convert(x, 1/y), 1/h) = x` | 0.9452706955539223 · 8760 / 8760 = 0.9452706955539222. |
| `lag(x, a)` reordered with `mean`, `xs_*` | Running-sum recompute epochs and listed-coin membership differ. |
| `neg(sign x) = sign(neg x)` | x = 0 gives −0 versus +0. |
