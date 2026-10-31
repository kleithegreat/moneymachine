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

end Ref
