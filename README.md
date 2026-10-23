# cl-cc-php

[![CI](https://github.com/nerima-lisp/cl-cc-php/actions/workflows/ci.yml/badge.svg)](https://github.com/nerima-lisp/cl-cc-php/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-nerima--lisp.github.io-blue)](https://nerima-lisp.github.io/cl-cc-php/)

The PHP frontend for the [cl-cc](https://github.com/nerima-lisp/cl-cc) Common
Lisp compiler: a lexer, parser, and grammar that turn PHP source into cl-cc's
AST, plus the PHP runtime builtins that compiled code calls into.

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

cl-cc-php needs the compiler systems `cl-cc-ast`, `cl-cc-bootstrap`,
`cl-cc-parse`, and `cl-cc-vm` from their separately pinned sibling source
repositories. It also uses [cl-host-kit](https://github.com/nerima-lisp/cl-host-kit)
and [cl-json-kit](https://github.com/nerima-lisp/cl-json-kit) at runtime. The
umbrella cl-cc checkout is not a PHP package dependency. See
[Getting Started](https://nerima-lisp.github.io/cl-cc-php/getting-started/).

## Documentation

- [Getting Started](https://nerima-lisp.github.io/cl-cc-php/getting-started/)
- [Core Concepts](https://nerima-lisp.github.io/cl-cc-php/guide/core-concepts/)
- [API Reference](https://nerima-lisp.github.io/cl-cc-php/reference/api/)
- [Architecture](https://nerima-lisp.github.io/cl-cc-php/reference/architecture/)
- [Compatibility](https://nerima-lisp.github.io/cl-cc-php/reference/compatibility/)

## Development

```sh
nix develop                          # SBCL with the dependency roots exported
nix flake check --print-build-logs   # tests, formatting, and docs
nix run .#test                       # the test suite alone
nix fmt                              # nixfmt via treefmt
```

Without Nix, `run-tests.lisp` uses sibling checkouts for the compiler systems
and library dependencies. See [Getting Started](https://nerima-lisp.github.io/cl-cc-php/getting-started/)
for the expected source roots:

```sh
sbcl --script run-tests.lisp
```

See [Development](https://nerima-lisp.github.io/cl-cc-php/project/development/).

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
