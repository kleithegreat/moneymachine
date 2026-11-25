import Engine.SOffer
import Engine.RInvSteps

/-!
# S1's step, fill and placement invariants under the moves that leave the steps alone (brief 3 step 5)
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book Placement CycleStep OrderFill Trigger)

theorem sinv_tick (s : State) (time ms : Int) (h : SInv s.core) :
    SInv ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core := by
  refine sInv_congr h (by simp [StateOf.core, tickAt_cfg]) (by simp [StateOf.core, tickAt_acct])
    (by simp [StateOf.core, tickAt_previous]) ?_
  have e := tickAt_log s time
  show ((tickAt s time).1.log.map Log.core).map _ = (s.log.map Log.core).map _
  rw [e]
  cases s.log <;> simp [Log.core]

theorem sinv_prev (s : State) (e : Event) (hprev : ∀ q, s.previous = some q → q.time ≤ e.time) (h : SInv s.core) :
    SInv ({ s with previous := some e } : State).core := by
  refine ⟨h.steps, h.mono, h.chain, h.times, ?_, h.exist, h.endedLt, h.placedIdx, h.placedOwn, h.fillsIdx, h.fillsOwn, h.fillsGood⟩
  intro l hl st hst hne
  obtain ⟨q, hq, hle⟩ := h.prevTime l hl st hst hne
  exact ⟨e, rfl, Int.le_trans hle (hprev q hq)⟩

theorem sinv_listing (s : State) (e : Event) (rules : Rules) (h : SInv s.core) :
    SInv (applyPayload s e (.listing rules)).1.core := by
  have hk := applyPayload_keeps s e (.listing rules)
  have hp := applyPayload_previous s e (.listing rules)
  have hlog : (applyPayload s e (.listing rules)).1.log = s.log := by
    simp only [applyPayload]
    exact emit_log _ _ _
  have hcy : (applyPayload s e (.listing rules)).1.acct.cycles = s.acct.cycles := by
    simp only [applyPayload]
    rw [emit_acct]
    by_cases hc : (s.rules[e.coin]? != some rules) = true
    · simp only [hc, ite_true]
      exact (foldl_cancels _ _ "rules" _ _).2.1
    · simp only [hc]
      rfl
  refine sInv_congr h (by simp [StateOf.core, hk.cfg]) hcy hp ?_
  simp [StateOf.core, hlog]

end Engine.Machine
