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
            ];
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
        });

      packages = forAll (pkgs: {
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