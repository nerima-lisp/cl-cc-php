;;;; parser-php85-language-test.lisp — src/parser.lisp — PHP 8.5 language features.
;;;;
;;;; Version-conformance suite, anchored on the parser entry point for the same reason as
;;;; parser-php84-features-test.lisp. Spans the pipe operator (src/parser-expr-operator.lisp),
;;;; array_first/last (src/runtime-builtins-array.lisp), the grapheme and locale helpers, the
;;;; PHP_BUILD_* constants (src/runtime-constants.lisp), and #[NoDiscard]
;;;; (src/parser-attributes.lisp, src/parser-attribute-passes.lisp).

(in-package :cl-cc-php/test)

(describe
  "PHP 8.5 language features"
  (it-sequential
    "The PHP 8.5 pipe operator lowers to the runtime pipe helper."
    (let ((ast (%php-first "<?php \"  HI  \" |> trim(...);")))
      (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
      (expect
        (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func ast))
        :to-be
        'cl-cc/php::%php-pipe)
      (expect (= 2 (length (cl-cc/ast:ast-call-args ast))) :to-be-truthy)
      (expect
        (cl-cc/ast:ast-lambda-p (second (cl-cc/ast:ast-call-args ast)))
        :to-be-truthy)))
  (it-sequential
    "The pipe helper applies a callable to the piped value."
    (expect (cl-cc/php::%php-pipe "HI" #'cl-cc/php::%php-strtolower) :to-equal "hi"))
  (it-sequential
    "array_first() and array_last() return inserted first/last values."
    (let ((array (cl-cc/php::%php-array)))
      (cl-cc/php::%php-array-set array "a" 10)
      (cl-cc/php::%php-array-set array "b" 20)
      (expect (= 10 (cl-cc/php:%php-array-first array)) :to-be-truthy)
      (expect (= 20 (cl-cc/php:%php-array-last array)) :to-be-truthy)))
  (it-sequential
    "array_first() and array_last() return null for empty arrays."
    (let ((array (cl-cc/php:%php-array)))
      (expect (cl-cc/php:%php-array-first array) :to-be cl-cc/php:+php-null+)
      (expect (cl-cc/php:%php-array-last array) :to-be cl-cc/php:+php-null+)))
  (it-sequential
    "grapheme_levenshtein() treats a base character plus combining mark as one cluster."
    (let ((cluster (format nil "a~C" (code-char #x0301))))
      (expect (= 1 (cl-cc/php::%php-grapheme-levenshtein cluster "")) :to-be-truthy)))
  (it-sequential
    "PHP 8.5 Locale direction helper detects common RTL locale identifiers."
    (expect (cl-cc/php:%php-locale-is-right-to-left "ar_EG.UTF-8") :to-be-truthy)
    (expect (cl-cc/php:%php-locale-is-right-to-left "fa-IR") :to-be-truthy)
    (expect (cl-cc/php:%php-locale-is-right-to-left "az-Arab") :to-be-truthy)
    (expect (cl-cc/php:%php-locale-is-right-to-left "en_US") :to-be-falsy)
    (expect (cl-cc/php:%php-locale-is-right-to-left "az-Latn") :to-be-falsy))
  (it-sequential
    "PHP_BUILD_DATE and PHP_BUILD_PROVIDER resolve as predefined PHP 8.5 constants."
    (multiple-value-bind (date date-found) (cl-cc/php::%php-lookup-constant "PHP_BUILD_DATE")
      (multiple-value-bind (provider provider-found) (cl-cc/php::%php-lookup-constant "PHP_BUILD_PROVIDER")
        (expect date-found :to-be-truthy)
        (expect provider-found :to-be-truthy)
        (expect date :to-equal "1970-01-01T00:00:00+00:00")
        (expect provider :to-equal "cl-cc"))))
  (it-sequential
    "PHP 8.5 #[\\NoDiscard] is preserved as function attribute metadata."
    (let* ((ast
          (%php-first "<?php #[\\NoDiscard] function important(): int { return 1; }"))
           (attr (first (getf (cl-cc/ast:ast-imports ast) :php-attributes))))
      (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
      (expect (cl-cc/php:php-attribute-name attr) :to-equal "NoDiscard")
      (expect (cl-cc/php:php-attribute-target-type attr) :to-be :function)))
  (it-sequential
    "PHP 8.5 #[NoDiscard('message')] preserves the optional attribute message."
    (let* ((ast
          (%php-first
            "<?php #[NoDiscard('use the return value')] function important() { return 1; }"))
           (attr (first (getf (cl-cc/ast:ast-imports ast) :php-attributes)))
           (arg (first (cl-cc/php:php-attribute-args attr))))
      (expect (cl-cc/php:php-attribute-name attr) :to-equal "NoDiscard")
      (expect (cl-cc/ast:ast-quote-p arg) :to-be-truthy)
      (expect (cl-cc/ast:ast-quote-value arg) :to-equal "use the return value")))
  (it-sequential
    "PHP 8.5 attributes on top-level constants survive as constant metadata."
    (let* ((ast (%php-first "<?php #[Deprecated('use NEW')] const OLD = 1;"))
           (attr (first (getf (cl-cc/ast:ast-imports ast) :php-attributes)))
           (arg (first (cl-cc/php:php-attribute-args attr))))
      (expect (cl-cc/ast:ast-defvar-p ast) :to-be-truthy)
      (expect (symbol-name (cl-cc/ast:ast-defvar-name ast)) :to-equal "OLD")
      (expect (cl-cc/php:php-attribute-name attr) :to-equal "Deprecated")
      (expect (cl-cc/php:php-attribute-target-type attr) :to-be :constant)
      (expect (cl-cc/ast:ast-quote-p arg) :to-be-truthy)
      (expect (cl-cc/ast:ast-quote-value arg) :to-equal "use NEW")))
  (it-sequential
    "PHP 8.5 attributes on grouped top-level const declarations are rejected."
    (signals
      error
      (cl-cc/php:parse-php-source "<?php #[Deprecated] const A = 1, B = 2;")))
  (it-sequential
    "PHP 8.5 #[NoDiscard] on enum methods survives enum classlike parsing."
    (dolist (source
        (list
          "<?php enum Mode { #[NoDiscard] public function label(): string { return 'x'; } case A; } class AfterEnum {}"
          "<?php class Box { #[NoDiscard] public function label(): string { return 'x'; } }"))
      (let* ((form (%php-first source))
             (ast
            (if (cl-cc/ast:ast-progn-p form) (first (cl-cc/ast:ast-progn-forms form))
              form))
             (method-slot
            (find-if
              (lambda (slot)
                (and
                  (cl-cc/ast:ast-slot-def-p slot)
                  (cl-cc/ast:ast-defun-p (cl-cc/ast:ast-slot-initform slot))))
              (append
                (list nil (cl-cc/ast:make-ast-slot-def :name 'probe :allocation :class))
                (cl-cc/ast:ast-defclass-slots ast))))
             (method (cl-cc/ast:ast-slot-initform method-slot))
             (attr (first (getf (cl-cc/ast:ast-imports method) :php-attributes))))
        (expect (cl-cc/ast:ast-defclass-p ast) :to-be-truthy)
        (expect (cl-cc/php:php-attribute-name attr) :to-equal "NoDiscard")
        (expect (cl-cc/php:php-attribute-target-type attr) :to-be :method))))
  (it-sequential
    "PHP 8.5 #[Override] is accepted on inherited methods."
    (expect
      (cl-cc/ast:ast-defclass-p
        (%php-first
          "<?php class Base { public function label(): string { return 'x'; } } class Child extends Base { #[Override] public function label(): string { return 'y'; } }"))
      :to-be-truthy))
  (it-sequential
    "PHP 8.5 #[Override] is accepted on inherited properties."
    (expect
      (cl-cc/ast:ast-defclass-p
        (%php-first
          "<?php class Base { public string $name; } class Child extends Base { #[Override] public string $name; }"))
      :to-be-truthy))
  (it-sequential
    "PHP 8.5 #[Override] does not accept private inherited properties."
    (signals
      error
      (cl-cc/php:parse-php-source
        "<?php class Base { private string $name; } class Child extends Base { #[Override] public string $name; }")))
  (it-sequential
    "The PHP 8.5 (void) statement evaluates its operand and returns PHP null."
    (let* ((value (%php-first "<?php (void) 123;"))
           (forms (cl-cc/ast:ast-progn-forms value)))
      (expect (cl-cc/ast:ast-progn-p value) :to-be-truthy)
      (expect (= 2 (length forms)) :to-be-truthy)
      (expect (cl-cc/ast:ast-quote-value (second forms)) :to-be cl-cc/php:+php-null+))))
