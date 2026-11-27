import Engine.Delivery

/-!
# The instrumented log never feeds back (brief 3 step 5; X1's third conjunct)

An instrumented run keeps a log beside the state. Nothing the machine does reads it but to extend it, so the rows and
every other field of a run are those of the same run with another log.
-/

namespace Engine.Machine

open Engine.Orders (Wish)

variable {α : Type}

/-- Every field but the log is the same. -/
def Nolog (s t : StateOf α) : Prop := ∃ x, t = { s with log := x }

theorem Nolog.refl (s : StateOf α) : Nolog s s := ⟨s.log, rfl⟩

theorem Nolog.trans {s t u : StateOf α} (h : Nolog s t) (h' : Nolog t u) : Nolog s u := by
  obtain ⟨x, rfl⟩ := h
  obtain ⟨y, rfl⟩ := h'
  exact ⟨y, rfl⟩

theorem Nolog.set (s : StateOf α) (x : Option Log) : Nolog s { s with log := x } := ⟨x, rfl⟩

theorem emit_nolog (s : StateOf α) (x : Option Log) (time : Int) (es : List Engine.World.Effect) :
    (emit { s with log := x } time es).2 = (emit s time es).2 ∧
    (emit { s with log := x } time es).1 = { (emit s time es).1 with log := x } := by
  unfold emit
  have key : ∀ (l : List Engine.World.Effect) (a : StateOf α) (r : String),
      (l.foldl (emitOne time) ({ a with log := x }, r)).2 = (l.foldl (emitOne time) (a, r)).2 ∧
      (l.foldl (emitOne time) ({ a with log := x }, r)).1 = { (l.foldl (emitOne time) (a, r)).1 with log := x } := by
    intro l
    induction l with
    | nil => intro a r; exact ⟨rfl, rfl⟩
    | cons e l ih =>
      intro a r
      simp only [List.foldl_cons]
      exact ih (emitOne time (a, r) e).1 (emitOne time (a, r) e).2
  exact key es s ""

theorem pushHistory_nolog (s : StateOf α) (time : Int) : Nolog s (pushHistory s time) := ⟨_, rfl⟩

theorem arriveWish_nolog (s : StateOf α) (x : Option Log) (w : Wish) :
    (arriveWish { s with log := x } w).2 = (arriveWish s w).2 ∧
    Nolog (arriveWish s w).1 (arriveWish { s with log := x } w).1 := by
  refine ⟨?_, (arriveWish { s with log := x } w).1.log, ?_⟩
  · unfold arriveWish pushHistory withLog
    simp only []
    rw [(emit_nolog s x _ _).1]
    rfl
  · unfold arriveWish pushHistory withLog
    simp only []
    rw [(emit_nolog s x _ _).2]
    rfl

theorem arriveWish_nolog' (s t : StateOf α) (h : Nolog s t) (w : Wish) :
    (arriveWish t w).2 = (arriveWish s w).2 ∧ Nolog (arriveWish s w).1 (arriveWish t w).1 := by
  obtain ⟨x, rfl⟩ := h
  exact arriveWish_nolog s x w

/-- Two accumulators that differ only in the log. -/
def Rel (a b : StateOf α × String) : Prop := Nolog a.1 b.1 ∧ a.2 = b.2

theorem drainOne_rel (a b : StateOf α × String) (h : Rel a b) (w : Wish) : Rel (drainOne a w) (drainOne b w) := by
  obtain ⟨⟨x, hx⟩, h2⟩ := h
  obtain ⟨a1, a2⟩ := a
  obtain ⟨b1, b2⟩ := b
  simp only [] at hx h2
  subst hx
  subst h2
  have := arriveWish_nolog a1 x w
  refine ⟨this.2, ?_⟩
  unfold drainOne
  simp only [this.1]

theorem foldl_drainOne_rel (l : List Wish) (a b : StateOf α × String) (h : Rel a b) :
    Rel (l.foldl drainOne a) (l.foldl drainOne b) := by
  induction l generalizing a b with
  | nil => exact h
  | cons w l ih => exact ih _ _ (drainOne_rel a b h w)

theorem drain_nolog (s t : StateOf α) (h : Nolog s t) (b : Int) :
    (drain t b).2 = (drain s b).2 ∧ Nolog (drain s b).1 (drain t b).1 := by
  obtain ⟨x, rfl⟩ := h
  have := foldl_drainOne_rel (s.wishes.takeWhile fun w => decide (w.arrives < b))
    ({ s with wishes := s.wishes.dropWhile fun w => decide (w.arrives < b) }, "")
    ({ { s with log := x } with wishes := { s with log := x }.wishes.dropWhile fun w => decide (w.arrives < b) }, "")
    ⟨⟨x, rfl⟩, rfl⟩
  exact ⟨this.2.symm, this.1⟩

theorem tickAt_nolog [Engine.Lang.Numbers α] (s t : StateOf α) (h : Nolog s t) (time : Int) :
    (tickAt t time).2 = (tickAt s time).2 ∧ Nolog (tickAt s time).1 (tickAt t time).1 := by
  obtain ⟨x, rfl⟩ := h
  exact ⟨rfl, _, rfl⟩

theorem stepTick_nolog (s t : State) (h : Nolog s t) (time ms : Int) :
    (tickAt (drain t time).1 time).2.1 = (tickAt (drain s time).1 time).2.1 ∧
    (stepTick t time ms).2 = (stepTick s time ms).2 ∧ Nolog (stepTick s time ms).1 (stepTick t time ms).1 := by
  have hd := drain_nolog s t h time
  have ht := tickAt_nolog _ _ hd.2 time
  obtain ⟨y, hy⟩ := ht.2
  refine ⟨by rw [ht.1], ?_, y, ?_⟩
  · unfold stepTick
    simp only [ht.1]
  · unfold stepTick
    simp only [hy]

theorem fireRec_nolog (n : Nat) : ∀ (s t : State) (acc : Rows) (recs : List TickRecord),
    Nolog s t → (fireRec n t acc recs).2 = (fireRec n s acc recs).2 ∧
      Nolog (fireRec n s acc recs).1 (fireRec n t acc recs).1 := by
  induction n with
  | zero => intro s t acc recs h; exact ⟨rfl, h⟩
  | succ n ih =>
    intro s t acc recs h
    rw [fireRec_succ, fireRec_succ]
    have e1 : t.nextTick = s.nextTick := by obtain ⟨x, rfl⟩ := h; rfl
    have e2 : t.cfg.tickMs = s.cfg.tickMs := by obtain ⟨x, rfl⟩ := h; rfl
    rw [e1, e2]
    cases s.nextTick with
    | none => exact ⟨rfl, h⟩
    | some time =>
      cases s.cfg.tickMs with
      | none => exact ⟨rfl, h⟩
      | some ms =>
        obtain ⟨h1, h2, h3⟩ := stepTick_nolog s t h time ms
        have hd := drain_nolog s t h time
        simp only []
        rw [h1, h2, hd.1]
        exact ih _ _ _ _ h3

theorem settle_nolog (b : Int) (acc : Rows) (s t : State) (h : Nolog s t) :
    (settle t b acc).2 = (settle s b acc).2 ∧ Nolog (settle s b acc).1 (settle t b acc).1 := by
  have ht : ticksBefore t b = ticksBefore s b := by obtain ⟨x, rfl⟩ := h; rfl
  have hf := fireRec_nolog (ticksBefore s b) s t acc [] h
  have hd := drain_nolog _ _ hf.2 b
  unfold settle
  simp only [ht]
  refine ⟨?_, hd.2⟩
  simp only [hf.1, hd.1]

theorem withPending_log (s : StateOf α) (x : Option Log) (e : Event) (what : Unit → PView) :
    withPending { s with log := x } e what = { withPending s e what with log := x } := by
  unfold withPending
  split <;> rfl

theorem applyPayload_nolog (s t : State) (h : Nolog s t) (e : Event) (r : Reading) :
    (applyPayload t e r).2 = (applyPayload s e r).2 ∧ Nolog (applyPayload s e r).1 (applyPayload t e r).1 := by
  obtain ⟨x, rfl⟩ := h
  cases r with
  | listing rules =>
    have := emit_nolog { s with rules := setAt s.rules e.coin rules } x e.time
      (if s.rules[e.coin]? != some rules then (s.acct.orders.filter (·.coin == e.coin)).map
        fun o => Engine.World.Effect.cancelled o "rules" else [])
    exact ⟨this.1, x, this.2⟩
  | ending price =>
    refine ⟨rfl, x, ?_⟩
    unfold applyPayload withPending
    by_cases hp : s.prog.isSome = true <;> simp [hp, getCoin]
  | funding hour rate oracle =>
    refine ⟨rfl, x, ?_⟩
    unfold applyPayload withPending
    by_cases hp : s.prog.isSome = true <;> simp [hp, getCoin]
  | trade id price size sizeScale seller =>
    refine ⟨rfl, x, ?_⟩
    unfold applyPayload withPending
    by_cases hp : s.prog.isSome = true <;> simp [hp, getCoin]
  | quote bid bidSize ask askSize sizeScale =>
    refine ⟨rfl, x, ?_⟩
    unfold applyPayload withPending
    by_cases hp : s.prog.isSome = true <;> simp [hp, getCoin]
  | observation source bits =>
    refine ⟨rfl, x, ?_⟩
    unfold applyPayload withPending
    by_cases hp : s.prog.isSome = true <;> simp [hp]

theorem after_nolog (s t : State) (h : Nolog s t) (e : Event) (r : Reading) : Nolog (after s e r) (after t e r) := by
  have ha := applyPayload_nolog s t h e r
  obtain ⟨y, hy⟩ := ha.2
  obtain ⟨x, rfl⟩ := h
  have hn : newIds { s with log := x } e = newIds s e := rfl
  refine ⟨(after { s with log := x } e r).log, ?_⟩
  unfold after pushHistory withLog
  simp only [hy, ha.1, hn]

theorem settleR_nolog (s t : State) (h : Nolog s t) (b : Int) : Nolog (settleR s b).1 (settleR t b).1 := by
  have hs := settle_nolog b Rows.empty s t h
  rw [← (settle_eq s b Rows.empty).1, ← (settle_eq t b Rows.empty).1]
  exact hs.2

theorem advanceRec_nolog (s t : State) (h : Nolog s t) (e : Event) (r : Reading) :
    (advanceRec t e r).2.1 = (advanceRec s e r).2.1 ∧ Nolog (advanceRec s e r).1 (advanceRec t e r).1 := by
  have hs := settle_nolog e.time Rows.empty s t h
  have ha := applyPayload_nolog _ _ hs.2 e r
  refine ⟨?_, ?_⟩
  · unfold advanceRec
    simp only [hs.1, ha.1]
  · rw [advanceRec_state, advanceRec_state]
    exact after_nolog _ _ (settleR_nolog s t h e.time) e r

theorem step_of_rejected (s : State) (e : Event) (f : Fault) (h : s.rejected = some f) : step s e = (s, Rows.empty) := by
  simp [step, h]

theorem step_of_ok (s : State) (e : Event) (reading : Reading) (hr : s.rejected = none) (ha : admit s e = .ok reading) :
    step s e = advance s e reading := by
  simp [step, hr, ha]

theorem step_of_error (s : State) (e : Event) (fault : String × String) (hr : s.rejected = none)
    (ha : admit s e = .error fault) : step s e = (s.reject fault.1 e.time fault.2, Rows.empty) := by
  simp [step, hr, ha]

theorem step_nolog (s t : State) (h : Nolog s t) (e : Event) :
    (step t e).2 = (step s e).2 ∧ Nolog (step s e).1 (step t e).1 := by
  have hr : t.rejected = s.rejected := by obtain ⟨x, rfl⟩ := h; rfl
  have hA : admit t e = admit s e := by obtain ⟨x, rfl⟩ := h; rfl
  cases hs : s.rejected with
  | some f =>
    rw [step_of_rejected s e f hs, step_of_rejected t e f (by rw [hr, hs])]
    exact ⟨rfl, h⟩
  | none =>
    have ht : t.rejected = none := by rw [hr, hs]
    cases ha : admit s e with
    | error fault =>
      rw [step_of_error s e fault hs ha, step_of_error t e fault ht (by rw [hA, ha])]
      obtain ⟨x, rfl⟩ := h
      exact ⟨rfl, x, rfl⟩
    | ok reading =>
      rw [step_of_ok s e reading hs ha, step_of_ok t e reading ht (by rw [hA, ha])]
      have := advanceRec_nolog s t h e reading
      exact this

theorem goAcc_nolog : ∀ (es : List Event) (s t : State) (acc : Rows), Nolog s t →
    (goAcc t es acc).2 = (goAcc s es acc).2 ∧ Nolog (goAcc s es acc).1 (goAcc t es acc).1 := by
  intro es
  induction es with
  | nil => intro s t acc h; exact ⟨rfl, h⟩
  | cons e es ih =>
    intro s t acc h
    have hs := step_nolog s t h e
    simp only [goAcc]
    rw [hs.1]
    exact ih _ _ _ hs.2

theorem feed_nolog (s t : State) (h : Nolog s t) (c : Chunk) :
    (feed t c).2 = (feed s c).2 ∧ Nolog (feed s c).1 (feed t c).1 := by
  have hr : t.rejected = s.rejected := by obtain ⟨x, rfl⟩ := h; rfl
  have hd : decodeChunk t c = decodeChunk s c := by obtain ⟨x, rfl⟩ := h; rfl
  cases hs : s.rejected with
  | some f =>
    have e1 : feed s c = (s, Rows.empty) := by simp [feed, hs]
    have e2 : feed t c = (t, Rows.empty) := by simp [feed, hr, hs]
    rw [e1, e2]
    exact ⟨rfl, h⟩
  | none =>
    have ht : t.rejected = none := by rw [hr, hs]
    cases hdc : decodeChunk s c with
    | error code =>
      have e1 : feed s c = (s.reject code 0 "a chunk that does not decode", Rows.empty) := by simp [feed, hs, hdc]
      have e2 : feed t c = (t.reject code 0 "a chunk that does not decode", Rows.empty) := by
        simp [feed, ht, hd, hdc]
      rw [e1, e2]
      obtain ⟨x, rfl⟩ := h
      exact ⟨rfl, x, rfl⟩
    | ok events =>
      have e1 : feed s c = goAcc s events Rows.empty := by simp [feed, hs, hdc]
      have e2 : feed t c = goAcc t events Rows.empty := by simp [feed, ht, hd, hdc]
      rw [e1, e2]
      exact goAcc_nolog events s t Rows.empty h

theorem emit_nolog' (s : StateOf α) (x : Option Log) (time : Int) (es : List Engine.World.Effect) :
    emit { s with log := x } time es = ({ (emit s time es).1 with log := x }, (emit s time es).2) :=
  Prod.ext (emit_nolog s x time es).2 (emit_nolog s x time es).1

theorem applyOffer_nolog (s : State) (x : Option Log) (coin : Nat) (p : Taken) (role : Engine.Ledger.Role) :
    (applyOffer { s with log := x } coin p role).2 = (applyOffer s coin p role).2 ∧
      Nolog (applyOffer s coin p role).1 (applyOffer { s with log := x } coin p role).1 := by
  unfold applyOffer
  simp only [emit_nolog']
  rcases emit s p.time [Engine.World.Effect.fill p.order p.units p.price role] with ⟨s1, r1⟩
  simp only []
  rw [emit_nolog']
  rcases emit s1 p.time (_ ++ _) with ⟨s2, r2⟩
  simp only []
  unfold pushHistory withLog
  exact ⟨trivial, _, rfl⟩

theorem offer_nolog (s t : State) (h : Nolog s t) (coin slot : Nat) (parts : List (Nat × Rat))
    (role : Engine.Ledger.Role) :
    (offer t coin slot parts role).2 = (offer s coin slot parts role).2 ∧
      Nolog (offer s coin slot parts role).1 (offer t coin slot parts role).1 := by
  obtain ⟨x, rfl⟩ := h
  have hp : offerPlan { s with log := x } coin slot parts = offerPlan s coin slot parts := rfl
  unfold offer
  rw [hp]
  cases offerPlan s coin slot parts with
  | none => exact ⟨rfl, x, rfl⟩
  | some p => exact applyOffer_nolog s x coin p role

theorem finishFull_nolog (s t : State) (h : Nolog s t) :
    (finishFull t).2 = (finishFull s).2 ∧ Nolog (finishFull s).1 (finishFull t).1 := by
  have hr : t.rejected = s.rejected := by obtain ⟨x, rfl⟩ := h; rfl
  have hst : t.cfg.stop = s.cfg.stop := by obtain ⟨x, rfl⟩ := h; rfl
  cases hs : s.rejected with
  | some f =>
    have e1 : finishFull s = (s, Rows.empty, "{\"error\":" ++ errorText f) := by simp [finishFull, hs]
    have e2 : finishFull t = (t, Rows.empty, "{\"error\":" ++ errorText f) := by simp [finishFull, hr, hs]
    rw [e1, e2]
    exact ⟨rfl, h⟩
  | none =>
    have ht : t.rejected = none := by rw [hr, hs]
    have hset := settle_nolog s.cfg.stop Rows.empty s t h
    have e1 : finishFull s = ((settle s s.cfg.stop Rows.empty).1, (settle s s.cfg.stop Rows.empty).2.1,
        "{\"ok\":" ++ okText (settle s s.cfg.stop Rows.empty).1) := by simp [finishFull, hs]
    have e2 : finishFull t = ((settle t s.cfg.stop Rows.empty).1, (settle t s.cfg.stop Rows.empty).2.1,
        "{\"ok\":" ++ okText (settle t s.cfg.stop Rows.empty).1) := by simp [finishFull, ht, hst]
    rw [e1, e2]
    obtain ⟨y, hy⟩ := hset.2
    refine ⟨?_, hset.2⟩
    simp only [hy, hset.1]
    rfl

theorem runMoves_nolog (moves : List Move) : ∀ (s t : State) (rows : Rows), Nolog s t →
    (moves.foldl (fun (acc : State × Rows) move =>
        let next := match move with
          | .event e => feed acc.1 (pack [e])
          | .offer coin slot parts role => offer acc.1 coin slot parts role
        (next.1, acc.2 ++ next.2)) (t, rows)).2 =
      (moves.foldl (fun (acc : State × Rows) move =>
        let next := match move with
          | .event e => feed acc.1 (pack [e])
          | .offer coin slot parts role => offer acc.1 coin slot parts role
        (next.1, acc.2 ++ next.2)) (s, rows)).2 ∧
    Nolog (moves.foldl (fun (acc : State × Rows) move =>
        let next := match move with
          | .event e => feed acc.1 (pack [e])
          | .offer coin slot parts role => offer acc.1 coin slot parts role
        (next.1, acc.2 ++ next.2)) (s, rows)).1
      (moves.foldl (fun (acc : State × Rows) move =>
        let next := match move with
          | .event e => feed acc.1 (pack [e])
          | .offer coin slot parts role => offer acc.1 coin slot parts role
        (next.1, acc.2 ++ next.2)) (t, rows)).1 := by
  induction moves with
  | nil => intro s t rows h; exact ⟨rfl, h⟩
  | cons m moves ih =>
    intro s t rows h
    cases m with
    | event e =>
      have hf := feed_nolog s t h (pack [e])
      simp only [List.foldl_cons]
      rw [hf.1]
      exact ih _ _ _ hf.2
    | offer coin slot parts role =>
      have hf := offer_nolog s t h coin slot parts role
      simp only [List.foldl_cons]
      rw [hf.1]
      exact ih _ _ _ hf.2

theorem recast_nolog {program header : String} {initial : State} (h : start program header = .ok initial) :
    Nolog initial (initial.recast Engine.Lang.bitsOps) := by
  obtain ⟨cfg, p, _, _, rfl⟩ := start_shape h
  exact ⟨_, rfl⟩

/-- X1's rows: an instrumented run writes the rows of the ordinary machine over the same moves. -/
theorem orderRun_rows {program header : String} {initial : State} (h : start program header = .ok initial)
    (moves : List Move) (run : Engine.Orders.Run) (hr : orderRun Engine.Lang.bitsOps initial moves = some run) :
    let empty : Rows := {report := "", trace := ""}
    let fed := moves.foldl (fun (acc : State × Rows) move =>
      let next := match move with
        | .event e => feed acc.1 (pack [e])
        | .offer coin slot parts role => offer acc.1 coin slot parts role
      (next.1, {report := acc.2.report ++ next.2.report, trace := acc.2.trace ++ next.2.trace})) (initial, empty)
    let final := finish fed.1
    run.rows.report = fed.2.report ++ final.1.report ∧ run.rows.trace = fed.2.trace ++ final.1.trace := by
  intro empty fed final
  have hn := recast_nolog h
  have hm : (runMoves (initial.recast Engine.Lang.bitsOps) moves).2 = (runMoves initial moves).2 ∧
      Nolog (runMoves initial moves).1 (runMoves (initial.recast Engine.Lang.bitsOps) moves).1 :=
    runMoves_nolog moves initial (initial.recast Engine.Lang.bitsOps) Rows.empty hn
  have hf := finishFull_nolog _ _ hm.2
  have hfed : fed = runMoves initial moves := rfl
  unfold orderRun at hr
  dsimp only at hr
  rcases hrm : runMoves (initial.recast Engine.Lang.bitsOps) moves with ⟨fed1, rows1⟩
  rw [hrm] at hr hm
  dsimp only at hr
  rcases hff : finishFull fed1 with ⟨final1, rest1, summary1⟩
  rw [hff] at hr
  dsimp only at hr
  rw [hrm, hff] at hf
  cases hl : final1.log with
  | none => rw [hl] at hr; simp at hr
  | some l =>
    rw [hl] at hr
    dsimp only at hr
    split at hr
    · injection hr with hr
      subst hr
      have h1 : rows1 = fed.2 := by rw [hfed]; exact hm.1
      have h2 : rest1 = (finish fed.1).1 := by
        rw [hfed]
        exact congrArg Prod.fst hf.1
      show (rows1 ++ rest1).report = fed.2.report ++ final.1.report ∧ (rows1 ++ rest1).trace = fed.2.trace ++ final.1.trace
      rw [h1, h2]
      exact ⟨rfl, rfl⟩
    · simp at hr

end Engine.Machine
