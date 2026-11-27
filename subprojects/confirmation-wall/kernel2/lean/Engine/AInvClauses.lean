import Engine.AInv

namespace Engine.Machine

open Engine.Orders (Wish)

theorem ainv_tick (s : State) (time ms : Int) (hS : Setup s) (h : AInv s.core)
    (hn : s.nextTick = some time) (ht : s.cfg.tickMs = some ms) :
    AInv ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core := by
  have hms : 0 < ms := hS.1 ms ht
  have hlam : 0 ≤ s.cfg.lambda := hS.2
  obtain ⟨hB1, _⟩ := tickAt_batch s time
  have hcfg : (tickAt s time).1.cfg = s.cfg := tickAt_cfg s time
  have hwq : (tickAt s time).1.wishes = s.wishes ++ orderWishes (tickAt s time).2.2.wishes := tickAt_wishes s time
  have hnt : s.core.nextTick = some time := hn
  have hlog : ∀ l', ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core.log = some l' →
      ∃ l : Log, s.core.log = some l.core ∧ l'.arrivals = l.arrivals ∧ l'.admissions = l.admissions ∧ l'.placed = l.placed := by
    intro l' hl'
    obtain ⟨l, hs, rfl⟩ := tick_decomp s time ms l' hl'
    exact ⟨l, by simp [StateOf.core, hs], rfl, rfl, rfl⟩
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl'; obtain ⟨l, hs, e1, _⟩ := hlog l' hl'; rw [e1]; exact h.own l.core hs
  · intro l' hl'; obtain ⟨l, hs, e1, _⟩ := hlog l' hl'; rw [e1]; exact h.sorted l.core hs
  · intro l' hl' a ha w hw'
    obtain ⟨l, hs, e1, _⟩ := hlog l' hl'
    rw [e1] at ha
    have hw'' : w ∈ s.wishes ++ orderWishes (tickAt s time).2.2.wishes := by simpa [StateOf.core, hwq] using hw'
    rcases List.mem_append.1 hw'' with hw'' | hw''
    · exact h.queue l.core hs a ha w hw''
    · have := hB1 w ((mem_orderWishes _ w).1 hw'')
      have := h.tick l.core hs a ha time hnt
      omega
  · intro l' hl' a ha t ht'
    obtain ⟨l, hs, e1, _⟩ := hlog l' hl'
    rw [e1] at ha
    simp only [StateOf.core, Option.some.injEq] at ht'
    subst ht'
    have := h.tick l.core hs a ha time hnt
    omega
  · intro l' hl' a ha
    obtain ⟨l, hs, e1, _⟩ := hlog l' hl'
    rw [e1] at ha
    have := h.stop l.core hs a ha
    simp only [StateOf.core, hcfg]
    exact this
  · intro l' hl'; obtain ⟨l, hs, _, e2, _⟩ := hlog l' hl'; rw [e2]; exact h.admPairs l.core hs
  · intro l' hl' x hx w hw'
    obtain ⟨l, hs, _, e2, _⟩ := hlog l' hl'
    rw [e2] at hx
    have hw'' : w ∈ s.wishes ++ orderWishes (tickAt s time).2.2.wishes := by simpa [StateOf.core, hwq] using hw'
    rcases List.mem_append.1 hw'' with hw'' | hw''
    · exact h.admQueue l.core hs x hx w hw''
    · intro heq
      have := hB1 w ((mem_orderWishes _ w).1 hw'')
      have := h.admTick l.core hs x hx time hnt
      omega
  · intro l' hl' x hx t ht'
    obtain ⟨l, hs, _, e2, _⟩ := hlog l' hl'
    rw [e2] at hx
    simp only [StateOf.core, Option.some.injEq] at ht'
    subst ht'
    have := h.admTick l.core hs x hx time hnt
    omega
  · intro l' hl'; obtain ⟨l, hs, _, e2, e3⟩ := hlog l' hl'; rw [e2, e3]; exact h.placedAdm l.core hs

theorem ainv_arrive (s : State) (w : Wish) (rest : List Wish) (b : Int)
    (hR : RInv ({ s with wishes := w :: rest } : State).core) (h : AInv ({ s with wishes := w :: rest } : State).core)
    (hb : w.arrives < b) (hnext : ∀ t, s.nextTick = some t → b ≤ t) (hstop : b ≤ s.cfg.stop) :
    AInv ({ (arriveWish s w).1 with wishes := rest } : State).core := by
  have fr := arriveWish_frame s w
  have hcfg : (arriveWish s w).1.cfg = s.cfg := fr.cfg
  have hnx : (arriveWish s w).1.nextTick = s.nextTick := fr.nextTick
  have hlog : ∀ l', ({ (arriveWish s w).1 with wishes := rest } : State).core.log = some l' →
      ∃ l : Log, ({ s with wishes := w :: rest } : State).core.log = some l.core ∧
        l'.arrivals = l.arrivals ++ [arrivalRecord s w] ∧ l'.admissions = l.admissions ++ arrivalAdmissions s w ∧
        l'.placed = l.placed ++ arrivalPlaced s w := by
    intro l' hl'
    obtain ⟨l, hs, rfl⟩ := arrive_decomp s w rest l' hl'
    exact ⟨l, by simp [StateOf.core, hs], rfl, rfl, rfl⟩
  have hhead : ∀ w' ∈ rest, wishLe w w' = true ∧ (w.arrives = w'.arrives → (w.coin, w.slot) ≠ (w'.coin, w'.slot)) :=
    fun w' hw' => (List.pairwise_cons.1 hR.queueSorted).1 w' hw'
  have hwq : w ∈ ({ s with wishes := w :: rest } : State).core.wishes := List.mem_cons_self ..
  have hlogged := arrival_logged s w
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl' a ha
    obtain ⟨l, hs, e1, _⟩ := hlog l' hl'
    rw [e1] at ha
    rcases List.mem_append.1 ha with ha | ha
    · exact h.own l.core hs a ha
    · simp only [List.mem_singleton] at ha
      subst ha
      exact ⟨rfl, rfl⟩
  · intro l' hl'
    obtain ⟨l, hs, e1, _⟩ := hlog l' hl'
    rw [e1]
    refine List.pairwise_append.2 ⟨h.sorted l.core hs, List.pairwise_singleton _ _, ?_⟩
    intro a ha b hb'
    simp only [List.mem_singleton] at hb'
    subst hb'
    exact h.queue l.core hs a ha w hwq
  · intro l' hl' a ha w' hw'
    obtain ⟨l, hs, e1, _⟩ := hlog l' hl'
    rw [e1] at ha
    rcases List.mem_append.1 ha with ha | ha
    · exact h.queue l.core hs a ha w' (List.mem_cons_of_mem _ hw')
    · simp only [List.mem_singleton] at ha
      subst ha
      exact wishLe_arrives (hhead w' hw').1
  · intro l' hl' a ha t ht
    obtain ⟨l, hs, e1, _⟩ := hlog l' hl'
    rw [e1] at ha
    simp only [StateOf.core, hnx] at ht
    have hbt := hnext t ht
    rcases List.mem_append.1 ha with ha | ha
    · have := h.tick l.core hs a ha t (by simpa [StateOf.core] using ht)
      exact this
    · simp only [List.mem_singleton] at ha
      subst ha
      show w.arrives < t
      omega
  · intro l' hl' a ha
    obtain ⟨l, hs, e1, _⟩ := hlog l' hl'
    rw [e1] at ha
    simp only [StateOf.core, hcfg]
    rcases List.mem_append.1 ha with ha | ha
    · exact h.stop l.core hs a ha
    · simp only [List.mem_singleton] at ha
      subst ha
      show w.arrives < s.cfg.stop
      omega
  · intro l' hl'
    obtain ⟨l, hs, _, e2, _⟩ := hlog l' hl'
    rw [e2]
    rcases hlogged with ⟨_, hA⟩ | ⟨o, r, _, hA, _, hp⟩ | ⟨o, v, _, hA, _, hp, _⟩
    · rw [hA, List.append_nil]; exact h.admPairs l.core hs
    · rw [hA]
      obtain ⟨hpl, hro, hco, hsl, _⟩ := prepare_fields hp
      refine List.pairwise_append.2 ⟨h.admPairs l.core hs, List.pairwise_singleton _ _, ?_⟩
      intro a ha x hx heq
      simp only [List.mem_singleton] at hx
      subst hx
      have := h.admQueue l.core hs a ha w hwq (by rw [heq]; exact hpl)
      simpa [orderKey, wishKey, hro, hco, hsl] using this
    · rw [hA]
      obtain ⟨hpl, hro, hco, hsl, _⟩ := prepare_fields hp
      refine List.pairwise_append.2 ⟨h.admPairs l.core hs, List.pairwise_singleton _ _, ?_⟩
      intro a ha x hx heq
      simp only [List.mem_singleton] at hx
      subst hx
      have := h.admQueue l.core hs a ha w hwq (by rw [heq]; exact hpl)
      simpa [orderKey, wishKey, hro, hco, hsl] using this
  · intro l' hl' x hx w' hw'
    obtain ⟨l, hs, _, e2, _⟩ := hlog l' hl'
    rw [e2] at hx
    rcases List.mem_append.1 hx with hx | hx
    · exact h.admQueue l.core hs x hx w' (List.mem_cons_of_mem _ hw')
    · rcases hlogged with ⟨_, hA⟩ | ⟨o, r, _, hA, _, hp⟩ | ⟨o, v, _, hA, _, hp, _⟩
      · rw [hA] at hx; simp at hx
      · rw [hA] at hx
        simp only [List.mem_singleton] at hx
        subst hx
        obtain ⟨hpl, hro, hco, hsl, _⟩ := prepare_fields hp
        intro heq
        have := keyLt_of_sorted (hhead w' hw') (by rw [← heq]; exact hpl.symm)
        simpa [orderKey, wishKey, hro, hco, hsl] using this
      · rw [hA] at hx
        simp only [List.mem_singleton] at hx
        subst hx
        obtain ⟨hpl, hro, hco, hsl, _⟩ := prepare_fields hp
        intro heq
        have := keyLt_of_sorted (hhead w' hw') (by rw [← heq]; exact hpl.symm)
        simpa [orderKey, wishKey, hro, hco, hsl] using this
  · intro l' hl' x hx t ht
    obtain ⟨l, hs, _, e2, _⟩ := hlog l' hl'
    rw [e2] at hx
    simp only [StateOf.core, hnx] at ht
    have hbt := hnext t ht
    rcases List.mem_append.1 hx with hx | hx
    · exact h.admTick l.core hs x hx t (by simpa [StateOf.core] using ht)
    · rcases hlogged with ⟨_, hA⟩ | ⟨o, r, _, hA, _, hp⟩ | ⟨o, v, _, hA, _, hp, _⟩
      · rw [hA] at hx; simp at hx
      · rw [hA] at hx
        simp only [List.mem_singleton] at hx
        subst hx
        obtain ⟨hpl, _⟩ := prepare_fields hp
        show o.placed < t
        omega
      · rw [hA] at hx
        simp only [List.mem_singleton] at hx
        subst hx
        obtain ⟨hpl, _⟩ := prepare_fields hp
        show o.placed < t
        omega
  · intro l' hl'
    obtain ⟨l, hs, _, e2, e3⟩ := hlog l' hl'
    have hp0 : l.placed.map (·.order) = l.admissions.filterMap fun a => (Engine.Orders.admit (Engine.Orders.admission a.1 a.2)).toOption :=
      h.placedAdm l.core hs
    rw [e2, e3, List.map_append, List.filterMap_append, hp0]
    rcases hlogged with ⟨hP, hA⟩ | ⟨o, r, hP, hA, hadm, _⟩ | ⟨o, v, hP, hA, hadm, _⟩
    · simp [hP, hA]
    · simp [hP, hA, hadm, Except.toOption]
    · simp [hP, hA, hadm, Except.toOption]

theorem ainv_listing (s : State) (e : Event) (rules : Rules) (h : AInv s.core) :
    AInv (applyPayload s e (.listing rules)).1.core := by
  have hk := applyPayload_keeps s e (.listing rules)
  have hl := applyPayload_listing_log s e rules
  refine aInv_congr h ?_ hk.nextTick hk.wishes ?_
  · show (applyPayload s e (.listing rules)).1.cfg.stop = s.cfg.stop
    rw [hk.cfg]
  · show ((applyPayload s e (.listing rules)).1.log.map Log.core).map _ = (s.log.map Log.core).map _
    rw [hl]

theorem ainv_prev (s : State) (e : Event) (h : AInv s.core) : AInv ({ s with previous := some e } : State).core :=
  aInv_congr h rfl rfl rfl rfl

theorem ainv_offer (s : State) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role)
    (h : AInv s.core) : AInv (offer s coin slot parts role).1.core := by
  obtain ⟨e1, e2, e3, _⟩ := offer_fields s coin slot parts role
  refine aInv_congr h (by show (offer s coin slot parts role).1.cfg.stop = s.cfg.stop; rw [e1]) e2 e3 ?_
  show ((offer s coin slot parts role).1.log.map Log.core).map _ = (s.log.map Log.core).map _
  rw [offer_log]
  cases offerPlan s coin slot parts <;> cases s.log <;> simp [Log.core]

end Engine.Machine
