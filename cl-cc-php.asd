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
  :version "0.1.1"
  :homepage "https://github.com/nerima-lisp/cl-cc-php"
  :bug-tracker "https://github.com/nerima-lisp/cl-cc-php/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-cc-php.git")
  :depends-on (:cl-cc-ast        ; AST node definitions the parser emits
               :cl-cc-bootstrap  ; compiler self-hosting core
               :cl-cc-parse      ; shared parsing infrastructure
               :cl-cc-vm         ; bytecode VM
               :cl-json-kit)     ; RFC 8259 JSON reader, used by json_validate
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
     (:file "runtime-builtins-io-streams")
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
     (:file "runtime-builtins-register-names")
     (:file "runtime-builtins-register-names-late")
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
   (:file "grammar-stmt")
   ;; Must load last, after every %PHP-* function is defined: the provider
   ;; thunk is called later, but the file registers it at load time.
   (:file "runtime-bridge-provider"))
  :in-order-to ((test-op (test-op "cl-cc-php/test"))))

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
  :version "0.1.1"
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
   (:file "helpers-parser")
   (:file "helpers-e2e")
   (:file "lexer-test")
   (:file "grammar-test")
   (:file "grammar-cst-test")
   (:file "grammar-stmt-test")
   (:file "parser-stmt-lower-test")
   (:file "parser-stmt-decls-control-test")
   (:file "parser-expr-test")
   (:file "parser-stmt-decls-modules-test")
   (:file "parser-class-test")
   (:file "parser-interface-test")
   (:file "parser-trait-test")
   (:file "runtime-builtins-string-ctype-test")
   (:file "runtime-builtins-string-core-test")
   (:file "runtime-builtins-array-test")
   (:file "runtime-builtins-array-transform-test")
   (:file "runtime-builtins-regex-preg-test")
   (:file "runtime-builtins-regex-date-test")
   (:file "runtime-builtins-string-multibyte-test")
   (:file "runtime-builtins-string-extra-test")
   (:file "runtime-builtins-string-transform-test")
   (:file "runtime-builtins-string-encoding-test")
   (:file "runtime-builtins-string-analysis-test")
   (:file "runtime-builtins-string-json-test")
   (:file "runtime-builtins-io-files-test")
   (:file "runtime-builtins-io-test")
   (:file "runtime-builtins-io-objects-test")
   (:file "runtime-builtins-io-image-test")
   (:file "runtime-builtins-math-test")
   (:file "runtime-constants-test")
   (:file "runtime-builtins-types-test")
   (:file "parser-property-hooks-e2e-test")
   (:file "runtime-helpers-operators-case-property-test")
   (:file "runtime-helpers-generators-test")
   (:file "parser-php84-features-test")
   (:file "parser-php85-language-test")
   (:file "runtime-helpers-php85-behavior-test")
   (:file "runtime-builtins-io-objects-php85-test")
   (:file "runtime-builtins-io-dom-php85-test")
   (:file "runtime-builtins-io-uri-php85-test")
   (:file "runtime-builtins-io-tokenizer-php85-test")
   (:file "runtime-builtins-io-cookie-session-test")
   (:file "runtime-builtins-io-cookie-session-php85-test")
   (:file "runtime-builtins-array-e2e-test")
   (:file "runtime-builtins-register-e2e-test")
   (:file "runtime-builtins-register-e2e-formatting-test")
   (:file "runtime-bridge-provider-test")
   (:file "parser-e2e-test")
   (:file "parser-class-e2e-test")
   (:file "runtime-helpers-e2e-test")))
