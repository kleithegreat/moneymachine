import Engine.DeliveryWorld
import Engine.Start
import Engine.StartProofs

/-!
# L1a: delivery (kernel-v2.md B3; briefs/3-kernel-v2.md step 7)

Two markets that agree on the events known by `τ` and on the events with `time ≤ τ - δ` give equal ticks through `τ`.
The proof follows the brief's five lemmas, each about the fold without admission (`advanceRec`), which an admitted
run equals (`snapshots_adm`):

1. An admitted stream's times never fall (`adm_props`), so the events with `time ≤ τ - δ` are a prefix both markets
   share (`adm_det`) and the rest a tail.
2. In the tail an event known by `τ` is no quote and no print (`adm_props`), so its reading is a function of the event
   alone (`plainReading`).
3. `Agree` is the part of a state ticks through `τ` can read: the view's side, the effects the world has made that the
   view takes by `τ`, and the world a wish's arrival reads, until the first event of the tail (`WorldEq`) or once no
   wish arrives by `τ - δ` (`Late`).
4. Ticks (`stepTick_agree`), the wishes that arrive (`drain_agree`) and one event applied to both (`after_agree`)
   keep two states in `Agree`; an event not known by `τ` keeps a state in `Agree` with itself (`after_self`).
5. The clock to a bound and then to a later one is the clock to the later (`Engine.Clock`), so an event not known by
   `τ` changes no record through `τ` (`recs_filterK`) and the tail's run equals that of its events known by `τ`.
-/

namespace Engine.Machine

open Engine.Orders (Wish)

/-! ### Events -/

def after (s : State) (e : Event) (r : Reading) : State :=
  let (s2, row) := applyPayload s e r
  let s3 := pushHistory s2 e.time
  let own := match r with
    | .listing _ => 0
    | _ => if row.isEmpty then 0 else 1
  { s3 with count := s3.count + 1, previous := some e, ids := newIds s e, traceLines := s3.traceLines + own }

theorem advanceRec_state (s : State) (e : Event) (r : Reading) :
    (advanceRec s e r).1 = after (settleR s e.time).1 e r := by
  unfold advanceRec
  have h := (settle_eq s e.time Rows.empty).1
  generalize settle s e.time Rows.empty = x at h
  obtain ⟨s1, ticks, records⟩ := x
  simp only [] at h
  rw [h]
  rfl

theorem advanceRec_recs (s : State) (e : Event) (r : Reading) :
    (advanceRec s e r).2.2 = (settleR s e.time).2 := by
  unfold advanceRec
  have h := (settle_eq s e.time Rows.empty).2
  generalize settle s e.time Rows.empty = x at h
  obtain ⟨s1, ticks, records⟩ := x
  simp only [] at h
  rw [h]

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
  y.2 ++ (settleR y.1 y.1.cfg.stop).2

theorem recsPairs_nil (s : State) : recsPairs s [] = (settleR s s.cfg.stop).2 := by
  simp [recsPairs, runP]

theorem recsPairs_cons (s : State) (p : Pair) (rest : List Pair) :
    recsPairs s (p :: rest) = (settleR s p.1.time).2 ++ recsPairs (after (settleR s p.1.time).1 p.1 p.2) rest := by
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
  simpa [pushHistory_cfg] using this

/-- Settling to an earlier bound first changes no record: the later settling takes up where it left off. -/
theorem recsPairs_settle (s : State) (hms : ∀ ms, s.cfg.tickMs = some ms → 0 < ms) (b : Int) :
    ∀ (ps : List Pair), (match ps with | [] => b ≤ s.cfg.stop | p :: _ => b ≤ p.1.time) →
      recsPairs s ps = (settleR s b).2 ++ recsPairs (settleR s b).1 ps := by
  intro ps hb
  have hcfg := settleR_cfg s b
  cases ps with
  | nil =>
    rw [recsPairs_nil, recsPairs_nil, settleR_split s b s.cfg.stop hb hms, hcfg]
  | cons p rest =>
    rw [recsPairs_cons, recsPairs_cons, settleR_split s b p.1.time hb hms]
    simp

/-! ### What two markets share at `τ` -/

def PendSorted (s : State) : Prop := s.pending.Pairwise (fun p q => p.known ≤ q.known)

def knownBy (τ : Int) (p : Pending) : Bool := decide (p.known ≤ τ)

def effKnownBy (τ : Int) (l : Logged) : Bool := decide (l.known ≤ τ)

def quotesBy (m : Int) (c : CoinState) : List Int := c.quotes.filter (fun q => decide (q ≤ m))

/-- The wishes wait in the order they arrive, none later than the next tick's by more than the order's delay. -/
def WishInv (s : State) : Prop :=
  s.wishes.Pairwise (fun a b => a.arrives ≤ b.arrives) ∧
    ∀ t, s.nextTick = some t → ∀ w ∈ s.wishes, w.arrives ≤ t + s.cfg.lambda

/-- No wish arrives by `τ - δ`, and none will be sent that does: the effects of what comes are not known by `τ`. -/
def Late (τ : Int) (s : State) : Prop :=
  (∀ w ∈ s.wishes, τ - s.cfg.delta < w.arrives) ∧ ∀ t ms, s.nextTick = some t → s.cfg.tickMs = some ms → τ - s.cfg.delta < t

/-- The part of a state the clock reads, as far as ticks through `τ` can see it (A3, A18; L1a). -/
structure Agree (τ : Int) (s u : State) : Prop where
  cfg : s.cfg = u.cfg
  prog : s.prog = u.prog
  next : s.nextTick = u.nextTick
  view : s.view = u.view
  mach : s.mach = u.mach
  vacct : s.vacct = u.vacct
  vage : s.vage = u.vage
  wishes : s.wishes = u.wishes
  sortedL : PendSorted s
  sortedR : PendSorted u
  inv : WishInv s
  pending : s.pending.filter (knownBy τ) = u.pending.filter (knownBy τ)
  effects : s.veffects.filter (effKnownBy τ) = u.veffects.filter (effKnownBy τ)
  quotes : s.coins.map (quotesBy (τ - s.cfg.delta)) = u.coins.map (quotesBy (τ - s.cfg.delta))
  world : WorldEq s u ∨ Late τ s

def Dead (τ : Int) (s : State) : Prop := ∀ t, s.nextTick = some t → τ < t

def Good (τ : Int) (s u : State) : Prop := Agree τ s u ∨ (Dead τ s ∧ Dead τ u)

/-- A header a run can start from: a step of the clock that is positive and an order delay that is not negative. -/
def Setup (s : State) : Prop := (∀ ms, s.cfg.tickMs = some ms → 0 < ms) ∧ 0 ≤ s.cfg.lambda

theorem Setup.of_cfg {s u : State} (h : Setup s) (hc : u.cfg = s.cfg) : Setup u := by
  unfold Setup at h ⊢
  rw [hc]; exact h

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

theorem filter_via {α : Type} (P Q : α → Bool) (hP : ∀ a, P a = true → Q a = true) (l l' : List α)
    (h : l.filter Q = l'.filter Q) : l.filter P = l'.filter P := by
  have e : ∀ m : List α, m.filter P = (m.filter Q).filter P := by
    intro m
    rw [List.filter_filter]
    apply List.filter_congr
    intro a _
    cases hpa : P a
    · simp
    · simp [hP a hpa]
  rw [e l, e l', h]

theorem release_agree (τ t : Int) {s u : State} (h : Agree τ s u) (ht : t ≤ τ) :
    Agree τ (release s t) (release u t) := by
  have hs := span_sorted t s.pending h.sortedL
  have hu := span_sorted t u.pending h.sortedR
  have hready : s.pending.filter (fun p => decide (p.known ≤ t)) = u.pending.filter (fun p => decide (p.known ≤ t)) :=
    filter_via _ (knownBy τ) (fun p hp => by simp only [knownBy, decide_eq_true_eq] at hp ⊢; omega) _ _ h.pending
  unfold release
  simp only [hs, hu]
  refine ⟨h.cfg, h.prog, h.next, ?_, h.mach, h.vacct, h.vage, h.wishes, ?_, ?_, h.inv, ?_, h.effects, h.quotes, h.world⟩
  · simp only [hready, h.view, h.cfg]
  · exact h.sortedL.filter _
  · exact h.sortedR.filter _
  · simp only [List.filter_filter]
    exact filter_via _ (knownBy τ) (fun p hp => by simp only [Bool.and_eq_true] at hp; exact hp.1) _ _ h.pending

theorem releaseEffects_agree (τ t : Int) {s u : State} (h : Agree τ s u) (ht : t ≤ τ) :
    Agree τ (releaseEffects s t) (releaseEffects u t) := by
  have hready : s.veffects.filter (fun l => decide (l.known ≤ t)) = u.veffects.filter (fun l => decide (l.known ≤ t)) :=
    filter_via _ (effKnownBy τ) (fun p hp => by simp only [effKnownBy, decide_eq_true_eq] at hp ⊢; omega) _ _ h.effects
  have hlater : (s.veffects.filter (fun l => !decide (l.known ≤ t))).filter (effKnownBy τ) =
      (u.veffects.filter (fun l => !decide (l.known ≤ t))).filter (effKnownBy τ) := by
    simp only [List.filter_filter]
    exact filter_via _ (effKnownBy τ) (fun p hp => by simp only [Bool.and_eq_true] at hp; exact hp.1) _ _ h.effects
  unfold releaseEffects
  refine ⟨h.cfg, h.prog, h.next, h.view, h.mach, ?_, h.vage, h.wishes, h.sortedL, h.sortedR, h.inv, h.pending, hlater,
    h.quotes, h.world⟩
  · simp only [hready, h.vacct, h.cfg]

theorem aged_agree (τ : Int) {s u : State} (h : Agree τ s u) : Agree τ (aged s) (aged u) := by
  have hlen : s.coins.length = u.coins.length := by
    have := congrArg List.length h.quotes
    simpa using this
  unfold aged
  refine ⟨h.cfg, h.prog, h.next, h.view, h.mach, h.vacct, ?_, h.wishes, h.sortedL, h.sortedR, h.inv, h.pending, h.effects,
    h.quotes, h.world⟩
  · simp only [hlen, h.vacct, h.vage, h.mach]


/-! ### One tick -/

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

theorem tickCoin_worldCoin (cfg : Config) (time : Int) (c : CoinState) :
    worldCoin (tickCoin cfg time c).1 = worldCoin c := rfl

theorem freeMargin_rules (cfg : Config) (r r' : List Rules) (ended : List Nat) (p : Option Engine.Lang.Program)
    (a : Engine.World.Acct) (marks : List Rat) (time : Int) :
    (buildBook cfg r ended p a marks time).freeMargin = (buildBook cfg r' ended p a marks time).freeMargin := rfl

theorem exactIn_congr (s u : State) (hc : s.cfg = u.cfg) (hp : s.prog = u.prog) (hv : s.view = u.view)
    (ha : s.vacct = u.vacct) (hg : s.vage = u.vage) (hm : s.mach = u.mach) (time : Int) (c : Nat) (stale : Bool)
    (name : String) (slot : Option Nat) : exactIn s time c stale name slot = exactIn u time c stale name slot := by
  unfold exactIn ownInput exactInput viewBook viewCoinAt
  simp only [hc, hp, hv, ha, hg, hm]
  simp only [freeMargin_rules _ s.rules u.rules]

theorem sourceValue_congr (s u : State) (hc : s.cfg = u.cfg) (hv : s.view = u.view) :
    sourceValue s = sourceValue u := by
  funext c name
  unfold sourceValue
  rw [hc, hv]

theorem coinName_congr (s u : State) (hc : s.cfg = u.cfg) (c : Nat) : coinName s c = coinName u c := by
  unfold coinName; rw [hc]

theorem tickBody_acct (s : State) (t : Int) : (tickBody s t).1.acct = s.acct := by simp only [tickBody, withLog]
theorem tickBody_rules (s : State) (t : Int) : (tickBody s t).1.rules = s.rules := by simp only [tickBody, withLog]
theorem tickBody_ended (s : State) (t : Int) : (tickBody s t).1.ended = s.ended := by simp only [tickBody, withLog]
theorem tickBody_prog (s : State) (t : Int) : (tickBody s t).1.prog = s.prog := by simp only [tickBody, withLog]
theorem tickBody_nextTick (s : State) (t : Int) : (tickBody s t).1.nextTick = s.nextTick := by simp only [tickBody, withLog]
theorem tickBody_vacct (s : State) (t : Int) : (tickBody s t).1.vacct = s.vacct := by simp only [tickBody, withLog]
theorem tickBody_veffects (s : State) (t : Int) : (tickBody s t).1.veffects = s.veffects := by simp only [tickBody, withLog]
theorem tickBody_pending (s : State) (t : Int) : (tickBody s t).1.pending = s.pending := by simp only [tickBody, withLog]
theorem tickBody_vage (s : State) (t : Int) : (tickBody s t).1.vage = s.vage := by simp only [tickBody, withLog]
theorem tickBody_view (s : State) (t : Int) : (tickBody s t).1.view = s.view.map clearInterval := by
  simp only [tickBody, withLog]
theorem tickBody_wishes (s : State) (t : Int) :
    (tickBody s t).1.wishes = s.wishes ++ orderWishes (tickBody s t).2.2.wishes := by simp only [tickBody, withLog]
theorem tickBody_coins (s : State) (t : Int) :
    (tickBody s t).1.coins = (s.coins.map (tickCoin s.cfg t)).map (·.1) := by simp only [tickBody, withLog]

theorem mem_of_ite_nil {α : Type} {c : Prop} [Decidable c] {l : List α} {x : α} (h : x ∈ (if c then l else [])) :
    x ∈ l := by
  by_cases hc : c <;> simp_all

theorem tickBody_sent_arrives (s : State) (t : Int) : ∀ w ∈ (tickBody s t).2.2.wishes, w.arrives = t + s.cfg.lambda := by
  intro w hw
  simp only [tickBody] at hw
  split at hw
  · have hw' := mem_of_ite_nil hw
    simp only [List.mem_map] at hw'
    obtain ⟨x, _, rfl⟩ := hw'
    rfl
  · simp at hw

theorem tickBody_inputs (τ time : Int) {s u : State} (h : Agree τ s u) (ht : time ≤ τ) :
    (tickBody s time).1.mach = (tickBody u time).1.mach ∧ (tickBody s time).2.2 = (tickBody u time).2.2 := by
  have hlen : s.coins.length = u.coins.length := by
    have := congrArg List.length h.quotes
    simpa using this
  have hm : time - s.cfg.delta ≤ τ - s.cfg.delta := by omega
  have hsv := sourceValue_congr s u h.cfg h.view
  have hex := exactIn_congr s u h.cfg h.prog h.view h.vacct h.vage h.mach
  have hcn := coinName_congr s u h.cfg
  have hmark : ∀ c : Nat, viewMarkAt s.cfg time s.coins c = viewMarkAt s.cfg time u.coins c := by
    intro c
    unfold viewMarkAt
    have hq := congrArg (fun l => l[c]?) h.quotes
    simp only [List.getElem?_map] at hq ⊢
    cases hx : s.coins[c]? <;> cases hy : u.coins[c]? <;> simp only [hx, hy, Option.map_none, Option.map_some] at hq ⊢
    all_goals first
      | rfl
      | (exfalso; simp at hq; done)
      | (simp at hq; exact tickCoin_view s.cfg time (τ - s.cfg.delta) hm _ _ hq)
  constructor
  · simp only [tickBody, withLog]
    simp only [hsv, hex, hmark, ← h.cfg, ← h.prog, ← h.view, ← h.mach]
  · simp only [tickBody]
    simp only [hsv, hex, hcn, hmark, ← h.cfg, ← h.prog, ← h.view, ← h.mach, ← h.vacct, hlen]

theorem mem_orderWishes (l : List Wish) (x : Wish) : x ∈ orderWishes l ↔ x ∈ l := by
  unfold orderWishes
  exact List.mem_mergeSort

theorem pairwise_arrives (l : List Wish) (a : Int) (h : ∀ w ∈ l, w.arrives = a) :
    l.Pairwise (fun x y => x.arrives ≤ y.arrives) := by
  induction l with
  | nil => exact List.Pairwise.nil
  | cons x rest ih =>
    refine List.Pairwise.cons ?_ (ih fun w hw => h w (List.mem_cons_of_mem _ hw))
    intro y hy
    rw [h x (List.mem_cons_self ..), h y (List.mem_cons_of_mem _ hy)]
    exact Int.le_refl _

/-- A tick at `time ≤ τ` from two agreeing states, taken at the next tick's time, gives agreeing states and one record. -/
theorem tickBody_agree (τ time ms : Int) {s u : State} (h : Agree τ s u) (ht : time ≤ τ) (hn : s.nextTick = some time)
    (hS : Setup s) (hm' : s.cfg.tickMs = some ms) : Agree τ (tickBody s time).1 (tickBody u time).1 ∧ (tickBody s time).2.2 = (tickBody u time).2.2 := by
  obtain ⟨hmach, hrec⟩ := tickBody_inputs τ time h ht
  have hm : time - s.cfg.delta ≤ τ - s.cfg.delta := by omega
  have hsent : ∀ w ∈ orderWishes (tickBody s time).2.2.wishes, w.arrives = time + s.cfg.lambda :=
    fun w hw => tickBody_sent_arrives s time w ((mem_orderWishes _ w).1 hw)
  have hwish : (tickBody s time).1.wishes = s.wishes ++ orderWishes (tickBody s time).2.2.wishes := tickBody_wishes s time
  refine ⟨⟨?_, ?_, ?_, ?_, hmach, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩, hrec⟩
  · rw [tickBody_cfg, tickBody_cfg]; exact h.cfg
  · rw [tickBody_prog, tickBody_prog]; exact h.prog
  · rw [tickBody_nextTick, tickBody_nextTick]; exact h.next
  · rw [tickBody_view, tickBody_view, h.view]
  · rw [tickBody_vacct, tickBody_vacct]; exact h.vacct
  · rw [tickBody_vage, tickBody_vage]; exact h.vage
  · rw [tickBody_wishes s time, tickBody_wishes u time, ← hrec, h.wishes]
  · unfold PendSorted; rw [tickBody_pending]; exact h.sortedL
  · unfold PendSorted; rw [tickBody_pending]; exact h.sortedR
  · refine ⟨?_, ?_⟩
    · rw [hwish]
      refine List.pairwise_append.2 ⟨h.inv.1, pairwise_arrives _ _ hsent, ?_⟩
      intro a ha b hb
      have h1 := h.inv.2 time hn a ha
      rw [hsent b hb]
      exact h1
    · intro t' ht' w hw
      rw [tickBody_nextTick, hn] at ht'
      obtain rfl := Option.some.inj ht'
      rw [tickBody_cfg]
      rw [hwish] at hw
      rcases List.mem_append.1 hw with hw | hw
      · exact h.inv.2 time hn w hw
      · rw [hsent w hw]; exact Int.le_refl _
  · rw [tickBody_pending, tickBody_pending]; exact h.pending
  · rw [tickBody_veffects, tickBody_veffects]; exact h.effects
  · rw [tickBody_coins, tickBody_coins, tickBody_cfg, ← h.cfg]
    simp only [List.map_map, Function.comp_def]
    exact map_eq_of_map_eq (quotesBy (τ - s.cfg.delta)) _
      (fun a b hab => tickCoin_quotes s.cfg time _ hm a b hab) _ _ h.quotes
  · rcases h.world with hw | hl
    · left
      refine ⟨?_, ?_, ?_, ?_⟩
      · rw [tickBody_acct, tickBody_acct]; exact hw.acct
      · rw [tickBody_rules, tickBody_rules]; exact hw.rules
      · rw [tickBody_ended, tickBody_ended]; exact hw.ended
      · rw [tickBody_coins, tickBody_coins]
        simp only [List.map_map]
        have e : worldCoin ∘ (fun c : CoinState × String × Bool × Bool => c.1) ∘ tickCoin s.cfg time = worldCoin := rfl
        have e' : worldCoin ∘ (fun c : CoinState × String × Bool × Bool => c.1) ∘ tickCoin u.cfg time = worldCoin := rfl
        rw [e, e']; exact hw.coins
    · right
      refine ⟨?_, ?_⟩
      · intro w hw
        rw [tickBody_cfg]
        rw [hwish] at hw
        rcases List.mem_append.1 hw with hw | hw
        · have := hl.1 w hw; exact this
        · rw [hsent w hw]
          have := hl.2 time ms hn hm'
          have := hS.2
          omega
      · intro t' ms' ht' hm''
        rw [tickBody_nextTick] at ht'
        rw [tickBody_cfg] at hm'' ⊢
        exact hl.2 t' ms' ht' hm''

/-! ### The wishes that arrive -/

theorem dropWhile_ge (b : Int) : ∀ l : List Wish, l.Pairwise (fun x y => x.arrives ≤ y.arrives) →
    ∀ w ∈ l.dropWhile (fun w => decide (w.arrives < b)), b ≤ w.arrives := by
  intro l
  induction l with
  | nil => intro _ w hw; simp at hw
  | cons x rest ih =>
    intro hp w hw
    have hp' := List.pairwise_cons.1 hp
    by_cases hx : x.arrives < b
    · simp only [List.dropWhile_cons, hx, decide_true] at hw
      exact ih hp'.2 w hw
    · simp only [List.dropWhile_cons, hx, decide_false] at hw
      rcases List.mem_cons.1 hw with rfl | hw
      · omega
      · have := hp'.1 w hw; omega

theorem drain_agree (τ b : Int) {s u : State} (h : Agree τ s u) : Agree τ (drain s b).1 (drain u b).1 := by
  have fs := drain_frame_wishes s b
  have fu := drain_frame_wishes u b
  have hws : (drain s b).1.wishes = s.wishes.dropWhile (fun w => decide (w.arrives < b)) := drain_wishes s b
  have hwu : (drain u b).1.wishes = u.wishes.dropWhile (fun w => decide (w.arrives < b)) := drain_wishes u b
  have hsub : (s.wishes.dropWhile (fun w => decide (w.arrives < b))).Sublist s.wishes := List.dropWhile_sublist _
  have hcfg : (drain s b).1.cfg = s.cfg := fs.cfg
  have hnext : (drain s b).1.nextTick = s.nextTick := fs.nextTick
  have hinv : WishInv (drain s b).1 := by
    refine ⟨?_, ?_⟩
    · rw [hws]; exact h.inv.1.sublist hsub
    · intro t ht w hw
      rw [hnext] at ht
      rw [hws] at hw
      rw [hcfg]
      exact h.inv.2 t ht w (hsub.subset hw)
  have hq : (drain s b).1.coins.map (quotesBy (τ - (drain s b).1.cfg.delta)) =
      (drain u b).1.coins.map (quotesBy (τ - (drain s b).1.cfg.delta)) := by
    rw [fs.coins, fu.coins, hcfg]; exact h.quotes
  rcases h.world with hw | hl
  · obtain ⟨hw', L, e1, e2⟩ := drain_worldEq s u hw h.cfg h.prog h.wishes b
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, hinv, ?_, ?_, hq, Or.inl hw'⟩
    · rw [fs.cfg, fu.cfg]; exact h.cfg
    · rw [fs.prog, fu.prog]; exact h.prog
    · rw [fs.nextTick, fu.nextTick]; exact h.next
    · rw [fs.view, fu.view]; exact h.view
    · rw [fs.mach, fu.mach]; exact h.mach
    · rw [fs.vacct, fu.vacct]; exact h.vacct
    · rw [fs.vage, fu.vage]; exact h.vage
    · rw [hws, hwu, h.wishes]
    · unfold PendSorted; rw [fs.pending]; exact h.sortedL
    · unfold PendSorted; rw [fu.pending]; exact h.sortedR
    · rw [fs.pending, fu.pending]; exact h.pending
    · rw [e1, e2, List.filter_append, List.filter_append, h.effects]
  · have hP : ∀ w ∈ s.wishes, τ - s.cfg.delta < w.arrives := hl.1
    obtain ⟨Ls, e1, k1⟩ := drain_known (fun a => τ - s.cfg.delta < a) s b hP
    obtain ⟨Lu, e2, k2⟩ := drain_known (fun a => τ - s.cfg.delta < a) u b (fun w hw => hP w (by rw [h.wishes]; exact hw))
    have hLs : Ls.filter (effKnownBy τ) = [] := by
      rw [List.filter_eq_nil_iff]
      intro x hx
      obtain ⟨a, ha, hk⟩ := k1 x hx
      simp only [effKnownBy, decide_eq_true_eq]; omega
    have hLu : Lu.filter (effKnownBy τ) = [] := by
      rw [List.filter_eq_nil_iff]
      intro x hx
      obtain ⟨a, ha, hk⟩ := k2 x hx
      rw [← h.cfg] at hk
      simp only [effKnownBy, decide_eq_true_eq]; omega
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, hinv, ?_, ?_, hq, Or.inr ?_⟩
    · rw [fs.cfg, fu.cfg]; exact h.cfg
    · rw [fs.prog, fu.prog]; exact h.prog
    · rw [fs.nextTick, fu.nextTick]; exact h.next
    · rw [fs.view, fu.view]; exact h.view
    · rw [fs.mach, fu.mach]; exact h.mach
    · rw [fs.vacct, fu.vacct]; exact h.vacct
    · rw [fs.vage, fu.vage]; exact h.vage
    · rw [hws, hwu, h.wishes]
    · unfold PendSorted; rw [fs.pending]; exact h.sortedL
    · unfold PendSorted; rw [fu.pending]; exact h.sortedR
    · rw [fs.pending, fu.pending]; exact h.pending
    · rw [e1, e2, List.filter_append, List.filter_append, hLs, hLu]; simpa using h.effects
    · refine ⟨?_, ?_⟩
      · intro w hw
        rw [hws] at hw
        rw [hcfg]
        exact hl.1 w (hsub.subset hw)
      · intro t ms ht hm
        rw [hnext] at ht
        rw [hcfg] at hm ⊢
        exact hl.2 t ms ht hm

/-! ### Ticks and the clock -/

theorem Agree.setNext {τ : Int} {s u : State} (h : Agree τ s u) (t ms : Int) (hn : s.nextTick = some t) (hms : 0 ≤ ms) :
    Agree τ { s with nextTick := some (t + ms) } { u with nextTick := some (t + ms) } := by
  have hu : u.nextTick = some t := by rw [← h.next]; exact hn
  refine ⟨h.cfg, h.prog, rfl, h.view, h.mach, h.vacct, h.vage, h.wishes, h.sortedL, h.sortedR, ?_, h.pending, h.effects,
    h.quotes, ?_⟩
  · refine ⟨h.inv.1, ?_⟩
    intro t' ht' w hw
    obtain rfl : t + ms = t' := Option.some.inj ht'
    have := h.inv.2 t hn w hw
    show w.arrives ≤ t + ms + s.cfg.lambda
    omega
  · rcases h.world with hw | hl
    · exact Or.inl hw
    · right
      refine ⟨hl.1, ?_⟩
      intro t' ms' ht' hm'
      obtain rfl : t + ms = t' := Option.some.inj ht'
      have := hl.2 t ms' hn hm'
      show τ - s.cfg.delta < t + ms
      omega

theorem stepTick_time (s : State) (time ms : Int) : (stepTick s time ms).2.time = time := rfl

theorem stepTick_nextTick (s : State) (time ms : Int) : (stepTick s time ms).1.nextTick = some (time + ms) := rfl

theorem stepTick_agree (τ time ms : Int) {s u : State} (h : Agree τ s u) (ht : time ≤ τ) (hn : s.nextTick = some time)
    (hS : Setup s) (hm : s.cfg.tickMs = some ms) :
    Agree τ (stepTick s time ms).1 (stepTick u time ms).1 ∧ (stepTick s time ms).2 = (stepTick u time ms).2 := by
  have h1 := drain_agree τ time h
  have h2 := release_agree τ time h1 ht
  have h3 := releaseEffects_agree τ time h2 ht
  have h4 := aged_agree τ h3
  have hn' : (aged (releaseEffects (release (drain s time).1 time) time)).nextTick = some time := by
    show (drain s time).1.nextTick = some time
    rw [drain_nextTick]; exact hn
  have hS' : Setup (aged (releaseEffects (release (drain s time).1 time) time)) := by
    refine Setup.of_cfg hS ?_
    show (drain s time).1.cfg = s.cfg
    exact drain_cfg s time
  have hm2 : (aged (releaseEffects (release (drain s time).1 time) time)).cfg.tickMs = some ms := by
    show (drain s time).1.cfg.tickMs = some ms
    rw [drain_cfg]; exact hm
  obtain ⟨h5, h6⟩ := tickBody_agree τ time ms h4 ht hn' hS' hm2
  have hn'' : (tickBody (aged (releaseEffects (release (drain s time).1 time) time)) time).1.nextTick = some time := by
    rw [tickBody_nextTick]; exact hn'
  have hms : 0 ≤ ms := Int.le_of_lt (hS.1 ms hm)
  refine ⟨?_, ?_⟩
  · unfold stepTick tickAt
    exact h5.setNext time ms hn'' hms
  · unfold stepTick tickAt
    exact h6

theorem fireR_dead (τ : Int) (n : Nat) : ∀ s : State, Setup s → Dead τ s →
    Dead τ (fireR n s).1 ∧ ∀ r ∈ (fireR n s).2, τ < r.time := by
  induction n with
  | zero => intro s _ h; simp [fireR_zero, h]
  | succ n ih =>
    intro s hS hd
    cases hn : s.nextTick with
    | none => rw [fireR_stuck _ s (Or.inl hn)]; exact ⟨hd, by simp⟩
    | some t =>
      cases ht : s.cfg.tickMs with
      | none => rw [fireR_stuck _ s (Or.inr ht)]; exact ⟨hd, by simp⟩
      | some ms =>
        have hms : 0 < ms := hS.1 ms ht
        have htau := hd t hn
        rw [fireR_succ_some n s t ms hn ht]
        have hS' : Setup (stepTick s t ms).1 := Setup.of_cfg hS (stepTick_cfg s t ms)
        have hd' : Dead τ (stepTick s t ms).1 := by
          intro x hx
          rw [stepTick_nextTick] at hx
          obtain rfl : t + ms = x := Option.some.inj hx
          omega
        obtain ⟨h1, h2⟩ := ih _ hS' hd'
        refine ⟨h1, ?_⟩
        intro r hr
        simp only [List.mem_cons] at hr
        rcases hr with rfl | hr
        · rw [stepTick_time]; exact htau
        · exact h2 r hr

theorem fireR_agree (τ : Int) (n : Nat) : ∀ s u : State, Setup s → Agree τ s u →
    Good τ (fireR n s).1 (fireR n u).1 ∧
      (fireR n s).2.filter (fun r => decide (r.time ≤ τ)) = (fireR n u).2.filter (fun r => decide (r.time ≤ τ)) := by
  induction n with
  | zero => intro s u _ h; simp [fireR_zero, Good, h]
  | succ n ih =>
    intro s u hS h
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
        have hms : 0 < ms := hS.1 ms ht
        rw [fireR_succ_some n s t ms hn ht, fireR_succ_some n u t ms hn' ht']
        by_cases htau : t ≤ τ
        · obtain ⟨ha, hr⟩ := stepTick_agree τ t ms h htau hn hS ht
          have hS' : Setup (stepTick s t ms).1 := Setup.of_cfg hS (stepTick_cfg s t ms)
          obtain ⟨h1, h2⟩ := ih _ _ hS' ha
          refine ⟨h1, ?_⟩
          simp only [List.filter_cons, hr, stepTick_time, htau, decide_true, ite_true, h2]
        · have hdead : ∀ v : State, v.cfg = s.cfg → Dead τ (stepTick v t ms).1 := by
            intro v _ x hx
            rw [stepTick_nextTick] at hx
            obtain rfl : t + ms = x := Option.some.inj hx
            omega
          have hSv : ∀ v : State, v.cfg = s.cfg → Setup (stepTick v t ms).1 := fun v hv =>
            Setup.of_cfg hS (by rw [stepTick_cfg, hv])
          obtain ⟨d1, d2⟩ := fireR_dead τ n _ (hSv s rfl) (hdead s rfl)
          obtain ⟨e1, e2⟩ := fireR_dead τ n _ (hSv u h.cfg.symm) (hdead u h.cfg.symm)
          refine ⟨Or.inr ⟨d1, e1⟩, ?_⟩
          have hs0 : (fireR n (stepTick s t ms).1).2.filter (fun r => decide (r.time ≤ τ)) = [] := by
            rw [List.filter_eq_nil_iff]; intro r hr; have := d2 r hr; simp; omega
          have hu0 : (fireR n (stepTick u t ms).1).2.filter (fun r => decide (r.time ≤ τ)) = [] := by
            rw [List.filter_eq_nil_iff]; intro r hr; have := e2 r hr; simp; omega
          simp [stepTick_time, htau, hs0, hu0]

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

/-- What an event leaves alone: the clock, the view's side and the wishes. -/
structure Keeps (s t : State) : Prop where
  cfg : t.cfg = s.cfg
  nextTick : t.nextTick = s.nextTick
  prog : t.prog = s.prog
  view : t.view = s.view
  mach : t.mach = s.mach
  vacct : t.vacct = s.vacct
  vage : t.vage = s.vage
  wishes : t.wishes = s.wishes

theorem Keeps.refl (s : State) : Keeps s s := ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

theorem Keeps.trans {s t u : State} (h : Keeps s t) (h' : Keeps t u) : Keeps s u :=
  ⟨by rw [h'.cfg, h.cfg], by rw [h'.nextTick, h.nextTick], by rw [h'.prog, h.prog], by rw [h'.view, h.view],
   by rw [h'.mach, h.mach], by rw [h'.vacct, h.vacct], by rw [h'.vage, h.vage], by rw [h'.wishes, h.wishes]⟩

theorem Frame.keeps {s t : State} (h : Frame s t) : Keeps s t :=
  ⟨h.cfg, h.nextTick, h.prog, h.view, h.mach, h.vacct, h.vage, h.wishes⟩

theorem applyPayload_keeps (s : State) (e : Event) (r : Reading) : Keeps s (applyPayload s e r).1 := by
  cases r with
  | listing rules =>
    simp only [applyPayload]
    exact Keeps.trans (t := { s with rules := setAt s.rules e.coin rules }) ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
      (emit_frame _ _ _).keeps
  | ending price => simp only [applyPayload, withPending]; split <;> exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  | funding hour rate oracle => simp only [applyPayload, withPending]; split <;> exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  | trade id price size sizeScale seller => simp only [applyPayload, withPending]; split <;> exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  | quote bid bidSize ask askSize sizeScale => simp only [applyPayload, withPending]; split <;> exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩
  | observation source bits => simp only [applyPayload, withPending]; split <;> exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

theorem after_keeps (s : State) (e : Event) (r : Reading) : Keeps s (after s e r) := by
  have := applyPayload_keeps s e r
  unfold after
  exact Keeps.trans this ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩


theorem setAt_map {α β : Type} (f : α → β) (l : List α) (i : Nat) (x : α) :
    (setAt l i x).map f = setAt (l.map f) i (f x) := by
  induction l generalizing i with
  | nil => simp [setAt]
  | cons y r ih =>
    cases i with
    | zero => simp [setAt]
    | succ i => simp [setAt, ih]

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

theorem after_pending (e : Event) (r : Reading) :
    ∃ o : Option PView, ∀ s : State, (after s e r).pending =
      (match o with
       | some w => if s.prog.isSome then insertPending ⟨e.coin, e.known, w⟩ s.pending else s.pending
       | none => s.pending) := by
  cases r with
  | listing rules =>
    refine ⟨none, fun s => ?_⟩
    simp only [after, applyPayload, pushHistory, withLog]
    exact (emit_frame _ _ _).pending
  | ending price =>
    refine ⟨some .ending, fun s => ?_⟩
    simp only [after, applyPayload, withPending, pushHistory, withLog]
    split <;> simp_all
  | funding hour rate oracle =>
    refine ⟨some (.funding (ofUnits 12 rate) (oracle.map (ofUnits 8))), fun s => ?_⟩
    simp only [after, applyPayload, withPending, pushHistory, withLog]
    split <;> simp_all
  | trade id price size sizeScale seller =>
    refine ⟨some (.trade (ofUnits 8 price) (ofUnits sizeScale size)), fun s => ?_⟩
    simp only [after, applyPayload, withPending, pushHistory, withLog]
    split <;> simp_all
  | quote bid bidSize ask askSize sizeScale =>
    refine ⟨some (.quote (ofUnits 8 bid) (ofUnits sizeScale bidSize) (ofUnits 8 ask) (ofUnits sizeScale askSize)), fun s => ?_⟩
    simp only [after, applyPayload, withPending, pushHistory, withLog]
    split <;> simp_all
  | observation source bits =>
    refine ⟨some (.observation source bits), fun s => ?_⟩
    simp only [after, applyPayload, withPending, pushHistory, withLog]
    split <;> simp_all

theorem after_coins (s : State) (e : Event) (r : Reading) (m : Int) (hc : ∃ ms, s.cfg.tickMs = some ms)
    (hm : m < e.time) : (after s e r).coins.map (quotesBy m) = s.coins.map (quotesBy m) := by
  have key : ∀ g : CoinState → CoinState, (∀ c, quotesBy m (g c) = quotesBy m c) →
      (setAt s.coins e.coin (g (getCoin s e.coin))).map (quotesBy m) = s.coins.map (quotesBy m) :=
    fun g hg => map_setAt_getD (quotesBy m) g hg CoinState.fresh s.coins e.coin
  obtain ⟨ms, hms⟩ := hc
  cases r with
  | listing rules =>
    simp only [after, applyPayload, pushHistory, withLog]
    rw [(emit_frame _ _ _).coins]
  | ending price =>
    simp only [after, applyPayload, withPending_coins, pushHistory, withLog]
    exact key (fun c => { c with price := some (ofUnits 8 price) }) (fun c => rfl)
  | funding hour rate oracle =>
    simp only [after, applyPayload, withPending_coins, pushHistory, withLog]
    exact key (fun c => { c with fundingHour := some hour }) (fun c => rfl)
  | trade id price size sizeScale seller =>
    simp only [after, applyPayload, withPending_coins, pushHistory, withLog]
    exact key (fun c => { c with price := some (ofUnits 8 price) }) (fun c => rfl)
  | quote bid bidSize ask askSize sizeScale =>
    simp only [after, applyPayload, withPending_coins, hms, Option.isSome_some, ite_true, pushHistory, withLog]
    refine key (fun c => { c with lastQuote := some e.time, quotes := e.time :: c.quotes, price := some (midPrice bid ask), bid := some (ofUnits 8 bid), ask := some (ofUnits 8 ask) }) ?_
    intro c
    simp [quotesBy, List.filter_cons]
    omega
  | observation source bits => simp [after, applyPayload, withPending_coins, pushHistory, withLog]

theorem emit_veffects_known (s : State) (t : Int) (es : List Engine.World.Effect) :
    ∃ L, (emit s t es).1.veffects = s.veffects ++ L ∧ ∀ x ∈ L, x.known = t + s.cfg.delta :=
  ⟨es.map (logged s.cfg t), emit_veffects s t es, fun x hx => by
    obtain ⟨_, _, rfl⟩ := List.mem_map.1 hx
    rfl⟩

theorem after_veffects (s : State) (e : Event) (r : Reading) :
    ∃ L, (after s e r).veffects = s.veffects ++ L ∧ ∀ x ∈ L, x.known = e.time + s.cfg.delta := by
  cases r with
  | listing rules =>
    obtain ⟨L, h1, h2⟩ := emit_veffects_known { s with rules := setAt s.rules e.coin rules } e.time
      (if (s.rules[e.coin]? != some rules) = true then
        (s.acct.orders.filter (·.coin == e.coin)).map fun o => World.Effect.cancelled o "rules" else [])
    exact ⟨L, by simpa only [after, applyPayload, pushHistory, withLog] using h1, h2⟩
  | ending price => exact ⟨[], by simp only [after, applyPayload, withPending, pushHistory, withLog]; split <;> simp, by simp⟩
  | funding hour rate oracle => exact ⟨[], by simp only [after, applyPayload, withPending, pushHistory, withLog]; split <;> simp, by simp⟩
  | trade id price size sizeScale seller => exact ⟨[], by simp only [after, applyPayload, withPending, pushHistory, withLog]; split <;> simp, by simp⟩
  | quote bid bidSize ask askSize sizeScale => exact ⟨[], by simp only [after, applyPayload, withPending, pushHistory, withLog]; split <;> simp, by simp⟩
  | observation source bits => exact ⟨[], by simp only [after, applyPayload, withPending, pushHistory, withLog]; split <;> simp, by simp⟩

theorem withPending_acct (s : State) (e : Event) (w : Unit → PView) : (withPending s e w).acct = s.acct := by
  unfold withPending; split <;> rfl
theorem withPending_rules (s : State) (e : Event) (w : Unit → PView) : (withPending s e w).rules = s.rules := by
  unfold withPending; split <;> rfl
theorem withPending_ended (s : State) (e : Event) (w : Unit → PView) : (withPending s e w).ended = s.ended := by
  unfold withPending; split <;> rfl
theorem withPending_veffects (s : State) (e : Event) (w : Unit → PView) : (withPending s e w).veffects = s.veffects := by
  unfold withPending; split <;> rfl

/-- A coin edited by functions of what the world reads of it is edited alike in two worlds that agree. -/
theorem coins_setAt_eq (s u : State) (hw : s.coins.map worldCoin = u.coins.map worldCoin) (i : Nat)
    (g g' : CoinState → CoinState) (G : Option Rat × Option Rat × Option Rat → Option Rat × Option Rat × Option Rat)
    (hg : ∀ c, worldCoin (g c) = G (worldCoin c)) (hg' : ∀ c, worldCoin (g' c) = G (worldCoin c)) :
    (setAt s.coins i (g (getCoin s i))).map worldCoin = (setAt u.coins i (g' (getCoin u i))).map worldCoin := by
  rw [setAt_map, setAt_map, hg, hg', getCoin_worldCoin s u hw i, hw]

def listingCancels (s : State) (e : Event) (rules : Rules) : List Engine.World.Effect :=
  if (s.rules[e.coin]? != some rules) = true then
    (s.acct.orders.filter (·.coin == e.coin)).map fun o => Engine.World.Effect.cancelled o "rules" else []

theorem after_listing_acct (s : State) (e : Event) (rules : Rules) :
    (after s e (.listing rules)).acct =
      (listingCancels s e rules).foldl (fun a x => a.apply s.cfg.fees e.time x) s.acct := by
  unfold after
  exact emit_acct _ _ _

theorem after_listing_veffects (s : State) (e : Event) (rules : Rules) :
    (after s e (.listing rules)).veffects = s.veffects ++ (listingCancels s e rules).map (logged s.cfg e.time) := by
  unfold after
  exact emit_veffects _ _ _

theorem after_listing_frame (s : State) (e : Event) (rules : Rules) :
    (after s e (.listing rules)).rules = setAt s.rules e.coin rules ∧ (after s e (.listing rules)).ended = s.ended ∧
      (after s e (.listing rules)).coins = s.coins := by
  unfold after
  have h := emit_frame { s with rules := setAt s.rules e.coin rules } e.time (listingCancels s e rules)
  exact ⟨h.rules, h.ended, h.coins⟩

/-- What an event of each kind does to the world's side: its account and veffects, its rules, the coins that ended and
the coin it edits. -/
theorem after_ending_fields (s : State) (e : Event) (price : Int) :
    (after s e (.ending price)).acct = s.acct ∧ (after s e (.ending price)).rules = s.rules ∧
      (after s e (.ending price)).veffects = s.veffects ∧ (after s e (.ending price)).ended = e.coin :: s.ended ∧
      (after s e (.ending price)).coins = setAt s.coins e.coin { getCoin s e.coin with price := some (ofUnits 8 price) } :=
  ⟨withPending_acct _ _ _, withPending_rules _ _ _, withPending_veffects _ _ _, withPending_ended _ _ _,
    withPending_coins _ _ _⟩

theorem after_funding_fields (s : State) (e : Event) (hour rate : Int) (oracle : Option Int) :
    (after s e (.funding hour rate oracle)).acct = s.acct ∧ (after s e (.funding hour rate oracle)).rules = s.rules ∧
      (after s e (.funding hour rate oracle)).veffects = s.veffects ∧
      (after s e (.funding hour rate oracle)).ended = s.ended ∧
      (after s e (.funding hour rate oracle)).coins = setAt s.coins e.coin { getCoin s e.coin with fundingHour := some hour } :=
  ⟨withPending_acct _ _ _, withPending_rules _ _ _, withPending_veffects _ _ _, withPending_ended _ _ _,
    withPending_coins _ _ _⟩

theorem after_trade_fields (s : State) (e : Event) (id price size : Int) (sizeScale : Nat) (seller : Bool) :
    (after s e (.trade id price size sizeScale seller)).acct = s.acct ∧
      (after s e (.trade id price size sizeScale seller)).rules = s.rules ∧
      (after s e (.trade id price size sizeScale seller)).veffects = s.veffects ∧
      (after s e (.trade id price size sizeScale seller)).ended = s.ended ∧
      (after s e (.trade id price size sizeScale seller)).coins =
        setAt s.coins e.coin { getCoin s e.coin with price := some (ofUnits 8 price) } :=
  ⟨withPending_acct _ _ _, withPending_rules _ _ _, withPending_veffects _ _ _, withPending_ended _ _ _,
    withPending_coins _ _ _⟩

def quoteCoin (s : State) (e : Event) (bid ask : Int) : CoinState :=
  { getCoin s e.coin with lastQuote := some e.time, quotes := if s.cfg.tickMs.isSome then e.time :: (getCoin s e.coin).quotes else [], price := some (midPrice bid ask), bid := some (ofUnits 8 bid), ask := some (ofUnits 8 ask) }

theorem after_quote_fields (s : State) (e : Event) (bid bidSize ask askSize : Int) (sizeScale : Nat) :
    (after s e (.quote bid bidSize ask askSize sizeScale)).acct = s.acct ∧
      (after s e (.quote bid bidSize ask askSize sizeScale)).rules = s.rules ∧
      (after s e (.quote bid bidSize ask askSize sizeScale)).veffects = s.veffects ∧
      (after s e (.quote bid bidSize ask askSize sizeScale)).ended = s.ended ∧
      (after s e (.quote bid bidSize ask askSize sizeScale)).coins = setAt s.coins e.coin (quoteCoin s e bid ask) :=
  ⟨withPending_acct _ _ _, withPending_rules _ _ _, withPending_veffects _ _ _, withPending_ended _ _ _,
    withPending_coins _ _ _⟩

theorem after_observation_fields (s : State) (e : Event) (source : Nat) (bits : UInt64) :
    (after s e (.observation source bits)).acct = s.acct ∧ (after s e (.observation source bits)).rules = s.rules ∧
      (after s e (.observation source bits)).veffects = s.veffects ∧
      (after s e (.observation source bits)).ended = s.ended ∧ (after s e (.observation source bits)).coins = s.coins :=
  ⟨withPending_acct _ _ _, withPending_rules _ _ _, withPending_veffects _ _ _, withPending_ended _ _ _,
    withPending_coins _ _ _⟩

theorem after_worldEq (s u : State) (e : Event) (r : Reading) (hw : WorldEq s u) (hc : s.cfg = u.cfg) :
    WorldEq (after s e r) (after u e r) ∧
      ∃ L, (after s e r).veffects = s.veffects ++ L ∧ (after u e r).veffects = u.veffects ++ L := by
  cases r with
  | listing rules =>
    have hcan : listingCancels s e rules = listingCancels u e rules := by
      simp only [listingCancels, hw.rules, hw.acct]
    obtain ⟨r1, r2, r3⟩ := after_listing_frame s e rules
    obtain ⟨r1', r2', r3'⟩ := after_listing_frame u e rules
    refine ⟨⟨?_, ?_, ?_, ?_⟩, _, after_listing_veffects s e rules, ?_⟩
    · rw [after_listing_acct, after_listing_acct, hcan, hw.acct, hc]
    · rw [r1, r1', hw.rules]
    · rw [r2, r2', hw.ended]
    · rw [r3, r3', hw.coins]
    · rw [after_listing_veffects u e rules, hcan, hc]
  | ending price =>
    obtain ⟨a1, a2, a3, a4, a5⟩ := after_ending_fields s e price
    obtain ⟨b1, b2, b3, b4, b5⟩ := after_ending_fields u e price
    refine ⟨⟨?_, ?_, ?_, ?_⟩, [], ?_, ?_⟩
    · rw [a1, b1]; exact hw.acct
    · rw [a2, b2]; exact hw.rules
    · rw [a4, b4, hw.ended]
    · rw [a5, b5]
      exact coins_setAt_eq s u hw.coins e.coin (fun c => { c with price := some (ofUnits 8 price) }) (fun c => { c with price := some (ofUnits 8 price) }) (fun x => (x.1, x.2.1, some (ofUnits 8 price))) (fun c => rfl) (fun c => rfl)
    · rw [a3]; simp
    · rw [b3]; simp
  | funding hour rate oracle =>
    obtain ⟨a1, a2, a3, a4, a5⟩ := after_funding_fields s e hour rate oracle
    obtain ⟨b1, b2, b3, b4, b5⟩ := after_funding_fields u e hour rate oracle
    refine ⟨⟨?_, ?_, ?_, ?_⟩, [], ?_, ?_⟩
    · rw [a1, b1]; exact hw.acct
    · rw [a2, b2]; exact hw.rules
    · rw [a4, b4]; exact hw.ended
    · rw [a5, b5]
      exact coins_setAt_eq s u hw.coins e.coin (fun c => { c with fundingHour := some hour }) (fun c => { c with fundingHour := some hour }) (fun x => x) (fun c => rfl) (fun c => rfl)
    · rw [a3]; simp
    · rw [b3]; simp
  | trade id price size sizeScale seller =>
    obtain ⟨a1, a2, a3, a4, a5⟩ := after_trade_fields s e id price size sizeScale seller
    obtain ⟨b1, b2, b3, b4, b5⟩ := after_trade_fields u e id price size sizeScale seller
    refine ⟨⟨?_, ?_, ?_, ?_⟩, [], ?_, ?_⟩
    · rw [a1, b1]; exact hw.acct
    · rw [a2, b2]; exact hw.rules
    · rw [a4, b4]; exact hw.ended
    · rw [a5, b5]
      exact coins_setAt_eq s u hw.coins e.coin (fun c => { c with price := some (ofUnits 8 price) }) (fun c => { c with price := some (ofUnits 8 price) }) (fun x => (x.1, x.2.1, some (ofUnits 8 price))) (fun c => rfl) (fun c => rfl)
    · rw [a3]; simp
    · rw [b3]; simp
  | quote bid bidSize ask askSize sizeScale =>
    obtain ⟨a1, a2, a3, a4, a5⟩ := after_quote_fields s e bid bidSize ask askSize sizeScale
    obtain ⟨b1, b2, b3, b4, b5⟩ := after_quote_fields u e bid bidSize ask askSize sizeScale
    refine ⟨⟨?_, ?_, ?_, ?_⟩, [], ?_, ?_⟩
    · rw [a1, b1]; exact hw.acct
    · rw [a2, b2]; exact hw.rules
    · rw [a4, b4]; exact hw.ended
    · rw [a5, b5]
      exact coins_setAt_eq s u hw.coins e.coin (fun c => { c with lastQuote := some e.time, quotes := if s.cfg.tickMs.isSome then e.time :: c.quotes else [], price := some (midPrice bid ask), bid := some (ofUnits 8 bid), ask := some (ofUnits 8 ask) }) (fun c => { c with lastQuote := some e.time, quotes := if u.cfg.tickMs.isSome then e.time :: c.quotes else [], price := some (midPrice bid ask), bid := some (ofUnits 8 bid), ask := some (ofUnits 8 ask) }) (fun _ => (some (ofUnits 8 bid), some (ofUnits 8 ask), some (midPrice bid ask))) (fun c => rfl) (fun c => rfl)
    · rw [a3]; simp
    · rw [b3]; simp
  | observation source bits =>
    obtain ⟨a1, a2, a3, a4, a5⟩ := after_observation_fields s e source bits
    obtain ⟨b1, b2, b3, b4, b5⟩ := after_observation_fields u e source bits
    refine ⟨⟨?_, ?_, ?_, ?_⟩, [], ?_, ?_⟩
    · rw [a1, b1]; exact hw.acct
    · rw [a2, b2]; exact hw.rules
    · rw [a4, b4]; exact hw.ended
    · rw [a5, b5]; exact hw.coins
    · rw [a3]; simp
    · rw [b3]; simp

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

theorem after_inv {s : State} (e : Event) (r : Reading) (h : WishInv s) : WishInv (after s e r) := by
  have k := after_keeps s e r
  unfold WishInv at h ⊢
  rw [k.wishes, k.nextTick, k.cfg]
  exact h

theorem after_late {τ : Int} {s : State} (e : Event) (r : Reading) (h : Late τ s) : Late τ (after s e r) := by
  have k := after_keeps s e r
  unfold Late at h ⊢
  rw [k.wishes, k.nextTick, k.cfg]
  exact h

theorem after_effects (τ : Int) (s : State) (e : Event) (r : Reading) (ht : τ - s.cfg.delta < e.time) :
    (after s e r).veffects.filter (effKnownBy τ) = s.veffects.filter (effKnownBy τ) := by
  obtain ⟨L, h1, h2⟩ := after_veffects s e r
  rw [h1, List.filter_append]
  have : L.filter (effKnownBy τ) = [] := by
    rw [List.filter_eq_nil_iff]
    intro x hx
    have := h2 x hx
    simp only [effKnownBy, decide_eq_true_eq]; omega
  rw [this]; simp

theorem after_agree (τ : Int) (s u : State) (e : Event) (r : Reading) (h : Agree τ s u) (hc : Clocked s)
    (ht : τ - s.cfg.delta < e.time) : Agree τ (after s e r) (after u e r) := by
  have ks := after_keeps s e r
  have ku := after_keeps u e r
  have hcu : Clocked u := by obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [← h.cfg]; exact hms⟩
  have hdelta : u.cfg.delta = s.cfg.delta := by rw [h.cfg]
  refine ⟨by rw [ks.cfg, ku.cfg, h.cfg], by rw [ks.prog, ku.prog, h.prog], by rw [ks.nextTick, ku.nextTick, h.next],
    by rw [ks.view, ku.view, h.view], by rw [ks.mach, ku.mach, h.mach], by rw [ks.vacct, ku.vacct, h.vacct],
    by rw [ks.vage, ku.vage, h.vage], by rw [ks.wishes, ku.wishes, h.wishes], after_sorted s e r h.sortedL,
    after_sorted u e r h.sortedR, after_inv e r h.inv, after_pending_agree τ s u e r h, ?_, ?_, ?_⟩
  · rw [after_effects τ s e r ht, after_effects τ u e r (by rw [hdelta]; exact ht), h.effects]
  · rw [ks.cfg, after_coins s e r (τ - s.cfg.delta) hc ht, after_coins u e r (τ - s.cfg.delta) hcu ht, h.quotes]
  · rcases h.world with hw | hl
    · exact Or.inl (after_worldEq s u e r hw h.cfg).1
    · exact Or.inr (after_late e r hl)

theorem after_self (τ : Int) (s : State) (e : Event) (r : Reading) (hs : PendSorted s) (hc : Clocked s)
    (hk : τ < e.known) (ht : τ - s.cfg.delta < e.time) (hi : WishInv s) (hl : Late τ s) :
    Agree τ s (after s e r) := by
  have ks := after_keeps s e r
  refine ⟨ks.cfg.symm, ks.prog.symm, ks.nextTick.symm, ks.view.symm, ks.mach.symm, ks.vacct.symm, ks.vage.symm,
    ks.wishes.symm, hs, after_sorted s e r hs, hi, ?_, (after_effects τ s e r ht).symm, ?_, Or.inr hl⟩
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

/-! ### What every state of a run keeps -/

theorem tickBody_inv (s : State) (time : Int) (hn : s.nextTick = some time) (hi : WishInv s) :
    WishInv (tickBody s time).1 := by
  have hsent : ∀ w ∈ orderWishes (tickBody s time).2.2.wishes, w.arrives = time + s.cfg.lambda :=
    fun w hw => tickBody_sent_arrives s time w ((mem_orderWishes _ w).1 hw)
  have hwish : (tickBody s time).1.wishes = s.wishes ++ orderWishes (tickBody s time).2.2.wishes := tickBody_wishes s time
  refine ⟨?_, ?_⟩
  · rw [hwish]
    refine List.pairwise_append.2 ⟨hi.1, pairwise_arrives _ _ hsent, ?_⟩
    intro a ha b hb
    have h1 := hi.2 time hn a ha
    rw [hsent b hb]
    exact h1
  · intro t' ht' w hw
    rw [tickBody_nextTick, hn] at ht'
    obtain rfl := Option.some.inj ht'
    rw [tickBody_cfg]
    rw [hwish] at hw
    rcases List.mem_append.1 hw with hw | hw
    · exact hi.2 time hn w hw
    · rw [hsent w hw]; exact Int.le_refl _

theorem drain_inv (s : State) (b : Int) (hi : WishInv s) : WishInv (drain s b).1 := by
  have fs := drain_frame_wishes s b
  have hws : (drain s b).1.wishes = s.wishes.dropWhile (fun w => decide (w.arrives < b)) := drain_wishes s b
  have hsub : (s.wishes.dropWhile (fun w => decide (w.arrives < b))).Sublist s.wishes := List.dropWhile_sublist _
  refine ⟨?_, ?_⟩
  · rw [hws]; exact hi.1.sublist hsub
  · intro t ht w hw
    rw [fs.nextTick] at ht
    rw [hws] at hw
    rw [fs.cfg]
    exact hi.2 t ht w (hsub.subset hw)

theorem stepTick_inv (s : State) (time ms : Int) (hn : s.nextTick = some time) (hms : 0 < ms) (hi : WishInv s) :
    WishInv (stepTick s time ms).1 := by
  have h1 := drain_inv s time hi
  have hn1 : (drain s time).1.nextTick = some time := by rw [drain_nextTick]; exact hn
  have h2 : WishInv (aged (releaseEffects (release (drain s time).1 time) time)) := h1
  have hn2 : (aged (releaseEffects (release (drain s time).1 time) time)).nextTick = some time := hn1
  have h3 := tickBody_inv _ time hn2 h2
  have hc : (tickBody (aged (releaseEffects (release (drain s time).1 time) time)) time).1.cfg = s.cfg := by
    rw [tickBody_cfg]; exact drain_cfg s time
  refine ⟨h3.1, ?_⟩
  intro t' ht' w hw
  have e : t' = time + ms := (Option.some.inj ((stepTick_nextTick s time ms).symm.trans ht')).symm
  have := h3.2 time (by rw [tickBody_nextTick]; exact hn2) w hw
  rw [hc] at this
  rw [stepTick_cfg, e]
  omega

theorem fireR_inv (n : Nat) : ∀ s : State, Setup s → WishInv s → WishInv (fireR n s).1 := by
  induction n with
  | zero => intro s _ hi; simpa [fireR_zero] using hi
  | succ n ih =>
    intro s hS hi
    cases hn : s.nextTick with
    | none => rw [fireR_stuck _ s (Or.inl hn)]; exact hi
    | some t =>
      cases ht : s.cfg.tickMs with
      | none => rw [fireR_stuck _ s (Or.inr ht)]; exact hi
      | some ms =>
        rw [fireR_succ_some n s t ms hn ht]
        exact ih _ (Setup.of_cfg hS (stepTick_cfg s t ms)) (stepTick_inv s t ms hn (hS.1 ms ht) hi)

theorem settleR_inv (s : State) (b : Int) (hS : Setup s) (hi : WishInv s) : WishInv (settleR s b).1 :=
  drain_inv _ _ (fireR_inv _ s hS hi)

theorem release_sorted (s : State) (t : Int) (h : PendSorted s) : PendSorted (release s t) := by
  have hs := span_sorted t s.pending h
  unfold PendSorted release
  simp only [hs]
  exact h.filter _

theorem tickAt_pending_sorted (s : State) (t : Int) (h : PendSorted s) :
    PendSorted (tickAt s t).1 := by
  have := release_sorted s t h
  unfold PendSorted at this ⊢
  unfold tickAt
  rw [tickBody_pending]
  exact this

theorem stepTick_sorted (s : State) (t ms : Int) (h : PendSorted s) : PendSorted (stepTick s t ms).1 := by
  have h1 : PendSorted (drain s t).1 := by
    unfold PendSorted; rw [(drain_frame_wishes s t).pending]; exact h
  exact tickAt_pending_sorted _ t h1

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
        exact ih _ (stepTick_sorted s t ms h)

theorem settleR_sorted (s : State) (b : Int) (h : PendSorted s) : PendSorted (settleR s b).1 := by
  have h1 := fireR_sorted (ticksBefore s b) s h
  unfold PendSorted at h1 ⊢
  unfold settleR
  simp only []
  rw [(drain_frame_wishes _ b).pending]
  exact h1

/-- After the clock has run to a bound past `τ - δ`, no wish arrives by `τ - δ` and none will be sent that does. -/
theorem settleR_late (τ b : Int) (s : State) (hS : Setup s) (hi : WishInv s) (hb : τ - s.cfg.delta < b)
    (hbs : b ≤ s.cfg.stop) : Late τ (settleR s b).1 := by
  have hf := fireR_inv (ticksBefore s b) s hS hi
  have hcfg := settleR_cfg s b
  refine ⟨?_, ?_⟩
  · intro w hw
    have hw' : w ∈ (fireR (ticksBefore s b) s).1.wishes.dropWhile (fun w => decide (w.arrives < b)) := by
      have := drain_wishes (fireR (ticksBefore s b) s).1 b
      unfold settleR at hw
      rw [this] at hw
      exact hw
    have := dropWhile_ge b _ hf.1 w hw'
    rw [hcfg]
    omega
  · intro t ms ht hm
    rw [hcfg] at hm ⊢
    unfold settleR at ht
    simp only [drain_nextTick] at ht
    cases hn : s.nextTick with
    | none => rw [fireR_stuck _ s (Or.inl hn)] at ht; simp [hn] at ht
    | some t0 =>
      obtain ⟨t', ht', hge⟩ := fireR_nextTick_ge s b t0 ms hn hm (hS.1 ms hm)
      rw [ht'] at ht
      obtain rfl := Option.some.inj ht
      have : min b s.cfg.stop = b := by omega
      omega

/-! ### Runs from two markets that agree -/

theorem dead_drain {τ : Int} {s : State} (b : Int) (h : Dead τ s) : Dead τ (drain s b).1 := by
  intro t ht
  rw [drain_nextTick] at ht
  exact h t ht

theorem settleR_good (τ b bu : Int) {s u : State} (hSs : Setup s) (hSu : Setup u) (h : Good τ s u)
    (hb : Agree τ s u → b = bu) :
    Good τ (settleR s b).1 (settleR u bu).1 ∧
      (settleR s b).2.filter (fun r => decide (r.time ≤ τ)) = (settleR u bu).2.filter (fun r => decide (r.time ≤ τ)) := by
  rcases h with h | ⟨hds, hdu⟩
  · have hbb := hb h
    subst hbb
    have hcount : ticksBefore u b = ticksBefore s b := by
      unfold ticksBefore; rw [← h.cfg, ← h.next]
    obtain ⟨hg, hr⟩ := fireR_agree τ (ticksBefore s b) s u hSs h
    unfold settleR
    simp only [hcount]
    refine ⟨?_, hr⟩
    rcases hg with ha | ⟨d1, d2⟩
    · exact Or.inl (drain_agree τ b ha)
    · exact Or.inr ⟨dead_drain b d1, dead_drain b d2⟩
  · obtain ⟨d1, d2⟩ := fireR_dead τ (ticksBefore s b) s hSs hds
    obtain ⟨e1, e2⟩ := fireR_dead τ (ticksBefore u bu) u hSu hdu
    refine ⟨Or.inr ⟨dead_drain b d1, dead_drain bu e1⟩, ?_⟩
    have hs0 : (fireR (ticksBefore s b) s).2.filter (fun r => decide (r.time ≤ τ)) = [] := by
      rw [List.filter_eq_nil_iff]; intro r hr; have := d2 r hr; simp; omega
    have hu0 : (fireR (ticksBefore u bu) u).2.filter (fun r => decide (r.time ≤ τ)) = [] := by
      rw [List.filter_eq_nil_iff]; intro r hr; have := e2 r hr; simp; omega
    unfold settleR
    simp only [hs0, hu0]

theorem afterSettle_cfg (s : State) (b : Int) (e : Event) (r : Reading) : (after (settleR s b).1 e r).cfg = s.cfg := by
  rw [after_cfg, settleR_cfg]

theorem after_good (τ : Int) {s u : State} (e : Event) (r : Reading) (h : Good τ s u) (hc : Clocked s)
    (ht : τ - s.cfg.delta < e.time) : Good τ (after s e r) (after u e r) := by
  rcases h with h | ⟨hs, hu⟩
  · exact Or.inl (after_agree τ s u e r h hc ht)
  · have ks := after_keeps s e r
    have ku := after_keeps u e r
    exact Or.inr ⟨fun t hx => hs t (by rw [← ks.nextTick]; exact hx), fun t hx => hu t (by rw [← ku.nextTick]; exact hx)⟩

/-- Two states that agree at `τ` give the same records through `τ` over the same events. -/
theorem recs_agree (τ δ : Int) : ∀ (ps : List Pair) (s u : State), s.cfg.delta = δ → Setup s → Setup u →
    Clocked s → Good τ s u → (∀ p ∈ ps, τ - δ < p.1.time) →
    (recsPairs s ps).filter (fun r => decide (r.time ≤ τ)) = (recsPairs u ps).filter (fun r => decide (r.time ≤ τ)) := by
  intro ps
  induction ps with
  | nil =>
    intro s u hδ hs hu hc h _
    rw [recsPairs_nil, recsPairs_nil]
    exact (settleR_good τ s.cfg.stop u.cfg.stop hs hu h (fun ha => by rw [ha.cfg])).2
  | cons p rest ih =>
    intro s u hδ hs hu hc h hp
    rw [recsPairs_cons, recsPairs_cons, List.filter_append, List.filter_append]
    obtain ⟨g1, g2⟩ := settleR_good τ p.1.time p.1.time hs hu h (fun _ => rfl)
    rw [g2]
    congr 1
    have hcs : (settleR s p.1.time).1.cfg = s.cfg := settleR_cfg _ _
    have hcu : (settleR u p.1.time).1.cfg = u.cfg := settleR_cfg _ _
    have hclk : Clocked (settleR s p.1.time).1 := by
      obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [hcs]; exact hms⟩
    have hpt : τ - (settleR s p.1.time).1.cfg.delta < p.1.time := by
      rw [hcs, hδ]; exact hp p (List.mem_cons_self ..)
    apply ih
    · rw [afterSettle_cfg]; exact hδ
    · exact Setup.of_cfg hs (afterSettle_cfg _ _ _ _)
    · exact Setup.of_cfg hu (afterSettle_cfg _ _ _ _)
    · obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [afterSettle_cfg]; exact hms⟩
    · exact after_good τ p.1 p.2 g1 hclk hpt
    · intro q hq; exact hp q (List.mem_cons_of_mem _ hq)

/-- Dropping the events not known by `τ` changes no record through `τ`. -/
theorem recs_filterK (τ δ : Int) : ∀ (ps : List Pair) (s : State), s.cfg.delta = δ → Setup s → Clocked s →
    PendSorted s → WishInv s → (∀ p ∈ ps, τ - δ < p.1.time) →
    ps.Pairwise (fun p q => p.1.time ≤ q.1.time) → (∀ p ∈ ps, p.1.time < s.cfg.stop) →
    (recsPairs s ps).filter (fun r => decide (r.time ≤ τ)) =
      (recsPairs s (ps.filter (fun p => decide (p.1.known ≤ τ)))).filter (fun r => decide (r.time ≤ τ)) := by
  intro ps
  induction ps with
  | nil => intros; rfl
  | cons p rest ih =>
    intro s hδ hS hc hsort hinv hp hmono hbound
    have hcs : (settleR s p.1.time).1.cfg = s.cfg := settleR_cfg _ _
    have hclk : Clocked (settleR s p.1.time).1 := by
      obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [hcs]; exact hms⟩
    have hpt : τ - (settleR s p.1.time).1.cfg.delta < p.1.time := by
      rw [hcs, hδ]; exact hp p (List.mem_cons_self ..)
    have hsort1 : PendSorted (settleR s p.1.time).1 := settleR_sorted s _ hsort
    have hinv1 : WishInv (settleR s p.1.time).1 := settleR_inv s _ hS hinv
    have hS1 : Setup (settleR s p.1.time).1 := Setup.of_cfg hS hcs
    have hmono' := List.pairwise_cons.1 hmono
    by_cases hk : p.1.known ≤ τ
    · have e : (p :: rest).filter (fun p => decide (p.1.known ≤ τ)) =
          p :: rest.filter (fun p => decide (p.1.known ≤ τ)) := by simp [hk]
      rw [e, recsPairs_cons, recsPairs_cons, List.filter_append, List.filter_append]
      congr 1
      apply ih
      · rw [afterSettle_cfg]; exact hδ
      · exact Setup.of_cfg hS (afterSettle_cfg _ _ _ _)
      · obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [afterSettle_cfg]; exact hms⟩
      · exact after_sorted _ _ _ hsort1
      · exact after_inv _ _ hinv1
      · intro q hq; exact hp q (List.mem_cons_of_mem _ hq)
      · exact hmono'.2
      · intro q hq; rw [afterSettle_cfg]; exact hbound q (List.mem_cons_of_mem _ hq)
    · have e : (p :: rest).filter (fun p => decide (p.1.known ≤ τ)) = rest.filter (fun p => decide (p.1.known ≤ τ)) := by
        simp [hk]
      rw [e, recsPairs_cons, List.filter_append]
      have hQ : ∀ q ∈ rest.filter (fun p => decide (p.1.known ≤ τ)), τ - δ < q.1.time :=
        fun q hq => hp q (List.mem_cons_of_mem _ ((List.mem_filter.1 hq).1))
      have hfire := recsPairs_settle s hS.1 p.1.time
        (rest.filter (fun p => decide (p.1.known ≤ τ))) (by
          cases hq : rest.filter (fun p => decide (p.1.known ≤ τ)) with
          | nil => exact Int.le_of_lt (hbound p (List.mem_cons_self ..))
          | cons q _ =>
            have : q ∈ rest := (List.mem_filter.1 (by rw [hq]; exact List.mem_cons_self ..)).1
            exact hmono'.1 q this)
      rw [hfire, List.filter_append]
      congr 1
      have hlate : Late τ (settleR s p.1.time).1 :=
        settleR_late τ p.1.time s hS hinv (by rw [hδ]; exact hp p (List.mem_cons_self ..))
          (Int.le_of_lt (hbound p (List.mem_cons_self ..)))
      have hag : Agree τ (settleR s p.1.time).1 (after (settleR s p.1.time).1 p.1 p.2) :=
        after_self τ _ p.1 p.2 hsort1 hclk (by omega) hpt hinv1 hlate
      have hrec := recs_agree τ δ (rest.filter (fun p => decide (p.1.known ≤ τ))) _ _
        (by rw [hcs]; exact hδ) hS1 (Setup.of_cfg hS (afterSettle_cfg _ _ _ _)) hclk (Or.inl hag) hQ
      have hih := ih (after (settleR s p.1.time).1 p.1 p.2)
        (by rw [afterSettle_cfg]; exact hδ) (Setup.of_cfg hS (afterSettle_cfg _ _ _ _))
        (by obtain ⟨ms, hms⟩ := hc; exact ⟨ms, by rw [afterSettle_cfg]; exact hms⟩)
        (after_sorted _ _ _ hsort1) (after_inv _ _ hinv1) (fun q hq => hp q (List.mem_cons_of_mem _ hq)) hmono'.2
        (fun q hq => by rw [afterSettle_cfg]; exact hbound q (List.mem_cons_of_mem _ hq))
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
  rw [advanceRec_state]; exact afterSettle_cfg s e.time e r

theorem advanceRec_previous (s : State) (e : Event) (r : Reading) : (advanceRec s e r).1.previous = some e := by
  rw [advanceRec_state]; unfold after; simp

theorem advanceRec_sorted (s : State) (e : Event) (r : Reading) (h : PendSorted s) :
    PendSorted (advanceRec s e r).1 := by
  rw [advanceRec_state]
  exact after_sorted _ _ _ (settleR_sorted s _ h)

theorem advanceRec_inv (s : State) (e : Event) (r : Reading) (hS : Setup s) (h : WishInv s) :
    WishInv (advanceRec s e r).1 := by
  rw [advanceRec_state]
  exact after_inv _ _ (settleR_inv s _ hS h)

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
    rw [recsPairs_nil, ← h]
    exact ((settle_eq s s.cfg.stop Rows.empty).2).symm
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


theorem runP_inv : ∀ (P : List Pair) (s : State), Setup s → WishInv s → WishInv (runP s P).1 := by
  intro P
  induction P with
  | nil => intro s _ h; exact h
  | cons p P ih =>
    intro s hS h
    simp only [runP]
    exact ih _ (Setup.of_cfg hS (advanceRec_cfg s p.1 p.2)) (advanceRec_inv s p.1 p.2 hS h)

theorem parseHeader_nonneg {text : String} {cfg : Config} (h : parseHeader text = .ok cfg) :
    0 ≤ cfg.lambda ∧ 0 ≤ cfg.delta := by
  unfold parseHeader at h
  cases hr : parseHeaderRaw text with
  | error e => rw [hr] at h; simp [Bind.bind, Except.bind] at h
  | ok c =>
    rw [hr] at h
    simp only [Bind.bind, Except.bind] at h
    split at h
    · rename_i hv
      split at h
      · simp at h
      · injection h with h
        subst h
        simp only [Bool.and_eq_true, decide_eq_true_eq] at hv
        exact ⟨hv.1.1.1.1, hv.1.1.1.2⟩
    · simp at h

theorem start_shape {program header : String} {initial : State} (h : start program header = .ok initial) :
    ∃ (cfg : Config) (p : Engine.Lang.Program), Engine.Lang.parse program = .ok p ∧ parseHeader header = .ok cfg ∧
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
      obtain ⟨hpp, hcc⟩ := prepare_parts hp
      exact ⟨cfg, p, hpp, hcc, h'.symm⟩

theorem start_facts {program header : String} {initial : State} (h : start program header = .ok initial) :
    Setup initial ∧ Clocked initial ∧ PendSorted initial ∧ WishInv initial ∧ initial.rejected = none ∧
      initial.previous = none := by
  obtain ⟨cfg, p, hp, hc, rfl⟩ := start_shape h
  have htick := Engine.Lang.parse_tick_pos hp
  have hn := parseHeader_nonneg hc
  refine ⟨⟨?_, hn.1⟩, ⟨_, rfl⟩, ?_, ⟨?_, ?_⟩, rfl, rfl⟩
  · intro ms hms
    simp only [initialState, Option.some.injEq] at hms
    subst hms
    omega
  · simp [PendSorted, initialState]
  · simp [initialState]
  · intro t ht w hw
    simp [initialState] at hw


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
  obtain ⟨hset, hclk, hsort, hinv, hrej, hprev⟩ := start_facts hs
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
  have hsetA : Setup (runP initial PA₁).1 := Setup.of_cfg hset hcfgA
  have hclkA : Clocked (runP initial PA₁).1 := by
    obtain ⟨ms, h⟩ := hclk; exact ⟨ms, by rw [hcfgA]; exact h⟩
  have hsortA := runP_sorted PA₁ initial hsort
  have hinvA := runP_inv PA₁ initial hset hinv
  have hδA : (runP initial PA₁).1.cfg.delta = δ := by rw [hcfgA]; exact hδ
  have hmB₁ : Mono PB₁ := (List.pairwise_append.1 mo1).2.1
  have hmB₂ : Mono PB₂ := (List.pairwise_append.1 mo2).2.1
  have hbd₁' : ∀ p ∈ PB₁, p.1.time < (runP initial PA₁).1.cfg.stop := fun p hp => by
    rw [hcfgA]; exact bd1 p (List.mem_append_right _ hp)
  have hbd₂' : ∀ p ∈ PB₂, p.1.time < (runP initial PA₁).1.cfg.stop := fun p hp => by
    rw [hcfgA]; exact bd2 p (List.mem_append_right _ hp)
  have f1 := recs_filterK τ δ PB₁ _ hδA hsetA hclkA hsortA hinvA hB₁ hmB₁ hbd₁'
  have f2 := recs_filterK τ δ PB₂ _ hδA hsetA hclkA hsortA hinvA hB₂ hmB₂ hbd₂'
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
