# cl-cc-php

The PHP frontend for the [cl-cc](https://github.com/nerima-lisp/cl-cc) Common
Lisp compiler.

cl-cc-php turns PHP source into cl-cc's AST and supplies the PHP runtime
builtins that compiled code calls into. It is a *plugin repository*: it defines
the `cl-cc-php` ASDF system, and depends on compiler core systems provided by
separately pinned sibling repositories.

## What is in here

| Layer | What it does |
|---|---|
| Lexer | PHP source text to a token stream |
| Parser | Tokens to cl-cc AST, or to a concrete syntax tree |
| Grammar | Statement and expression grammar, including PHP 8.4 and 8.5 forms |
| Runtime builtins | `array_*`, `str*`, math, `preg_*`, type predicates, I/O, and the dispatch registry |

## Where to go next

If you want to get something running, start with
[Getting Started](getting-started.md), which covers installation and carries one
parse through end to end.

If you want to understand the design before using it,
[Core Concepts](guide/core-concepts.md) explains the three-stage pipeline and the
distinction between parse-time code and the runtime builtins — the point that
most often trips up first readers.

If you are looking up a specific symbol, go to
[API Reference](reference/api.md).

If you are extending the frontend, [Architecture](reference/architecture.md) covers the
source layout and the dependency shape, and [Development](project/development.md)
covers the build, test, and formatting commands.

## Before you depend on this

Two constraints are worth knowing up front.

**It has compiler dependencies.** cl-cc-php consumes `cl-cc-ast`,
`cl-cc-bootstrap`, `cl-cc-parse`, and `cl-cc-vm` from separately pinned sibling
repositories. `flake.lock` records the revisions tested together with
cl-cc-php.

**The `%php-` symbols are a compilation target.** They are exported so that
generated code can name them, not because they form a comfortable user-facing
API. The stable surface is the four entry points documented in
[API Reference](reference/api.md).

See [Compatibility](reference/compatibility.md) for the full picture, including platform
support and PHP language coverage.

## Project policies

Contribution guidelines, code of conduct, security policy, and support channels
are maintained once for the whole organisation in
[nerima-lisp/.github](https://github.com/nerima-lisp/.github).

Released under the MIT license.
