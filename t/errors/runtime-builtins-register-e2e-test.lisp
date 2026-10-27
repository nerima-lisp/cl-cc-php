(in-package :cl-cc/php/errors/test)

(describe "PHP error and exception tests"
  (it-sequential "php-runtime-exception-payload-matches-class"
  (let ((payload (cl-cc/php:%php-make-exception 'ex :value)))
    (expect (cl-cc/php:%php-exception-object-p payload) :to-be-truthy)
    (expect (cl-cc/php:%php-exception-value payload) :to-be :value)
    (expect (cl-cc/php:%php-exception-matches-p payload 'ex) :to-be-truthy)
    (expect (cl-cc/php:%php-exception-matches-p payload '(other ex)) :to-be-truthy)
    (expect (cl-cc/php:%php-exception-matches-p payload 'other) :to-be-falsy))))
