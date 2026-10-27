(in-package :cl-cc/php/functions/test)

(describe "PHP function parser tests"
  (it-sequential "php-parser-stmt-ast-type function"
  (destructuring-bind (src pred) (list "<?php function greet($name) { return $name; }" #'cl-cc/ast:ast-defun-p)
    (expect (funcall pred (%php-first src)) :to-be-truthy)))
  ;;; ─── :function handler → ast-defun ───────────────────────────────────────

(it-sequential "php-parser-function-name-and-params-captured"
  (let ((ast (%php-first "<?php function add($a, $b) { return $a; }")))
    (expect (symbol-name (cl-cc/ast:ast-defun-name ast)) :to-equal "ADD")
    (expect (= 2 (length (cl-cc/ast:ast-defun-params ast))) :to-be-truthy)))
(it-sequential "php-parser-function-no-params-is-nil"
  (let ((ast (%php-first "<?php function noop() { return 0; }")))
    (expect (typep ast 'cl-cc/ast:ast-defun) :to-be-truthy)
    (expect (cl-cc/ast:ast-defun-params ast) :to-be-null))))
