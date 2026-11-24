{
  description = "Auditable agentic quant research";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      # The research environment: the dev shell's and the cluster image's, one closure.
      pythonFor = pkgs: pkgs.python313.withPackages (ps: with ps; [
        polars
        httpx
        certifi
        pytest
        mypy
        ruff
        pytest-xdist
        pytest-timeout
        lz4
        boto3
      ]);
      linux = nixpkgs.legacyPackages.x86_64-linux;
      apps64 = {
        session = linux.writeShellApplication {
          name = "session";
          runtimeInputs = [ linux.coreutils linux.util-linux linux.procps ];
          text = builtins.readFile ./ops/session.sh;
        };
        # Heavy work on this PC (CLAUDE.md, Running things): `nix run .#heavy -- 8G pytest ...`.
        heavy = linux.writeShellApplication {
          name = "heavy";
          runtimeInputs = [ linux.coreutils ];
          text = ''
            memory=$1; shift
            exec systemd-run --user --scope -p MemoryMax="$memory" -p MemorySwapMax=1G choom -n 1000 -- nix develop -c "$@"
          '';
        };
        # The timers' jobs (ops/units.nix): they run the working directory's files with this flake's Python.
        diskguard = linux.writeShellApplication {
          name = "diskguard";
          runtimeInputs = [ (pythonFor linux) linux.libnotify ];
          text = "exec python ops/diskguard.py";
        };
      };
      # The websocket recorder (recorder/RECORDER.md): OCaml 5 with Jane Street's stack, every library from the pinned
      # nixpkgs. Its tests need `zstd` (an independent decoder) and loopback sockets, which the sandbox has.
      mmrecFor = pkgs:
        let
          o = pkgs.ocamlPackages;
          libs = [ o.core o.core_unix o.async o.async_ssl o.async_websocket o.ppx_jane o.yojson ];
          testLibs = libs ++ [ o.ppx_expect o.base_quickcheck ];
          src = pkgs.lib.fileset.toSource {
            root = ./recorder;
            fileset = pkgs.lib.fileset.difference ./recorder ./recorder/RECORDER.md;
          };
        in {
          package = o.buildDunePackage {
            pname = "mmrec";
            version = "0";
            inherit src;
            duneVersion = "3";
            buildInputs = libs ++ [ pkgs.zstd.dev pkgs.zstd ];
            doCheck = false;
          };
          tests = pkgs.stdenv.mkDerivation {
            name = "mmrec-tests";
            inherit src;
            nativeBuildInputs = [ o.ocaml o.dune_3 o.findlib pkgs.zstd pkgs.libfaketime ];
            buildInputs = testLibs ++ [ pkgs.zstd.dev ];
            buildPhase = ''
              export HOME=$TMPDIR DUNE_CACHE=disabled
              dune build --root . --display short @runtest
            '';
            installPhase = "touch $out";
          };
          style = pkgs.stdenv.mkDerivation {
            name = "recorder-style";
            inherit src;
            nativeBuildInputs = [ o.ocaml o.dune_3 o.findlib o.ocamlformat o.ppx_js_style pkgs.zstd ];
            buildInputs = testLibs ++ [ o.ppx_js_style pkgs.zstd.dev ];
            buildPhase = ''
              export HOME=$TMPDIR DUNE_CACHE=disabled
              dune build --root . @fmt @check @lint
            '';
            installPhase = "touch $out";
          };
        };
    in
    {
      devShells = forAll (pkgs:
        let
          tools = self.packages.${pkgs.stdenv.hostPlatform.system};
          python = pythonFor pkgs;
        in
        {
          default = pkgs.mkShell {
            # The recorder's OCaml toolchain and libraries, with the editor's language server (.vscode/settings.json).
            inputsFrom = [ (mmrecFor pkgs).style ];
            packages = with pkgs; [
              ocamlPackages.ocaml-lsp
              sqlite
              python
              jq
              git
              openssh
              rsync
              libnotify
              tools.lean
              kubectl
              skopeo
              bubblewrap
            ];
            shellHook = "git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git config core.hooksPath .githooks";
          };
        });

      packages = forAll (pkgs: let system = pkgs.stdenv.hostPlatform.system; in {
        # The cluster's one image (CLAUDE.md, heavy jobs): the research environment and this commit's tree. The
        # workloads find every tool on PATH; /bin and /usr hold only /bin/sh and /usr/bin/env, as on the dev hosts.
        image = let
          tools = with pkgs; [ (pythonFor pkgs) coreutils util-linux sqlite self.packages.${system}.mmrec cacert ];
        in pkgs.dockerTools.buildLayeredImage {
          name = "moneymachine";
          tag = self.shortRev or "dirty";
          contents = [ pkgs.dockerTools.binSh pkgs.dockerTools.usrBinEnv ] ++ tools;
          extraCommands = ''
            mkdir -p app scratch tmp etc && cp -r ${self} app/repo
            printf 'root:x:0:0::/root:/bin/sh\nlive:x:1000:100::/scratch:/bin/sh\n' > etc/passwd
            printf 'root:x:0:\nusers:x:100:\n' > etc/group
          '';
          config = {
            User = "1000:100";
            WorkingDir = "/app/repo";
            Env = [
              "HOME=/scratch"
              "PYTHONDONTWRITEBYTECODE=1"
              "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              "PATH=${pkgs.lib.makeBinPath tools}:/bin:/usr/bin"
            ];
          };
        };
        # The adopted reference kernel's toolchain (stage 6): Lean v4.34.0.
        lean = pkgs.stdenv.mkDerivation {
          pname = "lean";
          version = "4.34.0";
          src = pkgs.fetchurl {
            url = "https://github.com/leanprover/lean4/releases/download/v4.34.0/lean-4.34.0-linux.tar.zst";
            sha256 = "0sv4dclf287zaavp56c2a5jynfbgqqg8xlmvzk05vj4qc0sriana";
          };
          nativeBuildInputs = [ pkgs.zstd pkgs.autoPatchelfHook ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.gmp pkgs.ncurses ];
          unpackPhase = "tar --zstd -xf $src";
          installPhase = "cp -r lean-4.34.0-linux $out";
          autoPatchelfIgnoreMissingDeps = true;
        };
        # The Lean reference kernel (stage 6), built offline by Lake. Its source is `reference/lean` alone, so it is cached by that;
        # building the `Ref` library checks every theorem, so this build is the proof check.
        refmm = pkgs.stdenv.mkDerivation {
          pname = "refmm";
          version = "0";
          src = ./reference/lean;
          nativeBuildInputs = [ self.packages.${pkgs.stdenv.hostPlatform.system}.lean pkgs.autoPatchelfHook ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.gmp ];
          dontConfigure = true;
          buildPhase = "export HOME=$TMPDIR; lake build";
          installPhase = "install -D .lake/build/bin/refmm $out/bin/refmm";
        };
        mmrec = (mmrecFor pkgs).package;
        whitepaper = pkgs.runCommand "whitepaper.pdf" {
          nativeBuildInputs = [
            (pkgs.texliveBasic.withPackages (ps: with ps; [
              latexmk lm microtype amsmath booktabs tools enumitem listings xcolor pgf hyperref geometry
            ]))
          ];
        } ''
          cp ${./docs/whitepaper.tex} whitepaper.tex
          latexmk -pdf -interaction=nonstopmode -halt-on-error whitepaper.tex
          cp whitepaper.pdf $out
        '';
      });

      # Tests as checks (CLAUDE.md, Running things): `nix run .#test` builds them, on remote builders when the host has
      # any, then runs what stays on this PC (`-m local`). x86_64-linux only: every host is one.
      checks.x86_64-linux =
        let
          system = "x86_64-linux";
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) lib;
          fs = lib.fileset;
          python = pythonFor pkgs;
          tools = [ python pkgs.git pkgs.sqlite pkgs.jq pkgs.openssh pkgs.rsync pkgs.procps pkgs.util-linux ];
          prose = [ ./docs ./audit/reviews ./audit/decisions.md ./audit/erasure ./CLAUDE.md ./PROGRESS.md
                   ./flake.nix ./flake.lock ./.githooks ./.gitignore ./ops/units.nix ];
          # The tracked tree minus prose and build files, so a commit that only edits those leaves every check cached; a test that
          # reads excluded prose fails in its check, which is how a missed dependency shows.
          srcAll = fs.toSource { root = ./.; fileset = fs.difference ./. (fs.unions prose); };
          pytestCheck =
            { name, paths, src ? srcAll, select ? "not local", env ? { } }:
            pkgs.stdenv.mkDerivation ({
              inherit name src env;
              nativeBuildInputs = tools;
              dontConfigure = true;
              buildPhase = ''
                export HOME=$TMPDIR SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
                patchShebangs ops
                mkdir -p data
                pytest -m ${lib.escapeShellArg select} -n $NIX_BUILD_CORES -p no:cacheprovider ${paths}
              '';
              installPhase = "touch $out";
            });
        in
        {
          progress-cap = pkgs.runCommand "progress-cap" { } ''
            test "$(stat -c %s ${./PROGRESS.md})" -le 12288 || { echo "PROGRESS.md is over 12 KiB"; exit 1; }
            touch $out
          '';
          # The ratchet: no Python outside audit/ beyond this list, and every file on it exists. A step that deletes Python
          # deletes its lines here in the same commit; the list ends empty and the check stays, so no Python comes back.
          python-left =
            let
              listed = [
            "cli.py"
            "conftest.py"
            "ingest/__init__.py"
            "ingest/archive.py"
            "ingest/compute.py"
            "ingest/datalayer.py"
            "ingest/live.py"
            "ingest/sources_record.py"
            "ingest/terms.py"
            "ingest/tests/__init__.py"
            "ingest/tests/crash_helpers.py"
            "ingest/tests/test_archive.py"
            "ingest/tests/test_archive_has_no_bars.py"
            "ingest/tests/test_compute.py"
            "ingest/tests/test_crash_recovery.py"
            "ingest/tests/test_datalayer.py"
            "ingest/tests/test_live.py"
            "ingest/tests/test_recorder_spec.py"
            "ingest/tests/test_terms.py"
            "ops/commitcheck.py"
            "ops/diskguard.py"
            "ops/live.py"
            "ops/style.py"
            "ops/test_commitcheck.py"
            "ops/test_diskguard.py"
            "ops/test_gpt.py"
            "ops/test_live.py"
            "ops/test_live_churn.py"
            "ops/test_session.py"
              ];
              src = fs.toSource { root = ./.; fileset = fs.difference ./. ./audit; };
            in
            pkgs.runCommand "python-left" { nativeBuildInputs = [ pkgs.findutils pkgs.diffutils ]; preferLocalBuild = true; } ''
              cd ${src}
              find . -type f ! -name '*.py' -print0 | while IFS= read -r -d "" f; do
                if head -n 1 "$f" | grep -aq '^#!.*python'; then echo "''${f#./}"; fi
              done > $TMPDIR/shebang
              find . -type f -name '*.py' | sed 's|^\./||' | cat - $TMPDIR/shebang | LC_ALL=C sort > $TMPDIR/found
              printf '%s\n' ${lib.escapeShellArgs listed} | LC_ALL=C sort > $TMPDIR/listed
              if ! diff $TMPDIR/listed $TMPDIR/found > $TMPDIR/diff; then
                sed -n 's/^> /Python file not on the list: /p' $TMPDIR/diff
                sed -n 's/^< /listed Python file is gone: /p' $TMPDIR/diff
                exit 1
              fi
              touch $out
            '';
          style = pkgs.stdenv.mkDerivation {
            name = "style";
            src = srcAll;
            nativeBuildInputs = tools;
            dontConfigure = true;
            buildPhase = ''
              export HOME=$TMPDIR
              files=$(python ops/style.py)
              ruff format --check $files
              ruff check --no-cache $files
              mypy --cache-dir=$TMPDIR/mypy $files
            '';
            installPhase = "touch $out";
          };
          ingest = pytestCheck { name = "ingest"; paths = "ingest/tests"; };
          ops = pytestCheck { name = "ops"; paths = "ops"; };
          lean-proofs = self.packages.${system}.refmm;
          mmrec-tests = (mmrecFor pkgs).tests;
          recorder-style = (mmrecFor pkgs).style;
        };

      apps.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          app = script: {
            type = "app";
            program = pkgs.lib.getExe script;
          };
        in
        builtins.mapAttrs (_: app) apps64
        // {
          test = app (pkgs.writeShellApplication {
            name = "test";
            runtimeInputs = [ pkgs.nix pkgs.git pkgs.coreutils pkgs.findutils pkgs.gnugrep ];
            text = ''
              nix flake check -L "$@"
              nix develop -c pytest -m local
              ops/test-python-left.sh
            '';
          });
        };

      homeManagerModules.default = import ./ops/units.nix { inherit (apps64) diskguard; };

      formatter = forAll (pkgs: pkgs.nixfmt-rfc-style);
    };
}
