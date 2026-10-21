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

So the laws are expressible. A faithful port of the model's machine and simulator, and the proofs of
L1, L4 and L5 over it, are the remaining work.
