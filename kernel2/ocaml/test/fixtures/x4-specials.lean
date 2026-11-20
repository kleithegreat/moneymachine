/- Step 5 test 12, raw IEEE cases hidden by a probe's non-finite filtering.
   Builder supplies Engine.Exact.exp, log : UInt64 → UInt64 through
   import Engine.Exact. These are X4's required pure Lean functions, NOT new
   exports, C stubs or mm2 entry points. Random/certified arguments still run
   through declared-source probes in x4_local.ml. No Laws/sorry dependency. -/
import Engine.Exact

set_option maxRecDepth 8192

namespace Step5Specials

def expect (name : String) (actual expected : UInt64) : IO Unit := do
  unless actual == expected do
    throw (IO.userError s!"{name}: got {actual}, expected {expected}")

def expectSubnormal (name : String) (actual : UInt64) : IO Unit := do
  unless actual > 0 && actual < 0x0010000000000000 do
    throw (IO.userError s!"{name}: expected nonzero subnormal, got {actual}")

def expectFinite (name : String) (actual : UInt64) : IO Unit := do
  unless (actual &&& 0x7FF0000000000000) < 0x7FF0000000000000 do
    throw (IO.userError s!"{name}: expected finite result, got {actual}")

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
  for neg in ([0x8000000000000001, 0x800FFFFFFFFFFFFF, 0x8010000000000000,
               0xBFF0000000000000, 0xFFEFFFFFFFFFFFFF] : List UInt64) do
    expect "log negative finite" (Engine.Exact.log neg) 0x7FF8000000000000
  for nan in ([0x7FF8000000000000, 0x7FF0000000000001,
               0xFFF0000000000001, 0xFFF8000000000001] : List UInt64) do
    expect "exp canonical NaN" (Engine.Exact.exp nan) 0x7FF8000000000000
    expect "log canonical NaN" (Engine.Exact.log nan) 0x7FF8000000000000
  expect "exp overflow" (Engine.Exact.exp (710 : Float).toBits) 0x7FF0000000000000
  expect "exp underflow" (Engine.Exact.exp (-746 : Float).toBits) 0
  expect "exp subnormal -744" (Engine.Exact.exp (-744 : Float).toBits) 2
  expect "exp subnormal -745" (Engine.Exact.exp (-745 : Float).toBits) 1
  -- Tiny exp inputs and 1 +/- eps for log
  for tiny in ([0x0000000000000001, 0x8000000000000001,
                0x3C90000000000000, 0xBC90000000000000] : List UInt64) do
    expect "exp near zero is 1" (Engine.Exact.exp tiny) 0x3FF0000000000000
  expect "exp +2^-53" (Engine.Exact.exp 0x3CA0000000000000) 0x3FF0000000000001
  expect "exp -2^-53" (Engine.Exact.exp 0xBCA0000000000000) 0x3FEFFFFFFFFFFFFF
  expect "log 1-eps/2" (Engine.Exact.log 0x3FEFFFFFFFFFFFFF) 0xBCA0000000000000
  expect "log 1+eps" (Engine.Exact.log 0x3FF0000000000001) 0x3CAFFFFFFFFFFFFF
  -- Cutoff interiors and extremes
  expect "exp DBL_MAX overflows" (Engine.Exact.exp 0x7FEFFFFFFFFFFFFF) 0x7FF0000000000000
  expect "exp -DBL_MAX underflows" (Engine.Exact.exp 0xFFEFFFFFFFFFFFFF) 0
  expect "exp nextafter(-746, 0) underflows" (Engine.Exact.exp 0xC0874FFFFFFFFFFF) 0
  expect "exp nextafter(c0874910d52d3052, -inf) underflows" (Engine.Exact.exp 0xC0874910D52D3053) 0
  expect "exp boundary 0 finite" (Engine.Exact.exp 0x40862E42FEFA39EF) 0x7FEFFFFFFFFFFF2A
  expect "exp boundary 2 subnormal" (Engine.Exact.exp 0xC086232BDD7ABCD3) 0x000FFFFFFFFFFE7C
  expect "exp boundary 3 normal" (Engine.Exact.exp 0xC086232BDD7ABCD2) 0x001000000000007C
  expect "exp boundary 4 zero" (Engine.Exact.exp 0xC0874910D52D3052) 0
  expect "exp boundary 5 min subnormal" (Engine.Exact.exp 0xC0874910D52D3051) 1
  -- Subnormal and extreme-exponent log inputs
  expect "log 2^-1074" (Engine.Exact.log 0x0000000000000001) 0xC0874385446D71C3
  expect "log max_subnormal" (Engine.Exact.log 0x000FFFFFFFFFFFFF) 0xC086232BDD7ABCD2
  expect "log min_normal" (Engine.Exact.log 0x0010000000000000) 0xC086232BDD7ABCD2
  expect "log DBL_MAX" (Engine.Exact.log 0x7FEFFFFFFFFFFFFF) 0x40862E42FEFA39EF
  for k in List.range 52 do
    expectFinite "log subnormal power of 2" (Engine.Exact.log ((1 : UInt64) <<< k.toUInt64))
  for sub in ([0x0000000000000003, 0x000123456789ABCD, 0x0008000000000001, 0x000FFFFFFFFFFFFE] : List UInt64) do
    expectFinite "log subnormal mixed" (Engine.Exact.log sub)
  for i in List.range 29 do
    let biased : UInt64 := (1023 + 995 + i).toUInt64 <<< 52
    expectFinite "log high binade" (Engine.Exact.log biased)
    expectFinite "log high binade mixed" (Engine.Exact.log (biased ||| 0x000A55A55A55A55A))
  for subIn in ([(-745.13 : Float).toBits, (-743.0 : Float).toBits, (-735.0 : Float).toBits,
                 (-725.0 : Float).toBits, (-715.0 : Float).toBits, (-708.5 : Float).toBits] : List UInt64) do
    expectSubnormal "exp subnormal range" (Engine.Exact.exp subIn)
  IO.println "step5_12_raw_IEEE_specials: passed"

end Step5Specials
