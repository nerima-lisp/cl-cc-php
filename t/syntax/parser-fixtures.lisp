;;;; helpers-parser.lisp — Shared parse fixtures.
;;;;
;;;; Not a suite: %php-first and friends are used by every parser-*-test.lisp file, which is why
;;;; this is named helpers-* rather than *-test.

(in-package :cl-cc/php/test-support)


(defun %php-first (src)
  "Parse SRC and return the first top-level AST node."
  (first (cl-cc/php:parse-php-source src)))

(defun %php-first-binding-value (src)
  "Parse SRC as an assignment and return the value expression from the first binding."
  (let ((ast (%php-first src)))
    (expect (cl-cc/ast:ast-let-p ast) :to-be-truthy)
    (cdr (first (cl-cc/ast:ast-let-bindings ast)))))

(defun %php-call-name (ast)
  "Return the symbol name for an AST-CALL function when it is a variable."
  (when (and (cl-cc/ast:ast-call-p ast)
             (cl-cc/ast:ast-var-p (cl-cc/ast:ast-call-func ast)))
    (symbol-name (cl-cc/ast:ast-var-name (cl-cc/ast:ast-call-func ast)))))

(defun %php-cst-ts (php-source)
  "Tokenize PHP-SOURCE (a full \"<?php ...\" snippet) and wrap it in a
php-token-stream, ready for the php-cst-parse-* functions."
  (cl-cc/php/syntax:make-php-token-stream
   :tokens (cl-cc/php:tokenize-php-source php-source)
   :source php-source
   :diagnostics nil))
