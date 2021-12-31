{
  description = "A flake demonstrating how to build OCaml projects with Dune";

  inputs = {
    # Convenience functions for writing flakes
    flake-utils.url = "github:numtide/flake-utils";
    # Precisely filter files copied to the nix store
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = { self, nixpkgs, flake-utils, nix-filter }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        ocamlPackages = nixpkgs.legacyPackages.${system}.ocamlPackages;

        # OCaml source files
        ocaml-src = nix-filter.lib.filter {
          root = ./.;
          include = [
            "dune-project"
            (nix-filter.lib.matchExt "opam")
            (nix-filter.lib.inDirectory "bin")
            (nix-filter.lib.inDirectory "lib")
            (nix-filter.lib.inDirectory "test")
          ];
        };

        # Nix source files
        nix-src = nix-filter.lib.filter {
          root = ./.;
          include = [
            (nix-filter.lib.matchExt "nix")
          ];
        };
      in
      {
        # Executed by `nix flake check`
        checks = {
          # Run Dune tests
          hello = ocamlPackages.buildDunePackage {
            pname = "hello";
            src = ocaml-src;
            version = "0.1.0";
            useDune2 = true;
            doCheck = true;
          };

          # Check generated OPAM file
          opam = pkgs.runCommand "check-opam"
            {
              nativeBuildInputs = [
                pkgs.diffutils
                ocamlPackages.findlib

                self.checks.${system}.hello
              ];
            }
            ''
              mkdir $out

              echo "checking generated opam files"

              set +e
              diff -u '${./hello.opam}' "$(ocamlfind query hello)/opam"
              exitcode=$?
              set -e

              if [ $exitcode -ne 0 ]; then
                echo "error: The opam file differs from the one found in the nix store"
                echo "hint: Run \`dune build\` in the source tree to regenerate it"
                exit $exitcode
              fi
            '';


          # Check Nix formatting
          nixpkgs-fmt = pkgs.runCommand "check-nixpkgs-fmt"
            {
              nativeBuildInputs = [
                pkgs.nixpkgs-fmt
              ];
            }
            ''
              mkdir $out
              nixpkgs-fmt --check ${nix-src}
            '';
        };

        # Executed by `nix build .#<name>`
        packages.hello = ocamlPackages.buildDunePackage {
          pname = "hello";
          version = "0.1.0";
          src = ocaml-src;
          useDune2 = true;
        };
        packages.hello-doc = pkgs.stdenv.mkDerivation {
          name = "hello-doc";
          src = ocaml-src;
          nativeBuildInputs = [
            ocamlPackages.dune_2
            ocamlPackages.ocaml
            ocamlPackages.odoc
          ];

          buildPhase = "dune build @doc";

          installPhase = ''
            mkdir -p $out/doc
            mv _build/default/_doc/_html $out/doc/hello
          '';
        };

        # Executed by `nix build`
        defaultPackage = self.packages.${system}.hello;

        # Executed by `nix run .#<name>`
        apps.hello = pkgs.stdenv.mkDerivation {
          pname = "hello";
          version = "0.1.0";
          src = ocaml-src;

          nativeBuildInputs = [
            ocamlPackages.dune_2
            ocamlPackages.ocaml
          ];

          buildPhase = "dune build bin/main.exe";

          installPhase = ''
            mkdir -p $out/bin
            mv _build/default/bin/main.exe $out/bin/hello
          '';
        };

        # Executed by `nix run`
        defaultApp = self.apps.${system}.hello;

        # Used by `nix develop`
        devShell = pkgs.mkShell {
          nativeBuildInputs = [
            ocamlPackages.dune_2
            ocamlPackages.ocaml

            # For `dune build @doc`
            ocamlPackages.odoc

            # Editor support
            # pkgs.ocamlformat # FIXME: fails to build `uunf` on my M1 mac :(
            ocamlPackages.merlin
            ocamlPackages.ocaml-lsp
            ocamlPackages.ocamlformat-rpc-lib
          ];
        };
      });
}
