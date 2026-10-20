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
body. So a Bend model can be written only for a concrete number type, and Bend's own `F32` is the
nearest to the engine. Laws over that instance are weaker than the frozen statements, which quantify
over every N, and C6.3's acceptance rule does not count a weaker statement. Under this toolchain,
Bend's accepted law count is therefore 0 by construction. This is a C6.5 comparison finding
(expressiveness and checker trust), alongside Bend's lack of binary64, which bars it from C6.4.
