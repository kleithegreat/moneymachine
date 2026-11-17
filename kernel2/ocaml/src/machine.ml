type t

type chunk =
  { records : bytes
  ; integers : int64 array
  ; doubles : float array
  }

type rows =
  { report : string
  ; trace : string
  }

external start_ : string -> string -> (t, string) result = "mm2_stub_machine_start"

external feed_
  :  t
  -> bytes
  -> int64 array
  -> float array
  -> t * string * string
  = "mm2_stub_machine_feed"

external finish_ : t -> string * string * string = "mm2_stub_machine_finish"
external snapshot : t -> string = "mm2_stub_machine_snapshot"
external count : t -> int64 = "mm2_stub_machine_count"
external retained_bytes : t -> int64 = "mm2_stub_machine_retained"
external windows_json : unit -> string = "mm2_stub_windows_json"
external compile_windows : string -> (string, string) result = "mm2_stub_compile_windows"

external inspect_
  :  string
  -> bytes
  -> int64 array
  -> float array
  -> (string, string) result
  = "mm2_stub_machine_inspect"

let start = start_

let feed state chunk =
  let next, report, trace = feed_ state chunk.records chunk.integers chunk.doubles in
  next, { report; trace }
;;

let finish state =
  let report, trace, summary = finish_ state in
  { report; trace }, summary
;;

let inspect header chunk = inspect_ header chunk.records chunk.integers chunk.doubles
