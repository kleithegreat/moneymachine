import Ref.Source

/-!
The resolver (kernel/RULES.md §5–§6): a checked rule evaluated on a stored revision, the selection of each key's
revision at a dataset version, its effective knownAt with the correction and derivation bounds, and the resolved
observations a run is admitted on. The trusted boundary (`Trusted`) says the implementation's loader computes
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

/-- The revisions of one key of a source eligible at version V (fetchedAt ≤ V), in stored order. -/
def Stored.eligible (st : Stored) (s : Nat) (V : Int) (coin : Nat) (event : Int) : List Revision :=
  (st.rows s).filter fun r => r.coin == some coin && r.event == event && decide (r.fetchedAt ≤ V)

/-- The keys of a source within U, in order of first stored appearance. -/
def Stored.keys (st : Stored) (s : Nat) : List (Nat × Int) :=
  ((st.rows s).filterMap fun r => r.coin.map (·, r.event)).eraseDups

/-- A dataset is invalid if two eligible revisions of one key share a fetchedAt (RULES.md §6). -/
def Stored.validAt (st : Stored) (s : Nat) (V : Int) : Bool :=
  (st.keys s).all fun (c, e) =>
    let fs := (st.eligible s V c e).map (·.fetchedAt)
    fs.eraseDups.length == fs.length

/-- The selected revision of a key: the eligible one with the largest fetchedAt; `none` if no revision is eligible or
the selected one is a tombstone. With it, the key's earliest eligible revision. -/
def Stored.select (st : Stored) (s : Nat) (V : Int) (coin : Nat) (event : Int) : Option (Revision × Revision) :=
  match st.eligible s V coin event with
  | [] => none
  | r :: rs =>
    let sel := rs.foldl (fun a b => if a.fetchedAt < b.fetchedAt then b else a) r
    let first := rs.foldl (fun a b => if b.fetchedAt < a.fetchedAt then b else a) r
    if sel.tombstone then none else some (sel, first)

/-- A column's value as compared for corrections: an absent column is null. -/
def cellAt (cells : List (String × Cell)) (col : String) : Cell := ((cells.find? (·.1 == col)).map (·.2)).getD .null

/-- The selected revision differs from the key's earliest in some observed column: a correction. -/
def isCorrection (sel first : Revision) : Bool :=
  let cols := (sel.cells.map (·.1) ++ first.cells.map (·.1)).eraseDups
  cols.any fun c => cellAt sel.cells c != cellAt first.cells c

/-- The effective knownAt of a key's selected revision (RULES.md §6): the rule's value on its row (with `fetchedAt`),
raised to its fetchedAt if it is a correction and to every dependency's latest upstream knownAt plus its delay; a
dependency with no usable upstream knownAt makes the row unusable. `none` when the key has no observation. -/
def effectiveKnown (reg : Registry) (st : Stored) (V : Int) : Nat → Nat → Nat → Int → Option (Except RuleError Int)
  | 0, _, _, _ => some (.error .unusable)
  | fuel + 1, s, coin, event => do
    let (sel, first) ← st.select s V coin event
    let d := reg.decls[s]!
    let deps : Except RuleError (List (String × Int)) := d.deps.mapM fun dep =>
      let ups := ((sel.upstream.find? (·.1 == dep.name)).map (·.2)).getD []
      let times := ups.filterMap fun (c, e) => match effectiveKnown reg st V fuel dep.source c e with
        | some (.ok t) => some t
        | _ => none
      match times with
      | [] => .error .unusable
      | t :: ts => .ok (dep.name, ts.foldl Max.max t)
    return do
      let ds ← deps
      let k ← d.rule.eval (sel.cells ++ [("fetchedAt", .int sel.fetchedAt)]) ds
      let k := if isCorrection sel first then Max.max k sel.fetchedAt else k
      let k ← d.deps.foldlM (fun k dep => do
        let t := ((ds.find? (·.1 == dep.name)).map (·.2)).getD k
        ranged (Max.max k (t + dep.lag))) k
      ranged k

/-- The resolved observations of the requested datasets at version V: per key with an observation whose rule
evaluation succeeded, the selected revision's values (`num` parses a cell as a number), slot, role payload and
effective knownAt; `none` if a requested dataset is invalid. -/
def resolveAll {α : Type} (num : Cell → Option α) (reg : Registry) (st : Stored) (V : Int) (req : List Nat) :
    Option (Array (Obs α)) :=
  if !req.all (st.validAt · V) then none else
  some (req.toArray.flatMap fun s =>
    let d := reg.decls[s]!
    (st.keys s).toArray.filterMap fun (coin, event) => do
      let (sel, _) ← st.select s V coin event
      let .ok known ← effectiveKnown reg st V reg.decls.size s coin event | none
      let cell (col : String) := cellAt sel.cells col
      let roleNum (col : String) := num (cell col)
      let role : Option (RolePayload α) := match d.roles with
        | [] => none
        | (.bars, cols) :: _ => match cols.map (·.2) with
          | [co, ch, cl, cc, ct] => match roleNum co, roleNum ch, roleNum cl, roleNum cc, cell ct with
            | some o, some h, some l, some c, .int t => some (.bar o h l c t)
            | _, _, _, _, _ => none
          | _ => none
        | (.settlement, cols) :: _ => match cols.map (·.2) with
          | [cr] => (roleNum cr).map .rate
          | _ => none
      return { source := s, coin, key := event, known, role
               slot := d.slotColumn.bind fun col => match cell col with | .int t => some t | _ => none
               vals := d.fields.map fun f => num (cell f.2.1) })

/-- The verifier's ledger: the certificates it issued, the supersessions it recorded, and its current position. -/
structure Ledger where
  issued : List Cert
  supersessions : List (Hash × Nat)
  position : Nat

/-- The trusted admission boundary (laws-v2-draft.md §1): what the implementation guarantees outside the model, and
the laws' safety statements assume. The loader's inventory is the stored revisions' event times; its resolution is
`resolveAll` on the stored bytes at the pinned version (`num`, a cell's parse); bindings name the bytes' content
identities; certificates are issued, their ids their payloads' hashes; supersessions and the admission position are
the ledger's current ones; policy, verifier and holdout are the pinned configuration. The staging obligations
(`rows` opening only the event-time column) are tested, laws-v2-draft.md §2 rows 17 and 18; a provider's
venue-state attestation is the verifier's claim, authenticated through `ids` and `issued`. -/
structure Trusted {α : Type} (num : Cell → Option α) (hash : Cert → Hash) (policy verifier : Hash)
    (holdout : List Hash) (holdoutStart : Int) (reg : Registry) (st : Stored) (led : Ledger) (adm : Meta)
    (ld : Loader α) : Prop where
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
