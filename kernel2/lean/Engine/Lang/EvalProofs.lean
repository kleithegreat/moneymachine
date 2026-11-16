import Engine.Lang.Eval
import Engine.Lang.SyntaxProofs

/-!
# The evaluator's rows (B3, L2, L3, N1)

A tick's rows are built one node after another, each from the rows before it. Everything the laws say of values
is said of `rowAt`, a node's row in the finished tick.
-/

namespace Engine.Lang

variable {α : Type} (N : NumOps α)

theorem push_get_lt {β : Type} [Inhabited β] (a : Array β) (x : β) (i : Nat) (h : i < a.size) :
    (a.push x)[i]! = a[i]! := by
  have h2 : i < (a.push x).size := by simp; omega
  rw [getElem!_pos (a.push x) i h2, getElem!_pos a i h, Array.getElem_push_lt h]

theorem push_get_eq {β : Type} [Inhabited β] (a : Array β) (x : β) : (a.push x)[a.size]! = x := by simp

theorem build_size (p : Program) (t : Tick α) (m : Mach α) (k : Nat) :
    (build N p t m k).1.size = k ∧ (build N p t m k).2.size = k := by
  induction k with
  | zero => simp [build]
  | succ k ih => simp [build, ih.1, ih.2]

/-- The row and memory node `j` has, from the rows before it. -/
def rowOf (p : Program) (t : Tick α) (m : Mach α) (j : Nat) : Array (Option α) × Array (NS α) :=
  nodeStep N t p.nodes[j]! m.count m.coins (build N p t m j).1 m.ns[j]!

theorem build_get (p : Program) (t : Tick α) (m : Mach α) {j k : Nat} (h : j < k) :
    (build N p t m k).1[j]! = (rowOf N p t m j).1 ∧ (build N p t m k).2[j]! = (rowOf N p t m j).2 := by
  induction k with
  | zero => omega
  | succ k ih =>
    by_cases hj : j < k
    · obtain ⟨h1, h2⟩ := ih hj
      have s := build_size N p t m k
      simp only [build]
      rw [push_get_lt _ _ _ (by omega), push_get_lt _ _ _ (by omega)]
      exact ⟨h1, h2⟩
    · have : j = k := by omega
      subst this
      have s := build_size N p t m j
      simp only [build, rowOf]
      constructor
      · have := push_get_eq (build N p t m j).1 (nodeStep N t p.nodes[j]! m.count m.coins (build N p t m j).1 m.ns[j]!).1
        rwa [s.1] at this
      · have := push_get_eq (build N p t m j).2 (nodeStep N t p.nodes[j]! m.count m.coins (build N p t m j).1 m.ns[j]!).2
        rwa [s.2] at this

/-- A program whose nodes read only earlier nodes. -/
def Program.Ordered (p : Program) : Prop := ∀ j, j < p.nodes.size → ∀ a ∈ (p.nodes[j]!).args, a < j

theorem nodeOkb_op {p : Program} {i : Nat} {o : Op} {args : List Nat} (h : p.nodes[i]! = .op o args) :
    p.nodeOkb i = true ↔ (∀ a ∈ args, a < i) ∧ opTy o (args.map (p.types[·]!)) = some p.types[i]! := by
  simp [Program.nodeOkb, h]

theorem wf_ordered {p : Program} (h : p.WF) : p.Ordered := by
  intro j hj a ha
  have hok := (wf_iff.1 h).2.2 j hj
  cases hn : p.nodes[j]! with
  | op o args =>
    rw [hn] at ha
    have := (nodeOkb_op hn).1 hok
    exact this.1 a ha
  | builtin _ => rw [hn] at ha; simp [Node.args] at ha
  | source _ _ => rw [hn] at ha; simp [Node.args] at ha
  | const _ _ => rw [hn] at ha; simp [Node.args] at ha

theorem step_vals (p : Program) (t : Tick α) (m : Mach α) :
    (Mach.step N p t m).vals = (build N p t m p.nodes.size).1 := by simp [Mach.step]

theorem step_ns (p : Program) (t : Tick α) (m : Mach α) :
    (Mach.step N p t m).ns = (build N p t m p.nodes.size).2 := by simp [Mach.step]

theorem argRow_build (p : Program) (t : Tick α) (m : Mach α) {j : Nat} (hj : j ≤ p.nodes.size) {args : List Nat}
    (ha : ∀ a ∈ args, a < j) (k : Nat) :
    argRow (build N p t m j).1 args k = argRow (build N p t m p.nodes.size).1 args k := by
  unfold argRow
  cases hk : args[k]? with
  | none => rfl
  | some a =>
    have hmem : a ∈ args := List.mem_of_getElem? hk
    simp only
    rw [(build_get N p t m (ha a hmem)).1, (build_get N p t m (show a < p.nodes.size by have := ha a hmem; omega)).1]

/-- Every node's row of the tick is `nodeCore` over the finished rows of its arguments. -/
theorem step_row (p : Program) (t : Tick α) (m : Mach α) (hp : p.Ordered) {j : Nat} (hj : j < p.nodes.size) :
    ((Mach.step N p t m).vals[j]!, (Mach.step N p t m).ns[j]!) =
      nodeCore N t p.nodes[j]! m.count m.coins (argRow (Mach.step N p t m).vals (p.nodes[j]!).args) m.ns[j]! := by
  rw [step_vals, step_ns, (build_get N p t m hj).1, (build_get N p t m hj).2]
  have : argRow (build N p t m j).1 (p.nodes[j]!).args = argRow (build N p t m p.nodes.size).1 (p.nodes[j]!).args :=
    funext (argRow_build N p t m (by omega) (hp j hj))
  simp only [rowOf, nodeStep, this]

end Engine.Lang
