import Ref.Spec
import Ref.Proof.Except

/-! L6, ported from version 1: evaluation and admission never raise R_BOUND. The return is built from a finite
positive equity over a positive one, or is −1 or 0. -/

namespace Ref
open _root_.Ref.Except

variable {α : Type} [Inhabited α]

private theorem deliver_avoids_bound (c : Ctx α) (s : SState α) (tick : Int) :
    Avoids .bound (c.deliver s tick) := by
  fun_induction Ctx.deliver c s tick <;> simp_all [Avoids]

private theorem checkFill_avoids_bound (N : NumOps α) (f : Fill α) (bars : Array (BarRow α))
    (ix : Index α) (v : Venue α) : Avoids .bound (checkFill N f bars ix v) := by
  unfold checkFill
  simp only [Avoids]
  repeat' split
  all_goals simp_all [bind, Except.bind, pure, Except.pure, throw, throwThe, MonadExceptOf.throw]

private theorem marks_loop_bound (l : List (Nat × BarRow α)) (s : SState α) :
    forIn l s (fun x s => (pure (ForInStep.yield { s with marks := s.marks.set! x.1 x.2.c }) :
      Except Abort (ForInStep (SState α)))) = .ok { s with marks := l.foldl (fun mk y => mk.set! y.1 y.2.c) s.marks } := by
  induction l generalizing s with
  | nil => rfl
  | cons x l ih => rw [List.forIn_cons, List.foldl_cons]; exact ih _

theorem ret_bounded (N : NumOps α) (hB : N.Bounded) (prev e1 g g' : α) (he : N.finite e1 = true) :
    N.le (N.neg N.one) (if N.lt N.zero prev = true then
      (if N.lt N.zero e1 = true then N.sub (N.div e1 prev) N.one else N.neg N.one, g) else (N.zero, g')).fst = true := by
  by_cases hp : N.lt N.zero prev = true
  · by_cases hq : N.lt N.zero e1 = true
    · simp only [hp, hq, ite_true]; exact hB.ret e1 prev he hq hp
    · simp only [hp, hq, ite_true, ite_false, Bool.false_eq_true]; exact hB.floor
  · simp only [hp, ite_false, Bool.false_eq_true]; exact hB.flat

/-- Walk a do-block that cannot raise R_BOUND. -/
macro "bwalk" : tactic => `(tactic| repeat (first
  | exact Except.Avoids.ok _
  | exact Except.Avoids.pure _
  | (apply Except.Avoids.throw; decide)
   | exact deliver_avoids_bound _ _ _
   | exact checkFill_avoids_bound _ _ _ _ _
  | (refine Except.Avoids.bind ?_ (fun _ => ?_))
  | (refine Except.Avoids.forIn_list _ _ _ (fun _ _ => ?_))
  | (refine Except.Avoids.ite ?_ ?_)
  | split))

theorem step_bounded (N : NumOps α) (hB : N.Bounded) (c : Ctx α) (s : SState α) (b : Int) :
    Avoids .bound (c.step N s b) := by
  unfold Ctx.step
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  refine Avoids.bind (Avoids.forIn_list _ _ _ fun _ _ => ?_) fun s₁ => ?_
  · bwalk
  rw [marks_loop_bound]
  refine Avoids.bind (Avoids.ok _) fun s₂ => ?_
  refine Avoids.join (Avoids.forIn_list _ _ _ fun _ _ => ?_) fun s₃ => ?_
  · unfold Ctx.execute Ctx.closeout; bwalk
  refine Avoids.bind (Avoids.forIn_list _ _ _ fun _ _ => ?_) fun s₄ => ?_
  · unfold Ctx.execute Ctx.closeout; bwalk
  refine Avoids.bind ?_ fun s₅ => ?_
  · unfold Ctx.bankrupt Ctx.execute Ctx.closeout; bwalk
  refine Avoids.ite_cond (fun _ => Avoids.throw_bind (by decide)) fun hacc => ?_
  refine Avoids.ite_cond (fun hb => absurd hb ?_) fun _ => ?_
  · have hfin := hB.acc_finite _ _ _ (by simpa using hacc)
    simp [ret_bounded N hB _ _ _ _ hfin]
  unfold Ctx.execute; bwalk

theorem evaluate_bounded (N : NumOps α) (hB : N.Bounded) (c : Ctx α) : c.evaluate N ≠ .error .bound := by
  unfold Ctx.evaluate Ctx.steps
  refine Avoids.bind (Avoids.bind ?_ fun _ => Avoids.bind (Avoids.forIn_list _ _ _
    fun b s => Avoids.bind (step_bounded N hB _ s b) fun _ => Avoids.pure _) fun _ => Avoids.pure _)
    fun _ => Avoids.pure _
  unfold Ctx.start
  exact Avoids.bind (deliver_avoids_bound _ _ _) fun _ => Avoids.pure _

theorem admission_not_bound (reg : Registry) (roles : Roles) (text : String) (adm : Meta) (ld : Loader α)
    (v : Venue α) (pol : Policy) (stop : Int) (mode : Mode) :
    Avoids .bound ((admission reg roles text adm ld v pol stop mode).mapError (·.2)) := by
  have h1 (p : Program) : Avoids .bound (stage1 reg roles p adm mode) := by
    unfold stage1
    bwalk
  have h2 (req : List Nat) : Avoids .bound (stage2 adm mode (ld.rows req)) := by
    unfold stage2
    bwalk
  unfold admission
  cases hr : reg.valid <;> cases hp : pol.valid <;>
    simp only [hr, hp, Bool.not_false, Bool.not_true, Bool.or_false, Bool.or_true, ite_true, ite_false,
      Bool.false_eq_true, bind, Except.bind, Except.mapError, throw, throwThe, MonadExceptOf.throw] <;>
      try simp [Avoids]
  cases hc : check reg.inputs text with
  | error e => simp [Avoids]
  | ok p =>
    try dsimp only
    unfold admit
    cases hs : stage1 reg roles p adm mode with
    | error e =>
      intro he
      cases he
      exact h1 p hs
    | ok req =>
      dsimp only [Except.mapError, bind, Except.bind]
      cases ht : stage2 adm mode (ld.rows req) with
      | error e =>
        intro he
        cases he
        exact h2 req ht
      | ok u =>
        dsimp only
        cases ld.resolve req with
        | none => simp [Avoids, throw, throwThe, MonadExceptOf.throw]
        | some obs =>
          cases ha : (Ctx.make reg roles p adm obs v pol stop req).admissible <;>
            cases hsc : (Ctx.make reg roles p adm obs v pol stop req).inScope <;>
            simp [ha, hsc, Avoids, pure, Except.pure, throw, throwThe, MonadExceptOf.throw]

end Ref
