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
cl-cc-vm — bootstrap and vm are the compiler's self-referential core and are
an explicit non-goal for further splitting (see cl-cc's
`docs/repo-split-design.md`), so `flake.nix` pulls them from a `cl-cc`
checkout as a plain (non-flake) source tree, the same pattern cl-cc's own
flake uses for cl-prolog/cl-weave/cl-cc-ast. `nix flake check` builds and runs
the full suite hermetically. The `.asd` also loads correctly against a bare
cl-cc checkout outside Nix, and the `:cl-cc-php/tests` system (see below) runs
directly on [cl-weave](https://github.com/nerima-lisp/cl-weave) with no
adapter layer.

## Usage

```lisp
(asdf:load-system :cl-cc-php)
```

## Testing

Tests live under `tests/` and run on [cl-weave](https://github.com/nerima-lisp/cl-weave)
directly — no compatibility shim, no umbrella `cl-cc/test` package. Loading
`:cl-cc-php/tests` additionally requires `cl-cc-pipeline` (for the e2e suites,
which compile and run PHP source end-to-end) and `cl-weave` itself to be
reachable in the ASDF source-registry:

```lisp
(asdf:load-system :cl-cc-php/tests)
(cl-cc-php/test:run-tests)
```

### Via Nix

```sh
nix flake check
```

builds a hermetic sandbox providing SBCL plus `cl-cc` (for
bootstrap/ast/parse/vm/pipeline/…), `cl-weave`, `cl-prolog`, and
`cl-parser-kit` — all pinned in `flake.lock` — and runs `scripts/run-tests.lisp`.

### Without Nix

`scripts/run-tests.lisp` also runs directly against sibling checkouts (the
default it falls back to is `../cl-cc`, `../cl-weave`, `../cl-prolog`,
`../cl-parser-kit` next to this repo — override with the
`CL_CC_PHP_CL_CC_ROOT` / `CL_CC_PHP_CL_WEAVE_ROOT` /
`CL_CC_PHP_CL_PROLOG_ROOT` / `CL_CC_PHP_CL_PARSER_KIT_ROOT` env vars):

```sh
sbcl --script scripts/run-tests.lisp
```

## License

MIT — see [LICENSE](LICENSE).
