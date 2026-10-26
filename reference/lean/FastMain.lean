import Ref.Io
import Fast.Sim

/-!
fastmm: the fast Lean engine (Fast/), with refmm's `run` and `bench` interfaces (Main.lean); programs are checked
by the reference checker. `bench` times indexing and the run, not the conversion of the parsed market into Fast's
rows (the counterpart of mm's load). `phases PROGRAM MARKET` prints the indexing and run times separately.
-/

open Ref Json Ref.Io

/-- Every node's value for every coin at every tick of the machine's schedule, as refmm's `writeStreams`
writes them; returns how many were defined. -/
def writeStreams (h : IO.FS.Handle) (cx : Fast.Cx) : IO (Except Abort Nat) := do
  let mut m ← match cx.start with
    | .error a => return .error a
    | .ok m => pure m
  let mut n := 0
  for k in [0:4 * cx.steps + 1] do
    if k > 0 then
      let hr := cx.wStart + k.toInt64 * Fast.HOUR
      m := (m.deliver cx (hr + cx.delta)).tick cx (cx.mask hr) hr
    let mut b := ByteArray.emptyWithCapacity (9 * m.val.size)
    for x in m.val do
      b := pushVal b (if Fast.def? x then some x else none)
      if Fast.def? x then n := n + 1
    h.write b
  return .ok n

def toRun (o : Fast.Out) : Run Float :=
  { trace := o.trace.map Fast.Ev.toRef, returns := o.returns.data, grossReturns := o.gross.data, equity := o.equity.data }

def main (args : List String) : IO UInt32 := do
  match args with
  | ["run", programs, mkt, outDir] =>
    let some v := (Json.parse (← IO.FS.readFile mkt)).toOption | IO.eprintln "bad market"; return 3
    let (m, venue, pol, stop) := market v
    let paths := (← IO.FS.readFile programs).splitOn "\n" |>.filter (· ≠ "")
    let mut i := 0
    for prog in paths do
      let streams : System.FilePath := outDir ++ s!"/{i}.bin"
      let result ← match Ref.check (← IO.FS.readFile prog) with
        | .error c => pure s!"\{\"reject\":\"{c.name}\"}"
        | .ok p =>
          let cx := Fast.Cx.make p (Fast.Mkt.ofRef m venue) pol stop
          match cx.run with
          | .error a => pure s!"\{\"abort\":\"{a.code}\"}"
          | .ok r => do
            let defined ← IO.FS.withFile streams .write fun h => writeStreams h cx
            let nodes := match defined with
              | .ok n => s!"\{\"defined\":{n}}"
              | .error a => s!"\"{a.code}\""
            pure (runJson p (toRun r) nodes)
      IO.FS.writeFile (outDir ++ s!"/{i}.json") result
      i := i + 1
    return 0
  | ["bench", prog, mkt, reps] =>
    let some v := (Json.parse (← IO.FS.readFile mkt)).toOption | IO.eprintln "bad market"; return 3
    let (m, venue, pol, stop) := market v
    let mk := Fast.Mkt.ofRef m venue
    let .ok p := Ref.check (← IO.FS.readFile prog) | IO.println "null"; return 0
    let mut ms := #[]
    for i in [0:reps.toNat!] do
      let t0 ← IO.monoNanosNow
      let .ok r := (Fast.Cx.make p mk pol (stop + if i > reps.toNat! then 1 else 0)).run | IO.println "null"; return 0
      if r.returns.size == 0 then IO.println "null"; return 0
      ms := ms.push (toString (((← IO.monoNanosNow) - t0).toFloat / 1e6))
    IO.println (list ms)
    return 0
  | ["phases", prog, mkt] =>
    let some v := (Json.parse (← IO.FS.readFile mkt)).toOption | IO.eprintln "bad market"; return 3
    let (m, venue, pol, stop) := market v
    let mk := Fast.Mkt.ofRef m venue
    let .ok p := Ref.check (← IO.FS.readFile prog) | IO.println "null"; return 0
    for i in [0:3] do
      let t0 ← IO.monoNanosNow
      let cx := Fast.Cx.make p mk pol (stop + if i > 5 then 1 else 0)
      IO.println s!"rows {cx.fRows.size} {cx.bRows.size} {cx.barsBy.size}"
      let t1 ← IO.monoNanosNow
      let .ok r := cx.run | IO.println "null"; return 0
      let t2 ← IO.monoNanosNow
      IO.println s!"make {(t1 - t0).toFloat / 1e6} run {(t2 - t1).toFloat / 1e6} trace {r.trace.size}"
    return 0
  | _ => IO.eprintln "usage: fastmm run PROGRAMS MARKET OUT_DIR | fastmm bench PROGRAM MARKET REPS | fastmm phases PROGRAM MARKET"; return 2
