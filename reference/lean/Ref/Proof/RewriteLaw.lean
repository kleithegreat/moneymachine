import Ref.Proof.InsertRun

namespace Ref
variable {α : Type} [Inhabited α]

theorem runProgram_congr (N : NumOps α) (reg : Registry) (roles : Roles) (p p' : Program)
    (hsrc : p'.sources = p.sources) (adm : Meta) (ld : Loader α) (v : Venue α) (pol : Policy) (stop : Int) (mode : Mode)
    (heval : ∀ obs req, (Ctx.make reg roles p' adm obs v pol stop req).evaluate N =
      (Ctx.make reg roles p adm obs v pol stop req).evaluate N) :
    runProgram N reg roles p' adm ld v pol stop mode = runProgram N reg roles p adm ld v pol stop mode := by
  have hstage : stage1 reg roles p' adm mode = stage1 reg roles p adm mode := by
    unfold stage1 Meta.required
    rw [hsrc]
  unfold runProgram admit
  rw [hstage]
  cases h1 : stage1 reg roles p adm mode with
  | error e => rfl
  | ok req =>
    simp only [Except.mapError, bind, Except.bind]
    cases h2 : stage2 adm mode (ld.rows req) with
    | error e => rfl
    | ok u =>
      simp only [Except.mapError, bind, Except.bind]
      cases ho : ld.resolve req with
      | none => rfl
      | some obs =>
        simp only
        have ha : (Ctx.make reg roles p' adm obs v pol stop req).admissible =
            (Ctx.make reg roles p adm obs v pol stop req).admissible := rfl
        have hs : (Ctx.make reg roles p' adm obs v pol stop req).inScope =
            (Ctx.make reg roles p adm obs v pol stop req).inScope := rfl
        rw [ha, hs]
        cases (Ctx.make reg roles p adm obs v pol stop req).admissible <;>
          cases (Ctx.make reg roles p adm obs v pol stop req).inScope <;>
          simp only [Bool.not_true, Bool.not_false, Bool.false_eq_true, ite_true, ite_false,
            throw, throwThe, MonadExceptOf.throw, pure, Except.pure] <;>
          first | rfl | exact heval obs req

theorem rewrite_sound (N : NumOps α) (hN : N.Lawful) {reg : Registry} {r : Rule} {p p' : Program} {i : Nat}
    (hp : p.WF reg) (h : r.apply p i = some p') (ctx : Ctx α) :
    p'.WF reg ∧ p'.sources = p.sources ∧
    (∀ n, (({ ctx with p := p' } : Ctx α).machineAfter N n).isOk = (({ ctx with p := p } : Ctx α).machineAfter N n).isOk ∧
      ∀ ms ms', ({ ctx with p := p } : Ctx α).machineAfter N n = .ok ms → ({ ctx with p := p' } : Ctx α).machineAfter N n = .ok ms' →
        ∀ k < p.nodes.size, ms'.vals[r.corr i k]! = ms.vals[k]!) ∧
    (∀ j, (({ ctx with p := p' } : Ctx α).steps N j).map (·.trace) = (({ ctx with p := p } : Ctx α).steps N j).map (·.trace)) ∧
    ({ ctx with p := p' } : Ctx α).evaluate N = ({ ctx with p := p } : Ctx α).evaluate N := by
  by_cases hr : r = .ifNotRev
  · subst r
    exact ifNotRev_sound N hN hp h ctx
  · obtain ⟨j, T⟩ := apply_twin N hN hp h hr
    refine ⟨T.wf', sources_twin T, fun n => ?_, fun j => ?_, evaluate_twin T ctx⟩
    · rw [machineAfter_twin T ctx n]
      refine ⟨rfl, fun ms ms' hm hm' k hk => ?_⟩
      have heq : ms' = ms := by rw [hm] at hm'; exact Except.ok.inj hm'.symm
      subst ms'
      have hcorr : r.corr i k = k := by cases r <;> simp_all [Rule.corr]
      rw [hcorr]
    · rw [steps_twin T ctx j]

end Ref
