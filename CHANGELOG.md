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

- `t/runtime-builtins-io-objects-php85-test.lisp` grew back over the
  500-line limit (511 lines) as later work in this session's own
  history added more tests to it. Its six `Dom\Element`/
  `Dom\ParentNode`/`Dom\HTMLDocument` tests split out to a new
  `t/runtime-builtins-io-dom-php85-test.lisp` — the same size-driven,
  topic-scoped split already applied once before in this file's history
  to pull out `runtime-builtins-io-uri-php85-test.lisp`. A fresh sweep
  of every file's current line count (`wc -l src/*.lisp t/*.lisp`,
  since several files grew substantially across this session's edits)
  found this as the only file over the limit; no `src/` file is over
  500 lines (`runtime-builtins-core.lisp` sits exactly at it).
- Every `sbcl --script` invocation in `flake.nix` (`checks.default`,
  `packages.coverage`, and `apps.test`/`nix run .#test`) now runs under
  `timeout` (600s for the plain test suite and the interactive `nix run`
  entry point, 900s for coverage's slower force-recompile-then-run), so a
  hang — an infinite loop, a VM/fiber deadlock — fails the build loudly
  instead of running until CI's own outer timeout eventually kills it.
  These were the only unguarded command invocations in the repository: the
  GitHub Actions workflows already carry `timeout-minutes` on every job, and
  there is no other place this codebase shells out to a subprocess.
- `json_validate` (`%php-json-validate`) now delegates to
  [`cl-json-kit`](https://github.com/nerima-lisp/cl-json-kit)'s
  `json-kit:parse`, a dependency-free, RFC 8259-conformance-tested JSON
  reader (the full JSONTestSuite corpus: 95/95 must-accept, 188/188
  must-reject), instead of a hand-rolled strict parser added earlier in this
  same series of changes. That hand-rolled version already regression-tested
  clean, but a purpose-built, conformance-tested library is strictly more
  correct with less code to maintain — e.g. it correctly rejects a leading
  zero before more digits (`"01"`), a real RFC 8259 rule the hand-rolled
  digit-scanner missed. This is `cl-cc-php`'s first adoption of a
  nerima-lisp sibling package as a genuine runtime dependency (`cl-weave`,
  `cl-prolog`, and `cl-parser-kit` are test-only): it is now a `:depends-on`
  of the shipped `cl-cc-php` system, not just `cl-cc-php/test`, wired into
  `flake.nix`/`run-tests.lisp`/`coverage.lisp` the same way the cl-cc
  subsystems are, and documented in `docs/src/installation.md`'s dependency
  table. `%php-json-decode`/`%php-json-encode` deliberately still use the
  original hand-rolled reader/writer: PHP's `json_decode` needs values
  translated into this runtime's own `%php-array`/`+php-null+`/PHP-boolean
  representation, which is a real, non-trivial mapping — not the "weird
  unnecessary adapter" this project avoids — and migrating it is a larger,
  separately-scoped change than `json_validate`'s zero-value-model swap.

### Fixed

- `final class Foo { ... }` had the exact same gap `abstract class`
  did (see below): no registered top-level statement parser of its
  own, so it fell through to generic expression-statement parsing and
  errored on the bare `final` keyword. Found by re-checking the
  `abstract`-class fix's own investigation notes, which had already
  identified `final` as sharing the same gap without fixing it at the
  time. Fixed the same way, registering a `:final` statement parser
  mirroring `:abstract`'s. As with `abstract`, this only makes the
  class parse — nothing tracks "is this class final" past parsing, so
  extending a final class is not rejected either, confirmed by a test
  documenting that current behavior rather than implementing the
  enforcement.
- An `enum` using a trait (`enum S { use Greetable; case A; }`) failed
  outright when a merged-in method was actually called. Found
  immediately after the class-trait fix above by applying the same
  "does this related feature have the same class of gap" check to
  enums — `t/parser-class-test.lisp`'s
  `php-parser-enum-implements-methods-traits-and-constants` test
  combines `enum ... { use HasLabels; ... }` but, like the class-trait
  tests before the fix above, only checks the parser's raw AST shape.
  Two separate, non-obvious causes, found by reading the actual error
  at each step rather than assuming the first fix covered enums too:
  (1) `%php-merge-all-trait-members`'s original `(dolist (stmt stmts)
  (when (ast-defclass-p stmt) ...))` walk never found an enum's
  `ast-defclass` at all — `%php-parse-classlike` wraps an enum's class
  definition in an `ast-progn` alongside a `%php-enum-finalize` call,
  unlike a plain class, whose `ast-defclass` is a bare top-level form —
  so the merge silently never ran for any enum. Fixed by also checking
  one level into an `ast-progn`'s forms. (2) Once the merge did run, a
  merged-in method still failed: enum methods dispatch through the
  shared enum class object and need `:allocation :class`, not the
  ordinary per-instance `:allocation :instance` a trait method carries
  from where it was declared — `%php-parse-classlike` already applies
  this fixup to methods declared directly in an enum body, but a method
  merged in later, by a separate pass, never went through that code
  path. Fixed by applying the same fixup to merged-in methods when the
  target is an enum.
- `abstract class Foo { abstract function m(): T; ... }` failed to parse
  at all — `PHP parse error: unexpected keyword :ABSTRACT in
  expression`. `:readonly` has its own top-level statement parser
  (`readonly class Foo {...}`, `src/parser-class.lisp`) that requires
  `class` to immediately follow and delegates to
  `%php-parse-class-decl`; `:abstract` (and `:final`) had no such
  registration, so a leading `abstract` before `class` fell through to
  generic expression-statement parsing and errored on the bare keyword.
  Member-level `abstract function ...;` *inside* a class/trait/interface
  body already worked (`%php-parse-visibility-modifiers` already
  recognized `:abstract` there) — only the class-level modifier itself
  was missing. Found while investigating whether abstract classes work
  at all (no test anywhere exercised the class-level `abstract`
  modifier before this). Fixed by registering a `:abstract` statement
  parser mirroring `:readonly`'s exact pattern. **Not fixed, and
  confirmed as a separate, real gap by the same investigation:**
  instantiating an abstract class directly (`new Shape()` where `Shape`
  is `abstract`) is not rejected — nothing currently tracks "is this
  class abstract" as metadata past parsing, and no instantiation-time
  check exists to consult it, unlike real PHP's fatal "Cannot
  instantiate abstract class" error. Documented via a test asserting
  the current (unenforced) behavior rather than implemented, given the
  additional scope (tracking abstractness through to whatever lowers
  `new`) this investigation did not cover.
- **PHP trait methods did not actually work at all.** The simplest
  possible case — `trait Greetable { function greet() { return 'hi'; }
  } class C { use Greetable; } (new C())->greet()` — failed outright
  with `The slot CL-CC/PHP::GREET is missing from the object of class
  CL-CC/PHP::C`. Every trait test before this fix either checked the
  parser's raw AST shape directly (`t/parser-trait-test.lisp`, which
  never compiled or ran anything) or used *empty* traits and checked
  only `class_uses()` reflection (which did work — trait names were
  always tracked correctly). None ever called an actual trait method,
  which is the entire point of a trait. Root cause: `use TraitA;`
  inside a class body produced only an internal `:PHP-TRAIT-USE` marker
  slot-def (`%php-parse-use-trait-stmt`, `src/parser-trait.lisp`) that
  nothing in class lowering ever consulted — confirmed with `grep`,
  there was no reference to `:php-trait-use`/`:php-trait-names`
  anywhere outside `parser-trait.lisp`, and `*php-trait-registry*`
  (trait name → member list, populated by trait declarations) had no
  reader at all. Fixed with a new whole-program pass,
  `%php-merge-all-trait-members` (run from `parse-php-source`, after
  every top-level form — including every trait declaration — is
  parsed, so a class using a trait declared later in the same file
  still resolves correctly): it replaces each class's trait-use marker
  with the real member slot-defs of the traits it names. A member name
  defined by only one used trait is copied in directly. A member name
  defined by more than one used trait is resolved by a matching
  `insteadof` clause (`TraitA::member insteadof TraitB;` keeps TraitA's
  version); a collision `insteadof` does not resolve now signals a
  clear error — matching real PHP's fatal "has not been applied,
  because there are collisions" — instead of silently picking whichever
  trait happened to be listed first, which is what would have happened
  with no conflict handling at all. `t/parser-trait-test.lisp`'s ten
  parser-level tests (which check that `use ... { insteadof/as }`
  syntax parses into the correct raw metadata) needed updating to read
  that metadata from `*php-trait-applications*` instead of the now-
  merged-away marker slot-def — their original intent (verify parsing
  captured the right `insteadof`/`alias` data) is unchanged, only the
  channel they read it through. `as` aliasing is also implemented, by
  `%php-apply-trait-aliases`: `TraitA::method as alias;` adds a renamed
  *copy* of the resolved member under the alias name — purely additive,
  the original name stays callable too, matching real PHP — and
  `method as protected;` (visibility only, no rename) replaces the
  merged member's `:php-modifiers` visibility keyword in place. Both
  verified end-to-end. (Not verified: whether the changed visibility is
  actually *enforced* against external callers — that is a separate
  mechanism this investigation did not check.)
- Prefix `++`/`--` on a non-assignable operand (anything besides a
  `$variable`, array element, or property — e.g. `++(1+1)`) reported a
  confusing internal `SB-INT:SIMPLE-PROGRAM-ERROR "invalid number of
  arguments: 2"` instead of the intended, clear diagnostic:
  `php-lower-prefix-incdec`'s fallback called `%php-unsupported` (which
  takes exactly one `message` argument) with an extra, unused second
  argument. Found while designing a smaller, bounded alternative to
  fully implementing `goto` (see below) — routing `goto`'s missing
  label-statement case through this same existing
  "unsupported-parse-form" mechanism, which meant actually reading how
  every other caller used it first. Fixed by removing the extra
  argument; this was the only call site.
- `http_build_query` silently dropped every key/value pair after the
  first: joining used `(format nil "~{~A~^~A~}" (list (car (nreverse
  parts)) sep))`, the exact same "reads as a join but only ever consumes
  two list elements" shape as `%php-fputcsv`'s bug earlier in this file
  — `http_build_query(['a'=>1,'b'=>2,'c'=>3])` returned just `"a=1&"`,
  not `"a=1&b=2&c=3"`. Found while investigating
  `runtime-builtins-io.lisp`'s low coverage (the function had zero
  tests of any kind). Fixed with the same explicit
  part-then-separator-if-more loop `%php-fputcsv` uses.
- `is_numeric()` (`%php-is-numeric`/`%php-string-numeric-p`) and
  `filter_var(..., FILTER_VALIDATE_FLOAT)` (`%php-filter-float-value`)
  both delegated straight to Common Lisp's `read-from-string` to decide
  whether a string was numeric, which accepts syntax PHP's own
  numeric-string grammar does not: a ratio like `"1/2"` reads as the CL
  ratio `1/2` — a `numberp` — and a double-float exponent marker like
  `"1.0d0"` reads as a valid CL float literal, so `is_numeric("1/2")`
  and `is_numeric("1.0d0")` both incorrectly returned `true` (real PHP:
  `false` for both). `is_numeric` is common enough that this had real
  reach beyond the two functions directly affected. Fixed with a new
  `%php-numeric-grammar-p`, an explicit character-level scan of PHP's
  actual grammar (optional sign, digits with an optional fractional
  part, optional `e`/`E` exponent), shared by both functions — CL's
  reader is still used afterward, but only for the numeric *conversion*
  in `%php-filter-float-value`, once the grammar check has already
  confirmed the string can't be one of the CL-only forms that would
  make that conversion produce something PHP wouldn't. Verified against
  17 cases including both counter-examples and PHP's own valid-numeric
  edge cases (`"007"`, `"-.5"`, `"5."`, surrounding whitespace).
  `%php-floatval`/`floatval()` has a separate, deliberately more lenient
  leading-numeric-prefix parser (`floatval("1.5abc")` is valid PHP,
  returning `1.5`, unlike `is_numeric`/`filter_var`'s whole-string
  requirement) and was not touched — conflating the two would risk
  changing already-tested, working behavior for a different function
  with different semantics.
- `%php-filter-var`'s `FILTER_VALIDATE_*` dispatch (`src/runtime-builtins-
  types.lisp`) used bare magic numbers (`257`/`258`/`259`/`273`/`274`/`516`)
  in a `case` even though named constants for every one of them
  (`+php-filter-validate-int+` etc.) already existed right above it —
  found while re-verifying the "left in place as incomplete" note under
  Removed below, which turned out to be based on a stale read of this
  function. The actual reason those constants were unreferenced: `case`
  keys are not evaluated in Common Lisp, so writing
  `(case filter ((+php-filter-validate-int+) ...))` would have compared
  `filter` against the literal symbol, never against `257` — using them
  as `case` keys was never an option, which is presumably why whoever
  wired the dispatch used the raw numbers instead and left the constants
  dangling. Fixed by rewriting the dispatch as a `cond` of `=`
  comparisons against the named constants, which both eliminates four
  more entries from `paredit inspect unused-definitions`'s output and
  makes the dispatch's six filter IDs self-documenting at each call
  site instead of requiring a lookup against the PHP manual's numeric
  `FILTER_VALIDATE_*` values. Behavior is unchanged (same five integers,
  same handler functions) — confirmed by the full suite passing
  identically before and after.
- 12 more files still had the stale `packages/php/src/...` header path
  from before the extraction out of the cl-cc monorepo — the `[0.1.0]`
  fix below for "seventeen source-file header comments" predates several
  of these files' current form (some are later splits in this same
  session's own work, inheriting the stale header from their pre-split
  parent) and simply never reached the rest. Found with `grep -rl
  '^;;;; packages/' src/*.lisp`; every file in `src/` now has the
  post-extraction header format.
- `%php-checkdate` accepted invalid dates like February 30th or April 31st:
  `encode-universal-time` alone only range-checks a day-of-month against
  1-31, never against the actual length of the given month, so nothing in
  the old implementation ever caught the difference. Fixed by cross-
  checking against a new `%php-days-in-month` helper (also now used by
  `%php-date`'s existing leap-year handling, removing one duplicate copy of
  the same Gregorian leap-year rule).
- `%php-fputcsv` wrote only the first field of a multi-field row: joining
  the fields used `(format nil "~{~A~^~A~}" (list (car parts) sep))`, which
  reads as a join but iterates a two-element list — `(car parts)`, then
  `sep` itself misread as a second field — so every field after the first
  was silently dropped. Found by writing the test this file had never had
  (see below); fixed with an explicit field-then-separator loop.
- `similar_text` (`%php-similar-text`) computed the wrong answer for many
  inputs: it counted, for each character of the first string, whether that
  character occurred *anywhere at all* in the second string, with no
  position tracking — not PHP's real algorithm (find the longest common
  substring, then recurse on the parts of both strings before and after
  it). The two algorithms happened to agree on PHP's own manual example
  (`similar_text('World', 'Word') === 4`), which is why it went
  unnoticed, but diverge on simple cases: the old code returned `2`, not
  PHP's real `1`, for `similar_text('ab', 'ba')`. Replaced with the
  documented recursive longest-common-substring algorithm
  (`%php-similar-text-lcs`/`%php-similar-text-count`), verified against
  both the manual example and the `'ab'`/`'ba'` counter-example. The
  third `&$percent` by-reference parameter — previously silently
  ignored entirely (`(declare (ignore percent-var))`) — is now
  implemented and registered in `*php-by-ref-param-registry*`
  alongside `settype`, the only other entry that registry has ever had.
  Writing an end-to-end PHP-source test for it (`similar_text($a, $b,
  $p); echo $p;`) is incidentally the first test in this repository to
  verify the by-reference-builtin-parameter mechanism itself works
  through the full compile-and-run pipeline, not just at the parser's
  AST-shape level or by calling the Lisp function directly with a
  hand-built ref.
- `%php-compile-regex` (the hand-rolled PHP `preg_*` NFA engine) is now a
  proper backtracking matcher instead of the previous "greedy, never undoes
  a match" one: `preg_match('/a*a/', 'aaa')` now correctly matches (`a*`
  gives one character back to the trailing literal `a`), where the old
  engine committed to consuming all three `a`s for `a*` with no way to give
  any back. Implemented as continuation-passing style internally — every
  compiled piece takes a success continuation and returns its result, which
  is what lets a quantifier retry the rest of the pattern at a shallower
  position instead of only ever offering its single longest match. Capturing
  groups now correctly undo their recorded span when the continuation
  representing everything after them goes on to fail, rather than keeping a
  stale span from an abandoned branch. The change is entirely internal:
  `%php-compile-regex`'s external `(matcher str pos g) -> end-pos-or-nil`
  contract, and every one of its callers, is unchanged. Verified against the
  full 1401-test suite (no regressions) plus two new regression tests for
  the `a*a`-style case and for a capturing group backing off correctly.
- `%php-json-validate` (`json_validate`, PHP 8.3) always returned `T`,
  for any input, including obviously malformed JSON: it ran
  `%php-json-decode` inside a `handler-case` for `error`, but
  `%php-json-decode`'s own parser never signals — every unrecognised
  token in `%php-json-parse-value` falls through to a catch-all branch
  that returns `null` instead of raising, by design, so that
  `json_decode` can offer PHP's "returns null on malformed input"
  contract. That made the `handler-case`'s error clause structurally
  unreachable underneath `json_validate`. Fixed by giving
  `json_validate` its own dedicated strict parser
  (`%php-json-strict-value`/`-string`/`-number`/`-object`/`-array`) that
  signals on the first syntax problem instead of defaulting to null, and
  by checking that parsing consumed the entire input, since PHP rejects
  trailing garbage like `"123abc"`. `%php-json-decode`/`json_decode`
  itself is unchanged — it still tolerantly returns `null` on malformed
  input, and still ignores the `JSON_THROW_ON_ERROR` flag, matching PHP's
  behaviour only when that flag is unset.

### Changed

- `src/runtime-builtins-string-json.lisp`: the bounds-checked
  `(and (< pos (length s)) (char= (char s pos) X))` guard, repeated 17
  times across both JSON parsers, is now the one inlined predicate
  `%php-json-at-p`. Applied with `paredit query replace` against the
  literal S-expression shape, not by hand, so every site changed
  identically in one pass.
- `src/grammar.lisp`/`src/grammar-stmt.lisp`: `(eq (php-ts-peek-type ts)
  X)` and `(eq (php-ts-peek-value ts) X)` — 54 and 7 call sites,
  respectively, found via `paredit inspect duplicates` — are now
  `php-ts-at-type-p`/`php-ts-at-value-p`, alongside the file's existing
  `php-ts-at-end-p` predicate whose naming they follow. Same
  `paredit query replace` technique as the JSON change above; the sweep
  ran before the two new functions existed, specifically to avoid the
  self-match failure mode that technique has (a generic S-expression
  pattern doesn't know not to rewrite the very definition it's building).

### Added

- Two tests in `t/parser-class-e2e-test.lisp` covering `readonly`
  properties, which had zero end-to-end coverage of any kind before
  this — only parser-level tests confirming the modifier is captured as
  AST metadata. Confirms a `readonly` property can be set once during
  construction, and — the same class of gap as abstract-class
  instantiation elsewhere in this file — confirms that reassigning one
  afterward is currently **not** rejected, unlike real PHP's fatal
  "Cannot modify readonly property" error. Documented via a test
  asserting the current, unenforced behavior; enforcing it needs the
  property-write lowering to check readonly-ness and the object's
  already-initialized-or-not state, which this investigation did not
  trace.
- A test in `t/parser-class-e2e-test.lisp` confirming an abstract class
  using a trait, and a concrete subclass of it, both correctly get the
  trait's methods — the same combination that turned up the enum+trait
  bug above, checked here since it plausibly could have had the same
  kind of gap. It did not: this composition already worked correctly.
- Two tests in `t/parser-class-e2e-test.lisp` confirming basic
  interface/abstract-class correctness that nothing had verified
  end-to-end before: an interface constant is actually readable through
  an implementing class (`interface HasVersion { const VERSION = '1.0';
  } class Impl implements HasVersion {}` — `Impl::VERSION` correctly
  returns `'1.0'`; `t/parser-interface-test.lisp`'s several
  interface-constant tests all only checked the parser's raw AST shape,
  none ever compiled or ran anything), and a concrete subclass of an
  abstract class correctly calls both its own override of an abstract
  method and a concrete method the abstract parent provides. Found
  while investigating whether other foundational PHP OOP constructs had
  the same class of "looks tested, never actually exercised end-to-end"
  gap the trait-methods fix above uncovered — abstract-class *parsing*
  turned out to have exactly that gap (see Fixed); interfaces did not.
- A test in `t/parser-e2e-test.lisp` confirming that `goto` is currently
  unusable for any real PHP program: `goto label;` itself parses fine
  (`:goto` is a registered statement keyword), but the corresponding
  `label:` target statement was not recognized anywhere in the main
  parser pipeline — `php-parse-statement` (`src/parser-class.lisp`)
  dispatched only on `:T-KEYWORD` tokens, with no check for a bare
  identifier immediately followed by a colon, the syntax a label
  statement uses, so it fell through to the generic expression-statement
  parser and failed with a generic, unhelpful `PHP parse error:
  unexpected token (:TYPE :T-COLON ...)`. `goto`/label had zero test
  coverage of any kind before this, found while investigating
  `parser-stmt-decls-modules.lisp`'s low coverage. A correct fix is a
  real feature, not a bounded one — it needs a label-statement AST
  representation and block-level lowering that recognizes labels and
  switches a plain statement block to a Common Lisp `TAGBODY` (today
  only loops/switches build one internally, for their own generated
  break/continue tags), plus correctly modeling PHP's own
  goto-scoping restrictions (no jumping into a loop/switch/variable
  scope from outside it) — so, matching the precedent elsewhere in this
  file, that full feature is not attempted here, where a rushed fix
  risks a silently-wrong jump target being worse than a clean error.
  What *is* bounded and safe, and now implemented: `php-parse-statement`
  recognizes the "identifier immediately followed by colon" shape
  explicitly and reports it through `%php-unsupported` (`src/parser-
  support.lisp`) — the same mechanism every other not-yet-supported
  parse form in this codebase already uses — so the error at least names
  the construct that triggered it instead of a generic token complaint.
- A test in `t/runtime-builtins-io-tokenizer-php85-test.lisp` confirming
  `token_get_all` has no dedicated heredoc/nowdoc (`<<<EOT ... EOT`)
  handling — none of `%php-token-get-all`'s internal string/comment
  scanners ever mention `<<<` — but, importantly, degrades gracefully
  rather than crashing or hanging on heredoc-containing source: it still
  returns a well-formed token array, just not one matching real PHP's
  heredoc/nowdoc token shape. A real fix is a genuine new tokenizer
  feature (heredoc/nowdoc's own closing-identifier and PHP 7.3+ flexible
  indentation-stripping rules), not a bounded bug fix, so — matching the
  precedent set by `date_modify`/Fiber `resume`/`ReflectionProperty`/
  `array_walk` earlier in this file — documented via a test rather than
  attempted here.
- Two direct tests for `%php-session-apply-start-options`
  (`session_start($options)`'s option-merging logic) in
  `t/runtime-builtins-io-cookie-session-test.lisp`, investigating
  `runtime-builtins-io-cookie-session.lisp`'s low coverage: the
  function had zero tests calling it by name (only reachable indirectly
  through the high-level `session_start()` e2e tests) despite being the
  single largest function in the file. Confirms it correctly merges
  every `cookie_*` option, and — the easy way for this kind of
  repetitive option-merging code to go wrong — correctly falls back to
  the *existing* session cookie param rather than a hard-coded default
  when an option key is omitted. `*PHP-SESSION-NAME*`/
  `*PHP-SESSION-COOKIE-PARAMS*` are `defvar`s mutated in place by the
  function under test, so both tests `let`-bind them to avoid leaking
  session state into other tests.
- Six `sscanf` format-specifier cases in
  `t/runtime-builtins-register-e2e-test.lisp`, investigating
  `runtime-builtins-io-scan.lisp`'s low coverage: the suppress flag
  (`%*d`), a literal `%%`, octal (`%o`), `%u` correctly rejecting a
  leading `-` (unlike `%d`), and the `%e`/`%g` float-format aliases had
  no test exercising them at all. Unlike every other coverage-driven
  addition in this file, this one confirmed the existing implementation
  is already correct on every case — traced by hand against
  `%php-sscanf-scan-int`/`-scan-float` before writing each assertion,
  and every trace matched the actual test run with no fix needed.
- Two tests in `t/runtime-builtins-array-e2e-test.lisp` documenting a real
  `array_walk`/`array_walk_recursive` limitation found while investigating
  `runtime-builtins-regex-array.lisp`'s low coverage (both functions had
  zero tests of any kind before this): PHP's real signature for the
  callback is `function(&$value, $key)` — the value is by reference, so a
  callback that reassigns it is documented to mutate the array in place —
  but `%php-array-walk`/`%php-array-walk-recursive` invoke the callback
  with the bare value (`(funcall fn (cdr pair) (car pair))`), never boxing
  it in a `%php-make-ref` or writing a mutated value back afterward. One
  test confirms the callback genuinely is invoked with the right value and
  key (so this isn't a dispatch bug); the other confirms a mutating
  callback's assignment is silently lost. A real fix needs the by-ref
  boxing/writeback `array_walk` needs to happen dynamically around the
  callback invocation (inspecting the callable's own by-ref-parameter
  declaration at runtime, since the callback isn't known statically the
  way a builtin's own by-ref parameters are), which is a real,
  separately-scoped feature rather than a bounded bug fix — matching the
  `date_modify`/Fiber `resume`/`ReflectionProperty` precedent elsewhere in
  this file, current behavior is documented via a test rather than
  silently left uncovered or half-fixed.
- `t/runtime-builtins-string-analysis-test.lisp`: `strstr`/`stristr`/
  `strchr`, `str_word_count`, `levenshtein`, `similar_text` (including
  the bug it caught — see Fixed), `soundex`, and `printf`/`vsprintf`/
  `vprintf` had no coverage of any kind — no direct unit test and no
  PHP-source e2e test either. `runtime-builtins-string-analysis.lisp`
  moved from 56.9% to 98.3% `sb-cover` expression coverage as a
  result; this was the lowest-covered file in the whole `src/` tree
  among files with real logic (as opposed to the handful of near-empty
  re-export/dispatch files, or the data tables like
  `runtime-constants.lisp`, which have an inherent coverage ceiling
  under this metric documented earlier in this file).
- A test in `t/runtime-builtins-io-objects-php85-test.lisp` documenting a
  real `ReflectionProperty` limitation found while investigating
  `runtime-builtins-io-reflection-objects.lisp`'s low coverage:
  `%php-reflection-property-new` hardcodes `__visibility__` to `:public`
  unconditionally — this runtime has no class-property-visibility
  registry for it to consult instead — so
  `%php-reflection-property-get-mangled-name`'s `:private`/`:protected`
  branches are unreachable from any real PHP program, and
  `ReflectionProperty::getMangledName()` always returns the bare
  property name, even for a genuinely `private`-declared property (real
  PHP mangles it to `"\0ClassName\0propname"`). Adding the visibility
  lookup this would need is a real, separately-scoped feature (a
  class-property metadata registry, populated at class-definition time
  and threaded through the constructor), not a bounded bug fix, so —
  matching the precedent set by `date_modify` and Fiber `resume`
  earlier in this file — the current behavior is documented via a test
  rather than silently left uncovered or half-fixed.
- `t/runtime-helpers-generators-test.lisp`: `%php-make-generator` (the
  eager-collection, host-only generator path — its own docstring notes
  compiled PHP uses `%php-generator-enter`/`-exit` instead, so e2e
  `yield` tests never reach this path directly), `%php-generator-p`,
  `%php-yield`/`-from`'s outside-a-generator inspection-marker fallback,
  and the exception-payload predicates (`%php-make-exception`,
  `%php-exception-object-p`/`-class`/`-value`/`-matches-p`) had no direct
  tests. `runtime-helpers-generators.lisp` moved from 75.4% to 83.8%
  `sb-cover` coverage.
- `t/runtime-builtins-io-cookie-session-test.lisp`: the option-coercion
  helpers (`cookie-string`/`-integer`/`-bool`/`-samesite`) and the
  Expires HTTP-date formatter (`cookie-weekday-name`/`-month-name`/
  `-expires-gmt`) underneath `setcookie`/`session_*` had no direct tests —
  only the high-level builtins they support were e2e-tested.
  `runtime-builtins-io-cookie-session.lisp` moved from 71.4% to 74.8%
  `sb-cover` coverage.
- `t/runtime-builtins-regex-date-test.lisp`: `checkdate` (including the
  bug it caught), the leap-year/days-in-month helpers, and the entire
  `DateTime`-object-style family — `date_create`/`date_format`/
  `date_modify`/`date_diff`/`DateTime::getTimestamp` — had no tests at
  all (unlike `date()`/`gmdate()`/`strtotime()`, which are already
  exercised extensively by PHP-source e2e tests). `date_modify`'s test
  documents its current real behavior — a no-op, since this runtime does
  not implement PHP's relative-time-string parser — rather than leaving
  it silently unasserted. `runtime-builtins-regex-date.lisp` moved from
  59.4% to 82.9% `sb-cover` coverage.
- `t/parser-php84-features-test.lisp`: `%php-fiber-suspend`'s outside-a-fiber
  error path, `isRunning`/`isSuspended` (previously only ever seen `nil`),
  and `%php-fiber-resume`'s two branches — signalling on a fiber that was
  never suspended, and (the more important case) locking in, via a test
  rather than only a comment, that resuming a fiber that *did* suspend
  terminates it and returns `null` instead of truly continuing: `RESUME-FN`
  is never set anywhere in this file (see its own header comment on why),
  so this is this runtime's actual, current behavior, not a hypothetical.
  `runtime-fibers.lisp` moved from 54.8% to 71.0% `sb-cover` coverage.
- `t/runtime-builtins-io-files-test.lisp`: `STDIN`/`STDOUT`/`STDERR`,
  `flock` (shared vs. exclusive lock compatibility, and release via
  `LOCK_UN`), `fgetc`, `fseek`/`ftell`/`rewind`, and `fgetcsv`/`fputcsv`
  had no tests — `runtime-builtins-io-streams.lisp` moved from 69.2% to
  88.0% `sb-cover` expression coverage.
- `t/runtime-builtins-math-test.lisp`: the entire `bcmath` (`bcadd`/`bcsub`/
  `bcmul`/`bcdiv`/`bcmod`/`bccomp`/`bcscale`/`bcsqrt`/`bcpow`) and `gmp_*`
  (`gmp_init`/`gmp_add`/`gmp_sub`/`gmp_mul`/`gmp_div_q`/`gmp_mod`/`gmp_pow`/
  `gmp_abs`/`gmp_neg`/`gmp_gcd`/`gmp_cmp`/`gmp_intval`/`gmp_strval`/
  `gmp_sqrt`/`gmp_fact`) extension families, plus `rand`/`mt_rand`/`srand`/
  `mt_srand`/`random_int`/`random_bytes`, `pi`, `atan2`, and `is_infinite`,
  had no tests at all — unlike `runtime-constants.lisp`, this is ordinary
  logic with real, closeable branches, not a data table with an inherent
  coverage ceiling. `runtime-builtins-math.lisp` moved from 54.8% to 95.1%
  `sb-cover` expression coverage as a result.
- `t/runtime-bridge-provider-test.lisp`: `%php-host-bridge-entries` (the scan
  that finds every `%PHP-*` function for the VM host bridge) had no direct
  test — only e2e tests observing that its result was usable — and measured
  at 8.0% `sb-cover` expression coverage as a result. Directly calling it and
  asserting every returned entry is a real, callable, non-macro `%PHP-*`
  function brought that to 88.0%.
- `t/runtime-constants-test.lisp`: every entry in `*php-predefined-constants*`
  and `*php-predefined-class-constants*` now round-trips through
  `%php-lookup-constant`/`%php-predefined-class-constant`, plus the
  dynamic-constant (`STDIN`/`STDOUT`/`STDERR`) and namespace-qualified lookup
  paths. This moved `runtime-constants.lisp` only from 65/838 to 69/838
  `sb-cover` expressions — most of that file's "expressions" are literal data
  inside two large quoted tables (`+php-nl-langinfo-items+`'s 57 tuples, the
  Intl/Pdo/Uri class-constant registrations' ~30), which read-time literal
  data can't register as "executed" the way a table-*driven* lookup can, so
  the file's ceiling under this metric is well under 100% regardless of test
  quality.
- `coverage.lisp` and `packages.coverage` in `flake.nix` (`nix build .#coverage`):
  an `sb-cover` HTML report scoped to `src/`'s own code, following the same
  pattern other nerima-lisp repos (e.g. cl-prolog) use — a package, not a
  check, so it makes the number visible without gating `nix flake check` on a
  threshold nobody has agreed to yet. `cl-nix-forge`'s `mkCoverageReport`
  (what those repos actually use) was evaluated first and set aside: it
  requires migrating this repo's whole hand-written `flake.nix` onto
  `cl.lispDerivation`, which is a much larger, separately-scoped change for a
  repo whose dependency shape (pulling `cl-cc` from a monorepo checkout by
  subdirectory) doesn't match `cl-nix-forge`'s single-tagged-dependency model.
- Two `cl-weave` `it-fuzz` tests in `t/lexer-test.lisp`: 200 trials each of
  `tokenize-php-source`/`parse-php-source` against strings drawn from a
  PHP-syntax-heavy alphabet, asserting malformed input always ends in a
  reported `simple-error` diagnostic (the only outcome the lexer/parser ever
  intentionally signal for bad input) rather than an unhandled crash.
- `t/runtime-builtins-string-json-test.lisp`: `json_encode` (scalars,
  `JSON_PRETTY_PRINT`), `%php-json-quote-string`'s escape table,
  `json_decode`'s malformed-input-returns-null tolerance, and — the main
  gap — `json_validate` (see the `json_validate` entry under Fixed), which
  had zero direct tests despite being a real 8.3 builtin with observable
  pass/fail behaviour.
- Two tests in `t/parser-class-e2e-test.lisp` checking member-level
  `final function ...` — the same "does the sibling of a just-fixed
  feature have the same gap" check applied to `final class` above.
  Unlike `final class`, no fix was needed here: `final` is already in
  `%php-parse-visibility-modifiers`'s accepted modifier list alongside
  `:abstract`/`:readonly` (`src/parser-class.lisp`), so a member-level
  `final function seal() { ... }` is consumed as an ordinary modifier
  before the `:function` keyword dispatch and always parsed correctly —
  confirmed by the first test. The second test confirms the same class
  of enforcement gap as `final class`/`readonly` elsewhere in this file:
  overriding a `final` method in a subclass is currently **not**
  rejected, unlike real PHP's fatal "Cannot override final method"
  error — nothing tracks "is this method final" past parsing to check
  against a subclass's own method table.

### Changed

- The four `t/` files over the 500-line limit were split by concern, using
  `paredit`'s structural kill/yank so every move was a verified-balanced
  span, not a hand-edited one: `runtime-builtins-io-objects-php85-test`'s
  eight Uri\* tests moved to `runtime-builtins-io-uri-php85-test`;
  `runtime-builtins-io-tokenizer-php85-test`'s ten
  setcookie/session-cookie-param tests moved to
  `runtime-builtins-io-cookie-session-php85-test`;
  `runtime-builtins-array-test`'s eleven reshape/compare tests (chunk
  through replace) moved to `runtime-builtins-array-transform-test`; and
  `runtime-builtins-register-e2e-test`'s seventeen largest tests moved to
  `runtime-builtins-register-e2e-formatting-test` (a size-driven split,
  documented as such in its header, since the parent suite's own point is
  to stay one flat builtin-reachability list). `:components` order is
  otherwise unchanged; every new file is registered immediately after the
  file it was split from.
- `flake.nix`/`flake.lock` bumped the three tagged, test-only inputs to their
  latest releases: `cl-weave` v1.0.0 → v1.1.0, `cl-prolog` v1.0.1 → v1.1.0,
  `cl-parser-kit` v1.0.0 → v1.0.1. `cl-cc` stays pinned at its current commit:
  it is 166 commits behind an unreleased, currently-failing-`nix flake check`
  branch, so bumping it is its own change with its own test run, not a routine
  dependency update (see `docs/src/compatibility.md`).
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

### Removed

- 21 unreferenced function definitions across 14 files (found with
  `paredit inspect unused-definitions`, cross-checked against every
  `t/` test file, `src/package.lisp`'s export list, and the sibling `cl-cc`
  checkout so exported public API was left untouched): `php-lex-peek` and
  `php-lower-foreach`/`php-lower-while` (both superseded by their
  `-with-label` variants), `%php-apply-named-args`,
  `%php-parse-arglist-named`, `%php-parse-first-class-callable`,
  `%php-named-arg-pair-ast`, `%php-parse-named-args`,
  `%php-parse-trait-use-member`, `%php-parse-property-slot`,
  `%php-skip-expression-like`, `%php-slot-readonly-p`,
  `%php-parse-label-stmt`, `%php-skip-type-annotation`,
  `%php-array-map-multi`, `%php-array-splice-in-place`,
  `%php-array-map-null`, `%php-object-visible-pair-by-name`, `%php-enum-name`
  (whose hash-table lookup used the wrong key type, `'name` instead of the
  `"name"` string every enum case is actually stored under, so it could never
  have returned a real value even if it had been called), `%php-enum-p`, and
  the test helper `%php-assert-full-source-unsupported`. At the time,
  `+php-filter-validate-int+`/`-float+`/`-url+`/`-email+` were left in place
  as incomplete-but-intentional PHP surface rather than dead code, on the
  belief that `%php-filter-var`'s dispatch did not yet handle them — that
  belief was stale even then: the dispatch already routed all four filter
  IDs correctly, just via bare magic numbers (`257`/`259`/`273`/`274`)
  instead of these named constants, which is why a later, independent
  `unused-definitions` pass flagged them again as unreferenced. See Fixed
  below for the actual resolution: the dispatch now uses the named
  constants directly.
- Four more unreferenced definitions, found by a follow-up
  `paredit inspect unused-definitions` sweep (this time run against
  `src/*.lisp` *and* `t/*.lisp` together, since scoping to `src/` alone
  produced 30 candidates — most of them false positives only called from
  `t/`, which the tool can't see when test files aren't in its input set):
  `%php-skip-attributes` (`src/parser-attributes.lisp`, a thin
  discard-the-parse wrapper around `%php-parse-attributes` that no call
  site ever actually wanted), `%php-parse-trait-decl`
  (`src/parser-trait.lisp`, a complete, correct `trait Name { ... }`
  parser — including its own `*php-trait-registry*` population — silently
  superseded when `trait` statement parsing was generalized onto the
  shared `%php-parse-classlike` used for interfaces/enums too; the live
  registry-population site is `src/parser-stmt-decls.lisp`'s
  `%php-parse-classlike`, not this file), and `%php-generator-send`/
  `%php-generator-current` (`src/runtime-helpers-generators.lisp`) — real,
  correct implementations of PHP `Generator`'s `send()`/`current()` methods
  for this runtime's eager, pre-collected-queue generator model, but
  PHP-level `$gen->send(...)`/`$gen->current()` method-call syntax was
  never wired to dispatch to them anywhere in the parser or lowering
  pipeline (generators here only work through `foreach`/`yield from`
  iteration, via `%php-generator-next`/`-valid`), so neither was ever
  reachable at runtime.
- The "advisory" method-copying block in `%php-apply-traits`
  (`src/parser-trait.lisp`) — found while investigating (and, in the
  same pass, fixing — see Fixed) the trait-methods gap. It was also
  independently buggy: `(setf (getf record :methods) ...)` mutated a
  local variable bound to `(car existing)`, not the actual
  `*php-trait-applications*` hash-table entry, so on the very first
  trait in any `use` list (where `:methods` doesn't exist in the plist
  yet and `setf`-of-`getf` needs to prepend a new key) the update was
  silently discarded every time. Confirmed via `grep` that nothing
  anywhere read `:methods` from `*php-trait-applications*` entries
  (only `:trait-names`, for reflection, actually was), so this was dead
  code independent of the bug in it. `*php-trait-registry*` itself —
  correctly populated, just as unread at the time this was found — is
  now genuinely read: it is exactly the data (trait name → member
  slot-defs) `%php-merge-trait-members` needed for the real fix.

### Fixed

- `t/runtime-builtins-math-test.lisp` (formerly `t/php-math-tests.lisp`) is
  now listed in `cl-cc-php.asd`, so its assertions are compiled and run. It
  previously was not, and running it for the first time surfaced six test
  bugs (not implementation bugs), now fixed in the same file: exact-rational
  vs. double-float literal comparisons (`%php-round`'s `3.14` case,
  `%php-log`'s `(exp 1)` case using single- instead of double-float
  precision), CL's `(sin 0)`/`(cos 0)`/`(tan 0)` returning single-float where
  `%php-sin`/`-cos`/`-tan` return double-float, `%php-log10`/`%php-log2`'s
  documented exact-integer-power short-circuit compared against a float
  literal instead of the integer it actually returns, `intdiv`'s
  `division-by-zero-error` test targeting a condition class that has never
  existed (`%php-throw` always signals `php-exception`, with the PHP class
  name as a slot, not a distinct condition type), and `is_finite`'s
  expectation for `MOST-POSITIVE-DOUBLE-FLOAT` contradicting this runtime's
  own consistent, pre-existing choice to represent PHP's `INF` as that same
  sentinel value (see `runtime-constants.lisp` and `%php-fdiv`).
- Stale `packages/php/src/...` paths in seventeen source-file header comments,
  left over from the extraction out of the cl-cc monorepo.

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
