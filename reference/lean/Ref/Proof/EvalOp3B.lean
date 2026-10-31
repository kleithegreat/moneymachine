import Ref.Proof.EvalBase

namespace Ref
variable {α : Type} [Inhabited α]

set_option maxHeartbeats 10000000 in
omit [Inhabited α] in
theorem evalU_op3B (N : NumOps α) (p : Program) (m : MState α) (tv : Array (Array (TVal α))) (i c : Nat)
    (o : Op) (a0 a1 a2 : Nat) (rest : List Nat) (hn : p.nodes[i]! = .op o (a0 :: a1 :: a2 :: rest)) (ty : Ty)
    (hty : opTy o ((a0 :: a1 :: a2 :: rest).map (p.types[·]!)) p.convTo[i]! = some ty) (hT : Tagged N p tv) (he : o = .neg ∨ o = .abs ∨ o = .sign ∨ o = .log ∨ o = .exp ∨ o = .sqrt ∨ o = .not)
    (ho : o ≠ .xsMean ∧ o ≠ .xsDemean ∧ o ≠ .xsRank ∧ o ≠ .hoursSince) :
    ∃ r, evalU N p m tv i c = .ok r ∧ r.map (·.1) = MState.eval N p { m with vals := eraseTV tv } i c ∧
      ∀ x t, r = some (x, t) → t = ty ∧ (t = .bool → ∃ b, x = N.truth b) := by
  simp only [evalU, MState.eval, hn, eraseTV_get]
  simp only [List.map_cons, List.map_nil, List.getElem!_cons_zero, List.getElem!_cons_succ] at hty ⊢
  all_goals cases o <;> simp at ho he
  all_goals revert hty
  all_goals (try cases h0 : p.types[a0]!) <;> (try cases h1 : p.types[a1]!) <;> (try cases h2 : p.types[a2]!)
  all_goals intro hty; replace hty := hty.symm; simp [opTy, discard_some, discard_none] at hty
  all_goals (try rcases hv0 : tv[a0]![c]! with _ | ⟨x0, t0⟩) <;> (try rcases hv1 : tv[a1]![c]! with _ | ⟨x1, t1⟩) <;>
    (try rcases hv2 : tv[a2]![c]! with _ | ⟨x2, t2⟩)
  all_goals (try obtain ⟨rfl, hb0⟩ := hT a0 c x0 t0 hv0)
  all_goals (try obtain ⟨rfl, hb1⟩ := hT a1 c x1 t1 hv1)
  all_goals (try obtain ⟨rfl, hb2⟩ := hT a2 c x2 t2 hv2)
  all_goals clear hT
  all_goals simp_all [pure, Except.pure, bind, Except.bind, discard_some]
  all_goals (try split) <;> (try simp_all [truth_cases])
  all_goals (try split) <;> (try simp_all [truth_cases])


end Ref
