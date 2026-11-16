namespace Engine

/-- A value OCaml holds for Lean across calls; step 0's stand-in for the machine. -/
structure State where
  counter : Nat
  label : String

@[export mm2_state_new]
def State.new (_ : Unit) : State := { counter := 0, label := "state" }

@[export mm2_state_bump]
def State.bump (s : State) : State := { s with counter := s.counter + 1 }

@[export mm2_state_counter]
def State.value (s : State) : UInt64 := s.counter.toUInt64

end Engine
