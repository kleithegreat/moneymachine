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
            pytest-xdist
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
            ];
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
          # The HL recorder alone (`python -m cli record`), for hosts that only record (ops/oci).
          recorder = pkgs.mkShell {
            packages = [ (pkgs.python313.withPackages (ps: [ ps.httpx ])) ];
          };
          # Cloud data access: AWS (Hyperliquid's requester-pays archives) and BigQuery (public chain datasets).
          cloud = pkgs.mkShell {
            packages = [ pkgs.awscli2 pkgs.google-cloud-sdk pkgs.lz4
                         (pkgs.python313.withPackages (ps: [ ps.google-cloud-bigquery ps.packaging ps.boto3 ps.lz4 ps.numpy ps.polars ])) ];
          };
        });

      packages = forAll (pkgs: {
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