import Ref.Spec

/-! What a successful admission implies (laws-v2-draft.md §4): the metadata stage returns the declared required set,
and `admit` and `admission` succeed exactly through their checks. -/

namespace Ref

variable {α : Type} [Inhabited α]

theorem stage1_required {reg : Registry} {roles : Roles} {p : Program} {adm : Meta} {mode : Mode} {req : List Nat}
    (h : stage1 reg roles p adm mode = .ok req) : req = adm.required reg roles p := by
  unfold stage1 at h
  simp only [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw] at h
  repeat' (split at h <;> try contradiction)
  all_goals (injection h with h; exact h.symm)

theorem admit_ok {reg : Registry} {roles : Roles} {p : Program} {adm : Meta} {ld : Loader α} {v : Venue α}
    {pol : Policy} {stop : Int} {mode : Mode} {c : Ctx α} (h : admit reg roles p adm ld v pol stop mode = .ok c) :
    ∃ req obs, stage1 reg roles p adm mode = .ok req ∧ stage2 adm mode (ld.rows req) = .ok () ∧
      ld.resolve req = some obs ∧ c = Ctx.make reg roles p adm obs v pol stop req ∧ c.admissible = true ∧
      c.inScope = true := by
  unfold admit at h
  rcases h1 : stage1 reg roles p adm mode with e | req <;>
    simp only [h1, Except.mapError, bind, Except.bind] at h <;> try contradiction
  rcases h2 : stage2 adm mode (ld.rows req) with e | u <;> simp only [h2] at h <;> try contradiction
  rcases h3 : ld.resolve req with _ | obs <;> simp only [h3] at h <;> try contradiction
  cases hA : (Ctx.make reg roles p adm obs v pol stop req).admissible <;>
    cases hS : (Ctx.make reg roles p adm obs v pol stop req).inScope <;>
    simp only [hA, hS, Bool.not_false, Bool.not_true, ite_true, ite_false, throw, throwThe, MonadExceptOf.throw,
      Except.pure, pure, reduceCtorEq] at h <;> try contradiction
  injection h with h
  subst h
  exact ⟨req, obs, by first | rfl | assumption, by cases u; first | rfl | assumption, by first | rfl | assumption, rfl,
    by first | rfl | assumption, by first | rfl | assumption⟩

theorem admission_ok {reg : Registry} {roles : Roles} {text : String} {adm : Meta} {ld : Loader α} {v : Venue α}
    {pol : Policy} {stop : Int} {mode : Mode} {c : Ctx α} (h : admission reg roles text adm ld v pol stop mode = .ok c) :
    reg.valid = true ∧ pol.valid = true ∧ ∃ p, check reg.inputs text = .ok p ∧ admit reg roles p adm ld v pol stop mode = .ok c := by
  unfold admission at h
  cases hr : reg.valid <;> cases hp : pol.valid <;>
    simp only [hr, hp, Bool.not_false, Bool.not_true, Bool.or_false, Bool.or_true, Bool.false_or, ite_true, ite_false,
      throw, throwThe, MonadExceptOf.throw, bind, Except.bind] at h <;> try contradiction
  rcases hk : check reg.inputs text with e | p <;> simp only [hk, Except.mapError] at h <;> try contradiction
  exact ⟨rfl, rfl, p, rfl, h⟩

theorem Abort.position_le (e : Abort) : e.position ≤ 4 := by cases e <;> decide

/-- `admit`'s refusals at positions up to 5 come from the metadata and event-time stages alone. -/
theorem admit_early (reg : Registry) (roles : Roles) (p : Program) (adm : Meta) (ld : Loader α) (v : Venue α)
    (pol : Policy) (stop : Int) (mode : Mode) :
    (failureOf (admit reg roles p adm ld v pol stop mode)).filter (·.1 ≤ 5)
      = (match stage1 reg roles p adm mode with
         | .error e => some (e.position, e)
         | .ok req => match stage2 adm mode (ld.rows req) with
           | .error e => some (5, e)
           | .ok _ => none) := by
  unfold admit
  rcases h1 : stage1 reg roles p adm mode with e | req <;> simp only [h1, Except.mapError, bind, Except.bind, failureOf]
  · simp [Option.filter, Abort.position_le e, Nat.le_trans (Abort.position_le e) (by decide : 4 ≤ 5)]
  rcases h2 : stage2 adm mode (ld.rows req) with e | u <;> simp only [h2]
  · simp [Option.filter]
  rcases h3 : ld.resolve req with _ | obs <;> simp only [h3]
  · simp [Option.filter, throw, throwThe, MonadExceptOf.throw]
  cases hA : (Ctx.make reg roles p adm obs v pol stop req).admissible <;>
    cases hS : (Ctx.make reg roles p adm obs v pol stop req).inScope <;>
    simp [hA, hS, Option.filter, throw, throwThe, MonadExceptOf.throw, pure, Except.pure]

end Ref
