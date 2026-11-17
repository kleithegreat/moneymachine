import Engine.Lang.RewriteProofs
import Engine.Lang.RewriteTypes

/-!
# L3: every rule keeps a program's values (B3)
-/

namespace Engine.Lang

variable {α : Type} (N : NumOps α)

theorem op_typing {p : Program} (hwf : p.WF) {i : Nat} (hi : i < p.nodes.size) {o : Op} {args : List Nat}
    (hn : p.nodes[i]! = .op o args) :
    (∀ a ∈ args, a < i) ∧ opTy o (args.map (p.types[·]!)) = some p.types[i]! :=
  (nodeOkb_op hn).1 ((wf_iff.1 hwf).2.2.1 i hi)

theorem const_typing {p : Program} (hwf : p.WF) {j : Nat} (hj : j < p.nodes.size) {b : UInt64} {u : Dim}
    (hn : p.nodes[j]! = .const b u) : p.types[j]! = .num u := by
  have := (wf_iff.1 hwf).2.2.1 j hj
  simpa [Program.nodeOkb, hn] using this

theorem lt_of_op {p : Program} {i : Nat} {o : Op} {args : List Nat} (hn : p.nodes[i]! = .op o args) :
    i < p.nodes.size := by
  by_cases hc : i < p.nodes.size
  · exact hc
  · rw [getElem!_neg p.nodes i hc] at hn
    exact absurd hn (by intro h; cases h)

/-- A float or bool operator's node is not typed exact. -/
theorem op_not_exact {p : Program} (hwf : p.WF) {i : Nat} (hi : i < p.nodes.size) {o : Op} {args : List Nat}
    (hn : p.nodes[i]! = .op o args) (ho : o.exactValued = false) : ∀ u, p.types[i]! ≠ Ty.exact u := by
  intro u hu
  have h := (op_typing hwf hi hn).2
  rw [hu] at h
  rcases opTy_kind h with ⟨h1, _⟩ | ⟨_, hk⟩
  · rw [ho] at h1; simp at h1
  · rcases hk with hk | ⟨v, hv⟩
    · simp at hk
    · simp at hv

/-- A rule at a float or bool node needs the number type to be lawful: the other branch of L3's premise is a node
typed exact, which no such operator is. -/
theorem lawful_of {p : Program} (hwf : p.WF) {i : Nat} (hi : i < p.nodes.size) {o : Op} {args : List Nat}
    (hn : p.nodes[i]! = .op o args) (ho : o.exactValued = false)
    (h : N.Lawful ∨ ∃ u, p.types[i]? = some (.exact u)) : N.Lawful := by
  rcases h with h | ⟨u, hu⟩
  · exact h
  · exfalso
    apply op_not_exact hwf hi hn ho u
    rw [getElem?_pos p.types i (by rw [(wf_iff.1 hwf).1]; exact hi)] at hu
    rw [getElem!_pos p.types i (by rw [(wf_iff.1 hwf).1]; exact hi)]
    exact Option.some.inj hu

theorem rewrite_sound (r : Rule) {p p' : Program} {i : Nat} (hLE : N.Lawful ∨ ∃ u, p.types[i]? = some (.exact u))
    (hwf : p.WF) (h : r.apply p i = some p') : RewriteConclusion N p p' := by
  have hp := wf_ordered hwf
  unfold Rule.apply at h
  split at h
  · rename_i _ a hn
    have hi := lt_of_op hn
    have hL := lawful_of N hwf hi hn rfl hLE
    split at h
    · rename_i x hna
      injection h with h; subst h
      have hai : a < i := hp i hi a (by rw [hn]; simp [Node.args])
      have hxa : x < a := hp a (by omega) x (by rw [hna]; simp [Node.args])
      have t1 := (op_typing hwf hi hn).2
      have t2 := (op_typing hwf (by omega) hna).2
      simp only [List.map_cons, List.map_nil] at t1 t2
      have e1 := (opTy_unary_num (Or.inl rfl) t1).1
      have e2 := (opTy_unary_num (Or.inl rfl) t2).1
      refine redirect_final N hwf (by omega) hi (by rw [e1, e2]) (op_not_exact hwf hi hn rfl) ?_
      exact fun t m => sem_negNeg N hp hL hi hn hna t m
    · simp at h
  · rename_i _ a hn
    have hi := lt_of_op hn
    have hL := lawful_of N hwf hi hn rfl hLE
    split at h
    · rename_i y hna
      injection h with h; subst h
      have hai : a < i := hp i hi a (by rw [hn]; simp [Node.args])
      have t1 := (op_typing hwf hi hn).2
      simp only [List.map_cons, List.map_nil] at t1
      have e1 := (opTy_unary_num (Or.inr rfl) t1).1
      refine redirect_final N hwf hai hi e1.symm (op_not_exact hwf hi hn rfl) ?_
      exact fun t m => sem_absAbs N hp hL hi hn hna t m
    · simp at h
  · rename_i _ a hn
    have hi := lt_of_op hn
    have hL := lawful_of N hwf hi hn rfl hLE
    split at h
    · rename_i x hna
      injection h with h; subst h
      have hai : a < i := hp i hi a (by rw [hn]; simp [Node.args])
      have hxa : x < a := hp a (by omega) x (by rw [hna]; simp [Node.args])
      have t1 := (op_typing hwf hi hn).2
      have t2 := (op_typing hwf (by omega) hna).2
      simp only [List.map_cons, List.map_nil] at t1 t2
      have e2 := (opTy_unary_num (Or.inl rfl) t2).1
      refine replace_final N hwf hi .abs [x] (by simp; omega) ?_ (by simp [Node.plain])
        (by rw [hn]; simp [Node.plain])
        (by simp [Node.exactFree, Op.exactValued]) (by rw [hn]; simp [Node.exactFree, Op.exactValued]) ?_
      · simp only [List.map_cons, List.map_nil]
        rw [← e2]; exact t1
      · exact fun t m => hnode_absNeg N hp hL hi hn hna t m
    · simp at h
  · -- mulOne
    rename_i _ x cc hn
    have hi := lt_of_op hn
    have hL := lawful_of N hwf hi hn rfl hLE
    split at h
    · rename_i hc
      injection h with h; subst h
      have hc' : p.nodes[cc]! = .const 0x3FF0000000000000 Dim.one := by simpa [Program.isConst] using hc
      have hxi : x < i := hp i hi x (by rw [hn]; simp [Node.args])
      have hcc : cc < i := hp i hi cc (by rw [hn]; simp [Node.args])
      have t1 := (op_typing hwf hi hn).2
      simp only [List.map_cons, List.map_nil, const_typing hwf (by omega) hc'] at t1
      refine redirect_final N hwf hxi hi (opTy_mul_one t1).1.symm (op_not_exact hwf hi hn rfl) ?_
      exact fun t m => sem_mulOne N hp hL hi hn hc' t m
    · simp at h
  · -- divOne
    rename_i _ x cc hn
    have hi := lt_of_op hn
    have hL := lawful_of N hwf hi hn rfl hLE
    split at h
    · rename_i hc
      injection h with h; subst h
      have hc' : p.nodes[cc]! = .const 0x3FF0000000000000 Dim.one := by simpa [Program.isConst] using hc
      have hxi : x < i := hp i hi x (by rw [hn]; simp [Node.args])
      have hcc : cc < i := hp i hi cc (by rw [hn]; simp [Node.args])
      have t1 := (op_typing hwf hi hn).2
      simp only [List.map_cons, List.map_nil, const_typing hwf (by omega) hc'] at t1
      refine redirect_final N hwf hxi hi (opTy_div_one t1).1.symm (op_not_exact hwf hi hn rfl) ?_
      exact fun t m => sem_divOne N hp hL hi hn hc' t m
    · simp at h
  · -- subZero
    rename_i _ x cc hn
    have hi := lt_of_op hn
    have hL := lawful_of N hwf hi hn rfl hLE
    split at h
    · rename_i u hty'
      split at h
      · rename_i hc
        injection h with h; subst h
        have hc' : p.nodes[cc]! = .const 0 u := by simpa [Program.isConst] using hc
        have hxi : x < i := hp i hi x (by rw [hn]; simp [Node.args])
        have t1 := (op_typing hwf hi hn).2
        simp only [List.map_cons, List.map_nil, hty'] at t1
        refine redirect_final N hwf hxi hi (by rw [hty', opTy_sub_inv t1]) (op_not_exact hwf hi hn rfl) ?_
        exact fun t m => sem_subZero N hp hL hi hn hc' t m
      · simp at h
    · simp at h
  · -- addComm
    rename_i _ a b hn
    have hi := lt_of_op hn
    have hL := lawful_of N hwf hi hn rfl hLE
    injection h with h; subst h
    obtain ⟨ha, t1⟩ := op_typing hwf hi hn
    simp only [List.map_cons, List.map_nil] at t1
    refine replace_final N hwf hi .add [b, a] (fun z hz => ha z (by simp at hz ⊢; exact hz.symm)) ?_
      (by simp [Node.plain]) (by rw [hn]; simp [Node.plain])
      (by simp [Node.exactFree, Op.exactValued]) (by rw [hn]; simp [Node.exactFree, Op.exactValued]) ?_
    · simp only [List.map_cons, List.map_nil]; rw [opTy_add_swap]; exact t1
    · intro t m
      rw [hn]
      exact hnode_addComm N t hL a b _ _ _ _ _
  · -- mulComm
    rename_i _ a b hn
    have hi := lt_of_op hn
    have hL := lawful_of N hwf hi hn rfl hLE
    injection h with h; subst h
    obtain ⟨ha, t1⟩ := op_typing hwf hi hn
    simp only [List.map_cons, List.map_nil] at t1
    refine replace_final N hwf hi .mul [b, a] (fun z hz => ha z (by simp at hz ⊢; exact hz.symm)) ?_
      (by simp [Node.plain]) (by rw [hn]; simp [Node.plain])
      (by simp [Node.exactFree, Op.exactValued]) (by rw [hn]; simp [Node.exactFree, Op.exactValued]) ?_
    · simp only [List.map_cons, List.map_nil]; rw [opTy_mul_swap]; exact t1
    · intro t m
      rw [hn]
      exact hnode_mulComm N t hL a b _ _ _ _ _
  · -- and
    rename_i _ a b hn
    have hi := lt_of_op hn
    injection h with h; subst h
    obtain ⟨ha, t1⟩ := op_typing hwf hi hn
    simp only [List.map_cons, List.map_nil] at t1
    refine replace_final N hwf hi .and [b, a] (fun z hz => ha z (by simp at hz ⊢; exact hz.symm)) ?_
      (by simp [Node.plain]) (by rw [hn]; simp [Node.plain])
      (by simp [Node.exactFree, Op.exactValued]) (by rw [hn]; simp [Node.exactFree, Op.exactValued]) ?_
    · simp only [List.map_cons, List.map_nil]; rw [opTy_and_swap]; exact t1
    · intro t m
      rw [hn]
      exact hnode_andComm N t a b _ _ _ _ _
  · -- or
    rename_i _ a b hn
    have hi := lt_of_op hn
    injection h with h; subst h
    obtain ⟨ha, t1⟩ := op_typing hwf hi hn
    simp only [List.map_cons, List.map_nil] at t1
    refine replace_final N hwf hi .or [b, a] (fun z hz => ha z (by simp at hz ⊢; exact hz.symm)) ?_
      (by simp [Node.plain]) (by rw [hn]; simp [Node.plain])
      (by simp [Node.exactFree, Op.exactValued]) (by rw [hn]; simp [Node.exactFree, Op.exactValued]) ?_
    · simp only [List.map_cons, List.map_nil]; rw [opTy_or_swap]; exact t1
    · intro t m
      rw [hn]
      exact hnode_orComm N t a b _ _ _ _ _
  · -- notNot
    rename_i _ a hn
    have hi := lt_of_op hn
    have hL := lawful_of N hwf hi hn rfl hLE
    split at h
    · rename_i cc hna
      injection h with h; subst h
      have hai : a < i := hp i hi a (by rw [hn]; simp [Node.args])
      have hca : cc < a := hp a (by omega) cc (by rw [hna]; simp [Node.args])
      have t1 := (op_typing hwf hi hn).2
      have t2 := (op_typing hwf (by omega) hna).2
      simp only [List.map_cons, List.map_nil] at t1 t2
      have e1 := opTy_not_inv t1
      have e2 := opTy_not_inv t2
      refine redirect_final N hwf (by omega) hi (by rw [e1.2, e2.1]) (op_not_exact hwf hi hn rfl) ?_
      exact fun t m => sem_notNot N hwf hL hi hn hna e2.1 t m
    · simp at h
  · -- ifNot
    rename_i _ nc a b hn
    have hi := lt_of_op hn
    have hL := lawful_of N hwf hi hn rfl hLE
    split at h
    · rename_i cc hnn
      injection h with h; subst h
      have hnci : nc < i := hp i hi nc (by rw [hn]; simp [Node.args])
      have hai : a < i := hp i hi a (by rw [hn]; simp [Node.args])
      have hbi : b < i := hp i hi b (by rw [hn]; simp [Node.args])
      have hcc : cc < nc := hp nc (by omega) cc (by rw [hnn]; simp [Node.args])
      have t1 := (op_typing hwf hi hn).2
      have t2 := (op_typing hwf (by omega) hnn).2
      simp only [List.map_cons, List.map_nil] at t1 t2
      have e2 := opTy_not_inv t2
      refine replace_final N hwf hi .ite [cc, b, a] (by simp; omega) ?_
        (by simp [Node.plain]) (by rw [hn]; simp [Node.plain])
        (by simp [Node.exactFree, Op.exactValued]) (by rw [hn]; simp [Node.exactFree, Op.exactValued]) ?_
      · simp only [List.map_cons, List.map_nil, e2.1]
        rw [e2.2] at t1
        rw [opTy_ite_swap]; exact t1
      · exact fun t m => hnode_ifNot N hp hL hi hn hnn t m
    · simp at h
  · -- gt to lt
    rename_i _ a b hn
    have hi := lt_of_op hn
    injection h with h; subst h
    obtain ⟨ha, t1⟩ := op_typing hwf hi hn
    simp only [List.map_cons, List.map_nil] at t1
    refine replace_final N hwf hi .lt [b, a] (fun z hz => ha z (by simp at hz ⊢; exact hz.symm)) ?_
      (by simp [Node.plain]) (by rw [hn]; simp [Node.plain])
      (by simp [Node.exactFree, Op.exactValued]) (by rw [hn]; simp [Node.exactFree, Op.exactValued]) ?_
    · simp only [List.map_cons, List.map_nil]
      rw [opTy_cmp (o := .gt) (o' := .lt) (Or.inl ⟨rfl, rfl⟩)]; exact t1
    · intro t m
      rw [hn]
      exact hnode_cmp N t .lt .gt a b _ _ _ _ _ (Or.inl ⟨rfl, rfl⟩)
  · -- lt to gt
    rename_i _ a b hn
    have hi := lt_of_op hn
    injection h with h; subst h
    obtain ⟨ha, t1⟩ := op_typing hwf hi hn
    simp only [List.map_cons, List.map_nil] at t1
    refine replace_final N hwf hi .gt [b, a] (fun z hz => ha z (by simp at hz ⊢; exact hz.symm)) ?_
      (by simp [Node.plain]) (by rw [hn]; simp [Node.plain])
      (by simp [Node.exactFree, Op.exactValued]) (by rw [hn]; simp [Node.exactFree, Op.exactValued]) ?_
    · simp only [List.map_cons, List.map_nil]
      rw [opTy_cmp (o := .lt) (o' := .gt) (Or.inr (Or.inl ⟨rfl, rfl⟩))]; exact t1
    · intro t m
      rw [hn]
      exact hnode_cmp N t .gt .lt a b _ _ _ _ _ (Or.inr (Or.inl ⟨rfl, rfl⟩))
  · -- ge to le
    rename_i _ a b hn
    have hi := lt_of_op hn
    injection h with h; subst h
    obtain ⟨ha, t1⟩ := op_typing hwf hi hn
    simp only [List.map_cons, List.map_nil] at t1
    refine replace_final N hwf hi .le [b, a] (fun z hz => ha z (by simp at hz ⊢; exact hz.symm)) ?_
      (by simp [Node.plain]) (by rw [hn]; simp [Node.plain])
      (by simp [Node.exactFree, Op.exactValued]) (by rw [hn]; simp [Node.exactFree, Op.exactValued]) ?_
    · simp only [List.map_cons, List.map_nil]
      rw [opTy_cmp (o := .ge) (o' := .le) (Or.inr (Or.inr (Or.inl ⟨rfl, rfl⟩)))]; exact t1
    · intro t m
      rw [hn]
      exact hnode_cmp N t .le .ge a b _ _ _ _ _ (Or.inr (Or.inr (Or.inl ⟨rfl, rfl⟩)))
  · -- le to ge
    rename_i _ a b hn
    have hi := lt_of_op hn
    injection h with h; subst h
    obtain ⟨ha, t1⟩ := op_typing hwf hi hn
    simp only [List.map_cons, List.map_nil] at t1
    refine replace_final N hwf hi .ge [b, a] (fun z hz => ha z (by simp at hz ⊢; exact hz.symm)) ?_
      (by simp [Node.plain]) (by rw [hn]; simp [Node.plain])
      (by simp [Node.exactFree, Op.exactValued]) (by rw [hn]; simp [Node.exactFree, Op.exactValued]) ?_
    · simp only [List.map_cons, List.map_nil]
      rw [opTy_cmp (o := .le) (o' := .ge) (Or.inr (Or.inr (Or.inr ⟨rfl, rfl⟩)))]; exact t1
    · intro t m
      rw [hn]
      exact hnode_cmp N t .ge .le a b _ _ _ _ _ (Or.inr (Or.inr (Or.inr ⟨rfl, rfl⟩)))
  · simp at h

end Engine.Lang
