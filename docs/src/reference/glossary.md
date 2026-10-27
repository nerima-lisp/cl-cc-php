# Feature Glossary

Key types and functions are representative exports from their owning feature
packages; they do not all belong to the `cl-cc/php` facade. A `%` prefix marks
an implementation helper, but package export status is determined by the
feature package. `None` marks an entry with no representative symbol listed.

## syntax

- Definition: Owns PHP tokenization, shared grammar machinery, parser diagnostics, and
  unsupported-form checks.
- Package: `cl-cc/php/syntax`
- Key types: None.
- Key functions: `tokenize-php-source`, `parse-php-source`, `parse-php-source-to-cst`

## expressions

- Definition: Owns generic PHP expression parsing and lowering, including operators and
  evaluation order.
- Package: `cl-cc/php/expressions`
- Key types: None.
- Key functions: `php-parse-expr`, `%php-call`, `%php-concat`

## statements

- Definition: Parses and lowers PHP statements and control-flow constructs.
- Package: `cl-cc/php/statements`
- Key types: None.
- Key functions: `php-parse-statement`, `php-cst-parse-statement`

## functions

- Definition: Handles PHP function declarations, calls, parameters, and closures.
- Package: `cl-cc/php/functions`
- Key types: None.
- Key functions: `php-parse-param-list`, `%php-callable-function`

## classes

- Definition: Handles PHP classes, interfaces, traits, enums, and class members.
- Package: `cl-cc/php/classes`
- Key types: None.
- Key functions: `php-cst-parse-new`, `%php-enum-cases`, `%php-clone`

## generators

- Definition: Handles PHP generator declarations, yield expressions, and generator runtime behavior.
- Package: `cl-cc/php/generators`
- Key types: None.
- Key functions: `%php-yield`, `%php-generator-next`, `%php-foreach-pairs`

## fibers

- Definition: Provides PHP fiber parsing and runtime integration.
- Package: `cl-cc/php/fibers`
- Key types: None.
- Key functions: `%php-fiber-make`, `%php-fiber-start`, `%php-fiber-resume`

## arrays

- Definition: Owns PHP ordered-array values and core literal, access, and update behavior.
- Package: `cl-cc/php/arrays`
- Key types: None.
- Key functions: `%php-array`, `%php-array-ref`, `%php-array-set`

## strings

- Definition: Owns PHP string literals, interpolation, concatenation, and string-value
  semantics.
- Package: `cl-cc/php/strings`
- Key types: None.
- Key functions: `%php-strlen`, `%php-strtolower`, `%php-strtoupper`

## match

- Definition: Handles PHP match-expression parsing and lowering.
- Package: `cl-cc/php/match`
- Key types: None.
- Key functions: `%php-lower-match`

## attributes

- Definition: Parses PHP attributes and associates their metadata with declarations.
- Package: `cl-cc/php/attributes`
- Key types: `php-attribute`
- Key functions: `%php-parse-attributes`, `%php-attribute-metadata`

## types

- Definition: Handles PHP type syntax, type declarations, and runtime type behavior.
- Package: `cl-cc/php/types`
- Key types: None.
- Key functions: `php-parse-type-annotation`, `%php-value-type`, `%php-stringify`

## errors

- Definition: Models PHP errors, exceptions, throw behavior, and exception matching.
- Package: `cl-cc/php/errors`
- Key types: `php-exception`
- Key functions: `%php-throw`, `%php-make-exception`, `%php-trigger-error`

## stdlib

- Definition: Provides PHP standard-library functions and constants, including array,
  string, JSON, URI, and DOM operations.
- Package: `cl-cc/php/stdlib`
- Key types: None.
- Key functions: `%php-json-encode`, `%php-array-map-keys`, `%php-uri-rfc3986-parse`

## backend

- Definition: Registers PHP runtime operations with the compiler runtime bridge.
- Package: `cl-cc/php/backend`
- Key types: None.
- Key functions: `%php-host-bridge-entries`
