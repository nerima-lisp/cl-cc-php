;;;; runtime-builtins-register-e2e-test.lisp — direct runtime helper tests.
;;;;
;;;; Compiler-driven registry cases are reserved for umbrella-level integration.

(in-package :cl-cc-php/test)

(describe "PHP runtime helper tests"


(it-sequential "php-runtime-yield-helper-preserves-value"
  (expect (cl-cc/php:%php-yield 42) :to-equal '(:yield 42))
  (expect (cl-cc/php:%php-yield-from '(1 2)) :to-equal '(:yield-from (1 2))))


(it-sequential "php-runtime-exception-payload-matches-class"
  (let ((payload (cl-cc/php:%php-make-exception 'ex :value)))
    (expect (cl-cc/php:%php-exception-object-p payload) :to-be-truthy)
    (expect (cl-cc/php:%php-exception-value payload) :to-be :value)
    (expect (cl-cc/php:%php-exception-matches-p payload 'ex) :to-be-truthy)
    (expect (cl-cc/php:%php-exception-matches-p payload '(other ex)) :to-be-truthy)
    (expect (cl-cc/php:%php-exception-matches-p payload 'other) :to-be-falsy)))


(it-sequential "php-runtime-concat-stringifies-values"
  (expect (cl-cc/php:%php-concat "Hello " 42) :to-equal "Hello 42")
  (expect (cl-cc/php:%php-concat "x" t) :to-equal "x1")
  (expect (cl-cc/php:%php-concat "x" cl-cc/php:+php-null+) :to-equal "x"))


; tab


  )
