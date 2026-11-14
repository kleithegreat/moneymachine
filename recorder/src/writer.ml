open Core

let max_buffer_bytes = 1_048_576
let flush_after_ms = 1000
let ms_per_hour = 3_600_000

type file =
  { fd : Core_unix.File_descr.t
  ; compressor : Zstd.compressor
  }

type buffer =
  { mutable hour : int
  ; mutable oldest_ms : int
  ; lines : Buffer.t
  ; mutable file : file option
  }

type t =
  { root : string
  ; run : int
  ; now_ms : unit -> int
  ; buffers : (Route.t, buffer) Hashtbl.Poly.t
  }

let create ~root ~now_ms = { root; run = now_ms (); now_ms; buffers = Hashtbl.Poly.create () }

let write_all fd data =
  let rec write pos =
    if pos < String.length data
    then (
      let n = Core_unix.single_write_substring fd ~buf:data ~pos ~len:(String.length data - pos) in
      write (pos + n))
  in
  write 0
;;

let open_file t route buffer =
  let path = Hour_path.of_recv ~root:t.root route ~run:t.run ~recv_ms:(buffer.hour * ms_per_hour) in
  Core_unix.mkdir_p (Filename.dirname path);
  let fd = Core_unix.openfile path ~mode:[ O_WRONLY; O_APPEND; O_CREAT ] ~perm:0o644 in
  { fd; compressor = Zstd.compressor () }
;;

let flush t route buffer ~ending =
  match buffer.file, Buffer.length buffer.lines with
  | None, 0 -> ()
  | file, _ ->
    let file =
      match file with
      | Some file -> file
      | None ->
        let file = open_file t route buffer in
        buffer.file <- Some file;
        file
    in
    write_all file.fd (Zstd.compress file.compressor (Buffer.contents buffer.lines) ~ending);
    Buffer.clear buffer.lines;
    if ending
    then (
      Core_unix.close file.fd;
      buffer.file <- None)
;;

let add t route ~recv_ms line =
  let buffer =
    Hashtbl.find_or_add t.buffers route ~default:(fun () ->
      { hour = 0; oldest_ms = 0; lines = Buffer.create 4096; file = None })
  in
  let hour = Int.max buffer.hour (recv_ms / ms_per_hour) in
  if hour > buffer.hour
  then (
    flush t route buffer ~ending:true;
    buffer.hour <- hour);
  if Buffer.length buffer.lines = 0 then buffer.oldest_ms <- t.now_ms ();
  Buffer.add_string buffer.lines line;
  if Buffer.length buffer.lines >= max_buffer_bytes then flush t route buffer ~ending:false
;;

let tick t =
  let now = t.now_ms () in
  Hashtbl.iteri t.buffers ~f:(fun ~key:route ~data:buffer ->
    if Buffer.length buffer.lines > 0 && now - buffer.oldest_ms >= flush_after_ms
    then flush t route buffer ~ending:false)
;;

let close t = Hashtbl.iteri t.buffers ~f:(fun ~key:route ~data:buffer -> flush t route buffer ~ending:true)
