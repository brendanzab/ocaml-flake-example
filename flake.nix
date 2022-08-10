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
        # Legacy packages that have not been converted to flakes
        legacyPackages = nixpkgs.legacyPackages.${system};
        # OCaml packages available on nixpkgs
        ocamlPackages = legacyPackages.ocamlPackages;
        # Library functions from nixpkgs
        lib = legacyPackages.lib;

        # Filtered sources (prevents unecessary rebuilds)
        sources = {
          ocaml = nix-filter.lib {
            root = ./.;
            include = [
              ".ocamlformat"
              "dune-project"
              (nix-filter.lib.inDirectory "bin")
              (nix-filter.lib.inDirectory "lib")
              (nix-filter.lib.inDirectory "test")
            ];
          };

          nix = nix-filter.lib {
            root = ./.;
            include = [
              (nix-filter.lib.matchExt "nix")
            ];
          };
        };
      in
      {
        # Executed by `nix build .#<name>`
        packages = {
          # Executed by `nix build .#hello`
          hello = ocamlPackages.buildDunePackage {
            pname = "hello";
            version = "0.1.0";
            duneVersion = "3";
            src = sources.ocaml;

            strictDeps = true;

            preBuild = ''
              dune build hello.opam
            '';
          };

          # Executed by `nix build`
          default = self.packages.${system}.hello;
        };

        # Executed by `nix run .#<name> <args?>`
        apps = {
          # Executed by `nix run .#hello`
          hello = {
            type = "app";
            program = "${self.packages.${system}.hello}/bin/hello";
          };

          # Executed by `nix run`
          default = self.apps.${system}.hello;
        };

        # Executed by `nix flake check`
        checks = {
          # Run tests for the `hello` package
          hello =
            let
              # Patches calls to dune commands to produce log-friendly output
              # when using `nix ... --print-build-log`. Ideally there would be
              # support for one or more of the following:
              #
              # In Dune:
              #
              # - have workspace-specific dune configuration files
              #
              # In NixPkgs:
              #
              # - allow dune flags to be set in in `ocamlPackages.buildDunePackage`
              # - alter `ocamlPackages.buildDunePackage` to use `--display=short`
              # - alter `ocamlPackages.buildDunePackage` to allow `--config-file=FILE` to be set
              patchDuneCommand =
                let
                  subcmds = [ "build" "test" "runtest" "install" ];
                in
                lib.replaceStrings
                  (lib.lists.map (subcmd: "dune ${subcmd}") subcmds)
                  (lib.lists.map (subcmd: "dune ${subcmd} --display=short") subcmds);
            in

            self.packages.${system}.hello.overrideAttrs
              (oldAttrs: {
                name = "check-${oldAttrs.name}";
                doCheck = true;
                buildPhase = patchDuneCommand oldAttrs.buildPhase;
                checkPhase = patchDuneCommand oldAttrs.checkPhase;
                # skip installation (this will be tested in the `hello-app` check)
                installPhase = "touch $out";
              });

          # Check that the `hello` app exists and is executable
          hello-app = legacyPackages.runCommand "check-hello-app"
            { PROGRAM = self.apps.${system}.hello.program; }
            ''
              echo "checking hello app"
              [[ -e $PROGRAM ]] || (echo "error: $PROGRAM does not exist" && exit 1)
              [[ -x $PROGRAM ]] || (echo "error: $PROGRAM is not executable" && exit 1)
              touch $out
            '';

          # Check Dune and OCaml formatting
          dune-fmt = legacyPackages.runCommand "check-dune-fmt"
            {
              nativeBuildInputs = [
                ocamlPackages.dune_3
                ocamlPackages.ocaml
                legacyPackages.ocamlformat
              ];
            }
            ''
              echo "checking dune and ocaml formatting"
              dune build \
                --display=short \
                --no-print-directory \
                --root="${sources.ocaml}" \
                --build-dir="$(pwd)/_build" \
                @fmt
              touch $out
            '';

          # Check documentation generation
          dune-doc = legacyPackages.runCommand "check-dune-doc"
            {
              ODOC_WARN_ERROR = "true";
              nativeBuildInputs = [
                ocamlPackages.dune_3
                ocamlPackages.ocaml
                ocamlPackages.odoc
              ];
            }
            ''
              echo "checking ocaml documentation"
              dune build \
                --display=short \
                --no-print-directory \
                --root="${sources.ocaml}" \
                --build-dir="$(pwd)/_build" \
                @doc
              touch $out
            '';

          # Check Nix formatting
          nixpkgs-fmt = legacyPackages.runCommand "check-nixpkgs-fmt"
            { nativeBuildInputs = [ legacyPackages.nixpkgs-fmt ]; }
            ''
              echo "checking nix formatting"
              nixpkgs-fmt --check ${sources.nix}
              touch $out
            '';
        };

        # Used by `nix develop`
        devShells = {
          default = legacyPackages.mkShell {
            # Development tools
            packages = [
              # Source file formatting
              legacyPackages.nixpkgs-fmt
              legacyPackages.ocamlformat
              # For `dune build --watch ...`
              legacyPackages.fswatch
              # For `dune build @doc`
              ocamlPackages.odoc
              # OCaml editor support
              ocamlPackages.ocaml-lsp
              # Nicely formatted types on hover
              ocamlPackages.ocamlformat-rpc-lib
              # Fancy REPL thing
              ocamlPackages.utop
            ];

            # Tools from packages
            inputsFrom = [
              self.packages.${system}.hello
            ];
          };
        };
      });
}
