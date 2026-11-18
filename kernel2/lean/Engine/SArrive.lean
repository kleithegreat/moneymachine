import Engine.SMoves
import Engine.RInvArrival

/-!
# What an arrival writes in S1's lists (brief 3 step 5)
-/

namespace Engine.Machine

open Engine.World
open Engine.Orders (Wish Order Book Placement CycleStep arrive cancelSlot admission)

theorem foldl_cycles_noend (fees : List Engine.Ledger.Tier) (time : Int) :
    ∀ (es : List Effect) (a : Acct), (∀ e ∈ es, ∀ coin c, e ≠ .cycleEnd coin c) →
      (es.foldl (fun a e => a.apply fees time e) a).cycles = a.cycles := by
  intro es
  induction es with
  | nil => intro a _; rfl
  | cons e es ih =>
    intro a h
    simp only [List.foldl_cons]
    rw [ih _ (fun e' he' => h e' (List.mem_cons_of_mem _ he'))]
    exact apply_cycles_of_not_end _ _ _ e (h e (List.mem_cons_self ..))

theorem emit_cycles_noend (s : State) (t : Int) (es : List Effect) (h : ∀ e ∈ es, ∀ coin c, e ≠ .cycleEnd coin c) :
    (emit s t es).1.acct.cycles = s.acct.cycles := by
  rw [emit_acct]
  exact foldl_cycles_noend _ _ es _ h

theorem arrival_after_cycle (s : State) (w : Wish) (k : Nat) :
    (worldBook (emit s w.arrives (arrivalEffects (worldBook s w.arrives) w)).1 w.arrives).cycle k =
      (worldBook s w.arrives).cycle k := by
  rw [worldBook_cycle, worldBook_cycle, emit_cycles_noend _ _ _ (fun e he => (arrivalEffects_ok s w e he).1)]

theorem arrival_cycles (s : State) (w : Wish) : (arriveWish s w).1.acct.cycles = s.acct.cycles := by
  rw [arriveWish_acct]
  exact foldl_cycles_noend _ _ _ _ (fun e he => (arrivalEffects_ok s w e he).1)

theorem arrivalSteps_spec (s : State) (w : Wish) :
    arrivalSteps s w = [] ∨ arrivalSteps s w =
      [⟨worldBook s w.arrives, worldBook (emit s w.arrives (arrivalEffects (worldBook s w.arrives) w)).1 w.arrives, .other,
        w.arrives, []⟩] := by
  unfold arrivalSteps
  dsimp only
  by_cases h : (arrivalEffects (worldBook s w.arrives) w).isEmpty = true
  · left; simp [h]
  · right; simp [h]

theorem arrivalPlaced_spec (s : State) (w : Wish) : ∀ p ∈ arrivalPlaced s w, arrivalSteps s w ≠ [] ∧ p.order.coin = w.coin ∧
    p.order.cycle = w.cycle ∧ p.order.placed = w.arrives ∧ p.step = stepCount s ∧ w.cycle = s.acct.cycles.getD w.coin 0 := by
  intro p hp
  rcases arrival_logged s w with ⟨h1, _⟩ | ⟨o, r, h1, _⟩ | ⟨o, v, h1, h2, h3, h4, h5⟩
  · rw [h1] at hp; simp at hp
  · rw [h1] at hp; simp at hp
  · rw [h1] at hp
    simp only [List.mem_singleton] at hp
    subst hp
    have hc : (arrive (worldBook s w.arrives) w).2.contains "placed" = true := by
      by_cases hc : (arrive (worldBook s w.arrives) w).2.contains "placed" = true
      · exact hc
      · have : arrivalPlaced s w = [] := by
          unfold arrivalPlaced
          dsimp only
          simp only [Bool.not_eq_true] at hc
          simp only [hc, Bool.false_eq_true, ↓reduceIte]
        rw [h1] at this
        simp at this
    obtain ⟨_, _, hco, _⟩ := prepare_fields h4
    have hcy := prepare_cycle h4
    have htag : "placed" ∈ (arrive (worldBook s w.arrives) w).2 := List.mem_of_elem_eq_true hc
    have hne : (arrive (worldBook s w.arrives) w).2 ≠ [] := by
      intro h0; rw [h0] at htag; simp at htag
    have hg := arrive_guard _ _ hne
    have hwc : w.cycle = (worldBook s w.arrives).cycle w.coin := by
      by_cases hh : w.cycle = (worldBook s w.arrives).cycle w.coin
      · exact hh
      · exact absurd (Or.inr (Or.inl hh)) hg
    refine ⟨?_, hco, hcy, (prepare_fields h4).1, rfl, hwc⟩
    intro hs
    have hmem : Effect.placed o ∈ arrivalEffects (worldBook s w.arrives) w := by
      unfold arrivalEffects
      rw [List.mem_filterMap]
      refine ⟨"placed", htag, ?_⟩
      have e1 : ("placed" == "cancelled:replaced") = false := by decide
      simp [e1, h4]
    have hne' : (arrivalEffects (worldBook s w.arrives) w).isEmpty = false := by
      cases hh : (arrivalEffects (worldBook s w.arrives) w).isEmpty
      · rfl
      · exfalso
        have h0 := List.isEmpty_iff.1 hh
        rw [h0] at hmem
        simp at hmem
    unfold arrivalSteps at hs
    dsimp only at hs
    simp [hne'] at hs

theorem stepGood_other (b1 b2 : Book) (t : Int) (hc : ∀ k, b2.cycle k = b1.cycle k) :
    StepGood ⟨b1, b2, .other, t, []⟩ :=
  ⟨rfl, fun coin _ => by simp [hc], fun coin hcoin => absurd hcoin (by simp)⟩

theorem stepCount_of_log {α : Type} (s : StateOf α) (l : Log) (hs : s.log = some l) : stepCount s = l.steps.length := by
  simp [stepCount, hs]

theorem getElem?_append_lt {α : Type} (l m : List α) (j : Nat) (h : j < l.length) : (l ++ m)[j]? = l[j]? :=
  List.getElem?_append_left h

theorem sinv_arrive (s : State) (w : Wish) (rest : List Wish) (h : SInv ({ s with wishes := w :: rest } : State).core) :
    SInv ({ (arriveWish s w).1 with wishes := rest } : State).core := by
  have fr := arriveWish_frame s w
  have hcy : (arriveWish s w).1.acct.cycles = s.acct.cycles := arrival_cycles s w
  have hlog : ∀ l', ({ (arriveWish s w).1 with wishes := rest } : State).core.log = some l' →
      ∃ l : Log, ({ s with wishes := w :: rest } : State).core.log = some l.core ∧ s.log = some l ∧
        l'.steps = l.steps ++ arrivalSteps s w ∧ l'.placed = l.placed ++ arrivalPlaced s w ∧ l'.fills = l.fills := by
    intro l' hl'
    obtain ⟨l, hs, rfl⟩ := arrive_decomp s w rest l' hl'
    exact ⟨l, by simp [StateOf.core, hs], hs, rfl, rfl, rfl⟩
  have hacct : ({ (arriveWish s w).1 with wishes := rest } : State).core.acct.cycles = s.acct.cycles := hcy
  have hprev : ({ (arriveWish s w).1 with wishes := rest } : State).core.previous = s.previous := fr.previous
  have hnames : ({ (arriveWish s w).1 with wishes := rest } : State).core.cfg.names.length = s.cfg.names.length := by
    show (arriveWish s w).1.cfg.names.length = _
    rw [fr.cfg]
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro l' hl' st hst
    obtain ⟨l, hc, _, e1, _⟩ := hlog l' hl'
    rw [e1] at hst
    rcases List.mem_append.1 hst with hst | hst
    · exact h.steps l.core hc st hst
    · rcases arrivalSteps_spec s w with e | e
      · rw [e] at hst; simp at hst
      · rw [e] at hst
        simp only [List.mem_singleton] at hst
        subst hst
        exact stepGood_other _ _ _ (arrival_after_cycle s w)
  · intro l' hl' st hst k
    obtain ⟨l, hc, _, e1, _⟩ := hlog l' hl'
    rw [e1] at hst
    rw [hacct]
    rcases List.mem_append.1 hst with hst | hst
    · exact h.mono l.core hc st hst k
    · rcases arrivalSteps_spec s w with e | e
      · rw [e] at hst; simp at hst
      · rw [e] at hst
        simp only [List.mem_singleton] at hst
        subst hst
        show (worldBook (emit s w.arrives (arrivalEffects (worldBook s w.arrives) w)).1 w.arrives).cycle k ≤ _
        rw [arrival_after_cycle, worldBook_cycle]
        exact Nat.le_refl _
  · intro l' hl'
    obtain ⟨l, hc, _, e1, _⟩ := hlog l' hl'
    rw [e1]
    rcases arrivalSteps_spec s w with e | e
    · rw [e, List.append_nil]; exact h.chain l.core hc
    · rw [e, List.pairwise_append]
      refine ⟨h.chain l.core hc, by simp, ?_⟩
      intro a ha b hb
      simp only [List.mem_singleton] at hb
      subst hb
      intro k hk
      have hg := (h.steps l.core hc a ha)
      have h1 := (hg.2.2 k hk).2.1
      have h2 : a.after.cycle k ≤ s.acct.cycles.getD k 0 := h.mono l.core hc a ha k
      show a.before.cycle k < (worldBook s w.arrives).cycle k
      rw [worldBook_cycle]
      omega
  · intro l' hl'
    obtain ⟨l, hc, _, e1, _⟩ := hlog l' hl'
    rw [e1]
    rcases arrivalSteps_spec s w with e | e
    · rw [e, List.append_nil]; exact h.times l.core hc
    · rw [e, List.pairwise_append]
      refine ⟨h.times l.core hc, by simp, ?_⟩
      intro a ha b hb
      simp only [List.mem_singleton] at hb
      subst hb
      intro _ hne
      exact absurd rfl hne
  · intro l' hl' st hst hne
    obtain ⟨l, hc, _, e1, _⟩ := hlog l' hl'
    rw [e1] at hst
    rcases List.mem_append.1 hst with hst | hst
    · rw [hprev]; exact h.prevTime l.core hc st hst hne
    · rcases arrivalSteps_spec s w with e | e
      · rw [e] at hst; simp at hst
      · rw [e] at hst
        simp only [List.mem_singleton] at hst
        subst hst
        exact absurd rfl hne
  · intro l' hl' k hk K hK1 hK2
    obtain ⟨l, hc, _, e1, _⟩ := hlog l' hl'
    rw [hacct] at hK2
    rw [hnames] at hk
    obtain ⟨st, hst, hend, hbef⟩ := h.exist l.core hc k hk K hK1 hK2
    exact ⟨st, by rw [e1]; exact List.mem_append_left _ hst, hend, hbef⟩
  · intro l' hl' p hp j st hj hjp
    obtain ⟨l, hc, hs, e1, e2, _⟩ := hlog l' hl'
    rw [e2] at hp
    rw [e1] at hj
    rcases List.mem_append.1 hp with hp | hp
    · obtain ⟨st', hst', _⟩ := h.placedOwn l.core hc p hp
      have hlen : p.step < l.steps.length := (List.getElem?_eq_some_iff.1 hst').1
      rw [getElem?_append_lt _ _ _ (by omega)] at hj
      exact h.placedIdx l.core hc p hp j st hj hjp
    · obtain ⟨_, hcoin, hcyc, _, hstep, hwc⟩ := arrivalPlaced_spec s w p hp
      rw [stepCount_of_log s l hs] at hstep
      rw [hstep] at hjp
      rw [getElem?_append_lt _ _ _ hjp] at hj
      have := h.mono l.core hc st (List.mem_of_getElem? hj) p.order.coin
      rw [hcyc, hwc, ← hcoin] at *
      exact this
  · intro l' hl' p hp
    obtain ⟨l, hc, hs, e1, e2, _⟩ := hlog l' hl'
    rw [e2] at hp
    rw [e1]
    rcases List.mem_append.1 hp with hp | hp
    · obtain ⟨st', hst', hend⟩ := h.placedOwn l.core hc p hp
      have hlen : p.step < l.steps.length := (List.getElem?_eq_some_iff.1 hst').1
      exact ⟨st', by rw [getElem?_append_lt _ _ _ hlen]; exact hst', hend⟩
    · obtain ⟨hne, _, _, _, hstep, _⟩ := arrivalPlaced_spec s w p hp
      rw [stepCount_of_log s l hs] at hstep
      rcases arrivalSteps_spec s w with e | e
      · exact absurd e hne
      · refine ⟨⟨worldBook s w.arrives, worldBook (emit s w.arrives (arrivalEffects (worldBook s w.arrives) w)).1 w.arrives,
          .other, w.arrives, []⟩, ?_, rfl⟩
        rw [e, hstep]
        simp
  · intro l' hl' f hf j st hj hjf
    obtain ⟨l, hc, _, e1, _, e3⟩ := hlog l' hl'
    rw [e3] at hf
    rw [e1] at hj
    have hlen : f.step < l.steps.length := h.fillsOwn l.core hc f hf
    rw [getElem?_append_lt _ _ _ (by omega)] at hj
    exact h.fillsIdx l.core hc f hf j st hj hjf
  · intro l' hl' f hf
    obtain ⟨l, hc, _, e1, _, e3⟩ := hlog l' hl'
    rw [e3] at hf
    rw [e1]
    have : f.step < l.steps.length := h.fillsOwn l.core hc f hf
    simp only [List.length_append]
    omega
  · intro l' hl' f hf
    obtain ⟨l, hc, _, _, _, e3⟩ := hlog l' hl'
    rw [e3] at hf
    exact h.fillsGood l.core hc f hf

end Engine.Machine
