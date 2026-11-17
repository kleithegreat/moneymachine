import Engine.MachineFaults
import Engine.Start

/-!
# L1a: delivery (kernel-v2.md B3; briefs/3-kernel-v2.md step 4)

Two markets that agree on the events known by `τ` and on the events with `time ≤ τ - δ` give equal ticks through `τ`.
The proof follows the brief's five lemmas, each about the fold without admission (`advanceRec`), which an admitted
run equals (`snapshots_adm`):

1. An admitted stream's times never fall (`adm_props`), so the events with `time ≤ τ - δ` are a prefix both markets
   share (`adm_det`) and the rest a tail.
2. In the tail an event known by `τ` is no quote and no print (`adm_props`), so its reading is a function of the event
   alone (`plainReading`).
3. `Agree` is the part of a state ticks through `τ` can read.
4. Ticks (`tickAt_agree`) and one event applied to both (`after_agree`) keep two states in `Agree`; an event not known
   by `τ` keeps a state in `Agree` with itself (`after_self`).
5. Firing ticks up to a bound and then to a later one is firing to the later (`fireR_split`), so an event not known by
   `τ` changes no record through `τ` (`recs_filterK`) and the tail's run equals that of its events known by `τ`.
-/

namespace Engine.Machine

/-! ### Ticks -/

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

/-- The state and records of firing `n` ticks. -/
def fireR (n : Nat) (s : State) : State × List TickRecord :=
  let r := fireRec n s Rows.empty []
  (r.1, r.2.2)

theorem fireRec_gen (n : Nat) : ∀ (s : State) (acc : Rows) (recs : List TickRecord),
    (fireRec n s acc recs).1 = (fireR n s).1 ∧ (fireRec n s acc recs).2.2 = recs ++ (fireR n s).2 := by
  induction n with
  | zero => intro s acc recs; simp [fireRec, fireR]
  | succ n ih =>
    intro s acc recs
    simp only [fireR]
    unfold fireRec
    split
    · rename_i time ms _ _
      obtain ⟨h1, h2⟩ := ih { (tickAt s time).1 with nextTick := some (time + ms) } (acc ++ ⟨"", (tickAt s time).2.1⟩) (recs ++ [(tickAt s time).2.2])
      obtain ⟨h3, h4⟩ := ih { (tickAt s time).1 with nextTick := some (time + ms) } (Rows.empty ++ ⟨"", (tickAt s time).2.1⟩) ([] ++ [(tickAt s time).2.2])
      simp only [fireR] at h1 h2 h3 h4
      refine ⟨by rw [h1, h3], ?_⟩
      rw [h2, h4]; simp
    · simp

theorem fireR_zero (s : State) : fireR 0 s = (s, []) := by simp [fireR, fireRec]

theorem fireR_succ_some (n : Nat) (s : State) (time ms : Int) (hn : s.nextTick = some time)
    (ht : s.cfg.tickMs = some ms) :
    fireR (n + 1) s =
      ((fireR n { (tickAt s time).1 with nextTick := some (time + ms) }).1,
        (tickAt s time).2.2 :: (fireR n { (tickAt s time).1 with nextTick := some (time + ms) }).2) := by
  have h := fireRec_gen n { (tickAt s time).1 with nextTick := some (time + ms) }
    (Rows.empty ++ ⟨"", (tickAt s time).2.1⟩) ([] ++ [(tickAt s time).2.2])
  unfold fireR
  rw [fireRec]
  simp only [hn, ht]
  refine Prod.ext ?_ ?_
  · exact h.1
  · exact h.2

theorem fireR_succ_none (n : Nat) (s : State) (h : s.nextTick = none ∨ s.cfg.tickMs = none) :
    fireR (n + 1) s = (s, []) := by
  unfold fireR
  rw [fireRec]
  rcases h with h | h <;> simp [h]


theorem fireR_stuck (n : Nat) (s : State) (h : s.nextTick = none ∨ s.cfg.tickMs = none) : fireR n s = (s, []) := by
  cases n with
  | zero => exact fireR_zero s
  | succ n => exact fireR_succ_none n s h

theorem fireR_cfg (n : Nat) (s : State) : (fireR n s).1.cfg = s.cfg := by
  unfold fireR; exact fireRec_cfg n s Rows.empty []

theorem fireR_nextTick (n : Nat) : ∀ (s : State) (t ms : Int), s.nextTick = some t → s.cfg.tickMs = some ms →
    (fireR n s).1.nextTick = some (t + n * ms) := by
  induction n with
  | zero => intro s t ms h _; simp [fireR_zero, h]
  | succ n ih =>
    intro s t ms hn ht
    rw [fireR_succ_some n s t ms hn ht]
    have hc : ({ (tickAt s t).1 with nextTick := some (t + ms) } : State).cfg.tickMs = some ms := by
      show (tickAt s t).1.cfg.tickMs = some ms
      rw [tickAt_cfg]; exact ht
    have := ih { (tickAt s t).1 with nextTick := some (t + ms) } (t + ms) ms rfl hc
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

theorem fireR_split (s : State) (b₁ b₂ : Int) (h : b₁ ≤ b₂) (hms : ∀ ms, s.cfg.tickMs = some ms → 0 ≤ ms) :
    fireR (ticksBefore s b₂) s =
      ((fireR (ticksBefore (fireR (ticksBefore s b₁) s).1 b₂) (fireR (ticksBefore s b₁) s).1).1,
       (fireR (ticksBefore s b₁) s).2 ++
         (fireR (ticksBefore (fireR (ticksBefore s b₁) s).1 b₂) (fireR (ticksBefore s b₁) s).1).2) := by
  rw [ticksBefore_split s b₁ b₂ h hms]
  exact fireR_add _ _ s


/-! ### Events -/

def after (s : State) (e : Event) (r : Reading) : State :=
  let (s2, row) := applyPayload s e r
  let lines := if row.isEmpty then 0 else 1
  { s2 with count := s2.count + 1, previous := some e, ids := newIds s e, traceLines := s2.traceLines + lines }

theorem advanceRec_state (s : State) (e : Event) (r : Reading) :
    (advanceRec s e r).1 = after (fireR (ticksBefore s e.time) s).1 e r := by
  unfold advanceRec after fireR
  rfl

theorem advanceRec_recs (s : State) (e : Event) (r : Reading) :
    (advanceRec s e r).2.2 = (fireR (ticksBefore s e.time) s).2 := by
  unfold advanceRec fireR
  rfl



/-! ### The records of a run without admission -/

abbrev Pair := Event × Reading

/-- The state and the records of the events' steps, before the clock runs out. -/
def runP (s : State) : List Pair → State × List TickRecord
  | [] => (s, [])
  | p :: rest =>
    let x := advanceRec s p.1 p.2
    let y := runP x.1 rest
    (y.1, x.2.2 ++ y.2)

/-- Every tick record of a run: the events' steps, then the clock to the horizon's end. -/
def recsPairs (s : State) (ps : List Pair) : List TickRecord :=
  let y := runP s ps
  y.2 ++ (fireR (ticksBefore y.1 y.1.cfg.stop) y.1).2

theorem recsPairs_nil (s : State) : recsPairs s [] = (fireR (ticksBefore s s.cfg.stop) s).2 := by
  simp [recsPairs, runP]

theorem recsPairs_cons (s : State) (p : Pair) (rest : List Pair) :
    recsPairs s (p :: rest) = (fireR (ticksBefore s p.1.time) s).2 ++ recsPairs (after (fireR (ticksBefore s p.1.time) s).1 p.1 p.2) rest := by
  simp only [recsPairs, runP, advanceRec_state, advanceRec_recs, List.append_assoc]

theorem runP_append (s : State) (P Q : List Pair) :
    runP s (P ++ Q) = ((runP (runP s P).1 Q).1, (runP s P).2 ++ (runP (runP s P).1 Q).2) := by
  induction P generalizing s with
  | nil => simp [runP]
  | cons p P ih => simp [runP, ih, List.append_assoc]

theorem recsPairs_append (s : State) (P Q : List Pair) :
    recsPairs s (P ++ Q) = (runP s P).2 ++ recsPairs (runP s P).1 Q := by
  simp [recsPairs, runP_append, List.append_assoc]

theorem after_cfg (s : State) (e : Event) (r : Reading) : (after s e r).cfg = s.cfg := by
  have := applyPayload_cfg s e r
  unfold after
  simpa using this

/-- Firing to an earlier bound first changes no record: the later firing takes up where it left off. -/
theorem recsPairs_fire (s : State) (hms : ∀ ms, s.cfg.tickMs = some ms → 0 ≤ ms) (b : Int) :
    ∀ (ps : List Pair), (match ps with | [] => b ≤ s.cfg.stop | p :: _ => b ≤ p.1.time) →
      recsPairs s ps = (fireR (ticksBefore s b) s).2 ++ recsPairs (fireR (ticksBefore s b) s).1 ps := by
  intro ps hb
  cases ps with
  | nil =>
    rw [recsPairs_nil, recsPairs_nil, fireR_split s b s.cfg.stop hb hms]
    simp [fireR_cfg]
  | cons p rest =>
    rw [recsPairs_cons, recsPairs_cons, fireR_split s b p.1.time hb hms]
    simp []


/-! ### What two markets share at `τ` -/

def PendSorted (s : State) : Prop := s.pending.Pairwise (fun p q => p.known ≤ q.known)

def knownBy (τ : Int) (p : Pending) : Bool := decide (p.known ≤ τ)

def quotesBy (m : Int) (c : CoinState) : List Int := c.quotes.filter (fun q => decide (q ≤ m))

/-- The part of a state the clock reads, as far as ticks through `τ` can see it (A3, A18; L1a). -/
structure Agree (τ : Int) (s u : State) : Prop where
  cfg : s.cfg = u.cfg
  prog : s.prog = u.prog
  next : s.nextTick = u.nextTick
  view : s.view = u.view
  mach : s.mach = u.mach
  sortedL : PendSorted s
  sortedR : PendSorted u
  pending : s.pending.filter (knownBy τ) = u.pending.filter (knownBy τ)
  quotes : s.coins.map (quotesBy (τ - s.cfg.delta)) = u.coins.map (quotesBy (τ - s.cfg.delta))

def Dead (τ : Int) (s : State) : Prop := ∀ t, s.nextTick = some t → τ < t

def Good (τ : Int) (s u : State) : Prop := Agree τ s u ∨ (Dead τ s ∧ Dead τ u)

theorem find_filter (m seen : Int) (h : seen ≤ m) (l : List Int) :
    l.find? (fun q => decide (q ≤ seen)) = (l.filter (fun q => decide (q ≤ m))).find? (fun q => decide (q ≤ seen)) := by
  induction l with
  | nil => rfl
  | cons x rest ih =>
    by_cases hx : x ≤ m
    · simp only [List.filter_cons, hx, decide_true, ite_true, List.find?_cons]
      by_cases hs : x ≤ seen
      · simp [hs]
      · simp [hs, ih]
    · have : ¬ x ≤ seen := by omega
      simp only [List.filter_cons, hx, decide_false, List.find?_cons]
      simp [this, ih]

theorem keepThrough_filter (m t : Int) (h : t ≤ m) (l : List Int) :
    (keepThrough t l).filter (fun q => decide (q ≤ m)) = keepThrough t (l.filter (fun q => decide (q ≤ m))) := by
  induction l with
  | nil => rfl
  | cons x rest ih =>
    by_cases hx : x ≤ m
    · by_cases ht : x ≤ t
      · simp [keepThrough, hx, ht]
      · simp [keepThrough, hx, ht, ih]
    · have ht : ¬ x ≤ t := by omega
      simp [keepThrough, hx, ht, ih]


theorem span_loop {α : Type} (p : α → Bool) (l : List α) : ∀ acc : List α,
    List.span.loop p l acc = (acc.reverse ++ l.takeWhile p, l.dropWhile p) := by
  induction l with
  | nil => intro acc; simp [List.span.loop]
  | cons a as ih =>
    intro acc
    cases hp : p a
    · simp [List.span.loop, hp]
    · simp [List.span.loop, hp, ih]

theorem span_eq {α : Type} (p : α → Bool) (l : List α) : l.span p = (l.takeWhile p, l.dropWhile p) := by
  unfold List.span
  rw [span_loop]; simp

theorem span_sorted (c : Int) : ∀ (l : List Pending), l.Pairwise (fun p q => p.known ≤ q.known) →
    l.span (fun p => decide (p.known ≤ c)) =
      (l.filter (fun p => decide (p.known ≤ c)), l.filter (fun p => !decide (p.known ≤ c))) := by
  intro l
  rw [span_eq]
  induction l with
  | nil => intro _; rfl
  | cons x rest ih =>
    intro h
    rw [List.pairwise_cons] at h
    by_cases hx : x.known ≤ c
    · simp only [List.takeWhile_cons, List.dropWhile_cons, List.filter_cons, hx, decide_true, ite_true, Bool.not_true]
      have := ih h.2
      simp only [Prod.mk.injEq] at this ⊢
      simp [this.1, this.2]
    · have hx' : ¬ x.known ≤ c := hx
      have hall : ∀ y ∈ rest, ¬ y.known ≤ c := fun y hy => by have := h.1 y hy; omega
      have e1 : rest.filter (fun p => decide (p.known ≤ c)) = [] := by
        rw [List.filter_eq_nil_iff]; intro y hy; simpa using hall y hy
      have e2 : rest.filter (fun p => !decide (p.known ≤ c)) = rest := by
        rw [List.filter_eq_self]; intro y hy; simpa using hall y hy
      simp [hx', e1, e2]

theorem filter_via (τ : Int) (P : Pending → Bool) (hP : ∀ p, P p = true → knownBy τ p = true)
    (l l' : List Pending) (h : l.filter (knownBy τ) = l'.filter (knownBy τ)) :
    l.filter P = l'.filter P := by
  have e : ∀ m : List Pending, m.filter P = (m.filter (knownBy τ)).filter P := by
    intro m
    rw [List.filter_filter]
    apply List.filter_congr
    intro a _
    cases hpa : P a
    · simp
    · simp [hP a hpa]
  rw [e l, e l', h]

theorem release_agree (τ t : Int) (h : Agree τ s u) (ht : t ≤ τ) : Agree τ (release s t) (release u t) := by
  have hs := span_sorted t s.pending h.sortedL
  have hu := span_sorted t u.pending h.sortedR
  have hready : s.pending.filter (fun p => decide (p.known ≤ t)) = u.pending.filter (fun p => decide (p.known ≤ t)) :=
    filter_via τ _ (fun p hp => by simp only [knownBy, decide_eq_true_eq] at hp ⊢; omega) _ _ h.pending
  unfold release
  simp only [hs, hu]
  refine ⟨h.cfg, h.prog, h.next, ?_, h.mach, ?_, ?_, ?_, h.quotes⟩
  · simp only [hready, h.view, h.cfg]
  · exact h.sortedL.filter _
  · exact h.sortedR.filter _
  · simp only [List.filter_filter]
    exact filter_via τ _ (fun p hp => by simp only [Bool.and_eq_true] at hp; exact hp.1) _ _ h.pending


theorem map_eq_of_map_eq {α β γ : Type} (f : α → β) (g : α → γ) (hfg : ∀ a b, f a = f b → g a = g b) :
    ∀ l l' : List α, l.map f = l'.map f → l.map g = l'.map g := by
  intro l
  induction l with
  | nil => intro l' h; cases l' <;> simp_all
  | cons a rest ih =>
    intro l' h
    cases l' with
    | nil => simp at h
    | cons b rest' =>
      simp only [List.map_cons, List.cons.injEq] at h ⊢
      exact ⟨hfg a b h.1, ih rest' h.2⟩

theorem tickCoin_view (cfg : Config) (time m : Int) (hm : time - cfg.delta ≤ m) (c c' : CoinState)
    (h : quotesBy m c = quotesBy m c') : (tickCoin cfg time c).2.2.2 = (tickCoin cfg time c').2.2.2 := by
  unfold tickCoin
  simp only []
  unfold quotesBy at h
  rw [find_filter m _ hm c.quotes, find_filter m _ hm c'.quotes, h]

theorem tickCoin_quotes (cfg : Config) (time m : Int) (hm : time - cfg.delta ≤ m) (c c' : CoinState)
    (h : quotesBy m c = quotesBy m c') : quotesBy m (tickCoin cfg time c).1 = quotesBy m (tickCoin cfg time c').1 := by
  unfold tickCoin quotesBy
  simp only []
  unfold quotesBy at h
  rw [keepThrough_filter m _ hm, keepThrough_filter m _ hm, h]

theorem flatMap_congr' {α β : Type} (f g : α → List β) (l : List α) (h : ∀ x ∈ l, f x = g x) :
    l.flatMap f = l.flatMap g := by
  induction l with
  | nil => rfl
  | cons x rest ih =>
    simp only [List.flatMap_cons]
    rw [h x (List.mem_cons_self ..), ih (fun y hy => h y (List.mem_cons_of_mem _ hy))]

theorem sourceValue_congr (s u : State) (hc : s.cfg = u.cfg) (hv : s.view = u.view) :
    sourceValue s = sourceValue u := by
  funext c name
  unfold sourceValue
  rw [hc, hv]

theorem exactInput_congr (s u : State) (hc : s.cfg = u.cfg) (v : ViewCoin) (stale : Bool) (name : String) :
    exactInput s v stale name = exactInput u v stale name := by
  unfold exactInput
  rw [hc]

theorem coinName_congr (s u : State) (hc : s.cfg = u.cfg) (c : Nat) : coinName s c = coinName u c := by
  unfold coinName; rw [hc]

theorem tickAt_agree (τ time : Int) (s u : State) (h : Agree τ s u) (ht : time ≤ τ) :
    Agree τ (tickAt s time).1 (tickAt u time).1 ∧ (tickAt s time).2.2 = (tickAt u time).2.2 := by
  have hr := release_agree τ time h ht
  unfold tickAt
  generalize release s time = s₁ at hr
  generalize release u time = u₁ at hr
  simp only []
  have hlen : s₁.coins.length = u₁.coins.length := by
    have := congrArg List.length hr.quotes
    simpa using this
  have hm : time - s₁.cfg.delta ≤ τ - s₁.cfg.delta := by omega
  have hleaf : ∀ c : Nat, ((List.map (tickCoin s₁.cfg time) s₁.coins)[c]?).map (fun m : CoinState × String × Bool × Bool => m.2.2.2) =
      ((List.map (tickCoin u₁.cfg time) u₁.coins)[c]?).map (fun m : CoinState × String × Bool × Bool => m.2.2.2) := by
    intro c
    have hq := congrArg (fun l => l[c]?) hr.quotes
    simp only [List.getElem?_map] at hq ⊢
    rw [← hr.cfg]
    cases hx : s₁.coins[c]? <;> cases hy : u₁.coins[c]? <;> simp only [hx, hy, Option.map_none, Option.map_some] at hq ⊢
    all_goals first
      | rfl
      | (exfalso; simp at hq; done)
      | (simp at hq; exact congrArg some (tickCoin_view s₁.cfg time (τ - s₁.cfg.delta) hm _ _ hq))
  have hsv := sourceValue_congr s₁ u₁ hr.cfg hr.view
  have hex := exactInput_congr s₁ u₁ hr.cfg
  have hcn := coinName_congr s₁ u₁ hr.cfg
  rw [← hr.cfg] at hleaf ⊢
  refine ⟨?_, ?_⟩
  · refine ⟨rfl, hr.prog, hr.next, ?_, ?_, hr.sortedL, hr.sortedR, hr.pending, ?_⟩
    · simp only [hr.view]
    · simp only [hsv, hr.view, hr.prog, hr.mach]
    · simp only [List.map_map]
      refine map_eq_of_map_eq (quotesBy (τ - s₁.cfg.delta)) _ ?_ _ _ hr.quotes
      intro a b hab
      exact tickCoin_quotes s₁.cfg time _ hm a b hab
  · simp only [hsv, hr.view, hr.prog, hr.mach, hlen, hcn, hex]
    congr 1
    · apply List.map_congr_left
      intro c _
      have h := hleaf c
      generalize (List.map (tickCoin s₁.cfg time) s₁.coins)[c]? = oa at h ⊢
      generalize (List.map (tickCoin s₁.cfg time) u₁.coins)[c]? = ob at h ⊢
      cases oa <;> cases ob <;> simp_all
    · apply flatMap_congr'
      intro c _
      have h := hleaf c
      generalize (List.map (tickCoin s₁.cfg time) s₁.coins)[c]? = oa at h ⊢
      generalize (List.map (tickCoin s₁.cfg time) u₁.coins)[c]? = ob at h ⊢
      cases oa <;> cases ob <;> simp_all


theorem tickAt_time (s : State) (time : Int) : (tickAt s time).2.2.time = time := by
  unfold tickAt; rfl

theorem Agree.withNext {τ : Int} {s u : State} (h : Agree τ s u) (x : Option Int) :
    Agree τ { s with nextTick := x } { u with nextTick := x } :=
  ⟨h.cfg, h.prog, rfl, h.view, h.mach, h.sortedL, h.sortedR, h.pending, h.quotes⟩

def TickOk (s : State) : Prop := ∀ ms, s.cfg.tickMs = some ms → 0 ≤ ms

theorem fireR_dead (τ : Int) (n : Nat) : ∀ s : State, TickOk s → Dead τ s →
    Dead τ (fireR n s).1 ∧ ∀ r ∈ (fireR n s).2, τ < r.time := by
  induction n with
  | zero => intro s _ h; simp [fireR_zero, h]
  | succ n ih =>
    intro s hok hd
    cases hn : s.nextTick with
    | none => rw [fireR_stuck _ s (Or.inl hn)]; exact ⟨hd, by simp⟩
    | some t =>
      cases ht : s.cfg.tickMs with
      | none => rw [fireR_stuck _ s (Or.inr ht)]; exact ⟨hd, by simp⟩
      | some ms =>
        have hms := hok ms ht
        have htau := hd t hn
        rw [fireR_succ_some n s t ms hn ht]
        have hcfg : ({ (tickAt s t).1 with nextTick := some (t + ms) } : State).cfg = s.cfg := tickAt_cfg s t
        have hok' : TickOk { (tickAt s t).1 with nextTick := some (t + ms) } := by
          intro m hm; rw [hcfg] at hm; exact hok m hm
        have hd' : Dead τ { (tickAt s t).1 with nextTick := some (t + ms) } := by
          intro x hx
          simp only [Option.some.injEq] at hx
          omega
        obtain ⟨h1, h2⟩ := ih _ hok' hd'
        refine ⟨h1, ?_⟩
        intro r hr
        simp only [List.mem_cons] at hr
        rcases hr with rfl | hr
        · rw [tickAt_time]; exact htau
        · exact h2 r hr

theorem fireR_agree (τ : Int) (n : Nat) : ∀ s u : State, TickOk s → Agree τ s u →
    Good τ (fireR n s).1 (fireR n u).1 ∧
      (fireR n s).2.filter (fun r => decide (r.time ≤ τ)) = (fireR n u).2.filter (fun r => decide (r.time ≤ τ)) := by
  induction n with
  | zero => intro s u _ h; simp [fireR_zero, Good, h]
  | succ n ih =>
    intro s u hok h
    cases hn : s.nextTick with
    | none =>
      have hn' : u.nextTick = none := by rw [← h.next]; exact hn
      rw [fireR_stuck _ s (Or.inl hn), fireR_stuck _ u (Or.inl hn')]
      exact ⟨Or.inl h, rfl⟩
    | some t =>
      have hn' : u.nextTick = some t := by rw [← h.next]; exact hn
      cases ht : s.cfg.tickMs with
      | none =>
        have ht' : u.cfg.tickMs = none := by rw [← h.cfg]; exact ht
        rw [fireR_stuck _ s (Or.inr ht), fireR_stuck _ u (Or.inr ht')]
        exact ⟨Or.inl h, rfl⟩
      | some ms =>
        have ht' : u.cfg.tickMs = some ms := by rw [← h.cfg]; exact ht
        have hms := hok ms ht
        rw [fireR_succ_some n s t ms hn ht, fireR_succ_some n u t ms hn' ht']
        have hcfg : ({ (tickAt s t).1 with nextTick := some (t + ms) } : State).cfg = s.cfg := tickAt_cfg s t
        have hcfg' : ({ (tickAt u t).1 with nextTick := some (t + ms) } : State).cfg = u.cfg := tickAt_cfg u t
        by_cases htau : t ≤ τ
        · obtain ⟨ha, hr⟩ := tickAt_agree τ t s u h htau
          have hok' : TickOk { (tickAt s t).1 with nextTick := some (t + ms) } := by
            intro m hm; rw [hcfg] at hm; exact hok m hm
          obtain ⟨h1, h2⟩ := ih _ _ hok' (ha.withNext (some (t + ms)))
          refine ⟨h1, ?_⟩
          simp only [List.filter_cons, hr, tickAt_time, htau, decide_true, ite_true, h2]
        · have hdead : ∀ (v : State), v.cfg = s.cfg → Dead τ { (tickAt v t).1 with nextTick := some (t + ms) } := by
            intro v _ x hx
            simp only [Option.some.injEq] at hx
            omega
          have hokv : ∀ (v : State), v.cfg = s.cfg → TickOk { (tickAt v t).1 with nextTick := some (t + ms) } := by
            intro v hv m hm
            have : ({ (tickAt v t).1 with nextTick := some (t + ms) } : State).cfg = v.cfg := tickAt_cfg v t
            rw [this, hv] at hm; exact hok m hm
          obtain ⟨d1, d2⟩ := fireR_dead τ n _ (hokv s rfl) (hdead s rfl)
          obtain ⟨e1, e2⟩ := fireR_dead τ n _ (hokv u h.cfg.symm) (hdead u h.cfg.symm)
          refine ⟨Or.inr ⟨d1, e1⟩, ?_⟩
          have hs0 : (fireR n { (tickAt s t).1 with nextTick := some (t + ms) }).2.filter (fun r => decide (r.time ≤ τ)) = [] := by
            rw [List.filter_eq_nil_iff]; intro r hr; have := d2 r hr; simp; omega
          have hu0 : (fireR n { (tickAt u t).1 with nextTick := some (t + ms) }).2.filter (fun r => decide (r.time ≤ τ)) = [] := by
            rw [List.filter_eq_nil_iff]; intro r hr; have := e2 r hr; simp; omega
          simp [tickAt_time, htau, hs0, hu0]

/-! ### The pending list -/

theorem mem_insertPending (p : Pending) : ∀ (l : List Pending) (x : Pending), x ∈ insertPending p l ↔ x = p ∨ x ∈ l := by
  intro l x
  induction l with
  | nil => simp [insertPending]
  | cons q rest ih =>
    unfold insertPending
    by_cases h : p.known < q.known
    · simp [h]
    · simp only [h, ite_false, List.mem_cons, ih]
      constructor
      · rintro (h | h | h) <;> simp [h]
      · rintro (h | h | h) <;> simp [h]

theorem insertPending_sorted (p : Pending) : ∀ l : List Pending, l.Pairwise (fun a b => a.known ≤ b.known) →
    (insertPending p l).Pairwise (fun a b => a.known ≤ b.known) := by
  intro l
  induction l with
  | nil => intro _; simp [insertPending]
  | cons q rest ih =>
    intro h
    have hs := h
    rw [List.pairwise_cons] at h
    unfold insertPending
    by_cases hp : p.known < q.known
    · simp only [hp, ite_true, List.pairwise_cons, List.mem_cons]
      refine ⟨?_, ?_⟩
      · intro x hx
        rcases hx with rfl | hx
        · omega
        · have := h.1 x hx; omega
      · exact h
    · simp only [hp, ite_false]
      rw [List.pairwise_cons]
      refine ⟨?_, ih h.2⟩
      intro x hx
      rw [mem_insertPending] at hx
      rcases hx with rfl | hx
      · omega
      · exact h.1 x hx

theorem filter_known_eq_nil (τ : Int) (l : List Pending) (h : ∀ x ∈ l, τ < x.known) : l.filter (knownBy τ) = [] := by
  rw [List.filter_eq_nil_iff]
  intro x hx
  have := h x hx
  simp [knownBy]; omega

theorem filter_insert_le (τ : Int) (p : Pending) (hp : p.known ≤ τ) : ∀ l : List Pending,
    l.Pairwise (fun a b => a.known ≤ b.known) →
    (insertPending p l).filter (knownBy τ) = insertPending p (l.filter (knownBy τ)) := by
  intro l
  induction l with
  | nil => intro _; simp [insertPending, knownBy, hp]
  | cons q rest ih =>
    intro h
    have h' := h
    rw [List.pairwise_cons] at h'
    unfold insertPending
    by_cases hpq : p.known < q.known
    · simp only [hpq, ite_true, List.filter_cons]
      by_cases hq : q.known ≤ τ
      · simp [knownBy, hp, hq, hpq]
      · have hrest : rest.filter (knownBy τ) = [] := filter_known_eq_nil τ rest (fun x hx => by have := h'.1 x hx; omega)
        simp [knownBy, hp, hq, hrest]
    · have hq : q.known ≤ τ := by omega
      simp only [hpq, ite_false, List.filter_cons]
      simp only [knownBy, hq, decide_true, ite_true]
      have := ih h'.2
      rw [this]
      simp [hpq]

theorem filter_insert_gt (τ : Int) (p : Pending) (hp : τ < p.known) : ∀ l : List Pending,
    l.Pairwise (fun a b => a.known ≤ b.known) →
    (insertPending p l).filter (knownBy τ) = l.filter (knownBy τ) := by
  intro l
  induction l with
  | nil => intro _; simp [insertPending, List.filter_cons, knownBy]; omega
  | cons q rest ih =>
    intro h
    have h' := h
    rw [List.pairwise_cons] at h'
    unfold insertPending
    by_cases hpq : p.known < q.known
    · simp only [hpq, ite_true, List.filter_cons]
      have : ¬ p.known ≤ τ := by omega
      simp [knownBy, this]
    · simp only [hpq, ite_false, List.filter_cons]
      by_cases hq : q.known ≤ τ
      · simp [knownBy, hq, ih h'.2]
      · have e1 : rest.filter (knownBy τ) = [] := filter_known_eq_nil τ rest (fun x hx => by have := h'.1 x hx; omega)
        have e2 : (insertPending p rest).filter (knownBy τ) = [] :=
          filter_known_eq_nil τ _ (fun x hx => by
            rw [mem_insertPending] at hx
            rcases hx with rfl | hx
            · exact hp
            · have := h'.1 x hx; omega)
        simp [knownBy, hq, e1, e2]


/-! ### One event's effect -/

theorem after_frame (s : State) (e : Event) (r : Reading) :
    (after s e r).cfg = s.cfg ∧ (after s e r).prog = s.prog ∧ (after s e r).nextTick = s.nextTick ∧
      (after s e r).view = s.view ∧ (after s e r).mach = s.mach := by
  cases r <;> simp only [after, applyPayload, withPending] <;> (try split) <;> simp

theorem after_pending (e : Event) (r : Reading) :
    ∃ o : Option PView, ∀ s : State, (after s e r).pending =
      (match o with
       | some w => if s.prog.isSome then insertPending ⟨e.coin, e.known, w⟩ s.pending else s.pending
       | none => s.pending) := by
  cases r with
  | listing rules => exact ⟨none, fun s => rfl⟩
  | ending price =>
    refine ⟨some .ending, fun s => ?_⟩
    simp only [after, applyPayload, withPending]
    split <;> simp_all
  | funding hour rate oracle =>
    refine ⟨some (.funding (ofUnits 12 rate) (oracle.map (ofUnits 8))), fun s => ?_⟩
    simp only [after, applyPayload, withPending]
    split <;> simp_all
  | trade id price size sizeScale seller =>
    refine ⟨some (.trade (ofUnits 8 price) (ofUnits sizeScale size)), fun s => ?_⟩
    simp only [after, applyPayload, withPending]
    split <;> simp_all
  | quote bid bidSize ask askSize sizeScale =>
    refine ⟨some (.quote (ofUnits 8 bid) (ofUnits sizeScale bidSize) (ofUnits 8 ask) (ofUnits sizeScale askSize)), fun s => ?_⟩
    simp only [after, applyPayload, withPending]
    split <;> simp_all
  | observation source bits =>
    refine ⟨some (.observation source bits), fun s => ?_⟩
    simp only [after, applyPayload, withPending]
    split <;> simp_all


theorem map_setAt_getD {α β : Type} (f : α → β) (g : α → α) (hg : ∀ a, f (g a) = f a) (d : α) :
    ∀ (l : List α) (i : Nat), (setAt l i (g (l.getD i d))).map f = l.map f := by
  intro l
  induction l with
  | nil => intro i; simp [setAt]
  | cons x rest ih =>
    intro i
    cases i with
    | zero => simp [setAt, hg]
    | succ i =>
      have := ih i
      simpa [setAt, List.getD_eq_getElem?_getD] using this

theorem withPending_coins (s : State) (e : Event) (w : Unit → PView) : (withPending s e w).coins = s.coins := by
  unfold withPending; split <;> rfl

theorem after_coins (s : State) (e : Event) (r : Reading) (m : Int) (hc : ∃ ms, s.cfg.tickMs = some ms)
    (hm : m < e.time) : (after s e r).coins.map (quotesBy m) = s.coins.map (quotesBy m) := by
  have key : ∀ g : CoinState → CoinState, (∀ c, quotesBy m (g c) = quotesBy m c) →
      (setAt s.coins e.coin (g (getCoin s e.coin))).map (quotesBy m) = s.coins.map (quotesBy m) :=
    fun g hg => map_setAt_getD (quotesBy m) g hg CoinState.fresh s.coins e.coin
  obtain ⟨ms, hms⟩ := hc
  cases r with
  | listing rules => simp [after, applyPayload]
  | ending price =>
    simp only [after, applyPayload, withPending_coins]
    exact key (fun c => { c with price := some (ofUnits 8 price) }) (fun c => rfl)
  | funding hour rate oracle =>
    simp only [after, applyPayload, withPending_coins]
    exact key (fun c => { c with fundingHour := some hour }) (fun c => rfl)
  | trade id price size sizeScale seller =>
    simp only [after, applyPayload, withPending_coins]
    exact key (fun c => { c with price := some (ofUnits 8 price) }) (fun c => rfl)
  | quote bid bidSize ask askSize sizeScale =>
    simp only [after, applyPayload, withPending_coins, hms, Option.isSome_some, ite_true]
    refine key (fun c => { c with lastQuote := some e.time, quotes := e.time :: c.quotes, price := some (midPrice bid ask) }) ?_
    intro c
    simp [quotesBy, List.filter_cons]
    omega
  | observation source bits => simp [after, applyPayload, withPending_coins]


def Clocked (s : State) : Prop := ∃ ms, s.cfg.tickMs = some ms

theorem after_sorted (s : State) (e : Event) (r : Reading) (h : PendSorted s) : PendSorted (after s e r) := by
  obtain ⟨o, ho⟩ := after_pending e r
  unfold PendSorted at h ⊢
  rw [ho]
  cases o with
  | none => exact h
  | some w =>
    simp only []
    split
    · exact insertPending_sorted _ _ h
    · exact h

theorem after_pending_agree (τ : Int) (s u : State) (e : Event) (r : Reading) (h : Agree τ s u) :
    (after s e r).pending.filter (knownBy τ) = (after u e r).pending.filter (knownBy τ) := by
  obtain ⟨o, ho⟩ := after_pending e r
  rw [ho s, ho u]
  cases o with
  | none => exact h.pending
  | some w =>
    simp only [h.prog]
    split
    · by_cases hk : e.known ≤ τ
      · rw [filter_insert_le τ _ hk _ h.sortedL, filter_insert_le τ _ hk _ h.sortedR, h.pending]
      · have : τ < e.known := by omega
        rw [filter_insert_gt τ _ this _ h.sortedL, filter_insert_gt τ _ this _ h.sortedR, h.pending]
    · exact h.pending

theorem after_agree (τ : Int) (s u : State) (e : Event) (r : Reading) (h : Agree τ s u) (hc : Clocked s)
    (ht : τ - s.cfg.delta < e.time) : Agree τ (after s e r) (after u e r) := by
  obtain ⟨c1, c2, c3, c4, c5⟩ := after_frame s e r
  obtain ⟨d1, d2, d3, d4, d5⟩ := after_frame u e r
  have hcu : Clocked u := by obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [← h.cfg]; exact hms⟩
  refine ⟨by rw [c1, d1, h.cfg], by rw [c2, d2, h.prog], by rw [c3, d3, h.next], by rw [c4, d4, h.view],
    by rw [c5, d5, h.mach], after_sorted s e r h.sortedL, after_sorted u e r h.sortedR,
    after_pending_agree τ s u e r h, ?_⟩
  rw [c1, after_coins s e r (τ - s.cfg.delta) hc ht, after_coins u e r (τ - s.cfg.delta) hcu ht, h.quotes]

theorem after_self (τ : Int) (s : State) (e : Event) (r : Reading) (hs : PendSorted s) (hc : Clocked s)
    (hk : τ < e.known) (ht : τ - s.cfg.delta < e.time) : Agree τ s (after s e r) := by
  obtain ⟨c1, c2, c3, c4, c5⟩ := after_frame s e r
  refine ⟨c1.symm, c2.symm, c3.symm, c4.symm, c5.symm, hs, after_sorted s e r hs, ?_, ?_⟩
  · obtain ⟨o, ho⟩ := after_pending e r
    rw [ho s]
    cases o with
    | none => rfl
    | some w =>
      simp only []
      split
      · rw [filter_insert_gt τ _ hk _ hs]
      · rfl
  · rw [after_coins s e r (τ - s.cfg.delta) hc ht]


/-! ### Runs from two markets that agree -/

theorem release_sorted (s : State) (t : Int) (h : PendSorted s) : PendSorted (release s t) := by
  have hs := span_sorted t s.pending h
  unfold PendSorted release
  simp only [hs]
  exact h.filter _

theorem tickAt_pending_sorted (s : State) (t : Int) (h : PendSorted s) : PendSorted (tickAt s t).1 := by
  have := release_sorted s t h
  unfold PendSorted at this ⊢
  unfold tickAt
  exact this

theorem fireR_sorted (n : Nat) : ∀ s : State, PendSorted s → PendSorted (fireR n s).1 := by
  induction n with
  | zero => intro s h; simpa [fireR_zero] using h
  | succ n ih =>
    intro s h
    cases hn : s.nextTick with
    | none => rw [fireR_stuck _ s (Or.inl hn)]; exact h
    | some t =>
      cases ht : s.cfg.tickMs with
      | none => rw [fireR_stuck _ s (Or.inr ht)]; exact h
      | some ms =>
        rw [fireR_succ_some n s t ms hn ht]
        exact ih _ (tickAt_pending_sorted s t h)

theorem fire_good (τ bs bu : Int) (s u : State) (hs : TickOk s) (hu : TickOk u) (h : Good τ s u)
    (hb : Agree τ s u → bs = bu) :
    Good τ (fireR (ticksBefore s bs) s).1 (fireR (ticksBefore u bu) u).1 ∧
      (fireR (ticksBefore s bs) s).2.filter (fun r => decide (r.time ≤ τ)) =
        (fireR (ticksBefore u bu) u).2.filter (fun r => decide (r.time ≤ τ)) := by
  rcases h with h | ⟨hds, hdu⟩
  · have hbb := hb h
    have : ticksBefore u bu = ticksBefore s bs := by
      unfold ticksBefore; rw [← h.cfg, ← h.next, hbb]
    rw [this]
    exact fireR_agree τ _ s u hs h
  · obtain ⟨d1, d2⟩ := fireR_dead τ (ticksBefore s bs) s hs hds
    obtain ⟨e1, e2⟩ := fireR_dead τ (ticksBefore u bu) u hu hdu
    refine ⟨Or.inr ⟨d1, e1⟩, ?_⟩
    have hs0 : (fireR (ticksBefore s bs) s).2.filter (fun r => decide (r.time ≤ τ)) = [] := by
      rw [List.filter_eq_nil_iff]; intro r hr; have := d2 r hr; simp; omega
    have hu0 : (fireR (ticksBefore u bu) u).2.filter (fun r => decide (r.time ≤ τ)) = [] := by
      rw [List.filter_eq_nil_iff]; intro r hr; have := e2 r hr; simp; omega
    rw [hs0, hu0]

theorem afterFire_cfg (n : Nat) (s : State) (e : Event) (r : Reading) : (after (fireR n s).1 e r).cfg = s.cfg := by
  rw [after_cfg, fireR_cfg]

theorem after_good (τ : Int) (s u : State) (e : Event) (r : Reading) (h : Good τ s u) (hc : Clocked s)
    (ht : τ - s.cfg.delta < e.time) : Good τ (after s e r) (after u e r) := by
  rcases h with h | ⟨hs, hu⟩
  · exact Or.inl (after_agree τ s u e r h hc ht)
  · obtain ⟨c1, c2, c3, c4, c5⟩ := after_frame s e r
    obtain ⟨d1, d2, d3, d4, d5⟩ := after_frame u e r
    refine Or.inr ⟨fun t hx => hs t (by rw [← c3]; exact hx), fun t hx => hu t (by rw [← d3]; exact hx)⟩

/-- Two states that agree at `τ` give the same records through `τ` over the same events. -/
theorem recs_agree (τ δ : Int) : ∀ (ps : List Pair) (s u : State), s.cfg.delta = δ → TickOk s → TickOk u →
    Clocked s → Good τ s u → (∀ p ∈ ps, τ - δ < p.1.time) →
    (recsPairs s ps).filter (fun r => decide (r.time ≤ τ)) = (recsPairs u ps).filter (fun r => decide (r.time ≤ τ)) := by
  intro ps
  induction ps with
  | nil =>
    intro s u hδ hs hu hc h _
    rw [recsPairs_nil, recsPairs_nil]
    exact (fire_good τ s.cfg.stop u.cfg.stop s u hs hu h (fun ha => by rw [ha.cfg])).2
  | cons p rest ih =>
    intro s u hδ hs hu hc h hp
    rw [recsPairs_cons, recsPairs_cons, List.filter_append, List.filter_append]
    obtain ⟨g1, g2⟩ := fire_good τ p.1.time p.1.time s u hs hu h (fun _ => rfl)
    rw [g2]
    congr 1
    have hcs : (fireR (ticksBefore s p.1.time) s).1.cfg = s.cfg := fireR_cfg _ _
    have hcu : (fireR (ticksBefore u p.1.time) u).1.cfg = u.cfg := fireR_cfg _ _
    have hclk : Clocked (fireR (ticksBefore s p.1.time) s).1 := by
      obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [hcs]; exact hms⟩
    have hpt : τ - (fireR (ticksBefore s p.1.time) s).1.cfg.delta < p.1.time := by
      rw [hcs, hδ]; exact hp p (List.mem_cons_self ..)
    apply ih
    · rw [afterFire_cfg]; exact hδ
    · intro m hm; rw [afterFire_cfg] at hm; exact hs m hm
    · intro m hm; rw [afterFire_cfg] at hm; exact hu m hm
    · obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [afterFire_cfg]; exact hms⟩
    · exact after_good τ _ _ p.1 p.2 g1 hclk hpt
    · intro q hq; exact hp q (List.mem_cons_of_mem _ hq)


/-- Dropping the events not known by `τ` changes no record through `τ`. -/
theorem recs_filterK (τ δ : Int) : ∀ (ps : List Pair) (s : State), s.cfg.delta = δ → TickOk s → Clocked s →
    PendSorted s → (∀ p ∈ ps, τ - δ < p.1.time) →
    ps.Pairwise (fun p q => p.1.time ≤ q.1.time) → (∀ p ∈ ps, p.1.time < s.cfg.stop) →
    (recsPairs s ps).filter (fun r => decide (r.time ≤ τ)) =
      (recsPairs s (ps.filter (fun p => decide (p.1.known ≤ τ)))).filter (fun r => decide (r.time ≤ τ)) := by
  intro ps
  induction ps with
  | nil => intros; rfl
  | cons p rest ih =>
    intro s hδ hs hc hsort hp hmono hbound
    have hcs : (fireR (ticksBefore s p.1.time) s).1.cfg = s.cfg := fireR_cfg _ _
    have hclk : Clocked (fireR (ticksBefore s p.1.time) s).1 := by
      obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [hcs]; exact hms⟩
    have hpt : τ - (fireR (ticksBefore s p.1.time) s).1.cfg.delta < p.1.time := by
      rw [hcs, hδ]; exact hp p (List.mem_cons_self ..)
    have hsort1 : PendSorted (fireR (ticksBefore s p.1.time) s).1 := fireR_sorted _ s hsort
    have hmono' := List.pairwise_cons.1 hmono
    by_cases hk : p.1.known ≤ τ
    · have e : (p :: rest).filter (fun p => decide (p.1.known ≤ τ)) =
          p :: rest.filter (fun p => decide (p.1.known ≤ τ)) := by simp [hk]
      rw [e, recsPairs_cons, recsPairs_cons, List.filter_append, List.filter_append]
      congr 1
      apply ih
      · rw [afterFire_cfg]; exact hδ
      · intro m hm; rw [afterFire_cfg] at hm; exact hs m hm
      · obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [afterFire_cfg]; exact hms⟩
      · exact after_sorted _ _ _ hsort1
      · intro q hq; exact hp q (List.mem_cons_of_mem _ hq)
      · exact hmono'.2
      · intro q hq; rw [afterFire_cfg]; exact hbound q (List.mem_cons_of_mem _ hq)
    · have e : (p :: rest).filter (fun p => decide (p.1.known ≤ τ)) = rest.filter (fun p => decide (p.1.known ≤ τ)) := by
        simp [hk]
      rw [e, recsPairs_cons, List.filter_append]
      have hQ : ∀ q ∈ rest.filter (fun p => decide (p.1.known ≤ τ)), τ - δ < q.1.time :=
        fun q hq => hp q (List.mem_cons_of_mem _ ((List.mem_filter.1 hq).1))
      have hfire := recsPairs_fire s (fun ms hm => by obtain ⟨ms', h⟩ := hc; exact hs ms hm) p.1.time
        (rest.filter (fun p => decide (p.1.known ≤ τ))) (by
          cases hq : rest.filter (fun p => decide (p.1.known ≤ τ)) with
          | nil => exact Int.le_of_lt (hbound p (List.mem_cons_self ..))
          | cons q _ =>
            have : q ∈ rest := (List.mem_filter.1 (by rw [hq]; exact List.mem_cons_self ..)).1
            exact hmono'.1 q this)
      rw [hfire, List.filter_append]
      congr 1
      have hag : Agree τ (fireR (ticksBefore s p.1.time) s).1 (after (fireR (ticksBefore s p.1.time) s).1 p.1 p.2) :=
        after_self τ _ p.1 p.2 hsort1 hclk (by omega) hpt
      have hrec := recs_agree τ δ (rest.filter (fun p => decide (p.1.known ≤ τ))) _ _
        (by rw [hcs]; exact hδ) (fun m hm => by rw [hcs] at hm; exact hs m hm)
        (fun m hm => by rw [afterFire_cfg] at hm; exact hs m hm) hclk (Or.inl hag) hQ
      have hih := ih (after (fireR (ticksBefore s p.1.time) s).1 p.1 p.2)
        (by rw [afterFire_cfg]; exact hδ) (fun m hm => by rw [afterFire_cfg] at hm; exact hs m hm)
        (by obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [afterFire_cfg]; exact hms⟩)
        (after_sorted _ _ _ hsort1) (fun q hq => hp q (List.mem_cons_of_mem _ hq)) hmono'.2
        (fun q hq => by rw [afterFire_cfg]; exact hbound q (List.mem_cons_of_mem _ hq))
      rw [hih]
      exact hrec.symm


/-! ### What admission gives of an event -/

def isQTp : Payload → Bool
  | .trade _ _ _ _ => true
  | .quote _ _ => true
  | _ => false

/-- The reading of an event that is no quote and no print: a function of the event alone. -/
def plainReading (e : Event) : Option Reading :=
  match e.payload with
  | .listing rules => some (.listing rules)
  | .ending price => (readInt 8 price).map .ending
  | .funding hour rate oracle =>
    match readInt 12 rate with
    | none => none
    | some r =>
      match oracle with
      | none => some (.funding hour r none)
      | some p => (readInt 8 p).map fun o => .funding hour r (some o)
  | .observation source bits => some (.observation source bits)
  | _ => none

theorem checkPayload_shape (s : State) (e : Event) (rules : Rules) (r : Reading)
    (h : checkPayload s e rules = .ok r) :
    (isQTp e.payload = true → e.known = e.time + s.cfg.delta) ∧
      (isQTp e.payload = false → plainReading e = some r) := by
  unfold checkPayload at h
  unfold plainReading
  cases hpl : e.payload with
  | listing newRules =>
    rw [hpl] at h
    dsimp only at h
    simp only [isQTp, Bool.false_eq_true, false_implies, true_and]
    intro _
    split at h
    · simp [fail] at h
    · split at h
      · simp [fail] at h
      · split at h
        · simp [fail] at h
        · cases h; rfl
  | ending price =>
    rw [hpl] at h
    dsimp only at h
    simp only [isQTp, Bool.false_eq_true, false_implies, true_and]
    intro _
    cases hr : readInt 8 price with
    | none => rw [hr] at h; simp [fail] at h
    | some v =>
      rw [hr] at h
      dsimp only at h
      split at h
      · simp [fail] at h
      · split at h
        · simp [fail] at h
        · split at h
          · simp [fail] at h
          · cases h; simp
  | funding hour rate oracle =>
    rw [hpl] at h
    dsimp only at h
    simp only [isQTp, Bool.false_eq_true, false_implies, true_and]
    intro _
    cases hr : readInt 12 rate with
    | none => rw [hr] at h; simp [fail] at h
    | some v =>
      rw [hr] at h
      dsimp only at h
      cases oracle with
      | none =>
        dsimp only at h
        split at h
        · simp [fail] at h
        · split at h
          · simp [fail] at h
          · split at h
            · simp [fail] at h
            · split at h
              · simp [fail] at h
              · cases h; simp
      | some price =>
        dsimp only at h
        cases ho : readInt 8 price with
        | none => rw [ho] at h; simp [fail] at h
        | some o =>
          rw [ho] at h
          dsimp only at h
          split at h
          · simp [fail] at h
          · split at h
            · simp [fail] at h
            · split at h
              · simp [fail] at h
              · split at h
                · simp [fail] at h
                · cases h; simp [ho]
  | trade id price size seller =>
    rw [hpl] at h
    dsimp only at h
    simp only [isQTp, true_implies, Bool.true_eq_false, false_implies, and_true]
    cases ht : s.cfg.trades with
    | none => rw [ht] at h; simp [fail] at h
    | some _ =>
      rw [ht] at h
      dsimp only at h
      cases hc : checkPrice rules price with
      | error f => rw [hc] at h; simp at h
      | ok pu =>
        rw [hc] at h
        dsimp only at h
        cases hd : checkSize rules size with
        | error f => rw [hd] at h; simp at h
        | ok su =>
          rw [hd] at h
          dsimp only at h
          cases hrp : checkRepeated s e id with
          | some f => rw [hrp] at h; simp at h
          | none =>
            rw [hrp] at h
            dsimp only at h
            split at h
            · simp [fail] at h
            · rename_i hne
              simpa using hne
  | quote bids asks =>
    rw [hpl] at h
    dsimp only at h
    simp only [isQTp, true_implies, Bool.true_eq_false, false_implies, and_true]
    cases hq : s.cfg.quotes with
    | none => rw [hq] at h; simp [fail] at h
    | some _ =>
      rw [hq] at h
      dsimp only at h
      cases bids with
      | nil => simp [fail] at h
      | cons bb rb =>
        cases asks with
        | nil => simp [fail] at h
        | cons ab ra =>
          dsimp only at h
          cases hsb : scanSide rules true bb rb with
          | error f => rw [hsb] at h; simp at h
          | ok bid =>
            rw [hsb] at h
            dsimp only at h
            cases hsa : scanSide rules false ab ra with
            | error f => rw [hsa] at h; simp at h
            | ok ask =>
              rw [hsa] at h
              dsimp only at h
              split at h
              · simp [fail] at h
              · split at h
                · simp [fail] at h
                · rename_i hne
                  simpa using hne
  | observation source bits =>
    rw [hpl] at h
    dsimp only at h
    simp only [isQTp, Bool.false_eq_true, false_implies, true_and]
    intro _
    cases ho : s.cfg.observations[source]? with
    | none => rw [ho] at h; simp [fail] at h
    | some o =>
      rw [ho] at h
      dsimp only at h
      split at h
      · simp [fail] at h
      · cases h; rfl


theorem key_time_le (e q : Event) (h : compare (eventKey e) (eventKey q) ≠ .lt) : q.time ≤ e.time := by
  by_cases hlt : e.time < q.time
  · exfalso
    apply h
    unfold eventKey
    have : compare e.time q.time = .lt := Int.compare_eq_lt.2 hlt
    simp [compare, compareLex, compareOn, Ordering.then, compareOfLessAndEq, hlt]
  · omega

theorem admit_ok_shape (s : State) (e : Event) (r : Reading) (h : admit s e = .ok r) :
    e.time < s.cfg.stop ∧ (∀ q, s.previous = some q → q.time ≤ e.time) ∧
      (isQTp e.payload = true → e.known = e.time + s.cfg.delta) ∧
      (isQTp e.payload = false → plainReading e = some r) := by
  unfold admit at h
  cases hp : checkProtected e with
  | some f => rw [hp] at h; simp at h
  | none =>
    rw [hp] at h
    dsimp only at h
    cases hh : checkHorizon s e with
    | some f => rw [hh] at h; simp at h
    | none =>
      rw [hh] at h
      dsimp only at h
      cases ho : checkOrder s e with
      | some f => rw [ho] at h; simp at h
      | none =>
        rw [ho] at h
        dsimp only at h
        cases he : checkEnded s e with
        | some f => rw [he] at h; simp at h
        | none =>
          rw [he] at h
          dsimp only at h
          cases hr : s.rules[e.coin]? with
          | none => rw [hr] at h; simp [fail] at h
          | some rules =>
            rw [hr] at h
            dsimp only at h
            obtain ⟨c1, c2⟩ := checkPayload_shape s e rules r h
            refine ⟨?_, ?_, c1, c2⟩
            · unfold checkHorizon at hh
              by_cases hlt : e.time < s.cfg.start || s.cfg.stop ≤ e.time
              · simp [hlt, found] at hh
              · simp only [Bool.or_eq_true, decide_eq_true_eq, not_or] at hlt
                omega
            · intro q hq
              unfold checkOrder at ho
              rw [hq] at ho
              dsimp only at ho
              cases hc : compare (eventKey e) (eventKey q) with
              | lt => rw [hc] at ho; simp [found] at ho
              | eq => exact key_time_le e q (by rw [hc]; simp)
              | gt => exact key_time_le e q (by rw [hc]; simp)

/-- A run of events the machine admits, with what admission read of each. -/
inductive Adm : State → List Pair → Prop
  | nil (s : State) : Adm s []
  | cons (s : State) (e : Event) (r : Reading) (ps : List Pair) : s.rejected = none → admit s e = .ok r →
      Adm (advanceRec s e r).1 ps → Adm s ((e, r) :: ps)

theorem advanceRec_cfg (s : State) (e : Event) (r : Reading) : (advanceRec s e r).1.cfg = s.cfg := by
  rw [advanceRec_state]; exact afterFire_cfg _ s e r

theorem advanceRec_previous (s : State) (e : Event) (r : Reading) : (advanceRec s e r).1.previous = some e := by
  rw [advanceRec_state]; unfold after; simp

theorem advanceRec_sorted (s : State) (e : Event) (r : Reading) (h : PendSorted s) :
    PendSorted (advanceRec s e r).1 := by
  rw [advanceRec_state]
  exact after_sorted _ _ _ (fireR_sorted _ s h)

theorem recsPairs_cons' (s : State) (p : Pair) (rest : List Pair) :
    recsPairs s (p :: rest) = (advanceRec s p.1 p.2).2.2 ++ recsPairs (advanceRec s p.1 p.2).1 rest := by
  simp [recsPairs, runP]

theorem snapshots_adm : ∀ (es : List Event) (s : State) (rs : List TickRecord), snapshots s es = some rs →
    ∃ ps : List Pair, ps.map Prod.fst = es ∧ Adm s ps ∧ recsPairs s ps = rs := by
  intro es
  induction es with
  | nil =>
    intro s rs h
    refine ⟨[], rfl, Adm.nil s, ?_⟩
    simp only [snapshots, Option.some.injEq] at h
    rw [recsPairs_nil]
    exact h
  | cons e es ih =>
    intro s rs h
    unfold snapshots at h
    cases hr : s.rejected with
    | some f => rw [hr] at h; simp at h
    | none =>
      rw [hr] at h
      dsimp only at h
      cases ha : admit s e with
      | error f => rw [ha] at h; simp at h
      | ok reading =>
        rw [ha] at h
        dsimp only at h
        cases hs : snapshots (advanceRec s e reading).1 es with
        | none => rw [hs] at h; simp at h
        | some rs' =>
          rw [hs] at h
          simp only [Option.map_some, Option.some.injEq] at h
          obtain ⟨ps, hps, hadm, hrec⟩ := ih _ rs' hs
          refine ⟨(e, reading) :: ps, by simp [hps], Adm.cons s e reading ps hr ha hadm, ?_⟩
          rw [recsPairs_cons', hrec, ← h]


def Mono (ps : List Pair) : Prop := ps.Pairwise (fun p q => p.1.time ≤ q.1.time)

theorem adm_props {s : State} {ps : List Pair} (h : Adm s ps) :
    (∀ q, s.previous = some q → ∀ p ∈ ps, q.time ≤ p.1.time) ∧ Mono ps ∧
      (∀ p ∈ ps, p.1.time < s.cfg.stop) ∧
      (∀ p ∈ ps, (isQTp p.1.payload = true → p.1.known = p.1.time + s.cfg.delta) ∧
        (isQTp p.1.payload = false → plainReading p.1 = some p.2)) := by
  induction h with
  | nil s => exact ⟨by simp, by simp [Mono], by simp, by simp⟩
  | cons s e r ps hrej hadm hrest ih =>
    obtain ⟨i1, i2, i3, i4⟩ := ih
    obtain ⟨s1, s2, s3, s4⟩ := admit_ok_shape s e r hadm
    have hprev := advanceRec_previous s e r
    have hcfg := advanceRec_cfg s e r
    rw [hcfg] at i3 i4
    refine ⟨?_, ?_, ?_, ?_⟩
    · intro q hq p hp
      rcases List.mem_cons.1 hp with rfl | hp
      · exact s2 q hq
      · have := i1 e hprev p hp
        have := s2 q hq
        omega
    · unfold Mono at i2 ⊢
      exact List.pairwise_cons.2 ⟨fun p hp => i1 e hprev p hp, i2⟩
    · intro p hp
      rcases List.mem_cons.1 hp with rfl | hp
      · exact s1
      · exact i3 p hp
    · intro p hp
      rcases List.mem_cons.1 hp with rfl | hp
      · exact ⟨s3, s4⟩
      · exact i4 p hp

theorem adm_det : ∀ {s : State} {P P' : List Pair}, Adm s P → Adm s P' → P.map Prod.fst = P'.map Prod.fst → P = P' := by
  intro s P
  induction P generalizing s with
  | nil => intro P' _ h2 h3; cases P' <;> simp_all
  | cons p P ih =>
    intro P' h1 h2 h3
    cases P' with
    | nil => simp at h3
    | cons p' P' =>
      obtain ⟨e, r⟩ := p
      obtain ⟨e', r'⟩ := p'
      simp only [List.map_cons, List.cons.injEq] at h3
      obtain ⟨he, hrest⟩ := h3
      cases h1 with
      | cons _ _ _ _ _ ha1 hadm1 =>
        cases h2 with
        | cons _ _ _ _ _ ha2 hadm2 =>
          subst he
          have : r = r' := by rw [ha1] at ha2; cases ha2; rfl
          subst this
          rw [ih hadm1 hadm2 hrest]

theorem adm_split : ∀ {P Q : List Pair} {s : State}, Adm s (P ++ Q) → Adm s P ∧ Adm (runP s P).1 Q := by
  intro P
  induction P with
  | nil => intro Q s h; exact ⟨Adm.nil s, by simpa [runP] using h⟩
  | cons p P ih =>
    intro Q s h
    obtain ⟨e, r⟩ := p
    cases h with
    | cons _ _ _ _ hrej ha hadm =>
      obtain ⟨h1, h2⟩ := ih hadm
      exact ⟨Adm.cons s e r P hrej ha h1, by simpa [runP] using h2⟩

theorem runP_cfg : ∀ (P : List Pair) (s : State), (runP s P).1.cfg = s.cfg := by
  intro P
  induction P with
  | nil => intro s; rfl
  | cons p P ih => intro s; simp only [runP]; rw [ih, advanceRec_cfg]

theorem runP_sorted : ∀ (P : List Pair) (s : State), PendSorted s → PendSorted (runP s P).1 := by
  intro P
  induction P with
  | nil => intro s h; exact h
  | cons p P ih => intro s h; simp only [runP]; exact ih _ (advanceRec_sorted s p.1 p.2 h)

theorem pairs_eq_of_plain : ∀ (L L' : List Pair), L.map Prod.fst = L'.map Prod.fst →
    (∀ p ∈ L, plainReading p.1 = some p.2) → (∀ p ∈ L', plainReading p.1 = some p.2) → L = L' := by
  intro L
  induction L with
  | nil => intro L' h _ _; cases L' <;> simp_all
  | cons p L ih =>
    intro L' h h1 h2
    cases L' with
    | nil => simp at h
    | cons p' L' =>
      simp only [List.map_cons, List.cons.injEq] at h
      obtain ⟨he, hrest⟩ := h
      have a1 := h1 p (List.mem_cons_self ..)
      have a2 := h2 p' (List.mem_cons_self ..)
      have : p.2 = p'.2 := by rw [he] at a1; rw [a1] at a2; exact Option.some.inj a2
      have hp : p = p' := Prod.ext he this
      rw [hp, ih L' hrest (fun q hq => h1 q (List.mem_cons_of_mem _ hq)) (fun q hq => h2 q (List.mem_cons_of_mem _ hq))]


theorem start_shape {program header : String} {initial : State} (h : start program header = .ok initial) :
    ∃ (cfg : Config) (p : Engine.Lang.Program),
      initial = initialState cfg (some p) (some ((p.tick : Int) * 1000)) := by
  unfold start at h
  cases hp : prepare program header with
  | error f => rw [hp] at h; simp [Bind.bind, Except.bind] at h
  | ok pc =>
    obtain ⟨p, cfg⟩ := pc
    rw [hp] at h
    simp only [Bind.bind, Except.bind] at h
    cases hb : Engine.Machine.bind p cfg with
    | error f => rw [hb] at h; simp at h
    | ok u =>
      rw [hb] at h
      have h' : (Except.ok (initialState cfg (some p) (some ((p.tick : Int) * 1000))) : Except String State) = Except.ok initial := h
      injection h' with h'
      exact ⟨cfg, p, h'.symm⟩


theorem start_facts {program header : String} {initial : State} (h : start program header = .ok initial) :
    TickOk initial ∧ Clocked initial ∧ PendSorted initial ∧ initial.rejected = none ∧ initial.previous = none := by
  obtain ⟨cfg, p, rfl⟩ := start_shape h
  refine ⟨?_, ?_, ?_, rfl, rfl⟩
  · intro ms hms
    simp only [initialState, Option.some.injEq] at hms
    subst hms
    omega
  · exact ⟨_, rfl⟩
  · simp [PendSorted, initialState]



/-! ### L1a -/

theorem dropWhile_gt (c : Int) : ∀ ps : List Pair, Mono ps →
    ∀ p ∈ ps.dropWhile (fun p => decide (p.1.time ≤ c)), c < p.1.time := by
  intro ps
  induction ps with
  | nil => intro _ p hp; simp at hp
  | cons x rest ih =>
    intro hm p hp
    unfold Mono at hm
    have hm' := List.pairwise_cons.1 hm
    by_cases hx : x.1.time ≤ c
    · simp only [List.dropWhile_cons, hx, decide_true] at hp
      exact ih hm'.2 p hp
    · simp only [List.dropWhile_cons, hx, decide_false] at hp
      rcases List.mem_cons.1 hp with rfl | hp
      · omega
      · have := hm'.1 p hp; omega

theorem events_split (c : Int) (PA PB : List Pair) (hA : ∀ p ∈ PA, p.1.time ≤ c) (hB : ∀ p ∈ PB, c < p.1.time) :
    ((PA ++ PB).map Prod.fst).filter (fun e => decide (e.time ≤ c)) = PA.map Prod.fst := by
  rw [List.map_append, List.filter_append]
  have hA' : (PA.map Prod.fst).filter (fun e => decide (e.time ≤ c)) = PA.map Prod.fst := by
    rw [List.filter_eq_self]
    intro e he
    obtain ⟨p, hp, rfl⟩ := List.mem_map.1 he
    simpa using hA p hp
  have hB' : (PB.map Prod.fst).filter (fun e => decide (e.time ≤ c)) = [] := by
    rw [List.filter_eq_nil_iff]
    intro e he
    obtain ⟨p, hp, rfl⟩ := List.mem_map.1 he
    have := hB p hp
    simp; omega
  rw [hA', hB']; simp

theorem delivery {program header : String} {initial : State} (hs : start program header = .ok initial)
    (es₁ es₂ : List Event) (τ : Int)
    (h1 : es₁.filter (fun e => decide (e.known ≤ τ)) = es₂.filter (fun e => decide (e.known ≤ τ)))
    (h2 : es₁.filter (fun e => decide (e.time ≤ τ - initial.cfg.delta)) =
      es₂.filter (fun e => decide (e.time ≤ τ - initial.cfg.delta)))
    (r₁ r₂ : List TickRecord) (hr₁ : snapshots initial es₁ = some r₁) (hr₂ : snapshots initial es₂ = some r₂) :
    r₁.filter (fun r => decide (r.time ≤ τ)) = r₂.filter (fun r => decide (r.time ≤ τ)) := by
  obtain ⟨hok, hclk, hsort, hrej, hprev⟩ := start_facts hs
  obtain ⟨ps₁, he₁, hadm₁, hrec₁⟩ := snapshots_adm es₁ initial r₁ hr₁
  obtain ⟨ps₂, he₂, hadm₂, hrec₂⟩ := snapshots_adm es₂ initial r₂ hr₂
  obtain ⟨δ, hδ⟩ : ∃ δ, initial.cfg.delta = δ := ⟨_, rfl⟩
  rw [hδ] at h2
  obtain ⟨m1, mo1, bd1, sh1⟩ := adm_props hadm₁
  obtain ⟨m2, mo2, bd2, sh2⟩ := adm_props hadm₂
  rw [hδ] at sh1 sh2
  have hsp₁ := List.takeWhile_append_dropWhile (p := fun p : Pair => decide (p.1.time ≤ τ - δ)) (l := ps₁)
  have hsp₂ := List.takeWhile_append_dropWhile (p := fun p : Pair => decide (p.1.time ≤ τ - δ)) (l := ps₂)
  have hA₁ : ∀ p ∈ ps₁.takeWhile (fun p => decide (p.1.time ≤ τ - δ)), p.1.time ≤ τ - δ := fun p hp => by
    simpa using List.all_eq_true.1 List.all_takeWhile _ hp
  have hA₂ : ∀ p ∈ ps₂.takeWhile (fun p => decide (p.1.time ≤ τ - δ)), p.1.time ≤ τ - δ := fun p hp => by
    simpa using List.all_eq_true.1 List.all_takeWhile _ hp
  have hB₁ := dropWhile_gt (τ - δ) ps₁ mo1
  have hB₂ := dropWhile_gt (τ - δ) ps₂ mo2
  generalize ps₁.takeWhile (fun p => decide (p.1.time ≤ τ - δ)) = PA₁ at hsp₁ hA₁
  generalize ps₁.dropWhile (fun p => decide (p.1.time ≤ τ - δ)) = PB₁ at hsp₁ hB₁
  generalize ps₂.takeWhile (fun p => decide (p.1.time ≤ τ - δ)) = PA₂ at hsp₂ hA₂
  generalize ps₂.dropWhile (fun p => decide (p.1.time ≤ τ - δ)) = PB₂ at hsp₂ hB₂
  subst hsp₁ hsp₂
  have e1 := events_split (τ - δ) PA₁ PB₁ hA₁ hB₁
  have e2 := events_split (τ - δ) PA₂ PB₂ hA₂ hB₂
  rw [he₁] at e1
  rw [he₂] at e2
  have hPA : PA₁.map Prod.fst = PA₂.map Prod.fst := by rw [← e1, ← e2, h2]
  obtain ⟨hadA₁, hadB₁⟩ := adm_split hadm₁
  obtain ⟨hadA₂, hadB₂⟩ := adm_split hadm₂
  have hPAeq : PA₁ = PA₂ := adm_det hadA₁ hadA₂ hPA
  subst hPAeq
  have hrec1 : r₁ = (runP initial PA₁).2 ++ recsPairs (runP initial PA₁).1 PB₁ := by
    rw [← hrec₁, recsPairs_append]
  have hrec2 : r₂ = (runP initial PA₁).2 ++ recsPairs (runP initial PA₁).1 PB₂ := by
    rw [← hrec₂, recsPairs_append]
  have hcfgA : (runP initial PA₁).1.cfg = initial.cfg := runP_cfg _ _
  have hokA : TickOk (runP initial PA₁).1 := fun ms hm => hok ms (by rw [← hcfgA]; exact hm)
  have hclkA : Clocked (runP initial PA₁).1 := by
    obtain ⟨ms, h⟩ := hclk; exact ⟨ms, by rw [hcfgA]; exact h⟩
  have hsortA := runP_sorted PA₁ initial hsort
  have hδA : (runP initial PA₁).1.cfg.delta = δ := by rw [hcfgA]; exact hδ
  have hmB₁ : Mono PB₁ := (List.pairwise_append.1 mo1).2.1
  have hmB₂ : Mono PB₂ := (List.pairwise_append.1 mo2).2.1
  have hbd₁' : ∀ p ∈ PB₁, p.1.time < (runP initial PA₁).1.cfg.stop := fun p hp => by
    rw [hcfgA]; exact bd1 p (List.mem_append_right _ hp)
  have hbd₂' : ∀ p ∈ PB₂, p.1.time < (runP initial PA₁).1.cfg.stop := fun p hp => by
    rw [hcfgA]; exact bd2 p (List.mem_append_right _ hp)
  have f1 := recs_filterK τ δ PB₁ _ hδA hokA hclkA hsortA hB₁ hmB₁ hbd₁'
  have f2 := recs_filterK τ δ PB₂ _ hδA hokA hclkA hsortA hB₂ hmB₂ hbd₂'
  have hE : (PB₁.map Prod.fst).filter (fun e => decide (e.known ≤ τ)) =
      (PB₂.map Prod.fst).filter (fun e => decide (e.known ≤ τ)) := by
    rw [← he₁, ← he₂, List.map_append, List.map_append, List.filter_append, List.filter_append] at h1
    exact List.append_cancel_left h1
  have hK : PB₁.filter (fun p => decide (p.1.known ≤ τ)) = PB₂.filter (fun p => decide (p.1.known ≤ τ)) := by
    have hm1 : (PB₁.filter (fun p => decide (p.1.known ≤ τ))).map Prod.fst =
        (PB₁.map Prod.fst).filter (fun e => decide (e.known ≤ τ)) := by
      rw [List.filter_map]; rfl
    have hm2 : (PB₂.filter (fun p => decide (p.1.known ≤ τ))).map Prod.fst =
        (PB₂.map Prod.fst).filter (fun e => decide (e.known ≤ τ)) := by
      rw [List.filter_map]; rfl
    have plain : ∀ (PB : List Pair), (∀ p ∈ PB, τ - δ < p.1.time) →
        (∀ p ∈ PA₁ ++ PB, (isQTp p.1.payload = true → p.1.known = p.1.time + δ) ∧
          (isQTp p.1.payload = false → plainReading p.1 = some p.2)) →
        ∀ p ∈ PB.filter (fun p => decide (p.1.known ≤ τ)), plainReading p.1 = some p.2 := by
      intro PB hB hsh p hp
      obtain ⟨hpB, hk⟩ := List.mem_filter.1 hp
      have hk' : p.1.known ≤ τ := by simpa using hk
      obtain ⟨q1, q2⟩ := hsh p (List.mem_append_right _ hpB)
      cases hq : isQTp p.1.payload with
      | true => have := q1 hq; have := hB p hpB; omega
      | false => exact q2 hq
    exact pairs_eq_of_plain _ _ (by rw [hm1, hm2, hE]) (plain PB₁ hB₁ sh1) (plain PB₂ hB₂ sh2)
  rw [hrec1, hrec2, List.filter_append, List.filter_append, f1, f2, hK]

end Engine.Machine
