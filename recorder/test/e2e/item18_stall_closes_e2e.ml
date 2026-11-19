(* Item 18: stalled listings requests close their connections. The first listings read is answered; the next five
   listings requests are accepted by the fake, which starts each answer and never finishes it. The recorder fails
   each after 30 s, and the open file count of its process (/proc/<pid>/fd), once the fifth has failed, must be
   where it was before the first stalled request, within a little slack: a connection left open by each stalled
   request would be five more descriptors. Each reading is the least of several samples, so a request in flight at
   that moment does not count. Uses the assumed flag --listings-interval-s to make the "hourly" read fast, but not
   so fast that the baseline cannot be read before the first stalled request. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let stalls = 5

let is_perp_dexs request =
  match Yojson.Safe.from_string request with
  | `Assoc fields -> Poly.equal (List.Assoc.find fields ~equal:String.equal "type") (Some (`String "perpDexs"))
  | _ -> false
  | exception Yojson.Json_error _ -> false
;;

let open_fds ~pid = Array.length (Stdlib.Sys.readdir (sprintf "/proc/%d/fd" (Pid.to_int pid)))

let settled_fds ~pid =
  let rec go samples least =
    if samples = 0
    then return least
    else (
      let least = Int.min least (open_fds ~pid) in
      let%bind () = after (Time_float.Span.of_ms 50.) in
      go (samples - 1) least)
  in
  go 10 Int.max_value
;;

let () =
  H.main "item 18: stalled listings requests close their connections" (fun () ->
    let perp_dexs_seen = ref 0 in
    let rest = F.rest_of_universe (fun () -> [ "C0"; "C1" ]) in
    let rest_stall ~request =
      if is_perp_dexs request
      then (
        incr perp_dexs_seen;
        !perp_dexs_seen >= 2 && !perp_dexs_seen <= stalls + 1)
      else false
    in
    let config =
      { F.default_config with
        rest
      ; rest_stall
      ; stream = Some (fun ~conn ~seq -> F.trades_frame ~coin:(sprintf "K%d" conn) ~seq)
      ; stream_interval_ms = 10
      }
    in
    let%bind fake = F.start config in
    let root = H.tmp_dir () in
    let%bind process = H.spawn_run ~root ~listings_interval_s:12 ~extra:[ "--connections"; "2" ] fake in
    let pid = Process.pid process in
    let exited () = Deferred.is_determined (Process.wait process) in
    let error_events () =
      List.filter (H.events ~root) ~f:(fun (_, _, event, _) -> String.equal event "error")
    in
    let%bind () =
      H.wait_until ~timeout_s:30. ~what:"the first listings read and a stream on each connection" (fun () ->
        H.check (not (exited ())) "the process exited";
        !perp_dexs_seen >= 1 && F.streamed fake ~conn:1 > 0 && F.streamed fake ~conn:2 > 0)
    in
    let%bind before = settled_fds ~pid in
    H.check (!perp_dexs_seen = 1) "the baseline was read after the first stalled request; it is not a baseline";
    let%bind () =
      H.wait_until ~timeout_s:900. ~what:"an error event for each of the stalled requests" (fun () ->
        H.check (not (exited ())) "the process exited";
        List.length (error_events ()) >= stalls)
    in
    let%bind after_stalls = settled_fds ~pid in
    H.check
      (!perp_dexs_seen >= stalls + 1)
      (sprintf "only %d listings requests were made, expected at least %d" !perp_dexs_seen (stalls + 1));
    H.check
      (after_stalls <= before + 1)
      (sprintf
         "open file count %d after %d stalled listings requests failed, against %d before the first"
         after_stalls
         stalls
         before);
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    F.stop fake)
;;
