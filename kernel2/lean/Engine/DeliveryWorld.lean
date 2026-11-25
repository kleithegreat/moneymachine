import Engine.Clock

/-!
# The world's side of L1a (kernel-v2.md B3; briefs/3-kernel-v2.md step 7, L1a's proof)

What two markets share of the world until the first event of the tail: its account, its rules, the coins that ended and
each coin's quotes and prints (`WorldEq`), from which one wish arrives as the same effects in both.
-/

namespace Engine.Machine

open Engine.Orders (Wish)

/-- What an arrival reads of a coin. -/
def worldCoin (c : CoinState) : Option Rat × Option Rat × Option Rat := (c.bid, c.ask, c.price)

/-- The world's side that a wish's arrival reads. -/
def WorldEq (s u : State) : Prop :=
  s.acct = u.acct ∧ s.rules = u.rules ∧ s.ended = u.ended ∧ s.coins.map worldCoin = u.coins.map worldCoin

theorem WorldEq.acct {s u : State} (h : WorldEq s u) : s.acct = u.acct := h.1
theorem WorldEq.rules {s u : State} (h : WorldEq s u) : s.rules = u.rules := h.2.1
theorem WorldEq.ended {s u : State} (h : WorldEq s u) : s.ended = u.ended := h.2.2.1
theorem WorldEq.coins {s u : State} (h : WorldEq s u) : s.coins.map worldCoin = u.coins.map worldCoin := h.2.2.2

theorem getD_map_eq {α β : Type} (f : α → β) (d : α) (l l' : List α) (h : l.map f = l'.map f) (i : Nat) :
    f (l.getD i d) = f (l'.getD i d) := by
  have := congrArg (fun m => m.getD i (f d)) h
  simp only [List.getD_eq_getElem?_getD, List.getElem?_map] at this ⊢
  cases hl : l[i]? <;> cases hl' : l'[i]? <;> simp_all

theorem getCoin_worldCoin (s u : State) (h : s.coins.map worldCoin = u.coins.map worldCoin) (c : Nat) :
    worldCoin (getCoin s c) = worldCoin (getCoin u c) :=
  getD_map_eq worldCoin CoinState.fresh s.coins u.coins h c

theorem worldBook_congr (s u : State) (hw : WorldEq s u) (hc : s.cfg = u.cfg) (hp : s.prog = u.prog) (t : Int) :
    worldBook s t = worldBook u t := by
  unfold worldBook
  simp only [hc, hp, hw.rules, hw.ended, hw.acct]
  congr 1
  apply List.map_congr_left
  intro c _
  have := getCoin_worldCoin s u hw.coins c
  simp only [worldCoin, Prod.mk.injEq] at this
  obtain ⟨h1, h2, h3⟩ := this
  simp only [h1, h2, h3]


/-! ### Effects -/

/-- The log entry an effect made at `time` leaves for the view. -/
def logged (cfg : Config) (time : Int) (e : Engine.World.Effect) : Logged := ⟨time + cfg.delta, time, e⟩

theorem emit_acct (s : State) (t : Int) (es : List Engine.World.Effect) :
    (emit s t es).1.acct = es.foldl (fun a e => a.apply s.cfg.fees t e) s.acct := by
  unfold emit
  have : ∀ (l : List Engine.World.Effect) (acc : State × String),
      (l.foldl (emitOne t) acc).1.acct = l.foldl (fun a e => a.apply acc.1.cfg.fees t e) acc.1.acct := by
    intro l
    induction l with
    | nil => intro acc; rfl
    | cons e l ih => intro acc; simp only [List.foldl_cons]; rw [ih]; rfl
  exact this es (s, "")

theorem emit_veffects (s : State) (t : Int) (es : List Engine.World.Effect) :
    (emit s t es).1.veffects = s.veffects ++ es.map (logged s.cfg t) := by
  unfold emit
  have : ∀ (l : List Engine.World.Effect) (acc : State × String),
      (l.foldl (emitOne t) acc).1.veffects = acc.1.veffects ++ l.map (logged acc.1.cfg t) := by
    intro l
    induction l with
    | nil => intro acc; simp
    | cons e l ih => intro acc; simp only [List.foldl_cons, List.map_cons]; rw [ih]; simp [emitOne, logged]
  exact this es (s, "")

theorem arriveWish_acct (s : State) (w : Wish) :
    (arriveWish s w).1.acct = (arrivalEffects (worldBook s w.arrives) w).foldl
      (fun a e => a.apply s.cfg.fees w.arrives e) s.acct := by
  unfold arriveWish
  exact emit_acct s _ _

theorem arriveWish_veffects (s : State) (w : Wish) :
    (arriveWish s w).1.veffects = s.veffects ++ (arrivalEffects (worldBook s w.arrives) w).map (logged s.cfg w.arrives) := by
  unfold arriveWish
  exact emit_veffects s _ _

theorem arriveWish_worldEq (s u : State) (hw : WorldEq s u) (hc : s.cfg = u.cfg) (hp : s.prog = u.prog) (w : Wish) :
    WorldEq (arriveWish s w).1 (arriveWish u w).1 ∧
      ∃ L, (arriveWish s w).1.veffects = s.veffects ++ L ∧ (arriveWish u w).1.veffects = u.veffects ++ L := by
  have hb := worldBook_congr s u hw hc hp w.arrives
  have fs := arriveWish_frame s w
  have fu := arriveWish_frame u w
  refine ⟨⟨?_, ?_, ?_, ?_⟩, _, arriveWish_veffects s w, ?_⟩
  · rw [arriveWish_acct, arriveWish_acct, ← hb, ← hc, hw.acct]
  · rw [fs.rules, fu.rules, hw.rules]
  · rw [fs.ended, fu.ended, hw.ended]
  · rw [fs.coins, fu.coins, hw.coins]
  · rw [arriveWish_veffects u w, ← hb, ← hc]

theorem foldl_drainOne_worldEq (l : List Wish) : ∀ (accs accu : State × String), WorldEq accs.1 accu.1 →
    accs.1.cfg = accu.1.cfg → accs.1.prog = accu.1.prog →
    WorldEq (l.foldl drainOne accs).1 (l.foldl drainOne accu).1 ∧
      ∃ L, (l.foldl drainOne accs).1.veffects = accs.1.veffects ++ L ∧
        (l.foldl drainOne accu).1.veffects = accu.1.veffects ++ L := by
  induction l with
  | nil => intro accs accu hw _ _; exact ⟨hw, [], by simp, by simp⟩
  | cons w l ih =>
    intro accs accu hw hc hp
    simp only [List.foldl_cons]
    obtain ⟨hw1, L1, e1, e2⟩ := arriveWish_worldEq accs.1 accu.1 hw hc hp w
    have fs := arriveWish_frame accs.1 w
    have fu := arriveWish_frame accu.1 w
    obtain ⟨hw2, L2, e3, e4⟩ := ih (drainOne accs w) (drainOne accu w) hw1 (by simp only [drainOne]; rw [fs.cfg, fu.cfg, hc])
      (by simp only [drainOne]; rw [fs.prog, fu.prog, hp])
    refine ⟨hw2, L1 ++ L2, ?_, ?_⟩
    · rw [e3]; simp only [drainOne]; rw [e1]; simp
    · rw [e4]; simp only [drainOne]; rw [e2]; simp

/-- Draining equal wishes from equal worlds leaves equal worlds and the same effects for the view. -/
theorem drain_worldEq (s u : State) (hw : WorldEq s u) (hc : s.cfg = u.cfg) (hp : s.prog = u.prog)
    (hq : s.wishes = u.wishes) (b : Int) :
    WorldEq (drain s b).1 (drain u b).1 ∧
      ∃ L, (drain s b).1.veffects = s.veffects ++ L ∧ (drain u b).1.veffects = u.veffects ++ L := by
  unfold drain
  have := foldl_drainOne_worldEq (s.wishes.takeWhile fun w => decide (w.arrives < b))
    ({ s with wishes := s.wishes.dropWhile fun w => decide (w.arrives < b) }, "")
    ({ u with wishes := u.wishes.dropWhile fun w => decide (w.arrives < b) }, "")
    ⟨hw.acct, hw.rules, hw.ended, hw.coins⟩ hc hp
  rw [hq] at this ⊢
  exact this

/-- In a state that has no wish before `bound`, arrivals add only effects the view takes after `bound + delta`. -/
theorem foldl_drainOne_known (P : Int → Prop) (l : List Wish) : ∀ (acc : State × String), (∀ w ∈ l, P w.arrives) →
    ∃ L, (l.foldl drainOne acc).1.veffects = acc.1.veffects ++ L ∧ ∀ x ∈ L, ∃ a, P a ∧ x.known = a + acc.1.cfg.delta := by
  induction l with
  | nil => intro acc _; exact ⟨[], by simp, by simp⟩
  | cons w l ih =>
    intro acc hP
    simp only [List.foldl_cons]
    have hw : P w.arrives := hP w (List.mem_cons_self ..)
    obtain ⟨L2, e2, k2⟩ := ih (drainOne acc w) (fun x hx => hP x (List.mem_cons_of_mem _ hx))
    refine ⟨(arrivalEffects (worldBook acc.1 w.arrives) w).map (logged acc.1.cfg w.arrives) ++ L2, ?_, ?_⟩
    · rw [e2]; simp only [drainOne]; rw [arriveWish_veffects]; simp
    · intro x hx
      rcases List.mem_append.1 hx with hx | hx
      · obtain ⟨e, _, rfl⟩ := List.mem_map.1 hx
        exact ⟨w.arrives, hw, rfl⟩
      · obtain ⟨a, ha, hk⟩ := k2 x hx
        have hf := arriveWish_frame acc.1 w
        refine ⟨a, ha, ?_⟩
        rw [hk]
        simp only [drainOne]
        rw [hf.cfg]

theorem drain_known (P : Int → Prop) (s : State) (b : Int) (hP : ∀ w ∈ s.wishes, P w.arrives) :
    ∃ L, (drain s b).1.veffects = s.veffects ++ L ∧ ∀ x ∈ L, ∃ a, P a ∧ x.known = a + s.cfg.delta := by
  unfold drain
  exact foldl_drainOne_known P _ ({ s with wishes := s.wishes.dropWhile fun w => decide (w.arrives < b) }, "")
    (fun w hw => hP w ((List.takeWhile_sublist _).subset hw))

end Engine.Machine
