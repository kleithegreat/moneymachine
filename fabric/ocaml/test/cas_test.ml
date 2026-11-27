open Core

let with_temp_dir f =
  let base =
    Filename.concat
      Filename.temp_dir_name
      (sprintf
         "mmfabric-cas-%d-%f"
         (Core_unix.getpid () |> Pid.to_int)
         (Core_unix.gettimeofday ()))
  in
  Core_unix.mkdir_p base;
  Exn.protect
    ~f:(fun () -> f base)
    ~finally:(fun () ->
      ignore
        (Core_unix.system (sprintf "rm -rf %s" (Filename.quote base))
         : Core_unix.Exit_or_signal.t))
;;

let%expect_test "CAS put, deduplicate, get, verify, and quarantine corrupt blob" =
  with_temp_dir (fun root ->
    let payload = "bitemporal cas payload bytes\n" in
    let r1 =
      Mmfabric.Cas.put ~uri_prefix:"cas://local" ~root payload |> Result.ok_or_failwith
    in
    let r2 =
      Mmfabric.Cas.put ~uri_prefix:"cas://local" ~root payload |> Result.ok_or_failwith
    in
    let fetched = Mmfabric.Cas.get ~root r1.sha256 |> Result.ok_or_failwith in
    printf
      "existed=(%b,%b) same_hash=%b equal_bytes=%b verify=%b\n"
      r1.existed
      r2.existed
      (String.equal r1.sha256 r2.sha256)
      (String.equal payload fetched)
      (Mmfabric.Cas.verify ~root r1.sha256);
    let path = Mmfabric.Cas.path_for ~root ~digest:r1.sha256 |> Result.ok_or_failwith in
    Out_channel.write_all path ~data:"corrupt-bytes";
    let bad_get = Mmfabric.Cas.get ~root r1.sha256 in
    let healed = Mmfabric.Cas.put ~root payload |> Result.ok_or_failwith in
    let recovered = Mmfabric.Cas.get ~root r1.sha256 |> Result.ok_or_failwith in
    let damaged_count =
      Sys_unix.ls_dir (Filename.dirname path)
      |> List.count ~f:(String.is_substring ~substring:".damaged-")
    in
    printf
      "corrupt_err=%b healed_existed=%b recovered=%b damaged=%d\n"
      (Result.is_error bad_get)
      healed.existed
      (String.equal payload recovered)
      damaged_count);
  [%expect
    {|
    existed=(false,true) same_hash=true equal_bytes=true verify=true
    corrupt_err=true healed_existed=false recovered=true damaged=1
    |}]
;;

let%expect_test "CAS rejects invalid SHA-256 digest" =
  with_temp_dir (fun root ->
    printf
      "bad_path=%b\n"
      (Result.is_error (Mmfabric.Cas.path_for ~root ~digest:"deadbeef"));
    printf "bad_verify=%b\n" (Mmfabric.Cas.verify ~root "xyz"));
  [%expect
    {|
    bad_path=true
    bad_verify=false
    |}]
;;
