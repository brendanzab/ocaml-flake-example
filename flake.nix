{
  description = "A flake demonstrating how to build OCaml projects with Dune";

  # Flake dependency specification
  #
  # To update all flake inputs:
  #
  #     $ nix flake update --commit-lock-file
  #
  # To update individual flake inputs:
  #
  #     $ nix flake lock --update-input <input> ... --commit-lock-file
  #
  inputs = {
    # Externally extensible flake systems. See <https://github.com/nix-systems/nix-systems>.
    systems.url = "github:nix-systems/default";
  };

  outputs = { self, nixpkgs, systems }:
    let
      # Nixpkgs library functions.
      lib = nixpkgs.lib;
      # Iterate over each system, configured via the `systems` input.
      eachSystem = lib.genAttrs (import systems);
    in
    {
      # Exposed packages that can be built or run with `nix build` or
      # `nix run` respectively:
      #
      #     $ nix build .#<name>
      #     $ nix run .#<name> -- <args?>
      #
      packages = eachSystem (system:
        let
          legacyPackages = nixpkgs.legacyPackages.${system};
          ocamlPackages = legacyPackages.ocamlPackages;
        in
        {
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
            src = ./.;

            buildInputs = [
              # OCaml package dependencies go here.
            ];

            strictDeps = true;
          };
        });

      # Flake checks
      #
      #     $ nix flake check
      #
      checks = eachSystem (system:
        let
          legacyPackages = nixpkgs.legacyPackages.${system};
          ocamlPackages = legacyPackages.ocamlPackages;
        in
        {
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
                # installPhase = patchDuneCommand oldAttrs.checkPhase;
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
                --root="${./.}" \
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
                --root="${./.}" \
                --build-dir="$(pwd)/_build" \
                @doc
              touch $out
            '';

          # Check Nix formatting
          nixpkgs-fmt = legacyPackages.runCommand "check-nixpkgs-fmt"
            { nativeBuildInputs = [ legacyPackages.nixpkgs-fmt ]; }
            ''
              echo "checking nix formatting"
              nixpkgs-fmt --check ${./.}
              touch $out
            '';
        });

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
      devShells = eachSystem (system:
        let
          legacyPackages = nixpkgs.legacyPackages.${system};
          ocamlPackages = legacyPackages.ocamlPackages;
        in
        {
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
              # Fancy REPL thing
              ocamlPackages.utop
            ];

            # Tools from packages
            inputsFrom = [
              self.packages.${system}.hello
            ];
          };
        });
    };
}
