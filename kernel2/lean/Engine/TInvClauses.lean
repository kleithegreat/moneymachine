import Engine.TInv

namespace Engine.Machine

open Engine.Orders (Wish)

theorem tickAt_prog (s : State) (time : Int) : (tickAt s time).1.prog = s.prog := by
  simp only [tickAt, tickBody, withLog, aged, releaseEffects, release]

theorem tinv_tick (s : State) (time ms : Int) (hS : Setup s) (hR : RInv s.core) (h : TInv s.core)
    (hn : s.nextTick = some time) (ht : s.cfg.tickMs = some ms) (hstop : time < s.cfg.stop) :
    TInv ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core := by
  have hms : 0 < ms := hS.1 ms ht
  obtain ⟨hB1, _⟩ := tickAt_batch s time
  have hbatch : (tickAt s time).2.2.wishes.map (fun x => (x.coin, x.slot)) =
      (if decidesAt (tickPre s time) time then keysOf ((List.range (tickPre s time).coins.length).map (inViewOf (tickPre s time)))
        (slotCount (tickPre s time)) else []) := (tickBody_batch (tickPre s time) time).2
  have hcfg : (tickAt s time).1.cfg = s.cfg := tickAt_cfg s time
  have hprog : (tickAt s time).1.prog = s.prog := tickAt_prog s time
  have hnt : s.core.nextTick = some time := hn
  have hd : decidesAt (tickPre s time) time = decidesC s.core time := rfl
  have hsl : slotCount (tickPre s time) = slotsC s.core := rfl
  rw [hd, hsl] at hbatch
  have hlog : ∀ l', ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core.log = some l' →
      ∃ l : Log, s.core.log = some l.core ∧
        l' = { l.core with wishes := l.wishes ++ (tickAt s time).2.2.wishes, ticks := l.ticks ++ [(time, tickView s time)] } := by
    intro l' hl'
    obtain ⟨l, hs, rfl⟩ := tick_decomp s time ms l' hl'
    exact ⟨l, by simp [StateOf.core, hs], rfl⟩
  have hdC : ∀ t, decidesC ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core t = decidesC s.core t := by
    intro t; simp [decidesC, StateOf.core, hcfg, hprog]
  have hsC : slotsC ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core = slotsC s.core := by
    simp [slotsC, StateOf.core, hprog]
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl' w hw
    obtain ⟨l, hs, rfl⟩ := hlog l' hl'
    rcases List.mem_append.1 hw with hw | hw
    · obtain ⟨tk, htk, e⟩ := h.sentTick l.core hs w hw
      exact ⟨tk, List.mem_append.2 (Or.inl htk), e⟩
    · exact ⟨(time, tickView s time), List.mem_append.2 (Or.inr (by simp)), ((hB1 w hw).1).symm⟩
  · intro l' hl' tk htk
    obtain ⟨l, hs, rfl⟩ := hlog l' hl'
    rw [hdC, hsC]
    rcases List.mem_append.1 htk with htk | htk
    · have hlt := h.beforeNext l.core hs tk htk time hnt
      have : (l.wishes ++ (tickAt s time).2.2.wishes).filter (fun w => decide (w.sent = tk.1)) =
          l.wishes.filter (fun w => decide (w.sent = tk.1)) := by
        rw [List.filter_append]
        have : (tickAt s time).2.2.wishes.filter (fun w => decide (w.sent = tk.1)) = [] := by
          rw [List.filter_eq_nil_iff]
          intro x hx
          have := (hB1 x hx).1
          simp only [decide_eq_true_eq]
          omega
        rw [this, List.append_nil]
      show ((l.wishes ++ (tickAt s time).2.2.wishes).filter (fun w => decide (w.sent = tk.1))).map _ = _
      rw [this]
      exact h.keys l.core hs tk htk
    · simp only [List.mem_singleton] at htk
      subst htk
      have hold : l.wishes.filter (fun w => decide (w.sent = time)) = [] := by
        rw [List.filter_eq_nil_iff]
        intro x hx
        have := hR.sentBefore l.core hs x hx time hnt
        simp only [decide_eq_true_eq]
        omega
      have hnew : (tickAt s time).2.2.wishes.filter (fun w => decide (w.sent = time)) = (tickAt s time).2.2.wishes := by
        rw [List.filter_eq_self]
        intro x hx
        simpa using (hB1 x hx).1
      show ((l.wishes ++ (tickAt s time).2.2.wishes).filter (fun w => decide (w.sent = time))).map _ = _
      rw [List.filter_append, hold, hnew, List.nil_append, hbatch]
      rfl
  · intro l' hl' ms' hms'
    obtain ⟨l, hs, rfl⟩ := hlog l' hl'
    have hms'' : s.core.cfg.tickMs = some ms' := by simpa [StateOf.core, hcfg] using hms'
    obtain ⟨k, hk1, hk2⟩ := h.progression l.core hs ms' hms''
    have : ms' = ms := by
      have := hms''
      simp only [StateOf.core] at this
      rw [ht] at this
      exact (Option.some.inj this).symm
    subst this
    have htime : time = firstTick s.cfg.start ms' + (k : Int) * ms' := by
      have := hk2
      simp only [StateOf.core, hn, Option.some.injEq] at this
      exact this
    have hk1' : l.ticks.map (·.1) = (List.range k).map (fun (j : Nat) => firstTick s.cfg.start ms' + (j : Int) * ms') := hk1
    refine ⟨k + 1, ?_, ?_⟩
    · show (l.ticks ++ [(time, tickView s time)]).map (·.1) =
        (List.range (k + 1)).map (fun (j : Nat) => firstTick (tickAt s time).1.cfg.start ms' + (j : Int) * ms')
      rw [hcfg, List.map_append, List.range_succ, List.map_append, hk1']
      congr 1
      simp [htime]
    · show some (time + ms') = some (firstTick (tickAt s time).1.cfg.start ms' + ((k + 1 : Nat) : Int) * ms')
      rw [hcfg]
      congr 1
      have h1 : ((1 : Nat) : Int) = 1 := rfl
      rw [htime, Int.natCast_add, Int.add_mul, h1, Int.one_mul]
      omega
  · intro l' hl' tk htk
    obtain ⟨l, hs, rfl⟩ := hlog l' hl'
    rcases List.mem_append.1 htk with htk | htk
    · have := h.beforeStop l.core hs tk htk
      simpa [StateOf.core, hcfg] using this
    · simp only [List.mem_singleton] at htk
      subst htk
      simpa [StateOf.core, hcfg] using hstop
  · intro l' hl' tk htk t ht'
    obtain ⟨l, hs, rfl⟩ := hlog l' hl'
    simp only [StateOf.core, Option.some.injEq] at ht'
    subst ht'
    rcases List.mem_append.1 htk with htk | htk
    · have := h.beforeNext l.core hs tk htk time hnt
      omega
    · simp only [List.mem_singleton] at htk
      subst htk
      omega

theorem offer_prog (s : State) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role) :
    (offer s coin slot parts role).1.prog = s.prog := by
  unfold offer
  cases offerPlan s coin slot parts with
  | none => rfl
  | some p =>
    simp only []
    unfold applyOffer pushHistory withLog
    have h1 := emit_frame s p.time [Engine.World.Effect.fill p.order p.units p.price role]
    have h2 := emit_frame (emit s p.time [Engine.World.Effect.fill p.order p.units p.price role]).1 p.time
      ((if p.ends = true then ((emit s p.time [Engine.World.Effect.fill p.order p.units p.price role]).1.acct.orders.filter
        (·.coin == coin)).map fun o => Engine.World.Effect.cancelled o "cycle_end" else []) ++
        if p.ends = true then [Engine.World.Effect.cycleEnd coin] else [])
    exact by rw [h2.prog, h1.prog]

theorem tinv_arrive (s : State) (w : Wish) (rest : List Wish) (h : TInv ({ s with wishes := w :: rest } : State).core) :
    TInv ({ (arriveWish s w).1 with wishes := rest } : State).core := by
  have fr := arriveWish_frame s w
  refine tInv_congr h fr.cfg fr.prog fr.nextTick ?_
  show ((arriveWish s w).1.log.map Log.core).map _ = (s.log.map Log.core).map _
  rw [arriveWish_log]
  cases s.log <;> simp [Log.core]

theorem tinv_listing (s : State) (e : Event) (rules : Rules) (h : TInv s.core) :
    TInv (applyPayload s e (.listing rules)).1.core := by
  have hk := applyPayload_keeps s e (.listing rules)
  have hl := applyPayload_listing_log s e rules
  refine tInv_congr h hk.cfg hk.prog hk.nextTick ?_
  show ((applyPayload s e (.listing rules)).1.log.map Log.core).map _ = (s.log.map Log.core).map _
  rw [hl]

theorem tinv_prev (s : State) (e : Event) (h : TInv s.core) : TInv ({ s with previous := some e } : State).core :=
  tInv_congr h rfl rfl rfl rfl

theorem tinv_offer (s : State) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role)
    (h : TInv s.core) : TInv (offer s coin slot parts role).1.core := by
  obtain ⟨e1, e2, _, _⟩ := offer_fields s coin slot parts role
  refine tInv_congr h e1 (offer_prog s coin slot parts role) e2 ?_
  show ((offer s coin slot parts role).1.log.map Log.core).map _ = (s.log.map Log.core).map _
  rw [offer_log]
  cases offerPlan s coin slot parts <;> cases s.log <;> simp [Log.core]

end Engine.Machine
