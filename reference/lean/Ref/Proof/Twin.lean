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

theorem isPoint_mapArgs (σ : Nat → Nat) (n : Node) : (n.mapArgs σ).isPoint = n.isPoint := by
  cases n with
  | op o args => cases o <;> rfl
  | _ => rfl

theorem mapArgs_self (i : Nat) (n : Node) : n.mapArgs (fun a => if a == i then i else a) = n := by
  cases n with
  | op o args =>
    simp only [Node.mapArgs, Node.op.injEq, true_and]
    induction args with
    | nil => rfl
    | cons a t ih => simp only [List.map_cons, ih]; by_cases h : a = i <;> simp [h]
  | _ => rfl

theorem redirect_node (p : Program) (i j k : Nat) :
    (p.redirect i j).nodes[k]! = p.nodes[k]!.mapArgs fun a => if a == i then j else a := by
  unfold Program.redirect
  rcases Nat.lt_or_ge k p.nodes.size with hk | hk
  · rw [getElem!_pos _ k (by simpa using hk), Array.getElem_map, getElem!_pos p.nodes k hk]
    cases p.nodes[k] <;> rfl
  · rw [getElem!_neg _ k (by simp; omega), getElem!_neg p.nodes k (by omega)]; rfl

/-- A redirect of node i's uses to node j is a twin when node j holds node i's value. -/
theorem twin_redirect (N : NumOps α) {p : Program} (hp : p.WF) {i j : Nat} (hi : i < p.nodes.size) (hji : j < i)
    (ht : p.types[j]! = p.types[i]!) (hpt : p.nodes[i]!.isPoint = true)
    (hid : ∀ (L : Array Bool) (m s : MState α), Done N p L m i s → ∀ c : Nat,
      (if L[c]! = true then (MState.eval N p s i c).bind N.keep else none) = s.vals[j]![c]!) :
    Twin N p (p.redirect i j) i j where
  wf := hp
  wf' := redirect_wf hp hji hi ht
  ji := Nat.le_of_lt hji
  ilt := hi
  size := by simp [Program.redirect]
  params := rfl
  others k _ := redirect_node p i j k
  point := hpt
  point' := by rw [redirect_node, isPoint_mapArgs]; exact hpt
  evalAt L m s hd c _ := by
    refine eval_mapArgs N _ (redirect_node p i j i) rfl (fun o args h a ha => ?_) c
    have := (WF.op hp hi h).1 a ha
    simp [show a ≠ i by omega]
  identAt _ := hid

omit [Inhabited α] in
/-- Replacing node i by a node of its type that evaluates alike is a twin. -/
theorem twin_set (N : NumOps α) {p : Program} (hp : p.WF) {i : Nat} (hi : i < p.nodes.size) {o : Op} {args : List Nat}
    (ha : ∀ a ∈ args, a < i) (ht : opTy o (args.map (p.types[·]!)) p.convTo[i]! = some p.types[i]!)
    (hpt : p.nodes[i]!.isPoint = true) (hpt' : (Node.op o args).isPoint = true)
    (hev : ∀ (L : Array Bool) (m s : MState α), Done N p L m i s → ∀ c : Nat, L[c]! = true →
      MState.eval N { p with nodes := p.nodes.set! i (.op o args) } s i c = MState.eval N p s i c) :
    Twin N p { p with nodes := p.nodes.set! i (.op o args) } i i where
  wf := hp
  wf' := set_wf hp hi ha ht
  ji := Nat.le_refl i
  ilt := hi
  size := by simp
  params := rfl
  others k hk := by
    show (p.nodes.set! i (.op o args))[k]! = _
    rw [Array.getElem!_set!_ne _ _ _ _ (Ne.symm hk), mapArgs_self]
  point := hpt
  point' := by
    show (p.nodes.set! i (.op o args))[i]!.isPoint = true
    rw [Array.getElem!_set!_self _ _ _ hi]; exact hpt'
  evalAt := hev
  identAt h := absurd h (Nat.lt_irrefl i)

/-! Each rule's identity at node i, on the rows a tick has written before it. -/

theorem keep_fin {N : NumOps α} {v : Val α} (h : Fin N v) : v.bind N.keep = v := by
  rcases h with rfl | ⟨x, rfl, hx⟩
  · rfl
  · simp [NumOps.keep, hx]

theorem row_listed {N : NumOps α} {p : Program} {L : Array Bool} {m s : MState α} {k a : Nat} (hd : Done N p L m k s)
    (ha : a < k) (hpt : p.nodes[a]!.isPoint = true) {c : Nat} (hl : L[c]! = true) :
    s.vals[a]![c]! = (MState.eval N p s a c).bind N.keep := by
  rw [(hd.rows a ha c).2.2 hpt, hl]; rfl

theorem negNeg_ident (N : NumOps α) (hN : N.Lawful) {p : Program} (hp : p.WF) {i a x : Nat}
    (hn : p.nodes[i]! = .op .neg [a]) (hx : p.nodes[a]! = .op .neg [x]) (L : Array Bool) (m s : MState α)
    (hd : Done N p L m i s) (c : Nat) :
    (if L[c]! = true then (MState.eval N p s i c).bind N.keep else none) = s.vals[x]![c]! := by
  have hai : a < i := (WF.op hp (op_lt hn) hn).1 a (by simp)
  have hxa : x < a := (WF.op hp (op_lt hx) hx).1 x (by simp)
  obtain ⟨hfx, hux, -⟩ := hd.rows x (by omega) c
  cases hl : L[c]!
  · simp [hux hl]
  · simp only [ite_true]
    simp only [MState.eval, hn, List.getElem!_cons_zero]
    rw [row_listed hd hai (by rw [hx]; rfl) hl]
    simp only [MState.eval, hx, List.getElem!_cons_zero]
    rcases hfx with h | ⟨v, h, hv⟩ <;> rw [h]
    · rfl
    · simp [NumOps.keep, hv, hN.finite_neg v hv, hN.neg_neg v hv]

theorem absAbs_ident (N : NumOps α) (hN : N.Lawful) {p : Program} (hp : p.WF) {i a y : Nat}
    (hn : p.nodes[i]! = .op .abs [a]) (hy : p.nodes[a]! = .op .abs [y]) (L : Array Bool) (m s : MState α)
    (hd : Done N p L m i s) (c : Nat) :
    (if L[c]! = true then (MState.eval N p s i c).bind N.keep else none) = s.vals[a]![c]! := by
  have hai : a < i := (WF.op hp (op_lt hn) hn).1 a (by simp)
  have hya : y < a := (WF.op hp (op_lt hy) hy).1 y (by simp)
  obtain ⟨hfy, -, -⟩ := hd.rows y (by omega) c
  cases hl : L[c]!
  · simp [(hd.rows a hai c).2.1 hl]
  · simp only [ite_true, MState.eval, hn, List.getElem!_cons_zero]
    rw [row_listed hd hai (by rw [hy]; rfl) hl]
    simp only [MState.eval, hy, List.getElem!_cons_zero]
    rcases hfy with h | ⟨v, h, hv⟩ <;> rw [h]
    · rfl
    · simp [NumOps.keep, hv, hN.finite_abs v hv, hN.abs_abs v hv]

/-- A constant node's row, where listed: its value, finite under the obligations. -/
theorem const_row {N : NumOps α} {p : Program} {L : Array Bool} {m s : MState α} {k b : Nat} (hd : Done N p L m k s)
    (hb : b < k) {bits : UInt64} {u : Dim} (hn : p.nodes[b]! = .const bits u) (hf : N.finite (N.ofBits bits) = true)
    {c : Nat} (hl : L[c]! = true) : s.vals[b]![c]! = some (N.ofBits bits) := by
  rw [row_listed hd hb (by rw [hn]; rfl) hl]
  simp [MState.eval, hn, NumOps.keep, hf]

theorem mulOne_ident (N : NumOps α) (hN : N.Lawful) {p : Program} (hp : p.WF) {i x k : Nat}
    (hn : p.nodes[i]! = .op .mul [x, k]) (hk : p.nodes[k]! = .const 0x3FF0000000000000 Dim.one)
    (L : Array Bool) (m s : MState α) (hd : Done N p L m i s) (c : Nat) :
    (if L[c]! = true then (MState.eval N p s i c).bind N.keep else none) = s.vals[x]![c]! := by
  have hxi : x < i := (WF.op hp (op_lt hn) hn).1 x (by simp)
  have hki : k < i := (WF.op hp (op_lt hn) hn).1 k (by simp)
  obtain ⟨hfx, hux, -⟩ := hd.rows x hxi c
  cases hl : L[c]!
  · simp [hux hl]
  · simp only [ite_true, MState.eval, hn, List.getElem!_cons_zero, List.getElem!_cons_succ,
      const_row hd hki hk hN.finite_one hl]
    rcases hfx with h | ⟨v, h, hv⟩ <;> rw [h]
    · rfl
    · simp [NumOps.keep, hv, hN.mul_one v hv]

theorem divOne_ident (N : NumOps α) (hN : N.Lawful) {p : Program} (hp : p.WF) {i x k : Nat}
    (hn : p.nodes[i]! = .op .div [x, k]) (hk : p.nodes[k]! = .const 0x3FF0000000000000 Dim.one)
    (L : Array Bool) (m s : MState α) (hd : Done N p L m i s) (c : Nat) :
    (if L[c]! = true then (MState.eval N p s i c).bind N.keep else none) = s.vals[x]![c]! := by
  have hxi : x < i := (WF.op hp (op_lt hn) hn).1 x (by simp)
  have hki : k < i := (WF.op hp (op_lt hn) hn).1 k (by simp)
  obtain ⟨hfx, hux, -⟩ := hd.rows x hxi c
  cases hl : L[c]!
  · simp [hux hl]
  · simp only [ite_true, MState.eval, hn, List.getElem!_cons_zero, List.getElem!_cons_succ,
      const_row hd hki hk hN.finite_one hl]
    rcases hfx with h | ⟨v, h, hv⟩ <;> rw [h]
    · simp [hN.one_ne_zero]
    · simp [NumOps.keep, hv, hN.one_ne_zero, hN.div_one v hv]

theorem subZero_ident (N : NumOps α) (hN : N.Lawful) {p : Program} (hp : p.WF) {i x k : Nat} {u : Dim}
    (hn : p.nodes[i]! = .op .sub [x, k]) (hk : p.nodes[k]! = .const 0 u)
    (L : Array Bool) (m s : MState α) (hd : Done N p L m i s) (c : Nat) :
    (if L[c]! = true then (MState.eval N p s i c).bind N.keep else none) = s.vals[x]![c]! := by
  have hxi : x < i := (WF.op hp (op_lt hn) hn).1 x (by simp)
  have hki : k < i := (WF.op hp (op_lt hn) hn).1 k (by simp)
  obtain ⟨hfx, hux, -⟩ := hd.rows x hxi c
  cases hl : L[c]!
  · simp [hux hl]
  · simp only [ite_true, MState.eval, hn, List.getElem!_cons_zero, List.getElem!_cons_succ,
      const_row hd hki hk hN.finite_zero hl]
    rcases hfx with h | ⟨v, h, hv⟩ <;> rw [h]
    · rfl
    · simp [NumOps.keep, hv, hN.sub_zero v hv]

/-- A boolean value: Undef, 0 or 1. -/
def Truthy (N : NumOps α) (v : Val α) : Prop := v = none ∨ ∃ b, v = some (N.truth b)

theorem truthy_keep {N : NumOps α} (hN : N.Lawful) {v : Val α} (h : Truthy N v) : Truthy N (v.bind N.keep) := by
  rcases h with rfl | ⟨b, rfl⟩
  · exact Or.inl rfl
  · exact Or.inr ⟨b, by simp [NumOps.keep, hN.finite_truth b]⟩

theorem opTy_ite_bool {ts : List Ty} {to : Option Dim} (h : opTy .ite ts to = some .bool) :
    ts[1]? = some .bool ∧ ts[2]? = some .bool := by
  simp only [opTy] at h
  (repeat' split at h) <;> simp_all

/-- An operator typed boolean is a comparison, a connective or an `if`. -/
theorem opTy_bool {o : Op} {ts : List Ty} {to : Option Dim} (h : opTy o ts to = some .bool) :
    o = .gt ∨ o = .ge ∨ o = .lt ∨ o = .le ∨ o = .and ∨ o = .or ∨ o = .not ∨ o = .ite := by
  cases o <;> simp only [reduceCtorEq, or_self, or_false, false_or, true_or, or_true] <;>
    simp only [opTy, Option.bind_eq_bind] at h <;>
    (repeat' split at h) <;> simp_all [Option.bind_eq_some_iff]

/-- A boolean-typed row a tick has written holds Undef, 0 or 1. -/
theorem canon_row (N : NumOps α) (hN : N.Lawful) {p : Program} (hp : p.WF) {L : Array Bool} {m s : MState α} {k : Nat}
    (hd : Done N p L m k s) : ∀ a < k, p.types[a]! = .bool → ∀ c : Nat, Truthy N (s.vals[a]![c]!) := by
  intro a
  induction a using Nat.strongRecOn with
  | ind a ih =>
  intro hak hty c
  have ha : a < p.nodes.size := by
    rcases Nat.lt_or_ge a p.nodes.size with h | h
    · exact h
    · rw [getElem!_neg p.types a (by have := hp.1; omega)] at hty; cases hty
  have hw := hp.2.2.2.2.2 a ha
  cases hl : L[c]!
  · exact Or.inl ((hd.rows a hak c).2.1 hl)
  cases hn : p.nodes[a]! with
  | input inp => rw [hn] at hw; rw [hw] at hty; cases hty
  | const _ u => rw [hn] at hw; rw [hw] at hty; cases hty
  | param k' => rw [hn] at hw; rw [hw.2] at hty; cases hty
  | op o args =>
    rw [hn] at hw
    obtain ⟨hargs, hop⟩ := hw
    rw [hty] at hop
    have hrow := row_listed hd hak (k := k) (a := a) (c := c)
    rcases opTy_bool hop with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
    rotate_left 7
    all_goals first
      | (rw [hrow (by rw [hn]; try rfl) hl]
         apply truthy_keep hN
         simp only [MState.eval, hn]
         generalize s.vals[args[0]!]![c]! = A
         generalize s.vals[args[1]!]![c]! = B
         cases A <;> cases B <;> first | exact Or.inl rfl | exact Or.inr ⟨_, rfl⟩)
      | (rw [hrow (by rw [hn]; try rfl) hl]
         apply truthy_keep hN
         simp only [MState.eval, hn]
         generalize s.vals[args[0]!]![c]! = A
         cases A <;> first | exact Or.inl rfl | exact Or.inr ⟨_, rfl⟩)
      | skip
    · rw [hrow (by rw [hn]; try rfl) hl]
      apply truthy_keep hN
      obtain ⟨h1, h2⟩ := opTy_ite_bool hop
      simp only [List.getElem?_map, Option.map_eq_some_iff] at h1 h2
      obtain ⟨b1, hb1, ht1⟩ := h1
      obtain ⟨b2, hb2, ht2⟩ := h2
      have e1 : args[1]! = b1 := by rw [getElem!_def, hb1]; try rfl
      have e2 : args[2]! = b2 := by rw [getElem!_def, hb2]; try rfl
      have l1 : b1 < a := hargs b1 (List.mem_of_getElem? hb1)
      have l2 : b2 < a := hargs b2 (List.mem_of_getElem? hb2)
      have t1 := ih b1 l1 (by omega) ht1 c
      have t2 := ih b2 l2 (by omega) ht2 c
      simp only [MState.eval, hn, e1, e2]
      generalize s.vals[args[0]!]![c]! = A
      cases A with
      | none => exact Or.inl rfl
      | some x => dsimp only [bind, Option.bind]; split <;> assumption

theorem notNot_ident (N : NumOps α) (hN : N.Lawful) {p : Program} (hp : p.WF) {i a b : Nat}
    (hn : p.nodes[i]! = .op .not [a]) (ha : p.nodes[a]! = .op .not [b]) (L : Array Bool) (m s : MState α)
    (hd : Done N p L m i s) (c : Nat) :
    (if L[c]! = true then (MState.eval N p s i c).bind N.keep else none) = s.vals[b]![c]! := by
  have hai : a < i := (WF.op hp (op_lt hn) hn).1 a (by simp)
  have hba : b < a := (WF.op hp (op_lt ha) ha).1 b (by simp)
  have hbt : p.types[b]! = .bool := by
    have := (WF.op hp (op_lt ha) ha).2
    simp only [List.map_cons, List.map_nil] at this
    exact (opTy_not this).1
  cases hl : L[c]!
  · simp [(hd.rows b (by omega) c).2.1 hl]
  · simp only [ite_true, MState.eval, hn, List.getElem!_cons_zero]
    rw [row_listed hd hai (by rw [ha]; try rfl) hl]
    simp only [MState.eval, ha, List.getElem!_cons_zero]
    rcases canon_row N hN hp hd b (by omega) hbt c with h | ⟨t, h⟩ <;> rw [h]
    · rfl
    · cases t <;> simp [NumOps.keep, hN.finite_truth, hN.truth_zero]

theorem comm_eval (N : NumOps α) (hN : N.Lawful) {p : Program} {i a b : Nat} {o : Op}
    (ho : o = .add ∨ o = .mul ∨ o = .and ∨ o = .or) (hi : i < p.nodes.size) (hn : p.nodes[i]! = .op o [a, b])
    (s : MState α) (c : Nat) :
    MState.eval N { p with nodes := p.nodes.set! i (.op o [b, a]) } s i c = MState.eval N p s i c := by
  rcases ho with rfl | rfl | rfl | rfl <;>
    simp only [MState.eval, hn, Array.getElem!_set!_self _ _ _ hi, List.getElem!_cons_zero, List.getElem!_cons_succ] <;>
    generalize s.vals[a]![c]! = A <;> generalize s.vals[b]![c]! = B <;> cases A <;> cases B <;>
    simp [hN.add_comm, hN.mul_comm, Bool.and_comm, Bool.or_comm]

theorem flip_eval (N : NumOps α) {p : Program} {i a b : Nat} {o o' : Op}
    (ho : (o = .gt ∧ o' = .lt) ∨ (o = .lt ∧ o' = .gt) ∨ (o = .ge ∧ o' = .le) ∨ (o = .le ∧ o' = .ge))
    (hi : i < p.nodes.size) (hn : p.nodes[i]! = .op o [a, b]) (s : MState α) (c : Nat) :
    MState.eval N { p with nodes := p.nodes.set! i (.op o' [b, a]) } s i c = MState.eval N p s i c := by
  rcases ho with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
    simp only [MState.eval, hn, Array.getElem!_set!_self _ _ _ hi, List.getElem!_cons_zero, List.getElem!_cons_succ] <;>
    generalize s.vals[a]![c]! = A <;> generalize s.vals[b]![c]! = B <;> cases A <;> cases B <;> rfl

theorem absNeg_eval (N : NumOps α) (hN : N.Lawful) {p : Program} (hp : p.WF) {i a x : Nat}
    (hn : p.nodes[i]! = .op .abs [a]) (ha : p.nodes[a]! = .op .neg [x]) (L : Array Bool) (m s : MState α)
    (hd : Done N p L m i s) (c : Nat) (hl : L[c]! = true) :
    MState.eval N { p with nodes := p.nodes.set! i (.op .abs [x]) } s i c = MState.eval N p s i c := by
  have hi := op_lt hn
  have hai : a < i := (WF.op hp hi hn).1 a (by simp)
  have hxa : x < a := (WF.op hp (op_lt ha) ha).1 x (by simp)
  simp only [MState.eval, hn, Array.getElem!_set!_self _ _ _ hi, List.getElem!_cons_zero]
  rw [row_listed hd hai (by rw [ha]; try rfl) hl]
  simp only [MState.eval, ha, List.getElem!_cons_zero]
  rcases (hd.rows x (by omega) c).1 with h | ⟨v, h, hv⟩ <;> rw [h]
  · rfl
  · simp [NumOps.keep, hN.finite_neg v hv, hN.abs_neg v hv]

theorem ifNot_eval (N : NumOps α) (hN : N.Lawful) {p : Program} (hp : p.WF) {i nc a b c₀ : Nat}
    (hn : p.nodes[i]! = .op .ite [nc, a, b]) (hc : p.nodes[nc]! = .op .not [c₀]) (L : Array Bool) (m s : MState α)
    (hd : Done N p L m i s) (c : Nat) (hl : L[c]! = true) :
    MState.eval N { p with nodes := p.nodes.set! i (.op .ite [c₀, b, a]) } s i c = MState.eval N p s i c := by
  have hi := op_lt hn
  have hnci : nc < i := (WF.op hp hi hn).1 nc (by simp)
  simp only [MState.eval, hn, Array.getElem!_set!_self _ _ _ hi, List.getElem!_cons_zero, List.getElem!_cons_succ]
  rw [row_listed hd hnci (by rw [hc]; try rfl) hl]
  simp only [MState.eval, hc, List.getElem!_cons_zero]
  generalize s.vals[c₀]![c]! = C
  cases C with
  | none => rfl
  | some v =>
    simp only [NumOps.keep, hN.finite_truth, Option.bind_some, ite_true, bind, Option.bind, hN.truth_zero]
    cases N.isZero v <;> rfl

/-- Every rule but `ifNotRev` rewrites node i in place: the result is a twin. -/
theorem apply_twin (N : NumOps α) (hN : N.Lawful) {r : Rule} {p p' : Program} {i : Nat} (hp : p.WF)
    (h : r.apply p i = some p') (hr : r ≠ .ifNotRev) : ∃ j, Twin N p p' i j := by
  unfold Rule.apply at h
  split at h
  next _ _ a hn =>
    split at h
    next x hx =>
      cases h
      have hi := op_lt hn; have ha := op_lt hx
      obtain ⟨hai, hti⟩ := WF.op hp hi hn
      obtain ⟨hxa, hta⟩ := WF.op hp ha hx
      simp only [List.mem_singleton, forall_eq, List.map_cons, List.map_nil] at hai hxa hti hta
      have h1 := opTy_unary (Or.inl rfl) hti; have h2 := opTy_unary (Or.inl rfl) hta
      exact ⟨x, twin_redirect N hp hi (by omega) (by rw [h1, h2]) (by rw [hn]; try rfl) (negNeg_ident N hN hp hn hx)⟩
    next => cases h
  next _ _ a hn =>
    split at h
    next y hx =>
      cases h
      have hi := op_lt hn
      obtain ⟨hai, hti⟩ := WF.op hp hi hn
      simp only [List.mem_singleton, forall_eq, List.map_cons, List.map_nil] at hai hti
      exact ⟨a, twin_redirect N hp hi hai (opTy_unary (Or.inr rfl) hti).symm (by rw [hn]; try rfl)
        (absAbs_ident N hN hp hn hx)⟩
    next => cases h
  next _ _ a hn =>
    split at h
    next x hx =>
      cases h
      have hi := op_lt hn; have ha := op_lt hx
      obtain ⟨hai, hti⟩ := WF.op hp hi hn
      obtain ⟨hxa, hta⟩ := WF.op hp ha hx
      simp only [List.mem_singleton, forall_eq, List.map_cons, List.map_nil] at hai hxa hti hta
      refine ⟨i, twin_set N hp hi (by simp; omega) ?_ (by rw [hn]; try rfl) rfl (absNeg_eval N hN hp hn hx)⟩
      simp only [List.map_cons, List.map_nil]
      rw [← opTy_unary (Or.inl rfl) hta]; exact hti
    next => cases h
  next _ _ x c hn =>
    split at h
    next hc =>
      cases h
      have hi := op_lt hn
      obtain ⟨hai, hti⟩ := WF.op hp hi hn
      simp only [List.map_cons, List.map_nil, WF.const hp (isConst_eq hc)] at hti
      exact ⟨x, twin_redirect N hp hi (hai x (by simp)) (opTy_one (Or.inl rfl) hti).symm (by rw [hn]; try rfl)
        (mulOne_ident N hN hp hn (isConst_eq hc))⟩
    next => cases h
  next _ _ x c hn =>
    split at h
    next hc =>
      cases h
      have hi := op_lt hn
      obtain ⟨hai, hti⟩ := WF.op hp hi hn
      simp only [List.map_cons, List.map_nil, WF.const hp (isConst_eq hc)] at hti
      exact ⟨x, twin_redirect N hp hi (hai x (by simp)) (opTy_one (Or.inr rfl) hti).symm (by rw [hn]; try rfl)
        (divOne_ident N hN hp hn (isConst_eq hc))⟩
    next => cases h
  next _ _ x c hn =>
    split at h
    next u hu =>
      split at h
      next hc =>
        cases h
        have hi := op_lt hn
        obtain ⟨hai, hti⟩ := WF.op hp hi hn
        simp only [List.map_cons, List.map_nil, WF.const hp (isConst_eq hc)] at hti
        exact ⟨x, twin_redirect N hp hi (hai x (by simp)) (opTy_sub hu hti).symm (by rw [hn]; try rfl)
          (subZero_ident N hN hp hn (isConst_eq hc))⟩
      next => cases h
    next => cases h
  next _ _ a b hn =>
    cases h
    have hi := op_lt hn
    obtain ⟨hai, hti⟩ := WF.op hp hi hn
    simp only [List.map_cons, List.map_nil] at hti
    exact ⟨i, twin_set N hp hi (fun x hx => hai x (by simp at hx ⊢; omega)) (by simpa using opTy_comm (by simp) hti)
      (by rw [hn]; try rfl) rfl fun L m s hd c hl => comm_eval N hN (by simp) hi hn s c⟩
  next _ _ a b hn =>
    cases h
    have hi := op_lt hn
    obtain ⟨hai, hti⟩ := WF.op hp hi hn
    simp only [List.map_cons, List.map_nil] at hti
    exact ⟨i, twin_set N hp hi (fun x hx => hai x (by simp at hx ⊢; omega)) (by simpa using opTy_comm (by simp) hti)
      (by rw [hn]; try rfl) rfl fun L m s hd c hl => comm_eval N hN (by simp) hi hn s c⟩
  next _ _ a b hn =>
    cases h
    have hi := op_lt hn
    obtain ⟨hai, hti⟩ := WF.op hp hi hn
    simp only [List.map_cons, List.map_nil] at hti
    exact ⟨i, twin_set N hp hi (fun x hx => hai x (by simp at hx ⊢; omega)) (by simpa using opTy_comm (by simp) hti)
      (by rw [hn]; try rfl) rfl fun L m s hd c hl => comm_eval N hN (by simp) hi hn s c⟩
  next _ _ a b hn =>
    cases h
    have hi := op_lt hn
    obtain ⟨hai, hti⟩ := WF.op hp hi hn
    simp only [List.map_cons, List.map_nil] at hti
    exact ⟨i, twin_set N hp hi (fun x hx => hai x (by simp at hx ⊢; omega)) (by simpa using opTy_comm (by simp) hti)
      (by rw [hn]; try rfl) rfl fun L m s hd c hl => comm_eval N hN (by simp) hi hn s c⟩
  next _ _ a hn =>
    split at h
    next c hc =>
      cases h
      have hi := op_lt hn; have ha := op_lt hc
      obtain ⟨hai, hti⟩ := WF.op hp hi hn
      obtain ⟨hca, hta⟩ := WF.op hp ha hc
      simp only [List.mem_singleton, forall_eq, List.map_cons, List.map_nil] at hai hca hti hta
      exact ⟨c, twin_redirect N hp hi (by omega) (by rw [(opTy_not hti).2, (opTy_not hta).1]) (by rw [hn]; try rfl)
        (notNot_ident N hN hp hn hc)⟩
    next => cases h
  next _ _ nc a b hn =>
    split at h
    next c hc =>
      cases h
      have hi := op_lt hn; have hnc := op_lt hc
      obtain ⟨hai, hti⟩ := WF.op hp hi hn
      obtain ⟨hca, hta⟩ := WF.op hp hnc hc
      simp only [List.mem_singleton, forall_eq, List.map_cons, List.map_nil] at hca hti hta
      have hnci := hai nc (by simp)
      refine ⟨i, twin_set N hp hi (fun x hx => ?_) ?_ (by rw [hn]; try rfl) rfl (ifNot_eval N hN hp hn hc)⟩
      · simp only [List.mem_cons, List.not_mem_nil, or_false] at hx
        rcases hx with rfl | rfl | rfl
        · omega
        · exact hai _ (by simp)
        · exact hai _ (by simp)
      · simp only [List.map_cons, List.map_nil, (opTy_not hta).1]
        exact (opTy_ite hti).2
    next => cases h
  next _ _ c b a hn =>
    exact absurd rfl hr
  next _ _ a b hn =>
    cases h
    have hi := op_lt hn
    obtain ⟨hai, hti⟩ := WF.op hp hi hn
    simp only [List.map_cons, List.map_nil] at hti
    exact ⟨i, twin_set N hp hi (fun x hx => hai x (by simp at hx ⊢; omega)) (by simpa using opTy_flip (by simp) hti)
      (by rw [hn]; try rfl) rfl fun L m s hd c hl => flip_eval N (by simp) hi hn s c⟩
  next _ _ a b hn =>
    cases h
    have hi := op_lt hn
    obtain ⟨hai, hti⟩ := WF.op hp hi hn
    simp only [List.map_cons, List.map_nil] at hti
    exact ⟨i, twin_set N hp hi (fun x hx => hai x (by simp at hx ⊢; omega)) (by simpa using opTy_flip (by simp) hti)
      (by rw [hn]; try rfl) rfl fun L m s hd c hl => flip_eval N (by simp) hi hn s c⟩
  next _ _ a b hn =>
    cases h
    have hi := op_lt hn
    obtain ⟨hai, hti⟩ := WF.op hp hi hn
    simp only [List.map_cons, List.map_nil] at hti
    exact ⟨i, twin_set N hp hi (fun x hx => hai x (by simp at hx ⊢; omega)) (by simpa using opTy_flip (by simp) hti)
      (by rw [hn]; try rfl) rfl fun L m s hd c hl => flip_eval N (by simp) hi hn s c⟩
  next _ _ a b hn =>
    cases h
    have hi := op_lt hn
    obtain ⟨hai, hti⟩ := WF.op hp hi hn
    simp only [List.map_cons, List.map_nil] at hti
    exact ⟨i, twin_set N hp hi (fun x hx => hai x (by simp at hx ⊢; omega)) (by simpa using opTy_flip (by simp) hti)
      (by rw [hn]; try rfl) rfl fun L m s hd c hl => flip_eval N (by simp) hi hn s c⟩
  next => cases h

end Ref
