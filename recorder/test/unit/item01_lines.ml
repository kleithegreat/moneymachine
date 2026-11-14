(* Item 1 of "The behaviour its tests must show": Lines. *)

open Core
module G = Base_quickcheck.Generator

let replace_crlf s = String.map s ~f:(function '\r' | '\n' -> ' ' | c -> c)

let%expect_test "item 1: a frame is spliced in byte for byte, CR and LF become spaces" =
  let frame = "{\"channel\":\"trades\",\r\n  \"data\":[{\"px\":\"1.5\"}]\n}" in
  let line = Mmrec.Line.of_frame ~recv_ms:1794653999999 ~conn:3 frame in
  let expected_msg = "{\"channel\":\"trades\",    \"data\":[{\"px\":\"1.5\"}] }" in
  assert (String.is_suffix line ~suffix:(expected_msg ^ "}\n"));
  assert (String.count line ~f:(Char.equal '\n') = 1);
  assert (not (String.mem line '\r'));
  assert (String.equal (Mmrec.Line.sanitize frame) expected_msg);
  let json = Yojson.Safe.from_string line in
  print_endline (Yojson.Safe.to_string (Yojson.Safe.Util.member "recv" json));
  print_endline (Yojson.Safe.to_string (Yojson.Safe.Util.member "conn" json));
  [%expect {|
    1794653999999
    3 |}]
;;

let%expect_test "item 1: a frame that needs no change is unchanged inside its line" =
  let frame = {|{"channel":"l2Book","data":{"coin":"BTC","levels":[[],[]],"time":1}}|} in
  let line = Mmrec.Line.of_frame ~recv_ms:0 ~conn:0 frame in
  assert (String.is_suffix line ~suffix:(frame ^ "}\n"));
  assert (String.equal (Mmrec.Line.sanitize frame) frame)
;;

(* A random JSON value whose strings include escaped CR, LF, quotes and backslashes. *)
type json =
  | Null
  | Bool of bool
  | Int of int
  | Str of string
  | List of json list
  | Obj of (string * json) list
[@@deriving sexp_of]

let gen_string =
  let open G.Let_syntax in
  let%map fragments =
    G.list (G.of_list [ "a"; "b"; "\n"; "\r"; "\""; "\\"; " "; "{"; "\t"; "\xc3\xa9" ])
  in
  String.concat fragments
;;

let rec gen_json depth : json G.t =
  let open G.Let_syntax in
  let leaf =
    G.union
      [ G.return Null
      ; G.map G.bool ~f:(fun b -> Bool b)
      ; G.map (G.int_uniform_inclusive (-1000) 1000) ~f:(fun n -> Int n)
      ; G.map gen_string ~f:(fun s -> Str s)
      ]
  in
  if depth = 0
  then leaf
  else (
    let list =
      let%bind n = G.int_uniform_inclusive 0 3 in
      let%map xs = G.list_with_length ~length:n (gen_json (depth - 1)) in
      List xs
    in
    let obj =
      let%bind n = G.int_uniform_inclusive 0 3 in
      let%map xs =
        G.list_with_length ~length:n (G.both gen_string (gen_json (depth - 1)))
      in
      Obj xs
    in
    G.union [ leaf; list; obj ])
;;

let rec to_yojson = function
  | Null -> `Null
  | Bool b -> `Bool b
  | Int n -> `Int n
  | Str s -> `String s
  | List xs -> `List (List.map xs ~f:to_yojson)
  | Obj kvs -> `Assoc (List.map kvs ~f:(fun (k, v) -> k, to_yojson v))
;;

let%test_unit "item 1: a pretty-printed frame round-trips to an equal JSON value (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 300 }
    (module struct
      type t = json [@@deriving sexp_of]

      let quickcheck_generator = gen_json 3
      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun value ->
      let original = to_yojson value in
      let frame = Yojson.Safe.pretty_to_string original in
      let line = Mmrec.Line.of_frame ~recv_ms:5 ~conn:1 frame in
      assert (String.is_suffix line ~suffix:(replace_crlf frame ^ "}\n"));
      assert (String.count line ~f:(Char.equal '\n') = 1);
      assert (not (String.mem line '\r'));
      match Yojson.Safe.from_string line with
      | `Assoc fields ->
        let msg = List.Assoc.find_exn fields ~equal:String.equal "msg" in
        assert (Yojson.Safe.equal msg original)
      | _ -> assert false)
;;

let%test_unit "item 1: sanitize changes only CR and LF (quickcheck)" =
  Base_quickcheck.Test.run_exn
    (module String)
    ~f:(fun s -> assert (String.equal (Mmrec.Line.sanitize s) (replace_crlf s)))
;;

let%expect_test "item 1: an event is a line whose msg carries the event name" =
  let event = Mmrec.Event.make "refused" [ "coin", `String "xyz:TSLA" ] in
  let line = Mmrec.Event.to_line ~recv_ms:42 ~conn:7 event in
  assert (String.is_suffix line ~suffix:"}\n");
  let json = Yojson.Safe.from_string line in
  let msg = Yojson.Safe.Util.member "msg" json in
  print_endline (Yojson.Safe.to_string (Yojson.Safe.Util.member "event" msg));
  print_endline (Yojson.Safe.to_string (Yojson.Safe.Util.member "coin" msg));
  print_endline (Yojson.Safe.to_string (Yojson.Safe.Util.member "recv" json));
  [%expect {|
    "refused"
    "xyz:TSLA"
    42 |}];
  print_endline (Mmrec.Event.name event);
  [%expect {| refused |}]
;;
