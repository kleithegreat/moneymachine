import Ref.Num
import Ref.Syntax

/-!
The causal machine (reference/SEMANTICS.md §3–§6): delivery of observations, and one tick of every
node for every coin, with the engine's window algorithms reproduced operation for operation.
-/

namespace Ref

def HOUR : Int := 3600000
def BAR : Int := 4 * HOUR

structure FundingRow (α : Type) where
  coin : Nat
  event : Int
  known : Int
  rate : α
  premium : α
  deriving Inhabited

structure BarRow (α : Type) where
  coin : Nat
  openTime : Int
  event : Int
  known : Int
  o : α
  h : α
  l : α
  c : α
  v : α
  trades : Int
  deriving Inhabited

structure EventRow (α : Type) where
  slot : Nat
  coin : Nat
  event : Int
  known : Int
  count : α
  deriving Inhabited

inductive Win (α : Type) where
  | lag (k : Nat) (buf : List (Val α))
  | sums (kind : Window) (n : Nat) (buf : List (Val α)) (sum sumsq : α) (nones sinceExact : Nat)
  | extreme (isMax : Bool) (n seq : Nat) (lastNone : Option Nat) (dq : List (Nat × α))
  | ema (n : Nat) (alpha s : α) (seen : Nat)
  deriving Inhabited

variable {α : Type} (N : NumOps α)

def Win.new : Window → Nat → Win α
  | .lag, n => .lag n []
  | .minOver, n => .extreme false n 0 none []
  | .maxOver, n => .extreme true n 0 none []
  | .ema, n => .ema n (N.div (N.ofNat 2) (N.add (N.ofNat n) N.one)) N.zero 0
  | w, n => .sums w n [] N.zero N.zero 0 0

/-- Σ as the left fold from −0.0 (SEMANTICS.md §1). -/
def total (xs : List α) : α := xs.foldl N.add (N.neg N.zero)

/-- One push: the window's new state and its output (SEMANTICS.md §6). -/
def Win.push : Win α → Val α → Win α × Val α
  | .lag k buf, x =>
    let b := buf ++ [x]
    let b := if b.length > k + 1 then b.drop 1 else b
    (.lag k b, if b.length == k + 1 then b.head! else none)
  | .sums kind n buf sum sumsq nones since, x =>
    let (sum, sumsq, nones) := match x with
      | some v => (N.add sum v, N.add sumsq (N.mul v v), nones)
      | none => (sum, sumsq, nones + 1)
    let b := buf ++ [x]
    let (b, sum, sumsq, nones) := if b.length > n then
        match b.head! with
        | some v => (b.drop 1, N.sub sum v, N.sub sumsq (N.mul v v), nones)
        | none => (b.drop 1, sum, sumsq, nones - 1)
      else (b, sum, sumsq, nones)
    let since := since + 1
    let defined := b.filterMap id
    let (since, sum, sumsq) := if since ≥ n then (0, total N defined, total N (defined.map fun v => N.mul v v))
      else (since, sum, sumsq)
    let out := if b.length < n || nones > 0 then none else
      let m := N.div sum (N.ofNat n)
      match kind with
      | .sum => some sum
      | .mean => some m
      | _ => some (N.sqrt (N.max (N.sub (N.div sumsq (N.ofNat n)) (N.mul m m)) N.zero))
    (.sums kind n b sum sumsq nones since, out)
  | .extreme isMax n seq lastNone dq, x =>
    let seq := seq + 1
    let (lastNone, dq) := match x with
      | none => (some seq, dq)
      | some v =>
        let dominated := fun (e : Nat × α) => if isMax then N.le e.2 v else N.le v e.2
        (lastNone, (dq.reverse.dropWhile dominated).reverse ++ [(seq, v)])
    let start : Int := (seq : Int) - n + 1
    let dq := dq.dropWhile fun (e : Nat × α) => (e.1 : Int) < start
    let out := if start < 1 || (match lastNone with | some s => (s : Int) ≥ start | none => false) then none
      else dq.head?.map (·.2)
    (.extreme isMax n seq lastNone dq, out)
  | .ema n alpha s seen, x =>
    match x with
    | none => (.ema n alpha s seen, none)
    | some v =>
      let s := if seen == 0 then v else N.add (N.mul alpha v) (N.mul (N.sub N.one alpha) s)
      let seen := seen + 1
      (.ema n alpha s seen, if seen ≥ n then some s else none)

structure MState (α : Type) where
  vals : Array (Array (Val α))
  wins : Array (Array (Option (Win α)))
  since : Array (Array (Option Int))
  funding : Array (Option (FundingRow α))
  bar : Array (Option (BarRow α))
  events : Array (Array (Option (EventRow α)))
  hour : Int
  maxKnown : Int
  deriving Inhabited

def MState.init (p : Program) (coins : Nat) : MState α :=
  { vals := Array.replicate p.nodes.size (Array.replicate coins none)
    wins := p.nodes.map fun n => match n with
      | .op (.window w h) _ => Array.replicate coins (some (Win.new N w h))
      | _ => Array.replicate coins none
    since := Array.replicate p.nodes.size (Array.replicate coins none)
    funding := Array.replicate coins none
    bar := Array.replicate coins none
    events := Array.replicate eventInputs.length (Array.replicate coins none)
    hour := 0
    maxKnown := -(2 ^ 63) }

/-- An observation known after the tick: the engine's R_CAUSALITY. -/
structure Causality where
  known : Int
  tick : Int

def MState.deliverFunding (m : MState α) (f : FundingRow α) (tick : Int) : Except Causality (MState α) :=
  if f.known > tick then .error ⟨f.known, tick⟩
  else .ok { m with maxKnown := max m.maxKnown f.known, funding := m.funding.set! f.coin (some f) }

def MState.deliverBar (m : MState α) (b : BarRow α) (tick : Int) : Except Causality (MState α) :=
  if b.known > tick then .error ⟨b.known, tick⟩
  else .ok { m with maxKnown := max m.maxKnown b.known, bar := m.bar.set! b.coin (some b) }

def MState.deliverEvent (m : MState α) (e : EventRow α) (tick : Int) : Except Causality (MState α) :=
  if e.known > tick then .error ⟨e.known, tick⟩
  else .ok { m with maxKnown := max m.maxKnown e.known,
                    events := m.events.modify e.slot fun row => row.set! e.coin (some e) }

def MState.input (m : MState α) (i : Input) (c : Nat) : Val α :=
  match i with
  | .funding => m.funding[c]!.map (·.rate)
  | .premium => m.funding[c]!.map (·.premium)
  | .open => m.bar[c]!.map (·.o)
  | .high => m.bar[c]!.map (·.h)
  | .low => m.bar[c]!.map (·.l)
  | .close => m.bar[c]!.map (·.c)
  | .volume => m.bar[c]!.map (·.v)
  | .event s => match m.events[s]![c]! with
    | some e => if e.event == m.hour then some e.count else none
    | none => none

/-- The pointwise value of node i for coin c at this tick, from its arguments' values (§5). -/
def MState.eval (p : Program) (m : MState α) (i : Nat) (c : Nat) : Val α :=
  let arg (k : Nat) : Val α := match p.nodes[i]! with
    | .op _ args => m.vals[args[k]!]![c]!
    | _ => none
  let b (x : Bool) : Val α := some (N.truth x)
  match p.nodes[i]! with
  | .input inp => m.input inp c
  | .const bits _ => some (N.ofBits bits)
  | .param k => some (N.ofBits p.params[k]!.1)
  | .op o _ => match o with
    | .add => do return N.add (← arg 0) (← arg 1)
    | .sub => do return N.sub (← arg 0) (← arg 1)
    | .mul => do return N.mul (← arg 0) (← arg 1)
    | .div => do let d ← arg 1; if N.isZero d then none else return N.div (← arg 0) d
    | .min => do return N.min (← arg 0) (← arg 1)
    | .max => do return N.max (← arg 0) (← arg 1)
    | .neg => do return N.neg (← arg 0)
    | .abs => do return N.abs (← arg 0)
    | .sign => do return N.sign (← arg 0)
    | .log => do let x ← arg 0; if N.lt N.zero x then return N.log x else none
    | .exp => do return N.exp (← arg 0)
    | .sqrt => do let x ← arg 0; if N.le N.zero x then return N.sqrt x else none
    | .clip => do return N.clip (← arg 0) (← arg 1) (← arg 2)
    | .gt => do let x ← arg 0; let y ← arg 1; b (N.lt y x)
    | .ge => do let x ← arg 0; let y ← arg 1; b (N.le y x)
    | .lt => do let x ← arg 0; let y ← arg 1; b (N.lt x y)
    | .le => do let x ← arg 0; let y ← arg 1; b (N.le x y)
    | .and => do let x ← arg 0; let y ← arg 1; b (!N.isZero x && !N.isZero y)
    | .or => do let x ← arg 0; let y ← arg 1; b (!N.isZero x || !N.isZero y)
    | .not => do let x ← arg 0; b (N.isZero x)
    | .ite => do let x ← arg 0; if !N.isZero x then arg 1 else arg 2
    | .convert f => do return N.mul (← arg 0) (N.ofBits f)
    | .window .. => arg 0
    | _ => none

def rank (xs : List α) (v : α) : α :=
  if xs.length == 1 then N.div N.one (N.ofNat 2) else
  let below := (xs.filter fun x => N.lt x v).length
  let equal := (xs.filter fun x => N.eq x v).length
  N.div (N.add (N.ofNat below) (N.div (N.sub (N.ofNat equal) N.one) (N.ofNat 2))) (N.sub (N.ofNat xs.length) N.one)

/-- One tick at hour `hour` with listing mask `listed` (SEMANTICS.md §4). -/
def MState.tick (p : Program) (m : MState α) (listed : Array Bool) (hour : Int) : MState α := Id.run do
  let mut m := { m with hour := hour }
  let coins := listed.size
  for i in [0:p.nodes.size] do
    match p.nodes[i]! with
    | .op .hoursSince args =>
      for c in [0:coins] do
        let cond := m.vals[args[0]!]![c]!
        if listed[c]! && (match cond with | some v => !N.isZero v | none => false) then
          m := { m with since := m.since.modify i fun row => row.set! c (some hour) }
        let v := if listed[c]! then m.since[i]![c]!.bind fun t => N.keep (N.ofInt ((hour - t) / HOUR)) else none
        m := { m with vals := m.vals.modify i fun row => row.set! c v }
    | .op o@(.xsMean) args | .op o@(.xsDemean) args | .op o@(.xsRank) args =>
      let xs := (List.range coins).filterMap fun c => if listed[c]! then (m.vals[args[0]!]![c]!).map (c, ·) else none
      let values := xs.map (·.2)
      let mean := N.div (total N values) (N.ofNat xs.length)
      let out := (List.range coins).map fun c => match xs.find? (·.1 == c) with
        | none => none
        | some (_, v) => match o with
          | .xsMean => N.keep mean
          | .xsDemean => N.keep (N.sub v mean)
          | _ => N.keep (rank N values v)
      m := { m with vals := m.vals.set! i (if xs.isEmpty then Array.replicate coins none else out.toArray) }
    | _ =>
      for c in [0:coins] do
        let v := if listed[c]! then m.eval N p i c else none
        let (v, w) := match m.wins[i]![c]! with
          | some w => if listed[c]! then let (w', out) := w.push N v; (out, some w') else (v, some w)
          | none => (v, none)
        m := { m with vals := m.vals.modify i (fun row => row.set! c (v.bind N.keep)),
                      wins := m.wins.modify i (fun row => row.set! c w) }
  return m

end Ref
