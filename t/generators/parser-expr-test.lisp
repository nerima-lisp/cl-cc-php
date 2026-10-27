(in-package :cl-cc/php/generators/test)

(defun %php-generator-body-block (ast)
  "For a yield-containing function AST, return the inner (block nil ...) that
%php-callable-body wraps. The generator lowering is:
  (let ((gen (%php-generator-enter)))
    (%php-generator-exit gen <block>)
    gen)
so the block is the second arg of the %php-generator-exit call."
  (let* ((let-form  (first (cl-cc/ast:ast-defun-body ast)))
         (exit-call (first (cl-cc/ast:ast-let-body let-form))))
    (second (cl-cc/ast:ast-call-args exit-call))))

(describe "PHP generator tests"
  (it-sequential "php-parser-yield-expression-lowering"
  (let* ((ast (%php-first "<?php function g() { yield 1; }"))
         (let-form (first (cl-cc/ast:ast-defun-body ast)))
         (enter-call (cdr (first (cl-cc/ast:ast-let-bindings let-form))))
         (block (%php-generator-body-block ast))
         (yield-call (first (cl-cc/ast:ast-block-body block))))
    (cl-cc/php:php-check-supported-forms (list ast))
    (expect (cl-cc/ast:ast-let-p let-form) :to-be-truthy)
    (expect (%php-call-name enter-call) :to-equal "%PHP-GENERATOR-ENTER")
    (expect (cl-cc/ast:ast-block-p block) :to-be-truthy)
    (expect (cl-cc/ast:ast-call-p yield-call) :to-be-truthy)
    (expect (%php-call-name yield-call) :to-equal "%PHP-YIELD")))
  (it-sequential "php-parser-yield-from-expression-lowering"
  (let* ((ast (%php-first "<?php function g() { yield from $items; }"))
         (block (%php-generator-body-block ast))
         (yield-call (first (cl-cc/ast:ast-block-body block))))
    (cl-cc/php:php-check-supported-forms (list ast))
    (expect (cl-cc/ast:ast-block-p block) :to-be-truthy)
    (expect (cl-cc/ast:ast-call-p yield-call) :to-be-truthy)
    (expect (%php-call-name yield-call) :to-equal "%PHP-YIELD-FROM"))))
