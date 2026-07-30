;;;; runtime-helpers-generators-test.lisp — src/runtime-helpers-generators.lisp — the host-only
;;;; generator path and the PHP-exception payload helpers.
;;;;
;;;; %php-generator-enter/-exit/-active (the VM-integrated path compiled PHP generators actually
;;;; use) are already exercised extensively by e2e yield/yield-from tests. This file covers what
;;;; those never reach directly: %php-make-generator's HOST-ONLY path (its own docstring: "Host-only
;;;; path (BODY-THUNK is a Common Lisp function); compiled PHP uses the %php-generator-enter /
;;;; %php-generator-exit threading instead"), %php-generator-p, and the exception-payload predicates.

(in-package :cl-cc-php/test)

(describe "PHP generators: the host-only creation path"

(it-sequential "make-generator eagerly collects every %php-yield call the thunk makes"
  (let ((gen (cl-cc/php::%php-make-generator
              (lambda ()
                (cl-cc/php::%php-yield 1)
                (cl-cc/php::%php-yield 2)
                (cl-cc/php::%php-yield 3)
                :done))))
    (expect (cl-cc/php::%php-generator-p gen) :to-be-truthy)
    (expect (cl-cc/php::%php-generator-get-return gen) :to-be :done)
    (expect (cl-cc/php::%php-generator-drain-values gen) :to-equal '(1 2 3))))

(it-sequential "make-generator swallows an error raised by the thunk, keeping values collected so far"
  (let ((gen (cl-cc/php::%php-make-generator
              (lambda ()
                (cl-cc/php::%php-yield 1)
                (error "boom")))))
    (expect (cl-cc/php::%php-generator-drain-values gen) :to-equal '(1))))

(it-sequential "generator-p is false for an ordinary value"
  (expect (cl-cc/php::%php-generator-p 42) :to-be nil)
  (expect (cl-cc/php::%php-generator-p "not a generator") :to-be nil))

(it-sequential "%php-yield with no active generator returns a (:yield VALUE) inspection marker"
  ;; %PHP-YIELD/-FROM's fallback path for a pure host call outside any
  ;; generator body (*CURRENT-GENERATOR* unbound and no VM state active).
  (expect (cl-cc/php::%php-yield 42) :to-equal '(:yield 42))
  (expect (cl-cc/php::%php-yield-from '(1 2)) :to-equal '(:yield-from (1 2))))

  )

(describe "PHP exceptions: the payload predicates underneath THROW/CATCH lowering"

(it-sequential "make-exception builds a lightweight (:php-exception CLASS VALUE) payload"
  (let ((payload (cl-cc/php::%php-make-exception 'value-error "bad")))
    (expect payload :to-equal '(:php-exception value-error "bad"))
    (expect (cl-cc/php::%php-exception-object-p payload) :to-be-truthy)
    (expect (cl-cc/php::%php-exception-class payload) :to-be 'value-error)
    (expect (cl-cc/php::%php-exception-value payload) :to-equal "bad")))

(it-sequential "exception-object-p is false for an ordinary value, exception-value passes it through"
  (expect (cl-cc/php::%php-exception-object-p 42) :to-be nil)
  (expect (cl-cc/php::%php-exception-value 42) :to-be 42))

(it-sequential "exception-matches-p checks a real PHP-EXCEPTION condition's class, and accepts a list of candidates"
  (let ((condition
          (handler-case (progn (cl-cc/php::%php-throw 'type-error "bad") nil)
            (cl-cc/php:php-exception (e) e))))
    (expect (cl-cc/php::%php-exception-matches-p condition 'type-error) :to-be-truthy)
    (expect (cl-cc/php::%php-exception-matches-p condition 'value-error) :to-be nil)
    (expect (cl-cc/php::%php-exception-matches-p condition '(value-error type-error)) :to-be-truthy)
    (expect (cl-cc/php::%php-exception-matches-p condition 'cl-cc/php::php-exception) :to-be-truthy)))

  )
