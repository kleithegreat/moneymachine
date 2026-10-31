import Ref.Sim
import Std.Data.HashSet.Lemmas

/-! Proved executable replacements, leaving the frozen model intact. `admit` is recompiled here so its
calls use the compiler rewrites; importing a rewrite cannot change an already compiled caller.
The noinline access traversal evaluates the schedule bounds once, outside the observation loop. -/

namespace Ref.Exec

private def dedupLoop {β : Type} [BEq β] [Hashable β]
    (xs : List β) (seen : Std.HashSet β) (acc : List β) : List β :=
  match xs with
  | [] => acc.reverse
  | x :: xs =>
    if seen.contains x then dedupLoop xs seen acc
    else dedupLoop xs (seen.insert x) (x :: acc)

private theorem dedupLoop_eq {β : Type} [BEq β] [LawfulBEq β] [Hashable β] [LawfulHashable β]
    (xs : List β) (seen : Std.HashSet β) (acc : List β)
    (h : ∀ x, seen.contains x = acc.any (x == ·)) :
    dedupLoop xs seen acc = List.eraseDupsBy.loop (· == ·) xs acc := by
  induction xs generalizing seen acc with
  | nil => rfl
  | cons x xs ih =>
    simp only [dedupLoop, List.eraseDupsBy.loop, h x]
    cases acc.any (x == ·) <;> simp only [Bool.false_eq_true, ite_false, ite_true]
    · apply ih
      intro y
      simp [Std.HashSet.contains_insert, h, BEq.comm]
    · exact ih seen acc h

private def dedup {β : Type} [BEq β] [Hashable β] (xs : List β) : List β :=
  dedupLoop xs ∅ []

private theorem dedup_eq {β : Type} [BEq β] [LawfulBEq β] [Hashable β] [LawfulHashable β]
    (xs : List β) : dedup xs = xs.eraseDups := by
  exact dedupLoop_eq xs ∅ [] (by simp)

def admissible {α : Type} (c : Ctx α) : Bool :=
  let keys := (c.obs.toList.filter (·.final)).map fun o => (o.source, o.coin, o.key)
  let capable (o : Obs α) (r : Role) := (c.reg.decls[o.source]!).roles.any (·.1 == r)
  let roleOk (o : Obs α) : Bool := match o.role with
    | none => o.retraction || (c.reg.decls[o.source]!).roles.isEmpty
    | some (.bar ..) => capable o .bars && !o.retraction
    | some (.rate _) => capable o .settlement && !o.retraction
  (dedup keys).length == keys.length &&
  c.obs.all fun o =>
    o.source < c.reg.decls.size && o.coin < c.coins && o.vals.size == (c.reg.decls[o.source]!).fields.size &&
    roleOk o && ((c.reg.decls[o.source]!).cadence == .event) == o.slot.isSome

@[csimp] theorem admissible_eq : @Ctx.admissible = @admissible := by
  funext α c
  simp only [Ctx.admissible, admissible, dedup_eq]
  rfl

@[noinline] private def accesses {α : Type} (c : Ctx α) (first last stop : Int) : List (Nat × Access) :=
  c.obs.toList.flatMap fun o =>
    let delivered := if o.known ≤ last then some (max o.known first) else none
    let executed := (if !o.final then none else match o.role with
      | some (.bar ..) => if o.source == c.roles.bars then some (o.key - BAR) else none
      | some (.rate _) => if o.source == c.roles.settlement then some o.key else none
      | none => none).filter (· < stop)
    let readFrom := match delivered, executed with
      | some a, some b => some (max (min a b) first)
      | some a, none => some (max a first)
      | none, some b => some (max b first)
      | none, none => none
    match readFrom with
    | none => []
    | some t => (c.reg.decls[o.source]!).values.map fun col => (o.source, ⟨o.coin, col, o.key, (t, stop)⟩)

def inScope {α : Type} (c : Ctx α) : Bool :=
  (accesses c c.firstTick c.lastTick c.useEnd).all fun (s, x) => match c.adm.bindings s with
    | none => false
    | some b => (c.adm.cert b.cert).any fun k => k.grants.any (·.covers x)

@[csimp] theorem inScope_eq : @Ctx.inScope = @inScope := by
  rfl

def admit {α : Type} (reg : Registry) (roles : Roles) (p : Program) (adm : Meta)
    (ld : Loader α) (v : Venue α) (pol : Policy) (stop : Int) (mode : Mode) : Except (Nat × Abort) (Ctx α) := do
  let req ← (stage1 reg roles p adm mode).mapError fun e => (e.position, e)
  (stage2 adm mode (ld.rows req)).mapError ((5, ·))
  let some obs := ld.resolve req | throw (6, .binding)
  let c := Ctx.make reg roles p adm obs v pol stop req
  if !c.admissible then throw (6, .binding)
  if !c.inScope then throw (7, .uncertified)
  return c

@[csimp] theorem admit_eq : @Ref.admit = @admit := by
  rfl

end Ref.Exec
