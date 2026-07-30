# Installation

## Requirements

- SBCL. This is the only supported implementation; the runtime builtins use
  `sb-*` facilities directly in the I/O and filesystem layers.
- Nix, if you want the reproducible path.
- A checkout of [cl-cc](https://github.com/nerima-lisp/cl-cc), which supplies
  `cl-cc-ast`, `cl-cc-bootstrap`, `cl-cc-parse`, and `cl-cc-vm`.
- A checkout of [cl-json-kit](https://github.com/nerima-lisp/cl-json-kit),
  which `json_validate` calls directly.

cl-cc-php cannot load without cl-cc on the ASDF source registry. That is a
property of the system rather than a packaging oversight — see
[Architecture](architecture.md).

## As a flake input

Add the input and let it follow your nixpkgs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cl-cc-php = {
      url = "github:nerima-lisp/cl-cc-php";
      flake = false;
    };
  };
}
```

!!! warning "No release tag yet"
    cl-cc-php has not been tagged. Sibling packages in this org are normally
    pinned as `github:nerima-lisp/<pkg>/vX.Y.Z`, and you should switch to that
    form as soon as a tag exists. Until then your `flake.lock` is the only thing
    holding the revision steady, so commit it.

Then put the source tree on the ASDF source registry of whatever derivation
consumes it, alongside a cl-cc checkout.

## As an ASDF dependency

In your `.asd`:

```lisp
:depends-on ("cl-cc-php")   ; PHP frontend: lexer, parser, grammar, runtime builtins
```

Loading it requires cl-cc's `packages/` subsystems to be visible to ASDF. The
simplest arrangement is sibling checkouts:

```text
parent/
  cl-cc/
  cl-cc-php/
  cl-weave/
  cl-prolog/
  cl-parser-kit/
  cl-json-kit/
```

With that layout, `run-tests.lisp` finds everything with no configuration.

## Verifying the install

```sh
nix flake check --print-build-logs
```

This builds the source, runs the test suite, checks Nix formatting, and builds
this documentation site with `--strict`.

## Dependencies

The main system depends on four cl-cc subsystems, plus one standalone package:

| Dependency | Why |
|---|---|
| `cl-cc-ast` | AST node definitions the parser emits |
| `cl-cc-bootstrap` | Compiler self-hosting core |
| `cl-cc-parse` | Shared parsing infrastructure |
| `cl-cc-vm` | Bytecode VM |
| [`cl-json-kit`](https://github.com/nerima-lisp/cl-json-kit) | RFC 8259 JSON reader backing `json_validate` |

The test system additionally depends on `cl-cc-pipeline`, for the end-to-end
suites that compile and run PHP source, and on
[cl-weave](https://github.com/nerima-lisp/cl-weave) as the test framework.
Neither is a dependency of the shipped system.
