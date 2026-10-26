# Stage 7, slice 1: the reference semantics generalized over declarations, and the laws restated (draft, revision 6)

C7.7 requires the Lean semantics to be parameterized by validated declarations and bindings; every stage 6 law to keep
its guarantee for every admitted declaration, held and event cadences included; each law whose definitions change to
be revised, independently reviewed and frozen before its proof; and a binding law under which evaluation is undefined
whenever a required source lacks a valid, matching, in-scope certificate. `Ref/Spec.lean` and `Ref/Laws.lean` stay
frozen as version 1 until this draft is resolved.

Reviews: four fresh-context Opus reviews while GPT was unavailable (`laws-review-opus-1.md` to `-4.md`; the fourth
accepted revision 4) and GPT's (`laws-review-gpt-1.md`, rejecting revision 5 with B1–B7 and N1–N3). Every finding of
the last three, its answer and whether it could change a false-discovery or leakage outcome are in §10 (CLAUDE.md,
rule 3). This draft is not frozen: §2–§6 are next written as compiling Lean with complete law signatures, and that
Lean is reviewed by GPT before any freeze or proof (N3).

## 1. The design, from what the semantics reads

- **Everything a decision reads is delivered.** Inputs, the decision's freshness and its price are reads of delivered
  observations; a role provider's observations carry their role columns and are delivered like any source's.
- **Execution reads venue state at its event time.** Fills, marks, extremes and settlement read the role providers'
  bars and rates by open or event time, as version 1 does: they are the account's state at the venue, which the venue
  applies at that time whatever our record's knownAt. A source is admitted to a role only if its verifier certifies
  that contract: each record's event time is when the venue applied it and its value is the one applied (CERTIFICATES
  §5). Decisions see execution only through the account (fills and equity) and through delivered observations.
- **Version 1's reads, per source.** Per source and coin the machine holds the latest delivered observation. A held
  input reads it; an event input reads it only if its slot is the current hour (version 1's single event row, which a
  later-delivered older correction replaces).
- **Version 1's order.** Within a source, observations are delivered in (knownAt, coin, resolver position) order:
  version 1's (knownAt, coin, feed, array index) with the feed fixed. Across sources the interleaving is unobservable
  (stores are per source, `maxKnown` is a maximum, causality is per observation), so C7.4 compares one stream per
  source (§9).
- **Staged admission, enforced by types.** Metadata checks take only metadata; I8's check takes only the time column
  of every stored row; the resolver runs after both; scope is checked against everything the run reads, transitive
  resolver reads included. The model's link from certified bytes to observations is an explicit trusted boundary
  (§3), discharged by tests, not assumed silently.

## 2. Registry, roles and inputs

```lean
inductive Cadence where | held | event | evidence deriving DecidableEq, Repr
inductive Role where | bars | settlement deriving DecidableEq, Repr

/-- One active declaration (SOURCES.md §1, version 2): its file's hash (covering its rule bytes); its fields (input
name, stored column, unit; in input-name order); every stored column its availability rule reads, `fetchedAt`
included; the stored column of its event time (for I8, evidence declarations included); its slot column (event
sources); its cadence; its dependencies (registry indices); and, per role it can provide, each role column's stored
column. -/
structure Decl where
  hash : Hash
  fields : Array (String × String × Dim)
  times : List String
  eventColumn : String
  slotColumn : Option String
  cadence : Cadence
  depends : List Nat
  roles : List (Role × List (String × String))

/-- Every stored column the run reads from one of this declaration's observations: fields, availability inputs, the
event and slot columns, and role columns. -/
def Decl.columns (d : Decl) : List String :=
  d.fields.toList.map (·.2.1) ++ d.times ++ [d.eventColumn] ++ d.slotColumn.toList ++ d.roles.flatMap (·.2.map (·.2))

/-- The columns the resolver reads from an upstream record when bounding a derived observation's knownAt. -/
def Decl.lineageColumns (d : Decl) : List String := d.times ++ [d.eventColumn]

structure Registry where
  decls : Array Decl

def Registry.closure (reg : Registry) : Nat → List Nat → List Nat
  | 0, xs => xs.eraseDups
  | fuel + 1, xs => (xs ++ reg.closure fuel (xs.flatMap fun s => (reg.decls[s]!).depends)).eraseDups

def Registry.Valid (reg : Registry) : Prop :=
  (reg.decls.toList.flatMap (fun d => d.fields.toList.map (·.1))).Nodup ∧
  (∀ d ∈ reg.decls.toList, ∀ s ∈ d.depends, s < reg.decls.size) ∧
  (∀ s < reg.decls.size, s ∉ reg.closure reg.decls.size ((reg.decls[s]!).depends)) ∧
  (∀ d ∈ reg.decls.toList, (d.fields.toList.map (·.1)).Sorted (· < ·)) ∧
  (∀ d ∈ reg.decls.toList, d.cadence = .evidence → d.fields.size = 0 ∧ d.roles = []) ∧
  (∀ d ∈ reg.decls.toList, (d.cadence = .event) = d.slotColumn.isSome) ∧
  (∀ d ∈ reg.decls.toList, ∀ r ∈ d.roles, r.1 = .bars → (r.2.map (·.1)) = ["open", "high", "low", "close", "trades"]) ∧
  (∀ d ∈ reg.decls.toList, ∀ r ∈ d.roles, r.1 = .settlement → (r.2.map (·.1)) = ["rate"])

structure Input where
  source : Nat
  field : Nat
  deriving DecidableEq, Repr

structure Roles where
  bars : Nat
  settlement : Nat

def Roles.valid (reg : Registry) (r : Roles) : Bool :=
  r.bars != r.settlement && r.bars < reg.decls.size && r.settlement < reg.decls.size &&
  (reg.decls[r.bars]!).roles.any (·.1 == .bars) && (reg.decls[r.settlement]!).roles.any (·.1 == .settlement)
```

`check : Registry → String → Except Code Program` resolves an input name to its unique `⟨source, field⟩`; an
undeclared name is `E_UNKNOWN_INPUT`. `Program.WF reg p`: for `.input inp`, `inp.source < reg.decls.size`, `inp.field <`
its field count, and `p.types[i]! = .num` the field's unit. `CheckerAccepted reg p := reg.Valid ∧ ∃ text, check reg
text = .ok p`. `Program.sources p := (p.nodes.toList.filterMap fun n => match n with | .input i => some i.source | _ =>
none).eraseDups`.

**Input references in the text.** `InputRef (v : Json) (name : String)` holds when `{"input": name}` occurs in `v`'s
`weight`, in the body of any `let` (used or not), or in `prediction.condition`, at any depth of the expression grammar
(DSL.md), and nowhere else.

## 3. Observations, metadata and the staged loader

```lean
inductive RolePayload (α : Type) where
  | bar (o h l c : α) (trades : Int)      -- open time is key − BAR
  | rate (r : α)

/-- One resolved observation (RULES.md §6): declaration, coin, key (event time), slot (an event source's event hour),
effective knownAt, one value per field (`none` for null), role payload for a provider's records, and lineage: the
upstream records (source, coin, key) the resolver read to bound its knownAt. -/
structure Obs (α : Type) where
  source : Nat
  coin : Nat
  key : Int
  slot : Option Int
  known : Int
  vals : Array (Option α)
  role : Option (RolePayload α)
  lineage : List (Nat × Nat × Int)

structure Grant where
  coin : Nat
  column : String
  event : Int × Int
  use : Int × Int

structure Access where
  coin : Nat
  column : String
  event : Int
  use : Int × Int

def Grant.covers (g : Grant) (x : Access) : Bool :=
  g.coin == x.coin && g.column == x.column && g.event.1 ≤ x.event && x.event < g.event.2 &&
  g.use.1 ≤ x.use.1 && x.use.2 ≤ g.use.2

/-- A certificate's payload as the verifier wrote it; its id is the hash of this payload. -/
structure Cert where
  id : Hash
  decl : Hash
  manifest : Hash
  policy : Hash
  verifier : Hash
  upstream : List Hash
  grants : List Grant

structure Binding where
  dataset : Hash          -- the bound dataset's content identity
  cert : Hash

inductive Mode where | search | holdout deriving DecidableEq

/-- Everything admission knows before any stored row is read. `policy` and `verifier` are compiled into the kernel
build the run identity pins. -/
structure Meta where
  bindings : Nat → Option Binding
  certs : List Cert
  supersessions : List (Hash × Nat)
  position : Nat
  policy : Hash
  verifier : Hash
  holdout : List Hash
  holdoutStart : Int
  intervals : Array (Int × Int)

/-- The loader, in two stages. `rows` reads only the event-time column of every stored row of the given datasets
(every revision, tombstone and coin); `resolve` runs RULES.md §6 on the given datasets. -/
structure Loader (α : Type) where
  rows : List Nat → List (Nat × Int)
  resolve : List Nat → Array (Obs α)
```

**The trusted boundary.** `Loader.Faithful reg meta ld` states that, for the bound datasets, `ld.rows` lists every
stored row's (source, event time), and `ld.resolve` is the resolver's output on bytes whose content identity is the
binding's `dataset`, lineage included. The model cannot prove it about bytes; `mm` discharges it by hashing the bytes
it reads against `dataset` (attack 6), by C7.6's three-implementation resolver suite, and by the staging tests of §8
(rows 17 and 18). Laws about data hold under it; L5's ordering and refusal clauses hold without it.

## 4. Preflight, staged by type

```lean
def Meta.cert (m : Meta) (h : Hash) : Option Cert := m.certs.find? (·.id == h)

def Meta.valid (m : Meta) : Nat → Hash → Bool
  | 0, _ => false
  | fuel + 1, h => match m.cert h with
    | none => false
    | some k => !(m.supersessions.any fun (x, pos) => x == h && pos ≤ m.position) && k.upstream.all (m.valid fuel ·)

def Meta.matches (reg : Registry) (m : Meta) (s : Nat) (b : Binding) (k : Cert) : Bool :=
  k.decl == (reg.decls[s]!).hash && k.manifest == b.dataset && k.policy == m.policy && k.verifier == m.verifier &&
  k.upstream.toFinset == ((reg.decls[s]!).depends.filterMap fun d => (m.bindings d).map (·.cert)).toFinset

/-- Every bound non-evidence source is delivered (version 1 delivers every dataset in the store). -/
def Meta.delivered (reg : Registry) (m : Meta) : List Nat :=
  (List.range reg.decls.size).filter fun s => (m.bindings s).isSome && (reg.decls[s]!).cadence != .evidence

def Meta.required (reg : Registry) (roles : Roles) (p : Program) (m : Meta) : List Nat :=
  reg.closure reg.decls.size (m.delivered reg ++ p.sources ++ [roles.bars, roles.settlement])

/-- Stage 1: metadata only. Returns the required set. -/
def stage1 (reg : Registry) (roles : Roles) (p : Program) (m : Meta) (mode : Mode) : Except Abort (List Nat) := do
  if !roles.valid reg then throw .roles
  let req := m.required reg roles p
  if !req.all (m.bindings · |>.isSome) then throw .inputUnavailable
  if mode == .search && !req.all (fun s => (m.bindings s).all (·.dataset ∉ m.holdout)) then throw .holdout
  if !req.all (fun s => match m.bindings s with
      | none => false
      | some b => (m.cert b.cert).any fun k => m.valid m.certs.length b.cert && m.matches reg s b k) then throw .uncertified
  return req

/-- Stage 2: event-time columns only (I8). -/
def stage2 (m : Meta) (mode : Mode) (rows : List (Nat × Int)) : Except Abort Unit :=
  if mode == .search && !rows.all (·.2 < m.holdoutStart) then throw .holdout else pure ()

/-- The whole run: stage 1, then `ld.rows`, stage 2, then `ld.resolve`, then the checks on resolved observations,
then evaluation. -/
def run (N : NumOps α) (reg : Registry) (roles : Roles) (p : Program) (m : Meta) (ld : Loader α) (v : Venue α)
    (pol : Policy) (stop : Int) (mode : Mode) : Except Abort (Run α) := do
  let req ← stage1 reg roles p m mode
  stage2 m mode (ld.rows req)
  let c := Ctx.make reg roles p m (ld.resolve req) v pol stop req
  if !c.admissible N then throw .binding
  if !c.inScope then throw .uncertified
  c.evaluate N

/-- The first failing check and its position, for L5.2 (N1): 1 roles, 2 unbound, 3 holdout identity,
4 uncertified (validity and matching), 5 holdout rows, 6 binding shape, 7 scope. -/
def firstFailure (N) (reg roles p m ld v pol stop mode) : Option (Nat × Abort) := ...  -- the same sequence, returning positions
```

`stage1` and `stage2` take no loader and no observations: that they read no payload is their type (B1). `mm` follows
the same stages, tested by rows 17 and 18 of §8.

## 5. The context, admissibility and accesses

```lean
def Ctx.make (reg roles p) (m : Meta) (obs : Array (Obs α)) (v pol stop) (req : List Nat) : Ctx α :=
  let obs := obs.filter (·.source ∈ m.delivered reg)
  { reg, roles, p, m, v, pol, stop, required := req, obs
    oOrder := (Array.range obs.size).mergeSort fun i j =>          -- (knownAt, source, coin, resolver position)
      let x := obs[i]!; let y := obs[j]!
      lexLe [x.known, x.source, x.coin, i] [y.known, y.source, y.coin, j]
    intervals := m.intervals
    ix := Index.of (obs.filterMap (barRow roles)) (obs.filterMap (rateRow roles)) m.intervals.size }

def Ctx.firstTick (c : Ctx α) : Int := c.pol.wStart + c.pol.delta
def Ctx.lastTick (c : Ctx α) : Int := c.pol.wStart + (c.bounds.length : Int) * BAR + c.pol.delta
/-- The end of every use interval: `stop`, or past the first tick, which `start` always runs (B6). -/
def Ctx.useEnd (c : Ctx α) : Int := max c.stop (c.firstTick + 1)
```

`Ctx.admissible N` (run admission, `R_BINDING`): observation (source, coin, key) unique; every coin `< intervals.size`
(rows of coins outside U are excluded by the resolver, as version 1 does, and are still in `rows` for I8); `vals.size`
the field count; every value and role payload finite or null by `N.finite`; `role` present exactly for the two
providers' records, `.bar` for the bars provider with every role column non-null and `key − BAR` on the 4h grid,
`.rate` for the settlement provider; an event source's `slot` some and on the hour grid, others' none; every lineage
entry's source among the observation's declaration's transitive dependencies.

**Accesses: every column read, with its use interval.** An observation is read from its delivery (`known`, or the
first tick for one carried in) if it can be delivered by the last tick; a role record is read by execution from its
open (bars) or event time (rates) if that precedes `useEnd`. Lineage records are read whenever their derived
observation is.

```lean
def Ctx.deliverable (c : Ctx α) (o : Obs α) : Bool := o.known ≤ c.lastTick

def Ctx.readFrom (c : Ctx α) (o : Obs α) : Option Int :=
  let delivered := if c.deliverable o then some (max o.known c.firstTick) else none
  let executed := match o.role with
    | some (.bar ..) => some (o.key - BAR)
    | some (.rate _) => some o.key
    | none => none
  match delivered, executed.filter (· < c.useEnd) with
  | some a, some b => some (max (min a b) c.firstTick)
  | some a, none | none, some a => some (max a c.firstTick)
  | none, none => none

def Ctx.accesses (c : Ctx α) : List (Nat × Access) :=
  c.obs.toList.flatMap fun o => match c.readFrom o with
    | none => []
    | some t =>
      ((c.reg.decls[o.source]!).columns.map fun col => (o.source, ⟨o.coin, col, o.key, (t, c.useEnd)⟩)) ++
      o.lineage.flatMap fun (u, coin, key) =>
        (c.reg.decls[u]!).lineageColumns.map fun col => (u, ⟨coin, col, key, (t, c.useEnd)⟩)

def Ctx.inScope (c : Ctx α) : Bool :=
  c.accesses.all fun (s, x) => match c.m.bindings s with
    | none => false
    | some b => (c.m.cert b.cert).any fun k => k.grants.any (·.covers x)
```

A held value is counted as used through `useEnd` even after replacement: its effect persists in window state.
Every `t ≥ firstTick` and `t < useEnd`, so no use interval is empty and the initialization tick is covered (B6).

## 6. The machine and execution

```lean
structure MState (α : Type) where
  vals : Array (Array (Val α))
  wins : Array (Array (Option (Win α)))
  since : Array (Array (Option Int))
  latest : Array (Array (Option (Obs α)))       -- per source and coin, the latest delivered observation
  hour : Int
  maxKnown : Int

def MState.init (reg : Registry) (p : Program) (coins : Nat) : MState α :=
  { vals := Array.replicate p.nodes.size (Array.replicate coins none)
    wins := p.nodes.map fun n => match n with
      | .op (.window w h) _ => Array.replicate coins (some (Win.new N w h)) | _ => Array.replicate coins none
    since := Array.replicate p.nodes.size (Array.replicate coins none)
    latest := Array.replicate reg.decls.size (Array.replicate coins none)
    hour := 0, maxKnown := -(2 ^ 63) }

def MState.deliver (m : MState α) (o : Obs α) (tick : Int) : Except Abort (MState α) :=
  if o.known > tick then .error .causality
  else .ok { m with latest := m.latest.modify o.source (·.set! o.coin (some o)), maxKnown := max m.maxKnown o.known }

/-- Version 1's reads: held reads the latest; event reads the latest only if its slot is the current hour. -/
def MState.input (reg : Registry) (m : MState α) (i : Input) (c : Nat) : Val α :=
  match (reg.decls[i.source]!).cadence, m.latest[i.source]![c]! with
  | .held, some o => o.vals[i.field]!
  | .event, some o => if o.slot == some m.hour then o.vals[i.field]! else none
  | _, _ => none

def Ctx.deliver (c : Ctx α) (s : SState α) (tick : Int) : Except Abort (SState α) := do
  let mut s := s
  while h : s.oi < c.oOrder.size do
    let o := c.obs[c.oOrder[s.oi]]!
    if o.known > tick then break
    s := { s with machine := ← s.machine.deliver o tick, oi := s.oi + 1 }
  return s
```

`SState`'s `fi`, `bi`, `ei` become one `oi`; `Ctx.start`, `Ctx.step` and `Ctx.evaluate` are version 1's with this
delivery and without the binding check, and are written out in the Lean (N3). In step 9:

```lean
let latest (src : Nat) : Option (Obs α) := s.machine.latest[src]![coin]!
let fresh := (latest c.roles.bars).any (·.key == bigB) && (latest c.roles.settlement).any (·.key == bigB)
let price := match (latest c.roles.bars).bind (·.role) with | some (.bar _ _ _ cl _) => cl | _ => N.zero
```

Execution reads the projections, by open and event time (§1):

```lean
def barRow (roles : Roles) (o : Obs α) : Option (BarRow α) := match o.role with
  | some (.bar op h l cl tr) => if o.source == roles.bars then some ⟨o.coin, o.key - BAR, o.key, o.known, op, h, l, cl, tr⟩ else none
  | _ => none
def rateRow (roles : Roles) (o : Obs α) : Option (RateRow α) := match o.role with
  | some (.rate r) => if o.source == roles.settlement then some ⟨o.coin, o.key, o.known, r⟩ else none
  | _ => none
def Ctx.bars (c : Ctx α) : List (BarRow α) := c.obs.toList.filterMap (barRow c.roles)
def Ctx.rates (c : Ctx α) : List (RateRow α) := c.obs.toList.filterMap (rateRow c.roles)
def barAt (c : Ctx α) (coin : Nat) (t : Int) : Option (BarRow α) := c.bars.find? fun b => b.coin == coin && b.openTime == t
def latestClosed (c : Ctx α) (coin : Nat) (t : Int) : Option (BarRow α) :=
  (c.bars.filter fun b => b.coin == coin && b.event ≤ t).foldl
    (fun acc b => match acc with | some x => if x.openTime < b.openTime then some b else acc | none => some b) none
def Ctx.deliveryPrefix (c : Ctx α) (t : Int) : List (Obs α) := (c.oOrder.toList.map (c.obs[·]!)).filter (·.known ≤ t)
def Ctx.execView (c : Ctx α) (t : Int) :=
  ((c.rates.filter (·.event ≤ t)).map (fun r => (r.coin, r.event, r.rate)),
   c.bars.filter (fun b => b.openTime + BAR ≤ t),
   (c.bars.filter (·.openTime ≤ t)).map (fun b => (b.coin, b.openTime, b.o, b.trades)),
   c.intervals)
```

`BarRow` loses `v` (no execution read uses volume; it stays a DSL field). The listing intervals come from the
venue-rules artifact the run identity pins (a known limitation until stage 8 records delisting with its own knownAt,
C8.1); version 1's derivation of a delisted coin's end from its last bar (`market.rs::load`) is reconciled in the
annex before C7.4's baseline.

## 7. Revised law statements

On `c := Ctx.make reg roles p m (ld.resolve req) v pol stop req`. Each law keeps version 1's domain and numerical
hypotheses (N3): L1, L2, L4 and L7 take `CheckerAccepted reg p`, `roles.valid reg`, `c.admissible N`, `pol.Valid` and
`Loader.Faithful`; L3 takes `p.WF reg` and `N.Lawful`, as version 1; L5's clauses 0 to 4 take nothing beyond their
objects; L6 takes only `N.Bounded`.

- **L1 non-interference.** `L1_values`: equal intervals and delivery prefixes at tick `wStart + n·HOUR + δ` give equal
  machines after every tick through it. `L1_simulator` as version 1. `L1_decisions`: equal delivery prefixes and
  execution views at decision `k`'s time give equal traces through step `k + 1`.
- **L2 unit soundness.** `L2_units` as version 1, its erasure clause `u.m.latest = ms.latest`; `L2_checker`:
  `CheckerAccepted reg p → p.WF reg`.
- **L3 rewrite soundness.** With `p.WF reg`, `N.Lawful`, `r.apply p i = some p'`: `p'.WF reg`; equal node values at
  corresponding nodes; equal traces at every step; `p'.sources` and `p.sources` equal as sets, so `required`,
  `accesses`, the checks and `run` are equal.
- **L4 fill ordering.** `L4_fills`, `L4_orders` as version 1 on `c.evaluate N = .ok r`, reading the projections; an
  ordinary fill's `inputsKnown` is the decision machine's `maxKnown`.
- **L5 binding and admission.**
  0. `run … = .ok r →` stage 1 and stage 2 return `ok`, `c.admissible N` and `c.inScope`;
  1. `stage1` and `stage2` are functions of metadata and, for stage 2, of `ld.rows req` alone: two loaders with equal
     `rows req` give equal results from them, and `ld.resolve` is not an argument of either;
  2. `run` returns `.error e` iff `firstFailure … = some (k, e)` for some position k, and `firstFailure … = some (k, e)`
     iff checks 1 to k − 1 pass and check k fails;
  3. if all pass, `run … = c.evaluate N`;
  4. the checks at positions 6 and 7 depend on observations' keys, slots, knownAt, coins, lineage and the nullness
     and finiteness of their values, never on the values themselves;
  5. *(the text)* if `check reg text = .ok p` and `InputRef (parse text) name` with `name` declared for `s`, then
     `s ∈ p.sources`, hence `s ∈ m.required reg roles p`.
- **L6 bounded loss.** As version 1, with only `N.Bounded`, on `c.evaluate N`.
- **L7 input reads.** For `H = wStart + n·HOUR`, `c.machineAfter N n = .ok ms`, `i < p.nodes.size`,
  `p.nodes[i]! = .input ⟨s, k⟩` and coin `x` listed at `H`, let `r` be the last observation of `(s, x)` in
  `c.deliveryPrefix (H + δ)`: `ms.vals[i]![x]! = (r.bind (·.vals[k]!)).bind N.keep` if `s` is held, and the same if
  `s` is an event source and `r`'s slot is `some H`, else undefined.

## 8. C7.7's named attacks: the law and the named `mm` test that catch each

| # | Attack | Law / check | Named test (planned location) | Expected | Positive control |
|---|---|---|---|---|---|
| 1 | forged ledger passes | verifier writes certificates in its transaction | `kernel/mm/tests/certify.rs::forged_pass_is_not_authority` | no certificate | issuance from the same bundle |
| 2 | missing tests, unjustified inapplicability | policy categories | `certify.rs::missing_test_refused` | issuance refused | a complete bundle |
| 3 | changed thresholds or policy | `matches` (policy pinned in the build) | `certify.rs::changed_policy_uncertified` | `R_UNCERTIFIED` | the frozen policy |
| 4 | replay against another manifest, mapping, extractor or rule | `matches`; verifier for mapping and extractor | `admission.rs::replayed_certificate` | `R_UNCERTIFIED` | the matching dataset |
| 5 | use outside the certified scope | L5, `inScope` | `admission.rs::out_of_scope_access` | `R_UNCERTIFIED` | a run within its grants |
| 6 | data changed after validation | the loader's content identity (trusted boundary) | `admission.rs::changed_data` | `R_UNCERTIFIED` | unchanged data |
| 7 | failed issuance or ledger commit before output | commit before output | `certify.rs::failed_commit_emits_nothing` | no certificate, no output | a committed issuance |
| 8 | a missing source in an unused let or inactive branch | L5.5, unbound check | `admission.rs::unused_let_source_required` | `R_INPUT_UNAVAILABLE` | the source bound |
| 9 | uncertified execution data | providers in `required`, role columns in `accesses` | `admission.rs::uncertified_role_provider` | `R_UNCERTIFIED` | certified providers |
| 10 | feed timestamp posing as trusted availability | verifier availability basis; `times` in `accesses` | `certify.rs::claimed_time_without_live_test` | issuance refused, or `R_UNCERTIFIED` | a server-set time with a passing live test |
| 11 | backdated revisions, superseded-rule outputs, old-revision fallback | C7.6 resolver suite | `kernel/tests/rules/test_three_implementations.py` | the selected revision's knownAt | the hand cases |
| 12 | future-dependent coverage or mapping | verifier coverage and mapping by knownAt | `certify.rs::coverage_from_a_later_poll` | issuance refused | coverage known in time |
| 13 | a derived feed before an upstream input; an upstream read outside its grants | resolver dependency bounds; lineage accesses | resolver suite; `admission.rs::lineage_out_of_scope` | knownAt raised; `R_UNCERTIFIED` | lineage within grants |
| 14 | timestamp overflow, malformed rule | C7.6 rule-language suite | `kernel/tests/rules/test_three_implementations.py` | `R_OVERFLOW`, `E_RULE` | in-range rules |
| 15 | holdout through a declaration, binding, alias or derived dependency | L5, stage 1 identity and stage 2 rows over `required` | `admission.rs::holdout_copy_refused`, `holdout_dependency_refused` | `R_HOLDOUT` | the search store |
| 16 | zero-filling, an event held past its tick, a held value expiring wrongly | L7 | `machine.rs::held_and_event_reads` | undefined, never zero | delivered values read as stated |
| 17 | a payload opened before the metadata checks pass | stage 1's type; `mm`'s staging | `admission.rs::superseded_cert_with_unreadable_payload` | `R_UNCERTIFIED`, no read error | a readable payload |
| 18 | non-time columns opened before I8's check | stage 2's type; `mm`'s staging | `admission.rs::holdout_rows_with_unreadable_values` | `R_HOLDOUT`, no read error | values readable |
| 19 | an older correction delivered after the current hour's event row (GPT B7) | L7, version 1's order | `machine.rs::late_correction_undefines_event` | undefined | the current row last |
| 20 | a slot or control column outside the grants | `columns` in `accesses` | `admission.rs::slot_column_out_of_scope` | `R_UNCERTIFIED` | slot column granted |
| 21 | an ungranted value read by the initialization tick of an empty window | `useEnd` | `admission.rs::empty_window_initialization` | `R_UNCERTIFIED` | grants covering the first tick |

Each test is committed with its expected code before its first judged run (C7 evidence rule).

## 9. Spec and annex changes that go with this (before any proof or baseline capture)

- **SOURCES.md version 2.** §1: the `evidence` cadence; each declaration's availability columns (`fetchedAt`
  included), event-time column (evidence declarations included) and slot column (event sources); fields name their
  stored column; roles map role columns to stored columns. §4: key and slot distinct; every bound source is
  delivered; within a source by (knownAt, coin, resolver position); held reads the latest, event reads the latest
  only if its slot is the current hour; the cross-source interleaving unobservable. §6: role columns non-null and
  finite, the bars key on the 4h grid, providers distinct, checked at run admission (`R_BINDING`, `R_ROLES`); volume
  is not a role column; execution reads role records at event or open time (§1). §7: the three stages of §4; a
  dataset's id is its content identity; scope covers every column read and the resolver's lineage reads.
- **CERTIFICATES.md.** §5: a role certificate attests that each record's event time is the venue's application time
  and its value the applied one; grants cover every column a run reads, availability and control columns included,
  and the upstream records a derived observation's knownAt was bounded by; the policy and verifier hashes are
  compiled into the kernel build. Supersession records are admission state, not part of a certificate's payload.
- **INVARIANTS.md.** I8 unchanged; added before it: a search run whose required datasets include a holdout dataset, by
  content identity, is refused (`R_HOLDOUT`). New codes `R_UNCERTIFIED`, `R_BINDING`, `R_ROLES`.
- **RULES.md §6.** The resolver reports each observation's lineage.
- **SEMANTICS.md.** The latest-observation store and its reads, per-source delivery, the decision's reads from the
  providers' delivered observations, the projections and the staged admission; §8's "core datasets always present"
  deleted.
- **Migration annex §4.** The compared "deliveries" are one stream per source, each delivery with its tick and
  knownAt, in (knownAt, coin, resolver position) order, the position being version 1's array order; the baseline is
  captured in that form. A migrated run binds every dataset version 1 would load, unread event feeds included. The
  annex's grants must cover the accesses of §5 for the baseline runs; if they do not, the access footprint is refined,
  never the evidence widened (GPT N2).

## 10. Findings of the last three reviews, their answers, and their effect (CLAUDE.md, rule 3)

Opus review 3 (F, N), Opus review 4 (accepted revision 4; its corrections taken in revision 5), GPT review 1 (B, N):

| Finding | Could change a false-discovery or leakage outcome | Answer |
|---|---|---|
| Opus-3 F1 row check later and narrower than I8 | leakage | stage 2 over every stored row's event time before resolution |
| Opus-3 F2 cross-source order | no | per-source order; superseded by GPT B7's exact order |
| Opus-3 F3, F4 availability columns, stored names | leakage | `Decl.columns`, stored names throughout |
| Opus-3 F5 dependency closure | leakage | one `required`, closed over delivered sources, programs and providers |
| Opus-3 F6, F7 L7 range, hypotheses | no | `i < p.nodes.size`; version 1's domains kept (§7) |
| Opus-3 F8 prose definitions | leakage via `lastTick` | written; the rest becomes Lean before review (N3) |
| Opus-3 N1–N8 | no | taken (InputRef, policy in the build, placements, WF, named tests, erasure) |
| Opus-4 maxKnown's initial value; R_ROLES first; per-position L5 | no | taken |
| GPT B1 preflight order not enforced | leakage | staged `stage1`, `stage2`, `run` with a two-stage `Loader`; tests 17 and 18 |
| GPT B2 certified bytes not linked to observations | leakage | `Loader.Faithful`, the explicit trusted boundary, discharged by content hashing, C7.6 and tests 6, 17, 18 |
| GPT B3 late role observations affect decisions | leakage (if a provider is not venue state) | the execution-role contract: role records are venue state at event time, certified as such (§1, §9) |
| GPT B4 slot and control columns unscoped | leakage | `slotColumn`; `Decl.columns` in every access; test 20 |
| GPT B5 upstream reads unscoped | leakage | `Obs.lineage`; lineage accesses; test 13 |
| GPT B6 empty-window initialization read | leakage | `useEnd`; test 21 |
| GPT B7 event tie order differs from version 1 | false discovery (decisions differ) | version 1's order and its event read; test 19 |
| GPT N1 positional L5.2 | no | `firstFailure` |
| GPT N2 over-approximated accesses | no (C7.4 risk) | reads from delivery, not `min known key`; annex refines the footprint, never widens evidence |
| GPT N3 incomplete definitions and signatures | no | the next step: compiling Lean with full signatures, reviewed by GPT before any freeze |

Recorded limitations, none able to change a false-discovery or leakage outcome: `maxKnown` (a fill's `inputsKnown`)
may reflect a delivered event observation of a pre-window slot, a trace timestamp only; listing intervals from the
venue-rules artifact (above); a held value's use is counted through `useEnd` even after replacement (safe direction).
