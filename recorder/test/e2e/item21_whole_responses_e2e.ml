(* Item 21, and What it records, "A response is whole, or the request failed": the first main-dex [meta] answer is a
   probe, valid JSON of the venue's shape carrying a marker, framed or delivered as each fixture says. A fixture that
   fails gives one [error] event naming the request and its stage, quoting no byte of the response, stores nothing
   of the probe in [listings], and is retried: the next [meta] answer, whole, is stored. A fixture that is whole is
   stored, with no error. Uses the assumed flag --listings-interval-s. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl
module U = Yojson.Safe.Util

let support file = Filename_unix.realpath (Filename.concat "../support" file)
let tls = { F.crt_file = support "tls_server.crt"; key_file = support "tls_server.key" }
let universe = [ "A"; "B" ]
let marker = "whole-response-21"
let whole_meta = F.meta_json ~live:universe ~delisted:[]
let with_fields fields = String.chop_suffix_exn whole_meta ~suffix:"}" ^ fields ^ "}"
let probe = with_fields (sprintf {|,"probe":"%s"|} marker)
let length = String.length probe
let halves = [ String.prefix probe (length / 2); String.drop_prefix probe (length / 2) ]
let chunk text = sprintf "%x\r\n%s\r\n" (String.length text) text
let chunked_head = F.head [ "Transfer-Encoding: chunked" ]
let mib = 1 lsl 20

let request_type request =
  match Yojson.Safe.from_string request with
  | `Assoc fields ->
    (match List.Assoc.find fields ~equal:String.equal "type" with
     | Some (`String kind) -> Some kind
     | _ -> None)
  | _ -> None
  | exception Yojson.Json_error _ -> None
;;

let is_meta request = Option.equal String.equal (request_type request) (Some "meta")

let listings_errors ~root =
  List.filter_map (H.events ~root) ~f:(fun (recv, conn, event, msg) ->
    if String.equal event "error" && Option.is_none conn then Some (recv, msg) else None)
;;

let listings_text ~root = H.raw_channel_data ~root ~channel:"listings"
let events_text ~root = H.raw_channel_data ~root ~channel:"events"

let peak_resident_kib process =
  let status =
    In_channel.read_all (sprintf "/proc/%d/status" (Pid.to_int (Process.pid process)))
  in
  List.find_map_exn (String.split_lines status) ~f:(fun line ->
    match String.lsplit2 line ~on:':' with
    | Some ("VmHWM", value) ->
      Some (Int.of_string (String.strip (String.chop_suffix_exn value ~suffix:"kB")))
    | _ -> None)
;;

type run =
  { fake : F.t
  ; root : string
  ; process : Process.t
  ; probed_at : int
  }

(* A recorder whose first [meta] request is answered by [serve]; every other request, and every later [meta],
   whole. [f] runs once the probe has been asked for. *)
let with_probe ~serve ~over_tls f =
  let probed_at = Ivar.create () in
  let rest_serve ~request =
    if is_meta request && Ivar.is_empty probed_at
    then (
      Ivar.fill_exn probed_at (H.now_ms ());
      Some serve)
    else None
  in
  let config =
    { F.default_config with
      rest = F.rest_of_universe (fun () -> universe)
    ; rest_serve
    ; rest_tls = Option.some_if over_tls tls
    }
  in
  let%bind fake = F.start config in
  let root = H.tmp_dir () in
  let env = if over_tls then [ "SSL_CERT_FILE", support "tls_server.crt" ] else [] in
  let%bind process =
    H.spawn_run ~root ~env ~listings_interval_s:2 ~extra:[ "--connections"; "2" ] fake
  in
  Monitor.protect
    ~finally:(fun () ->
      let%bind () = H.kill_if_running process in
      F.stop fake)
    (fun () ->
       let%bind probed_at =
         match%map
           Clock.with_timeout (Time_float.Span.of_sec 30.) (Ivar.read probed_at)
         with
         | `Result at -> at
         | `Timeout -> failwith "the main dex's meta was never asked for"
       in
       let%bind () = f { fake; root; process; probed_at } in
       let%map status, _ = H.sigterm_and_wait process in
       H.check (Result.is_ok status) "exit status")
;;

let fails ?stage ?bytes ?within_ms ?max_resident_kib ?(over_tls = false) ~serve what () =
  with_probe ~serve ~over_tls (fun { fake; root; process; probed_at } ->
    let%map () =
      H.wait_until
        ~timeout_s:90.
        ~what:(sprintf "%s: an error event, then a whole meta stored" what)
        (fun () ->
           (not (List.is_empty (listings_errors ~root)))
           && List.count (F.rest_requests fake) ~f:is_meta >= 2
           && String.is_substring (listings_text ~root) ~substring:whole_meta)
    in
    Option.iter max_resident_kib ~f:(fun limit ->
      let peak = peak_resident_kib process in
      H.check
        (peak < limit)
        (sprintf "%s: the recorder peaked at %d KiB resident" what peak));
    let errors = listings_errors ~root in
    H.check
      (List.length errors = 1)
      (sprintf "%s: %d error events, not one" what (List.length errors));
    let recv, error = List.hd_exn errors in
    let text = Yojson.Safe.to_string error in
    H.check
      (String.is_substring text ~substring:"meta")
      (sprintf "%s: the error does not name meta: %s" what text);
    Option.iter stage ~f:(fun stage ->
      H.check
        (Poly.equal (U.member "stage" error) (`String stage))
        (sprintf "%s: the error's stage is not %s: %s" what stage text));
    (match U.member "bytes" error, bytes with
     | `Int got, Some expected ->
       H.check
         (got = expected)
         (sprintf "%s: the error counts %d bytes, not %d" what got expected)
     | `Int _, None -> ()
     | _ -> H.check false (sprintf "%s: the error has no integer bytes: %s" what text));
    Option.iter within_ms ~f:(fun limit ->
      H.check
        (recv - probed_at <= limit)
        (sprintf
           "%s: the error came %d ms after the request, more than %d"
           what
           (recv - probed_at)
           limit));
    H.check
      (not (String.is_substring (events_text ~root) ~substring:marker))
      (sprintf "%s: an event quotes the response" what);
    H.check
      (not (String.is_substring (listings_text ~root) ~substring:marker))
      (sprintf "%s: the response that failed is stored in listings" what))
;;

let passes ~serve what () =
  with_probe ~serve ~over_tls:false (fun { root; probed_at; _ } ->
    let%bind () =
      H.wait_until ~timeout_s:30. ~what:(sprintf "%s: the probe stored" what) (fun () ->
        String.is_substring (listings_text ~root) ~substring:marker)
    in
    let stored_after = H.now_ms () - probed_at in
    H.check
      (stored_after <= 5_000)
      (sprintf "%s: the probe was stored %d ms after its request" what stored_after);
    let%map () = after (Time_float.Span.of_sec 2.) in
    H.check
      (List.is_empty (listings_errors ~root))
      (sprintf "%s: an error event for a whole response" what))
;;

let send = F.send
let first_half = List.hd_exn halves
let second_half = List.last_exn halves
let chunks_of_whole = String.concat (List.map halves ~f:chunk)
let informational = "HTTP/1.1 103 Early Hints\r\nLink: </a>; rel=preload\r\n\r\n"

(* A chunked body that streams on: 1 MiB chunks up to 64 MiB, then the connection is held open. *)
let endless writer =
  Writer.set_raise_when_consumer_leaves writer false;
  let one = chunk (String.make mib ' ') in
  let rec go sent =
    if sent >= 64 || Deferred.is_determined (Writer.consumer_left writer)
    then Deferred.never ()
    else (
      Writer.write writer one;
      let%bind () = Deferred.any [ Writer.flushed writer; Writer.consumer_left writer ] in
      go (sent + 1))
  in
  Writer.write writer chunked_head;
  go 0
;;

let big =
  with_fields (sprintf {|,"probe":"%s","pad":"%s"|} marker (String.make (4 * mib) 'x'))
;;

let big_chunked =
  let size = String.length big in
  F.chunked
    (List.init
       ((size + 1023) / 1024)
       ~f:(fun i ->
         let pos = i * 1024 in
         String.sub big ~pos ~len:(Int.min 1024 (size - pos))))
;;

let short = F.with_length ~announced:(length + 64) probe

let () =
  H.main "item 21: whole responses" (fun () ->
    H.run_all
      [ ( "a body shorter than its Content-Length"
        , fails
            ~stage:"body"
            ~bytes:(String.length short)
            ~serve:(send short)
            "short Content-Length" )
      ; ( "a chunked body without its zero-size last chunk"
        , fails
            ~stage:"body"
            ~serve:(send (F.chunked ~ending:`No_last_chunk halves))
            "chunked, no last chunk" )
      ; ( "a chunked body closed after its zero-size chunk, before the final CRLF"
        , fails
            ~stage:"body"
            ~serve:(send (F.chunked ~ending:`No_final_crlf halves))
            "chunked, no final CRLF" )
      ; ( "a size line 0_ before the last chunk"
        , fails
            ~stage:"json"
            ~serve:
              (send
                 (chunked_head
                  ^ chunk first_half
                  ^ "0_\r\n\r\n"
                  ^ chunk second_half
                  ^ "0\r\n\r\n"))
            "chunked, size 0_ before last chunk" )
      ; ( "an overflowing Content-Length"
        , fails
            ~stage:"head"
            ~within_ms:5_000
            ~serve:(send (F.head [ "Content-Length: 99999999999999999999" ] ^ probe))
            "overflowing Content-Length" )
      ; ( "two Content-Length fields that differ"
        , fails
            ~stage:"head"
            ~serve:
              (send
                 (F.head
                    [ sprintf "Content-Length: %d" length
                    ; sprintf "Content-Length: %d" (length + 1)
                    ]
                  ^ probe))
            "conflicting lengths" )
      ; ( "a Content-Length of +N"
        , fails
            ~stage:"head"
            ~serve:(send (F.head [ sprintf "Content-Length: +%d" length ] ^ probe))
            "length +N" )
      ; ( "both a Content-Length and chunking"
        , fails
            ~stage:"head"
            ~serve:
              (send
                 (F.head
                    [ sprintf "Content-Length: %d" (String.length chunks_of_whole + 5)
                    ; "Transfer-Encoding: chunked"
                    ]
                  ^ chunks_of_whole
                  ^ "0\r\n\r\n"))
            "length and chunked" )
      ; ( "neither, over plain HTTP"
        , fails ~stage:"head" ~serve:(send (F.to_close probe)) "no framing, plain HTTP" )
      ; ( "neither, over TLS closed without close_notify"
        , fails
            ~stage:"head"
            ~over_tls:true
            ~serve:(send (F.to_close probe))
            "no framing, TLS" )
      ; ( "a 103 followed by the close"
        , fails ~stage:"head" ~serve:(send informational) "103 then the close" )
      ; ( "a Content-Length of 1 GiB"
        , fails
            ~stage:"head"
            ~within_ms:5_000
            ~serve:(send (F.with_length ~announced:(1 lsl 30) probe))
            "1 GiB" )
      ; ( "a chunked body streaming on past 16 MiB"
        , fails
            ~within_ms:20_000
            ~max_resident_kib:(256 * 1024)
            ~serve:endless
            "a body past 16 MiB" )
      ; ( "a final 500"
        , fails
            ~stage:"status"
            ~serve:
              (send (F.head ~status:500 [ sprintf "Content-Length: %d" length ] ^ probe))
            "a 500" )
      ; ( "a body with a comment"
        , fails
            ~stage:"json"
            ~serve:(send (F.with_length (probe ^ sprintf " /* %s */" marker)))
            "a comment" )
      ; ( "a body with a NaN"
        , fails
            ~stage:"json"
            ~serve:
              (send
                 (F.with_length (with_fields (sprintf {|,"probe":"%s","x":NaN|} marker))))
            "a NaN" )
      ; ( "a second value after the first"
        , fails
            ~stage:"json"
            ~serve:(send (F.with_length (probe ^ " {}")))
            "a second value" )
      ; ( "a byte that is not UTF-8"
        , fails
            ~stage:"json"
            ~serve:
              (send (F.with_length (with_fields (sprintf {|,"probe":"%s\xff"|} marker))))
            "not UTF-8" )
      ; ( "a body with a UTF-8 BOM"
        , fails
            ~stage:"json"
            ~serve:(send (F.with_length ("\xef\xbb\xbf" ^ probe)))
            "UTF-8 BOM" )
      ; ( "a body with a lone surrogate"
        , fails
            ~stage:"json"
            ~serve:
              (send
                 (F.with_length (with_fields (sprintf {|,"probe":"%s\ud800"|} marker))))
            "lone surrogate" )
      ; ( "a body nested 65 arrays deep"
        , fails
            ~stage:"json"
            ~serve:(send (F.with_length (String.make 65 '[' ^ String.make 65 ']')))
            "depth 65" )
      ; ( "1 MiB of open brackets"
        , fails
            ~stage:"json"
            ~within_ms:5_000
            ~serve:(send (F.with_length (String.make mib '[')))
            "1 MiB open brackets" )
      ; ( "a chunked body with trailers is whole"
        , passes
            ~serve:(send (F.chunked ~trailers:[ "X-Checksum: 1" ] halves))
            "chunked with trailers" )
      ; ( "Content-Length: N, N is whole"
        , passes
            ~serve:
              (send (F.head [ sprintf "Content-Length: %d, %d" length length ] ^ probe))
            "N, N" )
      ; ( "a 100 and a 103 before the 200"
        , passes
            ~serve:
              (send
                 ("HTTP/1.1 100 Continue\r\n\r\n" ^ informational ^ F.with_length probe))
            "informational replies first" )
      ; ( "Date header on final 200 after 103 is preserved"
        , fun () ->
            let final_date = "Sun, 22 Nov 2026 23:02:55 GMT" in
            let info_with_date =
              "HTTP/1.1 103 Early Hints\r\nDate: Mon, 01 Jan 2024 00:00:00 GMT\r\n\r\n"
            in
            let wire =
              info_with_date
              ^ F.head
                  [ sprintf "Date: %s" final_date; sprintf "Content-Length: %d" length ]
              ^ probe
            in
            with_probe ~serve:(send wire) ~over_tls:false (fun { root; _ } ->
              let%map () =
                H.wait_until ~timeout_s:30. ~what:"probe with Date stored" (fun () ->
                  String.is_substring (listings_text ~root) ~substring:marker)
              in
              let lines =
                H.recordings (Filename.concat root "listings")
                |> List.concat_map ~f:(fun path ->
                  String.split_lines (H.zstd_lenient_decode path))
                |> List.filter ~f:(fun l -> String.is_substring l ~substring:marker)
              in
              H.check
                (List.length lines = 1)
                "expected one stored listing line with marker";
              let json = Yojson.Safe.from_string (List.hd_exn lines) in
              H.check
                (Poly.equal (U.member "date" json) (`String final_date))
                (sprintf
                   "stored date was %s, expected %s"
                   (Yojson.Safe.to_string (U.member "date" json))
                   final_date)) )
      ; ( "whitespace around the value"
        , passes
            ~serve:(send (F.with_length (" \t\r\n" ^ probe ^ "\r\n ")))
            "whitespace around" )
      ; ( "a 4 MiB body in 1 KiB pieces, by length"
        , passes
            ~serve:(F.send_in_pieces ~bytes:1024 (F.with_length big))
            "4 MiB by length" )
      ; ( "a 4 MiB body in 1 KiB pieces, chunked"
        , passes ~serve:(F.send_in_pieces ~bytes:1024 big_chunked) "4 MiB chunked" )
      ; ( "a framed body on a connection kept open, by length"
        , passes
            ~serve:(F.send_and_keep_open (F.with_length probe))
            "kept open, by length" )
      ; ( "a framed body on a connection kept open, chunked"
        , passes ~serve:(F.send_and_keep_open (F.chunked halves)) "kept open, chunked" )
      ])
;;
