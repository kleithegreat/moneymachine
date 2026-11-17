/- Step 5 test 12, raw IEEE cases hidden by a probe's non-finite filtering.
   Builder supplies Engine.Exact.exp, log : UInt64 → UInt64 through
   import Engine.Exact. These are X4's required pure Lean functions, NOT new
   exports, C stubs or mm2 entry points. Random/certified arguments still run
   through declared-source probes in x4_local.ml. No Laws/sorry dependency. -/
import Engine.Exact

set_option maxRecDepth 8192

namespace Step5Specials

def expect (name : String) (actual expected : UInt64) : IO Unit := do
  unless actual == expected do throw (IO.userError name)

#eval show IO Unit from do
  for zero in ([0, 0x8000000000000000] : List UInt64) do
    expect "exp of either zero is one" (Engine.Exact.exp zero) 0x3FF0000000000000
    expect "log of either zero is negative infinity" (Engine.Exact.log zero) 0xFFF0000000000000
  expect "log one is exact zero" (Engine.Exact.log 0x3FF0000000000000) 0
  expect "exp one witness" (Engine.Exact.exp 0x3FF0000000000000) 0x4005BF0A8B145769
  expect "log two witness" (Engine.Exact.log 0x4000000000000000) 0x3FE62E42FEFA39EF
  expect "exp positive infinity" (Engine.Exact.exp 0x7FF0000000000000) 0x7FF0000000000000
  expect "exp negative infinity" (Engine.Exact.exp 0xFFF0000000000000) 0
  expect "log positive infinity" (Engine.Exact.log 0x7FF0000000000000) 0x7FF0000000000000
  expect "log negative infinity" (Engine.Exact.log 0xFFF0000000000000) 0x7FF8000000000000
  expect "log negative finite" (Engine.Exact.log 0xBFF0000000000000) 0x7FF8000000000000
  for nan in ([0x7FF8000000000000, 0x7FF0000000000001, 0xFFF8000000000001] : List UInt64) do
    expect "exp canonical NaN" (Engine.Exact.exp nan) 0x7FF8000000000000
    expect "log canonical NaN" (Engine.Exact.log nan) 0x7FF8000000000000
  expect "exp overflow" (Engine.Exact.exp (710 : Float).toBits) 0x7FF0000000000000
  expect "exp underflow" (Engine.Exact.exp (-746 : Float).toBits) 0
  expect "exp subnormal" (Engine.Exact.exp (-744 : Float).toBits) 2
  IO.println "step5_12_raw_IEEE_specials: passed"

end Step5Specials
