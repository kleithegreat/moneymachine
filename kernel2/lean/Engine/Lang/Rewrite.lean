import Engine.Lang.Eval

/-!
# The rewrite rules of R version 1 (kernel/CANONICAL.md)

Twelve rows, each applied at one node of a checked program. A rule that makes a node's uses read another node
redirects them; the others replace a node in place. No rule moves a node, so a node corresponds to itself.
-/

namespace Engine.Lang

inductive Rule where
  | negNeg | absAbs | absNeg | mulOne | divOne | subZero | addComm | mulComm | andOrComm | notNot | ifNot | cmpSwap
  deriving DecidableEq, Repr

def Rule.all : List Rule :=
  [.negNeg, .absAbs, .absNeg, .mulOne, .divOne, .subZero, .addComm, .mulComm, .andOrComm, .notNot, .ifNot, .cmpSwap]

/-- Every use of node `i`, in the nodes and the probes, reads node `j`. -/
def Program.redirect (p : Program) (i j : Nat) : Program :=
  let f (k : Nat) : Nat := if k == i then j else k
  { p with nodes := p.nodes.map fun n => match n with | .op o args => .op o (args.map f) | n => n,
           probeNodes := p.probeNodes.map f }

def Program.isConst (p : Program) (j : Nat) (bits : UInt64) (u : Dim) : Bool := p.nodes[j]! == .const bits u

def Program.replace (p : Program) (i : Nat) (n : Node) : Program := { p with nodes := p.nodes.set! i n }

/-- Apply a rule at node `i`, if it matches there. -/
def Rule.apply (r : Rule) (p : Program) (i : Nat) : Option Program :=
  match r, p.nodes[i]! with
  | .negNeg, .op .neg [a] => match p.nodes[a]! with | .op .neg [x] => some (p.redirect i x) | _ => none
  | .absAbs, .op .abs [a] => match p.nodes[a]! with | .op .abs [_] => some (p.redirect i a) | _ => none
  | .absNeg, .op .abs [a] => match p.nodes[a]! with | .op .neg [x] => some (p.replace i (.op .abs [x])) | _ => none
  | .mulOne, .op .mul [x, c] => if p.isConst c 0x3FF0000000000000 Dim.one then some (p.redirect i x) else none
  | .divOne, .op .div [x, c] => if p.isConst c 0x3FF0000000000000 Dim.one then some (p.redirect i x) else none
  | .subZero, .op .sub [x, c] =>
    match p.types[x]! with
    | .num u => if p.isConst c 0 u then some (p.redirect i x) else none
    | _ => none
  | .addComm, .op .add [a, b] => some (p.replace i (.op .add [b, a]))
  | .mulComm, .op .mul [a, b] => some (p.replace i (.op .mul [b, a]))
  | .andOrComm, .op .and [a, b] => some (p.replace i (.op .and [b, a]))
  | .andOrComm, .op .or [a, b] => some (p.replace i (.op .or [b, a]))
  | .notNot, .op .not [a] => match p.nodes[a]! with | .op .not [c] => some (p.redirect i c) | _ => none
  | .ifNot, .op .ite [nc, a, b] =>
    match p.nodes[nc]! with
    | .op .not [c] => some (p.replace i (.op .ite [c, b, a]))
    | _ => none
  | .cmpSwap, .op .gt [a, b] => some (p.replace i (.op .lt [b, a]))
  | .cmpSwap, .op .lt [a, b] => some (p.replace i (.op .gt [b, a]))
  | .cmpSwap, .op .ge [a, b] => some (p.replace i (.op .le [b, a]))
  | .cmpSwap, .op .le [a, b] => some (p.replace i (.op .ge [b, a]))
  | _, _ => none

/-- Where each original node lives in the rewritten program: where it was. -/
def Rule.corr (_ : Rule) (_ k : Nat) : Nat := k

end Engine.Lang
