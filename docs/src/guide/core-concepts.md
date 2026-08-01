# Core concepts

## The three stages

cl-cc-php is a frontend. It does not emit code; it produces the AST that the
rest of cl-cc consumes.

```
PHP source ──lexer──▶ tokens ──parser──▶ cl-cc AST ──▶ (cl-cc: MIR, optimize, codegen, VM)
                                    └──▶ CST
```

**Lexer.** `tokenize-php-source` produces a token stream. Operator dispatch is
table-driven, so adding an operator is a table entry rather than a new branch.

**Parser.** `parse-php-source` produces a cl-cc AST. The parser is split by
syntactic category — expressions, statements, declarations, classes, traits,
interfaces — so that a change to, say, match expressions does not touch class
parsing.

**Grammar.** `parse-php-source-to-cst` produces a concrete syntax tree, which
keeps surface detail the AST discards. Use it when position or original
spelling matters; use the AST when you want to compile.

## The two runtimes

There is a distinction that trips people up on first reading:

- **Parse-time code** is what runs while cl-cc-php is reading your PHP.
- **Runtime builtins** are Lisp functions that *compiled PHP* calls at run time.

The `%php-` prefixed exports are the second kind. `%php-array-ref`,
`%php-eq-loose`, `%php-truthy`, and their several hundred siblings exist so
that generated code has a PHP-semantics primitive to call. They are exported
because generated code must be able to name them, not because they are a
comfortable user-facing API.

## The builtin registry

PHP has a large flat namespace of global functions. cl-cc-php registers them in
a dispatch registry rather than resolving each one at compile time.

Registration is data, not code: the roughly 440 builtin registrations live in a
table that `%php-register-all-builtins` walks. Adding a builtin means adding a
row. This matters because the alternative — 440 hand-written registration forms
— is exactly the shape that drifts out of sync with the implementations.

Builtins are grouped by family across several source files: core, array, array
sorting, string (with sub-families for formatting, multibyte, encoding,
transformation, analysis, ctype, serialization, JSON, and digests), regex and
`preg_*`, date, number formatting, math, type predicates, and I/O.

## PHP loose semantics

PHP's comparison and coercion rules are not Lisp's. The runtime layer models
them explicitly rather than leaning on host semantics:

- `%php-eq-loose` implements `==`, `%php-eq-strict` implements `===`.
- `%php-truthy` implements PHP's truthiness, where `"0"` is false.
- `%php-to-number` implements numeric coercion.
- `%php-spaceship` implements `<=>`.
- `+php-null+` is a distinct null sentinel; it is not `nil`, because PHP
  distinguishes null from false and from the empty array.

Treating these as ordinary Lisp operations is the most common source of
subtly-wrong output.

## Test organisation

Tests live in `t/` and run on cl-weave. Two support files
(`helpers-parser`, `helpers-e2e`) carry the shared helpers.

Most suites are table-driven: a test is a row of input and expected output, not
a hand-written block. End-to-end suites go further and actually compile and run
PHP source through the full pipeline, which is why the test system depends on
`cl-cc-pipeline` while the main system does not.
