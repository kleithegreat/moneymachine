open Core
open Async

let run =
  Command.async
    ~summary:"one pass of the vault collector (recorder/VAULT.md)"
    (let%map_open.Command root = anon ("ROOT" %: string)
     and user = flag "--user" (required string) ~doc:"ADDRESS the account"
     and rest_url =
       flag
         "--rest-url"
         (optional_with_default "https://api.hyperliquid.xyz/info" string)
         ~doc:"URL REST info endpoint"
     and now_ms =
       flag "--now-ms" (optional int) ~doc:"MS the clock, for tests (default: the real time)"
     in
     fun () ->
       let now_ms =
         Option.value now_ms ~default:(Time_ns.to_int_ns_since_epoch (Time_ns.now ()) / 1_000_000)
       in
       let%bind ok = Mmrec.Vault.run { root; user; rest_url; now_ms } in
       exit (if ok then 0 else 1))
;;

let () = Command_unix.run (Command.group ~summary:"the vault collector" [ "run", run ])
