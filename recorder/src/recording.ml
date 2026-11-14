open Core

let chunk_bytes = 65536

let fold_lines path ~init ~f =
  In_channel.with_file path ~f:(fun ic ->
    let reading = Zstd.reader () in
    let input = Bytes.create chunk_bytes in
    let partial = Buffer.create 4096 in
    let acc = ref init in
    let feed_lines content =
      let rec go start =
        match String.index_from content start '\n' with
        | None -> Buffer.add_substring partial content ~pos:start ~len:(String.length content - start)
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
      then not (Zstd.at_frame_end reading)
      else (
        match Zstd.feed reading (Bytes.To_string.sub input ~pos:0 ~len:n) ~f:feed_lines with
        | () -> read ()
        | exception _ -> true)
    in
    let truncated = read () in
    !acc, truncated)
;;
