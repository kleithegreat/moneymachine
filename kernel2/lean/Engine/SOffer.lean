import Engine.SBook
import Engine.Exact
import Engine.DeliveryWorld

/-!
# What an offer that takes something has (brief 3 step 5; S1)
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Order Book Side)


theorem ofUnits_nonneg (scale : Nat) (n : Nat) : 0 ≤ ofUnits scale (n : Int) := by
  unfold ofUnits
  have h1 : (0 : Rat) ≤ ((n : Int) : Rat) := by exact_mod_cast Int.natCast_nonneg n
  have h2 : (0 : Rat) < (10 : Rat) ^ scale := Rat.pow_pos (by decide)
  exact Engine.Exact.div_nonneg' h2 h1

theorem walk_bounds (scale : Nat) : ∀ (parts : List (Nat × Rat)) (rem : Rat), 0 ≤ rem →
    0 ≤ (walk scale rem parts).1 ∧ (walk scale rem parts).1 ≤ rem := by
  intro parts
  induction parts with
  | nil => intro rem h; simp [walk, h]
  | cons p rest ih =>
    intro rem h
    obtain ⟨lots, price⟩ := p
    have hl := ofUnits_nonneg scale lots
    have ht1 : min rem (ofUnits scale (lots : Int)) ≤ rem := by grind
    have ht2 : 0 ≤ min rem (ofUnits scale (lots : Int)) := by grind
    obtain ⟨h1, h2⟩ := ih (rem - min rem (ofUnits scale (lots : Int))) (by grind)
    simp only [walk]
    constructor <;> grind

theorem remainder_nonneg (a : Acct) (o : Order) : 0 ≤ a.remainder o := by
  unfold Acct.remainder Acct.reducible
  have hr : ∀ side, 0 ≤ (match side with | Side.sell => max 0 (a.position o.coin) | Side.buy => max 0 (-a.position o.coin) : Rat) := by
    intro side; cases side <;> grind
  cases o.target with
  | none => exact hr o.side
  | some t =>
    simp only []
    split
    · have := hr o.side; grind
    · grind

/-- What an offer that takes something is made of. -/
theorem offerPlan_spec {s : State} {coin slot : Nat} {parts : List (Nat × Rat)} {p : Taken}
    (h : offerPlan s coin slot parts = some p) :
    ∃ (last : Event) (m : Rat), s.previous = some last ∧ s.acct.live coin slot = some p.order ∧ p.time = last.time ∧
      p.remaining = s.acct.remainder p.order ∧ p.remaining ≠ 0 ∧
      m = (walk (s.rules.getD coin default).szDecimals p.remaining parts).1 ∧ m ≠ 0 ∧
      p.units = (match p.order.side with | .buy => m | .sell => -m) ∧
      fillAccepted s.cfg.fees s.acct.ledger last.time coin p.units p.price = true ∧
      p.ends = (s.acct.position coin != 0 && s.acct.position coin + p.units == 0) := by
  unfold offerPlan at h
  split at h
  · rename_i order last hrej hlive hprev
    dsimp only at h
    generalize hw : walk (s.rules.getD coin default).szDecimals (s.acct.remainder order) parts = taken at h
    simp at h
    obtain ⟨⟨⟨⟨h1, h2⟩, h3⟩, h4⟩, hp⟩ := h
    subst hp
    refine ⟨last, taken.1, hprev, hlive, rfl, rfl, ?_, by rw [← hw], ?_, ?_, ?_, rfl⟩
    · exact h1
    · exact h3
    · cases order.side <;> rfl
    · exact h4
  · simp at h

theorem live_spec {a : Acct} {coin slot : Nat} {o : Order} (h : a.live coin slot = some o) :
    o ∈ a.orders ∧ o.coin = coin ∧ o.slot = slot := by
  unfold Acct.live at h
  have hm := List.mem_of_find?_eq_some h
  have hp := List.find?_some h
  simp only [Bool.and_eq_true, beq_iff_eq] at hp
  exact ⟨hm, hp.1, hp.2⟩

/-- The account after the fill of an offer's order. -/
def fillAcct (s : State) (p : Taken) (role : Engine.Ledger.Role) : Acct :=
  s.acct.apply s.cfg.fees p.time (.fill p.order p.units p.price role)

theorem fillAcct_cycles (s : State) (p : Taken) (role : Engine.Ledger.Role) : (fillAcct s p role).cycles = s.acct.cycles :=
  apply_cycles_of_not_end _ _ _ _ (fun _ _ => by simp)

theorem fillAcct_position {s : State} {coin slot : Nat} {parts : List (Nat × Rat)} {p : Taken} {role : Engine.Ledger.Role}
    (h : offerPlan s coin slot parts = some p) (hn : coin < s.acct.ledger.positions.length) :
    (fillAcct s p role).position coin = s.acct.position coin + p.units := by
  obtain ⟨last, m, _, hlive, hpt, _, _, _, _, _, hacc, _⟩ := offerPlan_spec h
  obtain ⟨_, hco, _⟩ := live_spec hlive
  obtain ⟨r, hr⟩ := fillAccepted_ok hacc role
  have hr' : Engine.Ledger.step s.cfg.fees s.acct.ledger (.fill p.time p.order.coin p.units p.price role) = .ok r := by
    rw [hpt, hco]; exact hr
  obtain ⟨hlt, hpos⟩ := ledger_fill_ok hr'
  unfold fillAcct Acct.apply Acct.position
  simp only [hr']
  unfold Engine.Ledger.position
  rw [hpos, ← hco]
  simp [Engine.Ledger.fillPosition, hco, Engine.Ledger.position, hn]

theorem foldl_cancels (fees : List Engine.Ledger.Tier) (time : Int) (cause : String) :
    ∀ (os : List Order) (a : Acct),
      ((os.map fun o => Effect.cancelled o cause).foldl (fun a e => a.apply fees time e) a).ledger = a.ledger ∧
      ((os.map fun o => Effect.cancelled o cause).foldl (fun a e => a.apply fees time e) a).cycles = a.cycles ∧
      ((os.map fun o => Effect.cancelled o cause).foldl (fun a e => a.apply fees time e) a).filled = a.filled ∧
      ((os.map fun o => Effect.cancelled o cause).foldl (fun a e => a.apply fees time e) a).openings = a.openings ∧
      ∀ o ∈ ((os.map fun o => Effect.cancelled o cause).foldl (fun a e => a.apply fees time e) a).orders, o ∈ a.orders := by
  intro os
  induction os with
  | nil => intro a; exact ⟨rfl, rfl, rfl, rfl, fun o ho => ho⟩
  | cons x os ih =>
    intro a
    obtain ⟨h1, h2, h3, h4, h5⟩ := ih (a.apply fees time (.cancelled x cause))
    simp only [List.map_cons, List.foldl_cons]
    refine ⟨h1, h2, h3, h4, fun o ho => ?_⟩
    have := h5 o ho
    simp only [Acct.apply, List.mem_filter] at this
    exact this.1

theorem apply_cycleEnd_cycles (fees : List Engine.Ledger.Tier) (time : Int) (a : Acct) (coin c : Nat) :
    (a.apply fees time (.cycleEnd coin c)).cycles = replaceAt a.cycles coin (fun _ => c + 1) := rfl

theorem apply_cycleEnd_ledger (fees : List Engine.Ledger.Tier) (time : Int) (a : Acct) (coin c : Nat) :
    (a.apply fees time (.cycleEnd coin c)).ledger = a.ledger := rfl

theorem apply_cycleEnd_filled (fees : List Engine.Ledger.Tier) (time : Int) (a : Acct) (coin c : Nat) :
    (a.apply fees time (.cycleEnd coin c)).filled = replaceAt a.filled coin (fun _ => []) := rfl

theorem apply_cycleEnd_orders (fees : List Engine.Ledger.Tier) (time : Int) (a : Acct) (coin c : Nat) :
    (a.apply fees time (.cycleEnd coin c)).orders = a.orders.filter (fun x => x.coin != coin) := rfl

theorem offerFinal_acct_noend (s : State) (coin : Nat) (p : Taken) (role : Engine.Ledger.Role) (h : p.ends = false) :
    (offerFinal s coin p role).acct = fillAcct s p role := by
  unfold offerFinal
  dsimp only
  rw [emit_acct, emit_acct]
  simp [h, fillAcct, (emit_frame s p.time _).cfg]

theorem offerFinal_acct_end (s : State) (coin : Nat) (p : Taken) (role : Engine.Ledger.Role) (h : p.ends = true) :
    (offerFinal s coin p role).acct =
      (((((fillAcct s p role).orders.filter (·.coin == coin)).map fun o => Effect.cancelled o "cycle_end").foldl
        (fun a e => a.apply s.cfg.fees p.time e) (fillAcct s p role)).apply s.cfg.fees p.time
        (.cycleEnd coin (s.acct.cycle coin))) := by
  unfold offerFinal
  dsimp only
  rw [emit_acct, emit_acct]
  have hc := (emit_frame s p.time [Effect.fill p.order p.units p.price role]).cfg
  simp [h, fillAcct, hc, List.foldl_append]

theorem offerFinal_ends {s : State} {coin slot : Nat} {parts : List (Nat × Rat)} {p : Taken} {role : Engine.Ledger.Role}
    (h : offerPlan s coin slot parts = some p) (he : p.ends = true) (hn : coin < s.acct.ledger.positions.length)
    (hf : coin < s.acct.filled.length) :
    (offerFinal s coin p role).acct.cycles = replaceAt s.acct.cycles coin (fun _ => s.acct.cycle coin + 1) ∧
    (offerFinal s coin p role).acct.position coin = 0 ∧
    (∀ slot, (offerFinal s coin p role).acct.filledAt coin slot = 0) ∧
    (∀ o ∈ (offerFinal s coin p role).acct.orders, o.coin ≠ coin) := by
  obtain ⟨_, _, _, _, _, _, _, _, _, _, _, hends⟩ := offerPlan_spec h
  have hpos := fillAcct_position (role := role) h hn
  rw [offerFinal_acct_end s coin p role he]
  obtain ⟨c1, c2, c3, c4, c5⟩ := foldl_cancels s.cfg.fees p.time "cycle_end" ((fillAcct s p role).orders.filter (·.coin == coin))
    (fillAcct s p role)
  refine ⟨?_, ?_, ?_, ?_⟩
  · rw [apply_cycleEnd_cycles, c2, fillAcct_cycles]
  · unfold Acct.position
    rw [apply_cycleEnd_ledger, c1]
    have := hends
    rw [he] at this
    have h2 := this.symm
    simp only [Bool.and_eq_true, bne_iff_ne, ne_eq, beq_iff_eq] at h2
    unfold Acct.position at hpos
    rw [hpos]
    exact h2.2
  · intro slot
    unfold Acct.filledAt
    rw [apply_cycleEnd_filled, c3]
    have hl : coin < (fillAcct s p role).filled.length := by
      unfold fillAcct; rw [apply_filled_length]; exact hf
    rw [replaceAt_getD_self _ _ _ _ hl]
    simp
  · intro o ho
    rw [apply_cycleEnd_orders] at ho
    simp only [List.mem_filter, bne_iff_ne, ne_eq] at ho
    exact ho.2

end Engine.Machine
