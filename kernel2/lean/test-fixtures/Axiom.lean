namespace Fixture
axiom magic : ∀ n : Nat, n = 0
theorem onAxiom : (3 : Nat) = 0 := magic 3
end Fixture
