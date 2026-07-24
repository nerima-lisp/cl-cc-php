# cl-cc-php

The PHP frontend/backend for the [cl-cc](https://github.com/nerima-lisp/cl-cc)
Common Lisp compiler.

This system provides PHP language support: the lexer, parser, and grammar for
turning PHP source into cl-cc's AST, along with the PHP runtime builtins
(`array_*`, `str*`, math, regex/`preg_*`, type predicates, I/O, and the
dispatch registry). It defines the `:cl-cc-php` system, extracted from the cl-cc
monorepo as a **plugin repo**.

## Status

Source extracted from the cl-cc monorepo. Unlike the dependency-free leaf repos
(cl-cc-ast), cl-cc-php depends on cl-cc-ast, cl-cc-bootstrap, cl-cc-parse, and
cl-cc-vm (the last three still internal to cl-cc), so standalone Nix CI is
pending those systems being consumable as flake inputs (or cl-cc consumed as a
flake input). The `.asd` loads correctly against a cl-cc checkout.

## Usage

```lisp
(asdf:load-system :cl-cc-php)
```

## License

MIT — see [LICENSE](LICENSE).
