(in-package :cl-cc/php/errors/test)

(describe "PHP error and exception tests"
  (it-sequential "make-exception builds a lightweight (:php-exception CLASS VALUE) payload"
  (let ((payload (cl-cc/php:%php-make-exception 'value-error "bad")))
    (expect payload :to-equal '(:php-exception value-error "bad"))
    (expect (cl-cc/php:%php-exception-object-p payload) :to-be-truthy)
    (expect (cl-cc/php/errors:%php-exception-class payload) :to-be 'value-error)
    (expect (cl-cc/php:%php-exception-value payload) :to-equal "bad")))
  (it-sequential "exception-object-p is false for an ordinary value, exception-value passes it through"
  (expect (cl-cc/php:%php-exception-object-p 42) :to-be nil)
  (expect (cl-cc/php:%php-exception-value 42) :to-be 42))
  (it-sequential "exception-matches-p checks a real PHP-EXCEPTION condition's class, and accepts a list of candidates"
  (let ((condition
          (handler-case (progn (cl-cc/php:%php-throw 'type-error "bad") nil)
            (cl-cc/php:php-exception (e) e))))
    (expect (cl-cc/php:%php-exception-matches-p condition 'type-error) :to-be-truthy)
    (expect (cl-cc/php:%php-exception-matches-p condition 'value-error) :to-be nil)
    (expect (cl-cc/php:%php-exception-matches-p condition '(value-error type-error)) :to-be-truthy)
    (expect (cl-cc/php:%php-exception-matches-p condition 'cl-cc/php:php-exception) :to-be-truthy))))
