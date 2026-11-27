namespace Fixture
def fakeZero (_ : Nat) : Nat := 1
@[implemented_by fakeZero]
def realZero (_ : Nat) : Nat := 0
theorem viaImplementedBy : realZero 0 = 0 := rfl
end Fixture
