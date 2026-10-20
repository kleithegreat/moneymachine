import Ref

def main (args : List String) : IO UInt32 := do
  let text ← IO.FS.readFile args[0]!
  match Ref.check text with
  | .ok p => IO.println s!"ok {p.nodes.size}"; return 0
  | .error c => IO.println c.name; return 1
