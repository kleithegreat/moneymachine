open Core

let max_buffer_bytes = 1_048_576
let flush_after_ms = 1000
let ms_per_hour = 3_600_000

type buffer =
  { mutable hour : int
  ; mutable oldest_ms : int
  ; lines : Buffer.t
  }

type t =
  { root : string
  ; now_ms : unit -> int
  ; buffers : (Route.t, buffer) Hashtbl.Poly.t
  }

let create ~root ~now_ms = { root; now_ms; buffers = Hashtbl.Poly.create () }

let append_frame path frame =
  Core_unix.mkdir_p (Filename.dirname path);
  let fd = Core_unix.openfile path ~mode:[ O_WRONLY; O_APPEND; O_CREAT ] ~perm:0o644 in
  Exn.protect
    ~finally:(fun () -> Core_unix.close fd)
    ~f:(fun () ->
      let rec write pos =
        if pos < String.length frame
        then (
          let n = Core_unix.single_write_substring fd ~buf:frame ~pos ~len:(String.length frame - pos) in
          write (pos + n))
      in
      write 0)
;;

let flush t route buffer =
  if Buffer.length buffer.lines > 0
  then (
    let recv_ms = buffer.hour * ms_per_hour in
    let path = Hour_path.of_recv ~root:t.root route ~recv_ms in
    append_frame path (Zstd.compress (Buffer.contents buffer.lines));
    Buffer.clear buffer.lines)
;;

let add t route ~recv_ms line =
  let buffer =
    Hashtbl.find_or_add t.buffers route ~default:(fun () ->
      { hour = 0; oldest_ms = 0; lines = Buffer.create 4096 })
  in
  let hour = Int.max buffer.hour (recv_ms / ms_per_hour) in
  if hour > buffer.hour
  then (
    flush t route buffer;
    buffer.hour <- hour);
  if Buffer.length buffer.lines = 0 then buffer.oldest_ms <- t.now_ms ();
  Buffer.add_string buffer.lines line;
  if Buffer.length buffer.lines >= max_buffer_bytes then flush t route buffer
;;

let tick t =
  let now = t.now_ms () in
  Hashtbl.iteri t.buffers ~f:(fun ~key:route ~data:buffer ->
    if Buffer.length buffer.lines > 0 && now - buffer.oldest_ms >= flush_after_ms
    then flush t route buffer)
;;

let flush_all t = Hashtbl.iteri t.buffers ~f:(fun ~key:route ~data:buffer -> flush t route buffer)
let close = flush_all
