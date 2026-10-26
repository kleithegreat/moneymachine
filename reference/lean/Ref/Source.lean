import Ref.Syntax

/-!
Sources as a language feature (audit/stage7/laws-v2-draft.md §2–§4; SOURCES.md, CERTIFICATES.md, RULES.md §6):
declarations and the registry, resolved observations, certificates, admission metadata, the staged loader, and the
two admission stages that read no payload.
-/

namespace Ref

abbrev Hash := String

inductive Cadence where | held | event | evidence deriving DecidableEq, Repr, Inhabited
inductive Role where | bars | settlement deriving DecidableEq, Repr, Inhabited

/-- One active declaration (SOURCES.md §1): its file's hash, its fields (input name, stored column, unit; in
input-name order), every stored column its availability rule reads (`fetchedAt` included), its event-time, slot
(event sources) and entity columns, the columns that select revisions and mark tombstones, its cadence, its
dependencies (registry indices), and per role it can provide each role column's stored column. -/
structure Decl where
  hash : Hash
  fields : Array (String × String × Dim)
  times : List String
  eventColumn : String
  slotColumn : Option String
  entityColumn : String
  revisionColumns : List String
  cadence : Cadence
  depends : List Nat
  roles : List (Role × List (String × String))
  deriving Inhabited

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
  reg.decls.all (fun d => d.depends.all (· < reg.decls.size)) &&
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

/-- The loader in two stages: `rows` reads only the event-time column of every stored row of the given datasets
(every revision, tombstone and coin); `resolve` runs RULES.md §6 on them. -/
structure Loader (α : Type) where
  rows : List Nat → List (Nat × Int)
  resolve : List Nat → Array (Obs α)

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

/-- The stored bytes of the bound datasets as the trusted boundary sees them: per source, its rows (each row's event
time and its cells), and each dataset's content identity. -/
structure Stored where
  rows : Nat → List (Int × List (String × String))
  identity : Nat → Hash

/-- The verifier's ledger: the certificates it issued, the supersessions it recorded, and its current position. -/
structure Ledger where
  issued : List Cert
  supersessions : List (Hash × Nat)
  position : Nat

/-- A stored cell of a row, by column. -/
def cellOf (row : Int × List (String × String)) (col : String) : Option String := (row.2.find? (·.1 == col)).map (·.2)

/-- Two stores agree on the control columns of the requested datasets: the same rows, event times and control cells,
whatever their value cells. -/
def Stored.sameControls (reg : Registry) (req : List Nat) (a b : Stored) : Prop :=
  ∀ s ∈ req, (a.rows s).length = (b.rows s).length ∧ ∀ i < (a.rows s).length,
    ((a.rows s)[i]!).1 = ((b.rows s)[i]!).1 ∧
    ∀ col ∈ (reg.decls[s]!).controls, cellOf (a.rows s)[i]! col = cellOf (b.rows s)[i]! col

/-- Two observations of the same shape: declaration, coin, key, slot, knownAt, value count and role kind. -/
def Obs.sameShape {α : Type} (a b : Obs α) : Bool :=
  let kind (r : Option (RolePayload α)) : Nat := match r with | none => 0 | some (.bar ..) => 1 | some (.rate _) => 2
  a.source == b.source && a.coin == b.coin && a.key == b.key && a.slot == b.slot && a.known == b.known &&
  a.vals.size == b.vals.size && kind a.role == kind b.role

/-- The role columns' stored names of a declaration for one role, in SOURCES.md §6's order. -/
def Decl.roleCols (d : Decl) (role : Role) : List String :=
  ((d.roles.find? (·.1 == role)).map (·.2.map (·.2))).getD []

/-- The trusted admission boundary (laws-v2-draft.md §1): what the implementation guarantees outside the model, and
the laws' safety statements assume. Its parameters are the external semantics the obligations refer to: `knownAt`,
RULES.md §6's effective availability of a stored row (checked by the C7.6 suite); `value`, `integer` and `time`, a
cell's parse as a number, a count and a timestamp; `coinOf`, the entity mapping; `hash`, the certificate payload hash; `policy` and `verifier`, the build-pinned hashes; and the
frozen holdout configuration. Grants authorize the use of values in a run; decoding a bound dataset's rows during
resolution is authorized by its valid, matching certificate (laws-v2-draft.md §1). The staging obligations (`rows`
opening only the event-time column, `resolve` only bound datasets) are tested, §2 rows 17 and 18. A provider's
venue-state attestation is the verifier's, authenticated through `ids` and `issued`. -/
structure Trusted {α : Type} (knownAt : Stored → Nat → (Int × List (String × String)) → Int) (value : String → Option α)
    (integer time : String → Option Int) (coinOf : String → Option Nat) (hash : Cert → Hash) (policy verifier : Hash) (holdout : List Hash)
    (holdoutStart : Int) (reg : Registry) (resolver : Stored → List Nat → Array (Obs α)) (st : Stored) (led : Ledger)
    (adm : Meta) (ld : Loader α) : Prop where
  rows : ∀ req, ld.rows req = req.flatMap fun s => (st.rows s).map fun r => (s, r.1)
  resolve : ∀ req, ld.resolve req = resolver st req
  /-- The resolver reads only the requested datasets. -/
  confined : ∀ req (st' : Stored), (∀ s ∈ req, st'.rows s = st.rows s) → resolver st' req = resolver st req
  /-- Every observation comes from a stored row of its own requested declaration: its key, entity, slot, values,
  role payload and knownAt are that row's. -/
  provenance : ∀ req, ∀ o ∈ (resolver st req).toList, o.source ∈ req ∧ ∃ row ∈ st.rows o.source,
    let d := reg.decls[o.source]!
    let num (col : String) : Option α := (cellOf row col).bind value
    row.1 = o.key ∧ (cellOf row d.entityColumn).bind coinOf = some o.coin ∧
    o.slot = d.slotColumn.bind (fun col => (cellOf row col).bind time) ∧
    o.known = knownAt st o.source row ∧
    o.vals.toList = d.fields.toList.map (fun f => num f.2.1) ∧
    (match o.role with
     | none => True
     | some (.bar op h l c t) => match d.roleCols .bars with
       | [co, ch, cl, cc, ct] => num co = some op ∧ num ch = some h ∧ num cl = some l ∧ num cc = some c ∧
           (cellOf row ct).bind integer = some t
       | _ => False
     | some (.rate x) => match d.roleCols .settlement with
       | [cr] => num cr = some x
       | _ => False)
  /-- Which rows the resolver selects, how many and in what order, and each one's key, slot, knownAt, coin and role
  kind, depend on the requested datasets' control columns only, never on a value cell. -/
  controlsOnly : ∀ req (st' : Stored), Stored.sameControls reg req st st' →
    (resolver st' req).size = (resolver st req).size ∧
    ∀ i < (resolver st req).size, ((resolver st' req)[i]!).sameShape (resolver st req)[i]! = true
  identity : ∀ s b, adm.bindings s = some b → b.dataset = st.identity s
  ids : ∀ k ∈ adm.certs, k.id = hash k
  issued : ∀ k ∈ adm.certs, k ∈ led.issued
  supersessions : adm.supersessions = led.supersessions
  /-- A new evaluation is admitted at the ledger's current position. -/
  position : adm.position = led.position
  pinned : adm.policy = policy ∧ adm.verifier = verifier
  frozenHoldout : adm.holdout = holdout ∧ adm.holdoutStart = holdoutStart

end Ref
