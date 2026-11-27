import Engine.STimeOffer

/-!
# The view's lag under a tick (brief 3 step 5; S1)

A tick takes the effects known by its time into the view's account and then sends wishes in the view's cycles, so a wish
of a cycle after a step's end is sent at a tick no earlier than the step plus `δ`.
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book Placement CycleStep OrderFill Trigger)

theorem tickBody_sent_cycle (s : State) (t : Int) : ∀ w ∈ (tickBody s t).2.2.wishes, w.cycle = s.vacct.cycle w.coin := by
  intro w hw
  simp only [tickBody] at hw
  split at hw
  · have hw' := mem_of_ite_nil hw
    simp only [List.mem_map] at hw'
    obtain ⟨x, _, rfl⟩ := hw'
    rfl
  · simp at hw

theorem tickAt_vacct (s : State) (time : Int) : (tickAt s time).1.vacct =
    (s.veffects.filter fun l => decide (l.known ≤ time)).foldl (fun a l => a.apply s.cfg.fees l.time l.effect) s.vacct := by
  simp only [tickAt, tickBody, withLog, aged, releaseEffects, release]

theorem tickAt_veffects (s : State) (time : Int) :
    (tickAt s time).1.veffects = s.veffects.filter fun l => !decide (l.known ≤ time) := by
  simp only [tickAt, tickBody, withLog, aged, releaseEffects, release]

theorem tickAt_sent_cycle (s : State) (time : Int) :
    ∀ w ∈ (tickAt s time).2.2.wishes, w.cycle = (tickAt s time).1.vacct.cycle w.coin := by
  intro w hw
  have h := tickBody_sent_cycle (tickPre s time) time w hw
  rw [tickAt_vacct]
  exact h

theorem timeInv_tick (s : State) (time ms : Int) (hn : s.nextTick = some time) (hB : BInv s.core) (hS : SInv s.core)
    (hT : TInv s.core) (h : TimeInv s.core) :
    TimeInv ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core := by
  have hcfg := tickAt_cfg s time
  have hacct := tickAt_acct s time
  have hwq := tickAt_wishes s time
  have hsh : Shape s.cfg.names.length s.acct := hB.shapeW
  have hshv : Shape s.cfg.names.length s.vacct := hB.shapeV
  have hlog : ∀ l', ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core.log = some l' →
      ∃ l : Log, s.core.log = some l.core ∧ l'.steps = l.steps ∧ l'.placed = l.placed ∧
        l'.ticks = l.ticks ++ [(time, tickView s time)] := by
    intro l' hl'
    obtain ⟨l, hs, rfl⟩ := tick_decomp s time ms l' hl'
    exact ⟨l, by simp [StateOf.core, hs], rfl, rfl, rfl⟩
  have key : ∀ l : Log, s.core.log = some l.core →
      ((tickAt s time).1.vacct.cycles.length = s.cfg.names.length ∧ (∀ k, (tickAt s time).1.vacct.cycle k ≤ s.acct.cycle k) ∧
        VT l.steps s.cfg.delta time (tickAt s time).1.vacct) := by
    intro l hc
    rw [tickAt_vacct]
    refine release_fold hS hc s.cfg.fees time s.cfg.delta s.acct hsh.2.1 (hS.mono l.core hc) _ ?_ ?_ s.vacct hshv.2.1
      (h.va l.core hc) ?_
    · intro x hx
      simpa using (List.mem_filter.1 hx).2
    · intro x hx
      exact h.ve l.core hc x (List.mem_filter.1 hx).1
    · intro st hst k hk hlt
      obtain ⟨tk, htk, hle⟩ := h.vt l.core hc st hst k hk hlt
      have hle' : st.time + s.cfg.delta ≤ tk.1 := hle
      have := hT.beforeNext l.core hc tk htk time hn
      omega
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl' k
    obtain ⟨l, hc, _⟩ := hlog l' hl'
    show (tickAt s time).1.vacct.cycle k ≤ (tickAt s time).1.acct.cycle k
    rw [hacct]
    exact (key l hc).2.1 k
  · intro l' hl'
    obtain ⟨l, hc, e1, _⟩ := hlog l' hl'
    have hv := h.ve l.core hc
    show VE l'.steps (tickAt s time).1.cfg.delta (tickAt s time).1.veffects
    rw [hcfg, tickAt_veffects, e1]
    intro x hx
    exact hv x (List.mem_filter.1 hx).1
  · intro l' hl' st hst k hk hlt
    obtain ⟨l, hc, e1, _, e3⟩ := hlog l' hl'
    rw [e1] at hst
    have hlt' : st.before.cycle k < (tickAt s time).1.vacct.cycle k := hlt
    have := (key l hc).2.2 st hst k hk hlt'
    refine ⟨(time, tickView s time), by rw [e3]; exact List.mem_append_right _ (List.mem_singleton_self _), ?_⟩
    show st.time + (tickAt s time).1.cfg.delta ≤ time
    rw [hcfg]; exact this
  · intro l' hl' w hw
    obtain ⟨l, hc, e1, _⟩ := hlog l' hl'
    have hw' : w ∈ s.wishes ++ orderWishes (tickAt s time).2.2.wishes := by
      have : w ∈ (tickAt s time).1.wishes := hw
      rw [hwq] at this; exact this
    rcases List.mem_append.1 hw' with hw' | hw'
    · obtain ⟨h1, h2⟩ := h.wq l.core hc w hw'
      refine ⟨by show w.cycle ≤ (tickAt s time).1.acct.cycle w.coin; rw [hacct]; exact h1, ?_⟩
      intro st hst k hk hk' hlt
      rw [e1] at hst
      show st.time + (tickAt s time).1.cfg.delta + (tickAt s time).1.cfg.lambda ≤ w.arrives
      rw [hcfg]; exact h2 st hst k hk hk' hlt
    · have hsent := (mem_orderWishes _ w).1 hw'
      have hcyc := tickAt_sent_cycle s time w hsent
      have harr := tickAt_sent s time w hsent
      refine ⟨?_, ?_⟩
      · show w.cycle ≤ (tickAt s time).1.acct.cycle w.coin
        rw [hacct, hcyc]
        exact (key l hc).2.1 _
      · intro st hst k hk hk' hlt
        rw [e1] at hst
        have hlt' : st.before.cycle k < (tickAt s time).1.vacct.cycle k := by rw [hcyc, ← hk'] at hlt; rw [← hk']; exact hlt
        have := (key l hc).2.2 st hst k hk hlt'
        show st.time + (tickAt s time).1.cfg.delta + (tickAt s time).1.cfg.lambda ≤ w.arrives
        rw [hcfg, harr]
        omega
  · intro l' hl' p hp i st hi hip k hk hck hlt
    obtain ⟨l, hc, e1, e2, _⟩ := hlog l' hl'
    rw [e2] at hp
    rw [e1] at hi
    have := h.pl l.core hc p hp i st hi hip k hk hck hlt
    show st.time + (tickAt s time).1.cfg.delta + (tickAt s time).1.cfg.lambda ≤ p.order.placed
    rw [hcfg]; exact this

end Engine.Machine
