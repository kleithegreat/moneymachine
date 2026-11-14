(* Item 13: Hour end. At the first frame of a new hour, the previous hour's file is closed: its bytes never change
   again, even across a restart later in the new hour. 2026-11-14 10:59:59.999 UTC is 1794653999999. *)

open Core
module H = Rec_support.Harness

let at_10_59 = 1794653999999
let at_11_00 = 1794654000000
let line n = sprintf "{\"n\":%d}\n" n
let path root ~recv_ms = Mmrec.Hour_path.of_recv ~root Mmrec.Route.Trades ~recv_ms

let%test_unit "item 13: the first frame of a new hour writes and closes the previous hour's file, with no tick" =
  let root = H.tmp_dir () in
  let writer = Mmrec.Writer.create ~root ~now_ms:(fun () -> 0) in
  Mmrec.Writer.add writer Trades ~recv_ms:at_10_59 (line 1);
  Mmrec.Writer.add writer Trades ~recv_ms:(at_10_59 - 1) (line 2);
  let ten = path root ~recv_ms:at_10_59 in
  assert (not (Sys_unix.file_exists_exn ten));
  Mmrec.Writer.add writer Trades ~recv_ms:at_11_00 (line 3);
  assert (Sys_unix.file_exists_exn ten);
  let decoded = Mmrec.Frames.decode (H.read_file ten) in
  assert (String.equal decoded.data (line 1 ^ line 2));
  assert (not decoded.truncated);
  Mmrec.Writer.close writer
;;

let%test_unit "item 13: the previous hour's bytes never change again, across more frames, a flush, and a restart" =
  let root = H.tmp_dir () in
  let ten = path root ~recv_ms:at_10_59 in
  let eleven = path root ~recv_ms:at_11_00 in
  let first = Mmrec.Writer.create ~root ~now_ms:(fun () -> 0) in
  Mmrec.Writer.add first Trades ~recv_ms:at_10_59 (line 1);
  Mmrec.Writer.add first Trades ~recv_ms:at_11_00 (line 2);
  let frozen = H.read_file ten in
  Mmrec.Writer.add first Trades ~recv_ms:(at_11_00 + 500) (line 3);
  Mmrec.Writer.flush_all first;
  Mmrec.Writer.close first;
  assert (String.equal (H.read_file ten) frozen);
  let second = Mmrec.Writer.create ~root ~now_ms:(fun () -> 0) in
  Mmrec.Writer.add second Trades ~recv_ms:(at_11_00 + 5_000) (line 4);
  Mmrec.Writer.flush_all second;
  Mmrec.Writer.close second;
  assert (String.equal (H.read_file ten) frozen);
  let decoded = Mmrec.Frames.decode (H.read_file eleven) in
  assert (String.equal decoded.data (line 2 ^ line 3 ^ line 4));
  assert (String.equal (H.zstd_binary_decode ten) (line 1))
;;
