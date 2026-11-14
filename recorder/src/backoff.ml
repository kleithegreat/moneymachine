open Core

type t =
  { random : unit -> float
  ; mutable failures : int
  ; mutable up_since : float option
  }

let reset_after_s = 600.
let max_delay_s = 60.
let create ~random = { random; failures = 0; up_since = None }
let opened t ~now = t.up_since <- Some now

let failed t ~now =
  let stayed_up =
    Option.exists t.up_since ~f:(fun since -> Float.( >= ) (now -. since) reset_after_s)
  in
  if stayed_up then t.failures <- 0;
  t.up_since <- None;
  let base = Float.min max_delay_s (2. ** Float.of_int t.failures) in
  t.failures <- t.failures + 1;
  base *. (0.8 +. (0.4 *. t.random ()))
;;
