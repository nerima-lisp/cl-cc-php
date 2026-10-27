# Architecture

## Position in the dependency graph

cl-cc-php is the PHP frontend for the `cl-cc` compiler.

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

The flake also pins `cl-cc-runtime` and adds its source tree to the ASDF source
registry used by tests because the compiler systems depend on it.
`cl-cc-runtime` is not a direct dependency in `cl-cc-php.asd`. `flake.lock`
records the source revisions used with cl-cc-php. The umbrella `cl-cc`
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

`nix/feature-dependencies.sexp` declares dependencies between feature
packages, and the `feature-lint` check validates those edges. The syntax
package owns generic parser callback registries and does not depend on
language-feature packages. Feature source files load after the syntax registry
and register their callbacks as they load.

`src/backend/` contains the `cl-cc/php/backend` package for compiler
integration. It registers a PHP bridge provider, parser, and input validator
through functions owned by `cl-cc/bootstrap`. The bootstrap package owns the
registration protocol; PHP supplies the callbacks.

Builtin implementations live in `src/stdlib/`, with filenames grouped by
family, such as `runtime-builtins-array-*.lisp`. The registration data is in
`src/stdlib/runtime-builtins-register-names.lisp` and
`src/stdlib/runtime-builtins-register-names-late.lisp`. See [Adding a runtime
builtin](../project/development.md#adding-a-runtime-builtin) for which table to
use.

Load order is significant: ASDF's `:serial t` loads components in the order
listed in the `.asd`. The syntax registry must load before feature packages
register callbacks, and `runtime-builtins-register` loads after its helpers.

## Test layout

Tests are grouped under `t/<feature>/` with package roots matching the source
feature packages. See [Test layout in Development](../project/development.md#test-layout)
for the shared test runner, parser fixtures, and test coverage.

## Build and CI

`flake.nix` declares only `x86_64-linux`, which CI verifies on each push and
pull request.

See [Running the full check](../project/development.md#running-the-full-check)
for the CI checks and commands to run all checks or one check.

