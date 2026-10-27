(in-package :cl-cc/php/attributes/test)

(describe "PHP attribute tests"
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
        (expect (cl-cc/php:php-attribute-target-type attr) :to-be :method)))))
