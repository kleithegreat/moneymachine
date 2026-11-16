import Engine.Lang.Eval

/-!
# The unit-instrumented evaluator (B3, L2)

A node remembers the type of what it has computed: a leaf its own, an operator the rule's result over its
arguments' remembered types. A mismatch the typing rule refuses is a unit or sort error. The values are the
executable evaluator's.
-/

namespace Engine.Lang

variable {α : Type}

structure UMach (α : Type) where
  m : Mach α
  tags : Array (Option Ty)

def UMach.init (N : NumOps α) (p : Program) (coins : Nat) : UMach α :=
  ⟨Mach.init N p coins, p.nodes.map fun _ => none⟩

def UMach.erase (u : UMach α) : Mach α := u.m

/-- A node's value at a coin with the type it carries. -/
def UMach.tagged (u : UMach α) (i c : Nat) : Option (α × Ty) :=
  match (u.m.vals[i]!)[c]!, u.tags[i]! with
  | some x, some t => some (x, t)
  | _, _ => none

/-- Node `k`'s type after a tick: from its arguments' types, or as before when it has not computed anything. -/
def tagNode (p : Program) (vals : Array (Array (Option α))) (ts : Array (Option Ty)) (prev : Option Ty) (k : Nat) :
    Except String (Option Ty) :=
  let leaf (ty : Ty) : Except String (Option Ty) :=
    .ok (if (vals[k]!).any Option.isSome then some ty else prev)
  match p.nodes[k]! with
  | .builtin n => leaf ((builtinTy n).getD .bool)
  | .source _ u => leaf (.num u)
  | .const _ u => leaf (.num u)
  | .op o args =>
    let argTags := args.map fun a => ts[a]!
    if argTags.all Option.isSome then (opTyE o (argTags.filterMap id)).map some else .ok prev

def tagBuild (p : Program) (vals : Array (Array (Option α))) (prev : Array (Option Ty)) :
    Nat → Except String (Array (Option Ty))
  | 0 => .ok #[]
  | k + 1 => do
    let ts ← tagBuild p vals prev k
    let t ← tagNode p vals ts prev[k]! k
    return ts.push t

def UMach.step (N : NumOps α) (p : Program) (t : Tick α) (u : UMach α) : Except String (UMach α) := do
  let m := Mach.step N p t u.m
  let tags ← tagBuild p m.vals u.tags p.nodes.size
  return ⟨m, tags⟩

end Engine.Lang
