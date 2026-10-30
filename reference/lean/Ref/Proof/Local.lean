import Ref.Proof.Sim

namespace Ref

variable {α : Type} [Inhabited α]

def MState.withLocal (m : MState α) (X : Array (Array (Val α))) (W : Array (Array (Option (Win α))))
    (S : Array (Array (Option Int))) : MState α := { m with vals := X, wins := W, since := S }

theorem MState.deliver_local (m : MState α) (o : Obs α) (t : Int) (X : Array (Array (Val α)))
    (W : Array (Array (Option (Win α)))) (S : Array (Array (Option Int))) :
    (m.withLocal X W S).deliver o t = (m.deliver o t).map (·.withLocal X W S) := by
  unfold MState.deliver
  split <;> rfl

theorem deliver_local (c : Ctx α) (s : SState α) (t : Int) (X : Array (Array (Val α)))
    (W : Array (Array (Option (Win α)))) (S : Array (Array (Option Int))) :
    c.deliver { s with machine := s.machine.withLocal X W S } t =
      (c.deliver s t).map fun r => { r with machine := r.machine.withLocal X W S } := by
  fun_induction Ctx.deliver c s t <;> rw [Ctx.deliver] <;>
    simp_all (config := { zetaDelta := true }) [MState.deliver_local, Except.map]
  all_goals intro; omega

theorem deliver_keeps_local (c : Ctx α) (s r : SState α) (t : Int) (h : c.deliver s t = .ok r) :
    r.machine.vals = s.machine.vals ∧ r.machine.wins = s.machine.wins ∧ r.machine.since = s.machine.since := by
  have he := deliver_local c s t s.machine.vals s.machine.wins s.machine.since
  have hs : ({ s with machine := s.machine.withLocal s.machine.vals s.machine.wins s.machine.since } : SState α) = s := rfl
  rw [hs, h] at he
  simp only [Except.map, Except.ok.injEq] at he
  exact ⟨congrArg (fun s => s.machine.vals) he, congrArg (fun s => s.machine.wins) he,
    congrArg (fun s => s.machine.since) he⟩

end Ref
