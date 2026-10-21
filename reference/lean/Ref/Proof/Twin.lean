import Ref.Proof.Tick
import Ref.Proof.Rewrite

/-! L3 for the rules that keep every node in place: the rewritten program ticks to the same machine. -/

namespace Ref

variable {α : Type} [Inhabited α]

/-- A node with its arguments renamed. -/
def Node.mapArgs (σ : Nat → Nat) : Node → Node
  | .op o args => .op o (args.map σ)
  | n => n

/-- Two loops over one list agree when their bodies agree on states the first keeps an invariant on. -/
theorem forIn_congr_inv {β σ : Type} (l : List β) (init : σ) (f g : β → σ → Id (ForInStep σ)) (I : σ → Prop)
    (h0 : I init) (hf : ∀ a ∈ l, ∀ x, I x → f a x = g a x ∧ ∃ y, f a x = .yield y ∧ I y) :
    forIn (m := Id) l init f = forIn (m := Id) l init g := by
  induction l generalizing init with
  | nil => rfl
  | cons a l ih =>
    obtain ⟨he, y, hy, hI⟩ := hf a (by simp) init h0
    rw [List.forIn_cons, List.forIn_cons, ← he, hy]
    exact ih y hI fun a' ha' => hf a' (by simp [ha'])

/-- Renaming a node's arguments to rows equal to theirs keeps its pointwise value. -/
theorem eval_mapArgs (N : NumOps α) {p p' : Program} {k : Nat} (σ : Nat → Nat)
    (hn : p'.nodes[k]! = p.nodes[k]!.mapArgs σ) (hpar : p'.params = p.params) {t : MState α}
    (hv : ∀ o args, p.nodes[k]! = .op o args → ∀ a ∈ args, t.vals[σ a]! = t.vals[a]!) (c : Nat) :
    MState.eval N p' t k c = MState.eval N p t k c := by
  unfold MState.eval
  rw [hn, hpar]
  cases h : p.nodes[k]! with
  | op o args =>
    have harg : ∀ k' : Nat, t.vals[(args.map σ)[k']!]![c]! = t.vals[args[k']!]![c]! := by
      intro k'
      by_cases hk : k' < args.length
      · rw [getElem!_pos (args.map σ) k' (by simpa using hk), List.getElem_map, getElem!_pos args k' hk,
          hv o args h _ (List.getElem_mem hk)]
      · rw [getElem!_neg (args.map σ) k' (by simpa using hk), getElem!_neg args k' hk]
    simp only [Node.mapArgs, harg]
  | _ => rfl

/-- p' is p with node i rewritten in place and its uses redirected to node j ≤ i (j = i: none redirected): the
nodes before agree, node i evaluates alike, and node j holds node i's value. -/
structure Twin (N : NumOps α) (p p' : Program) (i j : Nat) : Prop where
  wf : p.WF
  wf' : p'.WF
  ji : j ≤ i
  ilt : i < p.nodes.size
  size : p'.nodes.size = p.nodes.size
  params : p'.params = p.params
  others : ∀ k, k ≠ i → p'.nodes[k]! = p.nodes[k]!.mapArgs fun a => if a == i then j else a
  point : p.nodes[i]!.isPoint = true
  point' : p'.nodes[i]!.isPoint = true
  evalAt : ∀ (L : Array Bool) (m s : MState α), Done N p L m i s → ∀ c : Nat, L[c]! = true →
    MState.eval N p' s i c = MState.eval N p s i c
  identAt : j < i → ∀ (L : Array Bool) (m s : MState α), Done N p L m i s → ∀ c : Nat,
    (if L[c]! = true then (MState.eval N p s i c).bind N.keep else none) = s.vals[j]![c]!

/-- The loop invariant of a node's coin loop: the rows before it and the inputs stay as they were. -/
def Before (k : Nat) (s t : MState α) : Prop :=
  (∀ b < k, t.vals[b]! = s.vals[b]!) ∧ t.funding = s.funding ∧ t.bar = s.bar ∧ t.events = s.events ∧ t.hour = s.hour

theorem tickNode_twin {N : NumOps α} {p p' : Program} {i j : Nat} (T : Twin N p p' i j) (L : Array Bool) (hour : Int)
    (m : MState α) {k : Nat} (hk : k < p.nodes.size) {s : MState α} (hd : Done N p L m k s)
    (hid : i < k → s.vals[i]! = s.vals[j]!) :
    MState.tickNode N p' L hour k s = MState.tickNode N p L hour k s := by
  by_cases hki : k = i
  · subst hki
    have he : ∀ t, Before k s t → ∀ c, (if L[c]! = true then MState.eval N p' t k c else none) =
        (if L[c]! = true then MState.eval N p t k c else none) := by
      intro t ht c
      by_cases hl : L[c]! = true
      · simp only [hl, ite_true]
        rw [eval_rows N p' T.wf' (m₂ := s) (fun b hb => ht.1 b (by omega)) ht.2.1 ht.2.2.1 ht.2.2.2.1 ht.2.2.2.2,
          T.evalAt L m s hd c hl,
          eval_rows N p T.wf (m₂ := s) (fun b hb => ht.1 b (by omega)) ht.2.1 ht.2.2.1 ht.2.2.2.1 ht.2.2.2.2]
      · simp [hl]
    unfold MState.tickNode
    simp only [Std.Legacy.Range.forIn_eq_forIn_range']
    have hp := T.point; have hp' := T.point'
    split <;> rename_i hn' <;> (try (rw [hn'] at hp'; cases hp')) <;> split <;> rename_i hn <;>
      (try (rw [hn] at hp; cases hp))
    congr 1
    refine forIn_congr_inv _ _ _ _ (Before k s) ⟨fun _ _ => rfl, rfl, rfl, rfl, rfl⟩ fun c _ t ht => ⟨?_, _, rfl, ?_⟩
    · simp only [he t ht c]
    · exact ⟨fun b hb => by rw [modify_ne _ _ (by omega)]; exact ht.1 b hb, ht.2⟩
  · have hn := T.others k hki
    have hrow : ∀ o args, p.nodes[k]! = .op o args → ∀ t, Before k s t → ∀ a ∈ args,
        t.vals[if a == i then j else a]! = t.vals[a]! := by
      intro o args h t ht a ha
      have hak : a < k := (WF.op T.wf hk h).1 a ha
      by_cases hai : a = i
      · subst hai
        simp only [beq_self_eq_true, ite_true]
        rw [ht.1 _ (by have := T.ji; omega), ht.1 _ hak, hid hak]
      · simp [hai]
    have hev : ∀ t, Before k s t → ∀ c, MState.eval N p' t k c = MState.eval N p t k c := fun t ht c =>
      eval_mapArgs N _ hn T.params (fun o args h => hrow o args h t ht) c
    unfold MState.tickNode
    simp only [Std.Legacy.Range.forIn_eq_forIn_range']
    rw [hn]
    cases h : p.nodes[k]! with
    | op o args =>
      have hr := hrow o args h
      have hr0 : ∀ t, Before k s t → t.vals[(args.map fun a => if a == i then j else a)[0]!]! = t.vals[args[0]!]! := by
        intro t ht
        cases args with
        | nil => rfl
        | cons a _ => exact hr t ht a (by simp)
      simp only [Node.mapArgs]
      cases o <;> dsimp only
      all_goals first
        | (rw [hr0 s ⟨fun _ _ => rfl, rfl, rfl, rfl, rfl⟩]; done)
        | (congr 1
           exact forIn_congr_inv _ _ _ _ (Before k s) ⟨fun _ _ => rfl, rfl, rfl, rfl, rfl⟩ fun c _ t ht =>
             ⟨by simp only [hev t ht c], _, rfl,
               fun b hb => by rw [modify_ne _ _ (by omega)]; exact ht.1 b hb, ht.2⟩)
        | (congr 1
           refine forIn_congr_inv _ _ _ _ (Before k s) ⟨fun _ _ => rfl, rfl, rfl, rfl, rfl⟩ fun c _ t ht => ?_
           rw [hr0 t ht]
           refine ⟨rfl, ?_⟩
           split <;> (split <;> exact ⟨_, rfl, fun b hb => by rw [modify_ne _ _ (by omega)]; exact ht.1 b hb, ht.2⟩))
    | _ =>
      simp only [Node.mapArgs]
      congr 1
      refine forIn_congr_inv _ _ _ _ (Before k s) ⟨fun _ _ => rfl, rfl, rfl, rfl, rfl⟩ fun c _ t ht => ⟨?_, _, rfl, ?_⟩
      · simp only [hev t ht c]
      · exact ⟨fun b hb => by rw [modify_ne _ _ (by omega)]; exact ht.1 b hb, ht.2⟩

/-- Two loops over s, s+1, … agree, and the first keeps an invariant indexed by the next element. -/
theorem forIn_range_congr {σ : Type} (s n : Nat) (init : σ) (f g : Nat → σ → Id (ForInStep σ)) (I : Nat → σ → Prop)
    (h0 : I s init) (hf : ∀ k, s ≤ k → k < s + n → ∀ x, I k x → f k x = g k x ∧ ∃ y, f k x = .yield y ∧ I (k + 1) y) :
    forIn (m := Id) (List.range' s n) init f = forIn (m := Id) (List.range' s n) init g ∧
      I (s + n) (forIn (m := Id) (List.range' s n) init f) := by
  induction n generalizing s init with
  | zero => exact ⟨rfl, h0⟩
  | succ n ih =>
    obtain ⟨he, y, hy, hI⟩ := hf s (Nat.le_refl _) (by omega) init h0
    rw [List.range'_succ, List.forIn_cons, List.forIn_cons, ← he, hy]
    obtain ⟨e, h⟩ := ih (s + 1) y hI fun k h1 h2 x hx => hf k (by omega) (by omega) x hx
    refine ⟨e, ?_⟩
    rwa [show s + 1 + n = s + (n + 1) by omega] at h

theorem ext_bang {β : Type} [Inhabited β] {a b : Array β} (hs : a.size = b.size) (h : ∀ c : Nat, a[c]! = b[c]!) : a = b := by
  apply Array.ext hs
  intro c h₁ h₂
  have := h c
  rwa [getElem!_pos a c h₁, getElem!_pos b c h₂] at this

/-- The rewritten program ticks to the same machine, in which node i's row is node j's. -/
theorem tick_twin {N : NumOps α} {p p' : Program} {i j : Nat} (T : Twin N p p' i j) (L : Array Bool) (hour : Int)
    (m : MState α) (hs : Shape p L m) :
    m.tick N p' L hour = m.tick N p L hour ∧ (m.tick N p L hour).vals[i]! = (m.tick N p L hour).vals[j]! := by
  unfold MState.tick
  rw [T.size]
  simp only [Std.Legacy.Range.forIn_eq_forIn_range']
  rw [range_size]
  have := forIn_range_congr 0 p.nodes.size { m with hour := hour } (MState.tickNode N p L hour)
    (MState.tickNode N p' L hour)
    (fun k x => Done N p L m k x ∧ x.hour = hour ∧ (i < k → x.vals[i]! = x.vals[j]!))
    ⟨⟨⟨hs.size, hs.rows, hs.wins⟩, rfl, rfl, rfl, rfl, fun a ha => absurd ha (Nat.not_lt_zero a)⟩, rfl,
      fun h => absurd h (Nat.not_lt_zero i)⟩
    fun k _ hk x ⟨hd, hh, hid⟩ => by
      refine ⟨(tickNode_twin T L hour m (by omega) hd hid).symm, ?_⟩
      obtain ⟨y, hy, hd', hh', hrows⟩ := tickNode_spec N p T.wf L hour m (by omega) hd hh
      refine ⟨y, hy, hd', hh', fun hik => ?_⟩
      rcases Nat.lt_or_ge i k with hik' | hik'
      · rw [hrows i (by omega), hrows j (by have := T.ji; omega)]; exact hid hik'
      · obtain rfl : i = k := by omega
        rcases Nat.lt_or_ge j i with hji | hji
        · refine ext_bang (by rw [hd'.shape.rows i (by omega), hd'.shape.rows j (by omega)]) fun c => ?_
          obtain ⟨-, -, hpt⟩ := hd'.rows i (by omega) c
          rw [hpt T.point, hrows j (by omega)]
          rw [eval_rows N p T.wf (m₂ := x) (fun b hb => hrows b (by omega)) (hd'.funding.trans hd.funding.symm)
            (hd'.bar.trans hd.bar.symm) (hd'.events.trans hd.events.symm) (hh'.trans hh.symm)]
          exact T.identAt hji L m x hd c
        · obtain rfl : j = i := by have := T.ji; omega
          rfl
  rw [← this.1]
  exact ⟨rfl, this.2.2.2 (by simpa using T.ilt)⟩

end Ref
