{
  description = "Auditable agentic quant research";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAll (pkgs:
        let
          tools = self.packages.${pkgs.stdenv.hostPlatform.system};
          python = pkgs.python313.withPackages (ps: with ps; [
            arch
            numpy
            scipy
            pandas
            polars
            pyarrow
            statsmodels
            duckdb
            httpx
            pytest
            hypothesis
          ]);
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
              duckdb
              jq
              git
              tools.lean
              tools.bend
            ];
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
        });

      packages = forAll (pkgs: {
        # Pinned reference-kernel toolchains (stage 6): Lean v4.34.0, the version Bend's --verdict requires.
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
        # A Bun single-file executable: patching its ELF breaks the embedded program, so it runs
        # unmodified in an FHS environment.
        bend = pkgs.buildFHSEnv {
          name = "bend";
          targetPkgs = p: [ p.stdenv.cc.cc.lib ];
          runScript = "${pkgs.stdenv.mkDerivation {
            pname = "bend-dist";
            version = "2.0.37";
            src = pkgs.fetchurl {
              url = "https://github.com/bendlang/bend/releases/download/v2.0.37/bend-2.0.37-linux-x64.tar.gz";
              sha256 = "0ig4qd9w3zpwcjazhq687lah7nxq1i3kzqmdbqqsrjcvldjj9hw4";
            };
            dontFixup = true;
            installPhase = "cp -r . $out";
          }}/bin/bend";
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