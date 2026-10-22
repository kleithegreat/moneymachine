# Bend 2.0.37: can the stage 6 laws be stated?

The frozen laws (PROGRESS.md, Stage 6) quantify over every number structure N: the model's number
operations are parameters, and the laws hold for each. In the pinned Bend 2.0.37 this quantification
cannot be stated in a form that `bend --verdict` accepts. Each file here reproduces one step of that
(`nix develop -c bend FILE [--verdict]`).

| File | What it tries | Result |
|---|---|---|
| `affine_operation.bend` | An abstract operation `f: N -> N -> N`, a parameter, used twice, as every model function would use add or compare | Refused: `f (consumed more than once)`. Functions are `Type`, never `Data`, so they cannot be copied, and closures are affine. |
| `template_law.bend` | The operation as a template parameter (`~f`), with the law quantified over it | The everyday checker accepts it. `--verdict` refuses: "a mismatch between the TypeScript implementation, and the formalized BendTT kernel ... we cannot validate them yet". |
| `first_order_law.bend` | An ordinary first-order law over `Nat` | Both checks pass (ALL PROOFS CHECK). |

An erased parameter (`-f`) can appear only in types and proofs, never in a model function's running
body, so a Bend model must use a concrete number type.

## Over a concrete type (human decision, 2026-10-21)

L1, L4 and L5 are structural, so they are stated over a concrete exact number type instead. The verdict
kernel accepts structural induction over concrete `Data` types: `concrete_binding.bend` models an
L5-shaped run (a preflight over list membership, then a step loop that may fail with another error)
and proves that it fails as unavailable exactly when a slot is unbound. `bend concrete_binding.bend
--verdict` prints ALL PROOFS CHECK. What the toolchain requires of such a model:

- matches follow parameter order, so each function takes the value it splits first;
- `Data` arguments a proof uses more than once are marked `+`, in laws as in code;
- Base's list functions are templates, which `--verdict` refuses in laws, so the model uses its own
  monomorphic recursions.

So the laws are expressible.

## The port (2026-10-22)

`model/` ports the Lean model's machine and simulator definition for definition: `num.bend` (the number type),
`bin.bend`, `machine.bend` and `sim.bend`. `LAWS.bend` states the laws over it, and `PROOF.bend` proves them.
What the toolchain forced:

- **Binary magnitudes.** `Nat` is unary, both in the checker and at run time. Times are milliseconds and some
  constants are 64-bit words, and expanding those overflowed the checker's stack. Magnitudes and times are
  therefore binary naturals (`bin.bend`), and constants are assembled from bytes. The model still cannot run on
  real data (it was killed for memory on a one-coin smoke run), so it is a proof model only. That agrees with C6.4's
  revision.
- **No match on a computed value.** Every `if` on a computed condition is a `Bool.pick` or a helper def. A proof
  through it passes that condition explicitly, since Bend infers no arguments.
- **Matches in parameter order**, and no mutual recursion. The cursor walks compute the next state eagerly and
  combine it with the error afterwards, which gives Lean's early exit.
- **Stable insertion sort** for the delivery orders, and last-insert-wins association lists for the index's
  HashMaps. Both give the same results as Lean's mergeSort and HashMap.

**L5 is proved** (`bend model/PROOF.bend --verdict`: ALL PROOFS CHECK).
- `L5_binding`: a run is refused as unavailable exactly when some event slot the program reads is unbound.
  The Lean statement's unused `CheckerAccepted` hypothesis is omitted, so this is stronger.
- `L5_preflight`: the start is that refusal or the ordinary first delivery and tick.
- The proof threads one fact through every function of the step: a result is never the unavailable refusal
  unless its input was.

**What L1 and L4 need next (2026-10-22).** L5 needed no arithmetic. Every remaining law does:
- L1_simulator equates a step's tick at (wStart + j·BAR) + k·HOUR with the hourly schedule's tick at
  wStart + (4j + k)·HOUR. The machine stores the hour, so equal values must be equal terms.
- L1_values needs the delivery orders to be sorted, which needs the order on times to be transitive and total.
- L4_orders needs decision times to be strictly increasing.
- L4_fills contains L1_simulator's clause.

In Lean these facts came from `Int`. Base has no integers, so Bend first needs a verified integer library over
canonical binary naturals: no leading zeros, with associativity, commutativity and distributivity of addition and
multiplication, and an order that is transitive and total. Only then can those law proofs start. The library is
a project of its own, several thousand lines of proof terms with no tactics.
