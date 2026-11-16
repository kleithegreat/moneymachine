/- Brief 3 step 5, tests 1--11. Builder contract (Lean only):
   Existing Engine.check : String → String; Machine.start : String → String →
   Except String State; pack : List Event → Chunk; feed : State → Chunk →
   State × Rows; finish : State → Rows × String; Lang.bitsOps : NumOps UInt64;
   Exact.onGrid : Nat → Int → Rat → Bool. Event/Number/Level/Rules are A18's
   existing records; Rows.report/trace : String are the engine's A19 bytes.

   Machine.Move.event : Event → Move
   Machine.Move.offer : Nat → Nat → Nat → Rat → Ledger.Role → Move
   Machine.offer : State → Nat → Nat → Nat → Rat → Ledger.Role → State × Rows
   Machine.orderRun : {α : Type} → Lang.NumOps α → State → List Move → Option Orders.Run
   Run.rows : Rows; Run.wishes : List Wish; Run.placed : List Placement;
   Run.admissions : List Admission; Run.fills : List OrderFill;
   Run.tickWorlds : List (Int × Nat × List (Option Rat)).
   Wish: coin slot cycle : Nat, value : Option Value, sent arrives : Int;
   Value: price : Rat, target : Option Rat (none = close);
   Placement: order : Order, value : Value; Order: coin slot cycle : Nat,
   price : Rat, target : Option Rat, remainder : Rat, placed : Int;
   OrderFill: order : Order, units : Rat, before : Book;
   Admission: order : Order, book : Book, positionMargin equity minimum cap : Rat,
   leverage takerRate : Nat → Rat; Book.position : Nat → Rat, orders : List Order.
   Full law-facing records/signatures are in Laws.lean; crossings' extra fields
   are in orders-crossings.lean. Value/Wish/Order and State have DecidableEq.

   orderRun OBSERVES calls to the SAME feed/offer/finish, never a test venue.
   Each offer below has positive LOT COUNTS and positive price; the engine
   converts lots by the rules in force. It acts at the last fed event's time,
   after that event and before its tick. No fixture calls the step-2 ledger
   to supply a fill. No offer is exported to C, OCaml or mm2.
   tickWorlds samples the ACTUAL world delta earlier: pos,equity, then each
   slot's filled/resting/resting_price. Not the view or a fold of output rows.
   At delta=0 it is the world as the tick finds it, before after-tick arrivals.
   Only the test retains history; the ordinary engine must not.
   Programs/headers are exactly A17/A18; effects and probes are A19 from this
   step. A7 arrival/matching/IOC cancels wait on step 6; liquidation/floor wait
   on step 7. This file imports no Laws and all data is synthetic. -/
import Engine.Machine

open Engine.Machine Engine.Lang Engine.Orders

namespace Step5Orders

def base : Int := 1775174400000
def at (t : Int) := base + t
def js (s : String) := "\"" ++ s ++ "\""
def obj (xs : List (String × String)) :=
  "{" ++ ",".intercalate (xs.map fun (k, v) => js k ++ ":" ++ v) ++ "}"
def arr (xs : List String) := "[" ++ ",".intercalate xs ++ "]"
def ex (s u : String) := obj [("exact", js s), ("unit", js u)]
def inp (s : String) := obj [("input", js s)]
def own (s name : String) := obj [("input", js s), ("slot", js name)]
def op (s : String) (xs : List String) := obj [("op", js s), ("args", arr xs)]
def num (n : Int) := obj [("const", toString n), ("unit", js "1")]
def yes := op "gt" [ex "1" "1", ex "0" "1"]
def positive := op "gt" [inp "pos", ex "0" "coin"]
def phase (n : Int) := op "and"
  [op "gt" [inp "vol", num (n - 1)], op "lt" [inp "vol", num (n + 1)]]
def price := ex "100" "usd/coin"
def slot (name : String) (p := price) (size := ex "1" "coin")
    (condition := yes) (side := "buy") (tif := "gtc") (reduce := false) :=
  obj [("name", js name), ("side", js side), ("when", condition), ("price", p),
       ("size", size), ("tif", js tif), ("reduce_only", if reduce then "true" else "false")]
def close (name := "exit") (p := ex "110" "usd/coin") (condition := positive)
    (side := "sell") := slot name p (js "close") condition side "gtc" true
def probe (name expression : String) := obj [("name", js name), ("is", expression)]
def program (slots : List String) (probes : List String := []) (leverage : Nat := 1) (decide : Nat := 1) :=
  obj [("version", "2"), ("tick", "1"), ("decide_every", toString decide),
       ("leverage", toString leverage), ("sources", arr [obj [("name", js "vol"), ("unit", js "1")]]),
       ("params", "[]"), ("let", "[]"), ("slots", arr slots), ("probes", arr probes)]

structure Market where
  stop : Int := 12001
  lambda : Int := 0
  delta : Int := 0
  cash : String := "10000"
  minimum : String := "0"
  cap : String := "10000"
  fee : String := "0"
  sz : Nat := 2
  coins : Nat := 1
  stale : Int := 60000

def header (h : Market) :=
  let coin := fun name => obj [("name", js name), ("sz_decimals", toString h.sz),
    ("figures", "5"), ("decimals", toString (6 - h.sz)),
    ("tiers", arr [obj [("from", js "0"), ("max_leverage", "10")]])]
  obj [("horizon", obj [("start", toString base), ("end", toString (at h.stop))]),
    ("venue", obj [("fill", js "pessimistic"), ("lambda", toString h.lambda),
      ("delta", toString h.delta), ("stale", toString h.stale),
      ("cap", js h.cap), ("minimum", js h.minimum)]), ("cash", js h.cash),
    ("coins", arr ((["A", "B"].take h.coins).map coin)),
    ("fees", arr [obj [("from", toString base), ("tier", js "base"),
      ("maker", js h.fee), ("taker", js h.fee)]]),
    ("sources", obj [("listings", obj [("lag", "0")]),
      ("funding", obj [("encoding", js "string"), ("lag", "0"), ("late", "1000")]),
      ("quotes", obj [("encoding", js "string")]), ("trades", obj [("encoding", js "string")]),
      ("observations", arr [obj [("name", js "vol"), ("unit", js "1"),
        ("kind", js "state"), ("lag", "0")]])]),
    ("aliases", obj [("coins", "{}"), ("sources", "{}")])]

def number (s : String) : Number :=
  match s.splitOn "." with
  | [a, b] => .placed ((a ++ b).toInt?.getD 0) b.length
  | _ => .placed (s.toInt?.getD 0) 0
def event (t : Int) (p : Payload) (delta := 0) (coin := 0) : Move :=
  .event {coin, time := at t, known := at (t + delta), payload := p}
def book (t : Int) (bid := "99") (ask := "101") (delta := 0) (coin := 0) :=
  event t (.quote [{price := number bid, size := number "100"}]
                    [{price := number ask, size := number "100"}]) delta coin
def signal (t : Int) (n : Float) (coin := 0) := event t (.observation 0 n.toBits) 0 coin
def print (t : Int) (p : String) (delta := 0) :=
  event t (.trade t (number p) (number "100") true) delta
def rules (t : Int) (sz : Nat := 3) (lev : Int := 10) :=
  event t (.listing {szDecimals := sz, figures := 5, decimals := (6 : Int) - sz,
    tiers := [(number "0", lev)]})
def offer (slot lots : Nat) (p : Rat := 100) (role := Engine.Ledger.Role.maker)
    (coin := 0) : Move := .offer coin slot lots p role

def require (name : String) (ok : Bool) : IO Unit := do
  unless ok do throw (IO.userError name)
def test (name : String) (body : IO Unit) : IO Unit := do
  body
  IO.println s!"{name}: passed"
-- Keep the later-step assertion bodies, but do NOT execute them at step 5.
def skip (name reason : String) (_body : IO Unit := pure ()) : IO Unit :=
  IO.println s!"{name}: SKIPPED ({reason})"
def run (p : String) (h : Market) (moves : List Move) : IO Run := do
  let s ← match start p (header h) with
    | .ok s => pure s
    | .error code => throw (IO.userError s!"start: {code}")
  match orderRun bitsOps s moves with
  | some r =>
    let (world, output) := moves.foldl (fun (acc : State × Rows) move =>
      let next := match move with
        | .event e => feed acc.1 (pack [e])
        | .offer coin slot lots price role => Engine.Machine.offer acc.1 coin slot lots price role
      (next.1, {report := acc.2.report ++ next.2.report,
                trace := acc.2.trace ++ next.2.trace})) (s, {report := "", trace := ""})
    let (last, summary) := finish world
    require "ordinary feed/offer/finish succeeds" (summary.startsWith "{\"ok\":true")
    require "instrumentation is exactly the linked engine's feed/offer/finish"
      (r.rows.report == output.report ++ last.report && r.rows.trace == output.trace ++ last.trace)
    pure r
  | none => throw (IO.userError "synthetic event/offer sequence rejected")

abbrev Row := List String
def rows (r : Run) : List Row :=
  ((r.rows.trace.splitOn "\n").filter (· != "")).map (·.splitOn "\t")
def field (r : Row) (i : Nat) := r[i]?.getD ""
def kind (k : String) (rs : List Row) := rs.filter (fun r => field r 0 == k)
def time (r : Row) := (field r 1).toInt?.getD 0 - base
def during (t : Int) (rs : List Row) := rs.filter (fun r => time r == t)
def named (name : String) (rs : List Row) := rs.filter (fun r => field r 3 == name)
def placed (name : String) (r : Run) := named name (kind "placed" (rows r))
def fills (name : String) (r : Run) := named name (kind "fill" (rows r))
def rat (s : String) : Rat :=
  match s.splitOn "/" with
  | [a, b] => (a.toInt?.getD 0 : Rat) / (b.toInt?.getD 1 : Rat)
  | _ => (s.toInt?.getD 0 : Rat)
def sum (i : Nat) (rs : List Row) : Rat := rs.foldl (fun a r => a + rat (field r i)) 0
def tick (t : Int) (r : Run) (coin := "A") : List String :=
  match (kind "tick" (rows r)).find? (fun row => time row == t && field row 2 == coin) with
  | some row => row.drop 6
  | none => ["MISSING TICK"]
def equal (name : String) (x y : Rat) := require name (x == y)
def value (name : String) (rs : List Row) (i : Nat) (x : Rat) : IO Unit := do
  require (name ++ " exists") (!rs.isEmpty)
  equal name (rat (field (rs.headD []) i)) x
def accountProbes (names : List String) :=
  [probe "pos" (inp "pos"), probe "equity" (inp "equity")] ++ names.flatMap (fun n =>
    [probe (n ++ "_filled") (own "filled" n), probe (n ++ "_rest") (own "resting" n),
     probe (n ++ "_price") (own "resting_price" n)])

def ladder : List (String × String × String × Rat × Rat) :=
  [("level1", "0.9775", "1", 9775/1000, 1),
   ("level2", "0.9646", "1.93", 9646/1000, 193/100),
   ("level3", "0.9496", "3.80", 9496/1000, 380/100),
   ("level4", "0.9300", "7.47", 93/10, 747/100),
   ("level5", "0.9015", "14.68", 9015/1000, 1468/100)]
def ladderSlots := ladder.map fun (n, ratio, target, _, _) =>
  slot n (op "mul" [inp "first_price", ex ratio "1"])
    (op "mul" [inp "first_size", ex target "1"]) positive "buy" "alo"

def test1 : IO Unit := do
  test "step5_1_sort_errors" do
    let fp := obj [("const", "100"), ("unit", js "usd/coin")]
    let fs := obj [("const", "1"), ("unit", js "coin")]
    for p in [program [slot "entry" fp], program [slot "entry" price fs],
        program [slot "entry" (op "add" [price, fp])],
        program [slot "entry" (op "if" [yes, price, price])]] do
      require "float/exact sorts are not coerced" ((Engine.check p).startsWith "{\"error\":\"E_TYPE\"")
    require "slot price unit" ((Engine.check (program [slot "entry" (ex "100" "usd")])).startsWith
      "{\"error\":\"E_UNIT\"")
  test "step5_1_crossings" do
    let f := op "add" [obj [("const", "0.1"), ("unit", js "1")],
                          obj [("const", "0.2"), ("unit", js "1")]]
    let e := op "exact" [f]
    let ps := [probe "e" e, probe "f" (op "float" [e]),
      probe "decimal" (op "add" [ex "0.1" "1", ex "0.2" "1"]),
      probe "tie" (op "float" [ex "9007199254740993" "1"]),
      probe "zero" (op "div" [ex "1" "1", ex "0" "1"]),
      probe "overflow" (op "float" [ex ("1" ++ String.ofList (List.replicate 400 '0')) "1"])]
    let r ← run (program [] ps) {stop := 1} []
    require "exact means the binary64, not a decimal; tie and overflow" (tick 0 r ==
      ["1351079888211149/4503599627370496", "3fd3333333333334", "3/10", "4340000000000000", "-", "-"])
  test "step5_1_nonfinite" do
    for bits in ([0x7ff8000000000000, 0x7ff0000000000000, 0xfff0000000000000] : List UInt64) do
      let p := op "mul" [price, op "exact" [inp "vol"]]
      let r ← run (program [slot "entry" p]) {stop := 2001}
        [book 0, event 0 (.observation 0 bits), book 1, book 1001]
      require "nonfinite price is inactive" ((placed "entry" r).isEmpty)
    let r ← run (program [slot "entry" price (op "mul" [ex "1" "coin",
      op "exact" [op "div" [num 1, num 0]]])]) {stop := 1001} [book 0]
    require "undefined target is inactive" ((placed "entry" r).isEmpty)
  test "step5_1_rounding_notional" do
    let p := ex "100.0019" "usd/coin"
    let r ← run (program [slot "notional" p (ex "100" "usd"),
      slot "sell" p (ex "1.239" "coin") yes "sell"]) {stop := 1} [book 0]
    value "buy rounds down" (placed "notional" r) 8 100
    value "notional divides BEFORE price rounding" (placed "notional" r) 9 (99/100)
    value "sell rounds up" (placed "sell" r) 8 (10001/100)
    value "target rounds toward zero" (placed "sell" r) 9 (123/100)

def test2 : IO Unit := do
  test "step5_2_published_ladder" do
    let r ← run (program (slot "first" (ex "10" "usd/coin") (ex "1" "coin") (phase 1) :: ladderSlots))
      {stop := 1501} [book 0 "9.9" "10", signal 0 1, book 1 "9.9" "10",
        offer 0 100 10 .taker, signal 500 0]
    equal "entry filled at ten" (sum 10 (fills "first" r)) 1
    for (n, _, _, p, target) in ladder do
      require "one placed ladder wish" ((placed n r).length == 1)
      value (n ++ " exact price") (placed n r) 8 p
      value (n ++ " exact target") (placed n r) 9 target
      require "published ladder is on grid" (Engine.Exact.onGrid 5 4 p)
  test "step5_2_argon_swept_first" do
    let ps := [probe "size" (inp "first_size"), probe "price" (inp "first_price")]
    let r ← run (program [slot "first" (ex "12" "usd/coin") (ex "1" "coin") (phase 1)] ps)
      {stop := 1001} [book 0 "9.9" "10", signal 0 1,
        event 1 (.quote [{price := number "9.9", size := number "10"}]
          [{price := number "10", size := number "0.1"},
           {price := number "11", size := number "0.9"}]),
        offer 0 10 10 .taker, offer 0 90 11 .taker, signal 500 0]
    require "two opening-order fills" ((fills "first" r).length == 2)
    require "size-weighted mean is 10.9" (tick 1000 r == ["1", "109/10"])

def test3 : IO Unit := test "step5_3_replacement_not_twice" do
  let p := program [slot "entry" (op "mul" [price, op "exact" [inp "vol"]]) (ex "10" "coin")]
    [probe "filled" (own "filled" "entry")]
  let r ← run p {stop := 6001, lambda := 2000, delta := 4000}
    [book 0 "99" "101" 4000, signal 0 1, book 2001 "99" "101" 4000,
     signal 3000 0.99, print 4500 "98" 4000, offer 0 600 100,
     book 5001 "98" "100" 4000, print 5500 "98" 4000, offer 0 2000 99]
  require "wish still read filled zero" (tick 3000 r == ["0"])
  value "arrival subtracts old fill" (during 5000 (placed "entry" r)) 10 4
  equal "does not buy twice" (sum 10 (fills "entry" r)) 10
  equal "new order fills only four" (sum 10 ((fills "entry" r).filter (fun row => time row >= 5000))) 4

def test4 : IO Unit := do
  test "step5_4_close_follows_position" do
    let r ← run (program [slot "first" price (ex "3" "coin") (phase 1),
      slot "level" (ex "90" "usd/coin") (ex "1" "coin") (phase 2), close "exit"]
      [probe "pos" (inp "pos"), probe "rest" (own "resting" "exit")]) {stop := 3001}
      [book 0, signal 0 1, book 1, offer 0 300, signal 500 0,
       book 1001, print 1500 "111", offer 2 100 110,
       signal 2000 2, book 2001 "89" "90", offer 1 100 90]
    require "partial close leaves two" (tick 2000 r == ["2", "2"])
    require "level raises remainder with no replacement" (tick 3000 r == ["3", "3"])
    require "one close placement" ((placed "exit" r).length == 1)
  test "step5_4_close_flat_retries" do
    let r ← run (program [slot "entry" price (ex "1" "coin") (phase 2), close "exit" (ex "110" "usd/coin") yes])
      {stop := 3001} [book 0, signal 0 0, signal 2000 2, book 2001, offer 0 100]
    require "flat close retries" ((placed "exit" r).map time == [3000])
  test "step5_4_argon_buy_close_long" do
    let r ← run (program [slot "entry" price (ex "1" "coin") (phase 1),
      close "wrong" (ex "110" "usd/coin") positive "buy"]) {stop := 3001}
      [book 0, signal 0 1, book 1, offer 0 100, signal 500 0, book 1001]
    equal "fixture long" (sum 10 (fills "entry" r)) 1
    require "buy close on long places nothing" ((placed "wrong" r).isEmpty)

def weightProgram :=
  let wanted := op "mul" [op "exact" [inp "vol"], ex "1" "coin"]
  let w := op "div" [op "mul" [wanted, inp "ask"], inp "equity"]
  let goal := op "div" [op "mul" [w, inp "equity"], inp "ask"]
  let target := fun name diff => op "add" [own "filled" name, op "max" [ex "0" "coin", diff]]
  program [slot "buy" (inp "ask") (target "buy" (op "sub" [goal, inp "pos"])) yes "buy" "ioc",
    slot "sell" (inp "bid") (target "sell" (op "sub" [inp "pos", goal])) yes "sell" "ioc"]
    [probe "pos" (inp "pos")]

def test5 : IO Unit := do
  test "step5_5_target_below_filled" do
    let r ← run (program [slot "entry" price (op "mul" [ex "1" "coin", op "exact" [inp "vol"]])]
      [probe "filled" (own "filled" "entry"), probe "rest" (own "resting" "entry")]) {stop := 2001}
      [book 0, signal 0 10, book 1, offer 0 600, signal 1000 4]
    require "below accumulated fills places nothing" (tick 2000 r == ["6", "0"])
    require "no negative-capacity replacement" ((placed "entry" r).length == 1)
  test "step5_5_weight_10_15_8_12" do
    let r ← run weightProgram {stop := 8001}
      [book 0 "99" "100", signal 0 10, book 1001 "99" "100", offer 0 1000,
       signal 2000 15, book 3001 "99" "100", offer 0 500,
       signal 4000 8, book 5001 "99" "100", offer 1 700 99,
       signal 6000 12, book 7001 "99" "100", offer 0 400]
    for (t, s) in ([(2000, "10"), (4000, "15"), (6000, "8"), (8000, "12")] : List (Int × String)) do
      require "weight tracked without flattening" (tick t r == [s])
    require "no cycle ended" ((kind "cycle_end" (rows r)).isEmpty)
  test "step5_5_argon_sale_in_flight" do
    let q := fun t => book t "99" "100" 2000
    let r ← run weightProgram {stop := 16001, delta := 2000}
      [q 0, signal 0 10, q 2001, offer 0 1000,
       signal 6000 15, q 6001, offer 0 500,
       signal 10000 8, q 10001, offer 1 700 99,
       signal 11000 12, q 11001, q 13001, offer 0 400]
    require "sale still unseen" (tick 11000 r == ["15"])
    require "first tick sees eight" (tick 13000 r == ["8"])
    equal "first eligible buy is four" (sum 10 (during 13001 (fills "buy" r))) 4
    equal "sale subtracted once" (sum 10 (fills "sell" r)) (-7)
    require "reaches twelve" (tick 16000 r == ["12"])
    require "never flat" ((kind "cycle_end" (rows r)).isEmpty)

def test6 : IO Unit := do
  test "step5_6_gpt_one_wish" do
    let p := op "mul" [ex "1" "usd/coin", op "exact" [inp "vol"]]
    let r ← run (program [slot "entry" p]) {stop := 8001, lambda := 2500}
      [book 0, signal 0 100, signal 1000 99, signal 2000 98, book 5001]
    require "FIFO, once, across more than two ticks" ((placed "entry" r).map (fun row =>
      (time row, field row 8)) == [(2500, "100"), (3500, "99"), (4500, "98")])
    require "equal wishes do not replace again" ((kind "cancelled" (rows r)).length == 2)
  test "step5_6_equal_arrivals" do
    let r ← run (program [slot "entry"]) {stop := 6001, lambda := 2500} [book 0, book 5001]
    require "one placement for equal wishes" ((placed "entry" r).map time == [2500])
    require "equal arrivals cancel nothing" ((kind "cancelled" (rows r)).isEmpty)
  test "step5_6_deciding_ticks_only" do
    let p := op "mul" [ex "1" "usd/coin", op "exact" [inp "vol"]]
    let r ← run (program [slot "entry" p] [] 1 3) {stop := 7001, lambda := 2500}
      [book 0, signal 0 100, signal 1000 99, signal 2000 98, signal 3000 97]
    require "nondeciding ticks send no wishes" ((placed "entry" r).map (fun row =>
      (time row, field row 8)) == [(2500, "100"), (5500, "97")])
  skip "step5_6_ioc_retries" "waiting on step 6: an empty IOC is cancelled at its A7 arrival" do
    let r ← run (program [slot "entry" price (ex "1" "coin") yes "buy" "ioc"])
      {stop := 2001} [book 0, book 1, book 1001 "99" "100"]
    require "empty IOC sent again next tick" ((placed "entry" r).map time == [0, 1000])
    equal "retried IOC fills" (sum 10 (fills "entry" r)) 1
  test "step5_6_refusal_retries" do
    let r ← run (program [slot "block" (ex "60" "usd/coin") (ex "1" "coin") (phase 1),
      slot "entry" (ex "60" "usd/coin")]) {stop := 1501, cash := "100"}
      [book 0, signal 0 1, signal 500 0]
    require "first wish margin-refused" ((named "entry" (kind "refused" (rows r))).any
      (fun row => time row == 0 && field row 5 == "margin"))
    require "next wish retries" ((placed "entry" r).map time == [1000])

def admissionOrder (reverse : Bool) : IO Unit := do
  let a := slot "zeta" price (ex "1" "coin") (phase 2)
  let b := slot "alpha" price (ex "1" "coin") (phase 2)
  let reduce := close "reduce" price (phase 2)
  let rest := if reverse then [reduce, b, a] else [a, b, reduce]
  let r ← run (program (slot "first" price (ex "1" "coin") (phase 1) :: rest))
    {stop := 2001, coins := 2} [book 0, signal 0 1, book 0 "99" "101" 0 1,
      signal 0 1 1, book 1, offer 0 100, book 1 "99" "101" 0 1, offer 0 100 100 .maker 1,
      signal 1500 2, signal 1500 2 1]
  let normal := if reverse then ["alpha", "zeta"] else ["zeta", "alpha"]
  let expected := [("A", "reduce"), ("B", "reduce")] ++
    ["A", "B"].flatMap (fun c => normal.map fun n => (c, n))
  require "same-ms reduce,coin,program-slot admission order"
    ((during 2000 (kind "placed" (rows r))).map (fun row => (field row 2, field row 3)) == expected)

def test7 : IO Unit := do
  test "step5_7_admission_buy_written_first" (admissionOrder false)
  test "step5_7_admission_reduce_written_first" (admissionOrder true)
  test "step5_7_refusal_reasons_and_fee" do
    for (cash, cap, minimum, p, s, fee, reason) in
      [("99", "10000", "0", "100", "1", "0", "margin"),
       ("10000", "10000", "10", "1", "9", "0", "minimum"),
       ("10000", "99", "0", "100", "1", "0", "cap"),
       ("100", "10000", "0", "100", "1", "0.01", "margin")] do
      let r ← run (program [slot "entry" (ex p "usd/coin") (ex s "coin")])
        {stop := 1, cash, cap, minimum, fee} [book 0]
      let refused := kind "refused" (rows r)
      require "one refusal, correct condition" (refused.length == 1 &&
        field (refused.headD []) 5 == reason && (placed "entry" r).isEmpty)
    let r ← run (program [slot "entry"])
      {stop := 1, cash := "101", cap := "100", minimum := "100", fee := "0.01"} [book 0]
    require "equality admits all three boundaries" ((placed "entry" r).length == 1)
  test "step5_7_reducing_sell_no_margin" do
    let r ← run (program [slot "entry" price (ex "1" "coin") (phase 1), close "exit" price])
      {stop := 1001, cash := "101", fee := "0.01"}
      [book 0, signal 0 1, book 1, offer 0 100 100 .taker, signal 500 0]
    require "pure reduction reserves no margin or fee" ((placed "exit" r).length == 1)
  test "step5_7_dust_remainder" do
    let p := ex "10" "usd/coin"
    let r ← run (program [slot "entry" p (ex "3" "coin") (phase 1),
      slot "trim" p (ex "2.5" "coin") (phase 2) "sell" "ioc",
      slot "partial" p (ex "0.4" "coin") (phase 3) "sell", close "exit" p (phase 3)])
      {stop := 4001, minimum := "10"} [book 0 "9.9" "10", signal 0 1,
        book 1 "9.9" "10", offer 0 300 10, signal 1500 2,
        book 2001 "10" "10.1", offer 1 250 10, signal 3000 3]
    require "under-minimum partial reduction refused" ((kind "refused" (rows r)).any
      (fun row => field row 3 == "partial" && field row 5 == "minimum"))
    value "exact dust close is exception" (placed "exit" r) 10 (1/2)
    let r ← run (program [slot "entry" p (op "mul" [ex "1" "coin", op "exact" [inp "vol"]])])
      {stop := 1001, minimum := "10"} [book 0 "9.9" "10", signal 0 2,
        book 1 "9.9" "10", offer 0 150 10, signal 1000 2.1]
    require "minimum is checked on remainder" ((kind "refused" (rows r)).any
      (fun row => time row == 1000 && field row 5 == "minimum"))

def endAtFill (buyFirst : Bool) (matching := false) : IO Unit := do
  let entry := slot "entry" price (ex "1" "coin") (phase 1)
  let add := slot "add" (ex "120" "usd/coin") (ex "1" "coin") (phase 2)
  let exit := close "exit" price (phase 2)
  let slots := if buyFirst then [entry, add, exit] else [entry, exit, add]
  let sellSlot := if buyFirst then 2 else 1
  let buySlot := if buyFirst then 1 else 2
  let opening := [book 0, signal 0 1, book 1 "99" "100"] ++
    (if matching then [] else [offer 0 100])
  let ending := [signal 500 2, book 1001 "110" "111"] ++
    (if matching then [] else [offer sellSlot 100, offer buySlot 100 111])
  let r ← run (program slots) {stop := 2001} (opening ++ ending)
  require "both orders live before offers" ((during 1000 (placed "add" r)).length == 1 &&
    (during 1000 (placed "exit" r)).length == 1)
  equal "reduce-only offer ends cycle first" (sum 10 (fills "exit" r)) (-1)
  require "next offer finds no buy" ((fills "add" r).isEmpty)
  require "same-event buy cancelled before it can fill" ((kind "cancelled" (rows r)).any
    (fun row => time row == 1001 && field row 3 == "add" && field row 5 == "cycle_end"))

def test8 : IO Unit := do
  test "step5_8_gpt_pending_replacement" do
    let p := program [slot "first", slot "level" (op "mul" [price, op "exact" [inp "vol"]]),
      close "exit" (ex "40" "usd/coin")] [probe "equity" (inp "equity")]
    let r ← run p {stop := 10001, lambda := 2000, delta := 1000}
      [book 0 "99" "101" 1000, signal 0 1, book 2001 "99" "100" 1000,
       offer 0 100, offer 1 100, book 6001 "39" "41" 1000,
       signal 7000 0.9, print 7500 "41" 1000, offer 2 200 40,
       book 9501 "99" "101" 1000, print 9800 "80" 1000, offer 1 10000 90]
    equal "two opening units" (sum 10 (during 2001 (kind "fill" (rows r)))) 2
    equal "close both at forty" (sum 10 (fills "exit" r)) (-2)
    require "old-cycle replacement places nothing" ((kind "placed" (rows r)).all (fun row => time row < 7500))
    require "loses 120 not 220" (tick 10000 r == ["9880"])
  test "step5_8_argon_nine_of_ten" do
    let later := (List.range 64).flatMap fun i =>
      [print (5001 + i) "90" 2000, offer 0 1000 100]
    let r ← run (program [slot "level" price (ex "10" "coin") (phase 1), close "exit"])
      {stop := 6001, delta := 2000} ([book 0 "99" "101" 2000, signal 0 1,
        book 1 "99" "100" 2000, offer 0 900, book 3001 "99" "101" 2000,
        print 4500 "111" 2000, offer 1 900 110, signal 4600 0] ++ later)
    equal "nine filled, one still live" (sum 10 (fills "level" r)) 9
    require "remaining buy cancelled at ending offer" ((kind "cancelled" (rows r)).any
      (fun row => time row == 4500 && field row 3 == "level" && field row 5 == "cycle_end"))
    require "all later offers buy nothing" ((fills "level" r).all (fun row => time row < 4500))
  test "step5_8_new_cycle_delay" do
    let r ← run (program [slot "entry", close "exit"]) {stop := 7001, lambda := 500, delta := 1500}
      [book 0 "99" "101" 1500, book 501 "99" "100" 1500, offer 0 100,
       book 3501 "99" "101" 1500, print 4000 "111" 1500, offer 1 100 110,
       book 6501 "99" "100" 1500]
    let next := (placed "entry" r).filter (fun row => field row 4 == "2")
    require "new cycle begins at first eligible tick plus lambda"
      (!next.isEmpty && time (next.headD []) == 6500 && next.all (fun row => time row >= 6000))
  test "step5_8_argon_end_at_fill_buy_first" (endAtFill true)
  test "step5_8_argon_end_at_fill_sell_first" (endAtFill false)
  skip "step5_8_argon_nine_of_ten_prints" "waiting on step 6: rerun later offers as A7 prints" do
    let q := event 1 (.quote [{price := number "99", size := number "100"}]
      [{price := number "100", size := number "9"}]) 2000
    let exitPrint := event 4500 (.trade 1 (number "111") (number "9") false) 2000
    let later := (List.range 64).map fun i => print (5001 + i) "90" 2000
    let r ← run (program [slot "level" price (ex "10" "coin") (phase 1), close "exit"])
      {stop := 6001, delta := 2000} ([book 0 "99" "101" 2000, signal 0 1,
        q, book 3001 "99" "101" 2000, exitPrint, signal 4600 0] ++ later)
    equal "nine, not ten, and no later print buys" (sum 10 (fills "level" r)) 9
    require "buy cancelled at ending print" ((kind "cancelled" (rows r)).any
      (fun row => time row == 4500 && field row 3 == "level" && field row 5 == "cycle_end"))
  skip "step5_8_argon_end_at_fill_quote_buy_first" "waiting on step 6: quote offers in A6 order"
    (endAtFill true true)
  skip "step5_8_argon_end_at_fill_quote_sell_first" "waiting on step 6: quote offers in A6 order"
    (endAtFill false true)

def test9 : IO Unit := test "step5_9_gpt_wish_new_grid" do
  let r ← run (program [slot "first" (ex "1.1" "usd/coin"),
    slot "level" (ex "1.0001" "usd/coin") (ex "2" "coin") positive])
    {stop := 9001, lambda := 2000, delta := 1000}
    [book 0 "1.09" "1.1" 1000, book 2001 "1.09" "1.1" 1000,
     offer 0 100 (11/10), rules 7500, book 8001 "1.001" "1.002" 1000]
  require "rules cancel without ending open cycle" ((kind "cancelled" (rows r)).any
    (fun row => time row == 7500 && field row 3 == "level" && field row 5 == "rules") &&
    (kind "cycle_end" (rows r)).isEmpty)
  value "old-grid placement" (during 6000 (placed "level" r)) 8 (10001/10000)
  value "wish rounded on arrival's grid" (during 8000 (placed "level" r)) 8 1

/- Independent test-side effect fold. It is NOT used to manufacture tickWorlds.
   Exhaustion is an order's own fill, not a synthetic cancelled row. -/
structure Live where
  name : String
  side : String
  price : Rat
  target : Option Rat
structure Account where
  cash : Rat
  pos : Rat := 0
  filled : List (String × Rat) := []
  live : List Live := []
def filledAt (a : Account) (n : String) := ((a.filled.find? (fun x => x.1 == n)).map (·.2)).getD 0
def remainder (a : Account) (o : Live) : Rat := match o.target with
  | some t => max 0 (t - filledAt a o.name)
  | none => if o.side == "sell" then max 0 a.pos else max 0 (-a.pos)
def effect (a : Account) (row : Row) : Account :=
  let name := field row 3
  match field row 0 with
  | "placed" => {a with live := a.live ++ [{name, side := field row 5,
      price := rat (field row 8), target := if field row 9 == "close" then none else some (rat (field row 9))}]}
  | "cancelled" => {a with live := a.live.filter (fun o => o.name != name)}
  | "fill" =>
    let units := rat (field row 10)
    let n := filledAt a name + (if units < 0 then -units else units)
    let b := {a with cash := a.cash - units * rat (field row 9) - rat (field row 11),
      pos := a.pos + units, filled := (name, n) :: a.filled.filter (fun x => x.1 != name)}
    {b with live := b.live.filter (fun o => o.name != name || remainder b o > 0)}
  | "cycle_end" => {a with filled := [], live := []}
  | "paid" => {a with cash := a.cash + rat (field row 4)}
  | "bankrupt" => {a with cash := a.cash + rat (field row 2)}
  | _ => a
def projections (a : Account) (mark : Rat) (names : List String) : List (Option Rat) :=
  [some a.pos, some (a.cash + a.pos * mark)] ++ names.flatMap (fun n =>
    match a.live.find? (fun o => o.name == n) with
    | none => [some (filledAt a n), some 0, none]
    | some o => [some (filledAt a n), some (remainder a o), some o.price])
def isEffect (row : Row) :=
  ["placed", "refused", "cancelled", "fill", "cycle_end", "paid", "liquidated", "bankrupt"].contains (field row 0)

def checkEffects (r : Run) (delta : Int) (names : List String) (moves : List Move)
    (cash : Rat := 10000) : IO Unit := do
  let mut a : Account := {cash}
  let mut pending : List (Int × Row) := []
  let mut count := 0
  for row in rows r do
    if isEffect row then pending := pending ++ [(time row + delta, row)]
    else if field row 0 == "tick" then
      let due := pending.filter (fun x => x.1 <= time row)
      pending := pending.filter (fun x => x.1 > time row)
      for (_, e) in due do a := effect a e
      let bound := time row - delta
      let mark := moves.foldl (fun (p : Rat) m => match m with
        | .event e => if e.time <= at bound then match e.payload with
            | .quote bs asks =>
              let read := fun n => match n with
                | Number.placed z d => (z : Rat) / (10 : Rat)^d
                | .bits _ => 0
              match bs.head?, asks.head? with
              | some b, some ask => (read b.price + read ask.price) / 2
              | _, _ => p
            | .trade _ n _ _ => match n with
              | .placed z d => (z : Rat) / (10 : Rat)^d
              | .bits _ => p
            | _ => p
          else p
        | _ => p) 0
      let expected := projections a mark names
      let actual := (row.drop 6).map (fun s => if s == "-" then none else some (rat s))
      require "effect fold equals view" (actual == expected)
      let sampled := r.tickWorlds.find? (fun x => x.1 == at (time row) && x.2.1 == 0)
      require "view equals ACTUAL delayed world, not a second effect fold"
        (sampled.map (fun x => x.2.2) == some expected)
      count := count + 1
  require "nonempty world/view comparisons" (count > 0)

def effectsScenario (delta : Int) (seed : Nat) : IO Run := do
  let names := ["entry", "empty", "refuse", "exit"]
  let size := 2 + seed * 17 % 5
  let partial := 1 + seed * 13 % (size - 1)
  let p := program [slot "entry" price (ex (toString size) "coin") (phase 1),
    slot "empty" (ex "1" "usd/coin") (ex "1" "coin") (phase 2) "buy" "ioc",
    slot "refuse" price (ex "200" "coin") (phase 2), close "exit" (ex "110" "usd/coin") (phase 3)]
    (accountProbes names)
  let jitter : Int := (seed * 137 % 300 : Nat)
  let moves := [book 0 "99" "101" delta, signal 0 1, book 1 "99" "100" delta,
    offer 0 (100 * size) 100 (if seed % 2 == 0 then .maker else .taker),
    signal 4000 2, book 4001 "99" "101" delta,
    signal 6000 3, book 6001 "99" "101" delta,
    print (7100 + jitter) "111" delta, offer 3 (100 * partial) 110,
    book (8100 + jitter) "98" "100" delta, print 10100 "111" delta, offer 3 2000 110]
  let r ← run p {stop := 15001, delta, fee := if seed % 2 == 0 then "0" else "0.001", cap := "1000"} moves
  checkEffects r delta names moves
  pure r

def waitingLiquidation (bankrupt : Bool) : IO Unit := do
  let names := ["entry"]
  let moves := [book 0 "99" "101" 1000, signal 0 1, book 1 "99" "100" 1000,
    offer 0 200, signal 500 0,
    book 8100 (if bankrupt then "1" else "91") (if bankrupt then "2" else "92") 1000]
  let r ← run (program [slot "entry" price (ex "2" "coin") (phase 1)] (accountProbes names) 10)
    {stop := 15001, delta := 1000, cash := "25"} moves
  checkEffects r 1000 names moves 25
  require "liquidation really exercised" (!(kind "liquidated" (rows r)).isEmpty)
  require "floor exercised exactly in bankruptcy case" ((!((kind "bankrupt" (rows r)).isEmpty)) == bankrupt)

def test10 : IO Unit := do
  test "step5_10_effects_placed_refused_cycle" do
    let r ← effectsScenario 1500 1
    require "unfilled placement covered" (!(placed "empty" r).isEmpty && (fills "empty" r).isEmpty)
    require "refusal covered" (!(kind "refused" (rows r)).isEmpty)
    require "cycle end covered" (!(kind "cycle_end" (rows r)).isEmpty)
  skip "step5_10_effects_ioc_cancel" "waiting on step 6: A7 creates IOC remainder cancellations" do
    let moves := [book 0, book 1]
    let r ← run (program [slot "empty" (ex "1" "usd/coin") (ex "1" "coin") yes "buy" "ioc"]
      (accountProbes ["empty"])) {stop := 2001} moves
    checkEffects r 0 ["empty"] moves
    require "IOC cancel actually exercised" ((kind "cancelled" (rows r)).any (fun row => field row 5 == "ioc"))
  skip "step5_10_effects_liquidation" "waiting on step 7: A10 creates liquidation effects"
    (waitingLiquidation false)
  skip "step5_10_effects_bankruptcy" "waiting on step 7: A11 creates bankruptcy effects"
    (waitingLiquidation true)
  test "step5_10_random_effect_folds" do
    for seed in List.range 64 do
      let delta := ([0, 1, 999, 1000, 2500] : List Int)[seed % 5]?.getD 0
      let _ ← effectsScenario delta seed
      pure ()
  test "step5_10_argon_zero_delay_l1a" do
    let p := program [slot "entry"] (accountProbes ["entry"])
    let moves := [book 0, book 1]
    let r ← run p {stop := 2001} moves
    checkEffects r 0 ["entry"] moves
    require "tick cannot read its own after-tick wish" (tick 0 r == ["0", "10000", "0", "0", "-"])
    require "next tick reads unfilled order" (tick 1000 r == ["0", "10000", "0", "1", "100"])
    let s ← run p {stop := 2001} (moves ++ [book 1001 "97" "99"])
    require "L1a at delta zero, including after-tick effects"
      ((kind "tick" (rows r)).filter (fun row => time row <= 1000) ==
       (kind "tick" (rows s)).filter (fun row => time row <= 1000))

def test11 : IO Unit := do
  test "step5_11_offer_capped_by_remainder" do
    let r ← run (program [slot "entry" price (ex "10" "coin")]) {stop := 1001, sz := 0}
      [book 0, book 1, offer 0 15]
    equal "15 offered, ten filled" (sum 10 (fills "entry" r)) 10
  test "step5_11_reduce_only_cap_and_cancel" do
    let r ← run (program [slot "entry" price (ex "3" "coin") (phase 1),
      slot "exit" price (ex "5" "coin") positive "sell" "gtc" true]) {stop := 2001, sz := 0}
      [book 0, signal 0 1, book 1, offer 0 3, signal 500 0, book 1001, offer 1 5]
    equal "reduce-only fills only long three" (sum 10 (fills "exit" r)) (-3)
    require "cut remainder cancelled as reduce_only" ((kind "cancelled" (rows r)).any
      (fun row => field row 3 == "exit" && field row 5 == "reduce_only"))
  test "step5_11_offer_no_live_order" do
    let initial ← match start (program [slot "entry" price (ex "1" "coin") (phase 1)]) (header {}) with
      | .ok s => pure s
      | .error e => throw (IO.userError e)
    let s := (feed initial (pack [{coin := 0, time := base, known := base,
      payload := .observation 0 (0 : Float).toBits}])).1
    let (s', output) := Engine.Machine.offer s 0 0 100 100 .maker
    require "absent live order changes no state and writes no row"
      (decide (s' = s) && output.report == "" && output.trace == "")
  test "step5_11_offer_before_first_quote" do
    let p := program [slot "entry"]
    let initial ← match start p (header {}) with
      | .ok s => pure s
      | .error e => throw (IO.userError e)
    let obs := fun t => {coin := 0, time := at t, known := at t,
      payload := Payload.observation 0 (1 : Float).toBits : Event}
    let s := (feed initial (pack [obs 0, obs 1])).1
    let (s', output) := Engine.Machine.offer s 0 0 100 100 .maker
    require "live order before any quote changes nothing and writes no row"
      (decide (s' = s) && output.report == "" && output.trace == "")
    let r ← run p {stop := 1001} [.event (obs 0), .event (obs 1), offer 0 100]
    require "the no-quote fixture did have a live order" ((placed "entry" r).length == 1)
  test "step5_11_own_exhaustion_clears_resting" do
    let p := program [slot "entry" (op "mul" [price, op "exact" [inp "vol"]])]
      [probe "rest" (own "resting" "entry"), probe "price" (own "resting_price" "entry")]
    let r ← run p {stop := 2001} [book 0, signal 0 1, book 1, offer 0 100, signal 500 0.9]
    require "own exhaustion clears resting and price" (tick 1000 r == ["0", "-"])
    require "different next wish cancels no exhausted order" ((kind "cancelled" (rows r)).isEmpty)
  test "step5_11_flat_listing_end_blocks_wishes" do
    let ending : Event := {coin := 0, time := at 500, known := at 5000, payload := .ending (number "100")}
    let r ← run (program [slot "entry"]) {stop := 6001, lambda := 2500}
      [book 0, .event ending]
    require "wish in flight and later wishes place nothing" ((kind "placed" (rows r)).isEmpty)
    require "nonvacuous pre-end and post-end sent wishes" (r.wishes.any (fun w => w.sent == base) &&
      r.wishes.any (fun w => w.sent == at 1000))
  test "step5_11_identical_rules_cancel_nothing" do
    let r ← run (program [slot "entry"]) {stop := 1001} [book 0, rules 500 2]
    require "restating rules cancels nothing" ((placed "entry" r).length == 1 &&
      (kind "cancelled" (rows r)).isEmpty)
  test "step5_11_tier_only_change_cancels_rules" do
    let r ← run (program [slot "entry"]) {stop := 1001} [book 0, rules 500 2 9]
    require "tier-only change cancels with rules cause" ((kind "cancelled" (rows r)).any
      (fun row => time row == 500 && field row 3 == "entry" && field row 5 == "rules"))
  test "step5_11_notional_wish_unrounded" do
    let r ← run (program [slot "entry" (ex "3" "usd/coin") (ex "25" "usd")])
      {stop := 1} [book 0 "2.99" "3.01"]
    require "notional wishes exact 25/3" (r.wishes.any (fun w =>
      w.value == some {price := 3, target := some (25/3)}))
    value "places 8.33 whole lots" (placed "entry" r) 9 (833/100)
  test "step5_11_zero_price_notional_inactive" do
    let r ← run (program [slot "entry" (ex "0" "usd/coin") (ex "25" "usd")])
      {stop := 1} [book 0]
    require "zero-price notional inactive" ((placed "entry" r).isEmpty &&
      !r.wishes.isEmpty && r.wishes.all (fun w => w.value.isNone))
  test "step5_11_age_first_known_fill" do
    let r ← run (program [slot "entry" price (ex "2" "coin") (phase 1)]
      [probe "age" (inp "age")]) {stop := 4001, delta := 1500}
      [book 0 "99" "101" 1500, signal 0 1, book 500 "99" "101" 1500, offer 0 100]
    require "first known tick age zero; next one" (tick 1000 r == ["-"] &&
      tick 2000 r == ["0"] && tick 3000 r == ["1"])
  test "step5_11_later_order_not_opening_order" do
    let target := op "mul" [ex "1" "coin", op "exact" [inp "vol"]]
    let r ← run (program [slot "entry" price target]
      [probe "size" (inp "first_size"), probe "price" (inp "first_price")]) {stop := 3001}
      [book 0, signal 0 1, book 1, offer 0 100 100, signal 1000 2,
       book 1001 "98" "100", offer 0 100 99]
    require "later order of same slot really filled" ((fills "entry" r).length == 2 &&
      (placed "entry" r).length == 2)
    require "opening order figures unchanged" (tick 3000 r == ["1", "100"])
  test "step5_11_reversal_requirement_fee_on_opened_part" do
    let r ← run (program [slot "entry" price (ex "3" "coin") (phase 1),
      slot "reverse" price (ex "5" "coin") positive "sell"]) {stop := 1001, fee := "0.00045"}
      [book 0, signal 0 1, book 1, offer 0 300, signal 500 0]
    let a ← match r.admissions.find? (fun a => a.order.slot == 1) with
      | some a => pure a
      | none => throw (IO.userError "missing reversal admission")
    equal "sell five opens two, not zero or five; fee on two"
      (2 * a.order.price * (1 / a.leverage 0 + a.takerRate 0)) (2 * 100 * (100045/100000))
    require "reversal actually placed" ((placed "reverse" r).length == 1)
    -- Boundary rejects the wrong requirement, including a fee on all five.
    let p := program [slot "entry" price (ex "3" "coin") (phase 1),
      slot "reverse" price (ex "5" "coin") positive "sell"] [probe "free" (inp "free_margin")]
    let moves := [book 0 "100" "102", signal 0 1, book 1 "100" "102", offer 0 300, signal 500 0]
    let tight ← run p {stop := 2001, cash := "500.225", fee := "0.00045"} moves
    require "exact requirement boundary admits" ((placed "reverse" tight).length == 1)
    require "actual reserved requirement leaves zero free margin" (tick 2000 tight == ["0"])
    let under ← run p {stop := 1001, cash := "500.224", fee := "0.00045"} moves
    require "one thousandth below actual requirement refuses" ((named "reverse" (kind "refused" (rows under))).any
      (fun row => field row 5 == "margin"))
  test "step5_11_free_margin_uses_one_adverse_mark" do
    let r ← run (program [slot "entry" price (ex "1" "coin") (phase 1)]
      [probe "free" (inp "free_margin") ] 2) {stop := 2001}
      [book 0 "100" "102", signal 0 1, book 1 "100" "102", offer 0 100 100,
       signal 500 0, print 1500 "98"]
    require "cash c=9900; adverse equity and margin at 98 give c+49"
      (tick 2000 r == ["9949"])
  test "step5_11_stale_account_values_defined" do
    let r ← run (program [slot "entry" price (ex "1" "coin") (phase 1)]
      [probe "bid" (inp "bid"), probe "equity" (inp "equity"), probe "free" (inp "free_margin")])
      {stop := 3001, stale := 1000, delta := 1000}
      [book 0 "100" "102" 1000, signal 0 1, book 1 "100" "102" 1000,
       offer 0 100 100, signal 500 0]
    require "stale prices undefined but last-price account remains defined"
      (tick 3000 r == ["-", "10001", "9900"])

#eval show IO Unit from do
  test1
  test2
  test3
  test4
  test5
  test6
  test7
  test8
  test9
  test10
  test11

end Step5Orders
