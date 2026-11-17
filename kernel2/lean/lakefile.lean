import Lake
open Lake DSL

package engine where
  leanOptions := #[⟨`warningAsError, true⟩]

/-- The tracked policy file (A13). Lake hashes it, so a release rebuilds `Engine.Policy`, which compiles it in. -/
input_file protectedWindows where
  path := "../protected-windows.json"
  text := true

@[default_target]
lean_lib Engine where
  needs := #[protectedWindows]
