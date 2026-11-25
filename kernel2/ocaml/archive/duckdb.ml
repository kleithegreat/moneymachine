type cursor

external exec : string -> unit = "mm2_duckdb_exec"
external scalar_int64 : string -> int64 = "mm2_duckdb_scalar_int64"
external scalar_string : string -> string = "mm2_duckdb_scalar_string"
external open_cursor : string -> cursor = "mm2_duckdb_open_cursor"
external close_cursor : cursor -> unit = "mm2_duckdb_close_cursor"

type batch =
  { n : int
  ; times : bytes
  ; lens : int array
  ; values : float array array
  }

external next_quotes_
  :  cursor
  -> (int * bytes * int array * float array array) option
  = "mm2_duckdb_next_quotes"

let next_quotes cursor =
  match next_quotes_ cursor with
  | None -> None
  | Some (n, times, lens, values) -> Some { n; times; lens; values }
;;
