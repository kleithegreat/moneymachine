import Engine.Lang.Eval

/-!
# The unit-instrumented evaluator (B3, L2)

A node carries a type: a leaf its own, an operator the typing rule's result over its arguments' types. A mismatch the
rule refuses is a unit or sort error. The values, float and exact, are the executable evaluator's.
-/

namespace Engine.Lang

variable {α : Type}

structure UMach (α : Type) where
  m : Mach α
  tags : Array Ty

def UMach.init (N : NumOps α) (p : Program) (coins : Nat) : UMach α :=
  ⟨Mach.init N p coins, #[]⟩

def UMach.erase (u : UMach α) : Mach α := u.m

/-- A float or bool value at a coin with the type its node carries. -/
def UMach.tagged (u : UMach α) (i c : Nat) : Option (α × Ty) :=
  match (u.m.vals[i]!)[c]!, u.tags[i]? with
  | some x, some t => some (x, t)
  | _, _ => none

/-- An exact value at a coin with the unit its node carries. -/
def UMach.exactTagged (u : UMach α) (i c : Nat) : Option (Rat × Dim) :=
  match (u.m.exacts[i]!)[c]!, u.tags[i]? with
  | some x, some (.exact d) => some (x, d)
  | _, _ => none

/-- Node `k`'s type from its arguments' types. -/
def tagNode (p : Program) (ts : Array Ty) (k : Nat) : Except String Ty :=
  match p.nodes[k]! with
  | .builtin n => .ok ((builtinTy n).getD .bool)
  | .slotIn n _ => .ok ((builtinTy n).getD .bool)
  | .source _ u => .ok (.num u)
  | .const _ u => .ok (.num u)
  | .exactConst _ u => .ok (.exact u)
  | .op o args => opTyE o (args.map (ts[·]!))

def tagBuild (p : Program) : Nat → Except String (Array Ty)
  | 0 => .ok #[]
  | k + 1 => do
    let ts ← tagBuild p k
    let t ← tagNode p ts k
    return ts.push t

def UMach.step (N : NumOps α) (p : Program) (t : Tick α) (u : UMach α) : Except String (UMach α) := do
  let m := Mach.step N p t u.m
  let tags ← tagBuild p p.nodes.size
  return ⟨m, tags⟩

end Engine.Lang
