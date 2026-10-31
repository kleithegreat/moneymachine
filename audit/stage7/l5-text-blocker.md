# L5_text proof blocker — 2026-10-30 18:29 UTC (14:29 EDT)

The frozen statement and definitions have not been changed. This is a missing logical interface, not a demonstrated runtime counterexample.

`Ref/Spec.lean:217` declares `Json.Value.mentions` with `partial def`. Lean exports this as

```lean
opaque Ref.Json.Value.mentions : String → Ref.Json.Value → Bool
```

There are no recursion equations available to proofs (`Ref.Json.Value.mentions.eq_def` is unknown). A capped `lake env lean` probe importing `Ref.Spec` confirms both facts. No existing theorem characterizes `mentions` elsewhere in the reference.

`InputRef` uses that opaque Boolean to assert that a name occurs in a weight, let body or prediction condition. `check` and its expression compiler never call `mentions`. Consequently the frozen proof interface supplies no connection between `hR : InputRef text name` and the expressions the checker compiles. Even the base cases of the occurrence traversal cannot be unfolded in a kernel proof. This is different from the partial JSON parser: the checker and `InputRef` share the same parser result, so a proof can reason conditionally on that result without proving the parser's internals.

An arbitrary Boolean occurrence oracle is not sufficient: an oracle reporting an input in a constant-only expression would make the desired implication fail when the input's source is unbound, is not a role provider, and is not in their dependency closure. The executable traversal is intended to rule that out, but its `partial` implementation supplies no such logical fact.

Proposed redesign, requiring a dated frozen-definition revision **before** any dependent proof: replace `mentions` with the same traversal as a total, terminating definition (with structural/well-founded recursion over JSON values and their children), exposing its recursion equations. Then prove that checker compilation retains every referenced input and that registry closure includes its source. Do not add an axiom, assume the desired implication, use an unchecked runtime decision as a proof, or weaken `L5_text`.

Stopped on `L5_text`. It remains admitted by its original `sorry`; no new admission or frozen-definition change was made.

2026-10-31 02:50 UTC (22:50 EDT 2026-10-30): superseded by the dated revision in `laws-frozen.md`. The claim above that sharing the parser result lets a proof avoid the parser's internals was wrong: the duplicate-key refusal had to leave the opaque parser too.
