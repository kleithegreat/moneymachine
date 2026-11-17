import Engine.Lang.Num
import Engine.Lang.Syntax

/-!
# The float evaluator (reference/SEMANTICS.md §1, §4 to §6; KERNEL.md A17)

One tick evaluates every node, in index order, for every coin. A node's value is a number, or `none` when it is
undefined; booleans are `N.truth`. Exact nodes are the view's, not the evaluator's: the evaluator leaves them
undefined, and no float or bool node reads one. Windows count ticks.
-/

namespace Engine.Lang

variable {α : Type}

/-- A tick as the evaluator takes it: the coins in view, the declared sources' values by coin, the time. -/
structure Tick (α : Type) where
  inView : Nat → Bool
  input : Nat → String → Option α
  time : Int

inductive Win (α : Type) where
  | lag (k : Nat) (buf : List (Option α))
  | sums (kind : Window) (n : Nat) (buf : List (Option α)) (sum sumsq : α) (nones sinceExact : Nat)
  | extreme (isMax : Bool) (n seq : Nat) (lastNone : Option Nat) (dq : List (Nat × α))
  | ema (n : Nat) (alpha s : α) (seen : Nat)
  deriving DecidableEq, Repr

/-- What a node remembers for a coin. -/
inductive NS (α : Type) where
  | stateless
  | win (w : Win α)
  | since (last : Option Nat)
  deriving DecidableEq, Repr

instance : Inhabited (NS α) := ⟨.stateless⟩

variable (N : NumOps α)

def Win.new : Window → Nat → Win α
  | .lag, n => .lag n []
  | .minOver, n => .extreme false n 0 none []
  | .maxOver, n => .extreme true n 0 none []
  | .ema, n => .ema n (N.div (N.ofNat 2) (N.add (N.ofNat n) N.one)) N.zero 0
  | w, n => .sums w n [] N.zero N.zero 0 0

/-- Σ as the left fold from −0.0 (SEMANTICS.md §1). -/
def total (xs : List α) : α := xs.foldl N.add (N.neg N.zero)

/-- One push: the window's new state and its output (SEMANTICS.md §6). -/
def Win.push : Win α → Option α → Win α × Option α
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

/-- The pointwise value of an operator from its arguments' values (§5). -/
def evalOp (o : Op) (arg : Nat → Option α) : Option α :=
  let b (x : Bool) : Option α := some (N.truth x)
  match o with
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
  | .convert f _ => do return N.mul (← arg 0) (N.ofBits f)
  | .window .. => arg 0
  | _ => none

/-- The pointwise value of a node at a coin. -/
def evalNode (t : Tick α) (c : Nat) (n : Node) (arg : Nat → Option α) : Option α :=
  match n with
  | .builtin _ | .slotIn .. | .exactConst .. => none
  | .source name _ => t.input c name
  | .const bits _ => some (N.ofBits bits)
  | .op o _ => evalOp N o arg

def rank (xs : List α) (v : α) : α :=
  if xs.length == 1 then N.div N.one (N.ofNat 2) else
  let below := (xs.filter fun x => N.lt x v).length
  let equal := (xs.filter fun x => N.eq x v).length
  N.div (N.add (N.ofNat below) (N.div (N.sub (N.ofNat equal) N.one) (N.ofNat 2))) (N.sub (N.ofNat xs.length) N.one)

/-- The row of a node's `k`th argument, in the rows of the nodes before it. -/
def argRow (vs : Array (Array (Option α))) (args : List Nat) (k : Nat) : Array (Option α) :=
  match args[k]? with
  | some a => vs[a]!
  | none => #[]

/-- The pointwise value of a node at a coin, from its arguments' rows. -/
def pointVal (t : Tick α) (n : Node) (argRows : Nat → Array (Option α)) (c : Nat) : Option α :=
  if t.inView c then evalNode N t c n (fun k => (argRows k)[c]!) else none

/-- One node's raw row of a tick, before the finiteness filter, and its memory, from its arguments' rows. -/
def nodeCore (t : Tick α) (n : Node) (count coins : Nat) (argRows : Nat → Array (Option α)) (ns : Array (NS α)) :
    Array (Option α) × Array (NS α) :=
  let coinList := List.range coins
  match n with
  | .op .ticksSince _ =>
    let cells := coinList.map fun c =>
      let cond := (argRows 0)[c]!
      let last := match ns[c]! with | .since l => l | _ => none
      let fire := t.inView c && (match cond with | some v => !N.isZero v | none => false)
      let last' := if fire then some count else last
      let v := if t.inView c then last'.bind fun l => some (N.ofInt ((count : Int) - l)) else none
      (v, NS.since last')
    ((cells.map (·.1)).toArray, (cells.map (·.2)).toArray)
  | .op o@(.xsMean) _ | .op o@(.xsDemean) _ | .op o@(.xsRank) _ =>
    let xs := coinList.filterMap fun c => if t.inView c then ((argRows 0)[c]!).map (c, ·) else none
    let values := xs.map (·.2)
    let mean := N.div (total N values) (N.ofNat xs.length)
    let out := coinList.map fun c => match xs.find? (·.1 == c) with
      | none => none
      | some (_, v) => match o with
        | .xsMean => some mean
        | .xsDemean => some (N.sub v mean)
        | _ => some (rank N values v)
    ((if xs.isEmpty then coinList.map fun _ => none else out).toArray, ns)
  | .op (.window _ _) _ =>
    let cells := coinList.map fun c =>
      let v := pointVal N t n argRows c
      match ns[c]! with
      | .win w => if t.inView c then (let r := Win.push N w v; (r.2, NS.win r.1)) else (none, NS.win w)
      | s => (v, s)
    ((cells.map (·.1)).toArray, (cells.map (·.2)).toArray)
  | _ => ((coinList.map fun c => pointVal N t n argRows c).toArray, ns)

/-- Every stored value passes the finiteness filter, and no coin out of view has one (SEMANTICS.md §1, §4). -/
def finalize (t : Tick α) (coins : Nat) (raw : Array (Option α)) : Array (Option α) :=
  ((List.range coins).map fun c => if t.inView c then (raw[c]!).bind N.keep else none).toArray

/-- One node's row of a tick: its stored values and its memory. -/
def nodeFull (t : Tick α) (n : Node) (count coins : Nat) (argRows : Nat → Array (Option α)) (ns : Array (NS α)) :
    Array (Option α) × Array (NS α) :=
  let r := nodeCore N t n count coins argRows ns
  (finalize N t coins r.1, r.2)

def Node.args : Node → List Nat
  | .op _ args => args
  | _ => []

/-- One node's row of a tick; `vs` holds the rows of the nodes before it. -/
def nodeStep (t : Tick α) (n : Node) (count coins : Nat) (vs : Array (Array (Option α))) (ns : Array (NS α)) :
    Array (Option α) × Array (NS α) :=
  nodeFull N t n count coins (argRow vs n.args) ns

/-- The evaluator's state: the ticks run, the coins, every node's value at the last tick and every node's memory. -/
structure Mach (α : Type) where
  count : Nat
  coins : Nat
  vals : Array (Array (Option α))
  ns : Array (Array (NS α))
  deriving DecidableEq, Repr

def Mach.init (p : Program) (coins : Nat) : Mach α :=
  { count := 0, coins := coins,
    vals := p.nodes.map fun _ => Array.replicate coins none,
    ns := p.nodes.map fun n => Array.replicate coins
      (match n with
       | .op (.window w k) _ => NS.win (Win.new N w k)
       | .op .ticksSince _ => NS.since none
       | _ => NS.stateless) }

/-- The first `k` nodes' rows of a tick. -/
def build (p : Program) (t : Tick α) (m : Mach α) : Nat → Array (Array (Option α)) × Array (Array (NS α))
  | 0 => (#[], #[])
  | k + 1 =>
    let (vs, ss) := build p t m k
    let (row, s) := nodeStep N t p.nodes[k]! m.count m.coins vs m.ns[k]!
    (vs.push row, ss.push s)

def Mach.step (p : Program) (t : Tick α) (m : Mach α) : Mach α :=
  let (vs, ss) := build N p t m p.nodes.size
  { m with count := m.count + 1, vals := vs, ns := ss }

def Mach.run (p : Program) (coins : Nat) (ts : List (Tick α)) : Mach α :=
  ts.foldl (fun m t => Mach.step N p t m) (Mach.init N p coins)

end Engine.Lang
