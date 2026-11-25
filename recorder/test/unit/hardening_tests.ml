(* Unit tests for Strict_json, 4-state Recording stream classification, and monotonic Writer run IDs. *)

open Core

let%expect_test
    "strict_json rejects comments, NaN, trailing bytes, BOM, lone surrogates, depth > 64"
  =
  let cases =
    [ "valid object", {|{"a":1,"b":[true,false,null,"hi"]}|}
    ; "depth 64 ok", String.make 64 '[' ^ String.make 64 ']'
    ; "depth 65 fail", String.make 65 '[' ^ String.make 65 ']'
    ; "1 MiB open brackets", String.make (1024 * 1024) '['
    ; "comment", {|{} /* comment */|}
    ; "NaN", {|{"x":NaN}|}
    ; "Infinity", {|{"x":Infinity}|}
    ; "trailing value", {|{} {}|}
    ; "BOM", "\xef\xbb\xbf{}"
    ; "lone high surrogate", {|"\ud800"|}
    ; "lone low surrogate", {|"\udc00"|}
    ; "valid surrogate pair", {|"\ud83d\ude00"|}
    ; "leading zero", "01"
    ; "invalid UTF-8", "\"\xff\""
    ]
  in
  List.iter cases ~f:(fun (name, text) ->
    let status =
      match Mmrec.Strict_json.check text with
      | Ok () -> "ok"
      | Error _ -> "err"
    in
    printf "%-22s %s\n" name status);
  [%expect
    {|
    valid object           ok
    depth 64 ok            ok
    depth 65 fail          err
    1 MiB open brackets    err
    comment                err
    NaN                    err
    Infinity               err
    trailing value         err
    BOM                    err
    lone high surrogate    err
    lone low surrogate     err
    valid surrogate pair   ok
    leading zero           err
    invalid UTF-8          err |}]
;;

let tmp_dir prefix =
  let base = Option.value (Sys.getenv "TMPDIR") ~default:"/tmp" in
  Core_unix.mkdtemp (Filename.concat base prefix)
;;

let%expect_test
    "recording classifies Complete, Cut, Malformed, Corrupt and feeds 0 lines on Corrupt"
  =
  let dir = tmp_dir "mmrec-rec-unit-" in
  let write name data =
    let path = Filename.concat dir name in
    Out_channel.write_all path ~data;
    path
  in
  let compress_all text ~ending =
    let c = Mmrec.Zstd.compressor () in
    Mmrec.Zstd.compress c text ~ending
  in
  let fold path =
    let lines, state =
      Mmrec.Recording.fold_lines path ~init:[] ~f:(fun acc line -> line :: acc)
    in
    List.length lines, Mmrec.Recording.state_to_string state
  in
  let good_bytes = compress_all "{\"a\":1}\n{\"a\":2}\n" ~ending:true in
  let complete_path = write "complete.jsonl.zst" good_bytes in
  let empty_path = write "empty.jsonl.zst" "" in
  let cut_checksum_path =
    write "cut_cksum.jsonl.zst" (String.prefix good_bytes (String.length good_bytes - 2))
  in
  let cut_1byte_path = write "cut_1b.jsonl.zst" (String.prefix good_bytes 1) in
  let malformed_path =
    write "malformed.jsonl.zst" (compress_all "{\"a\":1}\n{\"a\":2}" ~ending:true)
  in
  let empty_frame_path = write "empty_frame.jsonl.zst" (compress_all "" ~ending:true) in
  let bad_cksum =
    let b = Bytes.of_string good_bytes in
    let last = Bytes.length b - 1 in
    Bytes.set b last (Char.of_int_exn (Char.to_int (Bytes.get b last) lxor 0x01));
    Bytes.to_string b
  in
  let corrupt_cksum_path = write "corrupt_cksum.jsonl.zst" bad_cksum in
  let corrupt_magic_path = write "corrupt_magic.jsonl.zst" "\xff\xff\xff\xffrest" in
  let corrupt_1byte_path = write "corrupt_1b.jsonl.zst" "\x29" in
  List.iter
    [ "complete", complete_path
    ; "empty (0 bytes)", empty_path
    ; "cut in checksum", cut_checksum_path
    ; "cut at 1 byte", cut_1byte_path
    ; "malformed no nl", malformed_path
    ; "empty zstd frame", empty_frame_path
    ; "corrupt checksum", corrupt_cksum_path
    ; "corrupt magic", corrupt_magic_path
    ; "corrupt 1 byte", corrupt_1byte_path
    ]
    ~f:(fun (label, path) ->
      let n, st = fold path in
      printf "%-18s lines=%d state=%s\n" label n st);
  [%expect
    {|
    complete           lines=2 state=complete
    empty (0 bytes)    lines=0 state=cut
    cut in checksum    lines=2 state=cut
    cut at 1 byte      lines=0 state=cut
    malformed no nl    lines=1 state=malformed
    empty zstd frame   lines=0 state=malformed
    corrupt checksum   lines=0 state=corrupt
    corrupt magic      lines=0 state=corrupt
    corrupt 1 byte     lines=0 state=corrupt |}]
;;

let%expect_test
    "writer chooses strictly monotonic run IDs even when wall clock steps backwards"
  =
  let root = tmp_dir "mmrec-writer-unit-" in
  let t1 = 1_794_650_400_000 in
  let w1 = Mmrec.Writer.create ~root ~now_ms:(fun () -> t1) in
  Mmrec.Writer.add w1 Mmrec.Route.Trades ~recv_ms:t1 "{\"recv\":1}\n";
  Mmrec.Writer.close w1;
  let w2 = Mmrec.Writer.create ~root ~now_ms:(fun () -> t1) in
  Mmrec.Writer.add w2 Mmrec.Route.Trades ~recv_ms:t1 "{\"recv\":2}\n";
  Mmrec.Writer.close w2;
  let w3 = Mmrec.Writer.create ~root ~now_ms:(fun () -> t1 - 3_600_000) in
  Mmrec.Writer.add w3 Mmrec.Route.Trades ~recv_ms:t1 "{\"recv\":3}\n";
  Mmrec.Writer.close w3;
  let r1 = Mmrec.Writer.run w1 in
  let r2 = Mmrec.Writer.run w2 in
  let r3 = Mmrec.Writer.run w3 in
  printf "r1=%d r2-r1=%d r3-r2=%d\n" r1 (r2 - r1) (r3 - r2);
  [%expect {| r1=1794650400000 r2-r1=1 r3-r2=1 |}]
;;
