(in-package :cl-cc/php/functions/test)

(describe "PHP function parser tests"
  (it-sequential "php-parser-arrow-function-expression"
  (let ((value (%php-first-binding-value "<?php $inc = fn($x) => $x + 1;")))
    ;; fn arrow functions wrap the lambda in a capture let-binding
    (expect (cl-cc/ast:ast-let-p value) :to-be-truthy)
    (let ((lambda (first (cl-cc/ast:ast-let-body value))))
      (expect (cl-cc/ast:ast-lambda-p lambda) :to-be-truthy)
      (expect (mapcar #'symbol-name (cl-cc/ast:ast-lambda-params lambda)) :to-equal '("x")))))
  (it-sequential "php-parser-call-syntax-variants spread-arg"
  (destructuring-bind (src pred) (list "<?php foo(...$args);" #'cl-cc/ast:ast-apply-p)
    (expect (funcall pred (%php-first src)) :to-be-truthy)))
  (it-sequential "php-parser-call-syntax-variants named-args"
  (destructuring-bind (src pred) (list "<?php foo(name: 'x', age: 5);" #'cl-cc/ast:ast-call-p)
    (expect (funcall pred (%php-first src)) :to-be-truthy)))
  (it-sequential "php-parser-call-syntax-variants named-mixed"
  (destructuring-bind (src pred) (list "<?php foo('pos', name: 'x');" #'cl-cc/ast:ast-call-p)
    (expect (funcall pred (%php-first src)) :to-be-truthy)))
  (it-sequential "php-parser-named-args-after-dynamic-spread"
  (let* ((asts (cl-cc/php:parse-php-source
                "<?php function f($a,$b,$c) { return $c; } f(...$args, c: 3);"))
         (call (second asts)))
    (expect (cl-cc/ast:ast-apply-p call) :to-be-truthy)))
  (it-sequential "php-parser-named-argument-metadata-is-source-local"
  (cl-cc/php:parse-php-source
   "<?php function foo($value) { return $value; } echo foo(value: 'x');")
  (let ((ast (%php-first "<?php foo(name: 'x');")))
    (expect (cl-cc/ast:ast-call-p ast) :to-be-truthy)
    (expect (%php-call-name (first (cl-cc/ast:ast-call-args ast))) :to-equal "%PHP-NAMED-ARG")))
  (it-sequential "php-parser-first-class-callable"
  (let ((ast (%php-first "<?php $f = strlen(...);")))
    ;; assignment lowers to ast-let/ast-setq with a call value; just ensure it parsed.
    (expect ast :to-be-truthy))))
