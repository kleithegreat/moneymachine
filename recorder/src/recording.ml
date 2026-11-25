open Core

type state =
  | Complete
  | Cut
  | Malformed
  | Corrupt
[@@deriving sexp_of, compare, equal]

let state_to_string = function
  | Complete -> "complete"
  | Cut -> "cut"
  | Malformed -> "malformed"
  | Corrupt -> "corrupt"
;;

let worst_state a b = if compare_state a b >= 0 then a else b
let chunk_bytes = 65536
let zstd_magic = "\x28\xb5\x2f\xfd"

let has_valid_magic_prefix buf ~len =
  let check_len = Int.min len 4 in
  let rec go i =
    if i >= check_len
    then true
    else if Char.equal (Bytes.get buf i) zstd_magic.[i]
    then go (i + 1)
    else false
  in
  go 0
;;

let inspect_stream path =
  In_channel.with_file path ~f:(fun ic ->
    let reading = Zstd.reader () in
    let input = Bytes.create chunk_bytes in
    let saw_compressed = ref false in
    let checked_magic = ref false in
    let magic_ok = ref true in
    let saw_decompressed = ref false in
    let ends_with_nl = ref false in
    let observe chunk =
      let len = String.length chunk in
      if len > 0
      then (
        saw_decompressed := true;
        ends_with_nl := Char.equal chunk.[len - 1] '\n')
    in
    let rec read () =
      let n = In_channel.input ic ~buf:input ~pos:0 ~len:chunk_bytes in
      if n = 0
      then
        if not !saw_compressed
        then Cut
        else if not !magic_ok
        then Corrupt
        else if not (Zstd.at_frame_end reading)
        then Cut
        else if (not !saw_decompressed) || not !ends_with_nl
        then Malformed
        else Complete
      else (
        saw_compressed := true;
        if not !checked_magic
        then (
          checked_magic := true;
          magic_ok := has_valid_magic_prefix input ~len:n);
        if not !magic_ok
        then Corrupt
        else (
          match
            Zstd.feed reading (Bytes.To_string.sub input ~pos:0 ~len:n) ~f:observe
          with
          | () -> read ()
          | exception Zstd.Error _ -> Corrupt))
    in
    read ())
;;

let emit_lines path ~init ~f =
  In_channel.with_file path ~f:(fun ic ->
    let reading = Zstd.reader () in
    let input = Bytes.create chunk_bytes in
    let partial = Buffer.create 4096 in
    let acc = ref init in
    let feed_lines content =
      let rec go start =
        match String.index_from content start '\n' with
        | None ->
          Buffer.add_substring
            partial
            content
            ~pos:start
            ~len:(String.length content - start)
        | Some stop ->
          Buffer.add_substring partial content ~pos:start ~len:(stop - start);
          let line = Buffer.contents partial in
          Buffer.clear partial;
          acc := f !acc line;
          go (stop + 1)
      in
      go 0
    in
    let rec read () =
      let n = In_channel.input ic ~buf:input ~pos:0 ~len:chunk_bytes in
      if n = 0
      then !acc
      else (
        Zstd.feed reading (Bytes.To_string.sub input ~pos:0 ~len:n) ~f:feed_lines;
        read ())
    in
    read ())
;;

let fold_lines path ~init ~f =
  let state = inspect_stream path in
  match state with
  | Corrupt -> init, Corrupt
  | Complete | Cut | Malformed -> emit_lines path ~init ~f, state
;;
