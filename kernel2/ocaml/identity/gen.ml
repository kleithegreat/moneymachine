let read path =
  let channel = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () -> really_input_string channel (in_channel_length channel))
;;

let suffix = "/kernel2/lean/.lake/build/lib/libengine_Engine.a"

let root () =
  let library =
    try Sys.getenv "MM2_ENGINE_LIB" with
    | Not_found -> failwith "MM2_ENGINE_LIB is not set"
  in
  let n = String.length library
  and k = String.length suffix in
  if n < k || String.sub library (n - k) k <> suffix
  then failwith "MM2_ENGINE_LIB is not Lake's archive";
  String.sub library 0 (n - k)
;;

let rec walk root relative =
  let path = Filename.concat root relative in
  if Sys.is_directory path
  then
    Sys.readdir path
    |> Array.to_list
    |> List.sort String.compare
    |> List.filter (fun name -> name <> ".lake" && name <> "_build")
    |> List.concat_map (fun name -> walk root (relative ^ "/" ^ name))
  else [ relative ]
;;

let store_paths text =
  let marker = "/nix/store/" in
  let found = ref [] in
  let n = String.length text
  and m = String.length marker in
  let i = ref 0 in
  while !i + m <= n do
    if String.sub text !i m = marker
    then (
      let j = ref (!i + m) in
      while !j < n && text.[!j] <> '/' && text.[!j] <> ' ' && text.[!j] <> '\n' do
        incr j
      done;
      found := String.sub text !i (!j - !i) :: !found;
      i := !j)
    else incr i
  done;
  !found
;;

let run command =
  let input = Unix.open_process_in command in
  let text = In_channel.input_all input in
  ignore (Unix.close_process_in input);
  text
;;

let toolchain () =
  let own =
    List.concat_map
      store_paths
      [ run "lean --print-prefix"
      ; run "ocamlfind ocamlc -where"
      ; run "ocamlfind query yojson"
      ; run "ocamlfind query digestif"
      ; run "readlink -f $(command -v dune)"
      ; run "readlink -f $(command -v cc)"
      ]
  in
  let flags =
    store_paths
      (try Sys.getenv "NIX_LDFLAGS" with
       | Not_found -> "")
  in
  List.sort_uniq String.compare (own @ flags)
;;

let () =
  let root = root () in
  let files =
    List.concat_map
      (walk root)
      [ "kernel2/lean"; "kernel2/ocaml/src"; "kernel2/ocaml/bin" ]
    @ [ "kernel2/ocaml/dune-project"; "kernel2/protected-windows.json" ]
  in
  print_string "let sources = [\n";
  List.iter
    (fun path -> Printf.printf "  (%S, %S);\n" path (read (Filename.concat root path)))
    files;
  print_string "]\n\nlet toolchain = [\n";
  List.iter (fun path -> Printf.printf "  %S;\n" path) (toolchain ());
  print_string "]\n"
;;
