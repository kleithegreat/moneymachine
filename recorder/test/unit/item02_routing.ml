(* Item 2: Routing. *)

open Core

let route frame = Mmrec.Route.dir (Mmrec.Route.of_frame frame)

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
    Mmrec.Route.[ Trades; L2_book; All_dexs_asset_ctxs; Events; Listings ]
    ~f:(fun r -> print_endline (Mmrec.Route.dir r));
  [%expect {|
    trades
    l2Book
    allDexsAssetCtxs
    events
    listings |}]
;;

let%test_unit "item 2: a frame is never routed to listings (quickcheck)" =
  Base_quickcheck.Test.run_exn
    (module String)
    ~f:(fun frame -> assert (not (Mmrec.Route.equal (Mmrec.Route.of_frame frame) Listings)))
;;
