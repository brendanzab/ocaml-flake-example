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

        # OCaml source files
        ocaml-src = nix-filter.lib.filter {
          root = ./.;
          include = [
            "dune-project"
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

            preBuild = "dune build hello.opam";
            postBuild = "dune build @doc -p hello";
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
          hello = self.packages.${system}.hello.overrideAttrs (oldAttrs: {
            doCheck = true;
          });

          # Check Nix formatting
          nixpkgs-fmt = legacyPackages.runCommand "check-nixpkgs-fmt"
            {
              nativeBuildInputs = [
                legacyPackages.nixpkgs-fmt
              ];
            }
            ''
              mkdir $out
              nixpkgs-fmt --check ${nix-src}
            '';
        };

        # Used by `nix develop`
        devShells = {
          default = legacyPackages.mkShell {
            # Development tools
            packages = [
              # Nix tools
              legacyPackages.nixpkgs-fmt
              # For `dune build --watch ...`
              legacyPackages.fswatch
              # Editor support
              ocamlPackages.ocaml-lsp
              ocamlPackages.ocamlformat-rpc-lib
              # Fancy REPL thing
              ocamlPackages.utop
            ];

            inputsFrom = [
              self.packages.${system}.hello
            ];
          };
        };
      });
}
