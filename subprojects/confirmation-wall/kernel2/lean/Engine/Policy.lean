import Engine.Windows

namespace Engine.Machine

/-- The tracked policy file's bytes (`kernel2/protected-windows.json`), compiled in. -/
def policyText : String := include_str "../../protected-windows.json"

/-- The protected windows (A13). The theorem below fails the build when the file is not strict window data. -/
def windows : List Window :=
  match parseWindows policyText with
  | .ok ws => ws
  | .error _ => []

theorem policy_is_data : (match parseWindows policyText with | .ok _ => true | .error _ => false) = true := by
  decide +kernel

end Engine.Machine
