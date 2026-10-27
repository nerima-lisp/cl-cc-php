;;;; frontend/php/parser-expr-advanced-yield.lisp -- PHP Yield Expression Lowering
;;;;
;;;; Split from parser-expr-advanced.lisp.

(in-package #:cl-cc/php/generators)

;;; ─── Yield Handlers ─────────────────────────────────────────────────────────

(defun %php-parse-yield-expression (stream known-vars)
  "Parse yield/yield from into PHP runtime helper calls.

This is still a lightweight yield representation rather than a full coroutine
engine, but it prevents yield syntax from being silently rejected and preserves
the yielded value for later generator lowering passes."
  (cond
    ((and (eq (php-peek-type stream) :T-KEYWORD)
          (eq (php-peek-value stream) :from))
     (multiple-value-bind (from-token rest) (php-consume stream)
       (declare (ignore from-token))
       (multiple-value-bind (expr rest2 kv2) (php-parse-expr rest known-vars)
         (values (%php-call '%php-yield-from expr) rest2 kv2))))
    ((member (php-peek-type stream) '(:T-SEMI :T-COMMA :T-RPAREN :T-RBRACE :T-EOF) :test #'eq)
     (values (%php-call '%php-yield) stream known-vars))
    (t
     (multiple-value-bind (expr rest2 kv2) (php-parse-expr stream known-vars)
       (values (%php-call '%php-yield expr) rest2 kv2)))))
;;; ─── Yield Handlers ─────────────────────────────────────────────────────────

(progn
  (eval-when (:load-toplevel :execute)
    (register-php-cst-keyword-expression-parser
     :yield #'%php-cst-parse-unary-keyword-expression))
  (defun %php-parse-yield-keyword-expression (stream known-vars)
    "Parse a PHP yield keyword expression."
    (multiple-value-bind (token rest) (php-consume stream)
      (declare (ignore token))
      (%php-parse-yield-expression rest known-vars)))
  (eval-when (:load-toplevel :execute)
    (register-php-expression-keyword-parser
     :yield #'%php-parse-yield-keyword-expression)))
