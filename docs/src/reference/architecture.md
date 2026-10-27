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

The diagram shows direct ASDF dependencies. `cl-host-kit` and `cl-json-kit`
provide host operations and JSON parsing; the separate `cl-cc-php/test` system
adds `cl-weave`.

`cl-cc-ast`, `cl-cc-bootstrap`, `cl-cc-parse`, `cl-cc-runtime`, and `cl-cc-vm`
come from separate sibling repositories. `flake.nix` pins each source directly,
and `flake.lock` records the revisions used with cl-cc-php. The umbrella cl-cc
repository is not an input to this flake.

## Source layout

`src/` is divided into language-feature packages. `src/package.lisp` is the
public `cl-cc/php` facade; implementations live in `src/<feature>/` and use
`cl-cc/php/<feature>` as their home package.

| Feature directory | Contents |
|---|---|
| `src/syntax/` | Lexer, token stream, shared grammar registries, and unsupported-form diagnostics |
| `src/expressions/` | Expression parsing and operators |
| `src/statements/` | Statement parsing and lowering |
| `src/functions/` | Calls, closures, and named-argument handling |
| `src/classes/` | Classes, traits, interfaces, enums, and property hooks |
| `src/generators/` | Yield parsing and generator runtime |
| `src/fibers/` | Fiber runtime |
| `src/arrays/` | Array expression parsing and runtime representation |
| `src/strings/` | Interpolation and string runtime helpers |
| `src/match/` | Match expressions |
| `src/attributes/` | Attribute parsing and metadata |
| `src/types/` | PHP type parsing and runtime type helpers |
| `src/errors/` | PHP exception and fatal-error helpers |
| `src/stdlib/` | PHP builtins, constants, JSON, URI, and DOM support |
| `src/backend/` | VM bridge provider and backend registration |

Feature dependencies are declared in `nix/feature-dependencies.sexp`. The
syntax package owns the generic grammar registration points and does not
depend on language-feature packages. Feature source files load after the syntax
registry and register their grammar callbacks as they load.

The PHP backend uses one `cl-cc/php/backend` package with no separate
infrastructure package. Its PHP-specific adapter registers compiler bridge
callbacks; the shared registration protocol remains owned by `cl-cc/bootstrap`.

Builtin files load in these families: core; array core, callable, comparison,
reshape, cursor, and sort; string data, core, formatting, multibyte, encoding,
transform, analysis, ctype, extra, serialization, JSON, and digest; regex core,
preg, date, number, callback, and array; math; types; and I/O data, core, ini,
locale, scanning, files, streams, objects, autoload, SPL, reflection, compat,
image, output, cookie/session, tokenizer, and URI. They live in `src/stdlib/`.
`runtime-builtins-register` loads last because it references all of them. The
name-to-symbol entries it walks are data split between
`runtime-builtins-register-names.lisp` and
`runtime-builtins-register-names-late.lisp`.

Load order is significant: the `.asd` uses `:serial t`.

## Test layout

Tests are grouped under `t/<feature>/` with package roots matching the source
feature packages. `t/package.lisp` owns the shared test runner, and
`t/syntax/parser-fixtures.lisp` provides parser fixtures used by feature suites.

The PHP test system covers tokenization, parsing, CST generation, and runtime
behavior. Tests that compile and execute PHP through the compiler and VM remain
in umbrella-level integration. See [Running only the tests](../project/development.md#running-only-the-tests)
for the test command and [Running the full check](../project/development.md#running-the-full-check)
for the CI checks.

## Build and CI

`flake.nix` declares only `x86_64-linux`, which CI verifies on each push and
pull request.

Granularity lives in `checks.*`, not in extra CI jobs:

| Check | What it gates |
|---|---|
| `checks.default` | The SBCL test suite via `run-tests.lisp` |
| `checks.orphan-tests` | Every Lisp file under `t/` is loaded by the test system |
| `checks.feature-lint` | Feature ownership, dependency graph, glossary, and facade surface |
| `checks.formatting` | treefmt/nixfmt over the Nix sources |
| `checks.docs` | `mkdocs build --strict`, so broken links fail the PR |

During Nix evaluation, `flake.nix` reads the `:version` form from
`cl-cc-php.asd`, so the `.asd` is the single source of truth and no Nix-side
number can drift from it.
