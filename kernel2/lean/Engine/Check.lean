import Engine.Lang.Syntax

namespace Engine

/-- The verdict on a program's text (KERNEL.md A17): `{"ok":true}`, or `{"error":CODE,"at":WHERE}` for the first fault. -/
@[export mm2_check]
def check (program : String) : String :=
  match Lang.parseAt program with
  | .ok _ => "{\"ok\":true}"
  | .error (code, place) => "{\"error\":\"" ++ code ++ "\",\"at\":\"" ++ Json.escape place ++ "\"}"

end Engine
