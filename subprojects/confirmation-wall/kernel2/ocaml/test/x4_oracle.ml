(* Step 5 test-side bindings ONLY, supplied by x4_mpfr_stubs.c (not the builder).
   eval: 0=exp, 1=log, unchanged binary64 bits; round accepts an exact rational.
   selfcheck uses rational Taylor enclosures, including exp's underflow boundary.
   boundary arguments bracket the overflow, normal/subnormal and zero thresholds. *)

external eval : int -> int64 -> int64 = "mm2_test_mpfr_eval"
external round : string * string -> int64 = "mm2_test_mpfr_round"
external boundaries : unit -> int64 array = "mm2_test_mpfr_boundaries"
external selfcheck : unit -> unit = "mm2_test_mpfr_selfcheck"
external rational : int -> int -> int64 -> string * string = "mm2_test_mpfr_rational"
