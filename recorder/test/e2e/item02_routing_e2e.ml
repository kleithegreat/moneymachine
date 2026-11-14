(* Items 1 and 2 against the running recorder: frames land byte for byte in the file of their channel; acks,
   pongs, errors and unknown channels land in events. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let frame ~conn ~seq =
  match seq mod 6 with
  | 1 -> sprintf "{\"channel\":\"trades\",\r\n \"data\":[{\"coin\":\"C0\",\"n\":%d,\"c\":%d}]}" seq conn
  | 2 -> sprintf {|{"channel":"l2Book","data":{"coin":"C0","n":%d,"c":%d,"levels":[[],[]]}}|} seq conn
  | 3 -> sprintf {|{"channel":"allDexsAssetCtxs","data":{"n":%d,"c":%d}}|} seq conn
  | 4 -> sprintf {|{"channel":"pong","n":%d,"c":%d}|} seq conn
  | 5 -> sprintf {|{"channel":"error","data":"boom","n":%d,"c":%d}|} seq conn
  | _ -> sprintf "{\"channel\":\"unknownThing\",\n\"data\":[],\"n\":%d,\"c\":%d}" seq conn
;;

let channel_of_seq seq =
  match seq mod 6 with
  | 1 -> "trades"
  | 2 -> "l2Book"
  | 3 -> "allDexsAssetCtxs"
  | _ -> "events"
;;

let sanitize s = String.map s ~f:(function '\r' | '\n' -> ' ' | c -> c)

let () =
  H.main "item 1 and 2: lines and routing, end to end" (fun () ->
    let config =
      { F.default_config with
        rest = F.rest_of_universe (fun () -> [ "C0"; "C1"; "C2" ])
      ; stream = Some frame
      ; stream_interval_ms = 20
      }
    in
    let%bind fake = F.start config in
    let root = H.tmp_dir () in
    let%bind process = H.spawn_run ~root fake in
    let%bind () =
      H.wait_until ~timeout_s:20. ~what:"streams" (fun () ->
        List.exists (F.accepts fake) ~f:(fun (conn, _) -> F.streamed fake ~conn >= 60))
    in
    let%bind status, _ = H.sigterm_and_wait process in
    H.check (Result.is_ok status) "exit status";
    let data = Map.of_alist_exn (module String) (List.map [ "trades"; "l2Book"; "allDexsAssetCtxs"; "events" ] ~f:(fun c -> c, H.raw_channel_data ~root ~channel:c)) in
    let checked = ref 0 in
    List.iter (F.accepts fake) ~f:(fun (conn, _) ->
      for seq = 1 to F.streamed fake ~conn - 20 do
        let expected = sanitize (frame ~conn ~seq) in
        let home = channel_of_seq seq in
        H.check
          (String.is_substring (Map.find_exn data home) ~substring:(expected ^ "}\n"))
          (sprintf "frame conn=%d seq=%d is not byte for byte in %s" conn seq home);
        List.iter [ "trades"; "l2Book"; "allDexsAssetCtxs"; "events" ] ~f:(fun other ->
          if not (String.equal other home)
          then
            H.check
              (not (String.is_substring (Map.find_exn data other) ~substring:expected))
              (sprintf "frame conn=%d seq=%d also in %s" conn seq other));
        incr checked
      done);
    H.check (!checked >= 60) "too few frames checked";
    let events = Map.find_exn data "events" in
    H.check (String.is_substring events ~substring:{|"channel":"subscriptionResponse"|}) "acks are in events";
    H.check
      (not (String.is_substring (Map.find_exn data "trades") ~substring:"subscriptionResponse"))
      "ack in trades";
    F.stop fake)
;;
