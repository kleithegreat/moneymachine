open Core

exception Zstd_error of string

let () = Stdlib.Callback.register_exception "mmfabric.zstd.error" (Zstd_error "")

external zstd_compress : string -> int -> string = "mmfabric_zstd_compress"
external zstd_decompress : string -> string = "mmfabric_zstd_decompress"

type record =
  { sha256 : string
  ; uri : string
  ; byte_size : int
  ; compressed_size : int
  ; existed : bool
  }
[@@deriving sexp_of, equal]

let sha256_hex s = Digestif.SHA256.(digest_string s |> to_hex)
let is_lower_hex c = Char.is_digit c || (Char.( >= ) c 'a' && Char.( <= ) c 'f')

let validate_digest digest =
  let norm = String.lowercase digest in
  if String.length norm = 64 && String.for_all norm ~f:is_lower_hex
  then Ok norm
  else Error (sprintf "invalid SHA-256 digest: %S" digest)
;;

let join_parts parts ~init = List.fold parts ~init ~f:Filename.concat

let path_for ~root ~digest =
  match validate_digest digest with
  | Error _ as err -> err
  | Ok norm ->
    let p1 = String.sub norm ~pos:0 ~len:2 in
    let p2 = String.sub norm ~pos:2 ~len:2 in
    Ok (join_parts [ "cas"; "sha256"; p1; p2; norm ^ ".zst" ] ~init:root)
;;

let abs_path path =
  if Filename.is_relative path then Filename.concat (Core_unix.getcwd ()) path else path
;;

let uri_for ?uri_prefix ~root digest =
  match validate_digest digest with
  | Error _ as err -> err
  | Ok norm ->
    let p1 = String.sub norm ~pos:0 ~len:2 in
    let p2 = String.sub norm ~pos:2 ~len:2 in
    (match uri_prefix with
     | Some prefix ->
       let clean = String.rstrip prefix ~drop:(Char.equal '/') in
       Ok (sprintf "%s/%s/%s/%s.zst" clean p1 p2 norm)
     | None ->
       let abs_root = abs_path root in
       let abs_file =
         join_parts [ "cas"; "sha256"; p1; p2; norm ^ ".zst" ] ~init:abs_root
       in
       Ok ("file://" ^ abs_file))
;;

let exists ~root ~digest =
  match path_for ~root ~digest with
  | Error _ -> false
  | Ok path ->
    (match Sys_unix.file_exists ~follow_symlinks:true path with
     | `Yes -> true
     | `No | `Unknown -> false)
;;

let decompress_checked ~digest blob =
  try
    let raw = zstd_decompress blob in
    let actual = sha256_hex raw in
    if String.equal actual digest
    then Ok raw
    else Error (sprintf "CAS integrity mismatch for %s: got %s" digest actual)
  with
  | Zstd_error msg -> Error (sprintf "zstd error for %s: %s" digest msg)
;;

let quarantine_corrupt path =
  let bad = In_channel.read_all path in
  let bad_prefix = String.prefix (sha256_hex bad) 16 in
  let damaged = sprintf "%s.damaged-%s" path bad_prefix in
  Core_unix.rename ~src:path ~dst:damaged
;;

let put ?uri_prefix ?(level = 9) ~root raw =
  let digest = sha256_hex raw in
  match path_for ~root ~digest, uri_for ?uri_prefix ~root digest with
  | Error msg, _ | _, Error msg -> Error msg
  | Ok dest, Ok uri ->
    (try
       let already_valid =
         match Sys_unix.file_exists ~follow_symlinks:true dest with
         | `No | `Unknown -> None
         | `Yes ->
           let blob = In_channel.read_all dest in
           (match decompress_checked ~digest blob with
            | Ok _ -> Some (String.length blob)
            | Error _ ->
              quarantine_corrupt dest;
              None)
       in
       match already_valid with
       | Some compressed_size ->
         Ok
           { sha256 = digest
           ; uri
           ; byte_size = String.length raw
           ; compressed_size
           ; existed = true
           }
       | None ->
         let parent = Filename.dirname dest in
         Core_unix.mkdir_p parent;
         let compressed = zstd_compress raw level in
         let pid = Core_unix.getpid () |> Pid.to_int in
         let tmp =
           Filename.concat parent (sprintf ".%s.%d.tmp" (Filename.basename dest) pid)
         in
         Out_channel.write_all tmp ~data:compressed;
         Core_unix.rename ~src:tmp ~dst:dest;
         Ok
           { sha256 = digest
           ; uri
           ; byte_size = String.length raw
           ; compressed_size = String.length compressed
           ; existed = false
           }
     with
     | Zstd_error msg -> Error (sprintf "zstd compression failed: %s" msg)
     | Sys_error msg -> Error msg
     | Core_unix.Unix_error (err, fn, arg) ->
       Error (sprintf "%s(%s): %s" fn arg (Core_unix.Error.message err)))
;;

let get ~root digest =
  match path_for ~root ~digest, validate_digest digest with
  | Error msg, _ | _, Error msg -> Error msg
  | Ok path, Ok norm ->
    (match Sys_unix.file_exists ~follow_symlinks:true path with
     | `No | `Unknown -> Error (sprintf "CAS object not found: %s" norm)
     | `Yes ->
       (try
          let blob = In_channel.read_all path in
          decompress_checked ~digest:norm blob
        with
        | Sys_error msg -> Error msg
        | Core_unix.Unix_error (err, fn, arg) ->
          Error (sprintf "%s(%s): %s" fn arg (Core_unix.Error.message err))))
;;

let verify ~root digest =
  match get ~root digest with
  | Ok _ -> true
  | Error _ -> false
;;

let to_yojson rec_ =
  `Assoc
    [ "sha256", `String rec_.sha256
    ; "uri", `String rec_.uri
    ; "byte_size", `Int rec_.byte_size
    ; "compressed_size", `Int rec_.compressed_size
    ; "existed", `Bool rec_.existed
    ]
;;
