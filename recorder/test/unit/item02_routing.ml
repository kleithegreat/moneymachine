(* Item 2: Routing, including zero-AST parser vs Yojson QuickCheck equivalence. *)

open Core
module G = Base_quickcheck.Generator

let route ?(fast = false) frame = Mmrec.Route.dir (Mmrec.Route.of_frame ~fast frame)

let yojson_reference ~fast frame =
  match Mmrec.Strict_json.check frame with
  | Error _ -> Mmrec.Route.Events
  | Ok () ->
    (match Yojson.Safe.from_string frame with
     | `Assoc fields ->
       (match List.Assoc.find fields ~equal:String.equal "channel" with
        | Some (`String "trades") -> Trades
        | Some (`String "l2Book") -> if fast then L2_book_fast else L2_book
        | Some (`String "allDexsAssetCtxs") -> All_dexs_asset_ctxs
        | _ -> Events)
     | _ -> Events
     | exception Yojson.Json_error _ -> Events)
;;

let%expect_test "item 2: each channel's frames land in its file" =
  List.iter
    [ {|{"channel":"trades","data":[{"coin":"BTC","px":"1"}]}|}
    ; {|{"channel":"l2Book","data":{"coin":"BTC","levels":[[],[]]}}|}
    ; {|{"channel":"allDexsAssetCtxs","data":{"ctxs":[]}}|}
    ; {|{"data":[1],"channel":"trades"}|}
    ; "{\"channel\":\"trades\",\r\n\"data\":[]}"
    ; {|{"\u0063hannel":"tr\u0061des","data":[]}|}
    ; {|{"channel":"l2\u0042ook","data":{}}|}
    ; {|{"channel":"allDexs\u0041ssetCtxs","data":{}}|}
    ]
    ~f:(fun frame -> print_endline (route frame));
  [%expect
    {|
    trades
    l2Book
    allDexsAssetCtxs
    trades
    trades
    trades
    l2Book
    allDexsAssetCtxs |}]
;;

let%expect_test
    "item 2: acks, pongs, errors, unknown channels and malformed frames land in events"
  =
  List.iter
    [ {|{"channel":"subscriptionResponse","data":{"method":"subscribe","subscription":{"type":"trades","coin":"BTC"}}}|}
    ; {|{"channel":"pong"}|}
    ; {|{"channel":"error","data":"Already subscribed"}|}
    ; {|{"channel":"bbo","data":{"coin":"BTC"}}|}
    ; {|{"channel":"somethingNew","data":[]}|}
    ; {|{"data":[1]}|}
    ; {|{"channel":7}|}
    ; {|[1,2]|}
    ; "not json"
    ; ""
    ; {|{"channel":"trades", bad}|}
    ; {|{"channel":"trades"} trailing|}
    ; {|{"channel":"trades"} /* comment */|}
    ; {|{"channel":"trades","x":"\ud800"}|}
    ]
    ~f:(fun frame -> print_endline (route frame));
  [%expect
    {|
    events
    events
    events
    events
    events
    events
    events
    events
    events
    events
    events
    events
    events
    events |}]
;;

let%expect_test "item 2: only the top-level channel field counts" =
  List.iter
    [ {|{"data":{"channel":"trades"}}|}
    ; {|{"channel":"pong","data":{"channel":"trades"}}|}
    ; {|{"channel":"trades","data":[{"channel":"pong","note":"\"channel\":\"l2Book\""}]}|}
    ; {|{"arr":[{"channel":"l2Book"}],"channel":"trades"}|}
    ]
    ~f:(fun frame -> print_endline (route frame));
  [%expect
    {|
    events
    events
    trades
    trades |}]
;;

let%expect_test "item 2: directory names" =
  List.iter
    Mmrec.Route.[ Trades; L2_book; L2_book_fast; All_dexs_asset_ctxs; Events; Listings ]
    ~f:(fun r -> print_endline (Mmrec.Route.dir r));
  [%expect
    {|
    trades
    l2Book
    l2Book-fast
    allDexsAssetCtxs
    events
    listings |}]
;;

let%expect_test
    "item 2: an l2Book frame goes to l2Book-fast on a fast connection and to l2Book on a \
     deep one"
  =
  let l2 = {|{"channel":"l2Book","data":{"coin":"BTC","levels":[[],[]]}}|} in
  print_endline (route ~fast:true l2);
  print_endline (route ~fast:false l2);
  [%expect
    {|
    l2Book-fast
    l2Book |}]
;;

let%expect_test "item 2: the connection's kind changes no other frame's file" =
  List.iter
    [ {|{"channel":"trades","data":[]}|}
    ; {|{"channel":"allDexsAssetCtxs","data":{"ctxs":[]}}|}
    ; {|{"channel":"subscriptionResponse","data":{"method":"subscribe","subscription":{"type":"l2Book","coin":"BTC","fast":true}}}|}
    ; {|{"channel":"pong"}|}
    ; {|{"channel":"error","data":"boom"}|}
    ; {|{"channel":"bbo","data":{}}|}
    ; "not json"
    ]
    ~f:(fun frame ->
      let fast = route ~fast:true frame in
      let deep = route ~fast:false frame in
      print_endline
        (if String.equal fast deep then fast else sprintf "DIFFERS %s %s" fast deep));
  [%expect
    {|
    trades
    allDexsAssetCtxs
    events
    events
    events
    events
    events |}]
;;

let%test_unit "item 2: a frame is never routed to listings (quickcheck)" =
  Base_quickcheck.Test.run_exn
    (module String)
    ~f:(fun frame ->
      List.iter [ true; false ] ~f:(fun fast ->
        assert (not (Mmrec.Route.equal (Mmrec.Route.of_frame ~fast frame) Listings))))
;;

let gen_ws =
  let open G.Let_syntax in
  let%map parts = G.list_non_empty (G.of_list [ ""; " "; "\t"; "\n"; "\r\n" ]) in
  String.concat parts
;;

let gen_key =
  G.of_list
    [ "channel"; "\\u0063hannel"; "data"; "note"; "nested\\\"channel\\\""; "other" ]
;;

let gen_str_val =
  G.of_list
    [ "trades"
    ; "tr\\u0061des"
    ; "l2Book"
    ; "l2\\u0042ook"
    ; "allDexsAssetCtxs"
    ; "allDexs\\u0041ssetCtxs"
    ; "pong"
    ; "error"
    ; "a\\\"channel\\\":\\\"trades\\\"\\\\b"
    ; "\\uD83D\\uDE00"
    ]
;;

let rec gen_raw_json depth =
  let open G.Let_syntax in
  let leaf =
    G.union
      [ G.return "null"
      ; G.return "true"
      ; G.return "false"
      ; G.map (G.int_uniform_inclusive (-1000) 1000) ~f:Int.to_string
      ; G.return "1.25e-3"
      ; G.map gen_str_val ~f:(fun s -> "\"" ^ s ^ "\"")
      ]
  in
  if depth = 0
  then leaf
  else (
    let arr =
      let%bind n = G.int_uniform_inclusive 0 3 in
      let%bind xs = G.list_with_length ~length:n (gen_raw_json (depth - 1)) in
      let%map w1 = gen_ws
      and w2 = gen_ws in
      "[" ^ w1 ^ String.concat ~sep:("," ^ w1) xs ^ w2 ^ "]"
    in
    let obj =
      let%bind n = G.int_uniform_inclusive 0 4 in
      let%bind kvs =
        G.list_with_length ~length:n (G.both gen_key (gen_raw_json (depth - 1)))
      in
      let%map w1 = gen_ws
      and w2 = gen_ws in
      let fields = List.map kvs ~f:(fun (k, v) -> sprintf "\"%s\"%s:%s%s" k w1 w2 v) in
      "{" ^ w1 ^ String.concat ~sep:("," ^ w2) fields ^ w1 ^ "}"
    in
    G.union [ leaf; arr; obj ])
;;

let gen_frame =
  let open G.Let_syntax in
  let%bind base = gen_raw_json 3 in
  let%bind w1 = gen_ws
  and w2 = gen_ws in
  let valid = w1 ^ base ^ w2 in
  G.union
    [ G.return valid
    ; G.map
        (G.int_uniform_inclusive 0 (String.length valid))
        ~f:(fun n -> String.prefix valid n)
    ; G.return (valid ^ " extra")
    ; G.return (valid ^ " /* c */")
    ]
;;

let%test_unit "item 2: zero-AST Route.of_frame matches Yojson reference (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 1000 }
    (module struct
      type t = string [@@deriving sexp_of]

      let quickcheck_generator = gen_frame
      let quickcheck_shrinker = Base_quickcheck.Shrinker.atomic
    end)
    ~f:(fun frame ->
      List.iter [ true; false ] ~f:(fun fast ->
        let got = Mmrec.Route.of_frame ~fast frame in
        let expected = yojson_reference ~fast frame in
        if not (Mmrec.Route.equal got expected)
        then
          failwithf
            "Route.of_frame ~fast:%b %S = %s, expected %s"
            fast
            frame
            (Mmrec.Route.dir got)
            (Mmrec.Route.dir expected)
            ()))
;;

let%test_unit "item 2: Route.of_frame allocates zero minor words on normal frames" =
  let frames =
    [ {|{"channel":"trades","data":[{"coin":"BTC","px":"100000.5","sz":"0.1","time":1794650400000,"tid":1}]}|}
    ; {|{"channel":"l2Book","data":{"coin":"BTC","time":1794650400000,"levels":[[{"px":"1","sz":"2","n":1}],[]]}}|}
    ; {|{"channel":"allDexsAssetCtxs","data":{"ctxs":[[{"funding":"0.0001"}]]}}|}
    ; {|{"channel":"pong"}|}
    ]
  in
  List.iter frames ~f:(fun frame ->
    let base = Stdlib.Gc.minor_words () in
    let before = Stdlib.Gc.minor_words () in
    let overhead = before -. base in
    let _r1 = Mmrec.Route.of_frame ~fast:true frame in
    let _r2 = Mmrec.Route.of_frame ~fast:false frame in
    let after = Stdlib.Gc.minor_words () in
    let allocated = after -. before -. overhead in
    if Float.( > ) allocated 0.
    then failwithf "Route.of_frame allocated %.0f minor words on %S" allocated frame ())
;;
