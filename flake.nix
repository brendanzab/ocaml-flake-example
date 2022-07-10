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

        # OCaml source files
        ocaml-src = nix-filter.lib.filter {
          root = ./.;
          include = [
            ".ocamlformat"
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
        # Executed by `nix build .#<name>`
        packages = {
          # Executed by `nix build .#hello`
          hello = ocamlPackages.buildDunePackage {
            pname = "hello";
            version = "0.1.0";
            duneVersion = "2";

            src = ocaml-src;

            outputs = [ "doc" "out" ];

            nativeBuildInputs = [
              ocamlPackages.odoc
            ];

            strictDeps = true;

            preBuild = ''
              dune build hello.opam
            '';

            postBuild = ''
              echo "building docs"
              dune build @doc -p hello
            '';

            postInstall = ''
              echo "Installing $doc/share/doc/hello/html"
              mkdir -p $doc/share/doc/hello/html
              cp -r _build/default/_doc/_html/* $doc/share/doc/hello/html
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
              # - have workspace-specific dune configuration files
              # - be able to set dune flags in `buildDunePackage`
              # - alter `buildDunePackage` so that it uses `--display=short`
              # - alter `buildDunePackage` so that it allows `--config-file=FILE` to be set
              patchDuneCommand =
                let
                  subcmds = [ "build" "test" "runtest" "install" ];
                  from = lib.lists.map (subcmd: "dune ${subcmd}") subcmds;
                  to = lib.lists.map (subcmd: "dune ${subcmd} --display=short") subcmds;
                in
                lib.replaceStrings from to;
            in

            self.packages.${system}.hello.overrideAttrs (oldAttrs: {
              name = "check-${oldAttrs.name}";
              nativeBuildInputs =
                oldAttrs.nativeBuildInputs ++ [
                  legacyPackages.ocamlformat
                ];

              doCheck = true;
              buildPhase = patchDuneCommand oldAttrs.buildPhase;
              postBuild = patchDuneCommand oldAttrs.postBuild;
              checkPhase = patchDuneCommand oldAttrs.checkPhase;
              installPhase = "touch $out $doc";
              dontFixup = true;
            });

          # Check Dune and OCaml formatting
          dune-fmt = legacyPackages.runCommand "check-dune-fmt"
            {
              nativeBuildInputs = [
                ocamlPackages.ocaml
                ocamlPackages.dune_2
                legacyPackages.ocamlformat
              ];
            }
            ''
              echo "checking formatting"
              dune build \
                --display=short \
                --root="${ocaml-src}" \
                --build-dir="$(pwd)/_build" \
                --no-print-directory \
                @fmt
              touch $out
            '';

          # Check Nix formatting
          nixpkgs-fmt = legacyPackages.runCommand "check-nixpkgs-fmt"
            { nativeBuildInputs = [ legacyPackages.nixpkgs-fmt ]; }
            ''
              echo "checking formatting"
              nixpkgs-fmt --check ${nix-src}
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
