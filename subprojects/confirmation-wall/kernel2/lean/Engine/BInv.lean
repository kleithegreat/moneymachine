import Engine.SArrival

/-!
# S1's account invariants hold of every run (brief 3 step 5)
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book arrive cancelSlot admission)

structure BInv (c : Core) : Prop where
  shapeW : Shape c.cfg.names.length c.acct
  shapeV : Shape c.cfg.names.length c.vacct
  live : Live c.acct

theorem shape_foldl_logged {n : Nat} (fees : List Engine.Ledger.Tier) :
    ∀ (es : List Logged) (a : Acct), Shape n a → Shape n (es.foldl (fun a l => a.apply fees l.time l.effect) a) := by
  intro es
  induction es with
  | nil => intro a h; exact h
  | cons e es ih => intro a h; exact ih _ (shape_apply h fees e.time e.effect)

theorem tickAt_acct (s : State) (time : Int) : (tickAt s time).1.acct = s.acct := by
  simp only [tickAt, tickBody, withLog, aged, releaseEffects, release]

theorem tickAt_vacct_shape {n : Nat} (s : State) (time : Int) (h : Shape n s.vacct) : Shape n (tickAt s time).1.vacct := by
  have : (tickAt s time).1.vacct = (s.veffects.filter fun l => decide (l.known ≤ time)).foldl
      (fun a l => a.apply s.cfg.fees l.time l.effect) s.vacct := by
    simp only [tickAt, tickBody, withLog, aged, releaseEffects, release]
  rw [this]
  exact shape_foldl_logged _ _ _ h

theorem binv_tick (s : State) (time ms : Int) (h : BInv s.core) :
    BInv ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core := by
  have hc := tickAt_cfg s time
  have ha := tickAt_acct s time
  refine ⟨?_, ?_, ?_⟩
  · simp only [StateOf.core, hc, ha]; exact h.shapeW
  · simp only [StateOf.core, hc]; exact tickAt_vacct_shape s time h.shapeV
  · simp only [StateOf.core, ha]; exact h.live

theorem binv_arrive (s : State) (w : Wish) (rest : List Wish) (h : BInv ({ s with wishes := w :: rest } : State).core) :
    BInv ({ (arriveWish s w).1 with wishes := rest } : State).core := by
  have fr := arriveWish_frame s w
  have hacct : (arriveWish s w).1.acct = (arrivalEffects (worldBook s w.arrives) w).foldl
      (fun a e => a.apply s.cfg.fees w.arrives e) s.acct := by
    simp only [arriveWish, pushHistory, withLog]
    exact emit_acct s w.arrives _
  have hvacct : (arriveWish s w).1.vacct = s.vacct := fr.vacct
  have hok := arrivalEffects_ok s w
  refine ⟨?_, ?_, ?_⟩
  · show Shape (arriveWish s w).1.cfg.names.length (arriveWish s w).1.acct
    rw [hacct, fr.cfg]
    exact shape_foldl _ _ _ _ h.shapeW
  · show Shape (arriveWish s w).1.cfg.names.length (arriveWish s w).1.vacct
    rw [hvacct, fr.cfg]
    exact h.shapeV
  · show Live (arriveWish s w).1.acct
    rw [hacct]
    have key : ∀ (es : List Effect) (a : Acct), Live a → a.cycles = s.acct.cycles →
        (∀ e ∈ es, (∀ coin cycle, e ≠ .cycleEnd coin cycle) ∧ ∀ o, e = .placed o → o.cycle = s.acct.cycles.getD o.coin 0) →
        Live (es.foldl (fun a e => a.apply s.cfg.fees w.arrives e) a) := by
      intro es
      induction es with
      | nil => intro a ha _ _; exact ha
      | cons e es ih =>
        intro a ha hcy hes
        have hhe := hes e (List.mem_cons_self ..)
        refine ih _ (live_apply ha _ _ e (fun o ho => by rw [hcy]; exact hhe.2 o ho)) ?_
          (fun e' he' => hes e' (List.mem_cons_of_mem _ he'))
        rw [apply_cycles_of_not_end _ _ _ e hhe.1]
        exact hcy
    exact key _ _ h.live rfl hok


theorem live_foldl_noplaced (fees : List Engine.Ledger.Tier) (time : Int) :
    ∀ (es : List Effect) (a : Acct), Live a → (∀ e ∈ es, ∀ o, e ≠ .placed o) →
      Live (es.foldl (fun a e => a.apply fees time e) a) := by
  intro es
  induction es with
  | nil => intro a h _; exact h
  | cons e es ih =>
    intro a h hes
    exact ih _ (live_apply h fees time e (fun o ho => absurd ho (hes e (List.mem_cons_self ..) o)))
      (fun e' he' => hes e' (List.mem_cons_of_mem _ he'))

/-- A run of effects with no placement keeps the account's shape and its orders' cycles. -/
theorem binv_emit (s : State) (time : Int) (es : List Effect) (hes : ∀ e ∈ es, ∀ o, e ≠ .placed o) (h : BInv s.core) :
    BInv (emit s time es).1.core := by
  have fr := emit_frame s time es
  have hacct := emit_acct s time es
  refine ⟨?_, ?_, ?_⟩
  · show Shape (emit s time es).1.cfg.names.length (emit s time es).1.acct
    rw [hacct, fr.cfg]
    exact shape_foldl _ _ _ _ h.shapeW
  · show Shape (emit s time es).1.cfg.names.length (emit s time es).1.vacct
    rw [fr.vacct, fr.cfg]
    exact h.shapeV
  · show Live (emit s time es).1.acct
    rw [hacct]
    exact live_foldl_noplaced _ _ _ _ h.live hes

theorem binv_listing (s : State) (e : Event) (rules : Rules) (h : BInv s.core) :
    BInv (applyPayload s e (.listing rules)).1.core := by
  simp only [applyPayload]
  have h' : BInv ({ s with rules := setAt s.rules e.coin rules } : State).core := h
  refine binv_emit _ _ _ ?_ h'
  intro x hx o
  simp only [List.mem_ite_nil_right, List.mem_map] at hx
  obtain ⟨_, ⟨o', _, rfl⟩⟩ := hx
  simp

theorem binv_congr {c c' : Core} (h : BInv c) (hcfg : c'.cfg = c.cfg) (ha : c'.acct = c.acct) (hv : c'.vacct = c.vacct) :
    BInv c' := by
  refine ⟨?_, ?_, ?_⟩
  · rw [hcfg, ha]; exact h.shapeW
  · rw [hcfg, hv]; exact h.shapeV
  · rw [ha]; exact h.live

theorem binv_prev (s : State) (e : Event) (h : BInv s.core) : BInv ({ s with previous := some e } : State).core :=
  binv_congr h rfl rfl rfl

theorem applyOffer_acct (s : State) (coin : Nat) (p : Taken) (role : Engine.Ledger.Role) :
    (applyOffer s coin p role).1.acct = (offerFinal s coin p role).acct := rfl

theorem applyOffer_vacct (s : State) (coin : Nat) (p : Taken) (role : Engine.Ledger.Role) :
    (applyOffer s coin p role).1.vacct = s.vacct := by
  unfold applyOffer pushHistory withLog
  have h1 := emit_frame s p.time [Engine.World.Effect.fill p.order p.units p.price role]
  have h2 := emit_frame (emit s p.time [Engine.World.Effect.fill p.order p.units p.price role]).1 p.time
    ((if p.ends = true then ((emit s p.time [Engine.World.Effect.fill p.order p.units p.price role]).1.acct.orders.filter
      (·.coin == coin)).map fun o => Engine.World.Effect.cancelled o "cycle_end" else []) ++
      if p.ends = true then [Engine.World.Effect.cycleEnd coin (s.acct.cycle coin)] else [])
  exact by rw [h2.vacct, h1.vacct]

theorem binv_offer (s : State) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role)
    (h : BInv s.core) : BInv (offer s coin slot parts role).1.core := by
  obtain ⟨e1, _⟩ := offer_fields s coin slot parts role
  unfold offer
  cases hp : offerPlan s coin slot parts with
  | none => exact h
  | some p =>
    simp only []
    have h1 := binv_emit s p.time [Effect.fill p.order p.units p.price role] (by intro e he o; simp at he; subst he; simp) h
    have h2 : BInv (offerFinal s coin p role).core := by
      refine binv_emit _ _ _ ?_ h1
      intro x hx o
      simp only [List.mem_append, List.mem_map, List.mem_ite_nil_right, List.mem_singleton] at hx
      rcases hx with ⟨_, ⟨o', _, rfl⟩⟩ | ⟨_, rfl⟩
      all_goals simp
    have hvc := applyOffer_vacct s coin p role
    have hcf : (applyOffer s coin p role).1.cfg = s.cfg := by
      have := (offer_fields s coin slot parts role).1
      simpa [offer, hp] using this
    refine binv_congr h2 ?_ (applyOffer_acct s coin p role) ?_
    · show (applyOffer s coin p role).1.cfg = (offerFinal s coin p role).cfg
      rw [hcf]
      have := (emit_frame (emit s p.time [Effect.fill p.order p.units p.price role]).1 p.time
        ((if p.ends = true then ((emit s p.time [Effect.fill p.order p.units p.price role]).1.acct.orders.filter
          (·.coin == coin)).map fun o => Effect.cancelled o "cycle_end" else []) ++
          if p.ends = true then [Effect.cycleEnd coin (s.acct.cycle coin)] else [])).cfg
      unfold offerFinal
      rw [this]
      exact (emit_frame s p.time [Effect.fill p.order p.units p.price role]).cfg.symm
    · show (applyOffer s coin p role).1.vacct = (offerFinal s coin p role).vacct
      rw [hvc]
      unfold offerFinal
      have h1' := emit_frame s p.time [Effect.fill p.order p.units p.price role]
      have h2' := emit_frame (emit s p.time [Effect.fill p.order p.units p.price role]).1 p.time
        ((if p.ends = true then ((emit s p.time [Effect.fill p.order p.units p.price role]).1.acct.orders.filter
          (·.coin == coin)).map fun o => Effect.cancelled o "cycle_end" else []) ++
          if p.ends = true then [Effect.cycleEnd coin (s.acct.cycle coin)] else [])
      rw [h2'.vacct, h1'.vacct]

end Engine.Machine
