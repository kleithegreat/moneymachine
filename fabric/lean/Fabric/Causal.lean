namespace Fabric

/-- Temporal polarity separating realized observations from forecasts and schedules. -/
inductive Polarity where
  | obs
  | fcst
  | sched
  deriving DecidableEq, Repr

/-- Revision lifecycle matching `core.fact_observations.revision_state`. -/
inductive RevisionState where
  | original
  | restated
  | retracted
  deriving DecidableEq, Repr

/-- Natural key identifying a bitemporal observation series point. -/
structure ObsKey where
  entity : String
  source : String
  metric : String
  eventTime : Nat
  deriving DecidableEq, Repr

/-- Bitemporal observation record. -/
structure Obs where
  key : ObsKey
  knownAt : Nat
  revisionId : Nat
  obsId : Nat
  state : RevisionState
  polarity : Polarity
  quality : Nat
  license : String
  deriving DecidableEq, Repr

/-- Scoped read-only visibility specification for an experiment pod. -/
structure PodView where
  allowedSources : Option (List String)
  allowedLicenses : Option (List String)
  minQuality : Nat
  polarityFilter : Option Polarity
  deriving DecidableEq, Repr

def inOptList (xs? : Option (List String)) (x : String) : Bool :=
  match xs? with
  | none => true
  | some xs => xs.contains x

def polarityMatches (p? : Option Polarity) (p : Polarity) : Bool :=
  match p? with
  | none => true
  | some target => decide (p = target)

/-- Pod view admission predicate over source, license, quality, and polarity. -/
def admits (view : PodView) (o : Obs) : Bool :=
  inOptList view.allowedSources o.key.source &&
  inOptList view.allowedLicenses o.license &&
  decide (view.minQuality ≤ o.quality) &&
  polarityMatches view.polarityFilter o.polarity

/-- Total preference order `(knownAt, revisionId, obsId)` matching SQL `core.pit_latest`. -/
def ranksHigher (cand cur : Obs) : Bool :=
  if cur.knownAt < cand.knownAt then true
  else if cand.knownAt < cur.knownAt then false
  else if cur.revisionId < cand.revisionId then true
  else if cand.revisionId < cur.revisionId then false
  else cur.obsId < cand.obsId

def pickBetter (cand : Obs) : Option Obs → Option Obs
  | none => some cand
  | some cur => if ranksHigher cand cur then some cand else some cur

/-- Select the highest-ranked revision for `key` visible under `view` at `knownAt ≤ asOf`. -/
def latestRevision (rows : List Obs) (view : PodView) (asOf : Nat) (key : ObsKey) : Option Obs :=
  match rows with
  | [] => none
  | o :: rest =>
    let tail := latestRevision rest view asOf key
    if o.key == key && decide (o.knownAt ≤ asOf) && admits view o then
      pickBetter o tail
    else
      tail

/-- Exclude `retracted` ONLY AFTER selecting the latest revision so earlier vintages stay hidden. -/
def pitLatest (rows : List Obs) (view : PodView) (asOf : Nat) (key : ObsKey) : Option Obs :=
  match latestRevision rows view asOf key with
  | none => none
  | some o => if o.state == .retracted then none else some o

def asofCandidateValid (allRows : List Obs) (view : PodView) (asOf leftEventTime : Nat) (r : Obs) : Bool :=
  decide (r.key.eventTime ≤ leftEventTime) &&
  match pitLatest allRows view asOf r.key with
  | none => false
  | some winner => decide (winner = r)

def pickAsof (cand : Obs) : Option Obs → Option Obs
  | none => some cand
  | some cur => if cur.key.eventTime < cand.key.eventTime then some cand else some cur

def asofFold (allRows remaining : List Obs) (view : PodView) (asOf leftEventTime : Nat) : Option Obs :=
  match remaining with
  | [] => none
  | r :: rest =>
    let tail := asofFold allRows rest view asOf leftEventTime
    if asofCandidateValid allRows view asOf leftEventTime r then pickAsof r tail else tail

/-- Bitemporal ASOF join right-hand match: latest visible non-retracted row with `eventTime ≤ leftEventTime`. -/
def asofMatch (rightRows : List Obs) (view : PodView) (asOf leftEventTime : Nat) : Option Obs :=
  asofFold rightRows rightRows view asOf leftEventTime

private theorem pickBetter_mem_or {cand o : Obs} {tail : Option Obs}
    (h : pickBetter cand tail = some o) :
    o = cand ∨ ∃ cur, tail = some cur ∧ o = cur := by
  cases tail with
  | none =>
    simp [pickBetter] at h
    exact Or.inl h.symm
  | some cur =>
    simp only [pickBetter] at h
    by_cases hr : ranksHigher cand cur = true
    · simp [hr] at h
      exact Or.inl h.symm
    · simp [hr] at h
      exact Or.inr ⟨cur, rfl, h.symm⟩

/-- Every record returned by `latestRevision` matches `key`, satisfies `knownAt ≤ asOf`, and passes `admits`. -/
theorem latestRevision_spec (rows : List Obs) (view : PodView) (asOf : Nat) (key : ObsKey) {o : Obs}
    (h : latestRevision rows view asOf key = some o) :
    o.key = key ∧ o.knownAt ≤ asOf ∧ admits view o = true ∧ o ∈ rows := by
  induction rows with
  | nil =>
    simp [latestRevision] at h
  | cons x rest ih =>
    simp only [latestRevision] at h
    by_cases hm : (x.key == key && decide (x.knownAt ≤ asOf) && admits view x) = true
    · simp only [hm, ↓reduceIte] at h
      have h' := hm
      simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at h'
      rcases h' with ⟨⟨hxk, hxt⟩, hxa⟩
      cases pickBetter_mem_or h with
      | inl heq =>
        subst heq
        exact ⟨hxk, hxt, hxa, List.Mem.head rest⟩
      | inr hcur =>
        rcases hcur with ⟨cur, htail, heq⟩
        subst heq
        rcases ih htail with ⟨hck, hct, hca, hcm⟩
        exact ⟨hck, hct, hca, List.Mem.tail x hcm⟩
    · simp only [hm, Bool.false_eq_true, ↓reduceIte] at h
      rcases ih h with ⟨hck, hct, hca, hcm⟩
      exact ⟨hck, hct, hca, List.Mem.tail x hcm⟩

/-- Point-in-time results never leak future `knownAt`, never return retractions, and honor `PodView`. -/
theorem pitLatest_causal (rows : List Obs) (view : PodView) (asOf : Nat) (key : ObsKey) {o : Obs}
    (h : pitLatest rows view asOf key = some o) :
    o.knownAt ≤ asOf ∧ o.state ≠ .retracted ∧ admits view o = true ∧ o ∈ rows := by
  simp only [pitLatest] at h
  cases hlat : latestRevision rows view asOf key with
  | none =>
    simp [hlat] at h
  | some best =>
    simp only [hlat] at h
    by_cases hret : (best.state == .retracted) = true
    · simp [hret] at h
    · simp only [hret, Bool.false_eq_true, ↓reduceIte, Option.some.injEq] at h
      subst h
      rcases latestRevision_spec rows view asOf key hlat with ⟨_, hk, hadm, hmem⟩
      have hne : best.state ≠ .retracted := by
        intro heq
        apply hret
        simp [heq]
      exact ⟨hk, hne, hadm, hmem⟩

/-- If the latest revision as of `asOf` is `.retracted`, earlier vintages are never resurrected. -/
theorem pitLatest_no_resurrection (rows : List Obs) (view : PodView) (asOf : Nat) (key : ObsKey) {o : Obs}
    (hlat : latestRevision rows view asOf key = some o)
    (hret : o.state = .retracted) :
    pitLatest rows view asOf key = none := by
  simp [pitLatest, hlat, hret]

theorem latestRevision_future_invariant (future : Obs) (rows : List Obs) (view : PodView) (asOf : Nat) (key : ObsKey)
    (hfut : asOf < future.knownAt) :
    latestRevision (future :: rows) view asOf key = latestRevision rows view asOf key := by
  have hle : ¬(future.knownAt ≤ asOf) := Nat.not_le_of_gt hfut
  have hcond : (future.key == key && decide (future.knownAt ≤ asOf) && admits view future) = false := by
    simp [hle]
  simp [latestRevision, hcond]

/-- Prepending any future-known record (`knownAt > asOf`) leaves `pitLatest` bit-identical. -/
theorem pitLatest_future_invariant (future : Obs) (rows : List Obs) (view : PodView) (asOf : Nat) (key : ObsKey)
    (hfut : asOf < future.knownAt) :
    pitLatest (future :: rows) view asOf key = pitLatest rows view asOf key := by
  simp [pitLatest, latestRevision_future_invariant future rows view asOf key hfut]

/-- When all `.obs` rows satisfy `eventTime ≤ knownAt`, no `pitLatest` `.obs` row can have `eventTime > asOf`. -/
theorem pitLatest_obs_event_le_asOf (rows : List Obs) (view : PodView) (asOf : Nat) (key : ObsKey) {o : Obs}
    (hobs : ∀ r ∈ rows, r.polarity = .obs → r.key.eventTime ≤ r.knownAt)
    (hp : pitLatest rows view asOf key = some o)
    (hpol : o.polarity = .obs) :
    o.key.eventTime ≤ asOf := by
  rcases pitLatest_causal rows view asOf key hp with ⟨hk, _, _, hmem⟩
  exact Nat.le_trans (hobs o hmem hpol) hk

private theorem pickAsof_prop {P : Obs → Prop} {cand : Obs} {tail : Option Obs} {r : Obs}
    (hc : P cand)
    (ht : ∀ cur, tail = some cur → P cur)
    (h : pickAsof cand tail = some r) :
    P r := by
  cases tail with
  | none =>
    simp [pickAsof] at h
    subst h
    exact hc
  | some cur =>
    simp only [pickAsof] at h
    by_cases hlt : cur.key.eventTime < cand.key.eventTime
    · simp [hlt] at h
      subst h
      exact hc
    · simp [hlt] at h
      subst h
      exact ht cur rfl

private theorem asofFold_valid (allRows rem : List Obs) (view : PodView) (asOf leftEventTime : Nat) {r : Obs}
    (h : asofFold allRows rem view asOf leftEventTime = some r) :
    asofCandidateValid allRows view asOf leftEventTime r = true := by
  induction rem generalizing r with
  | nil =>
    simp [asofFold] at h
  | cons x rest ih =>
    simp only [asofFold] at h
    by_cases hv : asofCandidateValid allRows view asOf leftEventTime x = true
    · simp only [hv, ↓reduceIte] at h
      exact pickAsof_prop hv (fun _ htail => ih htail) h
    · simp only [hv, Bool.false_eq_true, ↓reduceIte] at h
      exact ih h

/-- Any `asofMatch` result satisfies `eventTime ≤ leftEventTime`, `knownAt ≤ asOf`, and `state ≠ .retracted`. -/
theorem asofMatch_causal (rightRows : List Obs) (view : PodView) (asOf leftEventTime : Nat) {r : Obs}
    (h : asofMatch rightRows view asOf leftEventTime = some r) :
    r.key.eventTime ≤ leftEventTime ∧ r.knownAt ≤ asOf ∧ r.state ≠ .retracted ∧ admits view r = true := by
  have hv := asofFold_valid rightRows rightRows view asOf leftEventTime h
  simp only [asofCandidateValid, Bool.and_eq_true, decide_eq_true_eq] at hv
  rcases hv with ⟨hev, hmatch⟩
  cases hpit : pitLatest rightRows view asOf r.key with
  | none =>
    simp [hpit] at hmatch
  | some winner =>
    simp only [hpit, decide_eq_true_eq] at hmatch
    subst hmatch
    rcases pitLatest_causal rightRows view asOf winner.key hpit with ⟨hk, hne, hadm, _⟩
    exact ⟨hev, hk, hne, hadm⟩

/-- Tightening a `PodView` never admits a row that the looser view rejected. -/
theorem podView_admits_monotone (tight loose : PodView) (o : Obs)
    (hsrc : inOptList tight.allowedSources o.key.source = true → inOptList loose.allowedSources o.key.source = true)
    (hlic : inOptList tight.allowedLicenses o.license = true → inOptList loose.allowedLicenses o.license = true)
    (hqual : loose.minQuality ≤ tight.minQuality)
    (hpol : polarityMatches tight.polarityFilter o.polarity = true → polarityMatches loose.polarityFilter o.polarity = true)
    (ht : admits tight o = true) :
    admits loose o = true := by
  simp only [admits, Bool.and_eq_true, decide_eq_true_eq] at ht ⊢
  rcases ht with ⟨⟨⟨hs, hl⟩, hq⟩, hp⟩
  exact ⟨⟨⟨hsrc hs, hlic hl⟩, Nat.le_trans hqual hq⟩, hpol hp⟩

theorem podView_reject_preserved (tight loose : PodView) (o : Obs)
    (hsrc : inOptList tight.allowedSources o.key.source = true → inOptList loose.allowedSources o.key.source = true)
    (hlic : inOptList tight.allowedLicenses o.license = true → inOptList loose.allowedLicenses o.license = true)
    (hqual : loose.minQuality ≤ tight.minQuality)
    (hpol : polarityMatches tight.polarityFilter o.polarity = true → polarityMatches loose.polarityFilter o.polarity = true)
    (hrej : admits loose o = false) :
    admits tight o = false := by
  cases ht : admits tight o with
  | false => rfl
  | true =>
    have hl := podView_admits_monotone tight loose o hsrc hlic hqual hpol ht
    simp [hrej] at hl

end Fabric
