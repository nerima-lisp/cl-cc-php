# Quick Start

This page carries one task through to completion: turning a PHP source string
into a cl-cc AST, and seeing what the lexer did along the way.

## Load the system

```lisp
(asdf:load-system "cl-cc-php")
```

## Parse PHP into an AST

```lisp
(cl-cc/php:parse-php-source "<?php $x = 1 + 2;")
```

`parse-php-source` takes a source string and returns a list of top-level AST
nodes, the same shape `parse-all-forms` returns for Common Lisp. Those nodes are
cl-cc AST nodes, so the rest of the compiler can consume them directly.

## Look at the tokens

When a parse does something surprising, check the token stream first. It tells
you whether the lexer or the parser is at fault:

```lisp
(cl-cc/php:tokenize-php-source "<?php $x = 1 <=> 2;")
```

Tokens are plists of the form `(:type :T-XXX :value val)`, and the list always
ends with `(:type :T-EOF :value nil)`.

## Keep the surface syntax

The AST discards detail that a formatter or linter needs. Parse to a concrete
syntax tree instead when that detail matters:

```lisp
(cl-cc/php:parse-php-source-to-cst "<?php if ($a) { b(); }")
;; => (values cst-list diagnostics)
```

Note that this returns two values: the CST nodes and any diagnostics collected
during the parse.

## Reject unsupported constructs early

`php-check-supported-forms` walks an AST and signals an error on any construct
the frontend does not handle, rather than letting it fail deeper in the
pipeline:

```lisp
(let ((ast (cl-cc/php:parse-php-source source)))
  (cl-cc/php:php-check-supported-forms ast)
  ast)
```

## Next steps

- [Core Concepts](core-concepts.md) explains the lexer/parser/grammar split and
  why the `%php-` runtime builtins exist.
- [Recipes](recipes.md) covers PHP value semantics, arrays, enums, and adding a
  builtin.
- [API Reference](api-reference.md) specifies the entry points.
