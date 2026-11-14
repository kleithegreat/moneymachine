(* Item 11, last case: [mmrec check] and [mmrec cat] on a file of 1 GiB of lines peak below 128 MiB resident. The
   file is written by the independent [zstd] tool as one stream; the child's peak is its VmHWM, polled from /proc. *)

open Core
open Async
module H = Rec_support.Harness

let limit_kib = 128 * 1024
let lines_per_block = 10_000

let block =
  let rng = Random.State.make [| 11 |] in
  String.concat
    (List.init lines_per_block ~f:(fun i ->
       sprintf
         "{\"recv\":%d,\"conn\":1,\"msg\":{\"channel\":\"trades\",\"data\":[{\"coin\":\"BTC\",\"px\":\"%d.%d\",\"sz\":\"%d\",\"tid\":%d}]}}\n"
         (1794650400000 + i)
         (Random.State.int rng 100_000)
         (Random.State.int rng 1_000_000)
         (Random.State.int rng 1_000)
         (Random.State.int rng 1_000_000_000)))
;;

let blocks = ((1 lsl 30) / String.length block) + 1
let total_bytes = blocks * String.length block
let total_lines = blocks * lines_per_block

let vm_hwm_kib pid =
  match In_channel.read_lines (sprintf "/proc/%d/status" (Pid.to_int pid)) with
  | lines ->
    List.find_map lines ~f:(fun l ->
      if String.is_prefix l ~prefix:"VmHWM:"
      then Some (Int.of_string (String.strip (String.chop_suffix_if_exists (String.chop_prefix_exn l ~prefix:"VmHWM:") ~suffix:"kB")))
      else None)
  | exception _ -> None
;;

let watch_peak process =
  let peak = ref 0 in
  let stop = Ivar.create () in
  let rec poll () =
    if Ivar.is_full stop
    then return ()
    else (
      Option.iter (vm_hwm_kib (Process.pid process)) ~f:(fun kib -> peak := Int.max !peak kib);
      let%bind () = after (Time_float.Span.of_ms 20.) in
      poll ())
  in
  let finished = poll () in
  peak, stop, finished
;;

let count_bytes reader =
  let buffer = Bytes.create 65536 in
  let rec loop total =
    match%bind Reader.read reader buffer with
    | `Eof -> return total
    | `Ok n -> loop (total + n)
  in
  loop 0
;;

let run_measured args ~consume =
  let%bind process = Process.create_exn ~prog:H.mmrec_exe ~args () in
  don't_wait_for (Reader.drain (Process.stderr process));
  let peak, stop, finished = watch_peak process in
  let%bind result = consume (Process.stdout process) in
  let%bind status = Process.wait process in
  Ivar.fill_exn stop ();
  let%map () = finished in
  H.check (Result.is_ok status) "the command failed";
  !peak, result
;;

let () =
  H.main "item 11: check and cat in bounded memory" (fun () ->
    let root = H.tmp_dir () in
    let path = Filename.concat root "trades/20261114/10.jsonl.zst" in
    Core_unix.mkdir_p (Filename.dirname path);
    let command = sprintf "zstd -9 -q --check -f -o %s" (Filename.quote path) in
    let channel = Core_unix.open_process_out command in
    for _ = 1 to blocks do
      Out_channel.output_string channel block
    done;
    H.check (Result.is_ok (Core_unix.close_process_out channel)) "zstd failed writing the 1 GiB file";
    H.check (total_bytes >= 1 lsl 30) "the file is under 1 GiB";
    let%bind peak_check, out =
      run_measured [ "check"; root; "2026111410"; "2026111410" ] ~consume:Reader.contents
    in
    (match H.parse_check out with
     | [ [ "2026111410"; "trades"; bytes; "1"; lines; "no" ] ] ->
       H.check (Int.of_string bytes = Int64.to_int_exn (Core_unix.stat path).st_size) "check's byte count";
       H.check (Int.of_string lines = total_lines) (sprintf "check counts %s lines, expected %d" lines total_lines)
     | _ -> failwithf "unexpected check output: %s" out ());
    H.check (peak_check > 1_000) (sprintf "peak of check not measured (%d kB)" peak_check);
    H.check (peak_check < limit_kib) (sprintf "check peaked at %d kB, limit %d" peak_check limit_kib);
    let%bind peak_cat, bytes = run_measured [ "cat"; path ] ~consume:count_bytes in
    H.check (bytes = total_bytes) (sprintf "cat wrote %d bytes, expected %d" bytes total_bytes);
    H.check (peak_cat > 1_000) (sprintf "peak of cat not measured (%d kB)" peak_cat);
    H.check (peak_cat < limit_kib) (sprintf "cat peaked at %d kB, limit %d" peak_cat limit_kib);
    return ())
;;
