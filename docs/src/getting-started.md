# Getting Started

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
[Architecture](reference/architecture.md).

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

## Verifying the install

```sh
nix flake check --print-build-logs
```

This builds the source, runs the test suite, checks Nix formatting, and builds
this documentation site with `--strict`.

## Parse PHP into an AST

The rest of this page carries one task through to completion: turning a PHP
source string into a cl-cc AST, and seeing what the lexer did along the way.

```lisp
(asdf:load-system "cl-cc-php")

(cl-cc/php:parse-php-source "<?php $x = 1 + 2;")
```

`parse-php-source` takes a source string and returns a list of top-level AST
nodes, the same shape `parse-all-forms` returns for Common Lisp. Those nodes are
cl-cc AST nodes, so the rest of the compiler can consume them directly.

## Look at the tokens

When a parse does something surprising, check the token stream first. It tells
you whether the lexer or the parser is at fault:

```lisp
(cl-cc/php:tokenize-php-source "<?php $x = 1 <=> 2;")
```

Tokens are plists of the form `(:type :T-XXX :value val)`, and the list always
ends with `(:type :T-EOF :value nil)`.

## Keep the surface syntax

The AST discards detail that a formatter or linter needs. Parse to a concrete
syntax tree instead when that detail matters:

```lisp
(cl-cc/php:parse-php-source-to-cst "<?php if ($a) { b(); }")
;; => (values cst-list diagnostics)
```

Note that this returns two values: the CST nodes and any diagnostics collected
during the parse.

## Reject unsupported constructs early

`php-check-supported-forms` walks an AST and signals an error on any construct
the frontend does not handle, rather than letting it fail deeper in the
pipeline:

```lisp
(let ((ast (cl-cc/php:parse-php-source source)))
  (cl-cc/php:php-check-supported-forms ast)
  ast)
```

## Next steps

- [Core Concepts](guide/core-concepts.md) explains the lexer/parser/grammar split
  and why the `%php-` runtime builtins exist.
- [Recipes](guide/recipes.md) covers PHP value semantics, arrays, enums, and
  adding a builtin.
- [API Reference](reference/api.md) specifies the entry points.
