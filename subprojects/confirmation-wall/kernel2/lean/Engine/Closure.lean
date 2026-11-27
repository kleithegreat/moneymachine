import Engine.PlacedLaw

/-!
# What every state of a run keeps (brief 3 step 5; R1 and S1)

The fields of a state that the laws about orders read are its `Core`. An invariant is a predicate of a `Core`; it holds of
every state of a run when it holds of the first and survives the machine's few moves that change a core: the wishes that
arrive (`drain`), a tick, a listing event's cancels, an event's own mark (`previous`) and an offer. Every other move
leaves the core as it was.
-/

namespace Engine.Machine

open Engine.Orders (Wish Book Order Placement Arrival CycleStep OrderFill)

/-- The lists of a log that the laws read. -/
structure LogCore where
  placed : List Placement
  wishes : List Wish
  arrivals : List Arrival
  admissions : List (Book × Order)
  steps : List CycleStep
  fills : List OrderFill
  ticks : List (Int × List Bool)

def Log.core (l : Log) : LogCore :=
  ⟨l.placed, l.wishes, l.arrivals, l.admissions, l.steps, l.fills, l.ticks⟩

structure Core where
  cfg : Config
  prog : Option Engine.Lang.Program
  acct : Engine.World.Acct
  nextTick : Option Int
  wishes : List Wish
  vacct : Engine.World.Acct
  veffects : List Logged
  previous : Option Event
  log : Option LogCore

def StateOf.core {α : Type} (s : StateOf α) : Core :=
  ⟨s.cfg, s.prog, s.acct, s.nextTick, s.wishes, s.vacct, s.veffects, s.previous, s.log.map Log.core⟩

/-- No event has been fed past the next tick or ahead of a wish that is still to arrive. -/
def Frontier (c : Core) : Prop :=
  ∀ e, c.previous = some e → (∀ t, c.nextTick = some t → e.time ≤ t) ∧ ∀ w ∈ c.wishes, e.time ≤ w.arrives

/-- The moves that change a core, and what an invariant must show of each. -/
structure Closed (P : Core → Prop) : Prop where
  arrive : ∀ (s : State) (w : Wish) (rest : List Wish) (b : Int), Setup s →
    WishInv ({ s with wishes := w :: rest } : State) → Frontier ({ s with wishes := w :: rest } : State).core →
    P ({ s with wishes := w :: rest } : State).core → w.arrives < b → (∀ t, s.nextTick = some t → b ≤ t) →
    b ≤ s.cfg.stop → P ({ (arriveWish s w).1 with wishes := rest } : State).core
  tick : ∀ (s : State) (time ms : Int), Setup s → WishInv s → Frontier s.core → P s.core →
    s.nextTick = some time → s.cfg.tickMs = some ms → time < s.cfg.stop →
    P ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core
  listing : ∀ (s : State) (e : Event) (rules : Rules), Setup s → WishInv s → Frontier s.core → P s.core →
    (∀ t, s.nextTick = some t → e.time ≤ t) → (∀ w ∈ s.wishes, e.time ≤ w.arrives) →
    P (applyPayload s e (.listing rules)).1.core
  prev : ∀ (s : State) (e : Event), Setup s → WishInv s → Frontier s.core → P s.core →
    (∀ t, s.nextTick = some t → e.time ≤ t) → (∀ w ∈ s.wishes, e.time ≤ w.arrives) →
    (∀ q, s.previous = some q → q.time ≤ e.time) → P ({ s with previous := some e } : State).core
  offer : ∀ (s : State) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role),
    Setup s → WishInv s → Frontier s.core → P s.core → P (offer s coin slot parts role).1.core

/-! ### What the moves leave -/

theorem tickAt_previous (s : State) (time : Int) : (tickAt s time).1.previous = s.previous := by
  simp only [tickAt, tickBody, withLog, aged, releaseEffects, release]

theorem tickAt_nextTick (s : State) (time : Int) : (tickAt s time).1.nextTick = s.nextTick := by
  simp only [tickAt, tickBody, withLog, aged, releaseEffects, release]

theorem tickAt_wishes (s : State) (time : Int) :
    (tickAt s time).1.wishes = s.wishes ++ orderWishes (tickAt s time).2.2.wishes := by
  have h := tickBody_wishes (aged (releaseEffects (release s time) time)) time
  simpa only [tickAt, aged, releaseEffects, release] using h

theorem tickAt_sent (s : State) (time : Int) : ∀ w ∈ (tickAt s time).2.2.wishes, w.arrives = time + s.cfg.lambda := by
  intro w hw
  have h := tickBody_sent_arrives (aged (releaseEffects (release s time) time)) time w
  simp only [tickAt, aged, releaseEffects, release] at h hw ⊢
  exact h hw

theorem frontier_drain (s : State) (b : Int) (h : Frontier s.core) : Frontier (drain s b).1.core := by
  intro e he
  have fs := drain_frame_wishes s b
  have hp : s.previous = some e := by
    have := fs.previous
    simpa [StateOf.core, this] using he
  obtain ⟨h1, h2⟩ := h e (by simpa [StateOf.core] using hp)
  have hws : (drain s b).1.wishes = s.wishes.dropWhile (fun w => decide (w.arrives < b)) := drain_wishes s b
  refine ⟨fun t ht => h1 t (by simpa [StateOf.core, fs.nextTick] using ht), fun w hw => ?_⟩
  have hw' : w ∈ s.wishes.dropWhile (fun w => decide (w.arrives < b)) := by simpa [StateOf.core, hws] using hw
  exact h2 w ((List.dropWhile_sublist _).subset hw')

theorem frontier_tick (s : State) (time ms : Int) (hS : Setup s) (hF : Frontier s.core) (hn : s.nextTick = some time)
    (ht : s.cfg.tickMs = some ms) : Frontier ({ (tickAt s time).1 with nextTick := some (time + ms) } : State).core := by
  intro e he
  have hp : s.previous = some e := by
    have h := tickAt_previous s time
    simpa [StateOf.core, h] using he
  obtain ⟨h1, h2⟩ := hF e (by simpa [StateOf.core] using hp)
  have hms := hS.1 ms ht
  have hl := hS.2
  have hetime : e.time ≤ time := h1 time hn
  refine ⟨fun t' ht' => ?_, fun w hw => ?_⟩
  · simp only [StateOf.core, Option.some.injEq] at ht'
    omega
  · have hw' : w ∈ (tickAt s time).1.wishes := by simpa [StateOf.core] using hw
    rw [tickAt_wishes] at hw'
    rcases List.mem_append.1 hw' with hw' | hw'
    · exact h2 w hw'
    · have := tickAt_sent s time w ((mem_orderWishes _ w).1 hw')
      omega

theorem frontier_keeps (s u : State) (hp : u.previous = s.previous) (hn : u.nextTick = s.nextTick)
    (hw : u.wishes = s.wishes) (h : Frontier s.core) : Frontier u.core := by
  intro e he
  have := h e (by simpa [StateOf.core, hp] using he)
  refine ⟨fun t ht => this.1 t (by simpa [StateOf.core, hn] using ht), fun w hw' => this.2 w ?_⟩
  simpa [StateOf.core, hw] using hw'

theorem frontier_prev (s : State) (e : Event) (h1 : ∀ t, s.nextTick = some t → e.time ≤ t)
    (h2 : ∀ w ∈ s.wishes, e.time ≤ w.arrives) : Frontier ({ s with previous := some e } : State).core := by
  intro e' he'
  simp only [StateOf.core, Option.some.injEq] at he'
  subst he'
  exact ⟨fun t ht => h1 t (by simpa [StateOf.core] using ht), fun w hw => h2 w (by simpa [StateOf.core] using hw)⟩

/-! ### The package a run keeps -/

def Pack (P : Core → Prop) (s : State) : Prop :=
  Setup s ∧ Clocked s ∧ WishInv s ∧ Frontier s.core ∧ P s.core

theorem Clocked.of_cfg {s u : State} (h : Clocked s) (hc : u.cfg = s.cfg) : Clocked u := by
  obtain ⟨ms, hms⟩ := h
  exact ⟨ms, by rw [hc]; exact hms⟩

theorem pack_core {P : Core → Prop} {s u : State} (h : Pack P s) (hc : u.core = s.core) : Pack P u := by
  obtain ⟨hS, hK, hI, hF, hP⟩ := h
  have e1 : u.cfg = s.cfg := congrArg Core.cfg hc
  have e2 : u.wishes = s.wishes := congrArg Core.wishes hc
  have e3 : u.nextTick = s.nextTick := congrArg Core.nextTick hc
  refine ⟨Setup.of_cfg hS e1, hK.of_cfg e1, ⟨?_, ?_⟩, by rw [hc]; exact hF, by rw [hc]; exact hP⟩
  · rw [e2]; exact hI.1
  · intro t ht w hw
    rw [e3] at ht
    rw [e2] at hw
    rw [e1]
    exact hI.2 t ht w hw

theorem frontier_sublist (s u : State) (hp : u.previous = s.previous) (hn : u.nextTick = s.nextTick)
    (hw : ∀ x ∈ u.wishes, x ∈ s.wishes) (h : Frontier s.core) : Frontier u.core := by
  intro e he
  have := h e (by simpa [StateOf.core, hp] using he)
  refine ⟨fun t ht => this.1 t (by simpa [StateOf.core, hn] using ht), fun w hw' => this.2 w ?_⟩
  exact hw w (by simpa [StateOf.core] using hw')

theorem pack_arrivals_aux {P : Core → Prop} (hC : Closed P) (b : Int) (later : List Wish) :
    ∀ (L : List Wish) (u : State), u.wishes = L ++ later → (∀ x ∈ L, x.arrives < b) → Pack P u →
      (∀ t, u.nextTick = some t → b ≤ t) → b ≤ u.cfg.stop → Pack P ({ arrivals u L with wishes := later } : State) := by
  intro L
  induction L with
  | nil =>
    intro u hu _ h _ _
    exact pack_core h (by simp [arrivals, StateOf.core, hu])
  | cons w L ih =>
    intro u hu hlt h hnext hstop
    have hw : u.wishes = w :: (L ++ later) := by simpa using hu
    have hcore : ({ u with wishes := w :: (L ++ later) } : State).core = u.core := by simp [StateOf.core, hw]
    have hpk : Pack P ({ u with wishes := w :: (L ++ later) } : State) := pack_core h hcore
    obtain ⟨hS, hK, hI, hF, hP⟩ := h
    have hP' := hC.arrive u w (L ++ later) b hS hpk.2.2.1 hpk.2.2.2.1 hpk.2.2.2.2
      (hlt w (List.mem_cons_self ..)) hnext hstop
    have fr := arriveWish_frame u w
    have hI' : WishInv ({ (arriveWish u w).1 with wishes := L ++ later } : State) := by
      refine ⟨?_, ?_⟩
      · have : (L ++ later).Sublist u.wishes := by rw [hw]; exact (List.sublist_cons_self w _)
        exact hI.1.sublist this
      · intro t ht x hx
        have ht' : u.nextTick = some t := by rw [← fr.nextTick]; exact ht
        have hx' : x ∈ u.wishes := by
          rw [hw]
          exact List.mem_cons_of_mem _ (by simpa using hx)
        have := hI.2 t ht' x hx'
        rw [fr.cfg]
        exact this
    have hF' : Frontier ({ (arriveWish u w).1 with wishes := L ++ later } : State).core := by
      refine frontier_sublist ({ u with wishes := w :: (L ++ later) } : State) _ fr.previous fr.nextTick ?_ hpk.2.2.2.1
      intro x hx
      exact List.mem_cons_of_mem _ (by simpa using hx)
    have hpk' : Pack P ({ (arriveWish u w).1 with wishes := L ++ later } : State) :=
      ⟨Setup.of_cfg hS fr.cfg, hK.of_cfg fr.cfg, hI', hF', hP'⟩
    have := ih _ (by simp) (fun x hx => hlt x (List.mem_cons_of_mem _ hx)) hpk'
      (fun t ht => hnext t (by rw [← fr.nextTick]; exact ht)) (by rw [fr.cfg]; exact hstop)
    rw [arrivals_set] at this
    exact this

theorem pack_drain {P : Core → Prop} (hC : Closed P) (s : State) (b : Int) (h : Pack P s)
    (hb : ∀ t, s.nextTick = some t → b ≤ t) (hs : b ≤ s.cfg.stop) : Pack P (drain s b).1 := by
  rw [drain_form]
  have hsplit := List.takeWhile_append_dropWhile (p := fun w : Wish => decide (w.arrives < b)) (l := s.wishes)
  exact pack_arrivals_aux hC b _ _ s hsplit.symm
    (fun x hx => by simpa using List.all_eq_true.1 List.all_takeWhile x hx) h hb hs

theorem pack_stepTick {P : Core → Prop} (hC : Closed P) (s : State) (time ms : Int) (h : Pack P s)
    (hn : s.nextTick = some time) (ht : s.cfg.tickMs = some ms) (hstop : time < s.cfg.stop) :
    Pack P (stepTick s time ms).1 := by
  have hd : Pack P (drain s time).1 := pack_drain hC s time h
    (fun t ht' => by rw [hn] at ht'; exact Int.le_of_eq (Option.some.inj ht')) (Int.le_of_lt hstop)
  obtain ⟨hS, hK, hI, hF, hP⟩ := hd
  have hn' : (drain s time).1.nextTick = some time := by rw [drain_nextTick]; exact hn
  have ht' : (drain s time).1.cfg.tickMs = some ms := by rw [drain_cfg]; exact ht
  have hms := hS.1 ms ht'
  refine ⟨Setup.of_cfg hS (by rw [stepTick_cfg, drain_cfg]), hK.of_cfg (by rw [stepTick_cfg, drain_cfg]), ?_, ?_, ?_⟩
  · have := stepTick_inv s time ms hn hms (let ⟨_, _, hI0, _⟩ := h; hI0)
    exact this
  · exact frontier_tick _ time ms hS hF hn' ht'
  · exact hC.tick _ time ms hS hI hF hP hn' ht' (by rw [drain_cfg]; exact hstop)

theorem ticksBefore_last (s : State) (b t ms : Int) (hn : s.nextTick = some t) (ht : s.cfg.tickMs = some ms)
    (hms : 0 < ms) (hpos : 0 < ticksBefore s b) : t + ((ticksBefore s b : Int) - 1) * ms < min b s.cfg.stop := by
  rw [ticksBefore_eq] at hpos ⊢
  simp only [hn, ht] at hpos ⊢
  unfold tickCount at hpos ⊢
  by_cases hlt : t < min b s.cfg.stop
  · simp only [hlt, ite_true] at hpos ⊢
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
    have e : (q - 1) * ms = q * ms - ms := by rw [Int.sub_mul, Int.one_mul]
    omega
  · simp only [hlt, ite_false] at hpos
    omega

theorem pack_fireR {P : Core → Prop} (hC : Closed P) (n : Nat) : ∀ s : State, Pack P s →
    (0 < n → ∀ t ms, s.nextTick = some t → s.cfg.tickMs = some ms → t + ((n : Int) - 1) * ms < s.cfg.stop) →
    Pack P (fireR n s).1 := by
  induction n with
  | zero => intro s h _; simpa [fireR_zero] using h
  | succ n ih =>
    intro s h hlast
    cases hn : s.nextTick with
    | none => rw [fireR_stuck _ s (Or.inl hn)]; exact h
    | some t =>
      cases ht : s.cfg.tickMs with
      | none => rw [fireR_stuck _ s (Or.inr ht)]; exact h
      | some ms =>
        rw [fireR_succ_some n s t ms hn ht]
        have hms := h.1.1 ms ht
        have hl := hlast (Nat.succ_pos n) t ms hn ht
        have hnn : (0 : Int) ≤ (n : Int) := Int.natCast_nonneg n
        have hmul : 0 ≤ (n : Int) * ms := Int.mul_nonneg hnn (Int.le_of_lt hms)
        have e : (((n + 1 : Nat) : Int) - 1) = (n : Int) := by push_cast; omega
        rw [e] at hl
        have hstop : t < s.cfg.stop := by omega
        refine ih _ (pack_stepTick hC s t ms h hn ht hstop) ?_
        intro hpos t' ms' hn' ht'
        rw [stepTick_nextTick] at hn'
        rw [stepTick_cfg] at ht' ⊢
        obtain rfl := Option.some.inj hn'
        rw [ht] at ht'
        obtain rfl := Option.some.inj ht'
        have e2 : t + ms + ((n : Int) - 1) * ms = t + (n : Int) * ms := by
          rw [Int.sub_mul, Int.one_mul]; omega
        rw [e2]
        exact hl

theorem pack_settleR {P : Core → Prop} (hC : Closed P) (s : State) (b : Int) (h : Pack P s) (hb : b ≤ s.cfg.stop) :
    Pack P (settleR s b).1 ∧ (∀ t, (settleR s b).1.nextTick = some t → b ≤ t) ∧
      ∀ w ∈ (settleR s b).1.wishes, b ≤ w.arrives := by
  have hf := pack_fireR hC (ticksBefore s b) s h (by
    intro hpos t ms hn ht
    have := ticksBefore_last s b t ms hn ht (h.1.1 ms ht) hpos
    have hm : min b s.cfg.stop = b := Int.min_eq_left hb
    omega)
  have hnext : ∀ t, (fireR (ticksBefore s b) s).1.nextTick = some t → b ≤ t := by
    intro t ht
    obtain ⟨hS, ⟨ms, hms⟩, hI, _⟩ := h
    cases hn : s.nextTick with
    | none => rw [fireR_stuck _ s (Or.inl hn)] at ht; simp [hn] at ht
    | some t0 =>
      obtain ⟨t', ht', hge⟩ := fireR_nextTick_ge s b t0 ms hn hms (hS.1 ms hms)
      rw [ht'] at ht
      obtain rfl := Option.some.inj ht
      have : min b s.cfg.stop = b := Int.min_eq_left hb
      omega
  have hd := pack_drain hC _ b hf hnext (by rw [fireR_cfg]; exact hb)
  refine ⟨hd, ?_, ?_⟩
  · intro t ht
    have : (settleR s b).1.nextTick = (fireR (ticksBefore s b) s).1.nextTick := by
      unfold settleR; exact drain_nextTick _ _
    rw [this] at ht
    exact hnext t ht
  · intro w hw
    have hI : WishInv (fireR (ticksBefore s b) s).1 := hf.2.2.1
    unfold settleR at hw
    have hws := drain_wishes (fireR (ticksBefore s b) s).1 b
    simp only [] at hw
    rw [hws] at hw
    exact dropWhile_ge b _ hI.1 w hw

theorem applyPayload_previous (s : State) (e : Event) (r : Reading) : (applyPayload s e r).1.previous = s.previous := by
  cases r with
  | listing rules => exact (emit_frame _ _ _).previous
  | ending price => simp only [applyPayload, withPending]; split <;> rfl
  | funding hour rate oracle => simp only [applyPayload, withPending]; split <;> rfl
  | trade id price size sizeScale seller => simp only [applyPayload, withPending]; split <;> rfl
  | quote bid bidSize ask askSize sizeScale => simp only [applyPayload, withPending]; split <;> rfl
  | observation source bits => simp only [applyPayload, withPending]; split <;> rfl

theorem applyPayload_core_other (s : State) (e : Event) (r : Reading) (h : ∀ rules, r ≠ .listing rules) :
    (applyPayload s e r).1.core = s.core := by
  cases r with
  | listing rules => exact absurd rfl (h rules)
  | ending price => simp only [applyPayload, withPending]; split <;> rfl
  | funding hour rate oracle => simp only [applyPayload, withPending]; split <;> rfl
  | trade id price size sizeScale seller => simp only [applyPayload, withPending]; split <;> rfl
  | quote bid bidSize ask askSize sizeScale => simp only [applyPayload, withPending]; split <;> rfl
  | observation source bits => simp only [applyPayload, withPending]; split <;> rfl

theorem pushHistory_core (s : State) (t : Int) : (pushHistory s t).core = s.core := by
  cases hl : s.log <;> simp [pushHistory, withLog, StateOf.core, hl, Log.core]

theorem pack_after {P : Core → Prop} (hC : Closed P) (u : State) (e : Event) (r : Reading) (h : Pack P u)
    (h1 : ∀ t, u.nextTick = some t → e.time ≤ t) (h2 : ∀ w ∈ u.wishes, e.time ≤ w.arrives)
    (h3 : ∀ q, u.previous = some q → q.time ≤ e.time) :
    Pack P (after u e r) := by
  have hk := applyPayload_keeps u e r
  have hp := applyPayload_previous u e r
  have hs2 : Pack P (applyPayload u e r).1 := by
    by_cases hl : ∃ rules, r = .listing rules
    · obtain ⟨rules, rfl⟩ := hl
      obtain ⟨hS, hK, hI, hF, hP⟩ := h
      have hI2 : WishInv (applyPayload u e (.listing rules)).1 := by
        refine ⟨by rw [hk.wishes]; exact hI.1, ?_⟩
        intro t ht w hw
        rw [hk.nextTick] at ht
        rw [hk.wishes] at hw
        rw [hk.cfg]
        exact hI.2 t ht w hw
      refine ⟨Setup.of_cfg hS hk.cfg, hK.of_cfg hk.cfg, hI2, frontier_keeps u _ hp hk.nextTick hk.wishes hF,
        hC.listing u e rules hS hI hF hP h1 h2⟩
    · have hne : ∀ rules, r ≠ .listing rules := fun rules hr => hl ⟨rules, hr⟩
      exact pack_core h (applyPayload_core_other u e r hne)
  have hs3 : Pack P (pushHistory (applyPayload u e r).1 e.time) := pack_core hs2 (pushHistory_core _ _)
  obtain ⟨hS, hK, hI, hF, hP⟩ := hs3
  have h1' : ∀ t, (pushHistory (applyPayload u e r).1 e.time).nextTick = some t → e.time ≤ t := by
    intro t ht
    apply h1 t
    have := hk.nextTick
    simpa [pushHistory, withLog, this] using ht
  have h2' : ∀ w ∈ (pushHistory (applyPayload u e r).1 e.time).wishes, e.time ≤ w.arrives := by
    intro w hw
    apply h2 w
    have := hk.wishes
    simpa [pushHistory, withLog, this] using hw
  have h3' : ∀ q, (pushHistory (applyPayload u e r).1 e.time).previous = some q → q.time ≤ e.time := by
    intro q hq
    apply h3 q
    have := hp
    simpa [pushHistory, withLog, this] using hq
  have hP' := hC.prev _ e hS hI hF hP h1' h2' h3'
  have hI' : WishInv ({ pushHistory (applyPayload u e r).1 e.time with previous := some e } : State) := hI
  have hpack : Pack P ({ pushHistory (applyPayload u e r).1 e.time with previous := some e } : State) :=
    ⟨hS, hK, hI', frontier_prev _ e h1' h2', hP'⟩
  exact pack_core hpack rfl

theorem fireR_previous (n : Nat) : ∀ s : State, (fireR n s).1.previous = s.previous := by
  induction n with
  | zero => intro s; simp [fireR_zero]
  | succ n ih =>
    intro s
    cases hn : s.nextTick with
    | none => rw [fireR_stuck _ s (Or.inl hn)]
    | some t =>
      cases ht : s.cfg.tickMs with
      | none => rw [fireR_stuck _ s (Or.inr ht)]
      | some ms =>
        rw [fireR_succ_some n s t ms hn ht, ih]
        have h1 : (stepTick s t ms).1.previous = s.previous := by
          simp only [stepTick, tickAt_previous]
          have := (drain_frame_wishes s t).previous
          simpa using this
        exact h1

theorem settleR_previous (s : State) (b : Int) : (settleR s b).1.previous = s.previous := by
  unfold settleR
  have := (drain_frame_wishes (fireR (ticksBefore s b) s).1 b).previous
  simp only [] at this ⊢
  rw [← fireR_previous (ticksBefore s b) s]
  exact this

theorem pack_advance {P : Core → Prop} (hC : Closed P) (s : State) (e : Event) (r : Reading) (h : Pack P s)
    (hb : e.time ≤ s.cfg.stop) (hpv : ∀ q, s.previous = some q → q.time ≤ e.time) : Pack P (advanceRec s e r).1 := by
  rw [advanceRec_state]
  obtain ⟨hp, h1, h2⟩ := pack_settleR hC s e.time h hb
  exact pack_after hC _ e r hp h1 h2 (by rw [settleR_previous]; exact hpv)

theorem pack_step {P : Core → Prop} (hC : Closed P) (s : State) (e : Event) (h : Pack P s) : Pack P (step s e).1 := by
  cases hr : s.rejected with
  | some f => rw [step_of_rejected s e f hr]; exact h
  | none =>
    cases ha : admit s e with
    | error fault =>
      rw [step_of_error s e fault hr ha]
      exact pack_core h rfl
    | ok reading =>
      rw [step_of_ok s e reading hr ha]
      have hb := (admit_ok_shape s e reading ha).1
      exact pack_advance hC s e reading h (Int.le_of_lt hb) (admit_ok_shape s e reading ha).2.1

theorem pack_goAcc {P : Core → Prop} (hC : Closed P) : ∀ (es : List Event) (s : State) (acc : Rows), Pack P s →
    Pack P (goAcc s es acc).1 := by
  intro es
  induction es with
  | nil => intro s acc h; exact h
  | cons e es ih => intro s acc h; exact ih _ _ (pack_step hC s e h)

theorem pack_feed {P : Core → Prop} (hC : Closed P) (s : State) (c : Chunk) (h : Pack P s) : Pack P (feed s c).1 := by
  cases hr : s.rejected with
  | some f =>
    have : feed s c = (s, Rows.empty) := by simp [feed, hr]
    rw [this]; exact h
  | none =>
    cases hd : decodeChunk s c with
    | error code =>
      have : feed s c = (s.reject code 0 "a chunk that does not decode", Rows.empty) := by simp [feed, hr, hd]
      rw [this]
      exact pack_core h rfl
    | ok events =>
      have : feed s c = goAcc s events Rows.empty := by simp [feed, hr, hd]
      rw [this]
      exact pack_goAcc hC events s Rows.empty h

theorem offer_fields (s : State) (coin slot : Nat) (parts : List (Nat × Rat)) (role : Engine.Ledger.Role) :
    (offer s coin slot parts role).1.cfg = s.cfg ∧ (offer s coin slot parts role).1.nextTick = s.nextTick ∧
      (offer s coin slot parts role).1.wishes = s.wishes ∧ (offer s coin slot parts role).1.previous = s.previous := by
  unfold offer
  cases offerPlan s coin slot parts with
  | none => exact ⟨rfl, rfl, rfl, rfl⟩
  | some p =>
    simp only []
    unfold applyOffer pushHistory withLog
    have h1 := emit_frame s p.time [Engine.World.Effect.fill p.order p.units p.price role]
    have h2 := emit_frame (emit s p.time [Engine.World.Effect.fill p.order p.units p.price role]).1 p.time
      ((if p.ends = true then ((emit s p.time [Engine.World.Effect.fill p.order p.units p.price role]).1.acct.orders.filter
        (·.coin == coin)).map fun o => Engine.World.Effect.cancelled o "cycle_end" else []) ++
        if p.ends = true then [Engine.World.Effect.cycleEnd coin (s.acct.cycle coin)] else [])
    exact ⟨by rw [h2.cfg, h1.cfg], by rw [h2.nextTick, h1.nextTick], by rw [h2.wishes, h1.wishes],
      by rw [h2.previous, h1.previous]⟩

theorem pack_offer {P : Core → Prop} (hC : Closed P) (s : State) (coin slot : Nat) (parts : List (Nat × Rat))
    (role : Engine.Ledger.Role) (h : Pack P s) : Pack P (offer s coin slot parts role).1 := by
  obtain ⟨hS, hK, hI, hF, hP⟩ := h
  obtain ⟨e1, e2, e3, e4⟩ := offer_fields s coin slot parts role
  refine ⟨Setup.of_cfg hS e1, hK.of_cfg e1, ⟨by rw [e3]; exact hI.1, ?_⟩, frontier_keeps s _ e4 e2 e3 hF,
    hC.offer s coin slot parts role hS hI hF hP⟩
  intro t ht w hw
  rw [e2] at ht
  rw [e3] at hw
  rw [e1]
  exact hI.2 t ht w hw

theorem pack_finishFull {P : Core → Prop} (hC : Closed P) (s : State) (h : Pack P s) : Pack P (finishFull s).1 := by
  cases hr : s.rejected with
  | some f =>
    have : finishFull s = (s, Rows.empty, "{\"error\":" ++ errorText f) := by simp [finishFull, hr]
    rw [this]; exact h
  | none =>
    have : (finishFull s).1 = (settle s s.cfg.stop Rows.empty).1 := by simp [finishFull, hr]
    rw [this, (settle_eq s s.cfg.stop Rows.empty).1]
    exact (pack_settleR hC s s.cfg.stop h (Int.le_refl _)).1

theorem pack_runMoves {P : Core → Prop} (hC : Closed P) (moves : List Move) : ∀ (s : State) (rows : Rows), Pack P s →
    Pack P (moves.foldl (fun (acc : State × Rows) move =>
      let next := match move with
        | .event e => feed acc.1 (pack [e])
        | .offer coin slot parts role => offer acc.1 coin slot parts role
      (next.1, acc.2 ++ next.2)) (s, rows)).1 := by
  induction moves with
  | nil => intro s rows h; exact h
  | cons m moves ih =>
    intro s rows h
    cases m with
    | event e => exact ih _ _ (pack_feed hC s _ h)
    | offer coin slot parts role => exact ih _ _ (pack_offer hC s coin slot parts role h)

theorem pack_start {P : Core → Prop} {program header : String} {initial : State}
    (h : start program header = .ok initial) (hP : P (initial.recast Engine.Lang.bitsOps).core) :
    Pack P (initial.recast Engine.Lang.bitsOps) := by
  obtain ⟨hS, hK, _, hI, _, hprev⟩ := start_facts h
  refine ⟨hS, hK, hI, ?_, hP⟩
  intro e he
  simp [StateOf.core, StateOf.recast, hprev] at he

theorem startsWith_error (x : String) : ("{\"error\":" ++ x).startsWith "{\"ok\":true" = false := by
  cases h : ("{\"error\":" ++ x).startsWith "{\"ok\":true"
  · rfl
  · exfalso
    simp only [String.startsWith_string_iff, String.toList_append] at h
    obtain ⟨t, ht⟩ := h
    have e1 : "{\"ok\":true".toList = ['{', '"', 'o', 'k', '"', ':', 't', 'r', 'u', 'e'] := by decide +kernel
    have e2 : "{\"error\":".toList = ['{', '"', 'e', 'r', 'r', 'o', 'r', '"', ':'] := by decide +kernel
    rw [e1, e2] at ht
    simp at ht

/-- What an instrumented run over bits ends in: the last state, holding every invariant a closed predicate keeps, with the
clock run to the horizon's end, and the log it made the run of. -/
theorem orderRun_pack {P : Core → Prop} (hC : Closed P) {program header : String} {initial : State}
    (h : start program header = .ok initial) (hP : P (initial.recast Engine.Lang.bitsOps).core)
    (moves : List Move) (run : Engine.Orders.Run) (hr : orderRun Engine.Lang.bitsOps initial moves = some run) :
    ∃ (final : State) (l : Log) (rows : Rows), Pack P final ∧ final.log = some l ∧ run = l.toRun rows ∧
      (∀ t, final.nextTick = some t → final.cfg.stop ≤ t) ∧ (∀ w ∈ final.wishes, final.cfg.stop ≤ w.arrives) ∧
      final = (finishFull (runMoves (initial.recast Engine.Lang.bitsOps) moves).1).1 := by
  have h0 := pack_start (P := P) h hP
  have h1 : Pack P (runMoves (initial.recast Engine.Lang.bitsOps) moves).1 :=
    pack_runMoves hC moves (initial.recast Engine.Lang.bitsOps) Rows.empty h0
  unfold orderRun at hr
  dsimp only at hr
  rcases hrm : runMoves (initial.recast Engine.Lang.bitsOps) moves with ⟨fed1, rows1⟩
  rw [hrm] at hr h1
  dsimp only at hr h1
  rcases hff : finishFull fed1 with ⟨final1, rest1, summary1⟩
  rw [hff] at hr
  dsimp only at hr
  cases hl : final1.log with
  | none => rw [hl] at hr; simp at hr
  | some l =>
    rw [hl] at hr
    dsimp only at hr
    split at hr
    · rename_i hsum
      injection hr with hr
      cases hrej : fed1.rejected with
      | some f =>
        exfalso
        have : finishFull fed1 = (fed1, Rows.empty, "{\"error\":" ++ errorText f) := by simp [finishFull, hrej]
        rw [hff] at this
        have hs : summary1 = "{\"error\":" ++ errorText f := by
          have := congrArg (fun x => x.2.2) this
          simpa using this
        rw [hs, startsWith_error] at hsum
        exact Bool.false_ne_true hsum
      | none =>
        have hfin : (finishFull fed1) = ((settle fed1 fed1.cfg.stop Rows.empty).1, (settle fed1 fed1.cfg.stop Rows.empty).2.1,
            "{\"ok\":" ++ okText (settle fed1 fed1.cfg.stop Rows.empty).1) := by simp [finishFull, hrej]
        rw [hff] at hfin
        have hfinal : final1 = (settleR fed1 fed1.cfg.stop).1 := by
          have := congrArg (fun x => x.1) hfin
          simp only [] at this
          rw [this, (settle_eq fed1 fed1.cfg.stop Rows.empty).1]
        obtain ⟨hp, hn, hw⟩ := pack_settleR hC fed1 fed1.cfg.stop h1 (Int.le_refl _)
        rw [← hfinal] at hp hn hw
        have hcfg : final1.cfg = fed1.cfg := by rw [hfinal]; exact settleR_cfg fed1 _
        refine ⟨final1, l, rows1 ++ rest1, hp, hl, hr.symm, ?_, ?_, ?_⟩
        · intro t ht; rw [hcfg]; exact hn t ht
        · intro w hw'; rw [hcfg]; exact hw w hw'
        · rfl
    · simp at hr

theorem Closed.and {P Q : Core → Prop} (hP : Closed P) (hQ : Closed Q) : Closed (fun c => P c ∧ Q c) where
  arrive := fun s w rest b hS hI hF h hb hn hs => ⟨hP.arrive s w rest b hS hI hF h.1 hb hn hs, hQ.arrive s w rest b hS hI hF h.2 hb hn hs⟩
  tick := fun s time ms hS hI hF h hn ht hs => ⟨hP.tick s time ms hS hI hF h.1 hn ht hs, hQ.tick s time ms hS hI hF h.2 hn ht hs⟩
  listing := fun s e rules hS hI hF h h1 h2 => ⟨hP.listing s e rules hS hI hF h.1 h1 h2, hQ.listing s e rules hS hI hF h.2 h1 h2⟩
  prev := fun s e hS hI hF h h1 h2 h3 => ⟨hP.prev s e hS hI hF h.1 h1 h2 h3, hQ.prev s e hS hI hF h.2 h1 h2 h3⟩
  offer := fun s coin slot parts role hS hI hF h => ⟨hP.offer s coin slot parts role hS hI hF h.1, hQ.offer s coin slot parts role hS hI hF h.2⟩

end Engine.Machine
