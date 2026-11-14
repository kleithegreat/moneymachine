(* Item 4: Compression (the kill -9 case is test/e2e/item04_kill9_e2e.ml). *)

open Core
module H = Rec_support.Harness

let recv_ms = 1794653999999
let path_of root = Mmrec.Hour_path.of_recv ~root Mmrec.Route.Trades ~recv_ms

let numbered_line i = sprintf "{\"recv\":%d,\"conn\":1,\"msg\":{\"i\":%d}}\n" recv_ms i

let%test_unit "item 4: a file of flushed frames decompresses to exactly the lines written" =
  let root = H.tmp_dir () in
  let clock = ref 0 in
  let writer = Mmrec.Writer.create ~root ~now_ms:(fun () -> !clock) in
  let lines = List.init 50 ~f:numbered_line in
  List.iter lines ~f:(fun line -> Mmrec.Writer.add writer Trades ~recv_ms line);
  Mmrec.Writer.flush_all writer;
  let path = path_of root in
  let decoded = Mmrec.Frames.decode (H.read_file path) in
  assert (String.equal decoded.data (String.concat lines));
  assert (decoded.frames = 1);
  assert (not decoded.truncated);
  assert (String.equal (H.zstd_binary_decode path) (String.concat lines));
  Mmrec.Writer.close writer
;;

let%test_unit "item 4: each flush appends one frame and the file only grows" =
  let root = H.tmp_dir () in
  let clock = ref 0 in
  let writer = Mmrec.Writer.create ~root ~now_ms:(fun () -> !clock) in
  let path = path_of root in
  let sizes = ref [] in
  for batch = 0 to 4 do
    for i = 0 to 9 do
      Mmrec.Writer.add writer Trades ~recv_ms (numbered_line ((batch * 10) + i))
    done;
    Mmrec.Writer.flush_all writer;
    sizes := String.length (H.read_file path) :: !sizes
  done;
  let sizes = List.rev !sizes in
  assert (List.is_sorted_strictly sizes ~compare:Int.compare);
  let decoded = Mmrec.Frames.decode (H.read_file path) in
  assert (decoded.frames = 5);
  assert (String.equal decoded.data (String.concat (List.init 50 ~f:numbered_line)));
  Mmrec.Writer.close writer
;;

let%test_unit "item 4: a flush with nothing buffered writes nothing" =
  let root = H.tmp_dir () in
  let writer = Mmrec.Writer.create ~root ~now_ms:(fun () -> 0) in
  Mmrec.Writer.flush_all writer;
  Mmrec.Writer.close writer;
  assert (List.is_empty (H.recordings root))
;;

let%test_unit "item 4: a buffer is written one second after its first line, by the injected clock" =
  let root = H.tmp_dir () in
  let clock = ref 10_000 in
  let writer = Mmrec.Writer.create ~root ~now_ms:(fun () -> !clock) in
  let path = path_of root in
  let written () = Sys_unix.file_exists_exn path && String.length (H.read_file path) > 0 in
  Mmrec.Writer.add writer Trades ~recv_ms (numbered_line 1);
  clock := 10_500;
  Mmrec.Writer.add writer Trades ~recv_ms (numbered_line 2);
  clock := 10_999;
  Mmrec.Writer.tick writer;
  assert (not (written ()));
  clock := 11_000;
  Mmrec.Writer.tick writer;
  assert (written ());
  let decoded = Mmrec.Frames.decode (H.read_file path) in
  assert (decoded.frames = 1);
  assert (String.equal decoded.data (numbered_line 1 ^ numbered_line 2));
  Mmrec.Writer.add writer Trades ~recv_ms (numbered_line 3);
  clock := 11_500;
  Mmrec.Writer.tick writer;
  assert ((Mmrec.Frames.decode (H.read_file path)).frames = 1);
  clock := 12_000;
  Mmrec.Writer.tick writer;
  assert ((Mmrec.Frames.decode (H.read_file path)).frames = 2);
  Mmrec.Writer.close writer
;;

let%test_unit "item 4: a buffer reaching 1 MiB is written at once, without a tick" =
  let root = H.tmp_dir () in
  let writer = Mmrec.Writer.create ~root ~now_ms:(fun () -> 0) in
  let path = path_of root in
  assert (Mmrec.Writer.max_buffer_bytes = 1_048_576);
  let big = String.make 65_535 'x' ^ "\n" in
  let lines_to_fill = Mmrec.Writer.max_buffer_bytes / String.length big in
  for _ = 1 to lines_to_fill - 1 do
    Mmrec.Writer.add writer Trades ~recv_ms big
  done;
  assert (not (Sys_unix.file_exists_exn path));
  Mmrec.Writer.add writer Trades ~recv_ms big;
  assert (Sys_unix.file_exists_exn path);
  let decoded = Mmrec.Frames.decode (H.read_file path) in
  assert (decoded.frames = 1);
  assert (String.length decoded.data >= Mmrec.Writer.max_buffer_bytes);
  Mmrec.Writer.close writer
;;

let%test_unit "item 4: writing never changes what is already in the file (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 50 }
    (module struct
      type t = string list list [@@deriving sexp_of]

      let quickcheck_generator =
        Base_quickcheck.Generator.(list (list (string_of char_alphanum)))
      ;;

      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun batches ->
      let root = H.tmp_dir () in
      let writer = Mmrec.Writer.create ~root ~now_ms:(fun () -> 0) in
      let path = path_of root in
      let expected = Buffer.create 64 in
      let previous = ref "" in
      List.iter batches ~f:(fun batch ->
        List.iter batch ~f:(fun text ->
          let line = text ^ "\n" in
          Buffer.add_string expected line;
          Mmrec.Writer.add writer Trades ~recv_ms line);
        Mmrec.Writer.flush_all writer;
        if Sys_unix.file_exists_exn path
        then (
          let now = H.read_file path in
          assert (String.is_prefix now ~prefix:!previous);
          previous := now));
      Mmrec.Writer.close writer;
      if not (List.is_empty (List.concat batches))
      then (
        let decoded = Mmrec.Frames.decode (H.read_file path) in
        assert (not decoded.truncated);
        assert (String.equal decoded.data (Buffer.contents expected))))
;;

(* A file cut at any byte. *)

let chunks =
  [ "{\"recv\":1,\"conn\":1,\"msg\":{\"a\":\"first frame\"}}\n"
  ; String.concat (List.init 20 ~f:numbered_line)
  ; "{\"recv\":3,\"conn\":2,\"msg\":{\"c\":\"third\"}}\n{\"recv\":4,\"conn\":2,\"msg\":{}}\n"
  ]

let%test_unit "item 4: a file cut at any byte yields every complete frame before the cut and reports the cut" =
  let frames = List.map chunks ~f:Mmrec.Zstd.compress in
  let file = String.concat frames in
  let boundaries =
    List.folding_map frames ~init:0 ~f:(fun offset frame ->
      let next = offset + String.length frame in
      next, next)
  in
  for cut = 0 to String.length file do
    let decoded = Mmrec.Frames.decode (String.prefix file cut) in
    let complete = List.filter boundaries ~f:(fun b -> b <= cut) in
    let expected_frames = List.length complete in
    let expected_bytes = List.last complete |> Option.value ~default:0 in
    let expected_data = String.concat (List.take chunks expected_frames) in
    if decoded.frames <> expected_frames
    then failwithf "cut %d: frames %d, expected %d" cut decoded.frames expected_frames ();
    if not (String.equal decoded.data expected_data)
    then failwithf "cut %d: wrong data" cut ();
    if decoded.complete_bytes <> expected_bytes
    then failwithf "cut %d: complete_bytes %d, expected %d" cut decoded.complete_bytes expected_bytes ();
    if Bool.( <> ) decoded.truncated (cut <> expected_bytes)
    then failwithf "cut %d: truncated = %b" cut decoded.truncated ()
  done
;;

let%test_unit "item 4: cutting random files at random bytes (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 200 }
    (module struct
      type t = string list * int [@@deriving sexp_of]

      let quickcheck_generator =
        Base_quickcheck.Generator.(
          both (list (string_of char_alphanum)) (int_uniform_inclusive 0 10_000))
      ;;

      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun (chunks, seed) ->
      let frames = List.map chunks ~f:Mmrec.Zstd.compress in
      let file = String.concat frames in
      let cut = if String.is_empty file then 0 else seed % (String.length file + 1) in
      let decoded = Mmrec.Frames.decode (String.prefix file cut) in
      let ends =
        List.folding_map frames ~init:0 ~f:(fun o f ->
          let n = o + String.length f in
          n, n)
      in
      let whole = List.count ends ~f:(fun e -> e <= cut) in
      assert (decoded.frames = whole);
      assert (String.equal decoded.data (String.concat (List.take chunks whole)));
      assert (
        Bool.equal decoded.truncated
          (cut > (List.nth ends (whole - 1) |> Option.value ~default:0))))
;;

let%test_unit "item 4: the empty file has no frames and no cut" =
  let decoded = Mmrec.Frames.decode "" in
  assert (decoded.frames = 0);
  assert (not decoded.truncated);
  assert (String.is_empty decoded.data)
;;

let%test_unit "item 4: a frame size is the whole frame, or none when cut or when not a frame" =
  let a = Mmrec.Zstd.compress "hello hello hello" in
  let b = Mmrec.Zstd.compress "world" in
  let file = a ^ b in
  assert (Option.equal Int.equal (Mmrec.Zstd.frame_size file ~pos:0) (Some (String.length a)));
  assert (
    Option.equal Int.equal (Mmrec.Zstd.frame_size file ~pos:(String.length a)) (Some (String.length b)));
  assert (Option.is_none (Mmrec.Zstd.frame_size (String.prefix a (String.length a - 1)) ~pos:0));
  assert (Option.is_none (Mmrec.Zstd.frame_size "this is not zstd at all" ~pos:0));
  assert (String.equal (Mmrec.Zstd.decompress a) "hello hello hello")
;;

let%test_unit "item 4: a compressed frame is read by the independent zstd binary" =
  let root = H.tmp_dir () in
  let path = Filename.concat root "x.jsonl.zst" in
  Out_channel.write_all path ~data:(Mmrec.Zstd.compress "abc\n" ^ Mmrec.Zstd.compress "def\n");
  assert (String.equal (H.zstd_binary_decode path) "abc\ndef\n")
;;
