import Engine.Machine

namespace Engine.Machine

theorem Rows.append_empty (r : Rows) : r ++ Rows.empty = r := by
  cases r with
  | mk a b => show (⟨a ++ "", b ++ ""⟩ : Rows) = ⟨a, b⟩; simp

theorem Rows.empty_append (r : Rows) : Rows.empty ++ r = r := by
  cases r with
  | mk a b => show (⟨"" ++ a, "" ++ b⟩ : Rows) = ⟨a, b⟩; simp

theorem Rows.append_assoc (a b c : Rows) : a ++ b ++ c = a ++ (b ++ c) := by
  cases a with
  | mk a1 a2 => cases b with
    | mk b1 b2 => cases c with
      | mk c1 c2 => show (⟨a1 ++ b1 ++ c1, a2 ++ b2 ++ c2⟩ : Rows) = ⟨a1 ++ (b1 ++ c1), a2 ++ (b2 ++ c2)⟩; simp [String.append_assoc]

theorem release_cfg (s : State) (t : Int) : (release s t).cfg = s.cfg := by
  simp [release]

theorem tickAt_cfg (s : State) (t : Int) : (tickAt s t).1.cfg = s.cfg := by
  simp [tickAt, release_cfg]

theorem fireRec_cfg (n : Nat) (s : State) (acc : Rows) (recs : List TickRecord) :
    (fireRec n s acc recs).1.cfg = s.cfg := by
  induction n generalizing s acc recs with
  | zero => simp [fireRec]
  | succ n ih =>
    simp only [fireRec]
    split
    · rename_i time ms _
      rw [ih]
      simp [tickAt_cfg]
    · rfl

theorem fireN_cfg (n : Nat) (s : State) (acc : Rows) : (fireN n s acc).1.cfg = s.cfg := by
  simp [fireN, fireRec_cfg]

theorem withPending_cfg (s : State) (e : Event) (w : PView) : (withPending s e w).cfg = s.cfg := by
  unfold withPending
  split <;> rfl

theorem applyPayload_cfg (s : State) (e : Event) : (applyPayload s e).1.cfg = s.cfg := by
  unfold applyPayload
  split <;> simp [withPending_cfg]

theorem advance_cfg (s : State) (e : Event) : (advance s e).1.cfg = s.cfg := by
  unfold advance advanceRec
  simp [fireN_cfg, fireRec_cfg, applyPayload_cfg]

theorem reject_cfg (s : State) (c : String) (t : Int) (d : String) : (s.reject c t d).cfg = s.cfg := rfl

theorem step_cfg (s : State) (e : Event) : (step s e).1.cfg = s.cfg := by
  unfold step
  split
  · rfl
  · split
    · rfl
    · exact advance_cfg s e

theorem go_cfg (es : List Event) : ∀ s : State, (go s es).1.cfg = s.cfg := by
  induction es with
  | nil => intro s; rfl
  | cons e es ih => intro s; simp only [go]; rw [ih, step_cfg]

theorem step_rejected (s : State) (f : Fault) (h : s.rejected = some f) (e : Event) :
    step s e = (s, Rows.empty) := by
  simp [step, h]

theorem go_rejected (s : State) (f : Fault) (h : s.rejected = some f) (es : List Event) :
    go s es = (s, Rows.empty) := by
  induction es with
  | nil => rfl
  | cons e es ih => simp [go, step_rejected s f h, ih, Rows.empty_append]

theorem step_rejected_keeps (s : State) (e : Event) (h : s.rejected.isSome) :
    (step s e).1.rejected.isSome := by
  cases hr : s.rejected with
  | none => simp [hr] at h
  | some f => rw [step_rejected s f hr]; simp [hr]

theorem go_append (a b : List Event) : ∀ s : State,
    go s (a ++ b) = ((go (go s a).1 b).1, (go s a).2 ++ (go (go s a).1 b).2) := by
  induction a with
  | nil => intro s; simp [go, Rows.empty_append]
  | cons e a ih =>
    intro s
    simp only [List.cons_append, go]
    rw [ih]
    simp [Rows.append_assoc]

theorem feed_eq_go (s : State) (c : Chunk) (events : List Event)
    (h : decodeChunk s c = .ok events) : feed s c = go s events := by
  unfold feed
  cases hr : s.rejected with
  | none => simp [h]
  | some f => simp [go_rejected s f hr]

theorem decode_cfg (s t : State) (hc : t.cfg = s.cfg) (c : Chunk) : decodeChunk t c = decodeChunk s c := by
  simp [decodeChunk, hc]

theorem fold_parts (initial : State) (parts : List (List Event))
    (h1 : ∀ events ∈ parts, decodeChunk initial (pack events) = .ok events) :
    ∀ (s : State) (acc : Rows), s.cfg = initial.cfg →
      parts.foldl (fun (acc : State × Rows) events =>
        let next := feed acc.1 (pack events)
        (next.1, { report := acc.2.report ++ next.2.report, trace := acc.2.trace ++ next.2.trace }))
        (s, acc) = ((go s parts.flatten).1, acc ++ (go s parts.flatten).2) := by
  induction parts with
  | nil => intro s acc _; simp [go, List.foldl, Rows.append_empty]
  | cons events parts ih =>
    intro s acc hcfg
    have hd : decodeChunk s (pack events) = .ok events := by
      rw [decode_cfg initial s hcfg]; exact h1 events (List.mem_cons_self ..)
    have hrest : ∀ ev ∈ parts, decodeChunk initial (pack ev) = .ok ev :=
      fun ev hev => h1 ev (List.mem_cons_of_mem _ hev)
    simp only [List.foldl_cons, List.flatten_cons]
    rw [feed_eq_go s _ events hd]
    have := ih hrest (go s events).1 (acc ++ (go s events).2) (by rw [go_cfg, hcfg])
    show _ = _
    rw [show ({ report := acc.report ++ (go s events).2.report, trace := acc.trace ++ (go s events).2.trace } : Rows)
      = acc ++ (go s events).2 from rfl]
    rw [this, go_append events parts.flatten s]
    simp [Rows.append_assoc]

theorem c1_general (initial : State) (parts : List (List Event))
    (h1 : ∀ events ∈ parts, decodeChunk initial (pack events) = .ok events)
    (hw : decodeChunk initial (pack parts.flatten) = .ok parts.flatten) :
    let empty : Rows := { report := "", trace := "" }
    let folded := parts.foldl (fun (acc : State × Rows) events =>
      let next := feed acc.1 (pack events)
      (next.1, { report := acc.2.report ++ next.2.report, trace := acc.2.trace ++ next.2.trace })) (initial, empty)
    let whole := feed initial (pack parts.flatten)
    folded.1 = whole.1 ∧
    (let finalParts := finish folded.1
     let finalWhole := finish whole.1
     finalParts.2 = finalWhole.2 ∧
     folded.2.report ++ finalParts.1.report = whole.2.report ++ finalWhole.1.report ∧
     folded.2.trace ++ finalParts.1.trace = whole.2.trace ++ finalWhole.1.trace) := by
  intro empty folded whole
  have hf : folded = ((go initial parts.flatten).1, empty ++ (go initial parts.flatten).2) :=
    fold_parts initial parts h1 initial empty rfl
  have hwhole : whole = go initial parts.flatten := feed_eq_go initial _ _ hw
  have e1 : folded.1 = whole.1 := by rw [hf, hwhole]
  have e2 : folded.2 = whole.2 := by
    rw [hf, hwhole]
    show Rows.empty ++ _ = _
    exact Rows.empty_append _
  refine ⟨e1, ?_⟩
  intro finalParts finalWhole
  have hfin : finalParts = finalWhole := by simp only [finalParts, finalWhole, e1]
  refine ⟨by rw [hfin], ?_, ?_⟩
  · rw [hfin, e2]
  · rw [hfin, e2]

end Engine.Machine
