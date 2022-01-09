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
        pkgs = nixpkgs.legacyPackages.${system};
        # OCaml packages available on nixpkgs
        ocamlPackages = pkgs.ocamlPackages;

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
        # Executed by `nix flake check`
        checks = {
          # Build dune package with checks enabled
          hello = ocamlPackages.buildDunePackage {
            pname = "hello";
            version = "0.1.0";
            src = ocaml-src;
            doCheck = true;
            useDune2 = true;
          };


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

          nativeBuildInputs = [
            ocamlPackages.odoc
          ];

          preBuild = "dune build hello.opam";
          postBuild = "dune build @doc";
          postInstall = ''
            mkdir -p $out/doc/hello/html
            cp -r _build/default/_doc/_html/* $out/doc/hello/html
          '';

          useDune2 = true;
        };

        # Executed by `nix build`
        defaultPackage = self.packages.${system}.hello;

        # Executed by `nix run .#<name>`
        apps.hello = {
          type = "app";
          program = "${self.packages.${system}.hello}/bin/hello";
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
            # FIXME: the `ocamllabs.ocaml-platform` VS Code extension does not
            # seem to find this library, complaining that:
            #
            # > OCamlformat_rpc is missing, displayed types might not be
            # > properly formatted.
            ocamlPackages.ocamlformat-rpc-lib
          ];
        };
      });
}
