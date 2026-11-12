{
  description = "Auditable agentic quant research";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      # The research environment: the dev shell's and the cluster image's, one closure.
      pythonFor = pkgs: pkgs.python313.withPackages (ps: with ps; [
        # StepM's step-down stopped on the last step's rejection count instead of the cumulative one, and crashed
        # once every model was superior. Upstream's fix (bashtage/arch, main), until a release carries it.
        (arch.overridePythonAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace arch/bootstrap/multiple_comparison.py --replace-fail \
              "while better_models and (len(better_models) < self.k):" \
              "while better_models and (len(all_better_models) < self.k):"
          '';
        }))
        numpy
        scipy
        pandas
        polars
        pyarrow
        statsmodels
        httpx
        certifi
        pytest
        mypy
        ruff
        pytest-xdist
        pytest-timeout
        hypothesis
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
            packages = with pkgs; [
              cargo
              rustc
              clippy
              rustfmt
              rust-analyzer
              pkg-config
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
              tools.claude-code
            ];
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
            shellHook = "git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git config core.hooksPath .githooks";
          };
          # The HL recorder alone (`python -m cli record`), for hosts that only record (ops/oci).
          recorder = pkgs.mkShell {
            packages = [ (pkgs.python313.withPackages (ps: [ ps.httpx ])) ];
          };
          # OCI access (the recorder VM, ops/oci).
          cloud = pkgs.mkShell {
            packages = [ pkgs.oci-cli ];
          };
        });

      packages = forAll (pkgs: let system = pkgs.stdenv.hostPlatform.system; in {
        # The cluster's one image (CLAUDE.md, heavy jobs): the research environment and this commit's tree; `mm` is
        # staged beside it as a content-addressed input, never built here (its identity embeds its build path).
        # The live workloads (CLUSTER.md) run agent sessions in bubblewrap, which binds /bin and /usr into the sandbox:
        # those hold only /bin/sh and /usr/bin/env, as on the dev hosts, and every tool is on PATH. The Nix database
        # serves the sandbox's closure query, read-only; the tools reach it through a file naming them.
        image = let
          tools = with pkgs; [ (pythonFor pkgs) coreutils util-linux self.packages.${system}.claude-code bubblewrap sqlite
                               nix ];
        in pkgs.dockerTools.buildLayeredImageWithNixDb {
          name = "moneymachine";
          tag = self.shortRev or "dirty";
          contents = [ pkgs.dockerTools.binSh pkgs.dockerTools.usrBinEnv (pkgs.writeTextDir "share/tools" (toString tools)) ];
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
              "NIX_REMOTE=local?read-only=true"
              "NIX_CONFIG=extra-experimental-features = read-only-local-store"
              "PATH=${pkgs.lib.makeBinPath tools}:/bin:/usr/bin"
            ];
          };
        };
        # Claude Code, pinned for the agent sessions' frozen harnesses (nixpkgs' packaging of the native binary).
        claude-code = pkgs.stdenvNoCC.mkDerivation {
          pname = "claude-code";
          version = "2.1.304";
          src = pkgs.fetchurl {
            url = "https://downloads.claude.ai/claude-code-releases/2.1.304/linux-x64/claude.zst";
            hash = "sha256-DzRo+ihfESZQ/rO+wpE0Jbe6XIPNTrQRtcdbQIZBa7Y=";
          };
          dontUnpack = true;
          dontStrip = true;
          nativeBuildInputs = [ pkgs.makeBinaryWrapper pkgs.zstd pkgs.autoPatchelfHook ];
          installPhase = ''
            mkdir -p $out/bin
            unzstd -q $src -o $out/bin/claude
            chmod 755 $out/bin/claude
            wrapProgram $out/bin/claude --set DISABLE_AUTOUPDATER 1 --set DISABLE_INSTALLATION_CHECKS 1 \
              --set USE_BUILTIN_RIPGREP 0 --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [ pkgs.alsa-lib ]} \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.procps pkgs.ripgrep pkgs.bubblewrap pkgs.socat ]}
          '';
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
          claude = self.packages.${system}.claude-code;
          tools = [ python claude pkgs.git pkgs.sqlite pkgs.jq pkgs.openssh pkgs.rsync pkgs.procps pkgs.util-linux ];
          prose = [ ./docs ./audit/reviews ./audit/decisions.md ./audit/erasure ./CLAUDE.md ./PROGRESS.md
                   ./flake.nix ./flake.lock ./.githooks ./.gitignore ];
          # The tracked tree minus prose and build files, so a commit that only edits those leaves every check cached; a test that
          # reads excluded prose fails in its check, which is how a missed dependency shows.
          srcAll = fs.toSource { root = ./.; fileset = fs.difference ./. (fs.unions prose); };
          srcCriteria = fs.toSource { root = ./.; fileset = fs.difference ./. (fs.unions [ ./docs ./CLAUDE.md ./PROGRESS.md ]); };
          srcKernel = fs.toSource {
            root = ./.;
            fileset = fs.unions [ ./kernel ./venue/hyperliquid ./gate/compute.py ./gate/__init__.py ./conftest.py ./pyproject.toml ];
          };
          srcMutants = fs.toSource {
            root = ./.;
            fileset = fs.unions [ ./kernel ./venue ./gate ./ingest ./sandbox ./conftest.py ./pyproject.toml ./policy.json ];
          };
          kernelOnly = fs.toSource { root = ./.; fileset = fs.unions [ ./kernel ./venue/hyperliquid ]; };
          cargoDeps = pkgs.rustPlatform.importCargoLock { lockFile = ./kernel/Cargo.lock; };
          cargoTools = [ pkgs.cargo pkgs.rustc pkgs.rustPlatform.cargoSetupHook ];
          # `kernel/target` as `cargo build --release` leaves it, for the checks whose tests build `mm` first.
          kernelTarget = pkgs.stdenv.mkDerivation {
            name = "kernel-target";
            src = kernelOnly;
            inherit cargoDeps;
            cargoRoot = "kernel";
            nativeBuildInputs = cargoTools;
            dontConfigure = true;
            buildPhase = "cd kernel && cargo build --release --offline";
            installPhase = "cp -r target $out";
          };
          pytestCheck =
            { name, paths, src ? srcAll, select ? "not local", kernel ? false, prebuilt ? false, vendor ? null }:
            pkgs.stdenv.mkDerivation ({
              inherit name src;
              nativeBuildInputs = tools ++ lib.optionals kernel cargoTools;
              dontConfigure = true;
              buildPhase = ''
                export HOME=$TMPDIR SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
                patchShebangs ops
                mkdir -p data
                ${lib.optionalString (vendor != null) ''
                  mkdir -p .cargo
                  printf '[source.crates-io]\nreplace-with = "vendored"\n[source.vendored]\ndirectory = "%s"\n' ${vendor} > .cargo/config.toml
                ''}
                ${lib.optionalString prebuilt "cp -r ${kernelTarget} kernel/target && chmod -R u+w kernel/target"}
                pytest -m ${lib.escapeShellArg select} -n $NIX_BUILD_CORES -p no:cacheprovider ${paths}
              '';
              installPhase = "touch $out";
            } // lib.optionalAttrs kernel { inherit cargoDeps; cargoRoot = "kernel"; });
        in
        {
          progress-cap = pkgs.runCommand "progress-cap" { } ''
            test "$(stat -c %s ${./PROGRESS.md})" -le 12288 || { echo "PROGRESS.md is over 12 KiB"; exit 1; }
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
          kernel-cargo = pytestCheck { name = "kernel-cargo"; src = srcKernel; paths = "kernel/tests/test_rust.py -k cargo"; kernel = true; };
          kernel-mutants = pytestCheck { name = "kernel-mutants"; src = srcMutants; paths = "kernel/tests/test_rust.py -k mutant"; kernel = true; };
          kernel-py = pytestCheck {
            name = "kernel-py";
            paths = "kernel/tests/cli kernel/tests/timing kernel/tests/test_mutants_apply.py kernel/tests/test_mutants_classifier.py";
            kernel = true;
            prebuilt = true;
          };
          gate = pytestCheck { name = "gate"; paths = "gate/tests"; kernel = true; prebuilt = true; };
          ingest = pytestCheck { name = "ingest"; paths = "ingest/tests"; };
          criteria = pytestCheck { name = "criteria"; src = srcCriteria; paths = "criteria"; };
          ops = pytestCheck { name = "ops"; paths = "ops"; };
          # The Lean differential runs locally: Lake's binaries need the host's dynamic loader, which the sandbox lacks.
          # mmdump's lock holds the kernel's crates too, so one vendor directory serves both builds.
          reference = pytestCheck {
            name = "reference";
            paths = "reference/tests";
            kernel = true;
            prebuilt = true;
            vendor = pkgs.rustPlatform.importCargoLock { lockFile = ./reference/mmdump/Cargo.lock; };
          };
          sandbox = pytestCheck { name = "sandbox"; paths = "sandbox/tests"; };
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
            runtimeInputs = [ pkgs.nix ];
            text = ''
              nix flake check -L "$@"
              nix develop -c pytest -m local
            '';
          });
        };

      formatter = forAll (pkgs: pkgs.nixfmt-rfc-style);
    };
}
