import Engine.Start

/-!
# What OCaml calls (B1, B2)

The machine's pure functions as C symbols, over flat byte arrays. `inspect` is the integrity inspection of
`CLAUDE.md`'s Holdout rule: a count of records and the stale spans of each coin, and no value of any record.
-/

namespace Engine.Machine

open Engine.Json

structure FeedResult where
  state : State
  report : String
  trace : String

structure FinishResult where
  report : String
  trace : String
  summary : String

@[export mm2_machine_start]
def startExported (program header : String) : Except String State := start program header

@[export mm2_machine_feed]
def feedExported (s : State) (records integers doubles : ByteArray) : FeedResult :=
  let r := feed s ⟨records, integers, doubles⟩
  ⟨r.1, r.2.report, r.2.trace⟩

@[export mm2_machine_finish]
def finishExported (s : State) : FinishResult :=
  let r := finish s
  ⟨r.1.report, r.1.trace, r.2⟩

@[export mm2_machine_snapshot]
def snapshot (s : State) : String := (repr s).pretty 1000000000

@[export mm2_machine_count]
def countExported (s : State) : UInt64 := s.count.toUInt64

@[export mm2_windows_json]
def windowsExported (_ : Unit) : String := windowsJson windows

/-- The strict reading of a policy file, for the build and for the identity; its canonical text. -/
@[export mm2_compile_windows]
def compileWindows (text : String) : Except String String :=
  match parseWindows text with
  | .ok ws => .ok (windowsJson ws)
  | .error message => .error message

/-- The half-open spans of `[start, stop)` in which a coin with these quote times (ascending) is stale. -/
def staleSpans (cfg : Config) (quotes : List Int) : List (Int × Int) :=
  let step := fun (acc : Int × List (Int × Int)) (q : Int) =>
    let a := max acc.1 cfg.start
    let b := min q cfg.stop
    ((q + cfg.gap), if a < b then (a, b) :: acc.2 else acc.2)
  let (from_, spans) := quotes.foldl step (cfg.start, [])
  let a := max from_ cfg.start
  (if a < cfg.stop then (a, cfg.stop) :: spans else spans).reverse

def quoteTimes (events : List Event) (coin : Nat) : List Int :=
  events.filterMap fun e =>
    match e.payload with
    | .quote _ _ => if e.coin == coin then some e.time else none
    | _ => none

def spanJson (name : String) (span : Int × Int) : String :=
  "{\"coin\":\"" ++ escape name ++ "\",\"start\":" ++ toString span.1 ++ ",\"end\":" ++ toString span.2 ++ "}"

/-- The count of records and the stale spans of a chunk under a header: the chunk is not admitted. -/
def inspectChunk (header : String) (c : Chunk) : Except String String := do
  let cfg ← parseHeader header
  let events ← decodeWith cfg c
  let spans := (List.range cfg.names.length).flatMap fun i =>
    (staleSpans cfg (quoteTimes events i)).map (spanJson (cfg.names.getD i "?"))
  return "{\"records\":" ++ toString events.length ++ ",\"stale\":[" ++ ",".intercalate spans ++ "]}"

@[export mm2_machine_inspect]
def inspectExported (header : String) (records integers doubles : ByteArray) : Except String String :=
  inspectChunk header ⟨records, integers, doubles⟩

end Engine.Machine
