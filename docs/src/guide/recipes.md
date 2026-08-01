# Recipes

Task-oriented snippets. All of these assume `(in-package :cl-cc/php)`.

## Parse a file rather than a string

`parse-php-source` takes source text, so read the file first:

```lisp
(parse-php-source (uiop:read-file-string "example.php"))
```

## Inspect the token stream when a parse fails

When a parse error is unhelpful, look at what the lexer actually produced:

```lisp
(tokenize-php-source "<?php $x = 1 <=> 2;")
```

This separates "the lexer mis-tokenised" from "the parser mis-grouped", which
are different bugs in different files.

## Keep surface syntax with the CST

The AST is lossy by design. When you need original structure — for a formatter,
a linter, or a source-to-source rewrite — parse to a CST instead:

```lisp
(parse-php-source-to-cst "<?php if ($a) { b(); }")
```

## Check for unsupported constructs before compiling

`php-check-supported-forms` reports constructs the frontend does not handle,
rather than letting them fail later in the pipeline:

```lisp
(php-check-supported-forms (parse-php-source source))
```

## Compare values with PHP semantics

Do not use `equal` on PHP values. Use the runtime predicates:

```lisp
(%php-eq-loose  "10" 10)   ; PHP ==
(%php-eq-strict "10" 10)   ; PHP ===
(%php-truthy    "0")       ; PHP falsiness: "0" is false
```

## Work with PHP arrays

PHP arrays are ordered maps, not Lisp lists or hash tables:

```lisp
(let ((a (%php-array)))
  (%php-array-set a "k" 1)
  (%php-array-ref a "k")
  (%php-array-key-exists a "k")
  (%php-count a))
```

`%php-array-first`, `%php-array-last`, `%php-array-find`, `%php-array-find-key`,
`%php-array-any`, and `%php-array-all` cover the PHP 8.4 array functions.

## Distinguish null from false

```lisp
(%php-null-p +php-null+)   ; => T
(%php-null-p nil)          ; => NIL
```

`+php-null+` is a dedicated sentinel. Passing Lisp `nil` where PHP null is
meant produces wrong results in loose comparisons.

## Handle PHP exceptions

```lisp
(%php-make-exception "RuntimeException" "boom")
(%php-exception-object-p obj)
(%php-exception-matches-p obj "RuntimeException")
```

## Work with enums

```lisp
(%php-enum-cases    "Suit")
(%php-enum-from     "Suit" "H")
(%php-enum-try-from "Suit" "nope")   ; nil rather than an error
```

## Add a runtime builtin

1. Implement the function in the appropriate `src/runtime-builtins-*.lisp`
   file, grouped with its family.
2. Add a row to the registration table that `%php-register-all-builtins`
   walks — do not write a bespoke registration form.
3. Add a table-driven test row in the matching `t/<source>-test.lisp`.

Keeping registration in the table is what stops the registry and the
implementations from drifting apart.

## Run one suite while iterating

The Nix check runs everything. While working on a single area it is faster to
load the test system in a REPL and call the suite directly:

```lisp
(asdf:load-system "cl-cc-php/test")
(cl-cc-php/test:run-tests)
```

`run-tests` signals an error on any failure rather than returning `nil`, so it
is usable as a script-level gate.
