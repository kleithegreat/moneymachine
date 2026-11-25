namespace Engine.Machine

inductive Number where
  | placed (digits : Int) (places : Nat)
  | bits (bits : UInt64)
  deriving Repr, DecidableEq

/-- A coin's rules: its lots, its price grid (A18) and its margin tiers, each a bound and a greatest leverage. -/
structure Rules where
  szDecimals : Nat
  figures : Nat
  decimals : Int
  tiers : List (Number × Int)
  deriving Repr, DecidableEq

structure Rows where
  report : String
  trace : String
  deriving Repr, DecidableEq

def Rows.empty : Rows := ⟨"", ""⟩

instance : Append Rows := ⟨fun a b => ⟨a.report ++ b.report, a.trace ++ b.trace⟩⟩

end Engine.Machine
