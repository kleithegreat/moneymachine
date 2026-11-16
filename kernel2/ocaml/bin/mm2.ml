let read_file path =
  let channel = open_in_bin path in
  let text = really_input_string channel (in_channel_length channel) in
  close_in channel;
  text

let check path =
  match read_file path with
  | exception Sys_error message ->
    prerr_endline message;
    2
  | text ->
    let verdict = Mm2_lean.Check.program text in
    print_endline verdict;
    if verdict = "ok" then 0 else 1

let () =
  match Array.to_list Sys.argv with
  | [ _; "check"; path ] -> exit (check path)
  | _ ->
    prerr_endline "usage: mm2 check FILE";
    exit 2
