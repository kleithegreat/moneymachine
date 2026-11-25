import Lake
open Lake DSL System

def envFlags (var : String) (prefixes : Array String) : IO (Array String) := do
  let some val ← IO.getEnv var | return #[]
  let tokens := val.splitOn " " |>.filter (!·.isEmpty) |>.toArray
  let mut out : Array String := #[]
  let mut takeNext := false
  for tok in tokens do
    if takeNext then
      out := out.push tok
      takeNext := false
    else if tok == "-isystem" || tok == "-I" || tok == "-L" then
      out := out.push tok
      takeNext := true
    else if prefixes.any (tok.startsWith ·) then
      out := out.push tok
  return out

def envLinkArgs : IO (Array String) := do
  let ldirs ← envFlags "NIX_LDFLAGS" #["-L"]
  let rpaths := ldirs.map fun f =>
    if f.startsWith "-L" then s!"-Wl,-rpath,{f.drop 2}" else f
  return ldirs ++ rpaths ++ #["-lmpfr", "-lgmp"]

package engine where
  leanOptions := #[⟨`warningAsError, true⟩]
  moreLinkArgs := run_io envLinkArgs

/-- The tracked policy file (A13). Lake hashes it, so a release rebuilds `Engine.Policy`, which compiles it in. -/
input_file protectedWindows where
  path := "../protected-windows.json"
  text := true

target mpfrOpsO pkg : FilePath := do
  let oFile := pkg.buildDir / "c" / "mpfr_ops.o"
  let srcJob ← inputTextFile <| pkg.dir / "c" / "mpfr_ops.c"
  let cflags ← envFlags "NIX_CFLAGS_COMPILE" #["-I", "-isystem"]
  buildO oFile srcJob (#["-I", (← getLeanIncludeDir).toString] ++ cflags) #["-O2", "-fPIC", "-ffp-contract=off"]

extern_lib mpfrOps pkg := do
  let oJob ← mpfrOpsO.fetch
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "mpfrOps") #[oJob]

@[default_target]
lean_lib Engine where
  needs := #[protectedWindows]
  moreLinkObjs := #[mpfrOpsO]
  moreLinkArgs := #["-lmpfr", "-lgmp"]
