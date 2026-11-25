import Engine.STime

/-!
# The view's lag under the moves that leave the steps alone (brief 3 step 5; S1)
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book Placement CycleStep OrderFill Trigger)

theorem timeInv_prev (s : State) (e : Event) (h : TimeInv s.core) : TimeInv ({ s with previous := some e } : State).core :=
  ⟨h.va, h.ve, h.vt, h.wq, h.pl⟩

theorem timeInv_emit (s : State) (t : Int) (es : List Effect) (hno : ∀ e ∈ es, ∀ k c, e ≠ .cycleEnd k c)
    (h : TimeInv s.core) : TimeInv (emit s t es).1.core := by
  have fr := emit_frame s t es
  have hcy := emit_cycles_noend s t es hno
  have hlg : (emit s t es).1.log = s.log := emit_log s t es
  have hacc : ∀ k, (emit s t es).1.acct.cycle k = s.acct.cycle k := by
    intro k; unfold Acct.cycle; rw [hcy]
  have hlc : ∀ l, (emit s t es).1.core.log = some l → s.core.log = some l := by
    intro l hl; simpa [StateOf.core, hlg] using hl
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · intro l hl k
    show (emit s t es).1.vacct.cycle k ≤ (emit s t es).1.acct.cycle k
    rw [fr.vacct, hacc]
    exact h.va l (hlc l hl) k
  · intro l hl
    have := h.ve l (hlc l hl)
    show VE l.steps (emit s t es).1.cfg.delta (emit s t es).1.veffects
    rw [fr.cfg, emit_veffects]
    intro x hx k C hxe
    rcases List.mem_append.1 hx with hx | hx
    · exact this x hx k C hxe
    · obtain ⟨e, he, rfl⟩ := List.mem_map.1 hx
      exact absurd hxe (hno e he k C)
  · intro l hl st hst k hk hlt
    have := h.vt l (hlc l hl) st hst k hk
    show ∃ tk ∈ l.ticks, st.time + (emit s t es).1.cfg.delta ≤ tk.1
    rw [fr.cfg]
    have hlt' : st.before.cycle k < s.vacct.cycle k := by rw [← fr.vacct]; exact hlt
    exact this hlt'
  · intro l hl w hw
    have hw' : w ∈ s.wishes := by rw [← fr.wishes]; exact hw
    obtain ⟨h1, h2⟩ := h.wq l (hlc l hl) w hw'
    refine ⟨by show w.cycle ≤ (emit s t es).1.acct.cycle w.coin; rw [hacc]; exact h1, ?_⟩
    show ∀ st ∈ l.steps, ∀ k ∈ st.ended, w.coin = k → st.before.cycle k < w.cycle →
      st.time + (emit s t es).1.cfg.delta + (emit s t es).1.cfg.lambda ≤ w.arrives
    rw [fr.cfg]
    exact h2
  · intro l hl
    have := h.pl l (hlc l hl)
    show ∀ p ∈ l.placed, ∀ (i : Nat) st, l.steps[i]? = some st → i < p.step → ∀ k ∈ st.ended, p.order.coin = k →
      st.before.cycle k < p.order.cycle → st.time + (emit s t es).1.cfg.delta + (emit s t es).1.cfg.lambda ≤ p.order.placed
    rw [fr.cfg]
    exact this

theorem timeInv_listing (s : State) (e : Event) (rules : Rules) (h : TimeInv s.core) :
    TimeInv (applyPayload s e (.listing rules)).1.core := by
  simp only [applyPayload]
  have h' : TimeInv ({ s with rules := setAt s.rules e.coin rules } : State).core := h
  refine timeInv_emit _ _ _ ?_ h'
  intro x hx k c
  simp only [List.mem_ite_nil_right, List.mem_map] at hx
  obtain ⟨_, ⟨o', _, rfl⟩⟩ := hx
  simp

theorem timeInv_arrive (s : State) (w : Wish) (rest : List Wish) (hS : SInv ({ s with wishes := w :: rest } : State).core)
    (h : TimeInv ({ s with wishes := w :: rest } : State).core) :
    TimeInv ({ (arriveWish s w).1 with wishes := rest } : State).core := by
  have fr := arriveWish_frame s w
  have hcy : (arriveWish s w).1.acct.cycles = s.acct.cycles := arrival_cycles s w
  have hacc : ∀ k, (arriveWish s w).1.acct.cycle k = s.acct.cycle k := by
    intro k; unfold Acct.cycle; rw [hcy]
  have hlog : ∀ l', ({ (arriveWish s w).1 with wishes := rest } : State).core.log = some l' →
      ∃ l : Log, ({ s with wishes := w :: rest } : State).core.log = some l.core ∧ s.log = some l ∧
        l'.steps = l.steps ++ arrivalSteps s w ∧ l'.placed = l.placed ++ arrivalPlaced s w ∧ l'.ticks = l.ticks := by
    intro l' hl'
    obtain ⟨l, hs, rfl⟩ := arrive_decomp s w rest l' hl'
    exact ⟨l, by simp [StateOf.core, hs], hs, rfl, rfl, rfl⟩
  have hnew : ∀ st ∈ arrivalSteps s w, st.ended = [] := by
    intro st hst
    rcases arrivalSteps_spec s w with e | e
    · rw [e] at hst; simp at hst
    · rw [e] at hst
      simp only [List.mem_singleton] at hst
      subst hst
      rfl
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl' k
    obtain ⟨l, hc, _⟩ := hlog l' hl'
    show (arriveWish s w).1.vacct.cycle k ≤ (arriveWish s w).1.acct.cycle k
    rw [fr.vacct, hacc]
    exact h.va l.core hc k
  · intro l' hl'
    obtain ⟨l, hc, _, e1, _⟩ := hlog l' hl'
    have hv := h.ve l.core hc
    show VE l'.steps (arriveWish s w).1.cfg.delta (arriveWish s w).1.veffects
    rw [fr.cfg, arriveWish_veffects, e1]
    intro x hx k C hxe
    rcases List.mem_append.1 hx with hx | hx
    · obtain ⟨st, hst, r⟩ := hv x hx k C hxe
      exact ⟨st, List.mem_append_left _ hst, r⟩
    · obtain ⟨e, he, rfl⟩ := List.mem_map.1 hx
      exact absurd hxe ((arrivalEffects_ok s w e he).1 k C)
  · intro l' hl' st hst k hk hlt
    obtain ⟨l, hc, _, e1, _, e4⟩ := hlog l' hl'
    rw [e1] at hst
    rcases List.mem_append.1 hst with hst | hst
    · have hlt' : st.before.cycle k < s.vacct.cycle k := by rw [← fr.vacct]; exact hlt
      obtain ⟨tk, htk, hle⟩ := h.vt l.core hc st hst k hk hlt'
      refine ⟨tk, by rw [e4]; exact htk, ?_⟩
      show st.time + (arriveWish s w).1.cfg.delta ≤ tk.1
      rw [fr.cfg]; exact hle
    · rw [hnew st hst] at hk; simp at hk
  · intro l' hl' w' hw'
    obtain ⟨l, hc, _, e1, _⟩ := hlog l' hl'
    have hw'' : w' ∈ w :: rest := List.mem_cons_of_mem _ hw'
    obtain ⟨h1, h2⟩ := h.wq l.core hc w' hw''
    refine ⟨by show w'.cycle ≤ (arriveWish s w).1.acct.cycle w'.coin; rw [hacc]; exact h1, ?_⟩
    intro st hst k hk hk' hlt
    rw [e1] at hst
    rcases List.mem_append.1 hst with hst | hst
    · have := h2 st hst k hk hk' hlt
      show st.time + (arriveWish s w).1.cfg.delta + (arriveWish s w).1.cfg.lambda ≤ w'.arrives
      rw [fr.cfg]; exact this
    · rw [hnew st hst] at hk; simp at hk
  · intro l' hl' p hp i st hi hip k hk hck hlt
    obtain ⟨l, hc, hs, e1, e2, _⟩ := hlog l' hl'
    rw [e2] at hp
    rw [e1] at hi
    show st.time + (arriveWish s w).1.cfg.delta + (arriveWish s w).1.cfg.lambda ≤ p.order.placed
    rw [fr.cfg]
    rcases List.mem_append.1 hp with hp | hp
    · obtain ⟨st', hst', _⟩ := hS.placedOwn l.core hc p hp
      have hlen : p.step < l.steps.length := (List.getElem?_eq_some_iff.1 hst').1
      rw [getElem?_append_lt _ _ _ (by omega)] at hi
      exact h.pl l.core hc p hp i st hi hip k hk hck hlt
    · obtain ⟨_, hcoin, hcyc, hplaced, hstep, _⟩ := arrivalPlaced_spec s w p hp
      rw [stepCount_of_log s l hs] at hstep
      rw [hstep] at hip
      rw [getElem?_append_lt _ _ _ hip] at hi
      obtain ⟨_, h2⟩ := h.wq l.core hc w (List.mem_cons_self ..)
      have := h2 st (List.mem_of_getElem? hi) k hk (by rw [← hcoin]; exact hck) (by rw [← hcyc]; exact hlt)
      rw [hplaced]
      exact this

end Engine.Machine
