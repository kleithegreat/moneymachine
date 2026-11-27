import Engine.Json

namespace Engine.Machine

/-- A protected window `[start, stop)` of milliseconds, and whether it has been released (A13). -/
structure Window where
  start : Int
  stop : Int
  released : Bool
  deriving Repr, DecidableEq

open Engine.Json

/-- The tracked policy file as data: a list of windows, each exactly `start`, `end` and `released`,
the start below the end. Anything else is an error. -/
def parseWindows (text : String) : Except String (List Window) := do
  let doc ← parse text
  match doc with
  | .arr entries =>
    entries.mapM fun entry =>
      match entry.keysAre ["start", "end", "released"] [], entry.field? "start", entry.field? "end",
          entry.field? "released" with
      | true, some (.int a), some (.int b), some (.bool r) =>
        if a < b then .ok { start := a, stop := b, released := r } else .error "window ends before it starts"
      | _, _, _, _ => .error "a window is exactly {start, end, released}"
  | _ => .error "the policy is a list of windows"

def windowJson (w : Window) : String :=
  s!"\{\"start\":{w.start},\"end\":{w.stop},\"released\":{w.released}}"

/-- The canonical text of a list of windows, which the identity hashes. -/
def windowsJson (ws : List Window) : String :=
  "[" ++ ",".intercalate (ws.map windowJson) ++ "]"

end Engine.Machine
