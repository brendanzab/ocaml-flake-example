# OCaml flake example project

![ci workflow](https://github.com/brendanzab/ocaml-flake-example/actions/workflows/ci/badge.svg)

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
[vscode-direnv]: https://github.com/cab404/vscode-direnv

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

### Building the documentation

Documentation can be built using the `nix` command with:

```sh
nix build .#hello-doc
open result/share/doc/hello/index.html
```

### Running the tests

The tests can be run using the `nix` command with:

```sh
nix flake test --print-build-logs
```

This will also check that `flake.nix` conforms to the expected [flake schema],
and will run formatting tests for the Nix files.

The test output can be promoted with:

```sh
dune promote
```

[flake schema]: https://nixos.wiki/wiki/Flakes#Flake_schema
