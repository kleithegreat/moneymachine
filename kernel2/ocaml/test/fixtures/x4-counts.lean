/- Step 5 test 12's least-deciding-N report. Builder contract: Engine.Laws
   supplies the frozen X4 definitions expStart/expTerms/expLoAt/expHiAt,
   logTerms/logLoAt/logHiAt; Engine.Exact.decode : UInt64 → Option Rat and
   nearestBits : Rat → UInt64. NO statistics export or new engine entry.
   This counts X4's least N using its law-owned formulas, not arbitrary bounds.
   MM2_X4_INPUTS names test 12's hash-checked corpus directory. Run after that
   check; missing corpus or a nondeciding finite-domain input is an error.
   This executable fixture has IO; the Engine library still has none. -/
import Engine.Laws

set_option maxRecDepth 8192

namespace Step5Counts

def word (s : String) : IO UInt64 := do
  let mut n : Nat := 0
  unless s.length == 16 do throw (IO.userError "expected 16 hex digits")
  for c in s.toList do
    let d := if '0' ≤ c && c ≤ '9' then c.toNat - '0'.toNat
      else if 'a' ≤ c && c ≤ 'f' then c.toNat - 'a'.toNat + 10
      else if 'A' ≤ c && c ≤ 'F' then c.toNat - 'A'.toNat + 10 else 16
    if d ≥ 16 then throw (IO.userError "bad hex argument")
    n := 16 * n + d
  return n.toUInt64

def count (isLog : Bool) (x : Rat) : IO (Nat × Nat) := do
  let first := if isLog then 0 else Engine.Laws.expStart x
  let last := if isLog then Engine.Laws.logTerms else Engine.Laws.expTerms x
  let lo := if isLog then Engine.Laws.logLoAt x else Engine.Laws.expLoAt x
  let hi := if isLog then Engine.Laws.logHiAt x else Engine.Laws.expHiAt x
  for n in List.range (last + 1) do
    if first ≤ n && Engine.Exact.nearestBits (lo n) == Engine.Exact.nearestBits (hi n) then
      return (n, first)
  throw (IO.userError "X4 cap reached without a deciding count")

#eval show IO Unit from do
  let some dir ← IO.getEnv "MM2_X4_INPUTS" | throw (IO.userError "MM2_X4_INPUTS required")
  let mut maximum := 0
  let mut beyond := 0
  let mut total := 0
  let mut inputs : List (Bool × String) := []
  for (isLog, name) in [(false, "exp"), (true, "log")] do
    for suffix in ["-draws.txt", "-glibc.txt"] do
      let text ← IO.FS.readFile (dir ++ "/" ++ name ++ suffix)
      inputs := inputs ++ (text.splitOn "\n").flatMap (fun s =>
        if s.isEmpty then [] else [(isLog, s), (!isLog, s)])
  let hardest ← IO.FS.readFile (dir ++ "/hardest.txt")
  for line in hardest.splitOn "\n" do
    if !line.isEmpty then
      match line.splitOn " " with
      | [name, s] =>
        unless name == "exp" || name == "log" do throw (IO.userError "bad hardest operation")
        inputs := inputs ++ [(false, s), (true, s)]
      | _ => throw (IO.userError "bad hardest argument")
  let boundaries ← IO.FS.readFile (dir ++ "/boundaries.txt")
  inputs := inputs ++ (boundaries.splitOn "\n").flatMap (fun s =>
    if s.isEmpty then [] else [(false, s), (true, s)])
  let specials := ["0000000000000000", "8000000000000000", "3ff0000000000000",
    "4000000000000000", "bff0000000000000", "4086300000000000",
    "c087500000000000", "c087400000000000"]
  inputs := inputs ++ specials.flatMap (fun s => [(false, s), (true, s)])
  for (isLog, s) in inputs do
    let b ← word s
    if let some x := Engine.Exact.decode b then
      if (isLog && 0 < x) || (!isLog && -746 < x && x < 710) then
        let (n, first) ← count isLog x
        maximum := max maximum n
        if first < n then beyond := beyond + 1
        total := total + 1
  unless total > 0 do throw (IO.userError "empty count report")
  IO.println s!"X4 least deciding N: maximum={maximum}, beyond_first={beyond}, arguments={total}"

end Step5Counts
