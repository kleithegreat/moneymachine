open Core
module File_writer = Writer
open Async

type config =
  { root : string
  ; connections : int
  ; max_subscriptions : int
  ; ws_url : string
  ; rest_url : string
  ; listings_interval_s : int
  }

type conn =
  { id : int
  ; mutable outbox : (string * Sub.t option) Pipe.Writer.t option
  }

type t =
  { config : config
  ; writer : File_writer.t
  ; planner : Planner.t
  ; conns : conn array
  ; open_limit : Rate_limit.t
  ; send_limit : Rate_limit.t
  ; stop : unit Ivar.t
  }

let now_ms () = Time_ns.to_int_ns_since_epoch (Time_ns.now ()) / 1_000_000
let span_of_ms ms = Time_ns.Span.of_int_ms ms
let stopped t = Ivar.is_full t.stop

let wait_ms t ms =
  Deferred.any [ Clock_ns.after (span_of_ms (Int.max 0 ms)); Ivar.read t.stop ]
;;

let record t ?conn event =
  let recv_ms = now_ms () in
  File_writer.add t.writer Route.Events ~recv_ms (Event.to_line ~recv_ms ~conn event)
;;

let sub_fields = function
  | Sub.All_dexs_asset_ctxs -> [ "channel", `String "allDexsAssetCtxs" ]
  | Sub.Trades coin -> [ "channel", `String "trades"; "coin", `String coin ]
  | Sub.L2_book_fast coin ->
    [ "channel", `String "l2Book"; "coin", `String coin; "fast", `Bool true ]
  | Sub.L2_book coin -> [ "channel", `String "l2Book"; "coin", `String coin ]
;;

let enqueue conn msg sub =
  Option.iter conn.outbox ~f:(fun outbox ->
    Pipe.write_without_pushback_if_open outbox (msg, sub))
;;

let apply_actions t actions =
  List.iter actions ~f:(function
    | Listing_update.Subscribe { conn; sub } ->
      enqueue t.conns.(conn) (Sub.subscribe_message sub) (Some sub)
    | Listing_update.Unsubscribe { conn; sub } ->
      enqueue t.conns.(conn) (Sub.unsubscribe_message sub) None
    | Listing_update.Record event -> record t event)
;;

let close_outcome ws =
  match%map
    Clock_ns.with_timeout (Time_ns.Span.of_sec 5.) (Websocket.close_finished ws)
  with
  | `Result
      ( ((Websocket.Connection_close_reason.Normal_closure | Endpoint_going_away) as code)
      , reason
      , _ ) ->
    Ok
      (sprintf
         "%s: %s"
         (Sexp.to_string (Websocket.Connection_close_reason.sexp_of_t code))
         reason)
  | `Result (code, reason, _) ->
    Error
      (sprintf
         "%s: %s"
         (Sexp.to_string (Websocket.Connection_close_reason.sexp_of_t code))
         reason)
  | `Timeout -> Error "connection lost: no close"
;;

let serve t conn ws ~ended =
  let reader, writer = Websocket.pipes ws in
  let outbox_reader, outbox = Pipe.create () in
  let finish reason = Ivar.fill_if_empty ended reason in
  let health = Conn_health.create ~now_ms:(now_ms ()) in
  let acks = Ack_tracker.create () in
  let pace = Rate_limit.create ~limit:10 ~window_ms:1000 in
  conn.outbox <- Some outbox;
  List.iter (Planner.subs t.planner ~conn:conn.id) ~f:(fun sub ->
    enqueue conn (Sub.subscribe_message sub) (Some sub));
  let send (message, sub) =
    if Ivar.is_full ended
    then return ()
    else (
      let paced = Rate_limit.reserve pace ~now_ms:(now_ms ()) ~n:1 in
      let at = Rate_limit.reserve t.send_limit ~now_ms:paced ~n:1 in
      let%map () =
        Deferred.any_unit
          [ wait_ms t (at - now_ms ()); Ivar.read ended |> Deferred.ignore_m ]
      in
      if not (Ivar.is_full ended)
      then (
        Pipe.write_without_pushback_if_open writer message;
        Option.iter sub ~f:(Ack_tracker.sent acks ~now_ms:(now_ms ()))))
  in
  don't_wait_for (Pipe.iter outbox_reader ~f:send);
  let on_frame frame =
    let recv_ms = now_ms () in
    Conn_health.received health ~now_ms:recv_ms;
    let fast = Planner.equal_kind (Planner.kind t.planner ~conn:conn.id) Planner.Fast in
    let route = Route.of_frame ~fast frame in
    File_writer.add t.writer route ~recv_ms (Line.of_frame ~recv_ms ~conn:conn.id frame);
    if Route.equal route Route.Events
    then
      Option.iter (Sub.of_ack frame) ~f:(fun sub ->
        Ack_tracker.acked acks sub;
        record t ~conn:conn.id (Event.make "subscribed" (sub_fields sub)))
  in
  upon
    (let%bind () = Pipe.iter_without_pushback reader ~f:on_frame in
     close_outcome ws)
    finish;
  upon (Ivar.read t.stop) (fun () -> finish (Ok "stopping"));
  Clock_ns.every
    ~stop:(Deferred.ignore_m (Ivar.read ended))
    (span_of_ms 1000)
    (fun () ->
       let now_ms = now_ms () in
       List.iter (Conn_health.poll health ~now_ms) ~f:(function
         | Conn_health.Send_ping -> enqueue conn {|{"method":"ping"}|} None
         | Conn_health.Reopen -> finish (Ok "nothing received for 45 s"));
       List.iter (Ack_tracker.expired acks ~now_ms) ~f:(fun sub ->
         record t ~conn:conn.id (Event.make "unacked" (sub_fields sub))));
  let%map reason = Ivar.read ended in
  conn.outbox <- None;
  Pipe.close outbox;
  Pipe.close writer;
  reason
;;

let attempt t conn backoff =
  let ended = Ivar.create () in
  let transport = ref None in
  let over = ref false in
  let opened = ref false in
  let connected net =
    if !over then don't_wait_for (net.Net.close ()) else transport := Some net
  in
  let life () =
    let%bind ws = Net.websocket t.config.ws_url ~connected in
    Backoff.opened backoff ~now:(Float.of_int (now_ms ()) /. 1000.);
    record t ~conn:conn.id (Event.make "open" []);
    opened := true;
    serve t conn ws ~ended
  in
  let fail exn = Ivar.fill_if_empty ended (Error (Exn.to_string exn)) in
  let%bind outcome = try_with ~rest:(`Call fail) life in
  over := true;
  (match outcome with
   | Ok (Ok reason) ->
     record t ~conn:conn.id (Event.make "close" [ "reason", `String reason ])
   | Ok (Error reason) ->
     record t ~conn:conn.id (Event.make "error" [ "reason", `String reason ])
   | Error exn ->
     fail exn;
     let reason =
       if !opened then "connection lost: " ^ Exn.to_string exn else Exn.to_string exn
     in
     record t ~conn:conn.id (Event.make "error" [ "reason", `String reason ]));
  match !transport with
  | None -> return ()
  | Some net ->
    Clock_ns.with_timeout (Time_ns.Span.of_sec 5.) (net.close ()) |> Deferred.ignore_m
;;

let rec keep_connected t conn backoff =
  if stopped t
  then return ()
  else (
    let at = Rate_limit.reserve t.open_limit ~now_ms:(now_ms ()) ~n:1 in
    let%bind () = wait_ms t (at - now_ms ()) in
    if stopped t
    then return ()
    else (
      let%bind () = attempt t conn backoff in
      let delay = Backoff.failed backoff ~now:(Float.of_int (now_ms ()) /. 1000.) in
      let%bind () = wait_ms t (Float.to_int (delay *. 1000.)) in
      keep_connected t conn backoff))
;;

let ask t ~request ~check =
  match%map Rest.post t.config.rest_url ~body:request with
  | Error failure -> Error (request, failure)
  | Ok response ->
    let recv_ms = now_ms () in
    File_writer.add
      t.writer
      Route.Listings
      ~recv_ms
      (Line.of_listing ~recv_ms ~request ?date:response.date response.body);
    (match check response.body with
     | checked -> Ok checked
     | exception Failure reason ->
       Error
         (request, { Rest.stage = "shape"; bytes = response.bytes; reason; status = None }))
;;

let meta_request dex =
  Yojson.Safe.to_string (`Assoc [ "type", `String "meta"; "dex", `String dex ])
;;

let rec read_metas t dexes ~read =
  match dexes with
  | [] -> return (Ok (List.rev read))
  | dex :: later ->
    (match%bind ask t ~request:(meta_request dex) ~check:(Listings.dex_perps ~dex) with
     | Ok perps -> read_metas t later ~read:(perps :: read)
     | Error _ as failed -> return failed)
;;

let read_listings t =
  let open Deferred.Result.Let_syntax in
  let%bind dexes = ask t ~request:{|{"type":"perpDexs"}|} ~check:Listings.dex_names in
  let%bind universes = read_metas t dexes ~read:[] in
  let%map () = ask t ~request:{|{"type":"spotMeta"}|} ~check:Listings.check_spot_meta in
  List.concat universes
;;

let retry_ms ~interval_ms ~failures =
  let base_ms = Float.of_int (60_000 * (1 lsl Int.min failures 20)) in
  let jittered = base_ms *. (0.8 +. (0.4 *. Random.float 1.)) in
  Int.min interval_ms (Float.to_int jittered)
;;

let rec watch_listings t ~before ~failures =
  if stopped t
  then return ()
  else (
    let%bind read = read_listings t in
    let interval_ms = t.config.listings_interval_s * 1000 in
    match read with
    | Error (request, failure) ->
      record t (Rest.error_event ~request failure);
      let%bind () = wait_ms t (retry_ms ~interval_ms ~failures) in
      watch_listings t ~before ~failures:(failures + 1)
    | Ok perps ->
      let held = Listings.held ~before:(Option.value before ~default:[]) perps in
      let actions =
        match before with
        | None -> Listing_update.first_read t.planner held
        | Some before -> Listing_update.apply t.planner ~before ~after:held
      in
      apply_actions t actions;
      let%bind () = wait_ms t interval_ms in
      watch_listings t ~before:(Some held) ~failures:0)
;;

let run config =
  Random.self_init ();
  let writer = File_writer.create ~root:config.root ~now_ms in
  let t =
    { config
    ; writer
    ; planner =
        Planner.create
          ~connections:config.connections
          ~max_subscriptions:config.max_subscriptions
    ; conns = Array.init config.connections ~f:(fun id -> { id; outbox = None })
    ; open_limit = Rate_limit.create ~limit:30 ~window_ms:60_500
    ; send_limit = Rate_limit.create ~limit:2000 ~window_ms:60_500
    ; stop = Ivar.create ()
    }
  in
  Signal.handle [ Signal.term; Signal.int ] ~f:(fun _ -> Ivar.fill_if_empty t.stop ());
  Clock_ns.every (span_of_ms 100) (fun () -> File_writer.tick writer);
  record t (Event.make "start" []);
  let connections =
    List.map (Array.to_list t.conns) ~f:(fun conn ->
      keep_connected t conn (Backoff.create ~random:(fun () -> Random.float 1.)))
  in
  let listings = watch_listings t ~before:None ~failures:0 in
  let%bind () = Ivar.read t.stop in
  let%bind () =
    Clock_ns.with_timeout
      (Time_ns.Span.of_sec 8.)
      (Deferred.all_unit (listings :: connections))
    |> Deferred.ignore_m
  in
  record t (Event.make "stop" []);
  File_writer.close writer;
  return ()
;;
