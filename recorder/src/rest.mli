(** One REST call whose response is whole, or has failed (RECORDER.md, What it records, item 1; VAULT.md, Limits). *)

type response =
  { body : string (** one strict JSON value, exactly as received *)
  ; bytes : int (** response bytes received (headers and body, decrypted under TLS) *)
  ; date : string option
    (** final response IMF-fixdate [Date] header, if single and valid *)
  }

type failure =
  { stage : string
    (** [connect], [tls], [timeout], [head], [body], [status] or [json]; a caller's own check adds its own *)
  ; bytes : int (** response bytes received before failure *)
  ; reason : string (** in the recorder's words: never quotes a byte of the response *)
  ; status : int option (** the final status, when the stage is [status] *)
  }

(** [post url ~body] sends [body] as an HTTP/1.1 JSON POST on a fresh libcurl handle in a worker thread,
    verifying TLS, disallowing redirects, capping total duration at 30 s and body size at 16 MiB. Succeeds only
    on a final [200] with valid framing ([Content-Length] xor [Transfer-Encoding: chunked]) and one strict RFC 8259
    JSON value of depth at most 64. *)
val post : string -> body:string -> (response, failure) Result.t Async.Deferred.t

(** The [error] event of a failed request: the request body as [request], and the failure's [stage], [bytes] and
    [reason]. [request] must be a JSON text. *)
val error_event : request:string -> failure -> Event.t
