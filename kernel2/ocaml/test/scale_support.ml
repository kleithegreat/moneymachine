(* Test-only B5 harness. Affinity covers the whole worker and all its threads,
   not just Lean. /proc VmHWM includes OCaml, DuckDB and native Lean memory. *)
open Events_support

external pin_one_core : unit -> unit = "mm2_test_pin_one_core"

let coins = [ "ADA";"AVAX";"BCH";"BNB";"BTC";"DOGE";"ETH";"HBAR";
              "HYPE";"LINK";"NEAR";"SOL";"SUI";"TRX";"XLM";"XRP" ]

let status key =
  lines (read "/proc/self/status") |> List.find_map (fun line ->
    match String.split_on_char ':' line with
    | [name; value] when name = key -> Some (String.trim value)
    | _ -> None) |> Option.get

let peak_rss () =
  let kb = status "VmHWM" |> String.split_on_char ' ' |> List.hd |> Int64.of_string in
  Int64.mul 1024L kb

let check_one_core () =
  let allowed = status "Cpus_allowed_list" in
  check "whole worker is pinned to exactly one OS core"
    (not (String.contains allowed ',') && not (String.contains allowed '-'))

let launch seconds arguments =
  pin_one_core ();
  let executable = if Filename.is_relative Sys.executable_name then
      Filename.concat (Sys.getcwd ()) Sys.executable_name else Sys.executable_name in
  let args = Array.of_list
    (["timeout"; "--signal=KILL"; string_of_int seconds;
      executable; "--worker"] @ arguments) in
  let pid = Unix.create_process "timeout" args Unix.stdin Unix.stdout Unix.stderr in
  check "one-core benchmark completed within its hard deadline"
    (snd (Unix.waitpid [] pid) = Unix.WEXITED 0)

let market ?(encoding = "double") ~last rules =
  let coin_headers = List.map (fun (name, sz, figures, decimals) ->
    `Assoc ["name", `String name; "sz_decimals", `Int sz;
      "figures", `Int figures; "decimals", `Int decimals;
      "tiers", `List [`Assoc ["from", `String "0"; "max_leverage", `Int 1]]]) rules in
  match json (header ~last ~encoding ()) with
  | `Assoc fields -> `Assoc (List.map (fun (key, value) ->
      key, if key = "coins" then `List coin_headers else value) fields)
      |> Yojson.Basic.to_string
  | _ -> assert false

let exclusive_output path =
  open_out_gen [Open_wronly; Open_creat; Open_excl; Open_binary] 0o600 path
