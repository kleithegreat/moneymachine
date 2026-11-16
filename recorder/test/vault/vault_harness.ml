(* Shared support for the vault collector's end-to-end tests (recorder/VAULT.md, Tests).

   INTERFACE ASSUMED OF THE BUILDER:
   - the executable [recorder/bin/mmvault.exe], run as
       [mmvault run ROOT --user ADDRESS --rest-url URL --now-ms MS]
     and exiting 0 when every pull completed, 1 otherwise;
   - [ROOT/vault/ADDRESS/state.json], a JSON object with the integer field ["watermark_ms"] (milliseconds since
     the epoch); absent, or equal to [nov 1 0 0], means the watermark has not moved;
   - an event line is a JSON object carrying the event's fields, with ["event"] naming it, either as the line's
     ["msg"] or at the line's top level; [pull] events have ["kind"], ["from_ms"], ["to_ms"], ["pages"], ["items"],
     ["new"] (integers) and ["complete"] (boolean);
   - a response line holds the response as ["msg"]; its path sorts in time order, as the recorder's do (the run
     in [<HH>.<run>.jsonl.zst] being the run's real start in ms);
   - a run's events are those from the last [start] event on;
   - "stores nothing new" is judged by item identity (a page of duplicates is still stored, VAULT.md), and a fills
     pull's [new] counts the identities it added. *)

open Core
open Async
module H = Rec_support.Harness
module U = Yojson.Safe.Util

let user = "0x53375ca9a649f337d83d0834fec0db97640a2a06"
let minute = 60_000
let hour = 3_600_000
let day = 86_400_000
let nov_1 = 1_793_491_200_000

(* [nov d h m]: day [d] of November 2026 (days past 30 run on into December) at [h]:[m] UTC, in ms. *)
let nov d h m = nov_1 + ((d - 1) * day) + (h * hour) + (m * minute)
let fills_cap = 2000
let funding_cap = 500
let px = "7391.8265"
let sz = "0.4172653"
let fee = "0.0018273649"
let funding_rate = "0.00004718293"
let usdc = "5826.3174"
let szi = "-3.9140627"
let closed_pnl = "-41.7305928"
let limit_px = "6238.4417"
let cross_rate = "0.00047193"
let add_rate = "0.00031827"
let sentinels = [ px; sz; fee; funding_rate; usdc; szi; closed_pnl; limit_px; cross_rate; add_rate ]

type fill =
  { tid : int
  ; time : int
  ; mutable visible : bool
  }

type funding_row =
  { coin : string
  ; ftime : int
  ; mutable fvisible : bool
  }

type behaviour =
  | Normal
  | Reply of int * string

type request =
  { kind : string
  ; body : Yojson.Safe.t
  ; start_ms : int option
  ; end_ms : int option
  ; returned : int
  ; status : int
  }

type t =
  { port : int
  ; stop_server : unit -> unit Deferred.t
  ; mutable fills : fill list
  ; mutable funding : funding_row list
  ; mutable behave : kind:string -> nth:int -> Yojson.Safe.t -> behaviour
  ; mutable log : request list
  ; on_request : request_start:int option -> kind:string -> unit
  }

let fill_json f =
  sprintf
    {|{"coin":"ETH","px":"%s","sz":"%s","side":"B","time":%d,"startPosition":"%s","dir":"Open Long","closedPnl":"%s","hash":"0x%016x","oid":%d,"crossed":true,"fee":"%s","tid":%d,"feeToken":"USDC"}|}
    px
    sz
    f.time
    szi
    closed_pnl
    f.tid
    f.tid
    fee
    f.tid
;;

let funding_json r =
  sprintf
    {|{"time":%d,"hash":"0x00","delta":{"type":"funding","coin":"%s","usdc":"%s","szi":"%s","fundingRate":"%s","nSamples":null}}|}
    r.ftime
    r.coin
    usdc
    szi
    funding_rate
;;

let fees_json =
  sprintf
    {|{"dailyUserVlm":[],"feeSchedule":{"cross":"%s","add":"%s"},"userCrossRate":"%s","userAddRate":"%s","activeReferralDiscount":"0.0"}|}
    cross_rate
    add_rate
    cross_rate
    add_rate
;;

let orders_json =
  sprintf
    {|[{"order":{"coin":"ETH","side":"B","limitPx":"%s","sz":"%s","oid":1,"timestamp":1},"status":"filled","statusTimestamp":2}]|}
    limit_px
    sz
;;

let array_json items = "[" ^ String.concat ~sep:"," items ^ "]"

let window items ~time ~compare ~start ~end_ ~cap =
  List.filter items ~f:(fun item ->
    let at = time item in
    at >= start && at <= end_)
  |> List.sort ~compare
  |> fun sorted -> List.take sorted cap
;;

let serve_normal t ~kind ~start ~end_ =
  match kind with
  | "userFillsByTime" ->
    let visible = List.filter t.fills ~f:(fun f -> f.visible) in
    let compare a b = [%compare: int * int] (a.time, a.tid) (b.time, b.tid) in
    let page = window visible ~time:(fun f -> f.time) ~compare ~start ~end_ ~cap:fills_cap in
    List.length page, array_json (List.map page ~f:fill_json)
  | "userFunding" ->
    let visible = List.filter t.funding ~f:(fun r -> r.fvisible) in
    let compare a b = [%compare: int * string] (a.ftime, a.coin) (b.ftime, b.coin) in
    let page = window visible ~time:(fun r -> r.ftime) ~compare ~start ~end_ ~cap:funding_cap in
    List.length page, array_json (List.map page ~f:funding_json)
  | "userFees" -> 1, fees_json
  | "historicalOrders" -> 1, orders_json
  | other -> failwithf "unexpected request type %s" other ()
;;

let answer t body =
  let json = Yojson.Safe.from_string body in
  let kind = U.to_string (U.member "type" json) in
  let start_ms = U.to_int_option (U.member "startTime" json) in
  let end_ms = U.to_int_option (U.member "endTime" json) in
  t.on_request ~request_start:start_ms ~kind;
  let nth = List.count t.log ~f:(fun r -> String.equal r.kind kind) in
  let status, returned, text =
    match t.behave ~kind ~nth json with
    | Reply (status, text) -> status, 0, text
    | Normal ->
      let start = Option.value start_ms ~default:0 in
      let end_ = Option.value end_ms ~default:Int.max_value in
      let returned, text = serve_normal t ~kind ~start ~end_ in
      200, returned, text
  in
  t.log <- t.log @ [ { kind; body = json; start_ms; end_ms; returned; status } ];
  status, text
;;

let read_body reader =
  let rec headers length =
    match%bind Reader.read_line reader with
    | `Eof -> return length
    | `Ok line ->
      let line = String.strip line in
      if String.is_empty line
      then return length
      else (
        match String.lsplit2 line ~on:':' with
        | Some (key, value) when String.equal (String.lowercase key) "content-length" ->
          headers (Int.of_string (String.strip value))
        | _ -> headers length)
  in
  let%bind _request_line = Reader.read_line reader in
  let%bind length = headers 0 in
  let buffer = Bytes.create length in
  let%map _ = Reader.really_read reader buffer in
  Bytes.to_string buffer
;;

(** A fake [info] endpoint on a free local port. [on_request] runs as each request arrives, before it is answered. *)
let start ?(on_request = fun ~request_start:_ ~kind:_ -> ()) () =
  let t_ref = ref None in
  let handler reader writer =
    let%bind body = read_body reader in
    let t = Option.value_exn !t_ref in
    let status, text = answer t body in
    Writer.write
      writer
      (sprintf
         "HTTP/1.1 %d X\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
         status
         (String.length text)
         text);
    Writer.close writer
  in
  let where = Tcp.Where_to_listen.bind_to Localhost On_port_chosen_by_os in
  let%map server = Tcp.Server.create ~on_handler_error:`Ignore where (fun _ r w -> handler r w) in
  let t =
    { port = Tcp.Server.listening_on server
    ; stop_server = (fun () -> Tcp.Server.close server)
    ; fills = []
    ; funding = []
    ; behave = (fun ~kind:_ ~nth:_ _ -> Normal)
    ; log = []
    ; on_request
    }
  in
  t_ref := Some t;
  t
;;

let stop t = t.stop_server ()
let set_behaviour t behave = t.behave <- behave
let rest_url t = sprintf "http://127.0.0.1:%d/info" t.port
let add_fill t ~tid ~time ~visible = t.fills <- { tid; time; visible } :: t.fills
let add_funding t ~coin ~time ~visible = t.funding <- { coin; ftime = time; fvisible = visible } :: t.funding

let reveal t =
  List.iter t.fills ~f:(fun f -> f.visible <- true);
  List.iter t.funding ~f:(fun r -> r.fvisible <- true)
;;

(** The requests of one kind ([userFillsByTime], [userFunding], [userFees], [historicalOrders]), in order. *)
let requests t ~kind = List.filter t.log ~f:(fun r -> String.equal r.kind kind)

let forget_requests t = t.log <- []

(* Running the collector. *)

type outcome =
  { exit_code : int
  ; output : string
  }

let mmvault_exe = "../../bin/mmvault.exe"

let args ~root ~fake ~now_ms =
  [ "run"; root; "--user"; user; "--rest-url"; rest_url fake; "--now-ms"; Int.to_string now_ms ]
;;

let run ~root ~fake ~now_ms =
  let%bind process = Process.create_exn ~prog:mmvault_exe ~args:(args ~root ~fake ~now_ms) () in
  match%map Clock.with_timeout (Time_float.Span.of_sec 900.) (Process.collect_output_and_wait process) with
  | `Timeout -> failwith "mmvault run did not finish in 900 s"
  | `Result output ->
    let exit_code =
      match output.exit_status with
      | Ok () -> 0
      | Error (`Exit_non_zero n) -> n
      | Error (`Signal _) -> -1
    in
    { exit_code; output = output.stdout ^ output.stderr }
;;

let spawn ~root ~fake ~now_ms =
  let%map process = Process.create_exn ~prog:mmvault_exe ~args:(args ~root ~fake ~now_ms) () in
  don't_wait_for (Reader.drain (Process.stdout process));
  don't_wait_for (Reader.drain (Process.stderr process));
  process
;;

let kill process =
  H.send_signal process Signal.kill;
  let%map _ = Process.wait process in
  ()
;;

(* Reading what it stored. *)

let vault_dir root = Filename.concat (Filename.concat root "vault") user

let files ~root kind = H.recordings (Filename.concat (vault_dir root) kind)

let lines_of_file path =
  H.zstd_lenient_decode path
  |> String.split_lines
  |> List.filter ~f:(fun l -> not (String.is_empty l))
  |> List.map ~f:Yojson.Safe.from_string
;;

let kind_lines ~root kind = List.concat_map (files ~root kind) ~f:lines_of_file
let raw_text ~root kind = String.concat (List.map (files ~root kind) ~f:H.zstd_lenient_decode)
let msgs ~root kind = List.map (kind_lines ~root kind) ~f:(U.member "msg")

let stored_tids ~root =
  List.concat_map (msgs ~root "fills") ~f:(fun msg ->
    List.map (U.to_list msg) ~f:(fun item -> U.to_int (U.member "tid" item)))
  |> List.dedup_and_sort ~compare:Int.compare
;;

let stored_funding ~root =
  List.concat_map (msgs ~root "funding") ~f:(fun msg ->
    List.map (U.to_list msg) ~f:(fun item ->
      U.to_string (U.member "coin" (U.member "delta" item)), U.to_int (U.member "time" item)))
  |> List.dedup_and_sort ~compare:[%compare: string * int]
;;

type event =
  { name : string
  ; json : Yojson.Safe.t
  }

let event_of_line line =
  let inner = U.member "msg" line in
  let json =
    match U.member "event" inner with
    | `String _ -> inner
    | _ -> line
  in
  { name = U.to_string (U.member "event" json); json }
;;

let all_events ~root = List.map (kind_lines ~root "events") ~f:event_of_line

(** The events of the latest run: from its [start] on. *)
let last_run_events ~root =
  let events = all_events ~root in
  let rec from_last_start acc = function
    | [] -> acc
    | e :: rest -> from_last_start (if String.equal e.name "start" then e :: rest else acc) rest
  in
  from_last_start [] events
;;

let named events name = List.filter events ~f:(fun e -> String.equal e.name name)

let pulls events ~kind =
  named events "pull" |> List.filter ~f:(fun e -> String.equal (U.to_string (U.member "kind" e.json)) kind)
;;

let field_int e name = U.to_int (U.member name e.json)

(** The sum of [new] over a run's pulls of one kind. *)
let new_total events ~kind = List.sum (module Int) (pulls events ~kind) ~f:(fun e -> field_int e "new")

let state_path root = Filename.concat (vault_dir root) "state.json"

let state_json root =
  if Stdlib.Sys.file_exists (state_path root) then Some (Yojson.Safe.from_file (state_path root)) else None
;;

(** The stored watermark; [nov 1 0 0] when no state has been written. *)
let watermark root =
  match state_json root with
  | None -> nov 1 0 0
  | Some json -> U.to_int (U.member "watermark_ms" json)
;;

let check_exit outcome ~expected what =
  H.check (outcome.exit_code = expected) (sprintf "%s: exit code %d, expected %d" what outcome.exit_code expected)
;;

(** After any number of kills: every stored line whole (the readers drop one truncated last line) and parseable,
    and [state.json], if there, a valid object. *)
let check_integrity ~root what =
  List.iter [ "fills"; "funding"; "fees"; "orders"; "events" ] ~f:(fun kind ->
    List.iter (files ~root kind) ~f:(fun path ->
      match lines_of_file path with
      | (_ : Yojson.Safe.t list) -> ()
      | exception exn -> failwithf "%s: %s is damaged: %s" what path (Exn.to_string exn) ()));
  match state_json root with
  | None -> ()
  | Some (`Assoc _) -> ()
  | Some _ -> failwithf "%s: state.json is not an object" what ()
  | exception exn -> failwithf "%s: state.json is unreadable: %s" what (Exn.to_string exn) ()
;;
