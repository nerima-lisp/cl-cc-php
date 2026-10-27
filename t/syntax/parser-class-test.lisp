(in-package :cl-cc/php/syntax/test)

(describe "PHP syntax parser tests"
  (it-sequential "php-parser-hash-comment-still-skips"
  (let ((ast (%php-first "<?php # this is a comment
function commented() { return 1; }")))
    (expect (cl-cc/ast:ast-defun-p ast) :to-be-truthy)
    (expect (symbol-name (cl-cc/ast:ast-defun-name ast)) :to-equal "COMMENTED"))))
