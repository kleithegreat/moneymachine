# Stage 7, slice 1: the reference semantics generalized over declarations, and the laws restated (draft, revision 4)

C7.7 requires the Lean semantics to be parameterized by validated declarations and bindings; every stage 6 law to keep
its guarantee for every admitted declaration, held and event cadences included; each law whose definitions change to
be revised, independently reviewed and frozen before its proof; and a binding law under which evaluation is undefined
whenever a required source lacks a valid, matching, in-scope certificate. `Ref/Spec.lean` and `Ref/Laws.lean` stay
frozen as version 1 until this draft is resolved.

History: three fresh-context Opus reviews (GPT unavailable; its review queued): `laws-review-opus-1.md` (D1–D11),
`-2.md` (B1–B5, N1–N10), `-3.md` (F1–F8, N1–N8). Revision 4 answers the third (§10). It was the third rejection of this
exit, so each finding's effect on a false-discovery or leakage outcome is recorded there (CLAUDE.md, rule 3).

## 1. The design, from what the semantics reads

- **Everything a decision reads is delivered.** Inputs, the decision's freshness and its price are reads of delivered
  observations; a role provider's observations carry their role columns and are delivered like any source's.
  Execution (scheduled-bar opens, marks, extremes, settlement) reads projections of the same observations.
- **Cadence decides how a delivered observation is read.** Per source and coin the machine keeps the observations
  delivered so far; a held input reads the latest, an event input the one whose slot is the current hour.
- **Delivery order is per source.** Within a source, observations are delivered in (knownAt, coin, key) order, which
  is version 1's per-source order; across sources the order is fixed by (knownAt, source, coin, key) and is
  unobservable (SOURCES.md §4): stores are per source, `maxKnown` is a maximum, and the causality check is per
  observation. Version 1 does not deliver its sources in a uniform cross-source order either (it merges its two event
  feeds by coin), so C7.4's delivery artifact is one stream per source (§9).
- **Admission is a record; every check over it is a definition; nothing reads a payload before the payload-free
  checks pass.** I8's row bound is checked on the time column of every stored row the run opens, before resolution,
  as version 1 checks it at load.

## 2. Registry, roles and inputs

```lean
inductive Cadence where | held | event | evidence deriving DecidableEq, Repr
inductive Role where | bars | settlement deriving DecidableEq, Repr

/-- One active declaration (SOURCES.md §1, version 2): its file's hash (which covers its rule bytes), its fields
(input name, stored column, unit; in input-name order), the stored time columns its availability rule reads
(`fetchedAt` excluded), the stored column holding its event time (for I8, also on evidence declarations), its
cadence, dependencies (registry indices), and, per role it can provide, each role column's stored column. -/
structure Decl where
  hash : Hash
  fields : Array (String × String × Dim)
  times : List String
  eventColumn : String
  cadence : Cadence
  depends : List Nat
  roles : List (Role × List (String × String))

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
  (∀ d ∈ reg.decls.toList, ∀ r ∈ d.roles, r.1 = .bars → (r.2.map (·.1)) = ["open", "high", "low", "close", "trades"]) ∧
  (∀ d ∈ reg.decls.toList, ∀ r ∈ d.roles, r.1 = .settlement → (r.2.map (·.1)) = ["rate"])

structure Input where
  source : Nat
  field : Nat
  deriving DecidableEq, Repr

structure Roles where
  bars : Nat
  settlement : Nat

def Roles.Valid (reg : Registry) (r : Roles) : Prop :=
  r.bars ≠ r.settlement ∧ r.bars < reg.decls.size ∧ r.settlement < reg.decls.size ∧
  ((reg.decls[r.bars]!).roles.any (·.1 == .bars)) ∧ ((reg.decls[r.settlement]!).roles.any (·.1 == .settlement))

def Decl.roleColumns (d : Decl) : List String := d.roles.flatMap fun r => r.2.map (·.2)
```

`check : Registry → String → Except Code Program` resolves an input name to its unique `⟨source, field⟩`; an
undeclared name is `E_UNKNOWN_INPUT`. `Program.WF reg p`: for `.input inp`, `inp.source < reg.decls.size`, `inp.field <`
its field count, and `p.types[i]! = .num` the field's unit. `CheckerAccepted reg p := reg.Valid ∧ ∃ text, check reg
text = .ok p`. `Program.sources p := (p.nodes.toList.filterMap fun n => match n with | .input i => some i.source | _ =>
none).eraseDups`.

**Input references in the text.** `InputRef (v : Json) (name : String)` holds when `{"input": name}` occurs in `v`'s
`weight`, in the body of any `let` (used or not), or in `prediction.condition`, at any depth of the expression grammar
(DSL.md), and nowhere else (not in names, mechanism text or other strings).

## 3. Observations and admission

```lean
inductive RolePayload (α : Type) where
  | bar (o h l c : α) (trades : Int)      -- open time is key − BAR
  | rate (r : α)

/-- One resolved observation (RULES.md §6): its declaration, coin, key (its event time), slot (an event source's
event hour; none otherwise), effective knownAt, one value per field (`none` for null), and its role payload if its
source is a role provider. -/
structure Obs (α : Type) where
  source : Nat
  coin : Nat
  key : Int
  slot : Option Int
  known : Int
  vals : Array (Option α)
  role : Option (RolePayload α)

structure Grant where
  coin : Nat
  column : String        -- a stored column
  event : Int × Int
  use : Int × Int

structure Access where
  coin : Nat
  column : String        -- a stored column
  event : Int
  use : Int × Int

def Grant.covers (g : Grant) (x : Access) : Bool :=
  g.coin == x.coin && g.column == x.column && g.event.1 ≤ x.event && x.event < g.event.2 &&
  g.use.1 ≤ x.use.1 && x.use.2 ≤ g.use.2

/-- A certificate's payload as the verifier wrote it; its id is the hash of this payload. -/
structure Cert where
  id : Hash
  decl : Hash
  manifest : Hash        -- the certified dataset's content identity
  policy : Hash
  verifier : Hash
  upstream : List Hash
  grants : List Grant

/-- A binding: the bound dataset's content identity (the hash of its data manifest) and the certificate. -/
structure Binding where
  dataset : Hash
  cert : Hash

inductive Mode where | search | holdout deriving DecidableEq

/-- One admitted snapshot. `policy` and `verifier` are the hashes frozen with the criteria and compiled into the
kernel build the run identity pins, never read from the files under test. `rows` lists (source, event time) for
every stored row of every dataset the run opens (every revision, tombstone and coin, dependencies included), read
from the time column alone, before any resolution. `obs` is the resolver's output for the delivered sources. -/
structure Admission (α : Type) where
  bindings : Nat → Option Binding
  certs : List Cert
  supersessions : List (Hash × Nat)
  position : Nat
  policy : Hash
  verifier : Hash
  holdout : List Hash
  holdoutStart : Int
  intervals : Array (Int × Int)
  rows : List (Nat × Int)
  obs : Array (Obs α)

def Admission.cert (a : Admission α) (h : Hash) : Option Cert := a.certs.find? (·.id == h)

def Admission.valid (a : Admission α) : Nat → Hash → Bool
  | 0, _ => false
  | fuel + 1, h => match a.cert h with
    | none => false
    | some k => !(a.supersessions.any fun (x, pos) => x == h && pos ≤ a.position) && k.upstream.all (a.valid fuel ·)

def Admission.matches (reg : Registry) (a : Admission α) (s : Nat) (b : Binding) (k : Cert) : Bool :=
  k.decl == (reg.decls[s]!).hash && k.manifest == b.dataset && k.policy == a.policy && k.verifier == a.verifier &&
  k.upstream.toFinset == ((reg.decls[s]!).depends.filterMap fun d => (a.bindings d).map (·.cert)).toFinset

/-- The admitted record is well-formed: certificate ids unique (an id is its payload's hash). -/
def Admission.WF (a : Admission α) : Prop := (a.certs.map (·.id)).Nodup
```

## 4. The context and its sets

```lean
def Ctx.make (reg : Registry) (roles : Roles) (p : Program) (a : Admission α) (v : Venue α) (pol : Policy) (stop : Int) : Ctx α :=
  let delivered := (List.range reg.decls.size).filter fun s => (a.bindings s).isSome && (reg.decls[s]!).cadence != .evidence
  let obs := a.obs.filter (·.source ∈ delivered)
  { reg, roles, p, a, v, pol, stop, delivered, obs
    required := reg.closure reg.decls.size (delivered ++ p.sources ++ [roles.bars, roles.settlement])
    oOrder := (Array.range obs.size).mergeSort fun i j =>
      let x := obs[i]!; let y := obs[j]!
      lexLe [x.known, x.source, x.coin, x.key] [y.known, y.source, y.coin, y.key]
    intervals := a.intervals
    ix := Index.of (obs.filterMap (barRow roles)) (obs.filterMap (rateRow roles)) a.intervals.size }

/-- The schedule's step boundaries (version 1's `bounds`) and its last tick. -/
def Ctx.lastTick (c : Ctx α) : Int := c.pol.wStart + (c.bounds.length : Int) * BAR + c.pol.delta
def Ctx.firstTick (c : Ctx α) : Int := c.pol.wStart + c.pol.delta
```

`required` is the one set every check uses: every delivered source (every bound, non-evidence source, as version 1
delivers every dataset in the store), the program's sources and the role providers, closed under dependencies, so
every upstream dataset the resolver opens is bound, checked by identity and pinned by `matches`.

**Accesses: what the run can read, per stored column, from when.** Only observations the run can read produce
accesses, and an empty use interval produces none:

```lean
def Ctx.readable (c : Ctx α) (o : Obs α) : Bool :=
  match (c.reg.decls[o.source]!).cadence with
  | .held => o.known ≤ c.lastTick &&
      (o.known ≥ c.firstTick || -- delivered during the run, or the latest delivered at the first tick
       c.obs.all fun o' => !(o'.source == o.source && o'.coin == o.coin && o'.known ≤ c.firstTick &&
                             lexLe [o.known, o.key] [o'.known, o'.key] && (o'.known, o'.key) != (o.known, o.key)))
  | .event => o.known ≤ c.lastTick && o.slot.any fun h => c.pol.wStart ≤ h && h + c.pol.delta ≤ c.lastTick
  | .evidence => false

def Ctx.accesses (c : Ctx α) (s : Nat) : List Access :=
  let d := c.reg.decls[s]!
  let use (t : Int) : Int × Int := (max t c.firstTick, c.stop)
  let cols (o : Obs α) (names : List String) (t : Int) : List Access :=
    if (use t).1 < (use t).2 then names.map fun col => ⟨o.coin, col, o.key, use t⟩ else []
  c.obs.toList.filter (·.source == s) |>.flatMap fun o =>
    (if c.readable o then cols o (d.fields.toList.map (·.2.1) ++ d.times) (min o.known o.key) else []) ++
    (match o.role with
     | some (.bar ..) => if o.key - BAR < c.stop then cols o d.roleColumns (min o.known (o.key - BAR)) else []
     | some (.rate _) => if o.key ≤ c.stop then cols o d.roleColumns (min o.known o.key) else []
     | none => [])
```

The fields' and the rule's time columns are read from delivery (or, for a held value carried into the run, from the
first tick) to `stop`; a bar's role columns are read by execution from its open time (the scheduled-bar fill reads the
open; marks and extremes later), a rate's from its event time, each through `stop`; every bar and rate up to `stop` counts, since marks read the
latest closed bar however old. Mapping and coverage facts and a
derived source's upstream lineage are certified by the verifier at issuance and pinned through `matches`.

## 5. Preflight, in the order that never opens a payload early

```lean
def Ctx.bound (c : Ctx α) : Bool := c.required.all fun s => (c.a.bindings s).isSome
def Ctx.authorizedIds (c : Ctx α) (mode : Mode) : Bool :=
  mode == .holdout || c.required.all fun s => (c.a.bindings s).all (·.dataset ∉ c.a.holdout)
def Ctx.certsMatch (c : Ctx α) : Bool :=
  c.required.all fun s => match c.a.bindings s with
    | none => false
    | some b => (c.a.cert b.cert).any fun k => c.a.valid c.a.certs.length b.cert && c.a.matches c.reg s b k
def Ctx.authorizedRows (c : Ctx α) (mode : Mode) : Bool :=
  mode == .holdout || c.a.rows.all (·.2 < c.a.holdoutStart)
def Ctx.admissible (c : Ctx α) : Bool := ...  -- the run-admission clauses of §6, as a decidable predicate
def Ctx.inScope (c : Ctx α) : Bool :=
  c.required.all fun s => match c.a.bindings s with
    | none => false
    | some b => (c.a.cert b.cert).any fun k => (c.accesses s).all fun x => k.grants.any (·.covers x)

def Ctx.preflight (c : Ctx α) (mode : Mode) : Except Abort Unit := do
  if !c.bound then throw .inputUnavailable          -- bindings only
  if !(c.roles.Valid c.reg) then throw .roles        -- registry only (R_ROLES)
  if !c.authorizedIds mode then throw .holdout       -- dataset identities only
  if !c.certsMatch then throw .uncertified           -- certificates, supersessions, hashes only
  if !c.authorizedRows mode then throw .holdout      -- the time column of every stored row (I8)
  -- the resolver runs here (RULES.md §6), outside the model; its rejections refuse the run
  if !c.admissible then throw .binding               -- resolved observations' shape (R_BINDING)
  if !c.inScope then throw .uncertified              -- grants against the accesses

def Ctx.run (N) (c : Ctx α) (mode : Mode) : Except Abort (Run α) := c.preflight mode *> c.evaluate N
```

`Abort` gains `.uncertified ↦ "R_UNCERTIFIED"`, `.holdout ↦ "R_HOLDOUT"`, `.roles ↦ "R_ROLES"`,
`.binding ↦ "R_BINDING"`. I8's frozen wording is unchanged; identity and lineage refusal is an addition before it.

## 6. Admissibility and the machine

`Ctx.admissible` (run admission; the binding knows nothing of the run's roles, so these are run-time clauses):
observation keys `(source, coin, key)` unique; every observation's coin `< intervals.size` (rows of coins outside U are
excluded by the resolver, as version 1 does, and are still in `rows` for I8); `vals.size` the field count; every
value and role payload finite or null; `role` present exactly for the two providers' observations, `.bar` for the
bars provider with every role column non-null and `key − BAR` on the 4h grid, `.rate` for the settlement provider;
an event source's `slot` some, on the hour grid, unique per (source, coin); other sources' `slot` none.

```lean
/-- The machine: per source and coin, the observations delivered so far, newest first. -/
structure MState (α : Type) where
  vals : Array (Array (Val α))
  wins : Array (Array (Option (Win α)))
  since : Array (Array (Option Int))
  delivered : Array (Array (List (Obs α)))
  hour : Int
  maxKnown : Int

def MState.init (reg : Registry) (p : Program) (coins : Nat) : MState α :=
  { vals := Array.replicate p.nodes.size (Array.replicate coins none)
    wins := p.nodes.map fun n => match n with
      | .op (.window w h) _ => Array.replicate coins (some (Win.new N w h)) | _ => Array.replicate coins none
    since := Array.replicate p.nodes.size (Array.replicate coins none)
    delivered := Array.replicate reg.decls.size (Array.replicate coins [])
    hour := 0, maxKnown := 0 }

def MState.deliver (m : MState α) (o : Obs α) (tick : Int) : Except Abort (MState α) :=
  if o.known > tick then .error .causality
  else .ok { m with delivered := m.delivered.modify o.source (·.modify o.coin (o :: ·)), maxKnown := max m.maxKnown o.known }

def MState.input (reg : Registry) (m : MState α) (i : Input) (c : Nat) : Val α :=
  let ds := m.delivered[i.source]![c]!
  match (reg.decls[i.source]!).cadence with
  | .held => ds.head?.bind (·.vals[i.field]!)
  | .event => (ds.find? (·.slot == some m.hour)).bind (·.vals[i.field]!)
  | .evidence => none

/-- Deliver every observation of `oOrder` due by `tick`, from position `s.oi`. -/
def Ctx.deliver (c : Ctx α) (s : SState α) (tick : Int) : Except Abort (SState α) := do
  let mut s := s
  while h : s.oi < c.oOrder.size do
    let o := c.obs[c.oOrder[s.oi]]!
    if o.known > tick then break
    s := { s with machine := ← s.machine.deliver o tick, oi := s.oi + 1 }
  return s
```

`SState`'s `fi`, `bi`, `ei` become one `oi`. `Ctx.start`, `Ctx.step` and `Ctx.evaluate` are version 1's with that
delivery, and without the binding check (moved to preflight). In step 9 the decision is:

```lean
let latest (src : Nat) : Option (Obs α) := s.machine.delivered[src]![coin]!.head?
let fresh := (latest c.roles.bars).any (·.key == bigB) && (latest c.roles.settlement).any (·.key == bigB)
let price := match (latest c.roles.bars).bind (·.role) with | some (.bar _ _ _ cl _) => cl | _ => N.zero  -- fresh implies some
```

Execution reads the projections:

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
venue-rules artifact the run identity pins, and are not a certified source: a known limitation until stage 8 records
delisting with its own knownAt (C8.1).

## 7. Revised law statements

On `c := Ctx.make reg roles p a v pol stop`. L1–L4 and L7 take `CheckerAccepted reg p`, `roles.Valid reg` and
`c.admissible`; L5 takes nothing but its objects; L6 takes only `N.Bounded`, as version 1.

- **L1 non-interference.** `L1_values`: equal intervals and delivery prefixes at tick `wStart + n·HOUR + δ` give equal
  machines after every tick through it. `L1_simulator` as version 1. `L1_decisions`: equal delivery prefixes and
  execution views at decision `k`'s time give equal traces through step `k + 1`.
- **L2 unit soundness.** `L2_units` as version 1, its erasure clause `u.m.delivered = ms.delivered`; `L2_checker`:
  `CheckerAccepted reg p → p.WF reg`.
- **L3 rewrite soundness.** With `p.WF reg`, `r.apply p i = some p'`: `p'.WF reg`; equal node values at corresponding
  nodes; equal traces at every step; `p'.sources` and `p.sources` equal as sets, so `required` and `accesses`, hence
  preflight and `run`, are equal.
- **L4 fill ordering.** `L4_fills`, `L4_orders` as version 1 on `c.evaluate N = .ok r`, reading the projections; an
  ordinary fill's `inputsKnown` is the decision machine's `maxKnown`.
- **L5 binding and admission.**
  0. `c.run N mode = .ok r → c.bound ∧ c.authorizedIds mode ∧ c.certsMatch ∧ c.authorizedRows mode ∧ c.admissible ∧ c.inScope`;
  1. `c.run N mode = .error .inputUnavailable ↔ ¬ c.bound`;
  2. each later refusal holds exactly when every earlier check passes and its own fails, in §5's order;
  3. if all pass, `c.run N mode = c.evaluate N`;
  4. *(refusal non-interference)* the checks through `.holdout` by row depend on no observation value: two admissions
     equal but for `obs` get the same result from them; the remaining checks depend on observations' keys, slots,
     knownAt, coins and the nullness and finiteness of their values, never on the values themselves;
  5. *(the text)* if `check reg text = .ok p` and `InputRef (parse text) name` with `name` declared for `s`, then
     `s ∈ p.sources`, hence `s ∈ c.required`.
- **L6 bounded loss.** As version 1, with only `N.Bounded`, on `c.evaluate N`.
- **L7 input reads.** For `H = wStart + n·HOUR`, `c.machineAfter N n = .ok ms`, `i < p.nodes.size`,
  `p.nodes[i]! = .input ⟨s, k⟩` and coin `x` listed at `H`: `ms.vals[i]![x]! = (r.bind (·.vals[k]!)).bind N.keep`,
  where `r` is the last observation of `(s, x)` in `c.deliveryPrefix (H + δ)` if `s` is held, and the observation of
  `(s, x)` with `slot = some H` there if `s` is an event source.

Under version 1's rules the store's event read cannot diverge from version 1's single held row: an event row's knownAt
is eventTime + δ, raised only by fetchedAt, so an earlier hour's row is never delivered after the current hour's
within a tick.

## 8. C7.7's named attacks: the law and the named `mm` test that catch each

| # | Attack | Law / check | Named test (planned location) | Expected | Positive control |
|---|---|---|---|---|---|
| 1 | forged ledger passes | verifier writes certificates in its transaction | `kernel/mm/tests/certify.rs::forged_pass_is_not_authority` | no certificate | issuance from the same bundle |
| 2 | missing tests, unjustified inapplicability | policy categories | `certify.rs::missing_test_refused` | issuance refused | a complete bundle |
| 3 | changed thresholds or policy | `matches` (policy pinned in the build) | `certify.rs::changed_policy_uncertified` | `R_UNCERTIFIED` | the frozen policy |
| 4 | replay against another manifest, mapping, extractor or rule | `matches` (declaration, manifest, upstream); verifier for mapping and extractor | `admission.rs::replayed_certificate` | `R_UNCERTIFIED` | the matching dataset |
| 5 | use outside the certified scope | L5, `inScope` | `admission.rs::out_of_scope_access` | `R_UNCERTIFIED` | a run within its grants |
| 6 | data changed after validation | `matches` (content identity of the bytes read) | `admission.rs::changed_data` | `R_UNCERTIFIED` | unchanged data |
| 7 | failed issuance or ledger commit before output | commit before output | `certify.rs::failed_commit_emits_nothing` | no certificate, no output | a committed issuance |
| 8 | a missing source in an unused let or inactive branch | L5.1, L5.5 | `admission.rs::unused_let_source_required` | `R_INPUT_UNAVAILABLE` | the source bound |
| 9 | uncertified execution data | L5, providers in `required`, role accesses | `admission.rs::uncertified_role_provider` | `R_UNCERTIFIED` | certified providers |
| 10 | feed timestamp posing as trusted availability | verifier availability basis; `inScope` on time columns | `certify.rs::claimed_time_without_live_test` | issuance refused, or `R_UNCERTIFIED` | a server-set time with a passing live test |
| 11 | backdated revisions, superseded-rule outputs, old-revision fallback | C7.6 resolver suite | `kernel/tests/rules/test_three_implementations.py` | the selected revision's knownAt | the hand cases |
| 12 | future-dependent coverage or mapping | verifier coverage and mapping by knownAt | `certify.rs::coverage_from_a_later_poll` | issuance refused | coverage known in time |
| 13 | a derived feed before an upstream input | resolver dependency bounds; `matches` (upstream) | resolver suite; `admission.rs::upstream_mismatch` | knownAt raised; `R_UNCERTIFIED` | lineage within bounds |
| 14 | timestamp overflow, malformed rule | C7.6 rule-language suite | `kernel/tests/rules/test_three_implementations.py` | `R_OVERFLOW`, `E_RULE` | in-range rules |
| 15 | holdout through a declaration, binding, alias or derived dependency | L5, `authorizedIds` and `authorizedRows` over `required` | `admission.rs::holdout_copy_refused`, `holdout_dependency_refused` | `R_HOLDOUT` | the search store |
| 16 | zero-filling, an event held past its tick, a held value expiring wrongly | L7; `inScope` for use after a grant | `machine.rs` tests `held_and_event_reads` | undefined, never zero | delivered values read as stated |

Each test is committed with its expected code before its first judged run (C7 evidence rule).

## 9. Spec and annex changes that go with this (before any proof or baseline capture)

- **SOURCES.md version 2.** §1: the `evidence` cadence; each declaration's `times` and its event-time column (for I8,
  evidence declarations included); fields name their stored column; roles map role columns to stored columns. §4: key
  and slot distinct (slot only for event sources, on the hour grid, unique per source and coin); every bound source is
  delivered; within a source by (knownAt, coin, key), and the cross-source interleaving unobservable, as now. §6: role
  columns non-null and finite, the bars key on the 4h grid, providers distinct, checked at run admission
  (`R_BINDING`, `R_ROLES`); volume is not a role column. §7: §5's order, the certificates' validity and matching
  checked before any row is read (as now: "before any observation is loaded"), grant scope after resolution; a
  dataset's id is its content identity.
- **CERTIFICATES.md.** §5: availability inputs (the rule's time columns) are granted like fields (the wording stands;
  `accesses` now covers them); the policy and verifier hashes are compiled into the kernel build. Supersession
  records are admission state, not part of a certificate's payload.
- **INVARIANTS.md.** I8 unchanged; added before it: a search run whose required datasets include a holdout dataset, by
  content identity, is refused (`R_HOLDOUT`). New codes `R_UNCERTIFIED`, `R_BINDING`, `R_ROLES`.
- **SEMANTICS.md.** The delivered store and its reads, per-source delivery, the decision's reads from the providers'
  delivered observations, the projections and preflight; §8's "core datasets always present" deleted.
- **Migration annex §4.** The compared "deliveries" are one stream per source, each delivery with its tick and knownAt,
  in (knownAt, coin, key) order; the baseline is captured in that form. The delivered set is every dataset the store
  holds, so a migrated run binds every dataset version 1 would load, unread event feeds included.

## 10. The third review's findings, their answers, and their effect (CLAUDE.md, rule 3)

| Finding | Could change a false-discovery or leakage outcome | Answer |
|---|---|---|
| F1 the row check later and narrower than I8 | leakage | `rows` (every stored row's time column, every opened dataset) checked before resolution; I8's wording kept (§3, §5) |
| F2 cross-source order not version 1's | no | per-source order; cross-source unobservable; the annex's deliveries per source (§1, §9) |
| F3 availability inputs unaccessed | leakage | `Decl.times` in `accesses` (§4) |
| F4 access versus grant column names | no | fields and roles name stored columns; accesses emit them (§2, §4) |
| F5 dependency closure | leakage | one `required`, closed over delivered sources too; `lineage` deleted (§4) |
| F6 L7 out of range | no | `i < p.nodes.size` (§7) |
| F7 new hypotheses on L5 and L6 | no | L5 none, L6 only `N.Bounded` (§7) |
| F8 prose definitions | leakage via `lastTick` | `lastTick`, `Ctx.make`, `deliver`, `MState`, step 9, projections, `barAt`, `latestClosed` written; `Ctx.admissible`'s clauses listed (§4–§6) |
| N1 text-level references | no | `InputRef` on the parsed JSON (§2) |
| N2 policy and verifier from the file under test | leakage (attack 3, operator-only) | compiled into the build (§3) |
| N3 admissibility placement | no | run admission, `R_BINDING` after resolution, `R_ROLES` first; out-of-U coins excluded, still I8-checked (§5, §6) |
| N4 accesses over-approximate | no (safe direction; C7.4 at risk) | `readable`; empty use intervals dropped (§4) |
| N5 certificate checks after loading | no | validity and matching before rows; scope after resolution (§5) |
| N6 duplicate ids | no | `Admission.WF` (§3) |
| N7 named tests | no | the table names an `mm` test per row (§8) |
| N8 erasure | no | `manifest`, `Obs.dataset`, `lineage`, `rank`, `tickOf`, the redundant id and rule checks removed |
