# Stage 7, slice 1: the reference semantics generalized over declarations, and the laws restated (draft, revision 3)

C7.7 requires the Lean semantics to be parameterized by validated declarations and bindings; every stage 6 law to keep
its guarantee for every admitted declaration, held and event cadences included; each law whose definitions change to
be revised, independently reviewed and frozen before its proof; and a binding law under which evaluation is undefined
whenever a required source lacks a valid, matching, in-scope certificate. `Ref/Spec.lean` and `Ref/Laws.lean` stay
frozen as version 1 until this draft is resolved.

History: revision 1 was reviewed by a fresh-context Opus agent (11 defects, D1–D11); revision 2 re-derived the
design and was reviewed by another (blocking B1–B5, further N1–N10). Revision 3 answers both reviews (§8). GPT's
review is queued; whatever it finds is fixed then. Each answer is a design change, not a patch.

## 1. The design, from what the semantics reads

- **Everything a decision reads is delivered.** Inputs, the decision's freshness and its price are reads of delivered
  observations, so a role provider's observations carry their role columns and are delivered like any source's.
  Execution (scheduled-bar opens, marks, extremes, settlement) reads projections of the same observations, after the
  decision.
- **Cadence decides how a delivered observation is read.** The machine keeps, per source and coin, the observations
  delivered so far. A held input reads the latest delivered; an event input reads the one whose slot is the current
  hour. One store, two reads, both selected by the registry.
- **Delivery is version 1's three loops, generalized.** At each tick, each delivered source's due observations are
  delivered in registry order, and within a source in (knownAt, coin, key) order. Version 1 is the case of a registry
  ordered funding, bars, events. Every bound source is delivered (version 1 delivers every event dataset in the
  store), and every delivered source must be certified.
- **Admission is a record, and everything about it is a definition.** It pins one binding per source, the
  certificates, the supersession records at a ledger position, the admitted observations with their datasets, and the
  holdout boundary. "Bound", "certified" and "authorized" are definitions over it, checked in an order that never
  opens a payload before the payload-free checks pass.

## 2. Registry, roles and inputs

```lean
inductive Cadence where
  | held | event | evidence
  deriving DecidableEq, Repr

inductive Role where
  | bars | settlement
  deriving DecidableEq, Repr

/-- One active declaration (SOURCES.md §1): its file's hash and its rule bytes' hash (what a certificate must match),
fields (input name and unit, in name order), cadence, dependencies (registry indices) and the roles it can provide. -/
structure Decl where
  hash : Hash
  rule : Hash
  fields : Array (String × Dim)
  cadence : Cadence
  depends : List Nat
  roles : List Role

structure Registry where
  decls : Array Decl

/-- Every source reachable from `xs` through `depends`, `xs` included; `fuel` bounds the walk, and the registry's
size suffices when its dependencies are acyclic. -/
def Registry.closure (reg : Registry) : Nat → List Nat → List Nat
  | 0, xs => xs.eraseDups
  | fuel + 1, xs => (xs ++ reg.closure fuel (xs.flatMap fun s => (reg.decls[s]!).depends)).eraseDups

def Registry.Valid (reg : Registry) : Prop :=
  (reg.decls.toList.flatMap (fun d => d.fields.toList.map (·.1))).Nodup ∧
  (∀ d ∈ reg.decls.toList, ∀ s ∈ d.depends, s < reg.decls.size) ∧
  (∀ s < reg.decls.size, s ∉ reg.closure reg.decls.size ((reg.decls[s]!).depends)) ∧
  (∀ d ∈ reg.decls.toList, (d.fields.toList.map (·.1)).Sorted (· < ·)) ∧
  (∀ d ∈ reg.decls.toList, d.cadence = .evidence → d.fields.size = 0 ∧ d.roles = [])

structure Input where
  source : Nat
  field : Nat
  deriving DecidableEq, Repr

/-- The run's role providers: distinct declarations, each listing its role. -/
structure Roles where
  bars : Nat
  settlement : Nat

def Roles.Valid (reg : Registry) (r : Roles) : Prop :=
  r.bars ≠ r.settlement ∧ r.bars < reg.decls.size ∧ r.settlement < reg.decls.size ∧
  Role.bars ∈ (reg.decls[r.bars]!).roles ∧ Role.settlement ∈ (reg.decls[r.settlement]!).roles
```

`check : Registry → String → Except Code Program` resolves an input name to its unique `⟨source, field⟩`; an
undeclared name is `E_UNKNOWN_INPUT`. `Program.WF reg p` requires, for `.input inp`: `inp.source < reg.decls.size`,
`inp.field <` its field count, and `p.types[i]! = .num` the declared unit; its unit and cadence are never stored on
the program. `CheckerAccepted reg p := reg.Valid ∧ ∃ text, check reg text = .ok p`.
`Program.sources p := (p.nodes.toList.filterMap fun n => match n with | .input i => some i.source | _ => none).eraseDups`.

## 3. Observations and admission

```lean
/-- A role provider's columns for one observation (SOURCES.md §6, version 2): a bar's open, extremes, close and trade
count (its open time is key − BAR), or a settlement rate. -/
inductive RolePayload (α : Type) where
  | bar (o h l c : α) (trades : Int)
  | rate (r : α)

/-- One resolved observation (RULES.md §6): its declaration and the dataset it was read from, coin, key (eventTime),
slot (an event source's event hour; none otherwise), effective knownAt, one value per field (`none` for null), and its
role payload if its source is a role provider. -/
structure Obs (α : Type) where
  source : Nat
  dataset : DatasetId
  coin : Nat
  key : Int
  slot : Option Int
  known : Int
  vals : Array (Option α)
  role : Option (RolePayload α)

/-- A grant (CERTIFICATES.md §5): an entity, one stored column, an event-time interval and a permitted-use interval,
both half-open. -/
structure Grant where
  coin : Nat
  column : String
  event : Int × Int
  use : Int × Int

/-- One access: the column read, the entity, the row's event time, and the interval over which it is used. -/
structure Access where
  coin : Nat
  column : String
  event : Int
  use : Int × Int

def Grant.covers (g : Grant) (x : Access) : Bool :=
  g.coin == x.coin && g.column == x.column && g.event.1 ≤ x.event && x.event < g.event.2 &&
  g.use.1 ≤ x.use.1 && x.use.2 ≤ g.use.2

/-- A certificate's payload as the verifier wrote it (CERTIFICATES.md §5); its id hashes this payload. -/
structure Cert where
  id : Hash
  decl : Hash
  rule : Hash
  manifest : Hash
  policy : Hash
  verifier : Hash
  upstream : List Hash
  grants : List Grant

structure Binding where
  dataset : DatasetId
  cert : Hash

inductive Mode where
  | search | holdout
  deriving DecidableEq

/-- One admitted snapshot (SOURCES.md §7): one binding per source, the certificates and the supersession records
(certificate id, ledger position) visible at the lifecycle check's position, each dataset's manifest hash and
lineage, the frozen policy and verifier hashes, the holdout datasets and the holdout start, the listing intervals (from
the venue-rules artifact the run identity pins), and the observations read from the bound datasets. -/
structure Admission (α : Type) where
  bindings : Nat → Option Binding
  certs : List Cert
  supersessions : List (Hash × Nat)
  position : Nat
  manifest : DatasetId → Hash
  lineage : DatasetId → List DatasetId
  policy : Hash
  verifier : Hash
  holdout : List DatasetId
  holdoutStart : Int
  intervals : Array (Int × Int)
  obs : Array (Obs α)
```

`DatasetId` is a content identity: a dataset's id is the hash of its data manifest, so a copy of a holdout dataset is
the same dataset, and an alias is impossible.

```lean
def Admission.cert (a : Admission α) (h : Hash) : Option Cert := a.certs.find? (·.id == h)

/-- A certificate is valid at the admission's position when no supersession record at or before it names it, and
every upstream certificate is present and valid; `fuel` bounds the walk (the certificate count suffices), and a cycle
exhausts it, which is invalid. -/
def Admission.valid (a : Admission α) : Nat → Hash → Bool
  | 0, _ => false
  | fuel + 1, h => match a.cert h with
    | none => false
    | some k => !(a.supersessions.any fun (x, pos) => x == h && pos ≤ a.position) &&
                k.upstream.all (a.valid fuel ·)

/-- A certificate matches source s's binding: the declaration's file and rule bytes, the bound dataset's manifest,
the frozen policy and verifier, and, for a derived source, upstream certificates that are exactly those bound for its
dependencies. -/
def Admission.matches (reg : Registry) (a : Admission α) (s : Nat) (b : Binding) (k : Cert) : Bool :=
  k.id == b.cert && k.decl == (reg.decls[s]!).hash && k.rule == (reg.decls[s]!).rule &&
  k.manifest == a.manifest b.dataset && k.policy == a.policy && k.verifier == a.verifier &&
  k.upstream.toFinset == ((reg.decls[s]!).depends.filterMap fun d => (a.bindings d).map (·.cert)).toFinset
```

## 4. The context, its sets and its checks

`Ctx.make reg roles p a v pol stop` fixes:

- `deliveredSet := (List.range reg.decls.size).filter fun s => (a.bindings s).isSome ∧ (reg.decls[s]!).cadence ≠ .evidence`
  (every bound, non-evidence source is delivered, as version 1 delivers every event dataset in the store);
- `needed := reg.closure reg.decls.size (p.sources ++ [roles.bars, roles.settlement])` (what must be bound: the
  program's sources, the role providers and their dependencies);
- `certSet := (deliveredSet ++ needed).eraseDups` (what must be certified);
- `obs := a.obs.filter (·.source ∈ deliveredSet)`;
- `lastTick := pol.wStart + (number of ticks before stop) · HOUR + pol.delta` (the last tick the schedule runs);
- `oOrder`: `obs` indices sorted by `(tickOf o.known, rank o.source, o.known, o.coin, o.key)`, where
  `tickOf t` is the first tick at or after t and `rank` the source's registry index. Within a tick this is
  version 1's order: each source's due observations in turn, each in (knownAt, coin, key) order. With unique keys
  it is total.

**Accesses.** Every read, per column, with the time it is first used:

```lean
def Ctx.accesses (c : Ctx α) (s : Nat) : List Access :=
  let start (t : Int) := max t (c.pol.wStart + c.pol.delta)
  c.obs.toList.filter (·.source == s) |>.flatMap fun o =>
    -- fields: read from delivery (known ≤ lastTick) to stop
    (if o.known ≤ c.lastTick then (c.reg.decls[s]!).fields.toList.map fun (col, _) =>
       ⟨o.coin, col, o.key, (start o.known, c.stop)⟩ else []) ++
    -- role columns: read by execution through stop, from their event time if earlier than delivery
    (match o.role with
     | some (.bar ..) => [("open", o.key - BAR), ("trades", o.key - BAR), ("high", o.key), ("low", o.key),
                          ("close", o.key)].map fun (col, t) => ⟨o.coin, col, o.key, (start (min o.known t), c.stop)⟩
     | some (.rate _) => [⟨o.coin, "rate", o.key, (start (min o.known o.key), c.stop)⟩]
     | none => [])
```

Each role read is listed for every observation in the admitted record (execution can read any of them through
`stop`), whether or not its knownAt precedes the last tick. Mapping and coverage facts, availability-time columns and a
derived source's upstream lineage are certified by the verifier at issuance (CERTIFICATES.md §3, `derived-inherits`),
and are pinned here through `matches` (the dependencies' certificates); they are not run-time accesses.

```lean
def Ctx.bound (c : Ctx α) (a : Admission α) : Bool := c.needed.all fun s => (a.bindings s).isSome

def Ctx.authorizedIds (c : Ctx α) (a : Admission α) (mode : Mode) : Bool :=
  mode == .holdout || c.certSet.all fun s => match a.bindings s with
    | none => true
    | some b => (b.dataset :: a.lineage b.dataset).all (· ∉ a.holdout)

def Ctx.authorizedRows (c : Ctx α) (a : Admission α) (mode : Mode) : Bool :=
  mode == .holdout || c.obs.all (·.key < a.holdoutStart)

def Ctx.certified (c : Ctx α) (a : Admission α) : Bool :=
  c.certSet.all fun s => match a.bindings s with
    | none => false
    | some b => match a.cert b.cert with
      | none => false
      | some k => a.valid a.certs.length b.cert && a.matches c.reg s b k && (c.accesses s).all fun x => k.grants.any (·.covers x)

def Ctx.preflight (c : Ctx α) (a : Admission α) (mode : Mode) : Except Abort Unit := do
  if !c.bound a then throw .inputUnavailable           -- payload-free
  if !c.authorizedIds a mode then throw .holdout        -- payload-free
  -- the resolver runs here (RULES.md §6): its rejections (an invalid dataset, R_OVERFLOW) refuse the run
  if !c.authorizedRows a mode then throw .holdout       -- the resolved rows (I8, generalized)
  if !c.certified a then throw .uncertified

def Ctx.run (N) (c : Ctx α) (a : Admission α) (mode : Mode) : Except Abort (Run α) :=
  c.preflight a mode *> c.evaluate N
```

`Abort` gains `.uncertified ↦ "R_UNCERTIFIED"`; `.holdout ↦ "R_HOLDOUT"`. The resolver is outside the Lean model
(C7.6 tests it against `store.as_of` and the suites); the model receives its resolved observations. The binding check
leaves `Ctx.start` and `Ctx.umachineAfter`.

**Admissibility, each clause enforced by a named rejection** (SOURCES.md version 2, §5 below):

| Clause | Rejected where, with |
|---|---|
| `reg.Valid`; `roles.Valid reg` | registry and run admission, `E_REGISTRY` / `R_ROLES` |
| observation keys `(source, coin, key)` unique | resolver, `R_INVALID_DATASET` (RULES.md §6) |
| `o.source < size`, not evidence, `o.coin < intervals.size`, `vals.size` its field count | binding validation, `R_BINDING` |
| `o.dataset = (bindings o.source).dataset` | admission, by construction (observations are read from the bound dataset) |
| `role` present exactly for the providers, `.bar` for bars and `.rate` for settlement, every role column non-null | binding validation, `R_BINDING` |
| bars provider: `key − BAR` on the 4h grid | binding validation, `R_BINDING` |
| event source: `slot` some, on the hour grid, `(source, coin, slot)` unique; other sources: `slot` none | binding validation, `R_BINDING` |
| every value and role payload finite or null | binding validation, `R_BINDING` |

## 5. The machine and delivery

`MState`'s `funding`, `bar` and `events` become `delivered : Array (Array (List (Obs α)))`, per source then coin,
newest first. Delivery prepends.

```lean
def MState.input (reg : Registry) (m : MState α) (i : Input) (c : Nat) : Val α :=
  let ds := m.delivered[i.source]![c]!
  match (reg.decls[i.source]!).cadence with
  | .held => ds.head?.bind (·.vals[i.field]!)
  | .event => (ds.find? (·.slot == some m.hour)).bind (·.vals[i.field]!)
  | .evidence => none
```

Delivery at a tick delivers every observation of `oOrder` with `known ≤ tick` not yet delivered, each checked
`known ≤ tick` (I1) and raising `maxKnown`. The decision (step 9) is fresh when the bars provider's and the settlement
provider's latest delivered observations for the coin have `key = B`, and is priced at the bars provider's latest
delivered close. Execution reads `bars c := c.obs.filterMap (barRow roles)` and `rates c := c.obs.filterMap (rateRow
roles)` (the providers' observations with their payloads), which `barAt`, `latestClosed`, the index and settlement use
as version 1 uses its tables:

```lean
def barRow (roles : Roles) (o : Obs α) : Option (BarRow α) := match o.role with
  | some (.bar op h l cl tr) => if o.source == roles.bars then some ⟨o.coin, o.key - BAR, o.key, o.known, op, h, l, cl, tr⟩ else none
  | _ => none
def rateRow (roles : Roles) (o : Obs α) : Option (RateRow α) := match o.role with
  | some (.rate r) => if o.source == roles.settlement then some ⟨o.coin, o.key, o.known, r⟩ else none
  | _ => none

def Ctx.deliveryPrefix (c : Ctx α) (t : Int) : List (Obs α) := (c.oOrder.toList.map (c.obs[·]!)).filter (·.known ≤ t)

def Ctx.execView (c : Ctx α) (t : Int) :=
  ((c.rates.filter (·.event ≤ t)).map (fun r => (r.coin, r.event, r.rate)),
   c.bars.filter (fun b => b.openTime + BAR ≤ t),
   (c.bars.filter (·.openTime ≤ t)).map (fun b => (b.coin, b.openTime, b.o, b.trades)),
   c.intervals)
```

`BarRow` loses `v` (no execution read uses volume; it stays a DSL field). The listing intervals come from the
venue-rules artifact the run identity pins; they are not a certified source, a known limitation until stage 8
records delisting as a source with its own knownAt (C8.1).

## 6. Revised law statements

Every law takes `reg`, `roles` with `CheckerAccepted reg p`, `roles.Valid reg` and `a.Admissible reg roles`, on
`c := Ctx.make reg roles p a v pol stop`. L1–L4, L6 and L7 are stated on the preflight-free schedule (`machineAfter`,
`steps`, `evaluate`), so they hold for every admissible record; L5 relates `run` to `evaluate`.

- **L1 non-interference.** `L1_values`: equal intervals and equal delivery prefixes at tick `wStart + n·HOUR + δ` give
  equal machines after every tick through it. `L1_simulator` unchanged in form. `L1_decisions`: equal delivery
  prefixes and execution views at decision `k`'s time give equal traces through step `k + 1`. Version 1's `hB` is
  gone (binding is preflight's).
- **L2 unit soundness.** `L2_units` as version 1, its erasure clause `u.m.delivered = ms.delivered`. `L2_checker`:
  `CheckerAccepted reg p → p.WF reg`.
- **L3 rewrite soundness.** With `p.WF reg`, `r.apply p i = some p'`: `p'.WF reg`; equal node values at corresponding
  nodes at every tick; equal traces at every step; `p'.sources` and `p.sources` equal as sets (the rules overwrite
  only op nodes and insert only a `not`), so `needed`, `certSet` and `accesses` are equal and `run` is equal.
- **L4 fill ordering.** `L4_fills` and `L4_orders` as version 1, on `c.evaluate N = .ok r`, reading the projections;
  an ordinary fill's `inputsKnown` is the decision machine's `maxKnown`.
- **L5 binding and admission.** For every admissible record:
  0. *(C7.7's statement)* `c.run N a mode = .ok r → c.bound a ∧ c.authorizedIds a mode ∧ c.authorizedRows a mode ∧
     c.certified a`;
  1. `c.run N a mode = .error .inputUnavailable ↔ ¬ c.bound a`;
  2. if bound: `c.run N a mode = .error .holdout ↔ ¬ (c.authorizedIds a mode ∧ c.authorizedRows a mode)`;
  3. if bound and authorized: `c.run N a mode = .error .uncertified ↔ ¬ c.certified a`;
  4. if bound, authorized and certified: `c.run N a mode = c.evaluate N`;
  5. *(refusal non-interference)* preflight's result depends only on the bindings, certificates, supersessions,
     position, manifests, lineage, policy, verifier, holdout datasets and start, and the access set: two admissions
     that agree on these, and whose observations agree on everything but `vals` and role payload values, get the same
     preflight result; and `.holdout` by identity depends on no observation at all;
  6. *(on the text)* if `check reg text = .ok p` and an input name declared for source `s` occurs anywhere in `text` (a
     let, used or not; a branch; the prediction), then `s ∈ p.sources`, hence `s ∈ c.needed`.
- **L6 bounded loss.** As version 1, on `c.evaluate N`.
- **L7 input reads (new).** For `H = wStart + n·HOUR`, `c.machineAfter N n = .ok ms`, `p.nodes[i]! = .input ⟨s, k⟩`,
  and coin `x` listed at `H`: `ms.vals[i]![x]! = (r.bind (·.vals[k]!)).bind N.keep`, where `r` is the last observation
  of `(s, x)` in `c.deliveryPrefix (H + δ)` if `s` is held, and the observation of `(s, x)` with `slot = some H` in
  that prefix if `s` is an event source.

## 7. C7.7's named attacks: the law or test that catches each

| # | Attack | Caught by | Check targeted | Expected | Positive control |
|---|---|---|---|---|---|
| 1 | forged ledger passes | verifier and ledger test (`mm certify`) | certificates written only by the verifier, in its transaction | refused, no certificate | the verifier issuing from the same bundle |
| 2 | missing tests or an unjustified inapplicability | verifier test | policy categories and justification kinds | issuance refused | a complete bundle issues |
| 3 | changed thresholds or policy | `matches` (policy hash); verifier test | certificate pins the policy | `R_UNCERTIFIED` | the frozen policy |
| 4 | replay against another manifest, mapping, extractor or rule | `matches` (manifest, rule, declaration, upstream); verifier test for mapping and extractor | certificate pins | `R_UNCERTIFIED` | the matching dataset |
| 5 | use outside the certified scope | L5.3 via `accesses` and grants | per-column grants, use intervals | `R_UNCERTIFIED` | a run inside the grants |
| 6 | data changed after validation | `matches` (manifest = content id of the bytes read); admission test recomputing the manifest | content identity | `R_UNCERTIFIED` | unchanged data |
| 7 | failed issuance or ledger commit before output | verifier and ledger test | commit before output | no certificate, no output | a committed issuance |
| 8 | a missing source in an unused let or an inactive branch | L5.1 with L5.6 | `needed` from the text | `R_INPUT_UNAVAILABLE` | the source bound |
| 9 | uncertified execution data | L5.3 (role reads in `accesses`, providers in `needed`) | role providers certified | `R_UNCERTIFIED` | certified providers |
| 10 | a feed timestamp posing as trusted availability | verifier test (availability basis) | rule and live test | issuance refused | a server-set time with a passing live test |
| 11 | backdated revisions, superseded-rule outputs, old-revision fallback | C7.6 resolver suite and `store.as_of` agreement | RULES.md §6 | the selected revision's knownAt | the hand cases |
| 12 | future-dependent coverage or mapping | verifier test (coverage and mapping by knownAt) | coverage evidence | issuance refused | coverage known in time |
| 13 | a derived feed available before an upstream input | C7.6 resolver suite (dependency bounds); `matches` (upstream) | RULES.md §6 lag bounds | knownAt raised to the bound | lineage within bounds |
| 14 | timestamp overflow, or a malformed rule exposing data early | C7.6 rule-language suite | RULES.md §5 | `R_OVERFLOW`, `E_RULE` | in-range rules |
| 15 | holdout data through a declaration, binding, alias or derived dependency | L5.2 (identity and lineage; rows by key) | content identity, transitive lineage, I8 row bound | `R_HOLDOUT` | the search store |
| 16 | zero-filling, an event held past its tick, a held value expiring wrongly | L7 | input reads | undefined, never zero | delivered values read as stated |

Each named test lives beside the check it targets (`kernel/mm/tests`, `ingest/tests`, `kernel/tests/rules`) and is
committed with its expected code before its first judged run (C7 evidence rule).

## 8. Spec changes that go with this (before any proof)

- **SOURCES.md version 2.** §1: the `evidence` cadence; declarations carry their file hash and rule-bytes hash.
  §4: an observation's key and slot are distinct (slot only for event sources, on the hour grid, unique per source and
  coin); delivery per tick in registry order, within a source by (knownAt, coin, key); every bound source is
  delivered. §6: role columns non-null and finite, the bars provider's key on the 4h grid, the two providers distinct,
  checked at binding (`R_BINDING`); volume is not a role column. §7: the order unbound (`R_INPUT_UNAVAILABLE`), holdout
  by identity and lineage (`R_HOLDOUT`), resolution, holdout by row (`R_HOLDOUT`), uncertified (`R_UNCERTIFIED`), all
  before evaluation; a dataset's id is its content identity.
- **CERTIFICATES.md version 2.** §5: grants are per column; supersession records are admission state, not part of a
  certificate's payload; `matches` pins the policy, the verifier and the dependencies' certificates.
- **INVARIANTS.md.** The I8 row: search mode refuses (`R_HOLDOUT`) a run whose bound datasets or their lineage include
  a holdout dataset, by content identity, or whose resolved rows have eventTime ≥ the holdout start; the codes
  `R_UNCERTIFIED`, `R_BINDING` and `R_ROLES`.
- **SEMANTICS.md.** The delivered store and its two reads, the per-tick delivery order, the decision's reads from the
  providers' delivered observations, the execution projections, and preflight; §8's "core datasets always present" is
  deleted (role providers are required instead).

## 9. The reviews' findings and their answers

| Finding | Answer |
|---|---|
| D1 role data in two homes | role payloads on delivered observations; projections for execution (§1, §5) |
| D2 event observations lost out of order | the delivered store and its event read (§5) |
| D3, B3 certification opaque; observations untied to bindings | `Admission` with one binding per source, `Obs.dataset`, content-identity manifests, `valid` and `matches` defined (§3) |
| D4, N2 the required set | `deliveredSet`, `needed` and `certSet`, each defined (§4) |
| D5, N1 delivery of unrequired sources; version 1 parity | every bound source delivered and certified; per-tick registry-order delivery, which is version 1's (§1, §4) |
| D6 cadence and unit on the program | `Input := ⟨source, field⟩`; `WF reg` |
| D7 slot versus key | `key` and `slot : Option Int` (§3) |
| D8 preflight undefined | `preflight` and `run` (§4) |
| D9, N3 input reads | L7, as an equation with `N.keep` |
| D10 null role columns | non-null and finite, checked at binding |
| D11, B1, B2 holdout | identity and lineage before any payload, resolver, then rows by key, then certificates (§4) |
| B4 execution reads | per-column accesses with role reads from their event time through `stop` (§4) |
| B5 elided definitions | all written (§2–§5) |
| N4, N5, N6 L5's vacuous clauses | refusal non-interference, the text-level required set, C7.7's headline (§6) |
| N7 `matches` | policy, verifier, upstream; supersessions in the admission (§3) |
| N8 admissibility unenforced | each clause's rejection (§4 table) |
| N9 use interval over-strict | from `max(known, wStart + δ)` |
| N10 erasure | `Cert.source`, `RolePayload.bar.openTime`, `BarRow.v` and held sources' slot removed |
