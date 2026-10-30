import Ref.Proof.Checker.Hoare

/-! `typeOp` agrees with `opTy`. -/

namespace Ref

variable {ok : Input → Prop}

theorem StateT.ite_run {σ : Type} {m : Type → Type} {β : Type} {c : Prop} [Decidable c] (x y : StateT σ m β) (s : σ) :
    (if c then x else y) s = if c then x s else y s := by
  split <;> rfl

theorem Except.ok_eq_bind {ε α β : Type} {x : Except ε α} {f : α → Except ε β} {r : β} :
    .ok r = x.bind f ↔ ∃ a, .ok a = x ∧ .ok r = f a := by
  cases x <;> simp [Except.bind]

theorem eq_ite_iff' {α : Type} {c : Prop} [Decidable c] {a b r : α} :
    r = (if c then a else b) ↔ (c ∧ r = a) ∨ (¬c ∧ r = b) := by
  split <;> simp_all

theorem StateT.discard_run {σ ε β : Type} (x : StateT σ (Except ε) β) (s : σ) :
    discard x s = (x s).bind fun r => .ok (PUnit.unit, r.2) := rfl

set_option hygiene false in
/-- Evaluate a `typeOp` run in hypothesis h, read right to left. -/
macro "tsimp" : tactic => `(tactic| simp [typeOp, bind, StateT.bind, pure, StateT.pure, fail, throw, throwThe,
  MonadExceptOf.throw, StateT.lift, Except.pure, StateT.ite_run, StateT.discard_run, Except.ok_eq_bind, eq_ite_iff',
  and_assoc, exists_and_left, exists_eq_left, Functor.map, Except.map] at h)

/-- typeOp agrees with opTy wherever the arguments match the operator's arity. -/
theorem typeOp_sound :
    ∀ name op arity ts kvs, (name, op, arity) ∈ ops → ts.length = arity → ∀ st op' ty st',
    typeOp op ts kvs st = .ok ((op', ty), st') →
    st' = st ∧ opTy op' ts (match (generalizing := false) op', ty with | .convert _, .num u => some u | _, _ => none) = some ty := by
  intro name op arity ts kvs hmem hlen st op' ty st' h
  simp only [ops, List.mem_cons, Prod.mk.injEq, List.not_mem_nil, or_false] at hmem
  rcases hmem with ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ |
    ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ |
    ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ |
    ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ | ⟨-, rfl, rfl⟩ |
    ⟨-, rfl, rfl⟩
  all_goals rcases ts with _ | ⟨a, _ | ⟨b, _ | ⟨c, _ | ⟨d, _⟩⟩⟩⟩ <;> simp at hlen
  all_goals (try cases a) <;> (try cases b) <;> (try cases c)
  all_goals replace h := h.symm
  all_goals tsimp
  all_goals try (simp_all [opTy]; done)
  all_goals try (simp_all [opTy]; rfl)
  all_goals try (generalize hm : Dim.mul _ _ = o at h; cases o <;> tsimp <;> simp_all [opTy]; done)
  all_goals try (generalize hm : Dim.div _ _ = o at h; cases o <;> tsimp <;> simp_all [opTy]; done)
  all_goals try (generalize hm : Dim.sqrt _ = o at h; cases o <;> tsimp <;> simp_all [opTy]; done)
  all_goals try (obtain ⟨a, b, hab, h⟩ := h; obtain rfl := unitOf_keeps _ _ _ _ hab.symm
                 generalize hm : Dim.conversion _ _ = o at h; cases o <;> tsimp <;> simp_all [opTy]; done)
  all_goals try (generalize field kvs "hours" = j at h; cases j <;> tsimp; rename_i i
                 by_cases hw : 1 ≤ i ∧ i ≤ (maxHours : Int) <;> simp [hw] at h <;> tsimp <;> simp_all [opTy] <;> omega)
  all_goals try grind [opTy]

end Ref
