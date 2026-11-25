(* Item 6, "A read that is not whole changes nothing" and "Absence changes nothing" (What it records, item 1). A
   healthy catalog is subscribed: the main dex with A, B and C, and dex xyz with xyz:T. Then one read is not whole,
   or is whole but leaves a coin or a dex out. A read that is not whole gives one [error] event naming its request and
   stage; one that leaves something out gives none; neither sends an [unsubscribe] nor writes a [listing] event. The
   read after it is whole: A, C and D listed, B flagged [isDelisted], xyz:T unchanged. Its [spotMeta] is held back,
   and until it is answered nothing changes; then D is subscribed and B unsubscribed, the only [listing] events. The
   [listings] lines are exactly the whole [200] responses sent, in order, each with its request and a null [conn]; a
   cut response's sent bytes are never stored. Uses the assumed flag --listings-interval-s. *)

open Core
open Async
module H = Rec_support.Harness
module F = Rec_support.Fake_hl
module U = Yojson.Safe.Util

let main_dex = [ "A"; "B"; "C" ]
let builder_coin = "xyz:T"
let whole_spot_meta = {|{"tokens":[],"universe":[]}|}
let healthy_meta = F.meta_json ~live:main_dex ~delisted:[]
let next_meta = F.meta_json ~live:[ "A"; "C"; "D" ] ~delisted:[ "B" ]
let builder_meta = F.meta_json ~live:[ builder_coin ] ~delisted:[]
let marker = "cut-short-6"

let field request name =
  match Yojson.Safe.from_string request with
  | `Assoc fields ->
    (match List.Assoc.find fields ~equal:String.equal name with
     | Some (`String value) -> value
     | _ -> "")
  | _ -> ""
  | exception Yojson.Json_error _ -> ""
;;

(* What a request of a read asks for. *)
type ask =
  | Perp_dexs
  | Main_meta
  | Builder_meta
  | Spot_meta
  | Other

let ask_of request =
  match field request "type", field request "dex" with
  | "perpDexs", _ -> Perp_dexs
  | "meta", "" -> Main_meta
  | "meta", "xyz" -> Builder_meta
  | "spotMeta", _ -> Spot_meta
  | _ -> Other
;;

let whole_answer ~meta = function
  | Perp_dexs -> F.perp_dexs_json [ "xyz" ]
  | Main_meta -> meta
  | Builder_meta -> builder_meta
  | Spot_meta -> whole_spot_meta
  | Other -> "{}"
;;

type answer =
  | Whole of string (** a whole [200] with this body, which must be stored *)
  | Cut of string
  (** this body cut short in transit: its first half sent under its whole [Content-Length] *)

type case =
  { answers : (ask * answer) list
    (** the read's answers where they differ from the healthy catalog's *)
  ; error : (string * string) option
    (** what the read's one [error] event must name, and its stage; [None]: the read is whole *)
  }

let fails ~ask ~names ~stage answer =
  { answers = [ ask, answer ]; error = Some (names, stage) }
;;

let leaves_out answers = { answers; error = None }

(* The times of every [subscribe] or [unsubscribe] the fake received for [coin]. *)
let requests fake ~meth ~coin =
  List.filter_map (F.received fake) ~f:(fun (_, at, text) ->
    match Yojson.Safe.from_string text with
    | `Assoc fields
      when Poly.equal
             (List.Assoc.find fields ~equal:String.equal "method")
             (Some (`String meth)) ->
      (match List.Assoc.find fields ~equal:String.equal "subscription" with
       | Some (`Assoc sub)
         when Poly.equal
                (List.Assoc.find sub ~equal:String.equal "coin")
                (Some (`String coin)) -> Some at
       | _ -> None)
    | _ -> None
    | exception Yojson.Json_error _ -> None)
;;

let all_coins = [ "A"; "B"; "C"; "D"; builder_coin ]
let subscribed fake ~coin = requests fake ~meth:"subscribe" ~coin
let unsubscribed fake ~coin = requests fake ~meth:"unsubscribe" ~coin
let unsubscribes fake = List.concat_map all_coins ~f:(fun coin -> unsubscribed fake ~coin)

let listing_changes ~root =
  List.filter_map (H.events ~root) ~f:(fun (recv, _, name, msg) ->
    match String.equal name "listing", U.member "coin" msg with
    | true, `String coin -> Some (recv, coin)
    | _ -> None)
;;

let listings_errors ~root =
  List.filter_map (H.events ~root) ~f:(fun (_, conn, event, msg) ->
    if String.equal event "error" && Option.is_none conn then Some msg else None)
;;

(* Each [listings] line as (request, conn, msg). *)
let listings_lines ~root =
  H.recordings (Filename.concat root "listings")
  |> List.concat_map ~f:(fun path ->
    String.split_lines (H.zstd_lenient_decode path)
    |> List.filter ~f:(fun line -> not (String.is_empty line))
    |> List.map ~f:(fun line ->
      let json = Yojson.Safe.from_string line in
      U.member "request" json, U.member "conn" json, U.member "msg" json))
;;

let check_errors case ~root =
  let errors = listings_errors ~root in
  match case.error with
  | None ->
    H.check
      (List.is_empty errors)
      (sprintf "%d error events for whole reads" (List.length errors))
  | Some (names, stage) ->
    H.check
      (List.length errors = 1)
      (sprintf "%d error events, not one" (List.length errors));
    List.iter errors ~f:(fun msg ->
      let text = Yojson.Safe.to_string msg in
      H.check
        (String.is_substring text ~substring:names)
        (sprintf "the error does not name %s: %s" names text);
      H.check
        (Poly.equal (U.member "stage" msg) (`String stage))
        (sprintf "the error's stage is not %s: %s" stage text))
;;

let check_stored ~root ~sent =
  H.check
    (not
       (String.is_substring
          (H.raw_channel_data ~root ~channel:"listings")
          ~substring:marker))
    "bytes of a cut response were stored";
  H.check
    (not
       (String.is_substring
          (H.raw_channel_data ~root ~channel:"events")
          ~substring:marker))
    "an event quotes a cut response";
  let stored = listings_lines ~root in
  H.check
    (List.length stored = List.length sent)
    (sprintf
       "%d listings lines for %d whole responses sent"
       (List.length stored)
       (List.length sent));
  let common = Int.min (List.length stored) (List.length sent) in
  List.iter2_exn
    (List.take stored common)
    (List.take sent common)
    ~f:(fun (request, conn, msg) (sent_request, sent_body) ->
      H.check (Poly.equal conn `Null) "a listings line's conn is not null";
      H.check
        (Yojson.Safe.equal request (Yojson.Safe.from_string sent_request))
        (sprintf
           "a listings line holds %s, not its request %s"
           (Yojson.Safe.to_string request)
           sent_request);
      H.check
        (Yojson.Safe.equal msg (Yojson.Safe.from_string sent_body))
        (sprintf
           "a listings line holds %s, not the response %s"
           (Yojson.Safe.to_string msg)
           sent_body))
;;

let judge case ~fake ~root ~process ~sent ~armed ~held ~release =
  let%bind () =
    H.wait_until ~timeout_s:20. ~what:"the healthy catalog subscribed" (fun () ->
      List.for_all main_dex ~f:(fun coin -> List.length (subscribed fake ~coin) >= 3)
      && List.length (subscribed fake ~coin:builder_coin) >= 2)
  in
  armed := true;
  let%bind () =
    H.wait_until ~timeout_s:90. ~what:"the next read's spotMeta asked for" (fun () ->
      !held)
  in
  let%bind () = after (Time_float.Span.of_sec 2.) in
  H.check
    (List.is_empty (unsubscribes fake))
    "an unsubscribe before the next read was whole";
  H.check
    (List.is_empty (subscribed fake ~coin:"D"))
    "D subscribed before the next read was whole";
  H.check
    (List.is_empty (listing_changes ~root))
    "a listing event before the next read was whole";
  let released_at = H.now_ms () in
  Ivar.fill_exn release ();
  let%bind () =
    H.wait_until
      ~timeout_s:30.
      ~what:"the next whole read applied: D subscribed, B unsubscribed"
      (fun () ->
         List.length (unsubscribed fake ~coin:"B") >= 3
         && List.length (subscribed fake ~coin:"D") >= 3)
  in
  let%map status, _ = H.sigterm_and_wait process in
  H.check (Result.is_ok status) "exit status";
  H.check
    (List.for_all (unsubscribes fake) ~f:(fun at -> at >= released_at))
    "an unsubscribe came early";
  List.iter [ "A"; "C"; builder_coin ] ~f:(fun coin ->
    H.check
      (List.is_empty (unsubscribed fake ~coin))
      (sprintf "%s, never flagged, was unsubscribed" coin));
  let changes = listing_changes ~root in
  H.check
    (List.for_all changes ~f:(fun (recv, _) -> recv >= released_at))
    "a listing event came early";
  H.check
    (List.equal
       String.equal
       (List.sort (List.map changes ~f:snd) ~compare:String.compare)
       [ "B"; "D" ])
    "the listing events are not exactly B's and D's";
  check_errors case ~root;
  check_stored ~root ~sent:(List.rev !sent)
;;

(* The fake's phases: the healthy catalog until [armed]; the case's read; the next read, its [spotMeta] held until
   [release]; then every request held for good, so that what was sent is final. *)
let scenario case () =
  let armed = ref false in
  let phase = ref `Healthy in
  let held = ref false in
  let release = Ivar.create () in
  let sent = ref [] in
  let deliver ~request = function
    | Whole body ->
      sent := (request, body) :: !sent;
      F.send (F.with_length body)
    | Cut body ->
      F.send
        (F.with_length
           ~announced:(String.length body)
           (String.prefix body (String.length body / 2)))
  in
  let rest_serve ~request =
    let ask = ask_of request in
    (match !phase, ask with
     | `Healthy, Perp_dexs when !armed -> phase := `Case
     | `Case, Perp_dexs -> phase := `Next
     | `Next, Perp_dexs when !held -> phase := `Done
     | _ -> ());
    match !phase, ask with
    | `Healthy, _ -> Some (deliver ~request (Whole (whole_answer ~meta:healthy_meta ask)))
    | `Case, _ ->
      let default = Whole (whole_answer ~meta:healthy_meta ask) in
      let answer =
        Option.value (List.Assoc.find case.answers ~equal:Poly.equal ask) ~default
      in
      Some (deliver ~request answer)
    | `Next, Spot_meta ->
      held := true;
      Some
        (fun writer ->
          let%bind () = Ivar.read release in
          deliver ~request (Whole whole_spot_meta) writer)
    | `Next, _ -> Some (deliver ~request (Whole (whole_answer ~meta:next_meta ask)))
    | `Done, _ -> Some (fun _ -> Deferred.never ())
  in
  let%bind fake = F.start { F.default_config with rest_serve } in
  let root = H.tmp_dir () in
  let%bind process =
    H.spawn_run ~root ~listings_interval_s:2 ~extra:[ "--connections"; "2" ] fake
  in
  Monitor.protect
    ~finally:(fun () ->
      let%bind () = H.kill_if_running process in
      F.stop fake)
    (fun () -> judge case ~fake ~root ~process ~sent ~armed ~held ~release)
;;

let spot_probe = sprintf {|{"tokens":[],"universe":[],"probe":"%s"}|} marker
let without_b = F.meta_json ~live:[ "A"; "C" ] ~delisted:[]
let foreign = F.meta_json ~live:[ "A"; "C" ] ~delisted:[ "B" ]
let nameless = {|{"universe":[{"szDecimals":4,"maxLeverage":10}],"marginTables":[]}|}

let () =
  H.main
    "item 6: a listings read that is not whole, or leaves something out, changes nothing"
    (fun () ->
       H.run_all
         [ ( "perpDexs answers 200 []"
           , scenario (fails ~ask:Perp_dexs ~names:"perpDexs" ~stage:"shape" (Whole "[]"))
           )
         ; ( "perpDexs answers null"
           , scenario
               (fails ~ask:Perp_dexs ~names:"perpDexs" ~stage:"shape" (Whole "null")) )
         ; ( "the main dex's meta answers null"
           , scenario (fails ~ask:Main_meta ~names:"meta" ~stage:"shape" (Whole "null")) )
         ; ( "the main dex's meta has a universe item with no name"
           , scenario (fails ~ask:Main_meta ~names:"meta" ~stage:"shape" (Whole nameless))
           )
         ; ( "xyz's meta answers with main-dex coins, B flagged"
           , scenario
               (fails ~ask:Builder_meta ~names:"xyz" ~stage:"shape" (Whole foreign)) )
         ; ( "spotMeta answers null"
           , scenario
               (fails ~ask:Spot_meta ~names:"spotMeta" ~stage:"shape" (Whole "null")) )
         ; ( "spotMeta is cut short"
           , scenario
               (fails ~ask:Spot_meta ~names:"spotMeta" ~stage:"body" (Cut spot_probe)) )
         ; ( "a whole main-dex meta omitting B, then spotMeta cut short"
           , scenario
               { answers = [ Main_meta, Whole without_b; Spot_meta, Cut spot_probe ]
               ; error = Some ("spotMeta", "body")
               } )
         ; "perpDexs is [null]", scenario (leaves_out [ Perp_dexs, Whole "[null]" ])
         ; ( "the main dex's universe omits B"
           , scenario (leaves_out [ Main_meta, Whole without_b ]) )
         ; ( "the main dex's universe is []"
           , scenario
               (leaves_out [ Main_meta, Whole {|{"universe":[],"marginTables":[]}|} ]) )
         ])
;;
