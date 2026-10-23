# Architecture

## Position in the dependency graph

cl-cc-php is the PHP frontend for the compiler.

```
cl-cc-php
  ├── cl-cc-ast        (AST node definitions)
  ├── cl-cc-bootstrap  (compiler self-hosting core)
  ├── cl-cc-parse      (shared parsing infrastructure)
  ├── cl-cc-vm         (bytecode VM)
  ├── cl-host-kit      (host operations)
  └── cl-json-kit      (JSON reader)

cl-cc-php/test
  ├── cl-cc-php        (system under test)
  └── cl-weave         (test framework)
```

## Compiler subsystem inputs

`cl-cc-ast`, `cl-cc-bootstrap`, `cl-cc-parse`, and `cl-cc-vm` come from
separate sibling repositories. `flake.nix` pins each source directly, and
`flake.lock` records the revisions used with cl-cc-php. The umbrella cl-cc
repository is not an input to this flake.

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
| `parser-call-args` | Named arguments and first-class callables |
| `parser-property-hooks` | Property hooks, asymmetric visibility, readonly |
| `runtime-fibers` | PHP 8.1 Fibers |
| `unsupported` | Detection and reporting of unhandled constructs |
| `grammar`, `grammar-stmt` | CST grammar |

Builtin families, in load order, are: core, array, array sorting, string (data,
core, format, multibyte, encoding, transform, analysis, ctype, extra,
serialization, JSON, digest), regex (`preg_*`, date, number, callback, array),
math, types, and I/O (data, scan, files, objects, SPL, reflection, compat,
image, output, cookie/session, tokenizer, URI). `runtime-builtins-register`
loads last because it references all of them; the ~700 name-to-symbol entries
it walks are data and live in `runtime-builtins-register-names*`.

Load order is significant: the `.asd` uses `:serial t`.

## Test layout

Every suite is named `<source>-test.lisp` after the `src/` file it covers, or
`<source>-<aspect>-test.lisp` where one source has several aspects worth
separating. Shared fixtures are `helpers-*.lisp` and are not suites.

PHP tests use the frontend's APIs to inspect tokens, ASTs, CSTs, and runtime
behavior. See the development guide for the test system's scope.

## Build and CI

`flake.nix` declares only `x86_64-linux`, which CI verifies on each push and
pull request.

Granularity lives in `checks.*`, not in extra CI jobs:

| Check | What it gates |
|---|---|
| `checks.default` | The SBCL test suite via `run-tests.lisp` |
| `checks.formatting` | treefmt/nixfmt over the Nix sources |
| `checks.docs` | `mkdocs build --strict`, so broken links fail the PR |

The package version is read out of `cl-cc-php.asd` at evaluation time, so the
`.asd` is the single source of truth and no Nix-side number can drift from it.
