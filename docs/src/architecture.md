# Architecture

## Position in the dependency graph

cl-cc-php is a domain-layer package: it depends on the compiler core and is
depended upon by nothing else in the org.

```
cl-cc-php
  ├── cl-cc-ast        (AST node definitions)
  ├── cl-cc-bootstrap  (compiler self-hosting core)
  ├── cl-cc-parse      (shared parsing infrastructure)
  └── cl-cc-vm         (bytecode VM)

cl-cc-php/test  (additionally)
  ├── cl-cc-pipeline   (full compile-and-run, for the e2e suites)
  └── cl-weave         (test framework)
```

The split between the two is deliberate. The end-to-end suites need to compile
*and run* PHP source through `cl-cc/compile:compile-string` and
`cl-cc/vm:run-compiled`, which pulls in codegen, optimize, regalloc, and emit.
Folding `cl-cc-pipeline` into the main system would make every consumer of the
PHP frontend drag along the entire backend for no reason.

## Why dependencies come from a cl-cc checkout

`cl-cc-ast`, `cl-cc-bootstrap`, `cl-cc-parse`, and `cl-cc-vm` are not separate
flakes here. They are read out of `packages/<name>/` inside a checkout of the
cl-cc monorepo, registered by `run-tests.lisp` as ASDF source trees.

This is a consequence of the ongoing repository split, not a design preference.
Bootstrap, VM, and parse are the compiler's self-referential core and are an
explicit non-goal for further splitting, so there is no independent repository
to depend on. `flake.nix` therefore takes cl-cc as a `flake = false` source
input.

!!! warning "Known issue: duplicated systems in cl-cc"
    `cl-cc/packages/` currently defines some systems twice under the same name
    with differing contents. Which definition wins depends on ASDF source
    registry ordering. This is a known design problem in cl-cc and is out of
    scope for this repository. `run-tests.lisp` pins an explicit, ordered list
    of `packages/` subdirectories partly to make that ordering deterministic.

## Source layout

`src/` is flat and grouped by prefix.

| Prefix | Contents |
|---|---|
| `package` | Package definition and exports |
| `lexer`, `lexer-ops` | Tokeniser and table-driven operator dispatch |
| `runtime-helpers-*` | Shared helpers for the runtime layer |
| `runtime-constants` | `+php-null+` and friends |
| `runtime-builtins-*` | The builtin families (see below) |
| `parser`, `parser-support` | Parser core |
| `parser-expr-*` | Expression parsing, by construct |
| `parser-stmt-*` | Statement and declaration parsing |
| `parser-class`, `parser-trait`, `parser-interface` | Type declarations |
| `parser-attributes`, `parser-attribute-passes` | PHP 8 attributes |
| `php84-features` | PHP 8.4-specific forms |
| `unsupported` | Detection and reporting of unhandled constructs |
| `grammar`, `grammar-stmt` | CST grammar |

Builtin families, in load order, are: core, array, array sorting, string (data,
core, format, multibyte, encoding, transform, analysis, ctype, extra,
serialization, JSON, digest), regex (`preg_*`, date, number, callback, array),
math, types, and I/O (data, scan, files, objects, SPL, reflection, compat,
image, output, cookie/session, tokenizer, URI). `runtime-builtins-register`
loads last because it references all of them.

Load order is significant: the `.asd` uses `:serial t`.

## Test layout

`t/` mirrors the source grouping. Two support files carry shared helpers, the
rest are per-area suites. The `php-compile-*-e2e-tests` files are the ones that
require the full pipeline.

## Build and CI

`flake.nix` declares `x86_64-linux` and `aarch64-darwin`. CI verifies the
former; maintainers verify the latter on their development machines. No other
platform is declared, because no one verifies any other platform.

Granularity lives in `checks.*`, not in extra CI jobs:

| Check | What it gates |
|---|---|
| `checks.default` | The SBCL test suite via `run-tests.lisp` |
| `checks.formatting` | treefmt/nixfmt over the Nix sources |
| `checks.docs` | `mkdocs build --strict`, so broken links fail the PR |

The package version is read out of `cl-cc-php.asd` at evaluation time, so the
`.asd` is the single source of truth and no Nix-side number can drift from it.
