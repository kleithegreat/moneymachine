(* Item 2: Routing. *)

open Core

let route ?(fast = false) frame = Mmrec.Route.dir (Mmrec.Route.of_frame ~fast frame)

let%expect_test "item 2: each channel's frames land in its file" =
  List.iter
    [ {|{"channel":"trades","data":[{"coin":"BTC","px":"1"}]}|}
    ; {|{"channel":"l2Book","data":{"coin":"BTC","levels":[[],[]]}}|}
    ; {|{"channel":"allDexsAssetCtxs","data":{"ctxs":[]}}|}
    ; {|{"data":[1],"channel":"trades"}|}
    ; "{\"channel\":\"trades\",\r\n\"data\":[]}"
    ]
    ~f:(fun frame -> print_endline (route frame));
  [%expect {|
    trades
    l2Book
    allDexsAssetCtxs
    trades
    trades |}]
;;

let%expect_test "item 2: acks, pongs, errors and unknown channels land in events" =
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
    ]
    ~f:(fun frame -> print_endline (route frame));
  [%expect {|
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
    ]
    ~f:(fun frame -> print_endline (route frame));
  [%expect {|
    events
    events
    trades |}]
;;

let%expect_test "item 2: directory names" =
  List.iter
    Mmrec.Route.[ Trades; L2_book; L2_book_fast; All_dexs_asset_ctxs; Events; Listings ]
    ~f:(fun r -> print_endline (Mmrec.Route.dir r));
  [%expect {|
    trades
    l2Book
    l2Book-fast
    allDexsAssetCtxs
    events
    listings |}]
;;

let%expect_test "item 2: an l2Book frame goes to l2Book-fast on a fast connection and to l2Book on a deep one" =
  let l2 = {|{"channel":"l2Book","data":{"coin":"BTC","levels":[[],[]]}}|} in
  print_endline (route ~fast:true l2);
  print_endline (route ~fast:false l2);
  [%expect {|
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
      print_endline (if String.equal fast deep then fast else sprintf "DIFFERS %s %s" fast deep));
  [%expect {|
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
