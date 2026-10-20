import Ref.Spec
import Ref.Proof.Except

/-! The instrumented evaluation of one node against the executable one (L2): on a well-formed program with
tagged arguments it never raises a unit error, its tag is the node's static type, and erasing it gives the
executable value. -/

namespace Ref
variable {α : Type} [Inhabited α]

/-- Tagged values carry their nodes' static types, and booleans are canonical. -/
def Tagged (N : NumOps α) (p : Program) (tv : Array (Array (TVal α))) : Prop :=
  ∀ (j c : Nat) (x : α) (t : Ty), tv[j]![c]! = some (x, t) → t = p.types[j]! ∧ (t = Ty.bool → ∃ b, x = N.truth b)

def eraseTV (tv : Array (Array (TVal α))) : Array (Array (Val α)) := tv.map (·.map (·.map (·.1)))

omit [Inhabited α] in
theorem eraseTV_get (tv : Array (Array (TVal α))) (j c : Nat) :
    (eraseTV tv)[j]![c]! = (tv[j]![c]!).map (·.1) := by
  unfold eraseTV
  by_cases hj : j < tv.size
  · rw [getElem!_pos _ j (by simpa using hj), getElem!_pos tv j hj, Array.getElem_map]
    by_cases hc : c < tv[j].size
    · rw [getElem!_pos _ c (by simpa using hc), getElem!_pos _ c hc, Array.getElem_map]
    · rw [getElem!_neg _ c (by simpa using hc), getElem!_neg _ c hc]; rfl
  · rw [getElem!_neg _ j (by simpa using hj), getElem!_neg tv j hj]; rfl

theorem discard_none {β : Type} : (discard (none : Option β) : Option PUnit) = none := rfl

omit [Inhabited α] in
theorem truth_cases (N : NumOps α) (b : Bool) : N.truth b = N.truth false ∨ N.truth b = N.truth true := by
  cases b <;> simp

theorem discard_some {β : Type} (u : β) : (discard (some u) : Option PUnit) = some ⟨⟩ := rfl

set_option maxHeartbeats 10000000 in
omit [Inhabited α] in
theorem evalU_op (N : NumOps α) (p : Program) (m : MState α) (tv : Array (Array (TVal α))) (i c : Nat)
    (o : Op) (args : List Nat) (hn : p.nodes[i]! = .op o args) (ty : Ty)
    (hty : opTy o (args.map (p.types[·]!)) p.convTo[i]! = some ty) (hT : Tagged N p tv)
    (ho : o ≠ .xsMean ∧ o ≠ .xsDemean ∧ o ≠ .xsRank ∧ o ≠ .hoursSince) :
    ∃ r, evalU N p m tv i c = .ok r ∧ r.map (·.1) = MState.eval N p { m with vals := eraseTV tv } i c ∧
      ∀ x t, r = some (x, t) → t = ty ∧ (t = .bool → ∃ b, x = N.truth b) := by
  simp only [evalU, MState.eval, hn, eraseTV_get]
  rcases args with _ | ⟨a0, _ | ⟨a1, _ | ⟨a2, rest⟩⟩⟩ <;>
    simp only [List.map_cons, List.map_nil, List.getElem!_cons_zero, List.getElem!_cons_succ] at hty ⊢
  all_goals cases o <;> simp at ho
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

omit [Inhabited α] in
theorem evalU_leaf (N : NumOps α) (p : Program) (m : MState α) (tv : Array (Array (TVal α))) (i c : Nat)
    (hW : p.WF) (hi : i < p.nodes.size) (hn : ∀ o args, p.nodes[i]! ≠ .op o args) :
    ∃ r, evalU N p m tv i c = .ok r ∧ r.map (·.1) = MState.eval N p { m with vals := eraseTV tv } i c ∧
      ∀ x t, r = some (x, t) → t = p.types[i]! ∧ (t = .bool → ∃ b, x = N.truth b) := by
  have h := hW.2.2.2.2.2 i hi
  cases hn' : p.nodes[i]! with
  | op o args => exact absurd hn' (hn o args)
  | input inp =>
    simp only [hn'] at h
    refine ⟨(m.input inp c).map (·, .num inp.unit), by simp only [evalU, hn']; rfl, ?_, ?_⟩
    · simp only [MState.eval, hn', Option.map_map]; cases inp <;> simp [MState.input, Function.comp_def]
    · intro x t hx; simp at hx; obtain ⟨_, _, _, rfl⟩ := hx; simp [h]
  | const bits u =>
    simp only [hn'] at h
    exact ⟨some (N.ofBits bits, .num u), by simp only [evalU, hn']; rfl, by simp [MState.eval, hn'],
      fun x t hx => by simp at hx; obtain ⟨_, rfl⟩ := hx; simp [h]⟩
  | param k =>
    simp only [hn'] at h
    exact ⟨some (N.ofBits p.params[k]!.1, .num p.params[k]!.2), by simp only [evalU, hn']; rfl,
      by simp [MState.eval, hn'], fun x t hx => by simp at hx; obtain ⟨_, rfl⟩ := hx; simp [h.2]⟩

end Ref
