# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
Heading format is fixed across the org:

    ## [X.Y.Z] - YYYY-MM-DD

The version is bracketed, the separator is an ASCII hyphen (not an em dash),
and the date is ISO 8601. release.yml extracts the section matching the pushed
tag as the GitHub Release body, so a heading that deviates makes the release
fail. Keep `## [Unreleased]` at the top at all times.

Use only these subsection names, and omit the ones that are empty:
Added / Changed / Deprecated / Removed / Fixed / Security
-->

## [Unreleased]

### Changed

- `src/package.lisp` no longer `:use`s the sibling compiler packages. The 155
  names `src/` actually reads from `cl-cc/ast`, `cl-cc/bootstrap`, and
  `cl-cc/parse` are taken in with `:import-from`, and the `:use` list names
  only `#:cl`, both in `#:` designator form. No symbol identity changed.
- Five source files over the 500-line limit were split by concern:
  `runtime-builtins-array` into callable/compare/reshape/cursor pieces,
  `php84-features` into `parser-call-args`, `parser-property-hooks`, and
  `runtime-fibers`, `runtime-builtins-io` into `-io-ini`, `-io-locale`, and
  `-io-autoload`, `runtime-builtins-io-files` into `-io-streams`, and
  `runtime-builtins-register` into its machinery plus two name-table files.
  `:components` order is unchanged for every pre-existing entry, so the
  `:serial t` load order is the same.
- `class_implements`/`class_parents`/`class_uses` and the SPL autoload registry
  now load after `runtime-builtins-io-objects`, removing a forward reference to
  the `%php-reflection-*` helpers they wrap.
- No source line exceeds 100 columns. Twelve unbreakable message strings became
  `(concatenate 'string ...)` of two literals; the messages themselves are
  unchanged.
- Every file in `t/` is named after the `src/` file it covers
  (`<source>-test.lisp`, or `<source>-<aspect>-test.lisp`), and the two shared
  fixtures are `helpers-parser.lisp` and `helpers-e2e.lisp`.

### Fixed

- Stale `packages/php/src/...` paths in seventeen source-file header comments,
  left over from the extraction out of the cl-cc monorepo.

### Known issues

- `t/runtime-builtins-math-test.lisp` (formerly `t/php-math-tests.lisp`) is not
  listed in `cl-cc-php.asd`, so its assertions are neither compiled nor run.
  Wiring it in changes what the suite asserts and is left for its own change.

## [0.1.0] - 2026-07-26

This section was reconstructed from the commit history: the repository had no
CHANGELOG before the move to the org packaging standard, and v0.1.0 has not
been tagged yet, so everything since the extraction from the cl-cc monorepo is
collected here rather than split across releases.

### Added

- Initial extraction of the PHP frontend from the cl-cc monorepo: lexer,
  parser, grammar, and the PHP runtime builtins (`array_*`, `str*`, math,
  regex/`preg_*`, type predicates, I/O, and the dispatch registry).
- `flake.nix` providing a hermetic Nix build and test environment, closing the
  gap the README's own Status section had flagged.
- Property-based tests written against cl-weave's generator API directly.
- Test coverage for `runtime-builtins-types`, `runtime-builtins-string-core`
  (previously 28.4%), `grammar` CST parsing (previously 33.0%), and the array,
  `preg_*`, I/O, I/O-objects, I/O-image, string-transform, and math builtins.
- End-to-end coverage for asymmetric visibility and intersection types.
- Org packaging standard adoption: `.github/workflows/` (`ci`, `docs`,
  `release`, `flake-update`), the shared `nix-setup` composite action, a
  MkDocs site under `docs/`, and this changelog.

### Changed

- Test suite now runs on cl-weave directly, with no `cl-cc/test` adapter layer.
- The `cl-cc-php/tests` ASDF system is now `cl-cc-php/test`, and the test
  sources moved from `tests/` to `t/`, per the org standard.
- `run-tests.lisp` moved from `scripts/` to the repository root.
- `ctype_*` and other repeated builtin shapes consolidated into macros.
- `%php-register-all-builtins`'s 440 registrations extracted into a data table.
- `%php-rewrite-ref-vars`'s 19 field-copy clauses consolidated into a table.
- The CST binary-operator precedence chain consolidated into a macro.
- Class-member slot allocation logic and the NoDiscard function/method warning
  message builders deduplicated.
- End-to-end compile-and-check-output tests converted to a table-driven form.
- The three largest source files split by section.
- `src` re-synced with upstream cl-cc.

### Removed

- Dead bridge-provider adapter.
- Seven redundant PHP Fiber method-dispatch wrappers.

### Fixed

- `fclose()` never actually closed the stream returned by `fopen()`.
- `is_dir()` returned an incorrect result on this platform.
