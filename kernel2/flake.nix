{
  description = "Kernel version 2";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      mm2For = pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          lean = self.packages.${system}.lean;
          o = pkgs.ocamlPackages;
          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [ ./lean ./ocaml ./tests ./protected-windows.json ./flake.lock ];
          };
          unpackPhase = ''
            mkdir -p kernel2
            cp -r "$src"/. kernel2/
            chmod -R u+w kernel2
          '';
          build = ''
            export HOME=$TMPDIR DUNE_CACHE=disabled
            (cd kernel2/lean && lake build Engine:static)
            export MM2_ENGINE_LIB=$PWD/kernel2/lean/.lake/build/lib/libengine_Engine.a
          '';
          common = {
            version = "0";
            inherit src unpackPhase;
            nativeBuildInputs = [ lean o.ocaml o.dune_3 o.findlib pkgs.autoPatchelfHook ];
            buildInputs = [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
              pkgs.gmp.dev
              pkgs.gmp
              pkgs.mpfr.dev
              pkgs.mpfr
              o.yojson
              o.digestif
              pkgs.duckdb.dev
              pkgs.duckdb.lib
            ];
            dontConfigure = true;
          };
        in {
          package = pkgs.stdenv.mkDerivation (common // {
            pname = "mm2";
            dontStrip = true;
            buildPhase = build + "(cd kernel2/ocaml && dune build --root . bin/mm2.exe)";
            installPhase = "install -D kernel2/ocaml/_build/default/bin/mm2.exe $out/bin/mm2";
          });
          tests = pkgs.stdenv.mkDerivation (common // {
            pname = "mm2-tests";
            buildPhase = build + ''
              (cd kernel2/ocaml && dune build --root . @runtest)
              sh kernel2/tests/flake-lock.sh
            '';
            installPhase = "touch $out";
          });
          style = pkgs.stdenv.mkDerivation (common // {
            pname = "mm2-style";
            nativeBuildInputs = common.nativeBuildInputs ++ [ o.ocamlformat o.ppx_js_style ];
            buildInputs = common.buildInputs ++ [ o.ppx_js_style ];
            buildPhase = build + ''
              (cd kernel2/ocaml && dune build --root . @fmt @check @lint)
            '';
            installPhase = "touch $out";
          });
          proofs = pkgs.stdenv.mkDerivation {
            pname = "engine-proofs";
            version = "0";
            inherit src unpackPhase;
            nativeBuildInputs = [ lean pkgs.autoPatchelfHook ];
            buildInputs = [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
              pkgs.gmp.dev
              pkgs.gmp
              pkgs.mpfr.dev
              pkgs.mpfr
            ];
            dontConfigure = true;
            buildPhase = "export HOME=$TMPDIR; sh kernel2/lean/check-proofs.sh $PWD/kernel2/lean | tee proofs.txt";
            installPhase = "install -D proofs.txt $out/proofs.txt";
          };
          proofsFixtures = pkgs.stdenv.mkDerivation (common // {
            pname = "engine-proofs-fixtures";
            buildPhase = "export HOME=$TMPDIR; sh kernel2/tests/engine-proofs.sh";
            installPhase = "touch $out";
          });
        };
    in
    {
      devShells = forAll (pkgs:
        let
          tools = self.packages.${pkgs.stdenv.hostPlatform.system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              tools.lean
              ocamlPackages.ocaml
              ocamlPackages.dune_3
              ocamlPackages.findlib
              ocamlPackages.yojson
              ocamlPackages.digestif
              ocamlPackages.ocamlformat
              ocamlPackages.ppx_js_style
              ocamlPackages.ocaml-lsp
              duckdb.dev
              duckdb.lib
              mpfr.dev
              mpfr
              gmp.dev
              gmp
              zlib
              zstd
              pkg-config
              git
            ];
            shellHook = ''
              k2_dir=$(pwd)
              if [ ! -d "$k2_dir/lean" ] && [ -d "$k2_dir/kernel2/lean" ]; then
                k2_dir="$k2_dir/kernel2"
              fi
              export MM2_ENGINE_LIB="$k2_dir/lean/.lake/build/lib/libengine_Engine.a"
            '';
          };
        });

      packages = forAll (pkgs: {
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
        mm2 = (mm2For pkgs).package;
      });

      checks.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          mm2 = mm2For pkgs;
        in
        {
          engine-proofs = mm2.proofs;
          engine-proofs-fixtures = mm2.proofsFixtures;
          mm2-tests = mm2.tests;
          mm2-style = mm2.style;
        };

      formatter = forAll (pkgs: pkgs.nixfmt-rfc-style);
    };
}
