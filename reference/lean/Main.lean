import Ref
import Ref.Io

/-!
refmm: the Lean reference kernel's executable, on binary64.
  refmm check PROGRAM                 the verdict: `ok` or the rejection code
  refmm run PROGRAMS MARKET OUT_DIR   on a market exported by reference/mmdump, each program listed in PROGRAMS
                                      (one path per line): the i-th's output to OUT_DIR/i.json, its node streams to
                                      OUT_DIR/i.bin
  refmm bench PROGRAM MARKET REPS     evaluator-only milliseconds of REPS runs (`null` if not completed)
                                      written in mmdump's format (every float as its bits)
-/

open Ref Json Ref.Io

/-- One tick's node values (nodes in order, each coin in order) as bytes, and how many are defined. -/
def tickBytes (ms : MState Float) : ByteArray × Nat :=
  ms.vals.foldl (fun acc row => row.foldl (fun (b, n) x => (pushVal b x, if x.isSome then n + 1 else n)) acc) (ByteArray.empty, 0)

/-- Every node's value for every coin at every tick of the machine's schedule (wStart, then each hour of every
step: `Ctx.machineAfter`'s schedule over the run's steps), written to `h`; returns how many were defined. -/
def writeStreams (h : IO.FS.Handle) (p : Program) (m : Market Float) (v : Venue Float) (pol : Policy) (stop : Int) :
    IO (Except Abort Nat) := do
  let c := Ctx.make p m v pol stop
  let mut s ← match c.start floatOps with
    | .error a => return .error a
    | .ok s => pure s
  let (b0, n0) := tickBytes s.machine
  h.write b0
  let mut n := n0
  for k in [1:4 * c.bounds.length + 1] do
    let hr := pol.wStart + (k : Int) * HOUR
    match c.deliver s (hr + pol.delta) with
    | .error a => return .error a
    | .ok s' => s := { s' with machine := s'.machine.tick floatOps p (c.mask hr) hr }
    let (b, d) := tickBytes s.machine
    h.write b
    n := n + d
  return .ok n

def main (args : List String) : IO UInt32 := do
  match args with
  | ["check", path] =>
    match Ref.check (← IO.FS.readFile path) with
    | .ok _ => IO.println "ok"; return 0
    | .error c => IO.println c.name; return 1
  | ["run", programs, mkt, outDir] =>
    let some v := (Json.parse (← IO.FS.readFile mkt)).toOption | IO.eprintln "bad market"; return 3
    let (m, venue, pol, stop) := market v
    let paths := (← IO.FS.readFile programs).splitOn "\n" |>.filter (· ≠ "")
    let mut i := 0
    for prog in paths do
      let streams : System.FilePath := outDir ++ s!"/{i}.bin"
      let result ← match Ref.check (← IO.FS.readFile prog) with
        | .error c => pure s!"\{\"reject\":\"{c.name}\"}"
        | .ok p => match Ref.run floatOps p m venue pol stop with
          | .error a => pure s!"\{\"abort\":\"{a.code}\"}"
          | .ok r => do
            let defined ← IO.FS.withFile streams .write fun h => writeStreams h p m venue pol stop
            let nodes := match defined with
              | .ok n => s!"\{\"defined\":{n}}"
              | .error a => s!"\"{a.code}\""
            pure (runJson p r nodes)
      IO.FS.writeFile (outDir ++ s!"/{i}.json") result
      i := i + 1
    return 0
  | ["bench", prog, mkt, reps] =>
    let some v := (Json.parse (← IO.FS.readFile mkt)).toOption | IO.eprintln "bad market"; return 3
    let (m, venue, pol, stop) := market v
    let .ok p := Ref.check (← IO.FS.readFile prog) | IO.println "null"; return 0
    let mut ms := #[]
    for i in [0:reps.toNat!] do
      let t0 ← IO.monoNanosNow
      let .ok r := Ref.run floatOps p m venue pol (stop + if i > reps.toNat! then 1 else 0) | IO.println "null"; return 0
      if r.returns.isEmpty then IO.println "null"; return 0
      ms := ms.push (toString (((← IO.monoNanosNow) - t0).toFloat / 1e6))
    IO.println (list ms)
    return 0
  | _ => IO.eprintln "usage: refmm check PROGRAM | refmm run PROGRAMS MARKET OUT_DIR | refmm bench PROGRAM MARKET REPS"; return 2
