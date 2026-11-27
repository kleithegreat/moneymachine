import Engine.MachineFaults

/-!
# The clock to a bound (kernel-v2.md A18; briefs/3-kernel-v2.md step 5, wall 9)

`settle s b` fires every tick before `b`, each after the wishes that arrive before it, and then the wishes that arrive
before `b`. Settling to a bound and then to a later one is settling to the later (`settleR_split`), the fifth lemma of
L1a's proof (`Engine.Delivery`).
-/

namespace Engine.Machine

open Engine.Orders (Wish)

/-! ### Counting ticks -/

def tickCount (time ms top : Int) : Nat := if time < top then ((top - time + ms - 1) / ms).toNat else 0

theorem tickCount_add (time ms top₁ top₂ : Int) (hms : 0 < ms) (h : top₁ ≤ top₂) :
    tickCount time ms top₂ = tickCount time ms top₁ + tickCount (time + (tickCount time ms top₁ : Int) * ms) ms top₂ := by
  unfold tickCount
  by_cases h1 : time < top₁
  · have h2 : time < top₂ := by omega
    simp only [h1, h2, ite_true]
    have hne : ms ≠ 0 := by omega
    have hq1 : 1 ≤ (top₁ - time + ms - 1) / ms := by
      apply (Int.le_ediv_iff_mul_le hms).2; omega
    have hdiv := Int.emod_add_mul_ediv (top₁ - time + ms - 1) ms
    have hlt := Int.emod_lt_of_pos (top₁ - time + ms - 1) hms
    have hge := Int.emod_nonneg (top₁ - time + ms - 1) hne
    generalize hq1d : (top₁ - time + ms - 1) / ms = q₁ at hq1 hdiv
    have hn1 : ((q₁.toNat : Nat) : Int) = q₁ := by omega
    rw [hn1]
    have hmul : q₁ * ms = ms * q₁ := Int.mul_comm _ _
    have hge1 : top₁ ≤ time + q₁ * ms := by omega
    by_cases h3 : time + q₁ * ms < top₂
    · simp only [h3, ite_true]
      have e : top₂ - (time + q₁ * ms) + ms - 1 = (top₂ - time + ms - 1) + (-q₁) * ms := by
        rw [Int.neg_mul]; omega
      rw [e, Int.add_mul_ediv_right _ _ hne]
      have : 1 ≤ (top₂ - time + ms - 1) / ms := by
        apply (Int.le_ediv_iff_mul_le hms).2; omega
      have h4 : 1 ≤ (top₂ - time + ms - 1) / ms + -q₁ := by
        have h5 : 1 ≤ (top₂ - (time + q₁ * ms) + ms - 1) / ms := by
          apply (Int.le_ediv_iff_mul_le hms).2; omega
        rw [e, Int.add_mul_ediv_right _ _ hne] at h5
        exact h5
      omega
    · simp only [h3, ite_false]
      have hz : (ms - 1) / ms = 0 := Int.ediv_eq_zero_of_lt (by omega) (by omega)
      have hle : (top₂ - time + ms - 1) / ms ≤ q₁ := by
        have : (top₂ - time + ms - 1) / ms ≤ (ms - 1 + q₁ * ms) / ms := by
          apply Int.ediv_le_ediv hms; omega
        rw [Int.add_mul_ediv_right _ _ hne, hz] at this
        omega
      have hge2 : q₁ ≤ (top₂ - time + ms - 1) / ms := by
        rw [← hq1d]; exact Int.ediv_le_ediv hms (by omega)
      omega
  · simp only [h1, ite_false, Nat.zero_add]
    simp


/-! ### Wishes' arrival leaves the queue alone -/

theorem emitOne_set (t : Int) (acc : State × String) (e : Engine.World.Effect) (x : List Wish) :
    emitOne t ({ acc.1 with wishes := x }, acc.2) e = ({ (emitOne t acc e).1 with wishes := x }, (emitOne t acc e).2) := by
  rfl

theorem emit_set (s : State) (t : Int) (es : List Engine.World.Effect) (x : List Wish) :
    emit { s with wishes := x } t es = ({ (emit s t es).1 with wishes := x }, (emit s t es).2) := by
  unfold emit
  have : ∀ (l : List Engine.World.Effect) (acc : State × String),
      l.foldl (emitOne t) ({ acc.1 with wishes := x }, acc.2) =
        ({ (l.foldl (emitOne t) acc).1 with wishes := x }, (l.foldl (emitOne t) acc).2) := by
    intro l
    induction l with
    | nil => intro acc; rfl
    | cons e l ih => intro acc; simp only [List.foldl_cons]; rw [emitOne_set, ← ih (emitOne t acc e)]
  exact this es (s, "")

theorem emit_wishes (s : State) (t : Int) (es : List Engine.World.Effect) : (emit s t es).1.wishes = s.wishes := by
  unfold emit
  have : ∀ (l : List Engine.World.Effect) (acc : State × String), (l.foldl (emitOne t) acc).1.wishes = acc.1.wishes := by
    intro l
    induction l with
    | nil => intro acc; rfl
    | cons e l ih => intro acc; simp only [List.foldl_cons]; rw [ih]; rfl
  exact this es (s, "")

theorem arriveWish_set (s : State) (w : Wish) (x : List Wish) :
    arriveWish { s with wishes := x } w = ({ (arriveWish s w).1 with wishes := x }, (arriveWish s w).2) := by
  unfold arriveWish
  simp only [emit_set]
  rfl

theorem withLog_wishes (s : State) (f : Log → Log) : (withLog s f).wishes = s.wishes := rfl

theorem pushHistory_wishes (s : State) (t : Int) : (pushHistory s t).wishes = s.wishes := rfl

theorem arriveWish_wishes (s : State) (w : Wish) : (arriveWish s w).1.wishes = s.wishes := by
  unfold arriveWish
  simp only [pushHistory_wishes, withLog_wishes, emit_wishes]

theorem drainOne_set (acc : State × String) (w : Wish) (x : List Wish) :
    drainOne ({ acc.1 with wishes := x }, acc.2) w = ({ (drainOne acc w).1 with wishes := x }, (drainOne acc w).2) := by
  unfold drainOne
  simp only [arriveWish_set]

theorem foldl_drainOne_set (l : List Wish) (acc : State × String) (x : List Wish) :
    l.foldl drainOne ({ acc.1 with wishes := x }, acc.2) =
      ({ (l.foldl drainOne acc).1 with wishes := x }, (l.foldl drainOne acc).2) := by
  induction l generalizing acc with
  | nil => rfl
  | cons w l ih => simp only [List.foldl_cons]; rw [drainOne_set, ← ih (drainOne acc w)]

theorem foldl_drainOne_wishes (l : List Wish) (acc : State × String) : (l.foldl drainOne acc).1.wishes = acc.1.wishes := by
  induction l generalizing acc with
  | nil => rfl
  | cons w l ih => simp only [List.foldl_cons]; rw [ih]; exact arriveWish_wishes acc.1 w

theorem drain_wishes (s : State) (b : Int) :
    (drain s b).1.wishes = s.wishes.dropWhile (fun w => decide (w.arrives < b)) := by
  unfold drain
  rw [foldl_drainOne_wishes]

/-- What an arrival, an effect and the log leave alone: the view's side, the clock, the coins and the world's rules. -/
structure Frame (s t : State) : Prop where
  cfg : t.cfg = s.cfg
  count : t.count = s.count
  previous : t.previous = s.previous
  ids : t.ids = s.ids
  ended : t.ended = s.ended
  rules : t.rules = s.rules
  coins : t.coins = s.coins
  nextTick : t.nextTick = s.nextTick
  rejected : t.rejected = s.rejected
  prog : t.prog = s.prog
  pending : t.pending = s.pending
  view : t.view = s.view
  mach : t.mach = s.mach
  vacct : t.vacct = s.vacct
  vage : t.vage = s.vage
  wishes : t.wishes = s.wishes

theorem Frame.refl (s : State) : Frame s s := ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

theorem Frame.trans {s t u : State} (h : Frame s t) (h' : Frame t u) : Frame s u :=
  ⟨by rw [h'.cfg, h.cfg], by rw [h'.count, h.count], by rw [h'.previous, h.previous], by rw [h'.ids, h.ids],
   by rw [h'.ended, h.ended], by rw [h'.rules, h.rules], by rw [h'.coins, h.coins],
   by rw [h'.nextTick, h.nextTick], by rw [h'.rejected, h.rejected], by rw [h'.prog, h.prog],
   by rw [h'.pending, h.pending], by rw [h'.view, h.view], by rw [h'.mach, h.mach], by rw [h'.vacct, h.vacct],
   by rw [h'.vage, h.vage], by rw [h'.wishes, h.wishes]⟩

theorem emit_frame (s : State) (t : Int) (es : List Engine.World.Effect) : Frame s (emit s t es).1 := by
  unfold emit
  have : ∀ (l : List Engine.World.Effect) (acc : State × String), Frame acc.1 (l.foldl (emitOne t) acc).1 := by
    intro l
    induction l with
    | nil => intro acc; exact Frame.refl _
    | cons e l ih =>
      intro acc
      simp only [List.foldl_cons]
      have h1 : Frame acc.1 (emitOne t acc e).1 := ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
      exact Frame.trans h1 (ih (emitOne t acc e))
  exact this es (s, "")

theorem withLog_frame (s : State) (f : Log → Log) : Frame s (withLog s f) :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

theorem pushHistory_frame (s : State) (t : Int) : Frame s (pushHistory s t) := withLog_frame s _

theorem arriveWish_frame (s : State) (w : Wish) : Frame s (arriveWish s w).1 := by
  unfold arriveWish
  exact Frame.trans (emit_frame s _ _) (Frame.trans (withLog_frame _ _) (pushHistory_frame _ _))

theorem foldl_drainOne_frame (l : List Wish) (acc : State × String) : Frame acc.1 (l.foldl drainOne acc).1 := by
  induction l generalizing acc with
  | nil => exact Frame.refl _
  | cons w l ih =>
    simp only [List.foldl_cons]
    exact Frame.trans (arriveWish_frame acc.1 w) (ih (drainOne acc w))

theorem drain_frame_wishes (s : State) (b : Int) : Frame { s with wishes := s.wishes.dropWhile (fun w => decide (w.arrives < b)) } (drain s b).1 := by
  unfold drain
  exact foldl_drainOne_frame (s.wishes.takeWhile fun w => decide (w.arrives < b))
    ({ s with wishes := s.wishes.dropWhile fun w => decide (w.arrives < b) }, "")

theorem drain_nextTick (s : State) (b : Int) : (drain s b).1.nextTick = s.nextTick := (drain_frame_wishes s b).nextTick

theorem takeWhile_split {α : Type} (p₁ p₂ : α → Bool) (h : ∀ a, p₁ a = true → p₂ a = true) (l : List α) :
    l.takeWhile p₂ = l.takeWhile p₁ ++ (l.dropWhile p₁).takeWhile p₂ ∧
      l.dropWhile p₂ = (l.dropWhile p₁).dropWhile p₂ := by
  induction l with
  | nil => simp
  | cons a l ih =>
    cases h1 : p₁ a
    · simp [List.takeWhile_cons, List.dropWhile_cons, h1]
    · have h2 := h a h1
      simp only [List.takeWhile_cons, List.dropWhile_cons, h1, h2, ite_true, List.cons_append]
      exact ⟨by rw [ih.1], ih.2⟩

/-- The state after a list of arrivals. -/
def arrivals (s : State) (l : List Wish) : State := l.foldl (fun s w => (arriveWish s w).1) s

theorem foldl_drainOne_fst (l : List Wish) (acc : State × String) : (l.foldl drainOne acc).1 = arrivals acc.1 l := by
  induction l generalizing acc with
  | nil => rfl
  | cons w l ih => simp only [List.foldl_cons, arrivals]; rw [ih]; rfl

theorem arrivals_append (s : State) (l l' : List Wish) : arrivals s (l ++ l') = arrivals (arrivals s l) l' := by
  simp [arrivals, List.foldl_append]

theorem arrivals_set (s : State) (l : List Wish) (x : List Wish) :
    arrivals { s with wishes := x } l = { arrivals s l with wishes := x } := by
  induction l generalizing s with
  | nil => rfl
  | cons w l ih =>
    simp only [arrivals, List.foldl_cons] at ih ⊢
    rw [arriveWish_set]
    exact ih _

theorem arrivals_wishes (s : State) (l : List Wish) : (arrivals s l).wishes = s.wishes := by
  induction l generalizing s with
  | nil => rfl
  | cons w l ih => simp only [arrivals, List.foldl_cons] at ih ⊢; rw [ih, arriveWish_wishes]

theorem drain_fst (s : State) (b : Int) :
    (drain s b).1 = arrivals { s with wishes := s.wishes.dropWhile (fun w => decide (w.arrives < b)) }
      (s.wishes.takeWhile (fun w => decide (w.arrives < b))) := by
  unfold drain
  rw [foldl_drainOne_fst]

theorem drain_form (s : State) (b : Int) :
    (drain s b).1 = { arrivals s (s.wishes.takeWhile (fun w => decide (w.arrives < b))) with
      wishes := s.wishes.dropWhile (fun w => decide (w.arrives < b)) } := by
  rw [drain_fst, arrivals_set]

/-- Draining to a bound and then to a later one is draining to the later. -/
theorem drain_drain (s : State) (b₁ b₂ : Int) (h : b₁ ≤ b₂) : (drain (drain s b₁).1 b₂).1 = (drain s b₂).1 := by
  obtain ⟨hd, hl⟩ := takeWhile_split (fun w : Wish => decide (w.arrives < b₁)) (fun w : Wish => decide (w.arrives < b₂))
    (fun a ha => by simp only [decide_eq_true_eq] at ha ⊢; omega) s.wishes
  rw [drain_form s b₂, drain_form (drain s b₁).1 b₂]
  have hw : (drain s b₁).1.wishes = s.wishes.dropWhile (fun w => decide (w.arrives < b₁)) := by
    rw [drain_form]
  have hwx : ∀ (A : State) (L : List Wish), ({ A with wishes := L } : State).wishes = L := fun _ _ => rfl
  rw [hw, hd, hl, drain_form s b₁, arrivals_append, arrivals_set]


/-! ### Firing ticks -/

/-- One tick at `time`: the wishes that arrive before it, then the tick, then the next tick's time. -/
def stepTick (s : State) (time ms : Int) : State × TickRecord :=
  let r := tickAt (drain s time).1 time
  ({ r.1 with nextTick := some (time + ms) }, r.2.2)

/-- The state and records of firing `n` ticks. -/
def fireR (n : Nat) (s : State) : State × List TickRecord :=
  let r := fireRec n s Rows.empty []
  (r.1, r.2.2)

theorem fireRec_succ (n : Nat) (s : State) (acc : Rows) (recs : List TickRecord) :
    fireRec (n + 1) s acc recs =
      match s.nextTick, s.cfg.tickMs with
      | some time, some ms =>
        fireRec n (stepTick s time ms).1
          (acc ++ ⟨"", (drain s time).2 ++ (tickAt (drain s time).1 time).2.1⟩) (recs ++ [(stepTick s time ms).2])
      | _, _ => (s, acc, recs) := by
  rw [fireRec.eq_2]
  rcases hn : s.nextTick with _ | time
  · rfl
  · rcases ht : s.cfg.tickMs with _ | ms
    · rfl
    · rfl

theorem fireRec_gen (n : Nat) : ∀ (s : State) (acc : Rows) (recs : List TickRecord),
    (fireRec n s acc recs).1 = (fireR n s).1 ∧ (fireRec n s acc recs).2.2 = recs ++ (fireR n s).2 := by
  induction n with
  | zero => intro s acc recs; simp [fireRec, fireR]
  | succ n ih =>
    intro s acc recs
    simp only [fireR]
    rw [fireRec_succ, fireRec_succ]
    split
    · rename_i time ms _ _
      obtain ⟨h1, h2⟩ := ih (stepTick s time ms).1 (acc ++ ⟨"", (drain s time).2 ++ (tickAt (drain s time).1 time).2.1⟩)
        (recs ++ [(stepTick s time ms).2])
      obtain ⟨h3, h4⟩ := ih (stepTick s time ms).1
        (Rows.empty ++ ⟨"", (drain s time).2 ++ (tickAt (drain s time).1 time).2.1⟩) ([] ++ [(stepTick s time ms).2])
      simp only [fireR] at h1 h2 h3 h4
      refine ⟨by rw [h1, h3], ?_⟩
      rw [h2, h4]; simp
    · simp

theorem fireR_zero (s : State) : fireR 0 s = (s, []) := by simp [fireR, fireRec]

theorem fireR_succ_some (n : Nat) (s : State) (time ms : Int) (hn : s.nextTick = some time)
    (ht : s.cfg.tickMs = some ms) :
    fireR (n + 1) s = ((fireR n (stepTick s time ms).1).1, (stepTick s time ms).2 :: (fireR n (stepTick s time ms).1).2) := by
  have h := fireRec_gen n (stepTick s time ms).1
    (Rows.empty ++ ⟨"", (drain s time).2 ++ (tickAt (drain s time).1 time).2.1⟩) ([] ++ [(stepTick s time ms).2])
  unfold fireR
  rw [fireRec_succ]
  simp only [hn, ht]
  refine Prod.ext ?_ ?_
  · exact h.1
  · rw [h.2]; simp [fireR]

theorem fireR_succ_none (n : Nat) (s : State) (h : s.nextTick = none ∨ s.cfg.tickMs = none) :
    fireR (n + 1) s = (s, []) := by
  unfold fireR
  rw [fireRec_succ]
  rcases h with h | h <;> simp [h]

theorem fireR_stuck (n : Nat) (s : State) (h : s.nextTick = none ∨ s.cfg.tickMs = none) : fireR n s = (s, []) := by
  cases n with
  | zero => exact fireR_zero s
  | succ n => exact fireR_succ_none n s h


theorem stepTick_cfg (s : State) (time ms : Int) : (stepTick s time ms).1.cfg = s.cfg := by
  simp [stepTick, tickAt_cfg, drain_cfg]

theorem fireR_cfg (n : Nat) (s : State) : (fireR n s).1.cfg = s.cfg := by
  unfold fireR; exact fireRec_cfg n s Rows.empty []

theorem fireR_nextTick (n : Nat) : ∀ (s : State) (t ms : Int), s.nextTick = some t → s.cfg.tickMs = some ms →
    (fireR n s).1.nextTick = some (t + n * ms) := by
  induction n with
  | zero => intro s t ms h _; simp [fireR_zero, h]
  | succ n ih =>
    intro s t ms hn ht
    rw [fireR_succ_some n s t ms hn ht]
    have hc : (stepTick s t ms).1.cfg.tickMs = some ms := by rw [stepTick_cfg]; exact ht
    have := ih (stepTick s t ms).1 (t + ms) ms rfl hc
    simp only [this]
    congr 1
    rw [Int.add_assoc]; congr 1; push_cast; rw [Int.add_mul, Int.one_mul, Int.add_comm]

theorem fireR_add (n m : Nat) : ∀ (s : State),
    fireR (n + m) s = ((fireR m (fireR n s).1).1, (fireR n s).2 ++ (fireR m (fireR n s).1).2) := by
  induction n with
  | zero => intro s; simp [fireR_zero]
  | succ n ih =>
    intro s
    have e : n + 1 + m = (n + m) + 1 := by omega
    rw [e]
    cases hn : s.nextTick with
    | none =>
      rw [fireR_stuck (n + m + 1) s (Or.inl hn), fireR_stuck (n + 1) s (Or.inl hn)]
      rw [fireR_stuck m s (Or.inl hn)]; simp
    | some t =>
      cases ht : s.cfg.tickMs with
      | none =>
        rw [fireR_stuck (n + m + 1) s (Or.inr ht), fireR_stuck (n + 1) s (Or.inr ht)]
        rw [fireR_stuck m s (Or.inr ht)]; simp
      | some ms =>
        rw [fireR_succ_some (n + m) s t ms hn ht, fireR_succ_some n s t ms hn ht, ih]
        simp

theorem ticksBefore_eq (s : State) (bound : Int) :
    ticksBefore s bound = match s.nextTick, s.cfg.tickMs with
      | some time, some ms => tickCount time ms (min bound s.cfg.stop)
      | _, _ => 0 := by
  unfold ticksBefore tickCount
  rfl

theorem ticksBefore_split (s : State) (b₁ b₂ : Int) (h : b₁ ≤ b₂)
    (hms : ∀ ms, s.cfg.tickMs = some ms → 0 ≤ ms) :
    ticksBefore s b₂ = ticksBefore s b₁ + ticksBefore (fireR (ticksBefore s b₁) s).1 b₂ := by
  cases hn : s.nextTick with
  | none =>
    rw [fireR_stuck _ s (Or.inl hn)]
    simp [ticksBefore_eq, hn]
  | some t =>
    cases ht : s.cfg.tickMs with
    | none =>
      rw [fireR_stuck _ s (Or.inr ht)]
      simp [ticksBefore_eq, ht]
    | some ms =>
      have hnt := fireR_nextTick (ticksBefore s b₁) s t ms hn ht
      have hcfg := fireR_cfg (ticksBefore s b₁) s
      rw [ticksBefore_eq (fireR (ticksBefore s b₁) s).1 b₂, hnt, hcfg, ht]
      rw [ticksBefore_eq s b₁, ticksBefore_eq s b₂]
      simp only [hn, ht]
      rcases Nat.eq_zero_or_pos ms.toNat with h0 | hpos
      · have : ms = 0 := by have := hms ms ht; omega
        subst this
        simp [tickCount]
      · have hms0 : 0 < ms := by omega
        exact tickCount_add t ms _ _ hms0 (by omega)


theorem drain_cfg' (s : State) (b : Int) : (drain s b).1.cfg = s.cfg := drain_cfg s b

/-- A tick the settled clock has not fired is at or after the bound (when the step is positive). -/
theorem fireR_nextTick_ge (s : State) (b : Int) (t ms : Int) (hn : s.nextTick = some t) (ht : s.cfg.tickMs = some ms)
    (hms : 0 < ms) : ∃ t', (fireR (ticksBefore s b) s).1.nextTick = some t' ∧ min b s.cfg.stop ≤ t' := by
  refine ⟨t + (ticksBefore s b : Int) * ms, fireR_nextTick _ s t ms hn ht, ?_⟩
  rw [ticksBefore_eq]
  simp only [hn, ht]
  unfold tickCount
  by_cases hlt : t < min b s.cfg.stop
  · simp only [hlt, ite_true]
    have hne : ms ≠ 0 := by omega
    have hdiv := Int.emod_add_mul_ediv (min b s.cfg.stop - t + ms - 1) ms
    have hlt' := Int.emod_lt_of_pos (min b s.cfg.stop - t + ms - 1) hms
    have hge := Int.emod_nonneg (min b s.cfg.stop - t + ms - 1) hne
    have hq1 : 1 ≤ (min b s.cfg.stop - t + ms - 1) / ms := by
      apply (Int.le_ediv_iff_mul_le hms).2; omega
    generalize (min b s.cfg.stop - t + ms - 1) / ms = q at hq1 hdiv
    have hn1 : ((q.toNat : Nat) : Int) = q := by omega
    rw [hn1]
    have : ms * q = q * ms := Int.mul_comm _ _
    omega
  · simp only [hlt, ite_false]
    omega

/-- The clock to `bound`: the ticks before it, each after the wishes that arrive before it, then the wishes that arrive
before the bound. -/
def settleR (s : State) (b : Int) : State × List TickRecord :=
  let r := fireR (ticksBefore s b) s
  ((drain r.1 b).1, r.2)

theorem settle_eq (s : State) (b : Int) (acc : Rows) :
    (settle s b acc).1 = (settleR s b).1 ∧ (settle s b acc).2.2 = (settleR s b).2 := by
  obtain ⟨h1, h2⟩ := fireRec_gen (ticksBefore s b) s acc []
  unfold settle settleR
  simp only [h1, h2, List.nil_append]
  exact ⟨trivial, trivial⟩

theorem settleR_cfg (s : State) (b : Int) : (settleR s b).1.cfg = s.cfg := by
  unfold settleR
  simp only [drain_cfg, fireR_cfg]

/-- Draining first changes nothing the clock fires afterwards, as the ticks are at or after the bound. -/
theorem fire_drain_absorb (m : Nat) (s : State) (b₁ b₂ : Int) (h : b₁ ≤ b₂)
    (hb : 0 < m → ∀ t, s.nextTick = some t → b₁ ≤ t) :
    (drain (fireR m (drain s b₁).1).1 b₂).1 = (drain (fireR m s).1 b₂).1 ∧
      (fireR m (drain s b₁).1).2 = (fireR m s).2 := by
  cases m with
  | zero => simp only [fireR_zero]; exact ⟨drain_drain s b₁ b₂ h, trivial⟩
  | succ k =>
    have hnt : (drain s b₁).1.nextTick = s.nextTick := drain_nextTick s b₁
    have hcf : (drain s b₁).1.cfg = s.cfg := drain_cfg s b₁
    cases hn : s.nextTick with
    | none =>
      rw [fireR_stuck _ s (Or.inl hn), fireR_stuck _ (drain s b₁).1 (Or.inl (by rw [hnt, hn]))]
      exact ⟨drain_drain s b₁ b₂ h, rfl⟩
    | some t =>
      cases ht : s.cfg.tickMs with
      | none =>
        rw [fireR_stuck _ s (Or.inr ht), fireR_stuck _ (drain s b₁).1 (Or.inr (by rw [hcf, ht]))]
        exact ⟨drain_drain s b₁ b₂ h, rfl⟩
      | some ms =>
        have hbt : b₁ ≤ t := hb (Nat.succ_pos k) t hn
        have hstep : stepTick (drain s b₁).1 t ms = stepTick s t ms := by
          unfold stepTick
          rw [drain_drain s b₁ t hbt]
        rw [fireR_succ_some k _ t ms (by rw [hnt, hn]) (by rw [hcf, ht]), fireR_succ_some k s t ms hn ht, hstep]
        exact ⟨rfl, rfl⟩

/-- The clock to a bound and then to a later one is the clock to the later one (A18; L1a's fifth lemma). -/
theorem settleR_split (s : State) (b₁ b₂ : Int) (h : b₁ ≤ b₂) (hms : ∀ ms, s.cfg.tickMs = some ms → 0 < ms) :
    settleR s b₂ = ((settleR (settleR s b₁).1 b₂).1, (settleR s b₁).2 ++ (settleR (settleR s b₁).1 b₂).2) := by
  have hms' : ∀ ms, s.cfg.tickMs = some ms → 0 ≤ ms := fun ms hm => Int.le_of_lt (hms ms hm)
  have hcfg₁ : (fireR (ticksBefore s b₁) s).1.cfg = s.cfg := fireR_cfg _ s
  have hsplit := ticksBefore_split s b₁ b₂ h hms'
  have hcount : ticksBefore (drain (fireR (ticksBefore s b₁) s).1 b₁).1 b₂ =
      ticksBefore (fireR (ticksBefore s b₁) s).1 b₂ := by
    unfold ticksBefore
    rw [drain_nextTick, drain_cfg]
  have hb : 0 < ticksBefore (fireR (ticksBefore s b₁) s).1 b₂ →
      ∀ t, (fireR (ticksBefore s b₁) s).1.nextTick = some t → b₁ ≤ t := by
    intro hm0 t ht
    obtain ⟨ms, hms1⟩ : ∃ ms, s.cfg.tickMs = some ms := by
      cases hc : s.cfg.tickMs with
      | none => simp [ticksBefore, hc, fireR_zero] at hm0
      | some ms => exact ⟨ms, rfl⟩
    have hpos := hms ms hms1
    obtain ⟨t0, ht0⟩ : ∃ t0, s.nextTick = some t0 := by
      cases hc : s.nextTick with
      | none =>
        rw [fireR_stuck _ s (Or.inl hc)] at hm0 ht
        simp [ticksBefore, hc] at hm0
      | some t0 => exact ⟨t0, rfl⟩
    obtain ⟨t', ht', hge⟩ := fireR_nextTick_ge s b₁ t0 ms ht0 hms1 hpos
    have htt : t' = t := by rw [ht'] at ht; exact Option.some.inj ht
    subst htt
    have hlt : t' < min b₂ s.cfg.stop := by
      rw [ticksBefore_eq] at hm0
      simp only [ht, hcfg₁, hms1] at hm0
      unfold tickCount at hm0
      by_cases hlt : t' < min b₂ s.cfg.stop
      · exact hlt
      · simp [hlt] at hm0
    have hmin : min b₂ s.cfg.stop ≤ s.cfg.stop := Int.min_le_right _ _
    have hb1 : b₁ < s.cfg.stop := by
      rcases Int.lt_or_le b₁ s.cfg.stop with hc | hc
      · exact hc
      · exfalso
        have : min b₁ s.cfg.stop = s.cfg.stop := by omega
        omega
    omega
  obtain ⟨e1, e2⟩ := fire_drain_absorb (ticksBefore (fireR (ticksBefore s b₁) s).1 b₂) (fireR (ticksBefore s b₁) s).1 b₁ b₂ h hb
  unfold settleR
  simp only [hcount]
  rw [hsplit, fireR_add, e1, e2]

end Engine.Machine
