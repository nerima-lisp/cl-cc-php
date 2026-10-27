(in-package :cl-cc/php/functions/test)

(describe "PHP function parser tests"
  (it-sequential "php-parser-function-return-by-reference-metadata"
  (let* ((ast (%php-first "<?php function &current_item(): mixed { return $item; }"))
         (decls (cl-cc/ast:ast-defun-declarations ast)))
    (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
    (expect (getf decls :php-return-type) :to-equal "mixed")
    (expect (getf decls :php-returns-by-ref) :to-be-truthy)))
  (it-sequential "php-parser-anonymous-function-return-by-reference-metadata"
  (let* ((value (%php-first-binding-value "<?php $f = function &() { return $item; };"))
         (lambda (if (cl-cc/ast:ast-let-p value)
                     (first (cl-cc/ast:ast-let-body value))
                     value))
         (decls (cl-cc/ast:ast-lambda-declarations lambda)))
    (expect (cl-cc/ast:ast-lambda-p lambda) :to-be-truthy)
    (expect (member '(:php-returns-by-ref t) decls :test #'equal) :to-be-truthy)))
  (it-sequential "php-parser-reference-syntax-is-supported closure-use-ref"
  (destructuring-bind (src) (list "<?php $fn = function() use (&$x) { return $x; };")
    (let ((asts (cl-cc/php:parse-php-source src)))
    (expect (cl-cc/php:php-check-supported-forms asts) :to-be-truthy))))
  (it-sequential "php-parser-reference-syntax-is-supported function-ref-param"
  (destructuring-bind (src) (list "<?php function f(&$x) { return $x; }")
    (let ((asts (cl-cc/php:parse-php-source src)))
    (expect (cl-cc/php:php-check-supported-forms asts) :to-be-truthy)))))
