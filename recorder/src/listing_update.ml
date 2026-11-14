open Core

type action =
  | Subscribe of
      { conn : int
      ; sub : Sub.t
      }
  | Unsubscribe of
      { conn : int
      ; sub : Sub.t
      }
  | Record of Event.t

let dex_of coin = Option.value_map (String.lsplit2 coin ~on:':') ~default:"" ~f:fst

let add_coin planner coin ~change =
  match Planner.add planner ~coin with
  | Planner.Refused -> [ Record (Event.make "refused" [ "coin", `String coin ]) ]
  | Planner.Added ->
    let conn = Option.value_exn (Planner.conn_of planner (Sub.Trades coin)) in
    let subscribes =
      List.map [ Sub.Trades coin; Sub.L2_book coin ] ~f:(fun sub -> Subscribe { conn; sub })
    in
    let listing =
      Option.to_list
        (Option.map change ~f:(fun change ->
           Record
             (Event.make
                "listing"
                [ "coin", `String coin; "dex", `String (dex_of coin); "change", `String change ])))
    in
    subscribes @ listing
;;

let first_read planner coins =
  let counts =
    List.fold coins ~init:[] ~f:(fun counts coin ->
      let dex = dex_of coin in
      match List.Assoc.find counts ~equal:String.equal dex with
      | None -> counts @ [ dex, 1 ]
      | Some n -> List.Assoc.add counts ~equal:String.equal dex (n + 1))
  in
  let dexes = `Assoc (List.map counts ~f:(fun (dex, n) -> dex, `Int n)) in
  Record (Event.make "listing" [ "dexes", dexes ])
  :: List.concat_map coins ~f:(add_coin planner ~change:None)
;;

let apply planner ~before ~after =
  let gone = List.filter before ~f:(fun coin -> not (List.mem after coin ~equal:String.equal)) in
  let added = List.filter after ~f:(fun coin -> not (List.mem before coin ~equal:String.equal)) in
  let removals =
    List.concat_map gone ~f:(fun coin ->
      let unsubscribes =
        List.map (Planner.remove planner ~coin) ~f:(fun (conn, sub) -> Unsubscribe { conn; sub })
      in
      let listing =
        Event.make
          "listing"
          [ "coin", `String coin; "dex", `String (dex_of coin); "change", `String "delisted" ]
      in
      unsubscribes @ [ Record listing ])
  in
  removals @ List.concat_map added ~f:(add_coin planner ~change:(Some "added"))
;;
