# Development

## Getting a shell

```sh
nix develop
```

This gives you SBCL with the dependency roots already exported as environment
variables, so `run-tests.lisp` finds cl-cc, cl-weave, cl-prolog, cl-parser-kit,
and cl-json-kit without further setup.

## Running the full check

```sh
nix flake check --print-build-logs
```

This is the same gate CI runs. It evaluates three checks in parallel:

| Check | What it gates |
|---|---|
| `checks.default` | The SBCL test suite, via `run-tests.lisp` |
| `checks.formatting` | treefmt/nixfmt over the Nix sources |
| `checks.docs` | `mkdocs build --strict`, so broken links fail |

Granularity lives in `checks.*` rather than in extra CI jobs, because
`nix flake check` already evaluates each attribute as its own derivation, in
parallel, with build caching.

## Running only the tests

```sh
nix run .#test
```

Or without Nix, from the repository root:

```sh
sbcl --script run-tests.lisp
```

That falls back to sibling checkouts (`../cl-cc`, `../cl-weave`, `../cl-prolog`,
`../cl-parser-kit`, `../cl-json-kit`). Override any root with
`CL_CC_PHP_CL_CC_ROOT`, `CL_CC_PHP_CL_WEAVE_ROOT`, `CL_CC_PHP_CL_PROLOG_ROOT`,
`CL_CC_PHP_CL_PARSER_KIT_ROOT`, or `CL_CC_PHP_CL_JSON_KIT_ROOT`.

## Coverage

```sh
nix build .#coverage
open result/cover-index.html   # or xdg-open on Linux
```

An `sb-cover` HTML report over `src/`'s own code — the dependency systems
(`cl-cc`, `cl-weave`, `cl-cc-pipeline`, `cl-json-kit`) and the test suite
itself are loaded uninstrumented, so the report answers "how much of cl-cc-php's implementation
do the tests reach", not "how much of the test suite runs". This is a
package, not a check: it exists to make the number visible and trending, not
to gate `nix flake check` on a percentage nobody has agreed to yet. Without
Nix: `sbcl --script coverage.lisp`, with the same environment variables as
`run-tests.lisp`; the report lands in `coverage-report/` by default, or
`$CL_CC_PHP_COVERAGE_OUT` if set.

## Iterating in a REPL

Running the whole suite for a one-line change is slow. Load the test system and
call it directly instead:

```lisp
(asdf:load-system "cl-cc-php/test")
(cl-cc-php/test:run-tests)
```

`run-tests` signals an error unless every test passes, rather than returning
`nil`, so it works as a script-level gate too.

## Formatting

```sh
nix fmt
```

treefmt is scoped to Nix only, running nixfmt. YAML is excluded because
formatters mangle the GitHub Actions `on:` key, and Markdown is excluded because
reformatting churns the whole docs tree.

## Building the documentation

```sh
nix build .#docs
```

The site builds with `--strict`, so a broken link or a page missing from the
`nav` in `docs/mkdocs.yml` fails the build. That is deliberate: it means the nav
cannot silently fall behind the pages.

mkdocs is invoked from the repository root, so the config path is always
`docs/mkdocs.yml` whether you build by hand or through Nix.

## Adding a runtime builtin

1. Implement the function in the matching `src/runtime-builtins-*.lisp` file,
   grouped with its family.
2. Add a row to the registration table that `%php-register-all-builtins` walks.
   Do not write a bespoke registration form — keeping registration as data is
   what stops the registry and the implementations from drifting apart.
3. Add a table-driven test row in `t/<same-name>-test.lisp`.
4. Update [API Reference](api-reference.md) if the symbol is exported.

## Test layout

Tests live in `t/` and run on cl-weave with no adapter layer. Two support files,
`helpers-parser` and `helpers-e2e`, carry the shared helpers.

Every other file is named `<source>-test.lisp` after the `src/` file it covers,
or `<source>-<aspect>-test.lisp` when one source has several aspects.

Most suites are table-driven: a test is a row of input and expected output. The
`*-e2e-test` suites go further and compile and run PHP source through the full
pipeline, which is why the test system depends on `cl-cc-pipeline` while the
shipped system does not.

## Versioning

`cl-cc-php.asd`'s `:version` is the single source of truth. `flake.nix` reads it
at evaluation time, so no Nix-side number can drift from it. A release edits the
`.asd` and nothing else.

Pushing a `v*.*.*` tag triggers `release.yml`, which refuses to publish unless
the tag matches the `.asd` version and the tagged tree passes `nix flake check`.
It then creates an empty *draft* release. The
[GitHub Release description](https://github.com/nerima-lisp/cl-cc-php/releases)
is the org's only canonical changelog, so the maintainer writes the notes into
the draft and publishes it:

```sh
gh release edit vX.Y.Z --notes-file notes.md --draft=false
```

## Contributing

Contribution, conduct, security, and support policies are maintained once for
the whole organisation in
[nerima-lisp/.github](https://github.com/nerima-lisp/.github).
