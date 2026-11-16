import Engine.Lang.UnitsProofs
import Engine.Lang.Rewrite

/-!
# The rewrite rules keep a program's values (B3, L3)

Everything is said of cells: node `k`'s value at coin `c` in a finished tick.
-/

namespace Engine.Lang

variable {α : Type} (N : NumOps α)

/-- A node's row of a tick depends on its arguments' rows only through their cells. -/
theorem nodeFull_cells (t : Tick α) (n : Node) (count coins : Nat) (R R' : Nat → Array (Option α))
    (h : ∀ (k c : Nat), (R k)[c]! = (R' k)[c]!) (ns : Array (NS α)) :
    nodeFull N t n count coins R ns = nodeFull N t n count coins R' ns := by
  have hp : ∀ c, pointVal N t n R c = pointVal N t n R' c := by
    intro c; unfold pointVal; simp [h]
  unfold nodeFull finalize nodeCore
  split <;> simp [h, hp]

theorem keep_finite {z y : α} (h : N.keep z = some y) : N.finite y = true := by
  unfold NumOps.keep at h
  split at h
  · simp at h; subst h; assumption
  · simp at h

theorem nodeFull_size (t : Tick α) (n : Node) (count coins : Nat) (R : Nat → Array (Option α)) (ns : Array (NS α)) :
    (nodeFull N t n count coins R ns).1.size = coins := by
  simp [nodeFull, finalize]

/-- A defined cell is inside the coins, in view and finite. -/
theorem nodeFull_defined (t : Tick α) (n : Node) (count coins : Nat) (R : Nat → Array (Option α))
    (ns : Array (NS α)) (c : Nat) (y : α) (h : (nodeFull N t n count coins R ns).1[c]! = some y) :
    c < coins ∧ t.inView c = true ∧ N.finite y = true := by
  unfold nodeFull finalize at h
  simp only [] at h
  rw [rowMap_get] at h
  by_cases hc : c < coins
  · rw [if_pos hc] at h
    split at h
    · rename_i hv
      obtain ⟨z, _, hz⟩ := Option.bind_eq_some_iff.1 h
      exact ⟨hc, hv, keep_finite N hz⟩
    · simp at h
  · rw [if_neg hc] at h
    simp at h

theorem row_ext {a b : Array (Option α)} (hs : a.size = b.size) (h : ∀ c : Nat, a[c]! = b[c]!) : a = b := by
  apply Array.ext hs
  intro i h1 h2
  have := h i
  rwa [getElem!_pos a i h1, getElem!_pos b i h2] at this

theorem arr_ext {β : Type} [Inhabited β] {a b : Array β} (hs : a.size = b.size) (h : ∀ i, i < a.size → a[i]! = b[i]!) :
    a = b := by
  apply Array.ext hs
  intro i h1 h2
  have := h i h1
  rwa [getElem!_pos a i h1, getElem!_pos b i h2] at this

/-- Two programs of one size whose nodes compute the same rows, given the same rows before them, run one tick alike. -/
theorem step_same {p p' : Program} (hp : p.Ordered) (hp' : p'.Ordered) (hsize : p'.nodes.size = p.nodes.size)
    (t : Tick α) (m : Mach α)
    (hnode : ∀ k, k < p.nodes.size →
      (∀ j, j < k → (Mach.step N p' t m).vals[j]! = (Mach.step N p t m).vals[j]!) →
      nodeFull N t p'.nodes[k]! m.count m.coins (argRow (Mach.step N p' t m).vals (p'.nodes[k]!).args) m.ns[k]! =
      nodeFull N t p.nodes[k]! m.count m.coins (argRow (Mach.step N p t m).vals (p.nodes[k]!).args) m.ns[k]!) :
    Mach.step N p' t m = Mach.step N p t m := by
  have hk : ∀ k, k < p.nodes.size →
      (Mach.step N p' t m).vals[k]! = (Mach.step N p t m).vals[k]! ∧
      (Mach.step N p' t m).ns[k]! = (Mach.step N p t m).ns[k]! := by
    intro k
    induction k using Nat.strongRecOn with
    | _ k ih =>
      intro hkk
      have h1 := step_row N p' t m hp' (by omega : k < p'.nodes.size)
      have h2 := step_row N p t m hp hkk
      have h3 := hnode k hkk (fun j hj => (ih j hj (by omega)).1)
      rw [h3] at h1
      have := h1.trans h2.symm
      exact ⟨congrArg Prod.fst this, congrArg Prod.snd this⟩
  have hs1 := build_size N p' t m p'.nodes.size
  have hs2 := build_size N p t m p.nodes.size
  unfold Mach.step
  rw [hsize]
  have hv : (build N p' t m p.nodes.size).1 = (build N p t m p.nodes.size).1 := by
    apply arr_ext (by rw [(build_size N p' t m _).1, (build_size N p t m _).1])
    intro i hi
    rw [(build_size N p' t m _).1] at hi
    have := (hk i hi).1
    rwa [step_vals, step_vals, hsize] at this
  have hn : (build N p' t m p.nodes.size).2 = (build N p t m p.nodes.size).2 := by
    apply arr_ext (by rw [(build_size N p' t m _).2, (build_size N p t m _).2])
    intro i hi
    rw [(build_size N p' t m _).2] at hi
    have := (hk i hi).2
    rwa [step_ns, step_ns, hsize] at this
  simp only [hv, hn]

theorem nodeFull_args_irrel (t : Tick α) (o : Op) (a b : List Nat) (count coins : Nat)
    (R : Nat → Array (Option α)) (ns : Array (NS α)) :
    nodeFull N t (.op o a) count coins R ns = nodeFull N t (.op o b) count coins R ns := by
  unfold nodeFull nodeCore
  cases o <;> simp [pointVal, evalNode]

theorem foldl_step_eq {p p' : Program} (h : ∀ (t : Tick α) (m : Mach α), Mach.step N p' t m = Mach.step N p t m)
    (ts : List (Tick α)) : ∀ m : Mach α,
    ts.foldl (fun m t => Mach.step N p' t m) m = ts.foldl (fun m t => Mach.step N p t m) m := by
  induction ts with
  | nil => intro m; rw [List.foldl_nil, List.foldl_nil]
  | cons t ts ih => intro m; rw [List.foldl_cons, List.foldl_cons, h t m]; exact ih _

theorem run_eq_of_step {p p' : Program} (coins : Nat) (ts : List (Tick α))
    (h : ∀ (t : Tick α) (m : Mach α), Mach.step N p' t m = Mach.step N p t m)
    (hinit : Mach.init N p' coins = Mach.init N p coins) : Mach.run N p' coins ts = Mach.run N p coins ts := by
  unfold Mach.run
  rw [hinit]
  exact foldl_step_eq N h ts _

theorem redirect_nodes_size (p : Program) (i x : Nat) : (p.redirect i x).nodes.size = p.nodes.size := by
  simp [Program.redirect]

theorem array_map_get {β γ : Type} [Inhabited β] [Inhabited γ] (f : β → γ) (a : Array β) {k : Nat} (hk : k < a.size) :
    (a.map f)[k]! = f a[k]! := by
  rw [getElem!_pos (a.map f) k (by simpa using hk), getElem!_pos a k hk]
  simp

theorem redirect_nodes_get (p : Program) (i x : Nat) {k : Nat} (hk : k < p.nodes.size) :
    (p.redirect i x).nodes[k]! = match p.nodes[k]! with
      | .op o args => .op o (args.map fun k => if k == i then x else k)
      | n => n :=
  array_map_get _ p.nodes hk

theorem redirect_ordered {p : Program} {i x : Nat} (hp : p.Ordered) (hxi : x < i) : (p.redirect i x).Ordered := by
  intro k hk a ha
  rw [redirect_nodes_size] at hk
  rw [redirect_nodes_get p i x hk] at ha
  have hpk := hp k hk
  cases hn : p.nodes[k]! with
  | op o args =>
    rw [hn] at ha
    simp only [Node.args, List.mem_map] at ha
    obtain ⟨b, hb, rfl⟩ := ha
    have hbk := hpk b (by rw [hn]; exact hb)
    by_cases hbi : b == i
    · simp only [hbi, if_true]
      have : b = i := by simpa using hbi
      subst this; omega
    · simp only [hbi]; exact hbk
  | builtin _ => rw [hn] at ha; simp [Node.args] at ha
  | source _ _ => rw [hn] at ha; simp [Node.args] at ha
  | const _ _ => rw [hn] at ha; simp [Node.args] at ha

theorem redirect_step {p : Program} {i x : Nat} (hp : p.Ordered) (hxi : x < i) (hi : i < p.nodes.size)
    (hsem : ∀ (t : Tick α) (m : Mach α) (c : Nat),
      ((Mach.step N p t m).vals[i]!)[c]! = ((Mach.step N p t m).vals[x]!)[c]!)
    (t : Tick α) (m : Mach α) : Mach.step N (p.redirect i x) t m = Mach.step N p t m := by
  apply step_same N hp (redirect_ordered hp hxi) (by rw [redirect_nodes_size]) t m
  intro k hk ih
  have hpk := hp k hk
  rw [redirect_nodes_get p i x hk]
  cases hn : p.nodes[k]! with
  | op o args =>
    simp only [Node.args]
    rw [nodeFull_args_irrel N t o (args.map fun k => if k == i then x else k) args]
    apply nodeFull_cells
    intro j c
    unfold argRow
    rw [List.getElem?_map]
    cases hj : args[j]? with
    | none => rfl
    | some a =>
      simp only [Option.map_some]
      have hak : a < k := hpk a (by rw [hn]; exact List.mem_of_getElem? hj)
      by_cases hai : a == i
      · have : a = i := by simpa using hai
        subst this
        simp only [hai, if_true]
        rw [(ih x (by omega)), hsem t m c]
      · have hf : (a == i) = false := by simpa using hai
        simp only [hf]
        simp only [Bool.false_eq_true, if_false]
        rw [ih a hak]
  | builtin _ =>
    simp only [Node.args]
    exact nodeFull_cells N t _ _ _ _ _ (fun j c => by simp [argRow]) _
  | source _ _ =>
    simp only [Node.args]
    exact nodeFull_cells N t _ _ _ _ _ (fun j c => by simp [argRow]) _
  | const _ _ =>
    simp only [Node.args]
    exact nodeFull_cells N t _ _ _ _ _ (fun j c => by simp [argRow]) _

end Engine.Lang
