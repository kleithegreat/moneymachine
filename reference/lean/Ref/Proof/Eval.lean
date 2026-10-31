import Ref.Proof.EvalOp0
import Ref.Proof.EvalOp1
import Ref.Proof.EvalOp2
import Ref.Proof.EvalOp3Ite
import Ref.Proof.EvalOp3Clip
import Ref.Proof.EvalOp3A
import Ref.Proof.EvalOp3B
import Ref.Proof.EvalOp3C
import Ref.Proof.EvalOp3D

namespace Ref
variable {α : Type} [Inhabited α]

omit [Inhabited α] in
theorem evalU_op (N : NumOps α) (p : Program) (m : MState α) (tv : Array (Array (TVal α))) (i c : Nat)
    (o : Op) (args : List Nat) (hn : p.nodes[i]! = .op o args) (ty : Ty)
    (hty : opTy o (args.map (p.types[·]!)) p.convTo[i]! = some ty) (hT : Tagged N p tv)
    (ho : o ≠ .xsMean ∧ o ≠ .xsDemean ∧ o ≠ .xsRank ∧ o ≠ .hoursSince) :
    ∃ r, evalU N p m tv i c = .ok r ∧ r.map (·.1) = MState.eval N p { m with vals := eraseTV tv } i c ∧
      ∀ x t, r = some (x, t) → t = ty ∧ (t = .bool → ∃ b, x = N.truth b) := by
  rcases args with _ | ⟨a0, _ | ⟨a1, _ | ⟨a2, rest⟩⟩⟩
  · exact evalU_op0 N p m tv i c o hn ty hty hT ho
  · exact evalU_op1 N p m tv i c o a0 hn ty hty hT ho
  · exact evalU_op2 N p m tv i c o a0 a1 hn ty hty hT ho
  · cases o <;> first
    | (refine evalU_op3Ite N p m tv i c _ a0 a1 a2 rest hn ty hty hT ?_ ho; simp; done)
    | (refine evalU_op3Clip N p m tv i c _ a0 a1 a2 rest hn ty hty hT ?_ ho; simp; done)
    | (refine evalU_op3A N p m tv i c _ a0 a1 a2 rest hn ty hty hT ?_ ho; simp; done)
    | (refine evalU_op3B N p m tv i c _ a0 a1 a2 rest hn ty hty hT ?_ ho; simp; done)
    | (refine evalU_op3C N p m tv i c _ a0 a1 a2 rest hn ty hty hT ?_ ho; simp; done)
    | (refine evalU_op3D N p m tv i c _ a0 a1 a2 rest hn ty hty hT ?_ ho; simp; done)
    | (exfalso; simp at ho)

omit [Inhabited α] in
theorem evalU_leaf (N : NumOps α) (p : Program) (m : MState α) (tv : Array (Array (TVal α))) (i c : Nat)
    {reg : Registry} (hW : p.WF reg) (hi : i < p.nodes.size) (hn : ∀ o args, p.nodes[i]! ≠ .op o args) :
    ∃ r, evalU N p m tv i c = .ok r ∧ r.map (·.1) = MState.eval N p { m with vals := eraseTV tv } i c ∧
      ∀ x t, r = some (x, t) → t = p.types[i]! ∧ (t = .bool → ∃ b, x = N.truth b) := by
  have h := hW.2.2.2.2.2 i hi
  cases hn' : p.nodes[i]! with
  | op o args => exact absurd hn' (hn o args)
  | input inp =>
    simp only [hn'] at h
    refine ⟨(m.input inp c).map (·, .num inp.unit), by simp only [evalU, hn']; rfl, ?_, ?_⟩
    · simp only [MState.eval, hn', Option.map_map]; cases inp <;> simp [MState.input, Function.comp_def]
    · intro x t hx; simp at hx; obtain ⟨_, _, _, rfl⟩ := hx; simp [h.2]
  | const bits u =>
    simp only [hn'] at h
    exact ⟨some (N.ofBits bits, .num u), by simp only [evalU, hn']; rfl, by simp [MState.eval, hn'],
      fun x t hx => by simp at hx; obtain ⟨_, rfl⟩ := hx; simp [h]⟩
  | param k =>
    simp only [hn'] at h
    exact ⟨some (N.ofBits p.params[k]!.1, .num p.params[k]!.2), by simp only [evalU, hn']; rfl,
      by simp [MState.eval, hn'], fun x t hx => by simp at hx; obtain ⟨_, rfl⟩ := hx; simp [h.2]⟩

end Ref
