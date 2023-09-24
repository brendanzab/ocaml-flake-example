{
  description = "A flake demonstrating how to build OCaml projects with Dune";

  # Flake dependency specification
  #
  # To update all flake inputs:
  #
  #     $ nix flake update --commit-lockfile
  #
  # To update individual flake inputs:
  #
  #     $ nix flake lock --update-input <input> ... --commit-lockfile
  #
  inputs = {
    # Convenience functions for writing flakes
    flake-utils.url = "github:numtide/flake-utils";
    # Precisely filter files copied to the nix store
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = { self, nixpkgs, flake-utils, nix-filter }:
    # Construct an output set that supports a number of default systems
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
        # Exposed packages that can be built or run with `nix build` or
        # `nix run` respectively:
        #
        #     $ nix build .#<name>
        #     $ nix run .#<name> -- <args?>
        #
        packages = {
          # The package that will be built or run by default. For example:
          #
          #     $ nix build
          #     $ nix run -- <args?>
          #
          default = self.packages.${system}.hello;

          hello = ocamlPackages.buildDunePackage {
            pname = "hello";
            version = "0.1.0";
            duneVersion = "3";
            src = sources.ocaml;

            buildInputs = [
                # Ocaml package dependencies needed to build go here.
            ];

            strictDeps = true;

            preBuild = ''
              dune build hello.opam
            '';
          };
        };

        # Flake checks
        #
        #     $ nix flake check
        #
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

        # Development shells
        #
        #    $ nix develop .#<name>
        #    $ nix develop .#<name> --command dune build @test
        #
        # [Direnv](https://direnv.net/) is recommended for automatically loading
        # development environments in your shell. For example:
        #
        #    $ echo "use flake" > .envrc && direnv allow
        #    $ dune build @test
        #
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
