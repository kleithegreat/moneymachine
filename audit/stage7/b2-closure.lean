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

def changed : List Lean.Name := [``Ref.Registry.valid, ``Ref.Registry.closure, ``Ref.Meta.matches, ``Ref.Meta.required, ``Ref.differs, ``Ref.Trusted, ``Ref.stage1, ``Ref.Decl.ruleOk,
  ``Ref.Program.WF, ``Ref.CheckerAccepted, ``Ref.Stored.validAt, ``Ref.resolveAll]

def laws : List Lean.Name := [``Ref.L1_values, ``Ref.L1_simulator, ``Ref.L1_decisions, ``Ref.L2_units, ``Ref.L2_checker,
  ``Ref.L3_rewrite, ``Ref.L4_fills, ``Ref.L4_orders, ``Ref.L5_admitted, ``Ref.L5_order, ``Ref.L5_staged, ``Ref.L5_shape,
  ``Ref.L5_text, ``Ref.L5_certified, ``Ref.L6_bounded, ``Ref.L7_reads, ``Ref.L8_monotone, ``Ref.L8_known]

#eval show CommandElabM Unit from do
  let env ← getEnv
  for l in laws do
    let some ci := env.find? l | logInfo m!"{l} missing"
    let s := reach env ci.type.getUsedConstants.toList {}
    let hit := changed.filter s.contains
    IO.println s!"{l}: {hit.map (·.toString.replace "Ref." "")}"
