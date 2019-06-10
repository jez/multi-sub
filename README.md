# multi-sub

[![Build multi-sub Status](https://travis-ci.org/jez/multi-sub.svg?branch=master)](https://travis-ci.org/jez/multi-sub)

> Substitute a pattern with a replacement on specific lines

By default, `sed`'s `s/.../.../` command tries to perform a substitution on
**all** lines in a file. Sometimes that is too coarse grained. By contrast,
`multi-sub` limits the substitution to only happen on specified lines.

`multi-sub` takes input that looks like

```
filename.txt:17
filename.txt:42
another.md:12
another.md:23
```

and substitutes some pattern with some replacement only on the lines specified
in the input. The replacement is always done in place. In this way, `multi-sub`
is a Unix-style pipeline [sink].

If `sed` is like a chainsaw, `multi-sub` is more like a scalpel. Using a
combination of tools like `git grep -l` and `awk` with `multi-sub`, we can
construct precise filters. Specifically, two other tools are particularly useful
in conjunection with `multi-sub`:

- [diff-locs] is a tool that converts a unified diff into input suitable for
  `multi-sub`.

- [multi-grep] is like `multi-sub`, but with `grep`.

`multi-sub` is fast. It's implemented in OCaml, compiled with OCaml's
impressive optimizing compiler, and has been repeatedly profiled to improve
performance. It only does work that's absolutely needed.

[diff-locs]: https://github.com/jez/diff-locs
[multi-grep]: https://github.com/jez/multi-grep


## Usage

This is the help for `multi-sub` version `0.0.0`. It might be out of date—run
`multi-sub --help` locally for up-to-date help.

```
❯ multi-sub --help
Usage:
  multi-sub [options] <pattern> <replace> [<locs.txt>]

Substitutes the pattern with the replacement in the mentioned lines.

Arguments:
  <pattern>      A valid OCaml regular expression[1].
  <replace>      The expression to substitute when a match is found[2].
  <locs.txt>     The name of a file with lines formatted like:
                   filename.ext:20
                 If omitted, reads from stdin.

Options:
  -i, --ignore-case     Treat the pattern as case insensitive.
  -s, --case-sensitive  Treat the pattern as case sensitive [default].
  -g, --global          Replace all matches on a line, not just the first.
  --version             Print version and exit.

[1]: https://caml.inria.fr/pub/docs/manual-ocaml/libref/Str.html#VALregexp
[2]: https://caml.inria.fr/pub/docs/manual-ocaml/libref/Str.html#VALglobal_replace
```


## Install

There are pre-compiled binaries for macOS and Linux.
You can also install from source (see [Contributing](#contributing)).

### macOS

Using Homebrew:

- `brew install jez/formulae/multi-sub`

Or, download the binary directly from the releases:

- <https://github.com/jez/multi-sub/releases/download/latest>

### Linux

Download the binary from the releases page:

- <https://github.com/jez/multi-sub/releases/download/latest>


## Contributing

### One-time setup

1.  Make sure you have `opam` installed. OPAM manages both the OCaml compiler
    version and any OCaml packages' versions.

    [→ How to install opam](https://opam.ocaml.org/doc/Install.html)

    The next instructions assume you're using `opam` 2.0+ (`opam --version`).

1.  Create a switch for this project:

    ```bash
    ❯ git clone https://github.com/jez/multi-sub
    ❯ cd multi-sub
    ❯ opam switch create . ocaml-base-compiler.4.07.1
    ```

1.  Install `dune`:

    ```bash
    ❯ opam install dune
    ```

### Building

```bash
# To build for development:
❯ dune build

# To run:
❯ dune exec -- multi-sub

# To install from source:
❯ dune install --prefix="$HOME/.local"
```


## TODO

- Add test suite
  - Test that we write the end of the file out
  - Test that we preserve permissions
  - Document how to run and add tests
- Publish Homebrew formula
  - Document how to bump the version
- Set up ShellCheck
- Set up source code formatter
- Document how to set up editor tools



## License

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](https://jez.io/MIT-LICENSE.txt)

[sink]: https://homepage.cs.uri.edu/~thenry/resources/unix_art/ch11s06.html#id2958116
[Dune]: https://dune.build/
