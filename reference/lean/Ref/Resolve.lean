import Ref.Source

/-!
The resolver (kernel/RULES.md §5–§6 with its bitemporal revision of 2026-10-26): a checked rule evaluated on a stored
revision, each key's timeline of revisions at a dataset version with their effective knownAt (correction,
replacement and derivation bounds) and retractions, and the resolved observations a run is admitted on. The trusted boundary (`Trusted`) says the implementation's loader computes
exactly this on the stored bytes; the C7.6 suites check that against the Python and Rust resolvers.
-/

namespace Ref

inductive RuleError where | fieldAbsent | fieldType | overflow | unusable
  deriving DecidableEq, Repr

def inRange (x : Int) : Bool := decide (-(2 ^ 62) ≤ x) && decide (x < 2 ^ 62)

def ranged (x : Int) : Except RuleError Int := if inRange x then .ok x else .error .overflow

mutual
/-- A rule's value on a row and the dependencies' times (RULES.md §5): depth-first, left to right, the first rejection
reached is the result. -/
def RuleExpr.eval (row : List (String × Cell)) (deps : List (String × Int)) : RuleExpr → Except RuleError Int
  | .field n => match row.find? (·.1 == n) with
    | none | some (_, .null) => .error .fieldAbsent
    | some (_, .int i) => ranged i
    | some _ => .error .fieldType
  | .dep n => match deps.find? (·.1 == n) with
    | some (_, t) => ranged t
    | none => .error .fieldAbsent
  | .ms n => ranged n
  | .add t d => do let a ← t.eval row deps; let b ← d.eval row deps; ranged (a + b)
  | .floor t p => do let a ← t.eval row deps; let b ← p.eval row deps; ranged (b * Int.fdiv a b)
  | .max xs => do
    let vs ← RuleExpr.evalAll row deps xs
    match vs with
    | [] => .error .unusable
    | v :: rest => .ok (rest.foldl Max.max v)

def RuleExpr.evalAll (row : List (String × Cell)) (deps : List (String × Int)) : List RuleExpr → Except RuleError (List Int)
  | [] => .ok []
  | x :: xs => do let v ← x.eval row deps; let vs ← RuleExpr.evalAll row deps xs; return v :: vs
end

/-- The revisions of one key of a source eligible at version V (fetchedAt ≤ V), in fetchedAt order. -/
def Stored.eligible (st : Stored) (s : Nat) (V : Int) (coin : Nat) (event : Int) : List Revision :=
  ((st.rows s).filter fun r => r.coin == some coin && r.event == event && decide (r.fetchedAt ≤ V)).mergeSort
    fun a b => decide (a.fetchedAt ≤ b.fetchedAt)

/-- The keys of a source within U with an eligible revision, in order of their first eligible stored revision. -/
def Stored.keys (st : Stored) (s : Nat) (V : Int) : List (Nat × Int) :=
  ((st.rows s).filterMap fun r => if decide (r.fetchedAt ≤ V) then r.coin.map (·, r.event) else none).eraseDups

/-- A dataset is invalid if two eligible revisions of one key share a fetchedAt (RULES.md §6), a key being its entity
and event or, inside U, its coin and event; or if an eligible revision's fetchedAt is out of range. -/
def Stored.validAt (st : Stored) (s : Nat) (V : Int) : Bool :=
  let el := (st.rows s).filter fun r => decide (r.fetchedAt ≤ V)
  let ks := el.map fun r => (r.entity, r.event, r.fetchedAt)
  let cs := el.filterMap fun r => r.coin.map (·, r.event, r.fetchedAt)
  ks.eraseDups.length == ks.length && cs.eraseDups.length == cs.length && el.all (inRange ·.fetchedAt)

/-- A column's value as compared for corrections: an absent column is null. -/
def cellAt (cells : List (String × Cell)) (col : String) : Cell := ((cells.find? (·.1 == col)).map (·.2)).getD .null

/-- Equal as values: numbers by value (the two zeros are equal), everything else exactly. -/
def Cell.sameValue : Cell → Cell → Bool
  | .num a, .num b => a == b || (a &&& 0x7FFFFFFFFFFFFFFF == 0 && b &&& 0x7FFFFFFFFFFFFFFF == 0)
  | a, b => a == b

/-- Two revisions differ in one of the declaration's columns (value and control columns other than `fetchedAt` and
the revision and tombstone columns), or in their tombstone flag; undeclared columns are never compared (RULES.md §6,
revision of 2026-10-26, second). -/
def differs (d : Decl) (a b : Revision) : Bool :=
  let cols := (d.values ++ d.controls).eraseDups.filter fun c => !(["fetchedAt"] ++ d.revisionColumns).contains c
  a.tombstone != b.tombstone || cols.any fun c => !(cellAt a.cells c).sameValue (cellAt b.cells c)

/-- One delivered revision of a key: the revision, its knownAt, and whether it retracts the key (a tombstone, or a
revision whose rule evaluation is rejected). -/
structure Entry where
  rev : Revision
  known : Int
  retraction : Bool
  deriving Inhabited

/-- A key's timeline (RULES.md §6, bitemporal revisions of 2026-10-26): its eligible revisions in fetchedAt order. A
revision identical to the one before it adds nothing. The key's first eligible revision is delivered at its rule's
value; every later one, delivered first or not, is known no earlier than its fetchedAt; every one is known no earlier than the one it replaces and than
each dependency's upstream knownAt plus its delay, the upstream deliveries counted being those recorded no later
than the revision itself. A tombstone, or a revision whose rule evaluation is rejected or which `ok` rejects (an
event source's slot or a role payload that does not decode), is delivered as a retraction at its fetchedAt (no
earlier than what it replaces), and never falls back to an older value; one before any delivery adds nothing. -/
def timeline (reg : Registry) (st : Stored) (V : Int) (ok : Nat → Revision → Bool) : Nat → Nat → Nat → Int → List Entry
  | 0, _, _, _ => []
  | fuel + 1, s, coin, event =>
    let d := reg.decls[s]!
    let upKnown (dep : Dep) (c : Nat) (e : Int) (by_ : Int) : Option Int :=
      ((timeline reg st V ok fuel dep.source c e).filter (fun x => !x.retraction && decide (x.rev.fetchedAt ≤ by_))).foldl
        (fun acc x => some (match acc with | some a => Max.max a x.known | none => x.known)) none
    let known (r : Revision) (later : Bool) (prev : Option Int) : Except RuleError Int := do
      if !ok s r then throw .unusable
      let ts ← d.deps.mapM fun dep =>
        let ups := ((r.upstream.find? (·.1 == dep.name)).map (·.2)).getD []
        match ups.filterMap (fun (c, e) => upKnown dep c e r.fetchedAt) with
        | [] => .error .unusable
        | t :: rest => .ok (rest.foldl Max.max t)
      let k ← d.rule.eval (("fetchedAt", .int r.fetchedAt) :: r.cells) (d.deps.map (·.name) |>.zip ts)
      let k ← if later then do let f ← ranged r.fetchedAt; pure (Max.max k f) else pure k
      let k := match prev with | some p => Max.max k p | none => k
      (d.deps.zip ts).foldlM (fun k (dep, t) => do let b ← ranged (t + dep.lag); pure (Max.max k b)) k
    let step (acc : Option Revision × Option Int × List Entry) (r : Revision) :=
      let (last, prev, out) := acc
      if last.any (fun p => !differs d p r) then (some r, prev, out) else
      let retract (k : Int) := (some r, some k, out ++ [⟨r, k, true⟩])
      match prev with
      | none => if r.tombstone then (some r, none, out) else
        match known r last.isSome none with
        | .ok k => (some r, some k, out ++ [⟨r, k, false⟩])
        | .error _ => (some r, none, out)
      | some p => if r.tombstone then retract (Max.max r.fetchedAt p) else
        match known r true (some p) with
        | .ok k => (some r, some k, out ++ [⟨r, k, false⟩])
        | .error _ => retract (Max.max r.fetchedAt p)
    ((st.eligible s V coin event).foldl step (none, none, [])).2.2

/-- The role payload of a revision for its declaration's first role, if its cells decode. -/
def rolePayload {α : Type} (num : Cell → Option α) (d : Decl) (r : Revision) : Option (RolePayload α) :=
  let cell (col : String) := cellAt r.cells col
  match d.roles with
  | [] => none
  | (.bars, cols) :: _ => match cols.map (·.2) with
    | [co, ch, cl, cc, ct] => match num (cell co), num (cell ch), num (cell cl), num (cell cc), cell ct with
      | some o, some h, some l, some c, .int t => some (.bar o h l c t)
      | _, _, _, _, _ => none
    | _ => none
  | (.settlement, cols) :: _ => match cols.map (·.2) with
    | [cr] => (num (cell cr)).map .rate
    | _ => none

/-- An event source's slot as a revision stores it. -/
def slotOf (d : Decl) (r : Revision) : Option Int :=
  d.slotColumn.bind fun col => match cellAt r.cells col with | .int t => some t | _ => none

/-- A revision decodes for its declaration: an event source's slot, and a role provider's payload. -/
def decodes {α : Type} (num : Cell → Option α) (reg : Registry) (s : Nat) (r : Revision) : Bool :=
  let d := reg.decls[s]!
  (d.cadence != .event || (slotOf d r).isSome) && (d.roles.isEmpty || (rolePayload num d r).isSome)

/-- The resolved observations of the requested datasets at version V: every entry of every key's timeline, in order,
with the revision's values (`num` parses a cell as a number), slot (a retraction keeps the slot of what it retracts)
and role payload (none for a retraction), its knownAt and recording time, and whether it is the key's final entry
(execution reads final entries only); `none` if a requested dataset is invalid. -/
def resolveAll {α : Type} (num : Cell → Option α) (reg : Registry) (st : Stored) (V : Int) (req : List Nat) :
    Option (Array (Obs α)) :=
  if !req.all (st.validAt · V) then none else
  some (req.toArray.flatMap fun s =>
    let d := reg.decls[s]!
    (st.keys s V).toArray.flatMap fun (coin, event) =>
      let es := timeline reg st V (decodes num reg) reg.decls.size s coin event
      let step (acc : Option Int × List (Obs α)) (ei : Entry × Nat) :=
        let (e, i) := ei
        let slot := if e.retraction then acc.1 else slotOf d e.rev
        (slot, acc.2 ++ [{ source := s, coin, key := event, known := e.known, slot, recorded := e.rev.fetchedAt
                           role := if e.retraction then none else rolePayload num d e.rev
                           vals := d.fields.map fun f => if e.retraction then none else num (cellAt e.rev.cells f.2.1)
                           final := i + 1 == es.length, retraction := e.retraction }])
      (es.zipIdx.foldl step (none, [])).2.toArray)

/-- The verifier's ledger: the certificates it issued, the supersessions it recorded, and its current position. -/
structure Ledger where
  issued : List Cert
  supersessions : List (Hash × Nat)
  position : Nat

/-- The trusted admission boundary (laws-v2-draft.md §1): what the implementation guarantees outside the model, and
the laws' safety statements assume. Declarations are the ones their hashes name, and stored revisions are decoded
canonically (`declHash` stands for decoding a declaration file); the loader's inventory is the stored revisions'
event times; its resolution is `resolveAll` on the stored bytes at the pinned version (`num`, a cell's parse);
bindings name the bytes' content identities; certificates are issued, their ids their payloads' hashes; supersessions and the admission position are
the ledger's current ones; policy, verifier and holdout are the pinned configuration. The staging obligations
(`rows` opening only the event-time column) are tested, laws-v2-draft.md §2 rows 17 and 18; a provider's
venue-state attestation is the verifier's claim, authenticated through `ids` and `issued`. -/
structure Trusted {α : Type} (num : Cell → Option α) (hash : Cert → Hash) (declHash : Decl → Hash)
    (policy verifier : Hash) (holdout : List Hash) (holdoutStart : Int) (reg : Registry) (st : Stored) (led : Ledger)
    (adm : Meta) (ld : Loader α) : Prop where
  /-- Each declaration, its rule included, is the one its hash names (the declaration file's bytes, decoded). -/
  decls : ∀ s < reg.decls.size, (reg.decls[s]!).hash = declHash reg.decls[s]!
  /-- Stored revisions are decoded canonically: column names unique, reserved names absent. -/
  canonical : ∀ s, ∀ r ∈ st.rows s, (r.cells.map (·.1)).Nodup ∧
    ∀ c ∈ r.cells.map (·.1), c ∉ ["fetchedAt", "source", "hash"] ++ (reg.decls[s]!).revisionColumns
  rows : ∀ req, ld.rows req = req.flatMap fun s => (st.rows s).map fun r => (s, r.event)
  resolve : ∀ req, ld.resolve req = resolveAll num reg st adm.version req
  identity : ∀ s b, adm.bindings s = some b → b.dataset = st.identity s
  ids : ∀ k ∈ adm.certs, k.id = hash k
  issued : ∀ k ∈ adm.certs, k ∈ led.issued
  supersessions : adm.supersessions = led.supersessions
  position : adm.position = led.position
  pinned : adm.policy = policy ∧ adm.verifier = verifier
  frozenHoldout : adm.holdout = holdout ∧ adm.holdoutStart = holdoutStart

end Ref
