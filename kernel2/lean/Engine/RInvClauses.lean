import Engine.RInvTick

namespace Engine.Machine

open Engine.Orders (Wish)

theorem rinv_tick (s : State) (time ms : Int) (hS : Setup s) (h : RInv s.core)
    (hn : s.nextTick = some time) (ht : s.cfg.tickMs = some ms) :
    RInv ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core := by
  have hms : 0 < ms := hS.1 ms ht
  have hlam : 0 ≤ s.cfg.lambda := hS.2
  obtain ⟨hB1, hB2⟩ := tickAt_batch s time
  have hcfg : (tickAt s time).1.cfg = s.cfg := tickAt_cfg s time
  have hwq : (tickAt s time).1.wishes = s.wishes ++ orderWishes (tickAt s time).2.2.wishes := tickAt_wishes s time
  obtain ⟨B, hB⟩ : ∃ B, B = (tickAt s time).2.2.wishes := ⟨_, rfl⟩
  rw [← hB] at hB1 hB2 hwq
  have hperm := orderWishes_perm B
  have hBpair : B.Pairwise (fun a b => (a.coin, a.slot) ≠ (b.coin, b.slot)) := by
    have := List.pairwise_map.1 hB2
    exact this
  have hOpair : (orderWishes B).Pairwise (fun a b => (a.coin, a.slot) ≠ (b.coin, b.slot)) :=
    (hperm.pairwise_iff (fun {a b} h h' => h h'.symm)).2 hBpair
  have hnt : s.core.nextTick = some time := hn
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl'
    obtain ⟨l, hlc, rfl⟩ := tick_decomp s time ms l' hl'
    rw [← hB]
    have hlc' : s.core.log = some l.core := by simp [StateOf.core, hlc]
    intro w hw'
    simp only [StateOf.core, hcfg]
    rcases List.mem_append.1 hw' with hw' | hw'
    · exact h.sentArrives l.core hlc' w hw'
    · have := hB1 w hw'
      rw [this.2, this.1]
  · intro l' hl'
    obtain ⟨l, hlc, rfl⟩ := tick_decomp s time ms l' hl'
    rw [← hB]
    have hlc' : s.core.log = some l.core := by simp [StateOf.core, hlc]
    intro w hw' t ht'
    simp only [StateOf.core, Option.some.injEq] at ht'
    subst ht'
    rcases List.mem_append.1 hw' with hw' | hw'
    · have := h.sentBefore l.core hlc' w hw' time hnt
      omega
    · have := (hB1 w hw').1
      omega
  · intro l' hl'
    obtain ⟨l, hlc, rfl⟩ := tick_decomp s time ms l' hl'
    rw [← hB]
    have hlc' : s.core.log = some l.core := by simp [StateOf.core, hlc]
    show (l.wishes ++ B).Pairwise _
    refine List.pairwise_append.2 ⟨h.sentPairs l.core hlc', ?_, ?_⟩
    · refine hBpair.imp ?_
      intro a b hab hc hs
      exact absurd (by rw [hc, hs]) hab
    · intro a ha b hb hc hs
      have h1 := h.sentBefore l.core hlc' a ha time hnt
      have h2 := h.sentArrives l.core hlc' a ha
      have h3 := hB1 b hb
      refine ⟨by omega, by simp only [StateOf.core, hcfg] at *; omega⟩
  · intro w hw' t ht'
    simp only [StateOf.core, Option.some.injEq] at ht'
    subst ht'
    have hw'' : w ∈ s.wishes ++ orderWishes B := by simpa [StateOf.core, hwq] using hw'
    simp only [StateOf.core, hcfg]
    rcases List.mem_append.1 hw'' with hw'' | hw''
    · have := h.queueBefore w hw'' time hnt
      simp only [StateOf.core] at this
      omega
    · have := hB1 w ((mem_orderWishes B w).1 hw'')
      omega
  · show (({ (tickAt s time).1 with nextTick := some (time + ms) } : State).wishes).Pairwise _
    show ((tickAt s time).1.wishes).Pairwise _
    rw [hwq]
    refine List.pairwise_append.2 ⟨h.queueSorted, ?_, ?_⟩
    · exact ((orderWishes_sorted B).and hOpair).imp fun {a b} hab => ⟨hab.1, fun _ => hab.2⟩
    · intro a ha b hb
      have h1 := h.queueBefore a ha time hnt
      simp only [StateOf.core] at h1
      have h2 := hB1 b ((mem_orderWishes B b).1 hb)
      refine ⟨?_, fun heq => absurd heq (by omega)⟩
      unfold wishLe
      simp only [Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq]
      left
      omega
  · intro l' hl' coin slot
    obtain ⟨l, hlc, rfl⟩ := tick_decomp s time ms l' hl'
    rw [← hB]
    have hlc' : s.core.log = some l.core := by simp [StateOf.core, hlc]
    have hf := h.fifo l.core hlc' coin slot
    show (l.wishes ++ B).filter (SameSlot coin slot) = (l.arrivals.map (·.wish)).filter (SameSlot coin slot) ++
      ((tickAt s time).1.wishes).filter (SameSlot coin slot)
    rw [hwq, List.filter_append, List.filter_append, filter_orderWishes B hB2, ← List.append_assoc]
    exact congrArg (· ++ B.filter (SameSlot coin slot)) hf

theorem rinv_arrive (s : State) (w : Wish) (rest : List Wish) (h : RInv ({ s with wishes := w :: rest } : State).core) :
    RInv ({ (arriveWish s w).1 with wishes := rest } : State).core := by
  have fr := arriveWish_frame s w
  have hcfg : (arriveWish s w).1.cfg = s.cfg := fr.cfg
  have hnx : (arriveWish s w).1.nextTick = s.nextTick := fr.nextTick
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl'
    obtain ⟨l, hlc, rfl⟩ := arrive_decomp s w rest l' hl'
    have hlc' : ({ s with wishes := w :: rest } : State).core.log = some l.core := by simp [StateOf.core, hlc]
    intro w' hw'
    simp only [StateOf.core, hcfg] at *
    exact h.sentArrives l.core hlc' w' hw'
  · intro l' hl'
    obtain ⟨l, hlc, rfl⟩ := arrive_decomp s w rest l' hl'
    have hlc' : ({ s with wishes := w :: rest } : State).core.log = some l.core := by simp [StateOf.core, hlc]
    intro w' hw' t ht
    simp only [StateOf.core, hnx] at ht
    exact h.sentBefore l.core hlc' w' hw' t ht
  · intro l' hl'
    obtain ⟨l, hlc, rfl⟩ := arrive_decomp s w rest l' hl'
    have hlc' : ({ s with wishes := w :: rest } : State).core.log = some l.core := by simp [StateOf.core, hlc]
    exact h.sentPairs l.core hlc'
  · intro w' hw' t ht
    simp only [StateOf.core, hnx, hcfg] at ht ⊢
    exact h.queueBefore w' (List.mem_cons_of_mem _ hw') t ht
  · exact (List.pairwise_cons.1 h.queueSorted).2
  · intro l' hl' coin slot
    obtain ⟨l, hlc, rfl⟩ := arrive_decomp s w rest l' hl'
    have hlc' : ({ s with wishes := w :: rest } : State).core.log = some l.core := by simp [StateOf.core, hlc]
    have hf : l.wishes.filter (SameSlot coin slot) = (l.arrivals.map (·.wish)).filter (SameSlot coin slot) ++
        (w :: rest).filter (SameSlot coin slot) := h.fifo l.core hlc' coin slot
    show l.wishes.filter (SameSlot coin slot) = ((l.arrivals ++ [arrivalRecord s w]).map (·.wish)).filter (SameSlot coin slot) ++
      rest.filter (SameSlot coin slot)
    rw [hf]
    simp only [List.map_append, List.map_cons, List.map_nil, List.filter_append, List.filter_cons, arrivalRecord]
    by_cases hk : SameSlot coin slot w = true
    · simp [hk]
    · simp [hk]

theorem applyPayload_listing_log (s : State) (e : Event) (rules : Rules) :
    (applyPayload s e (.listing rules)).1.log = s.log := by
  simp only [applyPayload]
  exact emit_log _ _ _

theorem rinv_listing (s : State) (e : Event) (rules : Rules) (h : RInv s.core) :
    RInv (applyPayload s e (.listing rules)).1.core := by
  have hk := applyPayload_keeps s e (.listing rules)
  have hl := applyPayload_listing_log s e rules
  refine rinv_congr h ?_ hk.nextTick hk.wishes ?_
  · show (applyPayload s e (.listing rules)).1.cfg.lambda = s.cfg.lambda
    rw [hk.cfg]
  · show ((applyPayload s e (.listing rules)).1.log.map Log.core).map _ = (s.log.map Log.core).map _
    rw [hl]

theorem rinv_prev (s : State) (e : Event) (h : RInv s.core) : RInv ({ s with previous := some e } : State).core :=
  rinv_congr h rfl rfl rfl rfl

theorem rinv_offer (s : State) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role)
    (h : RInv s.core) : RInv (offer s coin slot parts role).1.core := by
  obtain ⟨e1, e2, e3, _⟩ := offer_fields s coin slot parts role
  refine rinv_congr h (by show (offer s coin slot parts role).1.cfg.lambda = s.cfg.lambda; rw [e1]) e2 e3 ?_
  show ((offer s coin slot parts role).1.log.map Log.core).map _ = (s.log.map Log.core).map _
  rw [offer_log]
  cases offerPlan s coin slot parts <;> cases s.log <;> simp [Log.core]

end Engine.Machine
