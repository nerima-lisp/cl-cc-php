;;;; cl-cc-php.asd — PHP frontend: lexer, parser, grammar

(asdf:defsystem "cl-cc-php"
  :description "CL-CC PHP frontend: lexer, parser, and grammar"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-cc-php"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-php/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-php.git")
  :depends-on (:cl-cc-ast        ; AST node definitions the parser emits
               :cl-cc-bootstrap  ; compiler self-hosting core
               :cl-cc-parse      ; shared parsing infrastructure
               :cl-cc-vm)        ; bytecode VM
  :in-order-to ((test-op (test-op "cl-cc-php/test")))
  :pathname "src"
  :serial t
  :components
  ((:file "package")
   (:file "lexer")
   (:file "lexer-ops")
    (:file "runtime-helpers")
    (:file "runtime-helpers-generators")
    (:file "runtime-helpers-operators")
    (:file "runtime-helpers-array")
    (:file "runtime-constants")
    ;; PHP runtime builtins (count, array_*, str*, math, type predicates, and the
    ;; dispatch registry). Previously omitted, so their bodies were never compiled
    ;; — runtime calls such as array_find -> %php-array-pairs / %php-callable-function
    ;; hit undefined functions. register loads last (it references the others).
    (:file "runtime-builtins-core")
    (:file "runtime-builtins-array")
    (:file "runtime-builtins-array-callable")
    (:file "runtime-builtins-array-compare")
    (:file "runtime-builtins-array-reshape")
    (:file "runtime-builtins-array-cursor")
    (:file "runtime-builtins-array-sort")
    (:file "runtime-builtins-string-data")
    (:file "runtime-builtins-string")
    (:file "runtime-builtins-string-core")
    (:file "runtime-builtins-string-format")
    (:file "runtime-builtins-string-multibyte")
    (:file "runtime-builtins-string-encoding")
    (:file "runtime-builtins-string-transform")
    (:file "runtime-builtins-string-analysis")
    (:file "runtime-builtins-string-ctype")
    (:file "runtime-builtins-string-extra")
    (:file "runtime-builtins-string-serialization")
    (:file "runtime-builtins-string-json")
     (:file "runtime-builtins-string-digest")
     (:file "runtime-builtins-regex")
     (:file "runtime-builtins-regex-preg")
     (:file "runtime-builtins-regex-date")
     (:file "runtime-builtins-regex-number")
     (:file "runtime-builtins-regex-callback")
     (:file "runtime-builtins-regex-array")
     (:file "runtime-builtins-math")
     (:file "runtime-builtins-types")
     (:file "runtime-builtins-io-data")
     (:file "runtime-builtins-io")
     (:file "runtime-builtins-io-ini")
     (:file "runtime-builtins-io-locale")
     (:file "runtime-builtins-io-scan")
     (:file "runtime-builtins-io-files")
     (:file "runtime-builtins-io-objects")
     (:file "runtime-builtins-io-autoload")
     (:file "runtime-builtins-io-spl")
     (:file "runtime-builtins-io-reflection-objects")
     (:file "runtime-builtins-io-compat-objects")
     (:file "runtime-builtins-io-image")
     (:file "runtime-builtins-io-output")
     (:file "runtime-builtins-io-cookie-session")
     (:file "runtime-builtins-io-tokenizer")
     (:file "runtime-builtins-io-uri")
     (:file "runtime-builtins-register")
     (:file "parser")
      (:file "parser-support")
      (:file "parser-attributes")
      (:file "parser-expr")
      (:file "parser-expr-primary")
      (:file "parser-expr-new")
      (:file "parser-expr-postfix")
      (:file "parser-expr-operator")
      (:file "parser-expr-advanced")
     (:file "parser-expr-advanced-core")
     (:file "parser-expr-advanced-string")
     (:file "parser-expr-advanced-calls")
     (:file "parser-expr-advanced-short-circuit")
     (:file "parser-expr-advanced-closures")
     (:file "parser-expr-advanced-yield")
     (:file "parser-expr-advanced-array")
     (:file "parser-expr-advanced-match")
     (:file "parser-expr-advanced-compound")
     (:file "parser-expr-advanced-skip")
     (:file "parser-expr-advanced-dispatch")
   (:file "parser-stmt-lowering")
   (:file "parser-stmt-params")
   (:file "parser-stmt-lower")
   (:file "parser-stmt-decls")
   (:file "parser-stmt-decls-control")
   (:file "parser-stmt-decls-modules")
    (:file "parser-attribute-passes")
    (:file "parser-class")
    (:file "parser-trait")
    (:file "parser-interface")
    (:file "parser-call-args")
    (:file "parser-property-hooks")
    (:file "runtime-fibers")
    (:file "unsupported")
    (:file "grammar")
   (:file "grammar-stmt")))

;; A separate system: the e2e suites need to compile and *run* PHP source
;; through the full pipeline (cl-cc/compile:compile-string, cl-cc/vm:run-compiled),
;; which pulls in far more than cl-cc-php's own :depends-on — folding
;; :cl-cc-pipeline into the main system would make every consumer of the PHP
;; frontend drag along codegen/optimize/regalloc/emit for no reason. Load this
;; system to run the test suite.
(asdf:defsystem "cl-cc-php/test"
  :description "Test suite for cl-cc-php, run directly on cl-weave"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-cc-php"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-php/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-php.git")
  ;; Test-only: cl-cc-pipeline provides compile-string/run-compiled so the e2e
  ;; suites can compile and *run* PHP source end-to-end, and cl-weave is the
  ;; test framework. Neither belongs in the shipped system's :depends-on —
  ;; folding cl-cc-pipeline in would make every consumer of the PHP frontend
  ;; drag along codegen/optimize/regalloc/emit for no reason.
  :depends-on (:cl-cc-php
               :cl-cc-pipeline  ; test-only: full compile-and-run for e2e suites
               :cl-weave)       ; test-only: test framework
  :pathname "t"
  :serial t
  :components
  ((:file "package")
   (:file "php-parser-test-support")
   (:file "php-e2e-test-support")
   (:file "php-tests")
   (:file "php-grammar-tests")
   (:file "php-grammar-cst-tests")
   (:file "php-grammar-stmt-tests")
   (:file "php-parser-core-stmt-tests")
   (:file "php-parser-control-array-tests")
   (:file "php-parser-expression-tests")
   (:file "php-parser-namespace-tests")
   (:file "php-parser-type-class-tests")
   (:file "php-interfaces-tests")
   (:file "php-traits-tests")
   (:file "php-ctype-tests")
   (:file "php-string-core-tests")
   (:file "php-array-builtins-tests")
   (:file "php-regex-preg-tests")
   (:file "php-string-multibyte-tests")
   (:file "php-string-extra-tests")
   (:file "php-string-transform-tests")
   (:file "php-string-encoding-tests")
   (:file "php-io-files-tests")
   (:file "php-io-tests")
   (:file "php-io-objects-tests")
   (:file "php-io-image-tests")
   (:file "php-types-tests")
   (:file "php84-property-hooks-e2e-tests")
   (:file "php-string-case-property-tests")
   (:file "php84-tests-language")
   (:file "php85-tests-language")
   (:file "php85-tests-runtime-behavior")
   (:file "php85-tests-runtime-objects")
   (:file "php85-tests-runtime-tokenizer")
   (:file "php-compile-array-e2e-tests")
   (:file "php-compile-builtins-e2e-tests")
   (:file "php-compile-core-e2e-tests")
   (:file "php-compile-object-e2e-tests")
   (:file "php-compile-reference-e2e-tests")))
