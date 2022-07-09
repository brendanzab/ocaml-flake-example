# OCaml flake example project

[![built with nix][nix-badge]][nix-url]
[![ci workflow][ci-badge]][ci-url]
[![docs][docs-badge]][docs-url]

[nix-badge]: https://img.shields.io/static/v1?logo=nixos&logoColor=white&label=&message=Built%20with%20Nix&color=41439a
[nix-url]: https://builtwithnix.org
[ci-badge]: https://github.com/brendanzab/ocaml-flake-example/actions/workflows/ci.yml/badge.svg
[ci-url]: https://github.com/brendanzab/ocaml-flake-example/actions/workflows/ci.yml
[docs-badge]: https://img.shields.io/badge/docs-odoc-blue
[docs-url]: https://brendanzab.github.io/ocaml-flake-example

This is an overly elaborate example of building a ‘Hello World’ package with
[Nix flakes], [OCaml], and [Dune]. The following things are demonstrated:

- A library and an executable that depends on that library
- Building documentation
- Expect tests and Cram tests

[Nix flakes]: https://nixos.wiki/wiki/Flakes
[OCaml]: https://ocaml.org/
[Dune]: https://dune.build/

## Disclaimer

I'm not a Nix expert, nor am I an OCaml expert so there might be better
approaches to some of the things demonstrated here! That said, I thought I'd
share this in the off-chance it is useful to somebody else.

## Preliminaries

### Entering the Nix development shell

Sometimes it can be useful to run commands such as `dune` directly from your
shell. To do this you can call `nix develop` in your shell, which will load a
new `bash` shell with the appropriate tools in your `$PATH`:

```sh
nix develop
```

### Enabling Direnv

Alternatively you can use [`direnv`] or [`nix-direnv`] to load the development
tools automatically in the current shell. Direnv can also be extremely useful
for setting up your editor, for example with [vscode-direnv].

You can enable `direnv` to load the development tools onto your `$PATH` by
running:

```sh
echo "use flake" > .envrc
direnv allow
```

If you decide to use `direnv` you'll probably want to add `.direnv` and `.envrc`
to your global [gitignore] or local [excludes] in order to avoid committing
these files to git.

[`direnv`]: https://direnv.net/
[`nix-direnv`]: https://github.com/nix-community/nix-direnv/
[gitignore]: https://git-scm.com/docs/gitignore
[excludes]: https://git-scm.com/docs/gitignore#_configuration
[vscode-direnv]: https://github.com/direnv/direnv-vscode

## Flake Usage

### Running the executable

The `hello` executable can be run with the `nix` command with:

```sh
nix run
```

This should print `Hello, World!` in your shell.

### Building the package

The `hello` package can be built with the `nix` command with:

```sh
nix build
```

This should create a `result` symlink in the current directory, which will
contain the `hello` executable and library.

### Running the tests

The tests can be run using the `nix` command with:

```sh
nix flake check --print-build-logs
```

This will also check that `flake.nix` conforms to the expected [flake schema],
and will run formatting tests for the Nix files.

Expect test failures can be [promoted][dune-promotion] in a development shell with:

```sh
dune promote
```

This will update the tests to their current expected output.

[flake schema]: https://nixos.wiki/wiki/Flakes#Flake_schema
[dune-promotion]: https://dune.readthedocs.io/en/stable/concepts.html#promotion
