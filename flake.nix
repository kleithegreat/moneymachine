{
  description = "Auditable agentic quant research and multi-modal data fabric";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      # The live cluster image Python environment (kept lean for deployment).
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
      # Python environment scoped to ML/stats, fabric analytics, and MCP tooling.
      fabricPythonFor = pkgs: pkgs.python313.withPackages (ps: with ps; [
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
        numpy
        scipy
        duckdb
        pyarrow
        pydantic
        pyyaml
        types-pyyaml
        zstandard
        tantivy
        mcp
        xarray
      ]);
      linux = nixpkgs.legacyPackages.x86_64-linux;
      workloads = import ./ops/workloads.nix { lib = nixpkgs.lib; };
      apps64 = {
        # The deployer (CLUSTER.md): the caller's kubectl, skopeo and nix; the manifests and the image come from this flake.
        apply = linux.writeShellApplication {
          name = "apply";
          runtimeInputs = [ linux.jq ];
          text = ''
            manifests=${self.packages.x86_64-linux.manifests}
            registry=${workloads.registry}
          '' + builtins.readFile ./ops/apply.sh;
        };
        push = linux.writeShellApplication {
          name = "push";
          runtimeInputs = [ linux.jq linux.coreutils ];
          text = ''
            rev=${if self ? rev then builtins.substring 0 7 self.rev else ""}
            imageDrv=${builtins.unsafeDiscardOutputDependency self.packages.x86_64-linux.image.drvPath}
            registry=${workloads.registry}
          '' + builtins.readFile ./ops/push.sh;
        };
        session = linux.writeShellApplication {
          name = "session";
          runtimeInputs = [ linux.coreutils linux.util-linux linux.procps ];
          text = builtins.readFile ./ops/session.sh;
        };
        # Heavy work on this PC (CLAUDE.md): `nix run .#heavy -- 8G pytest ...`.
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
      # The websocket recorder (recorder/RECORDER.md): OCaml 5 with Jane Street's stack.
      mmrecFor = pkgs:
        let
          o = pkgs.ocamlPackages;
          libs = [ o.core o.core_unix o.async o.async_ssl o.async_websocket o.ppx_jane o.yojson o.curl o.jsont ];
          testLibs = libs ++ [ o.ppx_expect o.base_quickcheck ];
          src = pkgs.lib.fileset.toSource {
            root = ./recorder;
            fileset = pkgs.lib.fileset.difference ./recorder (
              pkgs.lib.fileset.unions [ ./recorder/RECORDER.md ./recorder/VAULT.md ]
            );
          };
        in {
          package = o.buildDunePackage {
            pname = "mmrec";
            version = "0";
            inherit src;
            duneVersion = "3";
            buildInputs = libs ++ [ pkgs.zstd.dev pkgs.zstd pkgs.curl.dev pkgs.curl ];
            doCheck = false;
          };
          tests = pkgs.stdenv.mkDerivation {
            name = "mmrec-tests";
            inherit src;
            nativeBuildInputs = [ o.ocaml o.dune_3 o.findlib pkgs.zstd pkgs.libfaketime ];
            buildInputs = testLibs ++ [ pkgs.zstd.dev pkgs.curl.dev pkgs.curl ];
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
            buildInputs = testLibs ++ [ o.ppx_js_style pkgs.zstd.dev pkgs.curl.dev pkgs.curl ];
            buildPhase = ''
              export HOME=$TMPDIR DUNE_CACHE=disabled
              dune build --root . @fmt @check @lint
            '';
            installPhase = "touch $out";
          };
        };
      # Default OCaml systems implementation of the Data Fabric CAS, PIT core, and CLI.
      mmfabricFor = pkgs:
        let
          o = pkgs.ocamlPackages;
          libs = [ o.core o.core_unix o.digestif o.yojson o.ppx_jane ];
          testLibs = libs ++ [ o.ppx_expect o.base_quickcheck ];
          src = pkgs.lib.fileset.toSource {
            root = ./fabric/ocaml;
            fileset = ./fabric/ocaml;
          };
        in {
          package = o.buildDunePackage {
            pname = "mmfabric";
            version = "0";
            inherit src;
            duneVersion = "3";
            buildInputs = libs ++ [ pkgs.zstd.dev pkgs.zstd ];
            doCheck = false;
            meta.mainProgram = "mmfabric";
          };
          tests = pkgs.stdenv.mkDerivation {
            name = "mmfabric-tests";
            inherit src;
            nativeBuildInputs = [ o.ocaml o.dune_3 o.findlib pkgs.zstd ];
            buildInputs = testLibs ++ [ pkgs.zstd.dev pkgs.zstd ];
            buildPhase = ''
              export HOME=$TMPDIR DUNE_CACHE=disabled
              dune build --root . --display short @runtest
            '';
            installPhase = "touch $out";
          };
          style = pkgs.stdenv.mkDerivation {
            name = "fabric-ocaml-style";
            inherit src;
            nativeBuildInputs = [ o.ocaml o.dune_3 o.findlib o.ocamlformat o.ppx_js_style pkgs.zstd ];
            buildInputs = testLibs ++ [ o.ppx_js_style pkgs.zstd.dev pkgs.zstd ];
            buildPhase = ''
              export HOME=$TMPDIR DUNE_CACHE=disabled
              dune build --root . @fmt @check @lint
            '';
            installPhase = "touch $out";
          };
        };
      # OCaml markdown wiki and repository docs server (`wiki/server/`).
      mmwikiFor = pkgs:
        let
          o = pkgs.ocamlPackages;
          libs = [ o.core o.core_unix o.cmarkit o.tiny_httpd o.yojson o.ppx_jane ];
          testLibs = libs ++ [ o.ppx_expect ];
          src = pkgs.lib.fileset.toSource {
            root = ./wiki/server;
            fileset = ./wiki/server;
          };
        in {
          package = o.buildDunePackage {
            pname = "mmwiki";
            version = "0";
            inherit src;
            duneVersion = "3";
            buildInputs = libs;
            doCheck = false;
            meta.mainProgram = "mmwiki";
          };
          tests = pkgs.stdenv.mkDerivation {
            name = "mmwiki-tests";
            inherit src;
            nativeBuildInputs = [ o.ocaml o.dune_3 o.findlib ];
            buildInputs = testLibs;
            buildPhase = ''
              export HOME=$TMPDIR DUNE_CACHE=disabled
              dune build --root . --display short @runtest
            '';
            installPhase = "touch $out";
          };
          style = pkgs.stdenv.mkDerivation {
            name = "wiki-style";
            inherit src;
            nativeBuildInputs = [ o.ocaml o.dune_3 o.findlib o.ocamlformat o.ppx_js_style ];
            buildInputs = testLibs ++ [ o.ppx_js_style ];
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
          python = fabricPythonFor pkgs;
        in
        {
          default = pkgs.mkShell {
            # OCaml toolchain and libraries across recorder/, fabric/ocaml/, and wiki/server/.
            inputsFrom = [ (mmrecFor pkgs).style (mmfabricFor pkgs).style (mmwikiFor pkgs).style ];
            packages = with pkgs; [
              ocamlPackages.ocaml-lsp
              sqlite
              python
              duckdb
              zstd
              uv
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
        # The live workloads' manifests, one `<name>.json` each, at a placeholder digest (ops/workloads.nix); `apply` sets the image.
        manifests = pkgs.runCommand "manifests" { } ''
          mkdir $out
          ${pkgs.lib.concatStrings (pkgs.lib.mapAttrsToList
            (name: m: "cp ${pkgs.writeText "${name}.json" (builtins.toJSON m)} $out/${name}.json\n") workloads.manifests)}
        '';
        # The cluster's one image: kept lean via `pythonFor` + `mmrec`.
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
        # Pinned Lean v4.34.0 toolchain.
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
        # Critical Lean 4 causal & PodView proofs for the Data Fabric (`fabric/lean`).
        fabric-proofs = pkgs.stdenv.mkDerivation {
          pname = "fabric-proofs";
          version = "0";
          src = ./fabric/lean;
          nativeBuildInputs = [ self.packages.${pkgs.stdenv.hostPlatform.system}.lean pkgs.autoPatchelfHook pkgs.gnugrep ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.gmp ];
          dontConfigure = true;
          buildPhase = ''
            if grep -rnE '\b(sorry|admit|axiom|native_decide)\b' Fabric.lean Fabric; then
              echo "forbidden proof keyword in fabric/lean" >&2
              exit 1
            fi
            export HOME=$TMPDIR
            lake build
          '';
          installPhase = "mkdir -p $out && touch $out/ok";
        };
        # The Lean reference kernel (Stage 6 subproject), built offline by Lake.
        refmm = pkgs.stdenv.mkDerivation {
          pname = "refmm";
          version = "0";
          src = ./subprojects/confirmation-wall/reference/lean;
          nativeBuildInputs = [ self.packages.${pkgs.stdenv.hostPlatform.system}.lean pkgs.autoPatchelfHook ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.gmp ];
          dontConfigure = true;
          buildPhase = "export HOME=$TMPDIR; lake build";
          installPhase = "install -D .lake/build/bin/refmm $out/bin/refmm";
        };
        mmrec = (mmrecFor pkgs).package;
        mmfabric = (mmfabricFor pkgs).package;
        mmwiki = (mmwikiFor pkgs).package;
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

      # Tests as checks: `nix run .#test` builds them, then runs what stays on this PC (`-m local`).
      checks.x86_64-linux =
        let
          system = "x86_64-linux";
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs) lib;
          fs = lib.fileset;
          python = pythonFor pkgs;
          fabricPython = fabricPythonFor pkgs;
          toolsFor = py: [ py pkgs.git pkgs.sqlite pkgs.jq pkgs.openssh pkgs.rsync pkgs.procps pkgs.util-linux ];
          prose = [
            ./docs
            ./audit/reviews
            ./audit/decisions.md
            ./audit/erasure
            ./CLAUDE.md
            ./PROGRESS.md
            ./AGENTS.md
            ./pods/README.md
            ./wiki
            ./flake.nix
            ./flake.lock
            ./.githooks
            ./.gitignore
            ./ops/units.nix
            ./ops/workloads.nix
            ./subprojects/confirmation-wall
            ./fabric/lean
            ./fabric/ocaml
          ];
          # The tracked tree minus prose and non-Python subtrees so non-Python edits leave Python checks cached.
          srcAll = fs.toSource { root = ./.; fileset = fs.difference ./. (fs.unions prose); };
          pytestCheck =
            { name, paths, src ? srcAll, select ? "not local", env ? { }, py ? python }:
            pkgs.stdenv.mkDerivation ({
              inherit name src env;
              nativeBuildInputs = toolsFor py;
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
          # The mirror copies diskguard.VOLUMES, and the workloads' table must say the same until the mirror leaves Python.
          volume-table = pkgs.runCommand "volume-table" { } ''
            sed -n '/^VOLUMES = {/,/^}/p' ${./ops/diskguard.py} | sed -n 's/^ *"\([a-z]*\)": "\([^"]*\)",$/\1 \2/p' | LC_ALL=C sort > guard
            printf '%s\n' ${lib.escapeShellArgs (map (v: "${v.name} ${v.path}") workloads.mirrored)} | LC_ALL=C sort > table
            test -s guard
            diff table guard
            touch $out
          '';
          workload-boundaries = pkgs.runCommand "workload-boundaries" { nativeBuildInputs = [ pkgs.jq ]; } ''
            bash ${./ops/check-workloads.sh} ${self.packages.${system}.manifests}
            touch $out
          '';
          # ops/test-session.sh drives ops/session.sh from outside with its tools stubbed (no network, no namespaces).
          test-session = pkgs.runCommand "test-session"
            {
              src = fs.toSource { root = ./ops; fileset = fs.unions [ ./ops/session.sh ./ops/test-session.sh ]; };
              nativeBuildInputs = [ pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.util-linux pkgs.procps pkgs.findutils ];
            }
            ''
              cp -r $src ops && chmod -R u+w ops
              patchShebangs ops
              ops/test-session.sh
              touch $out
            '';
          style = pkgs.stdenv.mkDerivation {
            name = "style";
            src = srcAll;
            nativeBuildInputs = toolsFor fabricPython;
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
          fabric = pytestCheck { name = "fabric"; paths = "fabric/tests"; py = fabricPython; };
          fabric-proofs = self.packages.${system}.fabric-proofs;
          mmfabric-tests = (mmfabricFor pkgs).tests;
          fabric-ocaml-style = (mmfabricFor pkgs).style;
          mmwiki-tests = (mmwikiFor pkgs).tests;
          wiki-style = (mmwikiFor pkgs).style;
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
          mmfabric = app (mmfabricFor pkgs).package;
          mmwiki = app (mmwikiFor pkgs).package;
          wiki = app (pkgs.writeShellApplication {
            name = "wiki";
            runtimeInputs = [ (mmwikiFor pkgs).package ];
            text = ''exec mmwiki serve "$@"'';
          });
          test = app (pkgs.writeShellApplication {
            name = "test";
            runtimeInputs = [ pkgs.nix pkgs.git pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.bubblewrap ];
            text = ''
              nix flake check -L "$@"
              nix develop -c pytest -m local
              ops/test-gpt.sh
              ops/check-times.sh
              ops/test-hooks.sh
              ops/test-workloads.sh
            '';
          });
        };

      homeManagerModules.default = import ./ops/units.nix { inherit (apps64) diskguard; };

      formatter = forAll (pkgs: pkgs.nixfmt-rfc-style);
    };
}
