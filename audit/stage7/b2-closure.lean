import Lean
import Ref
open Lean Elab Command

partial def reach (env : Environment) (todo : List Lean.Name) (seen : NameSet) : NameSet :=
  match todo with
  | [] => seen
  | n :: rest =>
    if seen.contains n then reach env rest seen else
    let seen := seen.insert n
    match env.find? n with
    | none => reach env rest seen
    | some ci =>
      let fromType := ci.type.getUsedConstants.toList
      let fromVal := match ci with
        | .defnInfo d => d.value.getUsedConstants.toList
        | .opaqueInfo d => d.value.getUsedConstants.toList
        | .inductInfo d => d.ctors
        | .ctorInfo d => [d.induct]
        | _ => []
      reach env (fromType ++ fromVal ++ rest) seen

/-- The definitions B2 changes. -/
def changed : List Lean.Name := [``Ref.Dep, ``Ref.Decl, ``Ref.Revision, ``Ref.Decl.depends, ``Ref.Decl.controls,
  ``Ref.Stored.eligible, ``Ref.Stored.keys, ``Ref.Stored.validAt, ``Ref.timeline, ``Ref.resolveAll]

/-- Unchanged definitions that read them, reported as the route by which a law reaches a change. -/
def through : List Lean.Name := [``Ref.Registry.valid, ``Ref.Registry.closure, ``Ref.Meta.matches, ``Ref.Meta.required,
  ``Ref.differs, ``Ref.Trusted, ``Ref.stage1, ``Ref.Decl.ruleOk, ``Ref.Program.WF, ``Ref.CheckerAccepted]

def laws : List Lean.Name := [``Ref.L1_values, ``Ref.L1_simulator, ``Ref.L1_decisions, ``Ref.L2_units, ``Ref.L2_checker,
  ``Ref.L3_rewrite, ``Ref.L4_fills, ``Ref.L4_orders, ``Ref.L5_admitted, ``Ref.L5_order, ``Ref.L5_staged, ``Ref.L5_shape,
  ``Ref.L5_text, ``Ref.L5_certified, ``Ref.L6_bounded, ``Ref.L7_reads, ``Ref.L8_monotone, ``Ref.L8_known]

#eval show CommandElabM Unit from do
  let env ← getEnv
  for l in laws do
    let some ci := env.find? l | logInfo m!"{l} missing"
    let s := reach env ci.type.getUsedConstants.toList {}
    let names (xs : List Lean.Name) := (xs.filter s.contains).map (·.toString.replace "Ref." "")
    IO.println s!"{l}: changed {names changed}, through {names through}"
