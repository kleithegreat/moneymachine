import Ref.Machine

/-!
The unit-instrumented machine for L2 (audit/criteria.md, stage 6): values carry their runtime category and
unit, and every operation checks its operands' categories and units and computes its result's from
them and from the program's declared parameter units and conversion targets, as DSL.md specifies.
It never reads the checker's node types. A mismatch is a runtime unit error.
-/

namespace Ref

variable {α : Type} [Inhabited α] (N : NumOps α)

/-- A value with its runtime tag: a number with a unit, or a boolean. -/
abbrev TVal (α : Type) := Option (α × Ty)

structure UnitError where
  node : Nat
  coin : Nat
  deriving Repr

/-- The instrumented value of node i for coin c, from its arguments' instrumented values. -/
def evalU (p : Program) (m : MState α) (tv : Array (Array (TVal α))) (i c : Nat) : Except UnitError (TVal α) := do
  let err : Except UnitError (TVal α) := .error ⟨i, c⟩
  let arg (k : Nat) : TVal α := match p.nodes[i]! with
    | .op _ args => tv[args[k]!]![c]!
    | _ => none
  let num (k : Nat) : Except UnitError (Option (α × Dim)) := match arg k with
    | none => .ok none
    | some (x, .num u) => .ok (some (x, u))
    | some (_, .bool) => .error ⟨i, c⟩
  let bool (k : Nat) : Except UnitError (Option α) := match arg k with
    | none => .ok none
    | some (x, .bool) => .ok (some x)
    | some (_, .num _) => .error ⟨i, c⟩
  let truthV (b : Bool) : TVal α := some (N.truth b, .bool)
  match p.nodes[i]! with
  | .input inp => return (m.input inp c).map (·, .num inp.unit)
  | .const bits u => return some (N.ofBits bits, .num u)
  | .param k => return some (N.ofBits p.params[k]!.1, .num p.params[k]!.2)
  | .op o _ => match o with
    | .add | .sub | .min | .max =>
      match ← num 0, ← num 1 with
      | some (x, u), some (y, v) =>
        if u != v then err else
        let r := match o with | .add => N.add x y | .sub => N.sub x y | .min => N.min x y | _ => N.max x y
        return some (r, .num u)
      | _, _ => return none
    | .mul | .div =>
      match ← num 0, ← num 1 with
      | some (x, u), some (y, v) =>
        let w := if o == .mul then Dim.mul u v else Dim.div u v
        match w with
        | none => err
        | some w => if o == .div && N.isZero y then return none
                    else return some (if o == .mul then N.mul x y else N.div x y, .num w)
      | _, _ => return none
    | .neg | .abs =>
      match ← num 0 with
      | some (x, u) => return some (if o == .neg then N.neg x else N.abs x, .num u)
      | none => return none
    | .sign => match ← num 0 with | some (x, _) => return some (N.sign x, .num Dim.one) | none => return none
    | .log | .exp =>
      match ← num 0 with
      | some (x, u) =>
        if u != Dim.one then err
        else if o == .log then (if N.lt N.zero x then return some (N.log x, .num u) else return none)
        else return some (N.exp x, .num u)
      | none => return none
    | .sqrt =>
      match ← num 0 with
      | some (x, u) => match Dim.sqrt u with
        | none => err
        | some h => if N.le N.zero x then return some (N.sqrt x, .num h) else return none
      | none => return none
    | .clip =>
      match ← num 0, ← num 1, ← num 2 with
      | some (x, u), some (lo, v), some (hi, w) => if u != v || v != w then err else return some (N.clip x lo hi, .num u)
      | _, _, _ => return none
    | .gt | .ge | .lt | .le =>
      match ← num 0, ← num 1 with
      | some (x, u), some (y, v) =>
        if u != v then err else
        return truthV (match o with | .gt => N.lt y x | .ge => N.le y x | .lt => N.lt x y | _ => N.le x y)
      | _, _ => return none
    | .and | .or =>
      match ← bool 0, ← bool 1 with
      | some x, some y => return truthV (if o == .and then !N.isZero x && !N.isZero y else !N.isZero x || !N.isZero y)
      | _, _ => return none
    | .not => match ← bool 0 with | some x => return truthV (N.isZero x) | none => return none
    | .ite =>
      match ← bool 0 with
      | some x => return if !N.isZero x then arg 1 else arg 2
      | none => return none
    | .convert f =>
      match ← num 0, p.convTo[i]! with
      | some (x, u), some to => if (Dim.conversion u to).isNone then err else return some (N.mul x (N.ofBits f), .num to)
      | none, _ => return none
      | some _, none => err
    | .window .. => return arg 0
    | _ => err

/-- The instrumented machine's state: tagged values, the executable window states, and each window's
tag (the tag of the values it holds). -/
structure UState (α : Type) where
  m : MState α
  tv : Array (Array (TVal α))
  wtag : Array (Array (Option Ty))

def UState.init (p : Program) (coins : Nat) : UState α :=
  { m := MState.init N p coins, tv := Array.replicate p.nodes.size (Array.replicate coins none),
    wtag := Array.replicate p.nodes.size (Array.replicate coins none) }

def keepT (x : TVal α) : TVal α := x.bind fun (v, t) => (N.keep v).map (·, t)

/-- One instrumented tick (as `MState.tick`, with tags). -/
def UState.tick (p : Program) (u : UState α) (listed : Array Bool) (hour : Int) : Except UnitError (UState α) := do
  let mut u := { u with m := { u.m with hour := hour } }
  let coins := listed.size
  for i in [0:p.nodes.size] do
    match p.nodes[i]! with
    | .op .hoursSince args =>
      for c in [0:coins] do
        let cond := u.tv[args[0]!]![c]!
        let fire ← match cond with
          | some (v, .bool) => pure (listed[c]! && !N.isZero v)
          | some (_, .num _) => throw ⟨i, c⟩
          | none => pure false
        if fire then u := { u with m := { u.m with since := u.m.since.modify i fun row => row.set! c (some hour) } }
        let v : TVal α := if listed[c]! then u.m.since[i]![c]!.bind fun t =>
          (N.keep (N.ofInt ((hour - t) / HOUR))).map (·, .num (Dim.base "h").get!) else none
        u := { u with tv := u.tv.modify i fun row => row.set! c v }
    | .op o@(.xsMean) args | .op o@(.xsDemean) args | .op o@(.xsRank) args =>
      let xs := (List.range coins).filterMap fun c => if listed[c]! then (u.tv[args[0]!]![c]!).map (c, ·) else none
      let units ← xs.mapM fun (c, (_, t)) => match t with | .num d => pure d | .bool => throw ⟨i, c⟩
      if !units.all (· == units.headD Dim.one) then throw ⟨i, 0⟩
      let d := units.headD Dim.one
      if o == .xsRank && !xs.isEmpty && d != Dim.one then throw ⟨i, 0⟩
      let values := xs.map (·.2.1)
      let mean := N.div (total N values) (N.ofNat xs.length)
      let out := (List.range coins).map fun c => match xs.find? (·.1 == c) with
        | none => none
        | some (_, (v, _)) => match o with
          | .xsMean => (N.keep mean).map (·, .num d)
          | .xsDemean => (N.keep (N.sub v mean)).map (·, .num d)
          | _ => (N.keep (rank N values v)).map (·, .num d)
      u := { u with tv := u.tv.set! i (if xs.isEmpty then Array.replicate coins none else out.toArray) }
    | _ =>
      for c in [0:coins] do
        let v ← if listed[c]! then evalU N p u.m u.tv i c else pure none
        let v ← match u.m.wins[i]![c]! with
          | some w =>
            if !listed[c]! then pure v else do
              let tag ← match v, u.wtag[i]![c]! with
                | some (_, t), some t' => if t == t' then pure (some t) else throw ⟨i, c⟩
                | some (_, t), none => pure (some t)
                | none, t => pure t
              let (w', out) := w.push N (v.map (·.1))
              u := { u with m := { u.m with wins := u.m.wins.modify i fun row => row.set! c (some w') },
                            wtag := u.wtag.modify i fun row => row.set! c tag }
              pure (match out, tag with | some x, some t => some (x, t) | _, _ => none)
          | none => pure v
        u := { u with tv := u.tv.modify i fun row => row.set! c (keepT N v) }
  return u

/-- Erasure: the executable values of an instrumented state. -/
def UState.erase (u : UState α) : Array (Array (Val α)) := u.tv.map (·.map (·.map (·.1)))

end Ref
