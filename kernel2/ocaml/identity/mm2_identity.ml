let policy_path = "kernel2/protected-windows.json"
let sha256 text = Digestif.SHA256.to_hex (Digestif.SHA256.digest_string text)
let part label text = Printf.sprintf "%s %d\n%s\n" label (String.length text) text

let build ~sources ~toolchain =
  let sources = List.filter (fun (path, _) -> path <> policy_path) sources in
  let files = List.map (fun (path, bytes) -> part "source" (part path bytes)) sources in
  let tools = List.map (part "toolchain") toolchain in
  sha256 (String.concat "" (files @ tools))
;;

let identity ~build ~windows ~inputs =
  let named = List.map (fun (name, text) -> part name text) inputs in
  sha256 (String.concat "" (part "build" build :: part "windows" windows :: named))
;;

let embedded_sources () = Embedded.sources
let embedded_toolchain () = Embedded.toolchain
let embedded_windows () = Mm2_lean.Machine.windows_json ()
let embedded_build () = build ~sources:Embedded.sources ~toolchain:Embedded.toolchain
let compile_windows text = Mm2_lean.Machine.compile_windows text
