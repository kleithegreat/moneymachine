# Stage 6: the Bend reference kernel (C6.3 and C6.5's Bend column)

Bend 2.0.37, pinned in the flake. The work stopped at L5 by human decision on 2026-10-22, and was then
deleted from the tree per paper §6. The final state is commit `7ffc32c`, and the proved port is `69e91e0`.
`git show 7ffc32c:reference/bend/FINDINGS.md` has the findings and their reproductions.

## Laws (C6.3)

| Law | Result |
|---|---|
| L5 binding (`L5_binding`, `L5_preflight`) | Proved, `bend model/PROOF.bend --verdict`: ALL PROOFS CHECK. Stated over the concrete number type below, and stronger than the frozen statement, since the unused checker hypothesis is dropped. |
| L1 (values, simulator, decisions) | Not proved. Each needs integer arithmetic first (equal times as equal terms, sorted delivery orders), so a verified integer library would have to come first. Not attempted. |
| L4 (fills, orders) | Not proved, for the same reason: increasing decision times, and L1_simulator's clause in L4_fills. |
| L2, L3 | Out of scope for Bend (human decision of 2026-10-21: L1, L4 and L5). |

## Findings

- **No abstract numbers.** Over an abstract number structure the frozen laws cannot be stated in a form
  `--verdict` accepts: functions are affine and never `Data`, erased parameters cannot run, and laws over
  template operations are refused (`761e2e5`). The laws were therefore stated over one concrete exact number
  type: integers with a sign bit, infinities and NaN, and every operation total. This is weaker than Lean's
  laws, which hold for every `NumOps`.
- **No integers.** Base has only unary `Nat`, `U32` and `F32`. Unary `Nat` overflowed the checker's stack on the
  model's 64-bit constants (millisecond times, the engine's tolerances), so magnitudes became hand-written
  binary naturals. They have no verified arithmetic, which is what L1 and L4 would need.
- **No binary64.** C6.4's exact comparisons are impossible. The model is also too slow to run on real data:
  a one-coin smoke run reached 8.7 GB and was killed by the OOM killer. It is a proof model only.
- **Language constraints, worked around.** No match on a computed value, so every computed condition becomes a
  `Bool.pick` or a helper, and proofs pass those conditions explicitly, since nothing is inferred. Matches go
  in parameter order. There is no mutual recursion. Variables are affine (`+` to reuse).

## Effort

| Milestone | Elapsed | Commit |
|---|---|---|
| Expressiveness finding (abstract numbers) | 2026-10-19 | `761e2e5` |
| Concrete-type probe | 2026-10-20 | `a624ddc` |
| Machine port (≈ 880 lines) | 2026-10-22, about 1.5 h of agent time | `dedfffa` |
| Simulator port (≈ 1,400 lines) | 2026-10-22, about 1 h | `2fb8517` |
| L5 proof (≈ 600 lines, after moving to binary magnitudes) | 2026-10-22, about 1 h | `69e91e0` |

## C6.4 and C6.5

Bend is not eligible: it has no binary64, so it cannot pass C6.4, and it has one of the five laws. Lean, with
every law proved (`audit/stage6/lean-axioms.txt`), is the reference kernel.
