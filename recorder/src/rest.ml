open Core
open Async

type response =
  { body : string
  ; bytes : int
  ; date : string option
  }

type failure =
  { stage : string
  ; bytes : int
  ; reason : string
  ; status : int option
  }

let max_body = 16 * 1024 * 1024
let timeout_ms = 30_000

let ca_file () =
  Option.value (Sys.getenv "SSL_CERT_FILE") ~default:"/etc/ssl/certs/ca-certificates.crt"
;;

let is_digits_in s ~pos ~len ~min ~max =
  if pos + len > String.length s
  then false
  else (
    let rec parse i acc =
      if i = len
      then acc >= min && acc <= max
      else (
        let c = s.[pos + i] in
        if Char.is_digit c
        then parse (i + 1) ((acc * 10) + (Char.to_int c - Char.to_int '0'))
        else false)
    in
    parse 0 0)
;;

let weekdays = [ "Mon"; "Tue"; "Wed"; "Thu"; "Fri"; "Sat"; "Sun" ]

let months =
  [ "Jan"; "Feb"; "Mar"; "Apr"; "May"; "Jun"; "Jul"; "Aug"; "Sep"; "Oct"; "Nov"; "Dec" ]
;;

let is_imf_fixdate s =
  String.length s = 29
  && List.mem weekdays (String.sub s ~pos:0 ~len:3) ~equal:String.equal
  && String.is_substring_at s ~pos:3 ~substring:", "
  && is_digits_in s ~pos:5 ~len:2 ~min:1 ~max:31
  && Char.equal s.[7] ' '
  && List.mem months (String.sub s ~pos:8 ~len:3) ~equal:String.equal
  && Char.equal s.[11] ' '
  && is_digits_in s ~pos:12 ~len:4 ~min:1970 ~max:9999
  && Char.equal s.[16] ' '
  && is_digits_in s ~pos:17 ~len:2 ~min:0 ~max:23
  && Char.equal s.[19] ':'
  && is_digits_in s ~pos:20 ~len:2 ~min:0 ~max:59
  && Char.equal s.[22] ':'
  && is_digits_in s ~pos:23 ~len:2 ~min:0 ~max:60
  && String.is_substring_at s ~pos:25 ~substring:" GMT"
;;

let status_of_line line =
  match String.split (String.strip line) ~on:' ' with
  | version :: code :: _
    when String.is_prefix version ~prefix:"HTTP/"
         && String.length code = 3
         && String.for_all code ~f:Char.is_digit -> Int.of_string_opt code
  | _ -> None
;;

let stage_and_reason_of_curl ~head_complete = function
  | Curl.CURLE_OPERATION_TIMEOUTED -> "timeout", "timeout"
  | CURLE_COULDNT_RESOLVE_PROXY | CURLE_COULDNT_RESOLVE_HOST | CURLE_COULDNT_CONNECT ->
    "connect", "connect failed"
  | CURLE_SSL_CONNECT_ERROR
  | CURLE_SSL_PEER_CERTIFICATE
  | CURLE_SSL_CERTPROBLEM
  | CURLE_SSL_CIPHER
  | CURLE_SSL_CACERT
  | CURLE_SSL_CACERT_BADFILE
  | CURLE_SSL_ENGINE_NOTFOUND
  | CURLE_SSL_ENGINE_SETFAILED
  | CURLE_SSL_ENGINE_INITFAILED
  | CURLE_USE_SSL_FAILED
  | CURLE_SSL_SHUTDOWN_FAILED -> "tls", "TLS verification or handshake failed"
  | CURLE_FILESIZE_EXCEEDED -> "head", "response exceeds 16 MiB"
  | CURLE_FTP_WEIRD_SERVER_REPLY ->
    (if head_complete then "body" else "head"), "malformed HTTP response"
  | CURLE_GOT_NOTHING -> "head", "empty HTTP response"
  | CURLE_PARTIAL_FILE -> "body", "truncated response body"
  | CURLE_SEND_ERROR | CURLE_SEND_FAIL_REWIND | CURLE_READ_ERROR ->
    (if head_complete then "body" else "connect"), "send failed"
  | CURLE_RECV_ERROR | CURLE_BAD_CONTENT_ENCODING | CURLE_WRITE_ERROR ->
    (if head_complete then "body" else "head"), "receive failed"
  | _ -> (if head_complete then "body" else "connect"), "request failed"
;;

let perform_sync url ~body =
  let h = Curl.init () in
  let body_buf = Buffer.create 4096 in
  let received_head = ref 0 in
  let head_complete = ref false in
  let current_status = ref 0 in
  let has_content_length = ref false in
  let transfer_encodings = ref [] in
  let dates = ref [] in
  let header_abort = ref None in
  let status_abort = ref None in
  let body_too_large = ref false in
  let on_header line =
    let len = String.length line in
    received_head := !received_head + len;
    if !head_complete
    then len
    else if String.is_prefix line ~prefix:"HTTP/"
    then (
      current_status := Option.value (status_of_line line) ~default:0;
      has_content_length := false;
      transfer_encodings := [];
      dates := [];
      len)
    else if String.equal line "\r\n" || String.equal line "\n"
    then
      if !current_status >= 200
      then (
        head_complete := true;
        if !current_status <> 200
        then (
          status_abort := Some !current_status;
          0)
        else (
          match !has_content_length, List.rev !transfer_encodings with
          | false, [] ->
            header_abort := Some ("head", "announces neither a length nor chunking");
            0
          | true, _ :: _ ->
            header_abort := Some ("head", "announces both a length and chunking");
            0
          | false, [ te ] when String.Caseless.equal te "chunked" -> len
          | false, _ ->
            header_abort := Some ("head", "unsupported transfer coding");
            0
          | true, [] -> len))
      else len
    else (
      (match String.lsplit2 line ~on:':' with
       | None -> ()
       | Some (name, value) ->
         let value = String.strip value in
         if String.Caseless.equal name "content-length"
         then has_content_length := true
         else if String.Caseless.equal name "transfer-encoding"
         then (
           let tokens =
             String.split value ~on:','
             |> List.map ~f:(fun s -> String.strip s)
             |> List.filter ~f:(fun s -> not (String.is_empty s))
           in
           transfer_encodings := List.rev_append tokens !transfer_encodings)
         else if String.Caseless.equal name "date"
         then dates := value :: !dates);
      len)
  in
  let on_write chunk =
    let len = String.length chunk in
    if Buffer.length body_buf + len > max_body
    then (
      body_too_large := true;
      0)
    else (
      Buffer.add_string body_buf chunk;
      len)
  in
  Exn.protect
    ~finally:(fun () -> Curl.cleanup h)
    ~f:(fun () ->
      Curl.set_url h url;
      Curl.set_protocols h [ Curl.CURLPROTO_HTTP; Curl.CURLPROTO_HTTPS ];
      Curl.set_httpversion h Curl.HTTP_VERSION_1_1;
      Curl.set_followlocation h false;
      Curl.set_nosignal h true;
      Curl.set_timeoutms h timeout_ms;
      Curl.set_connecttimeoutms h timeout_ms;
      Curl.set_forbidreuse h true;
      Curl.set_freshconnect h true;
      Curl.set_sslverifypeer h true;
      Curl.set_sslverifyhost h Curl.SSLVERIFYHOST_HOSTNAME;
      if String.is_prefix url ~prefix:"https://" then Curl.set_cainfo h (ca_file ());
      Curl.set_maxfilesizelarge h (Int64.of_int max_body);
      Curl.set_post h true;
      Curl.set_postfields h body;
      Curl.set_postfieldsize h (String.length body);
      Curl.set_httpheader h [ "Content-Type: application/json"; "Expect:" ];
      Curl.set_headerfunction h on_header;
      Curl.set_writefunction h on_write;
      let bytes () = !received_head + Buffer.length body_buf in
      let fail ?status ~stage reason =
        Error { stage; bytes = bytes (); reason; status }
      in
      match Curl.perform h with
      | () ->
        let code = Curl.get_responsecode h in
        if code <> 200
        then fail ~status:code ~stage:"status" (sprintf "HTTP status %d" code)
        else (
          let text = Buffer.contents body_buf in
          match Strict_json.check text with
          | Error why -> fail ~stage:"json" ("not one JSON value: " ^ why)
          | Ok () ->
            let date =
              match !dates with
              | [ d ] when is_imf_fixdate d -> Some d
              | _ -> None
            in
            Ok { body = text; bytes = bytes (); date })
      | exception Curl.CurlException (code, _, _) ->
        (match !status_abort, !header_abort, !body_too_large with
         | Some status, _, _ ->
           fail ~status ~stage:"status" (sprintf "HTTP status %d" status)
         | None, Some (stage, reason), _ -> fail ~stage reason
         | None, None, true -> fail ~stage:"body" "a body of more than 16 MiB"
         | None, None, false ->
           let stage, reason =
             stage_and_reason_of_curl ~head_complete:!head_complete code
           in
           fail ~stage reason))
;;

let post url ~body =
  Stdlib.Sys.set_signal Stdlib.Sys.sigpipe Stdlib.Sys.Signal_ignore;
  In_thread.run (fun () -> perform_sync url ~body)
;;

let error_event ~request (failure : failure) =
  Event.make
    "error"
    [ "request", Yojson.Safe.from_string request
    ; "stage", `String failure.stage
    ; "bytes", `Int failure.bytes
    ; "reason", `String failure.reason
    ]
;;
