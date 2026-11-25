(* VAULT.md test 7, "Framing", and Limits, "A response is whole, or the request failed": the run's first fills page
   is valid JSON, framed or delivered as each fixture says. A fixture that fails fails the run with an [error] naming
   the fills request and quoting no byte of the page, the watermark unmoved and nothing stored under [fills]. A
   fixture that is whole completes the pull. Interface assumed: see vault_harness.ml. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl
module V = Vault_harness

let support file = Filename_unix.realpath (Filename.concat "../support" file)
let tls = { F.crt_file = support "tls_server.crt"; key_file = support "tls_server.key" }
let tls_env = [ "SSL_CERT_FILE", support "tls_server.crt" ]
let now = V.nov 5 10 0
let marker = "vault-framing-7"
let one_fill = [ { V.tid = 1; time = V.nov 5 9 30; visible = true } ]
let page_of fills = V.array_json (List.map fills ~f:V.fill_json)
let page = page_of one_fill

let halves =
  [ String.prefix page (String.length page / 2)
  ; String.drop_prefix page (String.length page / 2)
  ]
;;

let leaks text =
  List.exists (marker :: V.sentinels) ~f:(fun s -> String.is_substring text ~substring:s)
;;

(* A fake holding [fills], whose first fills request is answered by [serve] and every other request as usual. *)
let start_fake ~fills ~serve ~over_tls =
  let%map fake = if over_tls then V.start ~tls () else V.start () in
  List.iter fills ~f:(fun (f : V.fill) ->
    V.add_fill fake ~tid:f.tid ~time:f.time ~visible:true);
  V.set_behaviour fake (fun ~kind ~nth _ ->
    if String.equal kind "userFillsByTime" && nth = 0 then V.Serve serve else V.Normal);
  fake
;;

let run fake ~root ~over_tls =
  let env = if over_tls then tls_env else [] in
  V.run_with ~env ~timeout_s:120. ~root ~fake ~now_ms:now ()
;;

let fails ?(over_tls = false) ~serve what () =
  let root = H.tmp_dir () in
  let%bind fake = start_fake ~fills:one_fill ~serve ~over_tls in
  let%bind outcome = run fake ~root ~over_tls in
  V.check_exit outcome ~expected:1 what;
  let errors = V.named (V.last_run_events ~root) "error" in
  H.check (not (List.is_empty errors)) (sprintf "%s: no error event" what);
  H.check
    (List.exists errors ~f:(fun e ->
       String.is_substring (Yojson.Safe.to_string e.V.json) ~substring:"userFillsByTime"))
    (sprintf "%s: no error event names the fills request" what);
  H.check
    (not (leaks (V.raw_text ~root "events")))
    (sprintf "%s: an event quotes the page" what);
  H.check (not (leaks outcome.output)) (sprintf "%s: the collector printed the page" what);
  H.check (V.watermark root = V.nov 1 0 0) (sprintf "%s: the watermark moved" what);
  H.check
    (String.is_empty (V.raw_text ~root "fills"))
    (sprintf "%s: something of a response not whole was stored under fills" what);
  V.stop fake
;;

let passes ?(fills = one_fill) ~serve what () =
  let root = H.tmp_dir () in
  let%bind fake = start_fake ~fills ~serve ~over_tls:false in
  let%bind outcome = run fake ~root ~over_tls:false in
  V.check_exit outcome ~expected:0 what;
  H.check
    (List.is_empty (V.named (V.last_run_events ~root) "error"))
    (sprintf "%s: an error event for a whole response" what);
  H.check
    (List.equal Int.equal (V.stored_tids ~root) (List.map fills ~f:(fun f -> f.V.tid)))
    (sprintf "%s: the fills were not stored" what);
  H.check (V.watermark root = now) (sprintf "%s: the watermark did not move" what);
  V.stop fake
;;

let length = String.length page
let send = F.send

let full_page =
  List.init V.fills_cap ~f:(fun i ->
    { V.tid = i + 1; time = V.nov 5 9 0 + i; visible = true })
;;

let () =
  H.main "vault: a response is whole, or the request failed" (fun () ->
    H.run_all
      [ ( "a body shorter than its Content-Length fails"
        , fails
            ~serve:(send (F.with_length ~announced:(length + 64) page))
            "a body shorter than its Content-Length" )
      ; ( "a chunked body without its zero-size last chunk fails"
        , fails
            ~serve:(send (F.chunked ~ending:`No_last_chunk halves))
            "a chunked body without its last chunk" )
      ; ( "a chunked body closed after its zero-size chunk, before the final CRLF, fails"
        , fails
            ~serve:(send (F.chunked ~ending:`No_final_crlf halves))
            "a chunked body without its final CRLF" )
      ; ( "an overflowing Content-Length fails"
        , fails
            ~serve:(send (F.head [ "Content-Length: 99999999999999999999" ] ^ page))
            "an overflowing Content-Length" )
      ; ( "a body with a lone surrogate fails"
        , fails
            ~serve:
              (send (F.with_length (sprintf {|[{"note":"\ud800","m":"%s"}]|} marker)))
            "a lone surrogate" )
      ; ( "two Content-Length fields that differ fail"
        , fails
            ~serve:
              (send
                 (F.head
                    [ sprintf "Content-Length: %d" length
                    ; sprintf "Content-Length: %d" (length + 1)
                    ]
                  ^ page))
            "two Content-Length fields that differ" )
      ; ( "a body announcing neither fails"
        , fails ~serve:(send (F.to_close page)) "a body announcing neither" )
      ; ( "a body announcing neither, over TLS, fails"
        , fails
            ~serve:(send (F.to_close page))
            ~over_tls:true
            "a TLS body announcing neither" )
      ; ( "a body with a comment after the page fails"
        , fails
            ~serve:(send (F.with_length (page ^ sprintf " /* %s */" marker)))
            "a comment after the page" )
      ; ( "a chunked body with trailers is whole"
        , passes
            ~serve:(send (F.chunked ~trailers:[ "X-Checksum: 1" ] halves))
            "a chunked body with trailers" )
      ; ( "Content-Length: N, N is whole"
        , passes
            ~serve:
              (send (F.head [ sprintf "Content-Length: %d, %d" length length ] ^ page))
            "N, N" )
      ; ( "a 103 before the 200 is skipped"
        , passes
            ~serve:
              (send
                 ("HTTP/1.1 103 Early Hints\r\nLink: </a>; rel=preload\r\n\r\n"
                  ^ F.with_length page))
            "a 103 first" )
      ; ( "a framed body whose server keeps the connection open is whole"
        , passes ~serve:(F.send_and_keep_open (F.with_length page)) "kept open" )
      ; ( "a page of 2,000 fills in 1 KiB pieces is whole"
        , passes
            ~fills:full_page
            ~serve:(F.send_in_pieces ~bytes:1024 (F.with_length (page_of full_page)))
            "2,000 fills in pieces" )
      ])
;;
