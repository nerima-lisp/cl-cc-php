;;;; cl-cc-php.asd — PHP frontend: lexer, parser, grammar
;;;;
;;;; This form comes FIRST, before any defsystem. ASDF binds *package* to
;;;; ASDF-USER only for a file it loads itself; read any other way — a REPL
;;;; `load`, an editor evaluating the buffer, flake.nix parsing :version — the
;;;; file is read in whatever package happens to be current.

(in-package #:asdf-user)

(asdf:defsystem "cl-cc-php"
  :description "CL-CC PHP frontend: lexer, parser, and grammar"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.2"
  :homepage "https://github.com/nerima-lisp/cl-cc-php"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-php/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-php.git")
  :depends-on (:cl-cc-ast        ; AST node definitions the parser emits
               :cl-cc-bootstrap  ; compiler self-hosting core
               :cl-cc-parse      ; shared parsing infrastructure
               :cl-cc-vm         ; bytecode VM
               :cl-host-kit      ; host operations: is_dir, FILTER_VALIDATE_URL
               :cl-json-kit)     ; RFC 8259 JSON reader, used by json_validate
  :pathname "src"
  :serial t
  :components
  (
   ;; The syntax registry must exist before feature package imports and registration.
   (:file "syntax/package")
   (:file "syntax/registry")
   ;; Feature packages load in dependency order before the facade and source.
   (:file "errors/package")
   (:file "types/package")
   (:file "expressions/package")
   (:file "arrays/package")
   (:file "strings/package")
   (:file "attributes/package")
   (:file "match/package")
   (:file "generators/package")
   (:file "statements/package")
   (:file "functions/package")
   (:file "classes/package")
   (:file "fibers/package")
   (:file "stdlib/package")
   (:file "backend/package")
   ;; The facade imports feature exports and must exist before source is read.
   (:file "package")
   (:file "syntax/lexer")
   (:file "syntax/lexer-ops")
   (:file "functions/parser-support")
   (:file "syntax/parser")
   (:file "syntax/grammar")
   (:file "syntax/unsupported")
   (:file "errors/runtime-errors")
   (:file "types/runtime-types")
   (:file "expressions/parser-expr")
   (:file "expressions/parser-expr-primary")
   (:file "expressions/parser-expr-postfix")
   (:file "expressions/parser-expr-operator")
   (:file "expressions/parser-expr-advanced")
   (:file "expressions/parser-expr-advanced-core")
   (:file "expressions/parser-expr-advanced-short-circuit")
   (:file "expressions/parser-expr-advanced-compound")
   (:file "expressions/parser-expr-advanced-skip")
   (:file "expressions/parser-expr-advanced-dispatch")
   (:file "expressions/runtime-operators")
   (:file "types/parser-stmt-params")
   (:file "functions/parser-stmt-params")
   (:file "arrays/runtime-representations")
   (:file "arrays/runtime-array")
   (:file "arrays/runtime-references")
   (:file "arrays/parser-expr-advanced-array")
   (:file "strings/parser-expr-advanced-string")
   (:file "strings/runtime-strings")
   (:file "match/parser-expr-advanced-match")
   (:file "generators/runtime-generators")
   (:file "generators/parser-expr-advanced-yield")
   (:file "attributes/parser-attributes")
   (:file "attributes/parser-attribute-passes")
   (:file "statements/parser-stmt-lowering")
   (:file "statements/parser-stmt-lower")
   (:file "statements/parser-stmt-decls-control")
   (:file "statements/parser-stmt-decls-modules")
   (:file "statements/grammar-stmt")
   (:file "functions/parser-call-args")
   (:file "functions/parser-expr-advanced-calls")
   (:file "functions/parser-expr-advanced-closures")
   (:file "functions/runtime-functions")
   (:file "classes/parser-class")
   (:file "classes/runtime-classes")
   (:file "classes/parser-expr-new")
   (:file "classes/parser-interface")
   (:file "classes/parser-property-hooks")
   (:file "classes/parser-stmt-decls")
   (:file "classes/parser-trait")
   (:file "fibers/runtime-fibers")
   (:file "stdlib/runtime-constants")
   ;; Builtins load after their feature dependencies, with registration last.
   (:file "stdlib/runtime-builtins-core")
   (:file "stdlib/runtime-builtins-array")
   (:file "stdlib/runtime-builtins-array-callable")
   (:file "stdlib/runtime-builtins-array-compare")
   (:file "stdlib/runtime-builtins-array-reshape")
   (:file "stdlib/runtime-builtins-array-cursor")
   (:file "stdlib/runtime-builtins-array-sort")
   (:file "stdlib/runtime-builtins-string-data")
   (:file "stdlib/runtime-builtins-string")
   (:file "stdlib/runtime-builtins-string-core")
   (:file "stdlib/runtime-builtins-string-format")
   (:file "stdlib/runtime-builtins-string-multibyte")
   (:file "stdlib/runtime-builtins-string-encoding")
   (:file "stdlib/runtime-builtins-string-transform")
   (:file "stdlib/runtime-builtins-string-analysis")
   (:file "stdlib/runtime-builtins-string-ctype")
   (:file "stdlib/runtime-builtins-string-extra")
   (:file "stdlib/runtime-builtins-string-serialization")
   (:file "stdlib/runtime-builtins-string-json")
   (:file "stdlib/runtime-builtins-string-digest")
   (:file "stdlib/runtime-builtins-regex")
   (:file "stdlib/runtime-builtins-regex-preg")
   (:file "stdlib/runtime-builtins-regex-date")
   (:file "stdlib/runtime-builtins-regex-number")
   (:file "stdlib/runtime-builtins-regex-callback")
   (:file "stdlib/runtime-builtins-regex-array")
   (:file "stdlib/runtime-builtins-math")
   (:file "stdlib/runtime-builtins-types")
   (:file "stdlib/runtime-builtins-io-data")
   (:file "stdlib/runtime-builtins-io")
   (:file "stdlib/runtime-builtins-io-ini")
   (:file "stdlib/runtime-builtins-io-locale")
   (:file "stdlib/runtime-builtins-io-scan")
   (:file "stdlib/runtime-builtins-io-files")
   (:file "stdlib/runtime-builtins-io-streams")
   (:file "stdlib/runtime-builtins-io-objects")
   (:file "stdlib/runtime-builtins-io-autoload")
   (:file "stdlib/runtime-builtins-io-spl")
   (:file "stdlib/runtime-builtins-io-reflection-objects")
   (:file "stdlib/runtime-builtins-io-compat-objects")
   (:file "stdlib/runtime-builtins-io-image")
   (:file "stdlib/runtime-builtins-io-output")
   (:file "stdlib/runtime-builtins-io-cookie-session")
   (:file "stdlib/runtime-builtins-io-tokenizer")
   (:file "stdlib/runtime-builtins-io-uri")
   (:file "stdlib/runtime-builtins-register-names")
   (:file "stdlib/runtime-builtins-register-names-late")
   (:file "stdlib/runtime-builtins-register")
   ;; Backend provider registration loads after all runtime helpers.
   (:file "backend/runtime-bridge-provider"))
  :in-order-to ((test-op (test-op "cl-cc-php/test"))))

;; Keep the PHP test system limited to its frontend and runtime tests.
(asdf:defsystem "cl-cc-php/test"
  :description "Test suite for cl-cc-php, run directly on cl-weave"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.2"
  :homepage "https://github.com/nerima-lisp/cl-cc-php"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-php/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-php.git")
  ;; cl-weave is the test framework; compiler integration tests are reserved for the umbrella.
  :depends-on (:cl-cc-php :cl-weave)
  :pathname "t"
  :serial t
  :perform (test-op (operation system)
             (declare (ignore operation system))
             (funcall (find-symbol "RUN-TESTS" "CL-CC-PHP/TEST")))
  :components
  (
   (:file "package")
   (:module "syntax" :serial t :components
     ((:file "package")
      (:file "parser-fixtures")
      (:file "grammar-cst-test")
      (:file "grammar-test")
      (:file "lexer-test")
      (:file "parser-class-test")
      (:file "parser-stmt-lower-test")))
   (:module "expressions" :serial t :components
     ((:file "package")
      (:file "parser-e2e-test")
      (:file "parser-expr-test")
      (:file "parser-php85-language-test")
      (:file "parser-stmt-lower-test")))
   (:module "statements" :serial t :components
     ((:file "package")
      (:file "grammar-stmt-test")
      (:file "parser-php85-language-test")
      (:file "parser-stmt-decls-control-test")
      (:file "parser-stmt-decls-modules-test")
      (:file "parser-stmt-lower-test")))
   (:module "functions" :serial t :components
     ((:file "package")
      (:file "parser-class-test")
      (:file "parser-expr-test")
      (:file "parser-php84-features-test")
      (:file "parser-stmt-lower-test")))
   (:module "classes" :serial t :components
     ((:file "package")
      (:file "clone-with-php85-test")
      (:file "parser-class-e2e-test")
      (:file "parser-class-test")
      (:file "parser-expr-test")
      (:file "parser-interface-test")
      (:file "parser-php84-features-test")
      (:file "parser-php85-language-test")
      (:file "parser-stmt-lower-test")
      (:file "parser-trait-test")))
   (:module "generators" :serial t :components
     ((:file "package")
      (:file "generator-runtime-test")
      (:file "parser-expr-test")
      (:file "runtime-builtins-register-e2e-test")))
   (:module "fibers" :serial t :components
     ((:file "package")
      (:file "parser-php84-features-test")))
   (:module "arrays" :serial t :components
     ((:file "package")
      (:file "parser-class-test")
      (:file "parser-expr-test")
      (:file "parser-php84-features-test")
      (:file "parser-php85-language-test")
      (:file "parser-stmt-lower-test")
      (:file "runtime-builtins-array-e2e-test")))
   (:module "strings" :serial t :components
     ((:file "package")
      (:file "parser-expr-test")
      (:file "parser-php85-language-test")
      (:file "runtime-builtins-register-e2e-test")
      (:file "string-case-property-test")))
   (:module "match" :serial t :components
     ((:file "package")
      (:file "parser-stmt-lower-test")))
   (:module "attributes" :serial t :components
     ((:file "package")
      (:file "parser-class-test")
      (:file "parser-php85-language-test")))
   (:module "types" :serial t :components
     ((:file "package")
      (:file "parser-class-test")
      (:file "parser-expr-test")
      (:file "parser-php84-features-test")
      (:file "parser-stmt-lower-test")))
   (:module "errors" :serial t :components
     ((:file "package")
      (:file "generator-error-behavior-test")
      (:file "parser-stmt-lower-test")
      (:file "runtime-builtins-register-e2e-test")))
   (:module "stdlib" :serial t :components
     ((:file "package")
      (:file "parser-php85-language-test")
      (:file "parser-stmt-lower-test")
      (:file "runtime-builtins-array-php85-test")
      (:file "runtime-builtins-array-test")
      (:file "runtime-builtins-array-transform-test")
      (:file "runtime-builtins-io-cookie-session-php85-test")
      (:file "runtime-builtins-io-cookie-session-test")
      (:file "runtime-builtins-io-dom-php85-test")
      (:file "runtime-builtins-io-files-test")
      (:file "runtime-builtins-io-image-test")
      (:file "runtime-builtins-io-objects-php85-test")
      (:file "runtime-builtins-io-objects-test")
      (:file "runtime-builtins-io-test")
      (:file "runtime-builtins-io-tokenizer-php85-test")
      (:file "runtime-builtins-io-uri-php85-test")
      (:file "runtime-builtins-math-test")
      (:file "runtime-builtins-regex-date-test")
      (:file "runtime-builtins-regex-preg-test")
      (:file "runtime-builtins-string-analysis-test")
      (:file "runtime-builtins-string-core-test")
      (:file "runtime-builtins-string-ctype-test")
      (:file "runtime-builtins-string-encoding-test")
      (:file "runtime-builtins-string-extra-test")
      (:file "runtime-builtins-string-json-test")
      (:file "runtime-builtins-string-multibyte-test")
      (:file "runtime-builtins-string-php85-test")
      (:file "runtime-builtins-string-transform-test")
      (:file "runtime-builtins-types-php85-test")
      (:file "runtime-builtins-types-test")
      (:file "runtime-constants-test")
      (:file "standard-library-php85-test")))
   (:module "backend" :serial t :components
     ((:file "package")
      (:file "parser-class-test")
      (:file "runtime-bridge-provider-test")))
  ))
