# Equivalence key (stage 4)

Rationale and bit-exactness arguments: `docs/whitepaper.tex`, appendix A.3, K2–K3
(`app:rewrites`, `app:kernel-checks`). This file defines the implemented key and rule set.

The strategy hash of stages 0–3 is unchanged. The equivalence key is a second, versioned identity:
1. Build the `weight` DAG as an `egg` term. Each node is a symbol plus children: `input/close`,
   `const/<f64 bits hex>/<unit>`, `param/<name>/<unit>`, `lag/<hours>`, `convert/<factor bits hex>/<unit>`,
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

| Rule | Side condition |
|---|---|
| `neg(neg x) → x` | well-typed |
| `abs(abs x) → abs x` | well-typed |
| `abs(neg x) → abs x` | well-typed |
| `mul(x, const 1 [1]) → x` | dimensionless constant 1 |
| `div(x, const 1 [1]) → x` | dimensionless constant 1 |
| `sub(x, const +0 [u]) → x` | constant +0 of x's unit u |
| `add(a, b) ↔ add(b, a)` | well-typed |
| `mul(a, b) ↔ mul(b, a)` | well-typed |
| `and(a, b) ↔ and(b, a)`, `or(a, b) ↔ or(b, a)` | Bool operands |
| `not(not c) → c` | c is Bool |
| `if(not c, a, b) ↔ if(c, b, a)` | c is Bool; branches have identical types |
| `gt(a, b) ↔ lt(b, a)`, `ge(a, b) ↔ le(b, a)` | well-typed |

Only R above is admitted; excluded-law counterexamples are in paper K2 (`app:rewrites`).
