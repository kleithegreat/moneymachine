open Core
module File_writer = Writer
open Async
module U = Yojson.Safe.Util

type config =
  { root : string
  ; user : string
  ; rest_url : string
  ; now_ms : int
  }

type kind =
  | Fills
  | Funding

let first_ms = 1_793_491_200_000
let day_ms = 86_400_000
let overlap_ms = 3_600_000
let reread_days = 30
let alarm_fills = 5000
let pace_s = 1.
let max_retries = 5

let kind_name = function
  | Fills -> "fills"
  | Funding -> "funding"
;;

let cap = function
  | Fills -> 2000
  | Funding -> 500
;;

let request_body kind ~user ~start ~end_ =
  let type_, fields =
    match kind with
    | Fills -> "userFillsByTime", [ "endTime", `Int end_; "aggregateByTime", `Bool false ]
    | Funding -> "userFunding", []
  in
  Yojson.Safe.to_string
    (`Assoc
        ([ "type", `String type_; "user", `String user; "startTime", `Int start ] @ fields))
;;

let identity kind item =
  match kind with
  | Fills -> Int.to_string (U.to_int (U.member "tid" item))
  | Funding ->
    sprintf
      "%s@%d"
      (U.to_string (U.member "coin" (U.member "delta" item)))
      (U.to_int (U.member "time" item))
;;

let vault_dir config = String.concat ~sep:"/" [ config.root; "vault"; config.user ]
let state_path config = Filename.concat (vault_dir config) "state.json"
let route config name = Route.Dir (sprintf "vault/%s/%s" config.user name)

type state =
  { watermark_ms : int
  ; last_daily_ms : int option
  }

let read_state config =
  if not (Sys_unix.file_exists_exn (state_path config))
  then { watermark_ms = first_ms; last_daily_ms = None }
  else (
    let json = Yojson.Safe.from_file (state_path config) in
    { watermark_ms = U.to_int (U.member "watermark_ms" json)
    ; last_daily_ms = U.to_int_option (U.member "last_daily_ms" json)
    })
;;

let write_state config state =
  let json =
    `Assoc
      [ "watermark_ms", `Int state.watermark_ms
      ; ( "last_daily_ms"
        , Option.value_map state.last_daily_ms ~default:`Null ~f:(fun ms -> `Int ms) )
      ]
  in
  let temporary = state_path config ^ ".tmp" in
  Core_unix.mkdir_p (vault_dir config);
  Out_channel.write_all temporary ~data:(Yojson.Safe.to_string json);
  Core_unix.rename ~src:temporary ~dst:(state_path config)
;;

type t =
  { config : config
  ; writer : File_writer.t
  ; backoff : Backoff.t
  ; mutable last_request_s : float
  }

let record t name json = File_writer.add t.writer name ~recv_ms:t.config.now_ms json

let event_of t made =
  let line = Event.to_line ~recv_ms:t.config.now_ms ~conn:None made in
  record t (route t.config "events") line
;;

let event t name fields = event_of t (Event.make name fields)

let add_line_identities kind seen line =
  match
    List.map
      (U.to_list (U.member "msg" (Yojson.Safe.from_string line)))
      ~f:(identity kind)
  with
  | identities ->
    List.iter identities ~f:(Hash_set.add seen);
    None
  | exception Yojson.Json_error _ -> Some "unparseable line"
  | exception U.Type_error _ -> Some "unexpected shape"
;;

let stored_identities t kind =
  let seen = String.Hash_set.create () in
  let dir = Filename.concat (vault_dir t.config) (kind_name kind) in
  List.iter (Integrity.list_dir dir) ~f:(fun date ->
    List.iter
      (Integrity.list_dir (Filename.concat dir date))
      ~f:(fun name ->
        if Option.is_some (Integrity.hour_and_run_of_name name)
        then (
          let path = String.concat ~sep:"/" [ dir; date; name ] in
          let parse_failure, stream_state =
            Recording.fold_lines path ~init:None ~f:(fun err line ->
              match err with
              | Some _ -> err
              | None -> add_line_identities kind seen line)
          in
          let failure =
            match stream_state, parse_failure with
            | Corrupt, _ -> Some "corrupt stream"
            | Malformed, None -> Some "malformed stream"
            | (Complete | Cut | Malformed), (Some _ as err) -> err
            | (Complete | Cut), None -> None
          in
          Option.iter failure ~f:(fun reason ->
            event t "error" [ "file", `String path; "reason", `String reason ]))));
  seen
;;

let fail t ~body failure =
  event_of t (Rest.error_event ~request:body failure);
  return (Error ())
;;

let shape_failure (response : Rest.response) =
  { Rest.stage = "shape"
  ; bytes = response.bytes
  ; reason = "unexpected shape"
  ; status = None
  }
;;

let pace t =
  let wait_s = pace_s -. (Core_unix.gettimeofday () -. t.last_request_s) in
  let%map () =
    if Float.( > ) wait_s 0. then after (Time_float.Span.of_sec wait_s) else return ()
  in
  t.last_request_s <- Core_unix.gettimeofday ()
;;

let post t ~body =
  let rec attempt retries =
    let%bind () = pace t in
    match%bind Rest.post t.config.rest_url ~body with
    | Error { Rest.status = Some 429; _ } when retries < max_retries ->
      let delay = Backoff.failed t.backoff ~now:(Core_unix.gettimeofday ()) in
      let%bind () = after (Time_float.Span.of_sec delay) in
      attempt (retries + 1)
    | Error failure -> fail t ~body failure
    | Ok response -> return (Ok response)
  in
  attempt 0
;;

let store t name ~body (response : Rest.response) =
  record
    t
    (route t.config name)
    (Line.of_response
       ~recv_ms:t.config.now_ms
       ~request:body
       ?date:response.date
       response.body)
;;

type pulled =
  { complete : bool
  ; distinct : int
  }

let pull t kind ~seen ~from_ ~to_ =
  let name = kind_name kind in
  let distinct = String.Hash_set.create () in
  let pages = ref 0 in
  let fresh = ref 0 in
  let rec page start =
    let body = request_body kind ~user:t.config.user ~start ~end_:to_ in
    match%bind post t ~body with
    | Error () -> return false
    | Ok response ->
      (match
         let items = U.to_list (Yojson.Safe.from_string response.body) in
         List.map items ~f:(fun item ->
           identity kind item, U.to_int (U.member "time" item))
       with
       | exception U.Type_error _ ->
         let%map (_ : (unit, unit) Result.t) = fail t ~body (shape_failure response) in
         false
       | exception Yojson.Json_error _ ->
         let%map (_ : (unit, unit) Result.t) = fail t ~body (shape_failure response) in
         false
       | items ->
         store t name ~body response;
         incr pages;
         List.iter items ~f:(fun (id, _) ->
           Hash_set.add distinct id;
           if not (Hash_set.mem seen id)
           then (
             Hash_set.add seen id;
             incr fresh));
         let last_time = Option.value_map (List.last items) ~default:start ~f:snd in
         if List.length items < cap kind
         then return true
         else if last_time = start
         then (
           event t "stuck" [ "kind", `String name; "start_ms", `Int start ];
           return false)
         else page last_time)
  in
  let%map complete = page from_ in
  event
    t
    "pull"
    [ "kind", `String name
    ; "from_ms", `Int from_
    ; "to_ms", `Int to_
    ; "pages", `Int !pages
    ; "items", `Int (Hash_set.length distinct)
    ; "new", `Int !fresh
    ; "complete", `Bool complete
    ];
  { complete; distinct = Hash_set.length distinct }
;;

let single t name ~type_ =
  let now = t.config.now_ms in
  let body =
    Yojson.Safe.to_string
      (`Assoc [ "type", `String type_; "user", `String t.config.user ])
  in
  let%map complete =
    match%map post t ~body with
    | Error () -> false
    | Ok response ->
      store t name ~body response;
      true
  in
  event
    t
    "pull"
    [ "kind", `String name
    ; "from_ms", `Int now
    ; "to_ms", `Int now
    ; "pages", `Int (Bool.to_int complete)
    ; "items", `Int (Bool.to_int complete)
    ; "new", `Int (Bool.to_int complete)
    ; "complete", `Bool complete
    ];
  complete
;;

let run config =
  let now = config.now_ms in
  let state = read_state config in
  let real_ms () = Time_ns.to_int_ns_since_epoch (Time_ns.now ()) / 1_000_000 in
  let t =
    { config
    ; writer = File_writer.create ~root:config.root ~now_ms:real_ms
    ; backoff = Backoff.create ~random:(fun () -> Random.float 1.)
    ; last_request_s = 0.
    }
  in
  event
    t
    "start"
    [ "user", `String config.user
    ; "now", `Int now
    ; "overlap_ms", `Int overlap_ms
    ; "reread_days", `Int reread_days
    ];
  let fills_seen = stored_identities t Fills in
  let funding_seen = stored_identities t Funding in
  let%bind hourly =
    pull
      t
      Fills
      ~seen:fills_seen
      ~from_:(Int.max first_ms (state.watermark_ms - overlap_ms))
      ~to_:now
  in
  let due =
    match state.last_daily_ms with
    | None -> true
    | Some last -> now / day_ms > last / day_ms
  in
  let reread () =
    let midnight = now / day_ms * day_ms in
    let reread_ms = reread_days * day_ms in
    let%bind fills =
      pull
        t
        Fills
        ~seen:fills_seen
        ~from_:(Int.max first_ms (state.watermark_ms - reread_ms))
        ~to_:now
    in
    if fills.distinct > alarm_fills
    then
      event
        t
        "alarm"
        [ "reason", `String "daily fills re-read over half the API's retention"
        ; "fills", `Int fills.distinct
        ];
    if not fills.complete
    then return false
    else (
      let%map funding =
        pull
          t
          Funding
          ~seen:funding_seen
          ~from_:(Int.max first_ms (midnight - reread_ms))
          ~to_:now
      in
      funding.complete)
  in
  let%bind daily = if hourly.complete && due then reread () else return (not due) in
  let%bind ok =
    if not (hourly.complete && daily)
    then return false
    else (
      match%bind single t "fees" ~type_:"userFees" with
      | true -> single t "orders" ~type_:"historicalOrders"
      | false -> return false)
  in
  event t "stop" [ "ok", `Bool ok ];
  File_writer.close t.writer;
  write_state
    config
    { watermark_ms = (if hourly.complete then now else state.watermark_ms)
    ; last_daily_ms = (if due && daily then Some now else state.last_daily_ms)
    };
  return ok
;;
