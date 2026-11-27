import Engine.RunSim

/-!
# X1: placement rounds the wish by the rules in force at arrival (kernel-v2.md A6; brief 3 step 5)

Every placement an instrumented run logs holds the order the book's `prepare` made of the original wish: its price and
target are the wish's rounded by the coin's rules at the arrival.
-/

namespace Engine.Machine

open Engine.Orders

variable {α : Type}

/-- The placements a state's log holds. -/
def loggedPlaced (s : StateOf α) : List Placement := (s.log.map (·.placed)).getD []

/-- X1's conjunct on one placement. -/
def PlacedGood (p : Placement) : Prop :=
  p.order.price = (match p.order.side with
    | .buy => Engine.Exact.roundPriceBuy p.rules.figures p.rules.decimals p.value.price
    | .sell => Engine.Exact.roundPriceSell p.rules.figures p.rules.decimals p.value.price) ∧
  p.order.target = p.value.target.map (fun target => Engine.Exact.roundSize target (1 / (10 : Rat) ^ p.rules.szDecimals))

/-- `t` has the placements of `s` and, after them, good ones. -/
def PlExt (s t : StateOf α) : Prop := ∃ new, loggedPlaced t = loggedPlaced s ++ new ∧ ∀ p ∈ new, PlacedGood p

theorem PlExt.refl (s : StateOf α) : PlExt s s := ⟨[], by simp, by simp⟩

theorem PlExt.trans {s t u : StateOf α} (h : PlExt s t) (h' : PlExt t u) : PlExt s u := by
  obtain ⟨n, hn, gn⟩ := h
  obtain ⟨m, hm, gm⟩ := h'
  refine ⟨n ++ m, by rw [hm, hn, List.append_assoc], ?_⟩
  intro p hp
  rcases List.mem_append.1 hp with h | h
  · exact gn p h
  · exact gm p h

theorem PlExt.of_placed {s t : StateOf α} (h : loggedPlaced t = loggedPlaced s) : PlExt s t := ⟨[], by simp [h], by simp⟩

theorem PlExt.of_log {s t : StateOf α} (h : t.log = s.log) : PlExt s t := PlExt.of_placed (by simp [loggedPlaced, h])

theorem PlExt.of_nolog {s t : StateOf α} (h : t.log = s.log) : PlExt s t := PlExt.of_log h

theorem emit_log (s : StateOf α) (time : Int) (es : List Engine.World.Effect) : (emit s time es).1.log = s.log := by
  unfold emit
  have : ∀ (l : List Engine.World.Effect) (a : StateOf α) (r : String), (l.foldl (emitOne time) (a, r)).1.log = a.log := by
    intro l
    induction l with
    | nil => intro a r; rfl
    | cons e l ih => intro a r; exact ih _ _
  exact this es s ""

theorem ite_none_some {β : Type} {c : Prop} [Decidable c] {a o : β} (h : (if c then none else some a) = some o) :
    a = o := by
  by_cases hc : c
  · simp [hc] at h
  · simp only [hc, ↓reduceIte, Option.some.injEq] at h
    exact h

theorem prepare_some {b : Book} {w : Wish} {o : Order} (h : Engine.Orders.prepare b w = some o) :
    ∃ v, w.value = some v ∧ o.side = w.side ∧
      o.price = roundedPrice (b.rules w.coin) w.side v.price ∧ o.target = roundedTarget (b.rules w.coin) v := by
  unfold Engine.Orders.prepare at h
  split at h
  · simp at h
  · split at h
    · simp at h
    · rename_i v hv
      dsimp only at h
      have h' := ite_none_some h
      subst h'
      exact ⟨v, hv, rfl, rfl, rfl⟩

theorem placement_good (book : Book) (w : Wish) (step : Nat) :
    ∀ p ∈ ((Engine.Orders.prepare (cancelSlot book w.coin w.slot) w).bind fun o =>
        w.value.map fun v => (⟨o, v, book.rules w.coin, step⟩ : Placement)).toList, PlacedGood p := by
  intro p hp
  cases hc : Engine.Orders.prepare (cancelSlot book w.coin w.slot) w with
  | none => rw [hc] at hp; simp at hp
  | some o =>
    rw [hc] at hp
    obtain ⟨v, hv, hside, hprice, htarget⟩ := prepare_some hc
    rw [hv] at hp
    simp only [Option.bind_some, Option.map_some, Option.toList_some, List.mem_singleton] at hp
    subst hp
    have hr : (cancelSlot book w.coin w.slot).rules w.coin = book.rules w.coin := rfl
    rw [hr] at hprice htarget
    refine ⟨?_, ?_⟩
    · show o.price = _
      rw [hside, hprice]
      cases w.side <;> rfl
    · show o.target = _
      rw [htarget]
      rfl

theorem arriveWish_ext (s : StateOf α) (w : Wish) : PlExt s (arriveWish s w).1 := by
  unfold arriveWish
  simp only []
  cases hl : s.log with
  | none =>
    apply PlExt.of_log
    simp [pushHistory, withLog, emit_log, hl]
  | some l =>
    refine ⟨if (arrive (worldBook s w.arrives) w).2.contains "placed" = true then
        ((Engine.Orders.prepare (cancelSlot (worldBook s w.arrives) w.coin w.slot) w).bind fun o =>
          w.value.map fun v => (⟨o, v, (worldBook s w.arrives).rules w.coin, stepCount s⟩ : Placement)).toList
      else [], ?_, ?_⟩
    · simp only [loggedPlaced, pushHistory, withLog, emit_log, hl, Option.map_some, Option.getD_some]
    · intro p hp
      split at hp
      · exact placement_good _ _ _ p hp
      · simp at hp

theorem pushHistory_ext (s : StateOf α) (time : Int) : PlExt s (pushHistory s time) :=
  PlExt.of_placed (by cases hl : s.log <;> simp [loggedPlaced, pushHistory, withLog, hl])

theorem drainOne_ext (acc : StateOf α × String) (w : Wish) : PlExt acc.1 (drainOne acc w).1 :=
  arriveWish_ext acc.1 w

theorem foldl_drainOne_ext (l : List Wish) : ∀ acc : StateOf α × String, PlExt acc.1 (l.foldl drainOne acc).1 := by
  induction l with
  | nil => intro acc; exact PlExt.refl _
  | cons w l ih => intro acc; exact (drainOne_ext acc w).trans (ih _)

theorem drain_ext (s : StateOf α) (b : Int) : PlExt s (drain s b).1 := by
  unfold drain
  have h := foldl_drainOne_ext (s.wishes.takeWhile fun w => decide (w.arrives < b))
    ({ s with wishes := s.wishes.dropWhile fun w => decide (w.arrives < b) }, "")
  exact PlExt.trans (PlExt.of_log rfl) h

theorem tickAt_ext [Engine.Lang.Numbers α] (s : StateOf α) (time : Int) : PlExt s (tickAt s time).1 := by
  apply PlExt.of_placed
  cases hl : s.log <;> simp [loggedPlaced, tickAt, tickBody, withLog, aged, releaseEffects, release, hl]

theorem fireRec_ext [Engine.Lang.Numbers α] (n : Nat) :
    ∀ (s : StateOf α) (acc : Rows) (recs : List TickRecord), PlExt s (fireRec n s acc recs).1 := by
  induction n with
  | zero => intro s acc recs; exact PlExt.refl _
  | succ n ih =>
    intro s acc recs
    simp only [fireRec]
    cases hn : s.nextTick with
    | none => exact PlExt.refl _
    | some time =>
      cases ht : s.cfg.tickMs with
      | none => exact PlExt.refl _
      | some ms =>
        simp only []
        refine (drain_ext s time).trans (((tickAt_ext _ time).trans (PlExt.of_log rfl)).trans (ih _ _ _))

theorem settle_ext [Engine.Lang.Numbers α] (s : StateOf α) (b : Int) (acc : Rows) : PlExt s (settle s b acc).1 := by
  unfold settle
  exact (fireRec_ext _ s acc []).trans (drain_ext _ b)

theorem withPending_keeps_log (s : StateOf α) (e : Event) (what : Unit → PView) :
    (withPending s e what).log = s.log := by
  unfold withPending
  split <;> rfl

theorem applyPayload_ext (s : StateOf α) (e : Event) (r : Reading) : PlExt s (applyPayload s e r).1 := by
  apply PlExt.of_log
  cases r with
  | listing rules => exact emit_log _ _ _
  | ending price => simp only [applyPayload]; exact withPending_keeps_log _ _ _
  | funding hour rate oracle => simp only [applyPayload]; exact withPending_keeps_log _ _ _
  | trade id price size sizeScale seller => simp only [applyPayload]; exact withPending_keeps_log _ _ _
  | quote bid bidSize ask askSize sizeScale => simp only [applyPayload]; exact withPending_keeps_log _ _ _
  | observation source bits => simp only [applyPayload]; exact withPending_keeps_log _ _ _

theorem advanceRec_ext [Engine.Lang.Numbers α] (s : StateOf α) (e : Event) (r : Reading) :
    PlExt s (advanceRec s e r).1 := by
  unfold advanceRec
  exact ((settle_ext s e.time Rows.empty).trans (applyPayload_ext _ e r)).trans
    ((pushHistory_ext _ e.time).trans (PlExt.of_log rfl))

theorem step_ext [Engine.Lang.Numbers α] (s : StateOf α) (e : Event) : PlExt s (step s e).1 := by
  unfold step
  cases s.rejected with
  | some f => exact PlExt.refl _
  | none =>
    simp only []
    cases admit s e with
    | error fault => exact PlExt.of_log rfl
    | ok reading => exact advanceRec_ext s e reading

theorem goAcc_ext [Engine.Lang.Numbers α] : ∀ (es : List Event) (s : StateOf α) (acc : Rows), PlExt s (goAcc s es acc).1 := by
  intro es
  induction es with
  | nil => intro s acc; exact PlExt.refl _
  | cons e es ih => intro s acc; exact (step_ext s e).trans (ih _ _)

theorem feed_ext [Engine.Lang.Numbers α] (s : StateOf α) (c : Chunk) : PlExt s (feed s c).1 := by
  unfold feed
  cases s.rejected with
  | some f => exact PlExt.refl _
  | none =>
    simp only []
    cases decodeChunk s c with
    | error code => exact PlExt.of_log rfl
    | ok events => exact goAcc_ext events s Rows.empty

theorem offer_ext (s : StateOf α) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role) :
    PlExt s (offer s coin slot parts role).1 := by
  unfold offer
  cases offerPlan s coin slot parts with
  | none => exact PlExt.refl _
  | some p =>
    simp only []
    unfold applyOffer
    simp only []
    apply PlExt.of_placed
    cases hl : s.log <;> simp [loggedPlaced, pushHistory, withLog, emit_log, hl]

theorem finishFull_ext [Engine.Lang.Numbers α] (s : StateOf α) : PlExt s (finishFull s).1 := by
  unfold finishFull
  cases s.rejected with
  | some f => exact PlExt.refl _
  | none =>
    simp only []
    exact settle_ext s _ _

theorem runMoves_ext [Engine.Lang.Numbers α] (moves : List Move) : ∀ (s : StateOf α) (rows : Rows),
    PlExt s (moves.foldl (fun (acc : StateOf α × Rows) move =>
      let next := match move with
        | .event e => feed acc.1 (pack [e])
        | .offer coin slot parts role => offer acc.1 coin slot parts role
      (next.1, acc.2 ++ next.2)) (s, rows)).1 := by
  induction moves with
  | nil => intro s rows; exact PlExt.refl _
  | cons m moves ih =>
    intro s rows
    cases m with
    | event e => exact (feed_ext s _).trans (ih _ _)
    | offer coin slot parts role => exact (offer_ext s coin slot parts role).trans (ih _ _)

/-- X1's first conjunct, over every evaluator. -/
theorem orderRun_placed {β : Type} (N : Engine.Lang.NumOps β) (s : State) (moves : List Move)
    (run : Engine.Orders.Run) (hr : orderRun N s moves = some run) : ∀ p ∈ run.placed, PlacedGood p := by
  letI : Engine.Lang.Numbers β := ⟨N⟩
  unfold orderRun at hr
  dsimp only at hr
  have h1 := runMoves_ext moves (s.recast N) Rows.empty
  rcases hrm : runMoves (s.recast N) moves with ⟨fed1, rows1⟩
  have h1' : PlExt (s.recast N) fed1 := by
    have : (runMoves (s.recast N) moves).1 = fed1 := by rw [hrm]
    rw [← this]; exact h1
  rw [hrm] at hr
  dsimp only at hr
  have h2 := finishFull_ext fed1
  rcases hff : finishFull fed1 with ⟨final1, rest1, summary1⟩
  rw [hff] at hr
  dsimp only at hr
  have h2' : PlExt fed1 final1 := by
    have : (finishFull fed1).1 = final1 := by rw [hff]
    rw [← this]; exact h2
  cases hl : final1.log with
  | none => rw [hl] at hr; simp at hr
  | some l =>
    rw [hl] at hr
    dsimp only at hr
    split at hr
    · injection hr with hr
      subst hr
      obtain ⟨n, hn, gn⟩ := h1'.trans h2'
      intro p hp
      have : loggedPlaced final1 = l.placed := by simp [loggedPlaced, hl]
      have h0 : loggedPlaced (s.recast N) = [] := by simp [loggedPlaced, StateOf.recast, Log.empty]
      rw [h0, this] at hn
      have hp' : p ∈ l.placed := hp
      rw [hn] at hp'
      exact gn p (by simpa using hp')
    · simp at hr

end Engine.Machine
