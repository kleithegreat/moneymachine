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
    (build N p t m k).vals.size = k ∧ (build N p t m k).exacts.size = k ∧ (build N p t m k).ns.size = k := by
  induction k with
  | zero => simp [build]
  | succ k ih => simp [build, ih.1, ih.2.1, ih.2.2]

theorem build_count (p : Program) (t : Tick α) (m : Mach α) (k : Nat) :
    (build N p t m k).count = m.count ∧ (build N p t m k).coins = m.coins := by
  induction k with
  | zero => simp [build]
  | succ k ih => simp [build, ih.1, ih.2]

/-- The rows and memory node `j` has, from the rows before it. -/
def rowOf (p : Program) (t : Tick α) (m : Mach α) (j : Nat) :
    (Array (Option α) × Array (NS α)) × Array (Option Rat) :=
  nodeStep N t p.nodes[j]! m.count m.coins (build N p t m j).vals (build N p t m j).exacts m.ns[j]!

theorem build_get (p : Program) (t : Tick α) (m : Mach α) {j k : Nat} (h : j < k) :
    (build N p t m k).vals[j]! = (rowOf N p t m j).1.1 ∧ (build N p t m k).exacts[j]! = (rowOf N p t m j).2 ∧
      (build N p t m k).ns[j]! = (rowOf N p t m j).1.2 := by
  induction k with
  | zero => omega
  | succ k ih =>
    by_cases hj : j < k
    · obtain ⟨h1, h2, h3⟩ := ih hj
      have s := build_size N p t m k
      simp only [build]
      rw [push_get_lt _ _ _ (by omega), push_get_lt _ _ _ (by omega), push_get_lt _ _ _ (by omega)]
      exact ⟨h1, h2, h3⟩
    · have : j = k := by omega
      subst this
      have s := build_size N p t m j
      simp only [build, rowOf]
      refine ⟨?_, ?_, ?_⟩
      · have := push_get_eq (build N p t m j).vals
          (nodeStep N t p.nodes[j]! m.count m.coins (build N p t m j).vals (build N p t m j).exacts m.ns[j]!).1.1
        rwa [s.1] at this
      · have := push_get_eq (build N p t m j).exacts
          (nodeStep N t p.nodes[j]! m.count m.coins (build N p t m j).vals (build N p t m j).exacts m.ns[j]!).2
        rwa [s.2.1] at this
      · have := push_get_eq (build N p t m j).ns
          (nodeStep N t p.nodes[j]! m.count m.coins (build N p t m j).vals (build N p t m j).exacts m.ns[j]!).1.2
        rwa [s.2.2] at this

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

/-- A program whose nodes read only earlier nodes. -/
def Program.Ordered (p : Program) : Prop := ∀ j, j < p.nodes.size → ∀ a ∈ (p.nodes[j]!).args, a < j

theorem nodeOkb_op {p : Program} {i : Nat} {o : Op} {args : List Nat} (h : p.nodes[i]! = .op o args) :
    p.nodeOkb i = true ↔ (∀ a ∈ args, a < i) ∧ opTy o (args.map (p.types[·]!)) = some p.types[i]! := by
  simp [Program.nodeOkb, h]

theorem wf_ordered {p : Program} (h : p.WF) : p.Ordered := by
  intro j hj a ha
  have hok := (wf_iff.1 h).2.2.1 j hj
  cases hn : p.nodes[j]! with
  | op o args =>
    rw [hn] at ha
    have := (nodeOkb_op hn).1 hok
    exact this.1 a ha
  | builtin _ => rw [hn] at ha; simp [Node.args] at ha
  | source _ _ => rw [hn] at ha; simp [Node.args] at ha
  | const _ _ => rw [hn] at ha; simp [Node.args] at ha
  | slotIn _ _ => rw [hn] at ha; simp [Node.args] at ha
  | exactConst _ _ => rw [hn] at ha; simp [Node.args] at ha

theorem step_vals (p : Program) (t : Tick α) (m : Mach α) :
    (Mach.step N p t m).vals = (build N p t m p.nodes.size).vals := rfl

theorem step_exacts (p : Program) (t : Tick α) (m : Mach α) :
    (Mach.step N p t m).exacts = (build N p t m p.nodes.size).exacts := rfl

theorem step_ns (p : Program) (t : Tick α) (m : Mach α) :
    (Mach.step N p t m).ns = (build N p t m p.nodes.size).ns := rfl

theorem argRow_build {β : Type} (A B : Array (Array (Option β))) (args : List Nat)
    (h : ∀ a ∈ args, A[a]! = B[a]!) (k : Nat) : argRow A args k = argRow B args k := by
  unfold argRow
  cases hk : args[k]? with
  | none => rfl
  | some a => exact h a (List.mem_of_getElem? hk)

/-- Every node's rows of the tick are `nodeFull` and `exactRow` over the finished rows of its arguments. -/
theorem step_row (p : Program) (t : Tick α) (m : Mach α) (hp : p.Ordered) {j : Nat} (hj : j < p.nodes.size) :
    ((Mach.step N p t m).vals[j]!, (Mach.step N p t m).ns[j]!) =
      nodeFull N t p.nodes[j]! m.count m.coins (argRow (Mach.step N p t m).vals (p.nodes[j]!).args)
        (argRow (Mach.step N p t m).exacts (p.nodes[j]!).args) m.ns[j]! ∧
    (Mach.step N p t m).exacts[j]! =
      exactRow N t p.nodes[j]! m.coins (argRow (Mach.step N p t m).vals (p.nodes[j]!).args)
        (argRow (Mach.step N p t m).exacts (p.nodes[j]!).args) := by
  have hc := build_count N p t m j
  have hj' : j < p.nodes.size := hj
  obtain ⟨h1, h2, h3⟩ := build_get N p t m hj'
  have hv : ∀ a ∈ (p.nodes[j]!).args, (build N p t m j).vals[a]! = (build N p t m p.nodes.size).vals[a]! := by
    intro a ha
    have := hp j hj a ha
    rw [(build_get N p t m (show a < j by omega)).1, (build_get N p t m (show a < p.nodes.size by omega)).1]
  have he : ∀ a ∈ (p.nodes[j]!).args, (build N p t m j).exacts[a]! = (build N p t m p.nodes.size).exacts[a]! := by
    intro a ha
    have := hp j hj a ha
    rw [(build_get N p t m (show a < j by omega)).2.1, (build_get N p t m (show a < p.nodes.size by omega)).2.1]
  have e1 : argRow (build N p t m j).vals (p.nodes[j]!).args =
      argRow (build N p t m p.nodes.size).vals (p.nodes[j]!).args := funext (argRow_build _ _ _ hv)
  have e2 : argRow (build N p t m j).exacts (p.nodes[j]!).args =
      argRow (build N p t m p.nodes.size).exacts (p.nodes[j]!).args := funext (argRow_build _ _ _ he)
  rw [step_vals, step_ns, step_exacts, h1, h2, h3] at *
  simp only [rowOf, nodeStep, e1, e2, and_self]

end Engine.Lang
