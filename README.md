# cl-cc-php

[![CI](https://github.com/nerima-lisp/cl-cc-php/actions/workflows/ci.yml/badge.svg)](https://github.com/nerima-lisp/cl-cc-php/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-nerima--lisp.github.io-blue)](https://nerima-lisp.github.io/cl-cc-php/)

The PHP frontend for the [cl-cc](https://github.com/nerima-lisp/cl-cc) Common
Lisp compiler: a lexer, parser, and grammar that turn PHP source into cl-cc's
AST, plus the PHP runtime builtins that compiled code calls into. Full
documentation is at
[nerima-lisp.github.io/cl-cc-php](https://nerima-lisp.github.io/cl-cc-php/).

## Quick Start

```lisp
(asdf:load-system "cl-cc-php")

(cl-cc/php:parse-php-source "<?php $x = 1 + 2;")
```

`parse-php-source` returns a list of top-level cl-cc AST nodes.
`tokenize-php-source` gives you the token stream instead, and
`parse-php-source-to-cst` gives you a concrete syntax tree when you need the
surface detail the AST drops.

## Install

Add the flake input:

```nix
cl-cc-php = {
  url = "github:nerima-lisp/cl-cc-php";
  flake = false;
};
```

Then depend on it from your `.asd`:

```lisp
:depends-on ("cl-cc-php")
```

cl-cc-php is not standalone. It needs `cl-cc-ast`, `cl-cc-bootstrap`,
`cl-cc-parse`, and `cl-cc-vm`, which live inside a checkout of the cl-cc
monorepo rather than in split-out repositories, plus a checkout of
[cl-json-kit](https://github.com/nerima-lisp/cl-json-kit). See
[Installation](https://nerima-lisp.github.io/cl-cc-php/installation/).

## Documentation

- [Quick Start](https://nerima-lisp.github.io/cl-cc-php/quick-start/)
- [Core Concepts](https://nerima-lisp.github.io/cl-cc-php/core-concepts/)
- [API Reference](https://nerima-lisp.github.io/cl-cc-php/api-reference/)
- [Architecture](https://nerima-lisp.github.io/cl-cc-php/architecture/)
- [Compatibility](https://nerima-lisp.github.io/cl-cc-php/compatibility/)

## Development

```sh
nix develop                          # SBCL with the dependency roots exported
nix flake check --print-build-logs   # tests, formatting, and docs
nix run .#test                       # the test suite alone
nix fmt                              # nixfmt via treefmt
```

Without Nix, `run-tests.lisp` falls back to sibling checkouts of `cl-cc`,
`cl-weave`, `cl-prolog`, `cl-parser-kit`, and `cl-json-kit` next to this
repository:

```sh
sbcl --script run-tests.lisp
```

See [Development](https://nerima-lisp.github.io/cl-cc-php/development/).

## Contributing

See the organisation-wide
[contributing guide](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
and [code of conduct](https://github.com/nerima-lisp/.github/blob/main/CODE_OF_CONDUCT.md).

## Support

Open an issue at
[nerima-lisp/cl-cc-php/issues](https://github.com/nerima-lisp/cl-cc-php/issues).
For security reports, follow the
[security policy](https://github.com/nerima-lisp/.github/blob/main/SECURITY.md).

## License

MIT — see [LICENSE](LICENSE).
