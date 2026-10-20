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
  · sorry

end Ref
