# Bend L5: the translated theorem and its audit (C6.3 acceptance rule)

- **Translation:** `bend PROOF.bend -o PROOF.bendtt` at commit `69e91e0` (2026-10-23, the pinned Bend 2.0.37), the BendTT form
  that `--verdict` re-checks. Archived as `bend-l5-PROOF.bendtt`, sha256 `cef0c8e45e8538f442f295605867c0c548e938e43d9df8b837b06f3521ba52ff`.
- **The verdict:** `bend-l5-verdict.txt` (ALL PROOFS CHECK, exit 0).

## The translated statements

```
LAWS.L5_binding : ∀+x0 : machine.Program -> ∀+x1 : sim.Market -> ∀+x2 : sim.Venue -> ∀+x3 : sim.Policy -> ∀+x4 : num.Z -> {(LAWS.run_unav +(sim.run +x0 +x1 +x2 +x3 +x4)) == (Bool.not (sim.bound +(sim.make +x0 +x1 +x2 +x3 +x4))) : Bool} =
LAWS.L5_preflight : ∀+x0 : sim.Ctx -> {(sim.start +x0) == (Bool.pick -sim.SRes (sim.bound +x0) (sim.ticked +x0 +(sim.pol_start +(sim.ctx_pol +x0)) +(sim.deliver +x0 +(sim.state0 +x0) +(num.zadd +(sim.pol_start +(sim.ctx_pol +x0)) +(sim.pol_delta +(sim.ctx_pol +x0))))) (.sim.SErr, ((.sim.InputUnavailable, ()), ()))) : sim.SRes} =
```

## Audit against the frozen law (`reference/lean/Ref/Laws.lean`, `L5_binding`)

- **First conjunct.** Lean: `run … = .error .inputUnavailable ↔ ∃ s ∈ p.eventSlots, s ∉ m.bound`. Bend:
  `run_unav (run …) == not (bound (make …))`, where `sim.bound` holds exactly when every event slot the program
  names is bound. The two are the same statement, with the existential negated into "not all bound".
- **The other two conjuncts.** Lean: with a source unbound, `start` aborts as unavailable; with every source
  bound, `start` is the first delivery and tick. Bend's `L5_preflight` states both in one equation:
  `start ctx == pick (bound ctx) (ticked … (deliver … state0 (wStart + δ))) (SErr InputUnavailable)`.
- **Differences.**
  - Bend drops Lean's `CheckerAccepted p` hypothesis, which L5's proof does not use, so its statement is
    stronger.
  - It is stated over one concrete exact number type (`num.Z`), not every `NumOps`, so its scope is narrower
    (`bend.md`).
  - The Bend model's definitions were ported from the Lean model definition by definition and audited by hand,
    not mechanically.
