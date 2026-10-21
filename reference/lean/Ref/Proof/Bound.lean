import Ref.Spec
import Ref.Proof.Fills

/-! L6: the loss bound's check never fires. Every abort a step can raise other than R_BOUND is avoided
structurally, and the check itself passes because its return is built from a finite positive equity over a
positive one, or is −1 or 0. -/

namespace Ref
open Except

variable {α : Type} [Inhabited α]

theorem ret_bounded (N : NumOps α) (hB : N.Bounded) (prev e1 g g' : α) (he : N.finite e1 = true) :
    N.le (N.neg N.one) (if N.lt N.zero prev = true then
      (if N.lt N.zero e1 = true then N.sub (N.div e1 prev) N.one else N.neg N.one, g) else (N.zero, g')).fst = true := by
  by_cases hp : N.lt N.zero prev = true
  · by_cases hq : N.lt N.zero e1 = true
    · simp only [hp, hq, if_true]; exact hB.ret e1 prev he hq hp
    · simp only [hp, hq, if_true, if_false, Bool.false_eq_true]; exact hB.floor
  · simp only [hp, if_false, Bool.false_eq_true]; exact hB.flat

/-- Walk a do-block that cannot raise R_BOUND. -/
macro "bwalk" : tactic => `(tactic| repeat (first
  | exact Except.Avoids.ok _
  | exact Except.Avoids.pure _
  | (apply Except.Avoids.throw; decide)
  | exact deliver_avoids _ _ _ (by decide)
  | exact checkFill_avoids _ _ _ _ _ (by decide) (by decide) (by decide)
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
  rw [marks_loop]
  refine Avoids.bind (Avoids.ok _) fun s₂ => ?_
  refine Avoids.join (Avoids.forIn_list _ _ _ fun _ _ => ?_) fun s₃ => ?_
  · unfold Ctx.execute Ctx.closeout; bwalk
  refine Avoids.bind (Avoids.forIn_list _ _ _ fun _ _ => ?_) fun s₄ => ?_
  · unfold Ctx.execute Ctx.closeout; bwalk
  refine Avoids.bind ?_ fun s₅ => ?_
  · unfold Ctx.bankrupt Ctx.execute Ctx.closeout; bwalk
  refine Avoids.ite_cond (fun _ => Avoids.throw_bind (by decide)) fun hacc => ?_
  refine Avoids.ite_cond (fun hb => absurd hb ?_) fun _ => ?_
  · have hfin := hB.acc_finite _ _ (by simpa using hacc)
    simp [ret_bounded N hB _ _ _ _ hfin]
  unfold Ctx.execute; bwalk

end Ref
