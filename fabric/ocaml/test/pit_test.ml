open Core

let default_view : Mmfabric.Pit.pod_view =
  { allowed_sources = None
  ; allowed_licenses = None
  ; min_quality = 0
  ; polarity_filter = None
  }
;;

let make_obs
      ?(entity = "USA")
      ?(source = "fred")
      ?(metric = "payems")
      ~event_time
      ~known_at
      ~revision_id
      ?(obs_id = revision_id)
      ?(state = Mmfabric.Pit.Original)
      ?(polarity = Mmfabric.Pit.Obs)
      ?(quality = 100)
      ?(license = "PUBLIC_DOMAIN")
      ()
  : Mmfabric.Pit.obs
  =
  { key = { entity; source; metric; event_time }
  ; known_at
  ; revision_id
  ; obs_id
  ; state
  ; polarity
  ; quality
  ; license
  }
;;

let%expect_test
    "PIT retractions never resurrect earlier revisions and exclude future rows"
  =
  let key : Mmfabric.Pit.obs_key =
    { entity = "USA"; source = "fred"; metric = "payems"; event_time = 100 }
  in
  let v1 = make_obs ~event_time:100 ~known_at:110 ~revision_id:1 ~state:Original () in
  let v2 = make_obs ~event_time:100 ~known_at:150 ~revision_id:2 ~state:Restated () in
  let v3 = make_obs ~event_time:100 ~known_at:200 ~revision_id:3 ~state:Retracted () in
  let rows = [ v1; v2; v3 ] in
  let at ts =
    match Mmfabric.Pit.pit_latest rows default_view ~as_of:ts key with
    | None -> "none"
    | Some o -> sprintf "rev=%d" o.revision_id
  in
  printf "t105=%s t120=%s t160=%s t210=%s\n" (at 105) (at 120) (at 160) (at 210);
  [%expect {| t105=none t120=rev=1 t160=rev=2 t210=none |}]
;;

let%expect_test "ASOF join selects latest visible event_time <= left_event_time" =
  let r1 = make_obs ~metric:"yield" ~event_time:90 ~known_at:95 ~revision_id:1 () in
  let r2 = make_obs ~metric:"yield" ~event_time:102 ~known_at:300 ~revision_id:2 () in
  let match_t200 =
    Mmfabric.Pit.asof_match [ r1; r2 ] default_view ~as_of:200 ~left_event_time:105
  in
  let rev_str =
    Option.value_map match_t200 ~default:"none" ~f:(fun r ->
      sprintf "ev=%d" r.key.event_time)
  in
  print_endline rev_str;
  [%expect {| ev=90 |}]
;;

let%test_unit "pit_latest future non-interference (quickcheck)" =
  Base_quickcheck.Test.run_exn
    ~config:{ Base_quickcheck.Test.default_config with test_count = 200 }
    (module struct
      type t =
        Mmfabric.Pit.obs list
        * Mmfabric.Pit.obs
        * Mmfabric.Pit.pod_view
        * int
        * Mmfabric.Pit.obs_key
      [@@deriving sexp_of, quickcheck]
    end)
    ~f:(fun (rows, future, view, as_of, key) ->
      if (future : Mmfabric.Pit.obs).known_at > as_of
      then
        assert (
          Option.equal
            Mmfabric.Pit.equal_obs
            (Mmfabric.Pit.pit_latest (future :: rows) view ~as_of key)
            (Mmfabric.Pit.pit_latest rows view ~as_of key)))
;;
