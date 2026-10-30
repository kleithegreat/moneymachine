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
        lz4
        pytest
        pytest-xdist
        pytest-timeout
        hypothesis
      ]);
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
          # Cloud access: AWS (Hyperliquid's requester-pays archives), BigQuery (public chain datasets) and OCI (the
          # recorder VM, ops/oci).
          cloud = pkgs.mkShell {
            packages = [ pkgs.awscli2 pkgs.google-cloud-sdk pkgs.oci-cli pkgs.lz4
                         (pkgs.python313.withPackages (ps: [ ps.google-cloud-bigquery ps.packaging ps.boto3 ps.lz4 ps.numpy ps.polars ])) ];
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

      formatter = forAll (pkgs: pkgs.nixfmt-rfc-style);
    };
}