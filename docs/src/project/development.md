# Development

## Getting a development shell on Linux

```sh
nix develop
```

The flake provides this shell on `x86_64-linux`, the platform used by its
checks. It gives you SBCL with dependency roots already exported, so
`run-tests.lisp` finds the compiler systems, cl-weave, and runtime libraries
without further setup. To run tests without Nix, use the command under
[Running only the tests](#running-only-the-tests) and place sibling dependency
checkouts in the listed directories.

## Running the full check

```sh
nix flake check --print-build-logs
```

GitHub Actions runs this Nix check, then runs `git diff --check` in its
checkout. That command checks unstaged working-tree changes against the index;
it does not compare a pull request with its base. To check local uncommitted
changes, run `git diff --check` for unstaged changes and
`git diff --cached --check` for staged changes. The Nix check evaluates five
derivations in parallel:

| Check | What it gates |
|---|---|
| `checks.default` | The SBCL test suite, via `run-tests.lisp` |
| `checks.orphan-tests` | Every Lisp file under `t/` is registered by the test system |
| `checks.feature-lint` | Feature ownership, dependencies, glossary, and facade surface |
| `checks.formatting` | treefmt/nixfmt over the Nix sources |
| `checks.docs` | `mkdocs build --strict`, so broken links fail |

Granularity lives in `checks.*` rather than in extra CI jobs, because
`nix flake check` already evaluates each attribute as its own derivation, in
parallel, with build caching.

To build one check for `x86_64-linux`, qualify the table entry with the system
name. For example, `checks.feature-lint` maps to
`checks.x86_64-linux.feature-lint`:

```sh
nix build .#checks.x86_64-linux.feature-lint
```

## Running only the tests

On `x86_64-linux`, run the Nix app:

```sh
nix run .#test
```

Or without Nix, from the repository root:

```sh
sbcl --script run-tests.lisp
```

`run-tests.lisp` uses sibling checkouts at the paths below. For example,
`../cl-cc-vm` is a `cl-cc-vm` checkout beside this
repository. Set the corresponding environment variable to use a different
path.

| System | Default path | Environment variable |
|---|---|---|
| `cl-cc-bootstrap` | `../cl-cc-bootstrap` | `CL_CC_PHP_CL_CC_BOOTSTRAP_ROOT` |
| `cl-cc-ast` | `../cl-cc-ast` | `CL_CC_PHP_CL_CC_AST_ROOT` |
| `cl-cc-parse` | `../cl-cc-parse` | `CL_CC_PHP_CL_CC_PARSE_ROOT` |
| `cl-cc-runtime` | `../cl-cc-runtime` | `CL_CC_PHP_CL_CC_RUNTIME_ROOT` |
| `cl-cc-vm` | `../cl-cc-vm` | `CL_CC_PHP_CL_CC_VM_ROOT` |
| `cl-weave` | `../cl-weave` | `CL_CC_PHP_CL_WEAVE_ROOT` |
| `cl-parser-kit` | `../cl-parser-kit` | `CL_CC_PHP_CL_PARSER_KIT_ROOT` |
| `cl-regex-kit` | `../cl-regex-kit` | `CL_CC_PHP_CL_REGEX_KIT_ROOT` |
| `cl-tty-kit` | `../cl-tty-kit` | `CL_CC_PHP_CL_TTY_KIT_ROOT` |
| `cl-log-kit` | `../cl-log-kit` | `CL_CC_PHP_CL_LOG_KIT_ROOT` |
| `cl-process-kit` | `../cl-process-kit` | `CL_CC_PHP_CL_PROCESS_KIT_ROOT` |
| `cl-codec-kit` | `../cl-codec-kit` | `CL_CC_PHP_CL_CODEC_KIT_ROOT` |
| `cl-concurrent-kit` | `../cl-concurrent-kit` | `CL_CC_PHP_CL_CONCURRENT_KIT_ROOT` |
| `cl-boundary-kit` | `../cl-boundary-kit` | `CL_CC_PHP_CL_BOUNDARY_KIT_ROOT` |
| `cl-date-kit` | `../cl-date-kit` | `CL_CC_PHP_CL_DATE_KIT_ROOT` |
| `cl-json-kit` | `../cl-json-kit` | `CL_CC_PHP_CL_JSON_KIT_ROOT` |
| `cl-host-kit` | `../cl-host-kit` | `CL_CC_PHP_CL_HOST_KIT_ROOT` |

## Coverage

```sh
nix build .#coverage
open result/cover-index.html   # or xdg-open on Linux
```

An `sb-cover` HTML report over `src/`'s own code. The compiler systems,
cl-weave, runtime libraries, and test suite load uninstrumented, so the report
shows how much of cl-cc-php's implementation the tests reach. This package
makes coverage visible; it does not gate `nix flake check` on a percentage.
Without Nix, run `sbcl --script coverage.lisp` with the same environment
variables as `run-tests.lisp`. The report lands in `coverage-report/` by
default, or in `$CL_CC_PHP_COVERAGE_OUT` if set.

## Iterating in a REPL

ASDF's source registry must include the repository root and the dependency
roots listed above. Running `run-tests.lisp` from the repository root
initializes that registry and immediately executes the full test suite. The
REPL example assumes the registry is already initialized in the current
session:

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

1. Implement the function in the matching `src/stdlib/runtime-builtins-*.lisp`
   file, grouped with its family.
2. Add a name that is absent from both registration tables to
   `src/stdlib/runtime-builtins-register-names.lisp`, the first registration
   pass. Use `src/stdlib/runtime-builtins-register-names-late.lisp` when an
   intentional later entry must override a name registered in an earlier pass,
   or when registration must happen after `%php-seed-by-ref-param-registry`.
   The split is by order, not builtin family. The seeder is defined in
   `src/functions/runtime-functions.lisp`; it adds by-reference metadata for
   `settype` and `similar_text`. When adding another by-reference builtin,
   update that seeder and add or adjust a call-site lowering case in
   `t/types/parser-stmt-lower-test.lisp`.
   Do not write a bespoke registration form — keeping registration as data is
   what stops the registry and the implementations from drifting apart.
3. Add a table-driven test row to the existing suite for that builtin family
   under `t/stdlib/` (for example, array builtins are tested in
   `t/stdlib/runtime-builtins-array-test.lisp`).
4. Check the public exports in `src/package.lisp`. If the change exports a
   public symbol from the `cl-cc/php` facade, update the
   [API Reference](../reference/api.md).

## Test layout

Tests live in `t/` and run on cl-weave with no adapter layer. Shared parser
fixtures live in `t/syntax/parser-fixtures.lisp` and are loaded by feature
suites.

Every other file is named `<source>-test.lisp` after the `src/` file it covers,
or `<source>-<aspect>-test.lisp` when one source has several aspects.

Most suites are table-driven: a test is a row of input and expected output.
Tests that need to compile and execute PHP through the compiler and VM are
reserved for umbrella-level integration. The PHP test system exercises
tokenization, parsing, concrete syntax tree (CST) generation, and runtime
behavior.

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
