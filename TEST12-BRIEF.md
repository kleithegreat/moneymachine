# Test writer: harden step 5's test 12 (`exp` and `log`), branch kernel2-step5

You harden test 12 from its specification only. **Do not open the engine:** nothing under `kernel2/lean/Engine/` and nothing under `kernel2/ocaml/` outside `test/` and `tests/` (`CLAUDE.md`, Correctness: tests are written from the spec without reading the code). You may read `CLAUDE.md`, the `plan/` folder, everything under `kernel2/ocaml/test/` and `kernel2/tests/`, and `kernel2/KERNEL.md`.

**The specification:** `plan/3-kernel-v2.md`, step 5, test 12 (round 8's hardened text) and wall 11. **Why:** `plan/2026-11-18-neon-x4-inputs.md`, the review whose seven loopholes the hardening closes. The recipe for the draws is `plan/arithmetic.py.txt` (`emit_x4_draws`).

**Change** `kernel2/ocaml/test/x4_local.ml`, `kernel2/tests/x4-hosts.sh`, and, only where the spec says so, `x4-specials.lean`, `x4-counts.lean` and `x4_mpfr_stubs.c`, so that each of the seven loopholes is closed as a behaviour the test checks. The input directory is the advisor's and does not exist yet: the test must say exactly what it requires of it in its header contract (files, formats, manifest keys, how its hashes are pinned).

**Rules:**
- **Your quota is small:** commit after each loophole closed.
- Do not change any law's statement, nor any other test.
- **Style gates hold:** `dune build @fmt @check @lint` (ocamlformat janestreet profile, `ppx_js_style`), every warning an error, no handler catching every exception.
- **Run:**
  - `cd kernel2/lean && lake build Engine:static`, then `cd ../ocaml && MM2_ENGINE_LIB=$PWD/../lean/.lake/build/lib/libengine_Engine.a dune build @runtest @fmt @check @lint`, inside `nix develop .#checks.x86_64-linux.mm2-tests -c ...` (from the worktree root; set `TMPDIR` to a folder under `$HOME/.cache`, never `/tmp`);
  - then `nix build --no-link .#checks.x86_64-linux.mm2-style .#checks.x86_64-linux.mm2-tests -L` after `git add` on new files.
  - `x4_local` itself cannot run until the advisor supplies the inputs; it must compile.
- Commit on this branch, each message `kernel v2 test 12: ...` ending with the line `Co-Authored-By: Gemini 4 Hydrogen <noreply@google.com>`. Do not push. Never `pkill -f`.
- If the spec is ambiguous or a loophole cannot be closed as written, stop and say exactly what is unclear.

**Report:** the commits, the input directory's exact contract as the test now states it, and each check's result.
