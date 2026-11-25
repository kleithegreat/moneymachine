(* Item 6, "Retries" (What it records, item 1, "A failed read is retried with backoff"): with a listings interval of
   130 s, the first read and the second fail at [spotMeta], the third is whole, and the fourth fails. Reads begin 60 s
   and then 120 s apart, within the jitter of 20 % (and 3 s for the reads themselves); the whole read's successor
   comes within the interval; after it fails, the wait is 60 s again. No two reads begin within 48 s. A read begins
   with [perpDexs]. Takes about seven minutes. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl

let interval_s = 130

let request_type request =
  Yojson.Safe.Util.member "type" (Yojson.Safe.from_string request)
;;

let within ~what ~gap_ms ~low_s ~high_s =
  H.check
    (gap_ms >= low_s * 1000 && gap_ms <= high_s * 1000)
    (sprintf "%s: %d ms, not within [%d s, %d s]" what gap_ms low_s high_s)
;;

let () =
  H.main "item 6: a failed listings read is retried with backoff" (fun () ->
    let read_starts = ref [] in
    let rest ~request =
      match request_type request with
      | `String "perpDexs" ->
        read_starts := H.now_ms () :: !read_starts;
        F.perp_dexs_json []
      | `String "meta" -> F.meta_json ~live:[ "A"; "B" ] ~delisted:[]
      | `String "spotMeta" ->
        if List.length !read_starts = 3 then {|{"tokens":[],"universe":[]}|} else "null"
      | _ -> "{}"
    in
    let%bind fake = F.start { F.default_config with rest } in
    let root = H.tmp_dir () in
    let%bind process =
      H.spawn_run
        ~root
        ~listings_interval_s:interval_s
        ~extra:[ "--connections"; "2" ]
        fake
    in
    Monitor.protect
      ~finally:(fun () ->
        let%bind () = H.kill_if_running process in
        F.stop fake)
      (fun () ->
         let%bind () =
           H.wait_until ~timeout_s:600. ~what:"five reads begun" (fun () ->
             List.length !read_starts >= 5)
         in
         let%map status, _ = H.sigterm_and_wait process in
         H.check (Result.is_ok status) "exit status";
         let starts = List.rev !read_starts in
         let gaps =
           List.map2_exn (List.drop_last_exn starts) (List.tl_exn starts) ~f:(fun a b ->
             b - a)
         in
         H.check
           (List.for_all gaps ~f:(fun gap -> gap >= 48_000))
           "two reads began within 48 s";
         match gaps with
         | first :: second :: third :: fourth :: _ ->
           within ~what:"after the first failure" ~gap_ms:first ~low_s:48 ~high_s:75;
           within
             ~what:"after the second failure in a row"
             ~gap_ms:second
             ~low_s:96
             ~high_s:147;
           within
             ~what:"after a whole read"
             ~gap_ms:third
             ~low_s:48
             ~high_s:(interval_s + 3);
           within
             ~what:"after a failure that follows a whole read"
             ~gap_ms:fourth
             ~low_s:48
             ~high_s:75
         | _ -> H.check false "fewer than four gaps"))
;;
