(* Step 0, test 4: a State held by OCaml survives a major collection and is released exactly once.

   Interface assumed (the builder provides it), library `mm2_lean` (kernel2/ocaml/src), module Mm2_lean.State:
     type t                      a custom block owning a Lean object (a finalizer releases it)
     val create : unit -> t      the stub's initial state, with counter 0; initializes Lean's runtime on first use only
     val counter : t -> int      reads the state's counter through Lean
   Kept minimal:
     val bump : t -> unit        adds 1 to the held state's counter, in place as seen from OCaml
     val created_total : unit -> int   number of states the stub has created
     val released_total : unit -> int  number of Lean releases the stub has performed (incremented in the release stub)
   Each state is released once: after a state becomes unreachable and a major GC runs, released_total rises by exactly one
   for it, and never again. *)

module S = Mm2_lean.State

let check name cond = if not cond then (Printf.eprintf "FAIL: %s\n" name; exit 1)

let () =
  let created0 = S.created_total () and released0 = S.released_total () in
  let held = S.create () in
  S.bump held;
  S.bump held;
  Gc.full_major ();
  Gc.compact ();
  check "held state survives major GC and compaction" (S.counter held = 2);
  check "held state is not released while reachable" (S.released_total () = released0);
  S.bump held;
  check "held state still usable after GC" (S.counter held = 3);
  let () =
    let tmp = S.create () in
    S.bump tmp;
    check "second state independent" (S.counter tmp = 1 && S.counter held = 3)
  in
  Gc.full_major ();
  check "two states created" (S.created_total () = created0 + 2);
  check "unreachable state released exactly once" (S.released_total () = released0 + 1);
  Gc.full_major ();
  Gc.compact ();
  check "no second release" (S.released_total () = released0 + 1);
  check "held state intact at the end" (S.counter (Sys.opaque_identity held) = 3);
  print_endline "state: ok"
