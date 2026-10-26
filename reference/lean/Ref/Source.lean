import Ref.Syntax

/-!
Sources as a language feature (audit/stage7/laws-v2-draft.md §2–§4; SOURCES.md, CERTIFICATES.md, RULES.md §6):
declarations and the registry, resolved observations, certificates, admission metadata, the staged loader, and the
two admission stages that read no payload.
-/

namespace Ref

abbrev Hash := String

inductive Cadence where | held | event | evidence deriving DecidableEq, Repr, Inhabited

/-- A checked availability rule (RULES.md §3), as its expression tree; parsing and checking the rule document are
validated by the C7.6 suite. -/
inductive RuleExpr where
  | field (name : String)
  | dep (name : String)
  | ms (n : Int)
  | add (t d : RuleExpr)
  | floor (t p : RuleExpr)
  | max (xs : List RuleExpr)
  deriving Inhabited, Repr

/-- A dependency: its registry index, its name in the rule, and its declared processing delay (ms, ≥ 0). -/
structure Dep where
  source : Nat
  name : String
  lag : Int
  deriving Inhabited, Repr
inductive Role where | bars | settlement deriving DecidableEq, Repr, Inhabited

/-- One active declaration (SOURCES.md §1): its file's hash, its fields (input name, stored column, unit; in
input-name order), every stored column its availability rule reads (`fetchedAt` included), its event-time, slot
(event sources) and entity columns, the columns that select revisions and mark tombstones, its availability rule,
its cadence, its dependencies, and per role it can provide each role column's stored column. -/
structure Decl where
  hash : Hash
  fields : Array (String × String × Dim)
  times : List String
  eventColumn : String
  slotColumn : Option String
  entityColumn : String
  revisionColumns : List String
  rule : RuleExpr
  cadence : Cadence
  deps : List Dep
  roles : List (Role × List (String × String))
  deriving Inhabited

def Decl.depends (d : Decl) : List Nat := d.deps.map (·.source)

inductive RTy where | time | duration deriving DecidableEq

mutual
/-- A rule expression's type in its declaration's context (RULES.md §4): Time fields (`times`), dependency names. -/
def RuleExpr.ty (times deps : List String) : RuleExpr → Option RTy
  | .field n => if times.contains n then some .time else none
  | .dep n => if deps.contains n then some .time else none
  | .ms n => if decide (0 ≤ n) && decide (n < 2 ^ 62) then some .duration else none
  | .add t d => if t.ty times deps == some .time && d.ty times deps == some .duration then some .time else none
  | .floor t p => match p with
    | .ms n => if t.ty times deps == some .time && decide (0 < n) && decide (n < 2 ^ 62) then some .time else none
    | _ => none
  | .max xs => if 2 ≤ xs.length && xs.length ≤ 16 && RuleExpr.allTime times deps xs then some .time else none

def RuleExpr.allTime (times deps : List String) : List RuleExpr → Bool
  | [] => true
  | x :: xs => x.ty times deps == some .time && RuleExpr.allTime times deps xs
end

mutual
/-- The lower-bound set (RULES.md §4, rule 5): (is a dependency, name). -/
def RuleExpr.lb : RuleExpr → List (Bool × String)
  | .field n => [(false, n)]
  | .dep n => [(true, n)]
  | .ms _ => []
  | .add t _ => t.lb
  | .floor .. => []
  | .max xs => RuleExpr.lbAll xs

def RuleExpr.lbAll : List RuleExpr → List (Bool × String)
  | [] => []
  | x :: xs => x.lb ++ RuleExpr.lbAll xs
end

/-- The declaration's rule is checked (RULES.md §4) and its dependency names are unique. -/
def Decl.ruleOk (d : Decl) : Bool :=
  let names := d.deps.map (·.name)
  names.eraseDups.length == names.length &&
  d.rule.ty d.times names == some .time && !d.rule.lb.isEmpty && names.all (fun n => d.rule.lb.contains (true, n))

/-- Value columns: what a run uses as data, authorized by grants over their use intervals. -/
def Decl.values (d : Decl) : List String := d.fields.toList.map (·.2.1) ++ d.roles.flatMap (·.2.map (·.2))

/-- Control columns: what the resolver reads to select entities and revisions and to compute availability, over the
whole dataset and its dependencies' controls; authorized by the certificate's `controls`. -/
def Decl.controls (d : Decl) : List String :=
  d.times ++ [d.eventColumn] ++ d.slotColumn.toList ++ [d.entityColumn] ++ d.revisionColumns

structure Registry where
  decls : Array Decl

def Registry.closure (reg : Registry) : Nat → List Nat → List Nat
  | 0, xs => xs.eraseDups
  | fuel + 1, xs => (xs ++ reg.closure fuel (xs.flatMap fun s => (reg.decls[s]!).depends)).eraseDups

/-- The checker's input table: every field of every declaration, by input name. -/
def Registry.inputs (reg : Registry) : Array (String × Input) :=
  (Array.range reg.decls.size).flatMap fun s =>
    let d := reg.decls[s]!
    (Array.range d.fields.size).map fun k =>
      (d.fields[k]!.1, ⟨s, k, d.cadence == .event, d.fields[k]!.2.2⟩)

/-- A valid registry: input names unique, dependencies in range and acyclic, evidence declarations without fields or
roles, a slot column exactly for event sources, and role columns as SOURCES.md §6 names them. -/
def Registry.valid (reg : Registry) : Bool :=
  let names := reg.decls.toList.flatMap fun d => d.fields.toList.map (·.1)
  names.eraseDups.length == names.length &&
  reg.decls.all (fun d => d.depends.all (· < reg.decls.size) && d.deps.all (decide <| 0 ≤ ·.lag) && d.ruleOk) &&
  (List.range reg.decls.size).all (fun s => !(reg.closure reg.decls.size (reg.decls[s]!).depends).contains s) &&
  reg.decls.all (fun d => d.cadence != .evidence || (d.fields.size == 0 && d.roles.isEmpty)) &&
  reg.decls.all (fun d => (d.cadence == .event) == d.slotColumn.isSome) &&
  reg.decls.all fun d => d.roles.all fun r => match r.1 with
    | .bars => r.2.map (·.1) == ["open", "high", "low", "close", "trades"]
    | .settlement => r.2.map (·.1) == ["rate"]

def Registry.Valid (reg : Registry) : Prop := reg.valid = true

/-- Programs the frozen checker accepts against a valid registry. -/
def CheckerAccepted (reg : Registry) (p : Program) : Prop := reg.Valid ∧ ∃ text, check reg.inputs text = .ok p

/-- The declarations a program reads. -/
def Program.sources (p : Program) : List Nat :=
  (p.nodes.toList.filterMap fun n => match n with | .input i => some i.source | _ => none).eraseDups

structure Roles where
  bars : Nat
  settlement : Nat

def Roles.valid (reg : Registry) (r : Roles) : Bool :=
  r.bars != r.settlement && r.bars < reg.decls.size && r.settlement < reg.decls.size &&
  (reg.decls[r.bars]!).roles.any (·.1 == .bars) && (reg.decls[r.settlement]!).roles.any (·.1 == .settlement)

inductive RolePayload (α : Type) where
  | bar (o h l c : α) (trades : Int)
  | rate (r : α)
  deriving Inhabited

/-- One resolved observation (RULES.md §6): declaration, coin, key (event time), slot (an event source's event
hour), effective knownAt, one value per field (`none` for null), and role payload for a provider's records. -/
structure Obs (α : Type) where
  source : Nat
  coin : Nat
  key : Int
  slot : Option Int
  known : Int
  vals : Array (Option α)
  role : Option (RolePayload α)
  deriving Inhabited

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
  g.coin == x.coin && g.column == x.column && decide (g.event.1 ≤ x.event) && decide (x.event < g.event.2) &&
  decide (g.use.1 ≤ x.use.1) && decide (x.use.2 ≤ g.use.2)

/-- A certificate's payload as the verifier wrote it; its id is the hash of this payload. `controls` lists the columns
it authorizes the resolver to read over the whole dataset (selection and availability, never as data); grants
authorize value columns for use; `venueState` attests that each record's event time is when the venue applied it and
its value the one applied (required of a role provider). -/
structure Cert where
  id : Hash
  decl : Hash
  manifest : Hash
  policy : Hash
  verifier : Hash
  upstream : List Hash
  grants : List Grant
  controls : List String
  venueState : Bool

/-- A binding: the bound dataset's content identity and its certificate. -/
structure Binding where
  dataset : Hash
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
  /-- The dataset version: the fetchedAt cutoff the run identity pins (RULES.md §6). -/
  version : Int

/-- The loader in two stages: `rows` reads only the event-time column of every stored row of the given datasets
(every revision, tombstone and coin); `resolve` runs RULES.md §6 on them, or fails on an invalid dataset. -/
structure Loader (α : Type) where
  rows : List Nat → List (Nat × Int)
  resolve : List Nat → Option (Array (Obs α))

inductive Abort where
  | causality | timing | fill | accounting | portfolio | bound | inputUnavailable | settlementMissing
  | uncertified | holdout | roles | binding | invalid
  deriving DecidableEq, Repr

def Abort.code : Abort → String
  | .causality => "R_CAUSALITY" | .timing => "R_TIMING" | .fill => "R_FILL" | .accounting => "R_ACCOUNTING"
  | .portfolio => "R_PORTFOLIO" | .bound => "R_BOUND" | .inputUnavailable => "R_INPUT_UNAVAILABLE"
  | .settlementMissing => "R_SETTLEMENT_MISSING" | .uncertified => "R_UNCERTIFIED" | .holdout => "R_HOLDOUT"
  | .roles => "R_ROLES" | .binding => "R_BINDING" | .invalid => "R_INVALID"

def Meta.cert (m : Meta) (h : Hash) : Option Cert := m.certs.find? (·.id == h)

/-- Valid: issued, not superseded at the admission position, and so are its upstream certificates. -/
def Meta.valid (m : Meta) : Nat → Hash → Bool
  | 0, _ => false
  | fuel + 1, h => match m.cert h with
    | none => false
    | some k => !(m.supersessions.any fun (x, pos) => x == h && decide (pos ≤ m.position)) &&
        k.upstream.all (m.valid fuel ·)

/-- The certificate is for this declaration, dataset, policy, verifier and upstream certificates; it authorizes the
declaration's control columns; and a role provider's attests venue state. -/
def Meta.matches (reg : Registry) (roles : Roles) (m : Meta) (s : Nat) (b : Binding) (k : Cert) : Bool :=
  let d := reg.decls[s]!
  k.decl == d.hash && k.manifest == b.dataset && k.policy == m.policy && k.verifier == m.verifier &&
  (let deps := d.depends.filterMap fun d => (m.bindings d).map (·.cert)
   k.upstream.all (deps.contains ·) && deps.all (k.upstream.contains ·)) &&
  d.controls.all (k.controls.contains ·) &&
  (k.venueState || (s != roles.bars && s != roles.settlement))

/-- Every bound non-evidence source is delivered (version 1 delivers every dataset in the store). -/
def Meta.delivered (reg : Registry) (m : Meta) : List Nat :=
  (List.range reg.decls.size).filter fun s => (m.bindings s).isSome && (reg.decls[s]!).cadence != .evidence

def Meta.required (reg : Registry) (roles : Roles) (p : Program) (m : Meta) : List Nat :=
  reg.closure reg.decls.size (m.delivered reg ++ p.sources ++ [roles.bars, roles.settlement])

/-- Admission stage 1, on metadata only; returns the required set. -/
def stage1 (reg : Registry) (roles : Roles) (p : Program) (m : Meta) (mode : Mode) : Except Abort (List Nat) := do
  if !roles.valid reg then throw .roles
  let req := m.required reg roles p
  if !req.all (fun s => (m.bindings s).isSome) then throw .inputUnavailable
  if mode == .search && !req.all (fun s => (m.bindings s).all (!m.holdout.contains ·.dataset)) then throw .holdout
  if !req.all (fun s => match m.bindings s with
      | none => false
      | some b => (m.cert b.cert).any fun k => m.valid m.certs.length b.cert && m.matches reg roles s b k) then
    throw .uncertified
  return req

/-- Admission stage 2, on event-time columns only (I8). -/
def stage2 (m : Meta) (mode : Mode) (rows : List (Nat × Int)) : Except Abort Unit :=
  if mode == .search && !rows.all (fun r => decide (r.2 < m.holdoutStart)) then throw .holdout else pure ()

/-- A stored cell (RULES.md §6: time-typed columns are integers of ms). -/
inductive Cell where
  | int (i : Int)
  | num (bits : UInt64)
  | str (s : String)
  | bool (b : Bool)
  | null
  deriving DecidableEq, Repr, Inhabited

/-- One stored revision of a key (RULES.md §6): its entity as stored and the coin of U it maps to (`none` outside U),
event time, fetchedAt, tombstone flag and observed columns (never `fetchedAt`, `source`, `hash` or the tombstone
column); for a derived source, per dependency name, the upstream keys (coin, event time) the row was computed from. -/
structure Revision where
  entity : String
  coin : Option Nat
  event : Int
  fetchedAt : Int
  tombstone : Bool
  cells : List (String × Cell)
  upstream : List (String × List (Nat × Int))
  deriving Inhabited

/-- The stored bytes of the datasets as the trusted boundary sees them: per source its revisions, and each dataset's
content identity. -/
structure Stored where
  rows : Nat → List Revision
  identity : Nat → Hash

/-- Two observations of the same shape: declaration, coin, key, slot, knownAt, value count and role kind. -/
def Obs.sameShape {α : Type} (a b : Obs α) : Bool :=
  let kind (r : Option (RolePayload α)) : Nat := match r with | none => 0 | some (.bar ..) => 1 | some (.rate _) => 2
  a.source == b.source && a.coin == b.coin && a.key == b.key && a.slot == b.slot && a.known == b.known &&
  a.vals.size == b.vals.size && kind a.role == kind b.role

end Ref
